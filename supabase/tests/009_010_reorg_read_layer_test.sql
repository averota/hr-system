-- Test for 009 (reorg) and 010 (read layer)
-- Paste into Supabase Dashboard -> SQL Editor (dev project only).
-- Everything rolls back at the end; nothing is kept.
-- "Success. No rows returned" = pass. An error starting with FAIL: = a check failed.

begin;

-- ---------------------------------------------------------------
-- Temporary helpers (vanish with the transaction)
-- ---------------------------------------------------------------
create function pg_temp.ok(p_ok boolean, p_label text)
returns void language plpgsql as $$
begin
  if p_ok is not true then
    raise exception 'FAIL: %', p_label;
  end if;
end $$;

create function pg_temp.expect_error(p_sql text, p_fragment text, p_label text)
returns void language plpgsql as $$
begin
  begin
    execute p_sql;
  exception when others then
    if position(lower(p_fragment) in lower(sqlerrm)) = 0 then
      raise exception 'FAIL: % (wrong error: %)', p_label, sqlerrm;
    end if;
    return;
  end;
  raise exception 'FAIL: % (expected an error, none was raised)', p_label;
end $$;

create function pg_temp.rows_in(p_sql text)
returns integer language plpgsql as $$
declare
  v integer;
begin
  execute 'select count(*) from (' || p_sql || ') q' into v;
  return v;
end $$;

create function pg_temp.add_rule(p_company integer, p_level text, p_parent text default null)
returns void language sql as $$
  insert into core.company_level_rule
    (company_id, tree, level_id, level_rank, parent_level_id, parent_level_rank)
  select p_company, l.tree, l.id, l.rank, pl.id, pl.rank
  from core.hierarchy_level l
  left join core.hierarchy_level pl on pl.code = p_parent and pl.tree = l.tree
  where l.code = p_level
$$;

do $$
declare
  v_today   date := current_date;
  l_bu integer; l_branch integer; l_div integer;
  l_dept integer; l_office integer; l_section integer;
  v_t1 integer; v_t2 integer; v_c1 integer; v_c2 integer;
  v_u1 uuid := gen_random_uuid();
  v_u2 uuid := gen_random_uuid();
  v_bu1 integer; v_bu2 integer; v_br1 integer; v_dv1 integer; v_x integer;
  v_da integer; v_db integer; v_o1 integer; v_o2 integer; v_s1 integer; v_s2 integer;
  v_job_a integer; v_job_b integer;
  v_parent integer;
  v_n integer;
begin
  -- -------------------------------------------------------------
  -- Setup
  -- -------------------------------------------------------------
  select max(id) filter (where code = 'business_unit'),
         max(id) filter (where code = 'branch'),
         max(id) filter (where code = 'division'),
         max(id) filter (where code = 'department'),
         max(id) filter (where code = 'office'),
         max(id) filter (where code = 'section')
  into l_bu, l_branch, l_div, l_dept, l_office, l_section
  from core.hierarchy_level;

  insert into core.tenant (name_en) values ('Test tenant 1') returning id into v_t1;
  insert into core.tenant (name_en) values ('Test tenant 2') returning id into v_t2;
  insert into core.parent_company (tenant_id, name_en) values (v_t1, 'Company 1') returning id into v_c1;
  insert into core.parent_company (tenant_id, name_en) values (v_t2, 'Company 2') returning id into v_c2;

  insert into auth.users (id, aud, role, email)
  values (v_u1, 'authenticated', 'authenticated', 'reorg-test-1@example.invalid'),
         (v_u2, 'authenticated', 'authenticated', 'reorg-test-2@example.invalid');
  insert into core.tenant_member (tenant_id, user_id)
  values (v_t1, v_u1), (v_t2, v_u2);

  -- Company 1 rules (8): org BU, Branch (root), Branch (under BU), Division;
  --                      pos Department, Office, Section (under Office), Section (under Department)
  perform pg_temp.add_rule(v_c1, 'business_unit');
  perform pg_temp.add_rule(v_c1, 'branch');
  perform pg_temp.add_rule(v_c1, 'branch', 'business_unit');
  perform pg_temp.add_rule(v_c1, 'division', 'branch');
  perform pg_temp.add_rule(v_c1, 'department');
  perform pg_temp.add_rule(v_c1, 'office', 'department');
  perform pg_temp.add_rule(v_c1, 'section', 'office');
  perform pg_temp.add_rule(v_c1, 'section', 'department');
  perform pg_temp.add_rule(v_c2, 'business_unit');

  v_bu1 := private.create_org_unit(v_c1, l_bu, null, 'BU1');
  v_bu2 := private.create_org_unit(v_c1, l_bu, null, 'BU2');
  v_br1 := private.create_org_unit(v_c1, l_branch, v_bu1, 'Branch1');
  v_dv1 := private.create_org_unit(v_c1, l_div, v_br1, 'Division1');
  v_x   := private.create_org_unit(v_c2, l_bu, null, 'Other company BU');

  v_da := private.create_pos_unit(v_c1, l_dept, null, 'Dept A');
  v_db := private.create_pos_unit(v_c1, l_dept, null, 'Dept B');
  v_o1 := private.create_pos_unit(v_c1, l_office, v_da, 'Office1');
  v_o2 := private.create_pos_unit(v_c1, l_office, v_db, 'Office2');
  v_s1 := private.create_pos_unit(v_c1, l_section, v_o1, 'Section1');
  v_s2 := private.create_pos_unit(v_c1, l_section, v_da, 'Section2');

  -- =============================================================
  -- 009: org tree reorg
  -- =============================================================
  perform private.reorg_org_unit(v_c1, v_br1, v_bu2);

  select parent_unit_id into v_parent
  from core.org_unit_parent where unit_id = v_br1 and valid_to is null;
  perform pg_temp.ok(v_parent = v_bu2, 'org: Branch1 is now under BU2');

  select count(*) into v_n from core.org_unit_parent where unit_id = v_br1;
  perform pg_temp.ok(v_n = 2, 'org: old and new links are both kept');

  select count(*) into v_n from core.org_unit_parent
  where unit_id = v_br1 and parent_unit_id = v_bu1 and valid_to = v_today;
  perform pg_temp.ok(v_n = 1, 'org: old link closed on the effective date');

  select parent_unit_id into v_parent
  from core.org_unit_parent where unit_id = v_dv1 and valid_to is null;
  perform pg_temp.ok(v_parent = v_br1, 'org: Division1 stayed under Branch1');

  perform pg_temp.expect_error(
    format('select private.reorg_org_unit(%s, %s, %s)', v_c1, v_br1, v_bu2),
    'already under this parent', 'org: same parent refused');

  -- to the root (rule: Branch directly under the company exists)
  perform private.reorg_org_unit(v_c1, v_br1, null);
  select count(*) into v_n from core.org_unit_parent
  where unit_id = v_br1 and valid_to is null and parent_unit_id is null;
  perform pg_temp.ok(v_n = 1, 'org: Branch1 moved to the root');

  -- and back under BU1
  perform private.reorg_org_unit(v_c1, v_br1, v_bu1);
  select parent_unit_id into v_parent
  from core.org_unit_parent where unit_id = v_br1 and valid_to is null;
  perform pg_temp.ok(v_parent = v_bu1, 'org: Branch1 back under BU1');
  select count(*) into v_n from core.org_unit_parent where unit_id = v_br1;
  perform pg_temp.ok(v_n = 4, 'org: four links of history for Branch1');

  perform pg_temp.expect_error(
    format('select private.reorg_org_unit(%s, %s, %s)', v_c1, v_dv1, v_bu2),
    'No active rule', 'org: Division directly under a BU refused (no rule)');

  perform pg_temp.expect_error(
    format('select private.reorg_org_unit(%s, %s, %s)', v_c1, v_bu1, v_br1),
    'No active rule', 'org: BU under its own descendant refused');

  perform pg_temp.expect_error(
    format('select private.reorg_org_unit(%s, %s, %s)', v_c1, v_br1, v_x),
    'not an open unit of this company', 'org: parent from another company refused');

  perform pg_temp.expect_error(
    format('select private.reorg_org_unit(%s, %s, %s, %L)', v_c1, v_br1, v_bu2, v_today - 1),
    'earlier than', 'org: effective date before the current link refused');

  -- =============================================================
  -- 009: position tree reorg (no allocations yet)
  -- =============================================================
  perform pg_temp.ok(private.pos_department_of(v_s1) = v_da, 'helper: Section1 is in Dept A');

  perform private.reorg_pos_unit(v_c1, v_s1, v_da);
  select parent_unit_id into v_parent
  from core.pos_unit_parent where unit_id = v_s1 and valid_to is null;
  perform pg_temp.ok(v_parent = v_da, 'pos: Section1 moved directly under Dept A');
  perform private.reorg_pos_unit(v_c1, v_s1, v_o1);

  perform pg_temp.expect_error(
    format('select private.reorg_pos_unit(%s, %s, %s)', v_c1, v_da, v_db),
    'No active rule', 'pos: a Department cannot be moved under another unit');

  perform pg_temp.expect_error(
    format('select private.reorg_pos_unit(%s, %s, null)', v_c1, v_da),
    'already under this parent', 'pos: Department already at the top');

  -- no allocation: moving into another Department's tree is allowed
  perform private.reorg_pos_unit(v_c1, v_s2, v_o2);
  perform pg_temp.ok(private.pos_department_of(v_s2) = v_db, 'pos: Section2 now sits in Dept B tree');
  perform private.reorg_pos_unit(v_c1, v_s2, v_da);
  perform pg_temp.ok(private.pos_department_of(v_s2) = v_da, 'pos: Section2 back in Dept A tree');

  -- =============================================================
  -- Data for allocation checks and the read layer
  --   jobs: Architect (Dept A), Auditor (Dept B)
  --   Dept A listed for Branch1, Dept B listed for BU1
  --   allocations: Branch1/Architect/Section1 = 5, Branch1/Architect/Dept A = 2,
  --                BU1/Auditor/Dept B = 1
  -- =============================================================
  insert into core.job_position (company_id, department_id, name_en)
  values (v_c1, v_da, 'Architect') returning id into v_job_a;
  insert into core.job_position (company_id, department_id, name_en)
  values (v_c1, v_db, 'Auditor') returning id into v_job_b;

  insert into core.org_unit_department (company_id, org_unit_id, department_id)
  values (v_c1, v_br1, v_da), (v_c1, v_bu1, v_db);

  perform private.create_allocation(v_c1, v_br1, v_job_a, v_s1, 5);
  perform private.create_allocation(v_c1, v_br1, v_job_a, v_da, 2);
  perform private.create_allocation(v_c1, v_bu1, v_job_b, v_db, 1);

  -- =============================================================
  -- 009: reorg with allocations
  -- =============================================================
  -- same Department: allowed, allocation stays on the unit
  perform private.reorg_pos_unit(v_c1, v_s1, v_da);
  select count(*) into v_n from core.position_allocation
  where pos_unit_id = v_s1 and valid_to is null;
  perform pg_temp.ok(v_n = 1, 'pos: allocation stayed on Section1 after a move inside Dept A');
  perform private.reorg_pos_unit(v_c1, v_s1, v_o1);

  -- other Department: refused while allocations sit at the unit or under it
  perform pg_temp.expect_error(
    format('select private.reorg_pos_unit(%s, %s, %s)', v_c1, v_s1, v_o2),
    'Open allocations sit', 'pos: allocated Section1 cannot move to Dept B tree');

  perform pg_temp.expect_error(
    format('select private.reorg_pos_unit(%s, %s, %s)', v_c1, v_o1, v_db),
    'Open allocations sit', 'pos: Office1 with an allocation under it cannot move to Dept B');

  select parent_unit_id into v_parent
  from core.pos_unit_parent where unit_id = v_s1 and valid_to is null;
  perform pg_temp.ok(v_parent = v_o1, 'pos: refused moves left Section1 under Office1');

  -- every open unit still has an open link (deferred check, run now)
  execute 'set constraints all immediate';
  execute 'set constraints all deferred';

  -- =============================================================
  -- 010: read layer as user 1 (member of tenant 1)
  -- =============================================================
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_u1, 'role', 'authenticated')::text, true);

  -- views
  perform pg_temp.ok(pg_temp.rows_in(format('select 1 from public.company_level_rules_current where company_id = %s', v_c1)) = 8, 'view: 8 open rules');
  perform pg_temp.ok(pg_temp.rows_in(format('select 1 from public.org_units_current where company_id = %s', v_c1)) = 4, 'view: 4 open org units');
  perform pg_temp.ok(pg_temp.rows_in(format('select 1 from public.pos_units_current where company_id = %s', v_c1)) = 6, 'view: 6 open position units');
  perform pg_temp.ok(pg_temp.rows_in(format('select 1 from public.org_unit_departments_current where company_id = %s', v_c1)) = 2, 'view: 2 eligibility rows');
  perform pg_temp.ok(pg_temp.rows_in(format('select 1 from public.job_positions_current where company_id = %s', v_c1)) = 2, 'view: 2 jobs');
  perform pg_temp.ok(pg_temp.rows_in(format('select 1 from public.position_allocations_current where company_id = %s', v_c1)) = 3, 'view: 3 allocations');
  perform pg_temp.ok(pg_temp.rows_in(format('select 1 from public.position_allocations_current where company_id = %s and approved_headcount = 5 and pos_unit_name_en = %L', v_c1, 'Section1')) = 1, 'view: Section1 headcount 5 shown');
  perform pg_temp.ok(pg_temp.rows_in(format('select 1 from public.org_units_current where unit_id = %s and parent_unit_id = %s', v_br1, v_bu1)) = 1, 'view: Branch1 shows its current parent BU1');

  -- org cascade
  perform pg_temp.ok(pg_temp.rows_in(format('select 1 from public.org_options(%s, null)', v_c1)) = 2, 'org_options: root gives BU1 and BU2');
  perform pg_temp.ok(pg_temp.rows_in(format('select 1 from public.org_options(%s, %s) where name_en = %L', v_c1, v_bu1, 'Branch1')) = 1, 'org_options: Branch1 under BU1');
  perform pg_temp.ok(pg_temp.rows_in(format('select 1 from public.org_options(%s, %s)', v_c1, v_bu2)) = 0, 'org_options: nothing under BU2');
  perform pg_temp.ok(pg_temp.rows_in(format('select 1 from public.org_options(%s, %s) where name_en = %L', v_c1, v_br1, 'Division1')) = 1, 'org_options: Division1 under Branch1');
  perform pg_temp.ok(pg_temp.rows_in(format('select 1 from public.org_options(%s, null)', v_c2)) = 0, 'org_options: other tenant company hidden');

  -- eligible Departments (no inheritance from the parent)
  perform pg_temp.ok(pg_temp.rows_in(format('select 1 from public.eligible_departments(%s, %s) where name_en = %L', v_c1, v_br1, 'Dept A')) = 1, 'eligible_departments: Branch1 offers Dept A');
  perform pg_temp.ok(pg_temp.rows_in(format('select 1 from public.eligible_departments(%s, %s)', v_c1, v_br1)) = 1, 'eligible_departments: Branch1 offers only Dept A');
  perform pg_temp.ok(pg_temp.rows_in(format('select 1 from public.eligible_departments(%s, %s) where name_en = %L', v_c1, v_bu1, 'Dept B')) = 1, 'eligible_departments: BU1 offers Dept B');
  perform pg_temp.ok(pg_temp.rows_in(format('select 1 from public.eligible_departments(%s, %s)', v_c1, v_bu2)) = 0, 'eligible_departments: BU2 offers none');
  perform pg_temp.ok(pg_temp.rows_in(format('select 1 from public.eligible_departments(%s, %s)', v_c1, v_dv1)) = 0, 'eligible_departments: Division1 does not inherit');

  -- position cascade
  perform pg_temp.ok(pg_temp.rows_in(format('select 1 from public.pos_options(%s, %s)', v_c1, v_da)) = 2, 'pos_options: Office1 and Section2 under Dept A');
  perform pg_temp.ok(pg_temp.rows_in(format('select 1 from public.pos_options(%s, %s) where name_en = %L', v_c1, v_o1, 'Section1')) = 1, 'pos_options: Section1 under Office1');
  perform pg_temp.ok(pg_temp.rows_in(format('select 1 from public.pos_options(%s, %s) where name_en = %L', v_c1, v_db, 'Office2')) = 1, 'pos_options: Office2 under Dept B');
  perform pg_temp.ok(pg_temp.rows_in(format('select 1 from public.pos_options(%s, %s)', v_c1, v_s1)) = 0, 'pos_options: nothing under Section1');

  -- eligible jobs: invalid combinations never appear
  perform pg_temp.ok(pg_temp.rows_in(format('select 1 from public.eligible_jobs(%s, %s, %s) where name_en = %L', v_c1, v_br1, v_da, 'Architect')) = 1, 'eligible_jobs: Architect offered at Branch1 for Dept A');
  perform pg_temp.ok(pg_temp.rows_in(format('select 1 from public.eligible_jobs(%s, %s, %s)', v_c1, v_br1, v_db)) = 0, 'eligible_jobs: Dept B jobs not offered at Branch1');
  perform pg_temp.ok(pg_temp.rows_in(format('select 1 from public.eligible_jobs(%s, %s, %s)', v_c1, v_bu1, v_da)) = 0, 'eligible_jobs: Architect not offered at BU1');
  perform pg_temp.ok(pg_temp.rows_in(format('select 1 from public.eligible_jobs(%s, %s, %s) where name_en = %L', v_c1, v_bu1, v_db, 'Auditor')) = 1, 'eligible_jobs: Auditor offered at BU1 for Dept B');

  -- closed rows disappear from the read layer
  execute 'reset role';
  perform private.close_pos_unit(v_c1, v_s2);
  execute 'set local role authenticated';
  perform pg_temp.ok(pg_temp.rows_in(format('select 1 from public.pos_options(%s, %s)', v_c1, v_da)) = 1, 'pos_options: closed Section2 is gone');
  perform pg_temp.ok(pg_temp.rows_in(format('select 1 from public.pos_units_current where company_id = %s', v_c1)) = 5, 'view: closed unit is gone');

  -- =============================================================
  -- 010: tenant isolation (user 2 belongs to tenant 2 only)
  -- =============================================================
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_u2, 'role', 'authenticated')::text, true);

  perform pg_temp.ok(pg_temp.rows_in(format('select 1 from public.org_options(%s, null)', v_c1)) = 0, 'isolation: user 2 gets no org options for company 1');
  perform pg_temp.ok(pg_temp.rows_in(format('select 1 from public.org_units_current where company_id = %s', v_c1)) = 0, 'isolation: user 2 sees no org units of company 1');
  perform pg_temp.ok(pg_temp.rows_in(format('select 1 from public.position_allocations_current where company_id = %s', v_c1)) = 0, 'isolation: user 2 sees no allocations of company 1');
  perform pg_temp.ok(pg_temp.rows_in(format('select 1 from public.org_options(%s, null)', v_c2)) = 1, 'isolation: user 2 sees own company');

  -- =============================================================
  -- 010: anon gets nothing
  -- =============================================================
  execute 'reset role';
  execute 'set local role anon';

  begin
    perform 1 from public.org_units_current;
    raise exception 'FAIL: anon can read org_units_current';
  exception when insufficient_privilege then
    null;
  end;

  begin
    perform 1 from public.org_options(v_c1, null);
    raise exception 'FAIL: anon can run org_options';
  exception when insufficient_privilege then
    null;
  end;

  execute 'reset role';
end $$;

rollback;

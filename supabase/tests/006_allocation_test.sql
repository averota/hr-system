-- Test for 006_allocation.sql
-- Run in Supabase Dashboard -> SQL Editor (dev project only).
-- Everything is rolled back at the end; nothing is saved.
--
-- PASS = "Success. No rows returned"
-- FAIL = an error message that starts with FAIL

begin;

-- ---------------------------------------------------------------
-- Test helpers (exist only for this transaction)
-- ---------------------------------------------------------------
create function pg_temp.lvl(p_code text) returns integer
language sql as $$ select id from core.hierarchy_level where code = p_code $$;

create function pg_temp.add_rule(p_company integer, p_level text, p_parent text)
returns void language plpgsql as $$
declare
  l core.hierarchy_level%rowtype;
  p core.hierarchy_level%rowtype;
begin
  select * into l from core.hierarchy_level where code = p_level;
  if p_parent is not null then
    select * into p from core.hierarchy_level where code = p_parent;
  end if;
  insert into core.company_level_rule
    (company_id, tree, level_id, level_rank, parent_level_id, parent_level_rank)
  values (p_company, l.tree, l.id, l.rank, p.id, p.rank);
end $$;

-- Forces the deferred "unit must have an open link" check to run now
create function pg_temp.check_now() returns void language plpgsql as $$
begin
  execute 'set constraints all immediate';
  execute 'set constraints all deferred';
end $$;

create function pg_temp.mk_org(p_company integer, p_level text, p_parent integer, p_name text)
returns integer language plpgsql as $$
declare v_id integer;
begin
  v_id := private.create_org_unit(p_company, pg_temp.lvl(p_level), p_parent, p_name, null);
  perform pg_temp.check_now();
  return v_id;
end $$;

create function pg_temp.mk_pos(p_company integer, p_level text, p_parent integer, p_name text)
returns integer language plpgsql as $$
declare v_id integer;
begin
  v_id := private.create_pos_unit(p_company, pg_temp.lvl(p_level), p_parent, p_name, null);
  perform pg_temp.check_now();
  return v_id;
end $$;

create function pg_temp.alloc(
  p_company integer, p_org integer, p_job integer, p_pos integer, p_headcount integer)
returns integer language sql as $$
  select private.create_allocation(p_company, p_org, p_job, p_pos, p_headcount)
$$;

-- Runs a statement and checks that it fails with the expected SQLSTATE
create function pg_temp.expect_error(p_sql text, p_state text, p_label text)
returns void language plpgsql as $$
declare v_ok boolean := false;
begin
  begin
    execute p_sql;
    execute 'set constraints all immediate';
  exception when others then
    if sqlstate = p_state then
      v_ok := true;
    else
      raise exception 'FAIL: % (expected %, got % - %)', p_label, p_state, sqlstate, sqlerrm;
    end if;
  end;
  execute 'set constraints all deferred';
  if not v_ok then
    raise exception 'FAIL: % (statement was accepted)', p_label;
  end if;
end $$;

-- ---------------------------------------------------------------
-- Fixtures: two users, two tenants, one company each
-- ---------------------------------------------------------------
insert into auth.users
  (instance_id, id, aud, role, email, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
   'authenticated', 'authenticated', 'user_a@test.local', '{}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
   'authenticated', 'authenticated', 'user_b@test.local', '{}', '{}', now(), now());

insert into core.tenant (name_en) values ('Tenant A'), ('Tenant B');

insert into core.parent_company (tenant_id, name_en)
select id, 'Company ' || right(name_en, 1) from core.tenant;

insert into core.tenant_member (tenant_id, user_id)
select id,
       case name_en
         when 'Tenant A' then 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid
         else 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'::uuid
       end
from core.tenant;

-- ---------------------------------------------------------------
-- Part 1: allocation behaviour (running as admin)
-- ---------------------------------------------------------------
do $$
declare
  v_a integer;
  v_b integer;
  bu1 integer;
  br1 integer;
  bu_b integer;
  d_eng integer;
  d_it integer;
  o_eng integer;
  s_eng integer;
  o_it integer;
  d_b integer;
  j_arch integer;
  j_mgr integer;
  j_dev integer;
  j_b integer;
  e_br1 integer;
  e_bu1 integer;
  a1 integer;
  a1b integer;
  a2 integer;
  a3 integer;
  a_b integer;
  v_n integer;
begin
  select id into v_a from core.parent_company where name_en = 'Company A';
  select id into v_b from core.parent_company where name_en = 'Company B';
  perform set_config('test.company_a', v_a::text, true);
  perform set_config('test.company_b', v_b::text, true);

  -- Rules
  perform pg_temp.add_rule(v_a, 'business_unit', null);
  perform pg_temp.add_rule(v_a, 'branch',        'business_unit');
  perform pg_temp.add_rule(v_a, 'department',    null);
  perform pg_temp.add_rule(v_a, 'office',        'department');
  perform pg_temp.add_rule(v_a, 'section',       'office');
  perform pg_temp.add_rule(v_b, 'business_unit', null);
  perform pg_temp.add_rule(v_b, 'department',    null);

  -- Org units
  bu1  := pg_temp.mk_org(v_a, 'business_unit', null, 'BU 1');
  br1  := pg_temp.mk_org(v_a, 'branch',        bu1,  'Branch 1');
  bu_b := pg_temp.mk_org(v_b, 'business_unit', null, 'BU B');

  -- Position units
  d_eng := pg_temp.mk_pos(v_a, 'department', null,  'Engineering');
  d_it  := pg_temp.mk_pos(v_a, 'department', null,  'IT');
  o_eng := pg_temp.mk_pos(v_a, 'office',     d_eng, 'Eng Office');
  s_eng := pg_temp.mk_pos(v_a, 'section',    o_eng, 'Eng Section');
  o_it  := pg_temp.mk_pos(v_a, 'office',     d_it,  'IT Office');
  d_b   := pg_temp.mk_pos(v_b, 'department', null,  'Dept B');

  -- Jobs
  insert into core.job_position (company_id, department_id, name_en) values (v_a, d_eng, 'Architect');
  insert into core.job_position (company_id, department_id, name_en) values (v_a, d_eng, 'Manager');
  insert into core.job_position (company_id, department_id, name_en) values (v_a, d_it,  'Developer');
  insert into core.job_position (company_id, department_id, name_en) values (v_b, d_b,   'B Analyst');

  select id into j_arch from core.job_position where company_id = v_a and name_en = 'Architect';
  select id into j_mgr  from core.job_position where company_id = v_a and name_en = 'Manager';
  select id into j_dev  from core.job_position where company_id = v_a and name_en = 'Developer';
  select id into j_b    from core.job_position where company_id = v_b and name_en = 'B Analyst';

  -- Eligibility: Branch 1 offers Engineering only. BU 1 offers IT only.
  insert into core.org_unit_department (company_id, org_unit_id, department_id) values
    (v_a, br1,  d_eng),
    (v_a, bu1,  d_it),
    (v_b, bu_b, d_b);

  select id into e_br1 from core.org_unit_department
  where org_unit_id = br1 and department_id = d_eng and valid_to is null;
  select id into e_bu1 from core.org_unit_department
  where org_unit_id = bu1 and department_id = d_it and valid_to is null;

  -- ---------- Valid allocations ----------
  a1  := pg_temp.alloc(v_a, br1,  j_arch, d_eng, 3);   -- at the Department itself
  a2  := pg_temp.alloc(v_a, br1,  j_mgr,  s_eng, 1);   -- deep in the Department's tree
  a3  := pg_temp.alloc(v_a, bu1,  j_dev,  o_it,  2);
  a_b := pg_temp.alloc(v_b, bu_b, j_b,    d_b,   5);

  select count(*) into v_n from core.position_allocation
  where company_id = v_a and valid_to is null;
  if v_n <> 3 then raise exception 'FAIL: company A has % open allocations, expected 3', v_n; end if;

  select count(*) into v_n from core.position_allocation
  where company_id = v_b and valid_to is null;
  if v_n <> 1 then raise exception 'FAIL: company B has % open allocations, expected 1', v_n; end if;

  -- Zero headcount is allowed
  perform pg_temp.alloc(v_a, br1, j_arch, o_eng, 0);

  -- ---------- Invalid allocations through the create function ----------
  perform pg_temp.expect_error(
    format('select pg_temp.alloc(%s, %s, %s, %s, 1)', v_a, bu1, j_arch, d_eng),
    'P0001', 'Architect at an org unit that only offers IT');

  perform pg_temp.expect_error(
    format('select pg_temp.alloc(%s, %s, %s, %s, 1)', v_a, br1, j_dev, o_it),
    'P0001', 'Developer (IT) at an org unit that only offers Engineering');

  perform pg_temp.expect_error(
    format('select pg_temp.alloc(%s, %s, %s, %s, 1)', v_a, br1, j_arch, o_it),
    'P0001', 'Position unit from another Department''s tree');

  perform pg_temp.expect_error(
    format('select pg_temp.alloc(%s, %s, %s, %s, 1)', v_a, br1, j_arch, d_it),
    'P0001', 'Another Department used as the position unit');

  perform pg_temp.expect_error(
    format('select pg_temp.alloc(%s, %s, %s, %s, 1)', v_a, br1, j_arch, d_b),
    'P0001', 'Position unit belonging to another company');

  perform pg_temp.expect_error(
    format('select pg_temp.alloc(%s, %s, %s, %s, 1)', v_b, bu_b, j_arch, d_b),
    'P0001', 'Job position belonging to another company');

  perform pg_temp.expect_error(
    format('select pg_temp.alloc(%s, %s, %s, %s, -1)', v_a, br1, j_mgr, o_eng),
    '23514', 'Negative headcount');

  perform pg_temp.expect_error(
    format('select pg_temp.alloc(%s, %s, %s, %s, 1)', v_a, br1, j_arch, d_eng),
    '23505', 'Duplicate open allocation');

  -- ---------- Invalid data inserted directly (database-level protection) ----------
  perform pg_temp.expect_error(
    format('insert into core.position_allocation
              (company_id, org_unit_id, department_id, eligibility_id, job_position_id, pos_unit_id, approved_headcount)
            values (%s, %s, %s, %s, %s, %s, 1)',
           v_a, bu1, d_eng, e_br1, j_arch, d_eng),
    '23503', 'Direct insert: eligibility row belongs to another org unit');

  perform pg_temp.expect_error(
    format('insert into core.position_allocation
              (company_id, org_unit_id, department_id, eligibility_id, job_position_id, pos_unit_id, approved_headcount)
            values (%s, %s, %s, %s, %s, %s, 1)',
           v_a, br1, d_eng, e_br1, j_dev, d_eng),
    '23503', 'Direct insert: job belongs to another Department');

  perform pg_temp.expect_error(
    format('insert into core.position_allocation
              (company_id, org_unit_id, department_id, eligibility_id, job_position_id, pos_unit_id, approved_headcount)
            values (%s, %s, %s, %s, %s, %s, 1)',
           v_a, bu1, d_it, e_bu1, j_arch, d_it),
    '23503', 'Direct insert: Architect in the IT Department');

  perform pg_temp.expect_error(
    format('insert into core.position_allocation
              (company_id, org_unit_id, department_id, eligibility_id, job_position_id, pos_unit_id, approved_headcount)
            values (%s, %s, %s, %s, %s, %s, 1)',
           v_a, br1, d_eng, e_br1, j_mgr, d_b),
    'P0001', 'Direct insert: position unit from another company');

  -- ---------- Allocations are never edited ----------
  perform pg_temp.expect_error(
    format('update core.position_allocation set approved_headcount = 9 where id = %s', a2),
    'P0001', 'Editing the headcount of an allocation');

  perform pg_temp.expect_error(
    format('update core.position_allocation set pos_unit_id = %s where id = %s', o_eng, a2),
    'P0001', 'Moving an allocation to another position unit');

  -- ---------- Close and replace (history is kept) ----------
  update core.position_allocation set valid_to = current_date where id = a1;
  a1b := pg_temp.alloc(v_a, br1, j_arch, d_eng, 4);

  select count(*) into v_n from core.position_allocation
  where org_unit_id = br1 and job_position_id = j_arch and pos_unit_id = d_eng;
  if v_n <> 2 then raise exception 'FAIL: expected 2 allocation rows (1 closed, 1 open), found %', v_n; end if;

  select count(*) into v_n from core.position_allocation
  where org_unit_id = br1 and job_position_id = j_arch and pos_unit_id = d_eng and valid_to is null;
  if v_n <> 1 then raise exception 'FAIL: expected exactly 1 open allocation, found %', v_n; end if;

  perform pg_temp.expect_error(
    format('update core.position_allocation set valid_to = null where id = %s', a1),
    'P0001', 'Re-opening a closed allocation');

  -- ---------- A listing cannot be closed while allocations use it ----------
  perform pg_temp.expect_error(
    format('update core.org_unit_department set valid_to = current_date where id = %s', e_br1),
    'P0001', 'Closing a Department listing that open allocations use');

  -- ---------- Closing a job closes its allocations ----------
  update core.job_position set valid_to = current_date where id = j_mgr;

  select count(*) into v_n from core.position_allocation
  where id = a2 and valid_to is not null;
  if v_n <> 1 then raise exception 'FAIL: closing the job did not close its allocation'; end if;

  select count(*) into v_n from core.position_allocation
  where id = a1b and valid_to is null;
  if v_n <> 1 then raise exception 'FAIL: closing one job closed an unrelated allocation'; end if;

  perform pg_temp.expect_error(
    format('select pg_temp.alloc(%s, %s, %s, %s, 1)', v_a, br1, j_mgr, s_eng),
    'P0001', 'New allocation for a closed job');

  -- ---------- Closing a position unit closes allocations placed at it ----------
  update core.pos_unit set valid_to = current_date where id = o_it;
  perform pg_temp.check_now();

  select count(*) into v_n from core.position_allocation
  where id = a3 and valid_to is not null;
  if v_n <> 1 then raise exception 'FAIL: closing the position unit did not close its allocation'; end if;

  perform pg_temp.expect_error(
    format('select pg_temp.alloc(%s, %s, %s, %s, 1)', v_a, bu1, j_dev, o_it),
    'P0001', 'New allocation at a closed position unit');

  -- ---------- Closing an org unit closes its allocations and listings ----------
  update core.org_unit set valid_to = current_date where id = br1;
  perform pg_temp.check_now();

  select count(*) into v_n from core.position_allocation
  where org_unit_id = br1 and valid_to is null;
  if v_n <> 0 then raise exception 'FAIL: % allocations still open for the closed org unit', v_n; end if;

  select count(*) into v_n from core.org_unit_department
  where org_unit_id = br1 and valid_to is null;
  if v_n <> 0 then raise exception 'FAIL: % listings still open for the closed org unit', v_n; end if;

  perform pg_temp.expect_error(
    format('select pg_temp.alloc(%s, %s, %s, %s, 1)', v_a, br1, j_arch, d_eng),
    'P0001', 'New allocation at a closed org unit');

  perform pg_temp.expect_error(
    format('insert into core.position_allocation
              (company_id, org_unit_id, department_id, eligibility_id, job_position_id, pos_unit_id, approved_headcount)
            values (%s, %s, %s, %s, %s, %s, 1)',
           v_a, br1, d_eng, e_br1, j_arch, d_eng),
    'P0001', 'Direct insert: closed eligibility row');

  -- Company B is untouched by everything above
  select count(*) into v_n from core.position_allocation
  where id = a_b and valid_to is null;
  if v_n <> 1 then raise exception 'FAIL: an allocation of company B was closed'; end if;
end $$;

-- ---------------------------------------------------------------
-- Part 2: access control (running as a logged-in user)
-- ---------------------------------------------------------------
set local role authenticated;

do $$
declare
  v_a integer := current_setting('test.company_a')::integer;
  v_b integer := current_setting('test.company_b')::integer;
  v_n integer;
begin
  -- ---------- User A ----------
  perform set_config('request.jwt.claims',
    '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","role":"authenticated"}', true);

  select count(*) into v_n from core.position_allocation where company_id = v_a;
  if v_n = 0 then raise exception 'FAIL: user A cannot see own allocations'; end if;

  select count(*) into v_n from core.position_allocation where company_id <> v_a;
  if v_n <> 0 then raise exception 'FAIL: user A sees % allocations of other companies', v_n; end if;

  begin
    insert into core.position_allocation
      (company_id, org_unit_id, department_id, eligibility_id, job_position_id, pos_unit_id, approved_headcount)
    values (v_a, 1, 1, 1, 1, 1, 1);
    raise exception 'FAIL: user A was able to insert an allocation';
  exception when insufficient_privilege then
    null;
  end;

  begin
    perform private.create_allocation(v_a, 1, 1, 1, 1);
    raise exception 'FAIL: user A was able to call create_allocation';
  exception when insufficient_privilege then
    null;
  end;

  -- ---------- User B ----------
  perform set_config('request.jwt.claims',
    '{"sub":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb","role":"authenticated"}', true);

  select count(*) into v_n from core.position_allocation where company_id = v_a;
  if v_n <> 0 then raise exception 'FAIL: user B sees % allocations of company A', v_n; end if;

  select count(*) into v_n from core.position_allocation where company_id = v_b;
  if v_n = 0 then raise exception 'FAIL: user B cannot see own allocations'; end if;
end $$;

rollback;

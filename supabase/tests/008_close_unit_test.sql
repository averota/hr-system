-- Test for 008_close_unit.sql
-- Run in Supabase Dashboard -> SQL Editor (dev project only).
-- Everything is rolled back at the end; nothing is saved.
--
-- PASS = "Success. No rows returned"
-- FAIL = an error message that starts with FAIL
--
-- Only the new functions are tested. The cascade itself belongs to the guards
-- from 003 to 006, so it is checked here only through the function.

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
-- Fixtures: two tenants, one company each
-- ---------------------------------------------------------------
insert into core.tenant (name_en) values ('Tenant A'), ('Tenant B');
insert into core.parent_company (tenant_id, name_en)
select id, 'Company ' || right(name_en, 1) from core.tenant;

-- ---------------------------------------------------------------
-- Part 1: behaviour (running as admin)
-- ---------------------------------------------------------------
do $$
declare
  v_a  integer;
  v_b  integer;
  bu1  integer;
  br1  integer;
  br2  integer;
  d1   integer;
  o1   integer;
  j1   integer;
  a1   integer;
  a2   integer;
  a3   integer;
  v_n  integer;
begin
  select id into v_a from core.parent_company where name_en = 'Company A';
  select id into v_b from core.parent_company where name_en = 'Company B';

  perform pg_temp.add_rule(v_a, 'business_unit', null);
  perform pg_temp.add_rule(v_a, 'branch',        'business_unit');
  perform pg_temp.add_rule(v_a, 'department',    null);
  perform pg_temp.add_rule(v_a, 'office',        'department');

  bu1 := pg_temp.mk_org(v_a, 'business_unit', null, 'BU 1');
  br1 := pg_temp.mk_org(v_a, 'branch',        bu1,  'Branch 1');
  br2 := pg_temp.mk_org(v_a, 'branch',        bu1,  'Branch 2');
  d1  := pg_temp.mk_pos(v_a, 'department',    null, 'Dept 1');
  o1  := pg_temp.mk_pos(v_a, 'office',        d1,   'Office 1');

  insert into core.job_position (company_id, department_id, name_en) values (v_a, d1, 'Job 1');
  select id into j1 from core.job_position where company_id = v_a and name_en = 'Job 1';

  insert into core.org_unit_department (company_id, org_unit_id, department_id) values
    (v_a, br1, d1),
    (v_a, br2, d1);

  a1 := private.create_allocation(v_a, br1, j1, d1, 2);   -- Branch 1, at the Department
  a2 := private.create_allocation(v_a, br2, j1, d1, 2);   -- Branch 2, at the Department
  a3 := private.create_allocation(v_a, br2, j1, o1, 1);   -- Branch 2, at Office 1

  -- ---------- Refusals ----------
  perform pg_temp.expect_error(
    format('select private.close_org_unit(%s, %s)', v_a, bu1),
    'P0001', 'Closing an org unit that still has open units under it');

  perform pg_temp.expect_error(
    format('select private.close_org_unit(%s, %s)', v_b, br1),
    'P0001', 'Closing an org unit using another company id');

  perform pg_temp.expect_error(
    format('select private.close_org_unit(%s, %s, current_date - 1)', v_a, br1),
    'P0001', 'Close date earlier than the unit start date');

  perform pg_temp.expect_error(
    format('select private.close_pos_unit(%s, %s)', v_a, d1),
    'P0001', 'Closing a Department that still has open units under it');

  perform pg_temp.expect_error(
    format('select private.close_pos_unit(%s, %s)', v_b, o1),
    'P0001', 'Closing a position unit using another company id');

  -- ---------- Close an org unit ----------
  perform private.close_org_unit(v_a, br1);
  perform pg_temp.check_now();

  select count(*) into v_n from core.org_unit where id = br1 and valid_to is not null;
  if v_n <> 1 then raise exception 'FAIL: org unit was not closed'; end if;

  select count(*) into v_n from core.org_unit_parent where unit_id = br1 and valid_to is null;
  if v_n <> 0 then raise exception 'FAIL: parent link of the closed org unit is still open'; end if;

  select count(*) into v_n from core.position_allocation where id = a1 and valid_to is null;
  if v_n <> 0 then raise exception 'FAIL: allocation of the closed org unit is still open'; end if;

  select count(*) into v_n from core.position_allocation where id in (a2, a3) and valid_to is null;
  if v_n <> 2 then raise exception 'FAIL: closing Branch 1 closed allocations of Branch 2'; end if;

  perform pg_temp.expect_error(
    format('select private.close_org_unit(%s, %s)', v_a, br1),
    'P0001', 'Closing an org unit that is already closed');

  -- ---------- Close a position unit ----------
  perform private.close_pos_unit(v_a, o1);
  perform pg_temp.check_now();

  select count(*) into v_n from core.pos_unit where id = o1 and valid_to is not null;
  if v_n <> 1 then raise exception 'FAIL: position unit was not closed'; end if;

  select count(*) into v_n from core.position_allocation where id = a3 and valid_to is null;
  if v_n <> 0 then raise exception 'FAIL: allocation placed at the closed position unit is still open'; end if;

  select count(*) into v_n from core.position_allocation where id = a2 and valid_to is null;
  if v_n <> 1 then raise exception 'FAIL: closing Office 1 closed an unrelated allocation'; end if;

  -- The Department still has an open job position
  perform pg_temp.expect_error(
    format('select private.close_pos_unit(%s, %s)', v_a, d1),
    'P0001', 'Closing a Department that still has an open job position');
end $$;

-- ---------------------------------------------------------------
-- Part 2: not callable by logged-in users
-- ---------------------------------------------------------------
set local role authenticated;

do $$
begin
  begin
    perform private.close_org_unit(1, 1);
    raise exception 'FAIL: a logged-in user was able to call close_org_unit';
  exception when insufficient_privilege then
    null;
  end;

  begin
    perform private.close_pos_unit(1, 1);
    raise exception 'FAIL: a logged-in user was able to call close_pos_unit';
  exception when insufficient_privilege then
    null;
  end;
end $$;

rollback;

-- Test for 005_jobs_and_eligibility.sql
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
-- Part 1: job positions and eligibility (running as admin)
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
  o1 integer;
  d_b integer;
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
  perform pg_temp.add_rule(v_b, 'business_unit', null);
  perform pg_temp.add_rule(v_b, 'department',    null);

  -- Units
  bu1   := pg_temp.mk_org(v_a, 'business_unit', null, 'BU 1');
  br1   := pg_temp.mk_org(v_a, 'branch',        bu1,  'Branch 1');
  bu_b  := pg_temp.mk_org(v_b, 'business_unit', null, 'BU B');
  d_eng := pg_temp.mk_pos(v_a, 'department',    null, 'Engineering');
  d_it  := pg_temp.mk_pos(v_a, 'department',    null, 'IT');
  o1    := pg_temp.mk_pos(v_a, 'office',        d_eng, 'Office 1');
  d_b   := pg_temp.mk_pos(v_b, 'department',    null, 'Dept B');

  -- ---------- Valid job positions ("Manager" may exist in two Departments) ----------
  insert into core.job_position (company_id, department_id, name_en) values
    (v_a, d_eng, 'Architect'),
    (v_a, d_eng, 'Manager'),
    (v_a, d_it,  'Developer'),
    (v_a, d_it,  'Manager'),
    (v_b, d_b,   'B Analyst');

  select count(*) into v_n from core.job_position where company_id = v_a and valid_to is null;
  if v_n <> 4 then raise exception 'FAIL: company A has % open job positions, expected 4', v_n; end if;

  -- ---------- Valid eligibility ----------
  insert into core.org_unit_department (company_id, org_unit_id, department_id) values
    (v_a, br1,  d_eng),
    (v_a, bu1,  d_it),
    (v_b, bu_b, d_b);

  select count(*) into v_n from core.org_unit_department where company_id = v_a and valid_to is null;
  if v_n <> 2 then raise exception 'FAIL: company A has % open eligibility rows, expected 2', v_n; end if;

  -- ---------- Invalid job positions ----------
  perform pg_temp.expect_error(
    format('insert into core.job_position (company_id, department_id, name_en) values (%s, %s, %L)',
           v_a, o1, 'x'),
    'P0001', 'Job position under an Office (not a Department)');

  perform pg_temp.expect_error(
    format('insert into core.job_position (company_id, department_id, name_en) values (%s, %s, %L)',
           v_b, d_eng, 'x'),
    '23503', 'Job position in a Department of another company');

  perform pg_temp.expect_error(
    format('insert into core.job_position (company_id, department_id, name_en) values (%s, %s, %L)',
           v_a, d_eng, 'Architect'),
    '23505', 'Duplicate open title in the same Department');

  perform pg_temp.expect_error(
    format('update core.job_position set department_id = %s
            where company_id = %s and name_en = %L and department_id = %s',
           d_it, v_a, 'Architect', d_eng),
    'P0001', 'Moving a job position to another Department');

  perform pg_temp.expect_error(
    format('update core.pos_unit set valid_to = current_date where id = %s', d_it),
    'P0001', 'Closing a Department that still has open job positions');

  -- ---------- Invalid eligibility ----------
  perform pg_temp.expect_error(
    format('insert into core.org_unit_department (company_id, org_unit_id, department_id)
            values (%s, %s, %s)', v_a, br1, o1),
    'P0001', 'Listing an Office (not a Department) for an org unit');

  perform pg_temp.expect_error(
    format('insert into core.org_unit_department (company_id, org_unit_id, department_id)
            values (%s, %s, %s)', v_b, bu_b, d_eng),
    '23503', 'Department of another company');

  perform pg_temp.expect_error(
    format('insert into core.org_unit_department (company_id, org_unit_id, department_id)
            values (%s, %s, %s)', v_a, bu_b, d_eng),
    '23503', 'Org unit of another company');

  perform pg_temp.expect_error(
    format('insert into core.org_unit_department (company_id, org_unit_id, department_id)
            values (%s, %s, %s)', v_a, br1, d_eng),
    '23505', 'Duplicate open eligibility row');

  perform pg_temp.expect_error(
    format('update core.org_unit_department set department_id = %s where org_unit_id = %s',
           d_it, br1),
    'P0001', 'Editing an eligibility row');

  -- ---------- Close and re-list a Department (history is kept) ----------
  update core.org_unit_department
  set valid_to = current_date
  where org_unit_id = br1 and department_id = d_eng and valid_to is null;

  insert into core.org_unit_department (company_id, org_unit_id, department_id)
  values (v_a, br1, d_eng);

  select count(*) into v_n from core.org_unit_department
  where org_unit_id = br1 and department_id = d_eng;
  if v_n <> 2 then raise exception 'FAIL: expected 2 eligibility rows (1 closed, 1 open), found %', v_n; end if;

  select count(*) into v_n from core.org_unit_department
  where org_unit_id = br1 and department_id = d_eng and valid_to is null;
  if v_n <> 1 then raise exception 'FAIL: expected exactly 1 open eligibility row, found %', v_n; end if;

  -- ---------- Closing a Department: titles first, eligibility closes with it ----------
  update core.job_position set valid_to = current_date
  where department_id = d_it and valid_to is null;

  update core.pos_unit set valid_to = current_date where id = d_it;
  perform pg_temp.check_now();

  select count(*) into v_n from core.org_unit_department
  where department_id = d_it and valid_to is null;
  if v_n <> 0 then raise exception 'FAIL: % eligibility rows still open for the closed Department', v_n; end if;

  perform pg_temp.expect_error(
    format('insert into core.job_position (company_id, department_id, name_en) values (%s, %s, %L)',
           v_a, d_it, 'New title'),
    'P0001', 'New job position in a closed Department');

  -- ---------- Closing an org unit: its eligibility closes with it ----------
  update core.org_unit set valid_to = current_date where id = br1;
  perform pg_temp.check_now();

  select count(*) into v_n from core.org_unit_department
  where org_unit_id = br1 and valid_to is null;
  if v_n <> 0 then raise exception 'FAIL: % eligibility rows still open for the closed org unit', v_n; end if;

  perform pg_temp.expect_error(
    format('insert into core.org_unit_department (company_id, org_unit_id, department_id)
            values (%s, %s, %s)', v_a, br1, d_eng),
    'P0001', 'Listing a Department for a closed org unit');
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

  select count(*) into v_n from core.job_position where company_id = v_a;
  if v_n = 0 then raise exception 'FAIL: user A cannot see own job positions'; end if;

  select count(*) into v_n from core.job_position where company_id <> v_a;
  if v_n <> 0 then raise exception 'FAIL: user A sees % job positions of other companies', v_n; end if;

  select count(*) into v_n from core.org_unit_department where company_id = v_a;
  if v_n = 0 then raise exception 'FAIL: user A cannot see own eligibility rows'; end if;

  select count(*) into v_n from core.org_unit_department where company_id <> v_a;
  if v_n <> 0 then raise exception 'FAIL: user A sees % eligibility rows of other companies', v_n; end if;

  begin
    insert into core.job_position (company_id, department_id, name_en) values (v_a, 1, 'Hack');
    raise exception 'FAIL: user A was able to insert a job position';
  exception when insufficient_privilege then
    null;
  end;

  begin
    insert into core.org_unit_department (company_id, org_unit_id, department_id) values (v_a, 1, 1);
    raise exception 'FAIL: user A was able to insert an eligibility row';
  exception when insufficient_privilege then
    null;
  end;

  -- ---------- User B ----------
  perform set_config('request.jwt.claims',
    '{"sub":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb","role":"authenticated"}', true);

  select count(*) into v_n from core.job_position where company_id = v_a;
  if v_n <> 0 then raise exception 'FAIL: user B sees % job positions of company A', v_n; end if;

  select count(*) into v_n from core.job_position where company_id = v_b;
  if v_n = 0 then raise exception 'FAIL: user B cannot see own job positions'; end if;
end $$;

rollback;

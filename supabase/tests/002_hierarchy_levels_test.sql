-- Test for 002_hierarchy_levels.sql
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

-- Runs a statement and checks that it fails with the expected SQLSTATE
create function pg_temp.expect_error(p_sql text, p_state text, p_label text)
returns void language plpgsql as $$
declare v_ok boolean := false;
begin
  begin
    execute p_sql;
  exception when others then
    if sqlstate = p_state then
      v_ok := true;
    else
      raise exception 'FAIL: % (expected %, got % - %)', p_label, p_state, sqlstate, sqlerrm;
    end if;
  end;
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
-- Part 1: rules (running as admin)
-- ---------------------------------------------------------------
do $$
declare
  v_a integer;
  v_b integer;
  v_n integer;
begin
  select id into v_a from core.parent_company where name_en = 'Company A';
  select id into v_b from core.parent_company where name_en = 'Company B';
  perform set_config('test.company_a', v_a::text, true);
  perform set_config('test.company_b', v_b::text, true);

  -- Catalog is seeded
  select count(*) into v_n from core.hierarchy_level;
  if v_n <> 7 then
    raise exception 'FAIL: catalog has % levels, expected 7', v_n;
  end if;

  -- Company A: full org chain + Department -> Office
  perform pg_temp.add_rule(v_a, 'business_unit', null);
  perform pg_temp.add_rule(v_a, 'branch',        'business_unit');
  perform pg_temp.add_rule(v_a, 'division',      'branch');
  perform pg_temp.add_rule(v_a, 'department',    null);
  perform pg_temp.add_rule(v_a, 'office',        'department');

  -- Company B: skips Branch and Office, no placeholder rows
  perform pg_temp.add_rule(v_b, 'business_unit', null);
  perform pg_temp.add_rule(v_b, 'department',    null);

  -- Invalid combinations are rejected
  perform pg_temp.expect_error(
    format('select pg_temp.add_rule(%s, %L, %L)', v_a, 'division', 'department'),
    '23503', 'Division under a Department (wrong tree)');

  perform pg_temp.expect_error(
    format('select pg_temp.add_rule(%s, %L, %L)', v_a, 'branch', 'division'),
    '23514', 'Branch under Division (parent ranked lower than child)');

  perform pg_temp.expect_error(
    format('select pg_temp.add_rule(%s, %L, %L)', v_a, 'office', null),
    'P0001', 'Office directly under the root');

  perform pg_temp.expect_error(
    format('select pg_temp.add_rule(%s, %L, %L)', v_a, 'business_unit', null),
    '23505', 'Duplicate open rule');

  perform pg_temp.expect_error(
    format('select pg_temp.add_rule(%s, %L, %L)', v_b, 'division', 'branch'),
    'P0001', 'Division under Branch while Branch is not enabled');

  -- Skipping a level works: Division directly under Business Unit,
  -- Section directly under Department
  perform pg_temp.add_rule(v_b, 'division', 'business_unit');
  perform pg_temp.add_rule(v_b, 'section',  'department');

  select count(*) into v_n
  from core.company_level_rule
  where company_id = v_b and valid_to is null;
  if v_n <> 4 then
    raise exception 'FAIL: company B has % open rules, expected 4', v_n;
  end if;

  -- Rules cannot be edited
  perform pg_temp.expect_error(
    format('update core.company_level_rule set parent_level_id = pg_temp.lvl(%L)
            where company_id = %s and level_id = pg_temp.lvl(%L)',
           'business_unit', v_a, 'department'),
    'P0001', 'Editing an existing rule');

  -- A required level cannot be disabled
  perform pg_temp.expect_error(
    format('update core.company_level_rule set valid_to = current_date
            where company_id = %s and level_id = pg_temp.lvl(%L)',
           v_a, 'department'),
    'P0001', 'Disabling the required Department level');

  -- A level still used as a parent cannot be disabled
  perform pg_temp.expect_error(
    format('update core.company_level_rule set valid_to = current_date
            where company_id = %s and level_id = pg_temp.lvl(%L)',
           v_a, 'branch'),
    'P0001', 'Disabling Branch while Division still sits under it');

  -- Correct order works: close Division first, then Branch
  update core.company_level_rule set valid_to = current_date
  where company_id = v_a and level_id = pg_temp.lvl('division') and valid_to is null;

  update core.company_level_rule set valid_to = current_date
  where company_id = v_a and level_id = pg_temp.lvl('branch') and valid_to is null;

  select count(*) into v_n
  from core.company_level_rule
  where company_id = v_a and valid_to is null;
  if v_n <> 3 then
    raise exception 'FAIL: company A has % open rules after closing two, expected 3', v_n;
  end if;
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

  select count(*) into v_n from core.hierarchy_level;
  if v_n <> 7 then
    raise exception 'FAIL: user A sees % catalog levels, expected 7', v_n;
  end if;

  select count(*) into v_n from core.company_level_rule where company_id = v_a;
  if v_n = 0 then
    raise exception 'FAIL: user A cannot see own company rules';
  end if;

  select count(*) into v_n from core.company_level_rule where company_id <> v_a;
  if v_n <> 0 then
    raise exception 'FAIL: user A sees % rules of other companies', v_n;
  end if;

  begin
    perform pg_temp.add_rule(v_a, 'group', 'office');
    raise exception 'FAIL: user A was able to insert a rule';
  exception when insufficient_privilege then
    null;
  end;

  -- ---------- User B ----------
  perform set_config('request.jwt.claims',
    '{"sub":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb","role":"authenticated"}', true);

  select count(*) into v_n from core.company_level_rule where company_id = v_a;
  if v_n <> 0 then
    raise exception 'FAIL: user B sees % rules of company A', v_n;
  end if;

  select count(*) into v_n from core.company_level_rule where company_id = v_b;
  if v_n = 0 then
    raise exception 'FAIL: user B cannot see own company rules';
  end if;
end $$;

rollback;

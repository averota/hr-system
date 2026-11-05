-- Test for 003_org_tree.sql
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

create function pg_temp.rule_id(p_company integer, p_level text, p_parent text)
returns integer language sql as $$
  select id from core.company_level_rule
  where company_id = p_company
    and level_id = pg_temp.lvl(p_level)
    and parent_level_key = coalesce(pg_temp.lvl(p_parent), 0)
    and valid_to is null
$$;

-- Forces the deferred "unit must have an open link" check to run now
create function pg_temp.check_now() returns void language plpgsql as $$
begin
  execute 'set constraints all immediate';
  execute 'set constraints all deferred';
end $$;

create function pg_temp.mk(p_company integer, p_level text, p_parent integer, p_name text)
returns integer language plpgsql as $$
declare v_id integer;
begin
  v_id := private.create_org_unit(p_company, pg_temp.lvl(p_level), p_parent, p_name, null);
  perform pg_temp.check_now();
  return v_id;
end $$;

-- Bypasses create_org_unit to prove the database itself rejects bad data
create function pg_temp.raw_unit_with_link(
  p_company integer, p_level text, p_parent integer, p_parent_level text, p_rule integer)
returns void language plpgsql as $$
declare v_unit integer;
begin
  insert into core.org_unit (company_id, level_id, name_en)
  values (p_company, pg_temp.lvl(p_level), 'raw')
  returning id into v_unit;

  insert into core.org_unit_parent
    (company_id, unit_id, level_id, parent_unit_id, parent_level_id, rule_id)
  values
    (p_company, v_unit, pg_temp.lvl(p_level), p_parent,
     case when p_parent_level is null then null else pg_temp.lvl(p_parent_level) end,
     p_rule);
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
-- Part 1: org tree behaviour (running as admin)
-- ---------------------------------------------------------------
do $$
declare
  v_a integer;
  v_b integer;
  bu1 integer;
  br1 integer;
  dv1 integer;
  dv2 integer;
  bu_b integer;
  dv_b integer;
  v_n integer;
begin
  select id into v_a from core.parent_company where name_en = 'Company A';
  select id into v_b from core.parent_company where name_en = 'Company B';
  perform set_config('test.company_a', v_a::text, true);
  perform set_config('test.company_b', v_b::text, true);

  -- Rules. Company A: Division may sit under a Branch or directly under a BU.
  -- Company B: no Branch level at all.
  perform pg_temp.add_rule(v_a, 'business_unit', null);
  perform pg_temp.add_rule(v_a, 'branch',        'business_unit');
  perform pg_temp.add_rule(v_a, 'division',      'branch');
  perform pg_temp.add_rule(v_a, 'division',      'business_unit');
  perform pg_temp.add_rule(v_b, 'business_unit', null);
  perform pg_temp.add_rule(v_b, 'division',      'business_unit');

  -- Valid trees (no placeholder rows anywhere)
  bu1  := pg_temp.mk(v_a, 'business_unit', null, 'BU 1');
  br1  := pg_temp.mk(v_a, 'branch',        bu1,  'Branch 1');
  dv1  := pg_temp.mk(v_a, 'division',      br1,  'Division 1');
  dv2  := pg_temp.mk(v_a, 'division',      bu1,  'Division 2 (directly under BU)');
  bu_b := pg_temp.mk(v_b, 'business_unit', null, 'BU B');
  dv_b := pg_temp.mk(v_b, 'division',      bu_b, 'Division B (company has no Branch level)');

  select count(*) into v_n from core.org_unit where company_id = v_a;
  if v_n <> 4 then raise exception 'FAIL: company A has % units, expected 4', v_n; end if;

  select count(*) into v_n from core.org_unit_parent where company_id = v_a and valid_to is null;
  if v_n <> 4 then raise exception 'FAIL: company A has % open links, expected 4', v_n; end if;

  select count(*) into v_n from core.org_unit where company_id = v_b;
  if v_n <> 2 then raise exception 'FAIL: company B has % units, expected 2', v_n; end if;

  -- ---------- Invalid structures through the create function ----------
  perform pg_temp.expect_error(
    format('select pg_temp.mk(%s, %L, %s, %L)', v_a, 'branch', dv1, 'x'),
    'P0001', 'Branch under a Division');

  perform pg_temp.expect_error(
    format('select pg_temp.mk(%s, %L, %s, %L)', v_b, 'branch', bu_b, 'x'),
    'P0001', 'Branch in a company that has not enabled the Branch level');

  perform pg_temp.expect_error(
    format('select pg_temp.mk(%s, %L, %s, %L)', v_b, 'division', br1, 'x'),
    'P0001', 'Parent unit belonging to another company');

  -- ---------- Invalid data inserted directly (database-level protection) ----------
  perform pg_temp.expect_error(
    format('select pg_temp.raw_unit_with_link(%s, %L, %s, %L, %s)',
           v_b, 'division', br1, 'branch', pg_temp.rule_id(v_b, 'division', 'business_unit')),
    '23503', 'Direct insert: parent from another company');

  perform pg_temp.expect_error(
    format('select pg_temp.raw_unit_with_link(%s, %L, %s, %L, %s)',
           v_a, 'division', bu1, 'business_unit', pg_temp.rule_id(v_a, 'division', 'branch')),
    '23503', 'Direct insert: rule does not match the parent level');

  perform pg_temp.expect_error(
    format('select pg_temp.raw_unit_with_link(%s, %L, %s, %L, %s)',
           v_a, 'division', bu1, 'branch', pg_temp.rule_id(v_a, 'division', 'branch')),
    '23503', 'Direct insert: parent unit is not at the stated level');

  perform pg_temp.expect_error(
    format('select pg_temp.raw_unit_with_link(%s, %L, %s, %L, %s)',
           v_b, 'branch', bu_b, 'business_unit', pg_temp.rule_id(v_b, 'division', 'business_unit')),
    'P0001', 'Direct insert: level not enabled for the company');

  perform pg_temp.expect_error(
    format('insert into core.org_unit (company_id, level_id, name_en)
            values (%s, pg_temp.lvl(%L), %L)', v_a, 'business_unit', 'Orphan'),
    'P0001', 'Unit without a parent link');

  perform pg_temp.expect_error(
    format('insert into core.org_unit_parent
              (company_id, unit_id, level_id, parent_unit_id, parent_level_id, rule_id)
            values (%s, %s, pg_temp.lvl(%L), %s, pg_temp.lvl(%L), %s)',
           v_a, dv2, 'division', bu1, 'business_unit',
           pg_temp.rule_id(v_a, 'division', 'business_unit')),
    '23505', 'Second open link for the same unit');

  perform pg_temp.expect_error(
    format('update core.org_unit set level_id = pg_temp.lvl(%L) where id = %s', 'branch', dv1),
    'P0001', 'Changing the level of an existing unit');

  perform pg_temp.expect_error(
    format('update core.org_unit set valid_to = current_date where id = %s', br1),
    'P0001', 'Closing a unit that still has units under it');

  -- ---------- Reorg: move Division 2 from under the BU to under Branch 1 ----------
  update core.org_unit_parent
  set valid_to = current_date
  where unit_id = dv2 and valid_to is null;

  insert into core.org_unit_parent
    (company_id, unit_id, level_id, parent_unit_id, parent_level_id, rule_id)
  values
    (v_a, dv2, pg_temp.lvl('division'), br1, pg_temp.lvl('branch'),
     pg_temp.rule_id(v_a, 'division', 'branch'));

  perform pg_temp.check_now();

  select count(*) into v_n from core.org_unit_parent where unit_id = dv2;
  if v_n <> 2 then raise exception 'FAIL: Division 2 has % links, expected 2 (history kept)', v_n; end if;

  select count(*) into v_n from core.org_unit_parent
  where unit_id = dv2 and valid_to is null and parent_unit_id = br1;
  if v_n <> 1 then raise exception 'FAIL: Division 2 is not open under Branch 1 after the reorg'; end if;

  -- ---------- Changing a rule does not touch existing links ----------
  update core.company_level_rule
  set valid_to = current_date
  where id = pg_temp.rule_id(v_a, 'division', 'branch');

  select count(*) into v_n from core.org_unit_parent
  where unit_id in (dv1, dv2) and valid_to is null;
  if v_n <> 2 then raise exception 'FAIL: closing a rule changed % existing links', 2 - v_n; end if;

  perform pg_temp.expect_error(
    format('select pg_temp.mk(%s, %L, %s, %L)', v_a, 'division', br1, 'x'),
    'P0001', 'New Division under Branch after that rule was closed');

  -- ---------- Closing units: children first, links close with their unit ----------
  update core.org_unit set valid_to = current_date where id in (dv1, dv2);
  update core.org_unit set valid_to = current_date where id = br1;
  perform pg_temp.check_now();

  select count(*) into v_n from core.org_unit_parent
  where company_id = v_a and valid_to is null;
  if v_n <> 1 then raise exception 'FAIL: company A has % open links after closing, expected 1', v_n; end if;
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

  select count(*) into v_n from core.org_unit where company_id = v_a;
  if v_n = 0 then raise exception 'FAIL: user A cannot see own units'; end if;

  select count(*) into v_n from core.org_unit where company_id <> v_a;
  if v_n <> 0 then raise exception 'FAIL: user A sees % units of other companies', v_n; end if;

  select count(*) into v_n from core.org_unit_parent where company_id <> v_a;
  if v_n <> 0 then raise exception 'FAIL: user A sees % links of other companies', v_n; end if;

  begin
    insert into core.org_unit (company_id, level_id, name_en) values (v_a, 1, 'Hack');
    raise exception 'FAIL: user A was able to insert a unit';
  exception when insufficient_privilege then
    null;
  end;

  begin
    perform private.create_org_unit(v_a, 1, null, 'Hack', null);
    raise exception 'FAIL: user A was able to call create_org_unit';
  exception when insufficient_privilege then
    null;
  end;

  -- ---------- User B ----------
  perform set_config('request.jwt.claims',
    '{"sub":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb","role":"authenticated"}', true);

  select count(*) into v_n from core.org_unit where company_id = v_a;
  if v_n <> 0 then raise exception 'FAIL: user B sees % units of company A', v_n; end if;

  select count(*) into v_n from core.org_unit where company_id = v_b;
  if v_n = 0 then raise exception 'FAIL: user B cannot see own units'; end if;
end $$;

rollback;

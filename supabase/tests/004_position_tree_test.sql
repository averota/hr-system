-- Test for 004_position_tree.sql
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
  v_id := private.create_pos_unit(p_company, pg_temp.lvl(p_level), p_parent, p_name, null);
  perform pg_temp.check_now();
  return v_id;
end $$;

-- Bypasses create_pos_unit to prove the database itself rejects bad data
create function pg_temp.raw_unit_with_link(
  p_company integer, p_level text, p_parent integer, p_parent_level text, p_rule integer)
returns void language plpgsql as $$
declare v_unit integer;
begin
  insert into core.pos_unit (company_id, level_id, name_en)
  values (p_company, pg_temp.lvl(p_level), 'raw')
  returning id into v_unit;

  insert into core.pos_unit_parent
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
-- Part 1: position tree behaviour (running as admin)
-- ---------------------------------------------------------------
do $$
declare
  v_a integer;
  v_b integer;
  d1 integer;
  o1 integer;
  s1 integer;
  s2 integer;
  g1 integer;
  d_b integer;
  s_b integer;
  v_n integer;
begin
  select id into v_a from core.parent_company where name_en = 'Company A';
  select id into v_b from core.parent_company where name_en = 'Company B';
  perform set_config('test.company_a', v_a::text, true);
  perform set_config('test.company_b', v_b::text, true);

  -- Rules. Company A: Section may sit under an Office or directly under a Department.
  -- Company B: no Office and no Group.
  perform pg_temp.add_rule(v_a, 'department', null);
  perform pg_temp.add_rule(v_a, 'office',     'department');
  perform pg_temp.add_rule(v_a, 'section',    'office');
  perform pg_temp.add_rule(v_a, 'section',    'department');
  perform pg_temp.add_rule(v_a, 'group',      'section');
  perform pg_temp.add_rule(v_a, 'business_unit', null);   -- org level, used for one negative test
  perform pg_temp.add_rule(v_b, 'department', null);
  perform pg_temp.add_rule(v_b, 'section',    'department');

  -- Valid trees (no placeholder rows anywhere)
  d1  := pg_temp.mk(v_a, 'department', null, 'Dept 1');
  o1  := pg_temp.mk(v_a, 'office',     d1,   'Office 1');
  s1  := pg_temp.mk(v_a, 'section',    o1,   'Section 1');
  s2  := pg_temp.mk(v_a, 'section',    d1,   'Section 2 (directly under Department)');
  g1  := pg_temp.mk(v_a, 'group',      s1,   'Group 1');
  d_b := pg_temp.mk(v_b, 'department', null, 'Dept B');
  s_b := pg_temp.mk(v_b, 'section',    d_b,  'Section B (company has no Office level)');

  select count(*) into v_n from core.pos_unit where company_id = v_a;
  if v_n <> 5 then raise exception 'FAIL: company A has % units, expected 5', v_n; end if;

  select count(*) into v_n from core.pos_unit_parent where company_id = v_a and valid_to is null;
  if v_n <> 5 then raise exception 'FAIL: company A has % open links, expected 5', v_n; end if;

  select count(*) into v_n from core.pos_unit where company_id = v_b;
  if v_n <> 2 then raise exception 'FAIL: company B has % units, expected 2', v_n; end if;

  -- ---------- Invalid structures through the create function ----------
  perform pg_temp.expect_error(
    format('select pg_temp.mk(%s, %L, %s, %L)', v_a, 'office', s1, 'x'),
    'P0001', 'Office under a Section');

  perform pg_temp.expect_error(
    format('select pg_temp.mk(%s, %L, %L, %L)', v_a, 'office', null, 'x'),
    'P0001', 'Office at the top of the tree');

  perform pg_temp.expect_error(
    format('select pg_temp.mk(%s, %L, %s, %L)', v_b, 'group', s_b, 'x'),
    'P0001', 'Group in a company that has not enabled the Group level');

  perform pg_temp.expect_error(
    format('select pg_temp.mk(%s, %L, %s, %L)', v_b, 'section', o1, 'x'),
    'P0001', 'Parent unit belonging to another company');

  -- ---------- Invalid data inserted directly (database-level protection) ----------
  perform pg_temp.expect_error(
    format('select pg_temp.raw_unit_with_link(%s, %L, %s, %L, %s)',
           v_b, 'section', d1, 'department', pg_temp.rule_id(v_b, 'section', 'department')),
    '23503', 'Direct insert: parent from another company');

  perform pg_temp.expect_error(
    format('select pg_temp.raw_unit_with_link(%s, %L, %s, %L, %s)',
           v_a, 'section', d1, 'department', pg_temp.rule_id(v_a, 'section', 'office')),
    '23503', 'Direct insert: rule does not match the parent level');

  perform pg_temp.expect_error(
    format('select pg_temp.raw_unit_with_link(%s, %L, %s, %L, %s)',
           v_a, 'section', d1, 'office', pg_temp.rule_id(v_a, 'section', 'office')),
    '23503', 'Direct insert: parent unit is not at the stated level');

  perform pg_temp.expect_error(
    format('select pg_temp.raw_unit_with_link(%s, %L, %s, %L, %s)',
           v_b, 'group', s_b, 'section', pg_temp.rule_id(v_b, 'section', 'department')),
    'P0001', 'Direct insert: level not enabled for the company');

  perform pg_temp.expect_error(
    format('insert into core.pos_unit (company_id, level_id, name_en)
            values (%s, pg_temp.lvl(%L), %L)', v_a, 'business_unit', 'Org level in position tree'),
    '23503', 'Org-tree level stored in the position tree');

  perform pg_temp.expect_error(
    format('insert into core.pos_unit (company_id, level_id, name_en)
            values (%s, pg_temp.lvl(%L), %L)', v_a, 'department', 'Orphan'),
    'P0001', 'Unit without a parent link');

  perform pg_temp.expect_error(
    format('insert into core.pos_unit_parent
              (company_id, unit_id, level_id, parent_unit_id, parent_level_id, rule_id)
            values (%s, %s, pg_temp.lvl(%L), %s, pg_temp.lvl(%L), %s)',
           v_a, s2, 'section', d1, 'department',
           pg_temp.rule_id(v_a, 'section', 'department')),
    '23505', 'Second open link for the same unit');

  perform pg_temp.expect_error(
    format('update core.pos_unit set level_id = pg_temp.lvl(%L) where id = %s', 'office', s1),
    'P0001', 'Changing the level of an existing unit');

  perform pg_temp.expect_error(
    format('update core.pos_unit set valid_to = current_date where id = %s', o1),
    'P0001', 'Closing a unit that still has units under it');

  -- ---------- Reorg: move Section 2 from under the Department to under Office 1 ----------
  update core.pos_unit_parent
  set valid_to = current_date
  where unit_id = s2 and valid_to is null;

  insert into core.pos_unit_parent
    (company_id, unit_id, level_id, parent_unit_id, parent_level_id, rule_id)
  values
    (v_a, s2, pg_temp.lvl('section'), o1, pg_temp.lvl('office'),
     pg_temp.rule_id(v_a, 'section', 'office'));

  perform pg_temp.check_now();

  select count(*) into v_n from core.pos_unit_parent where unit_id = s2;
  if v_n <> 2 then raise exception 'FAIL: Section 2 has % links, expected 2 (history kept)', v_n; end if;

  select count(*) into v_n from core.pos_unit_parent
  where unit_id = s2 and valid_to is null and parent_unit_id = o1;
  if v_n <> 1 then raise exception 'FAIL: Section 2 is not open under Office 1 after the reorg'; end if;

  -- ---------- Rule changes ----------
  -- Closing "Section under Office" is allowed: "Section under Department" keeps
  -- the Section level enabled, so the Group rule that needs Section is unaffected.
  update core.company_level_rule
  set valid_to = current_date
  where id = pg_temp.rule_id(v_a, 'section', 'office');

  select count(*) into v_n from core.pos_unit_parent
  where unit_id in (s1, s2) and valid_to is null;
  if v_n <> 2 then raise exception 'FAIL: closing a rule changed existing links'; end if;

  perform pg_temp.expect_error(
    format('select pg_temp.mk(%s, %L, %s, %L)', v_a, 'section', o1, 'x'),
    'P0001', 'New Section under Office after that rule was closed');

  -- Closing the LAST Section rule is blocked while the Group rule needs Section
  perform pg_temp.expect_error(
    format('update core.company_level_rule set valid_to = current_date where id = %s',
           pg_temp.rule_id(v_a, 'section', 'department')),
    'P0001', 'Disabling Section while the Group rule still uses it as parent');

  -- Closing the Group rule is allowed. Existing Group 1 is untouched.
  update core.company_level_rule
  set valid_to = current_date
  where id = pg_temp.rule_id(v_a, 'group', 'section');

  select count(*) into v_n from core.pos_unit_parent
  where unit_id = g1 and valid_to is null;
  if v_n <> 1 then raise exception 'FAIL: closing the Group rule changed the link of Group 1'; end if;

  perform pg_temp.expect_error(
    format('select pg_temp.mk(%s, %L, %s, %L)', v_a, 'group', s1, 'x'),
    'P0001', 'New Group after the Group rule was closed');

  -- ---------- Closing units: children first, links close with their unit ----------
  update core.pos_unit set valid_to = current_date where id = g1;
  update core.pos_unit set valid_to = current_date where id in (s1, s2);
  update core.pos_unit set valid_to = current_date where id = o1;
  perform pg_temp.check_now();

  select count(*) into v_n from core.pos_unit_parent
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

  select count(*) into v_n from core.pos_unit where company_id = v_a;
  if v_n = 0 then raise exception 'FAIL: user A cannot see own units'; end if;

  select count(*) into v_n from core.pos_unit where company_id <> v_a;
  if v_n <> 0 then raise exception 'FAIL: user A sees % units of other companies', v_n; end if;

  select count(*) into v_n from core.pos_unit_parent where company_id <> v_a;
  if v_n <> 0 then raise exception 'FAIL: user A sees % links of other companies', v_n; end if;

  begin
    insert into core.pos_unit (company_id, level_id, name_en) values (v_a, 1, 'Hack');
    raise exception 'FAIL: user A was able to insert a unit';
  exception when insufficient_privilege then
    null;
  end;

  begin
    perform private.create_pos_unit(v_a, 1, null, 'Hack', null);
    raise exception 'FAIL: user A was able to call create_pos_unit';
  exception when insufficient_privilege then
    null;
  end;

  -- ---------- User B ----------
  perform set_config('request.jwt.claims',
    '{"sub":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb","role":"authenticated"}', true);

  select count(*) into v_n from core.pos_unit where company_id = v_a;
  if v_n <> 0 then raise exception 'FAIL: user B sees % units of company A', v_n; end if;

  select count(*) into v_n from core.pos_unit where company_id = v_b;
  if v_n = 0 then raise exception 'FAIL: user B cannot see own units'; end if;
end $$;

rollback;

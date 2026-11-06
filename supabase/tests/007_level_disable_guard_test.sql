-- Test for 007_level_disable_guard.sql
-- Run in Supabase Dashboard -> SQL Editor (dev project only).
-- Everything is rolled back at the end; nothing is saved.
--
-- PASS = "Success. No rows returned"
-- FAIL = an error message that starts with FAIL
--
-- Only the new behaviour is tested: a level cannot be disabled while open
-- units exist at it. Access control is unchanged by 007, so it is not retested.

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

-- Id of the open rule for a level under a given parent level (null = under the root)
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
-- Fixtures: one tenant, one company
-- ---------------------------------------------------------------
insert into core.tenant (name_en) values ('Tenant A');
insert into core.parent_company (tenant_id, name_en)
select id, 'Company A' from core.tenant;

-- ---------------------------------------------------------------
-- Tests (running as admin)
-- ---------------------------------------------------------------
do $$
declare
  v_a      integer;
  bu1      integer;
  br1      integer;
  d1       integer;
  o1       integer;
  s1       integer;
  r_branch integer;
  r_sec_o  integer;
  r_sec_d  integer;
  v_n      integer;
begin
  select id into v_a from core.parent_company where name_en = 'Company A';

  -- Rules. Section has TWO open rules (under Office and directly under Department).
  perform pg_temp.add_rule(v_a, 'business_unit', null);
  perform pg_temp.add_rule(v_a, 'branch',        'business_unit');
  perform pg_temp.add_rule(v_a, 'department',    null);
  perform pg_temp.add_rule(v_a, 'office',        'department');
  perform pg_temp.add_rule(v_a, 'section',       'office');
  perform pg_temp.add_rule(v_a, 'section',       'department');

  r_branch := pg_temp.rule_id(v_a, 'branch',  'business_unit');
  r_sec_o  := pg_temp.rule_id(v_a, 'section', 'office');
  r_sec_d  := pg_temp.rule_id(v_a, 'section', 'department');

  -- Units
  bu1 := pg_temp.mk_org(v_a, 'business_unit', null, 'BU 1');
  br1 := pg_temp.mk_org(v_a, 'branch',        bu1,  'Branch 1');
  d1  := pg_temp.mk_pos(v_a, 'department',    null, 'Dept 1');
  o1  := pg_temp.mk_pos(v_a, 'office',        d1,   'Office 1');
  s1  := pg_temp.mk_pos(v_a, 'section',       o1,   'Section 1');

  -- ---------- Org tree ----------
  perform pg_temp.expect_error(
    format('update core.company_level_rule set valid_to = current_date where id = %s', r_branch),
    'P0001', 'Disabling Branch while an open Branch exists');

  update core.org_unit set valid_to = current_date where id = br1;
  perform pg_temp.check_now();

  update core.company_level_rule set valid_to = current_date where id = r_branch;

  select count(*) into v_n from core.company_level_rule
  where company_id = v_a and level_id = pg_temp.lvl('branch') and valid_to is null;
  if v_n <> 0 then raise exception 'FAIL: Branch still enabled after its unit was closed and the rule closed'; end if;

  -- ---------- Position tree ----------
  -- Another open Section rule remains, so this is not "disabling the level"
  update core.company_level_rule set valid_to = current_date where id = r_sec_o;

  select count(*) into v_n from core.pos_unit where id = s1 and valid_to is null;
  if v_n <> 1 then raise exception 'FAIL: closing one Section rule changed the Section unit'; end if;

  -- Last open Section rule, open Section unit still exists
  perform pg_temp.expect_error(
    format('update core.company_level_rule set valid_to = current_date where id = %s', r_sec_d),
    'P0001', 'Disabling Section while an open Section exists');

  update core.pos_unit set valid_to = current_date where id = s1;
  perform pg_temp.check_now();

  update core.company_level_rule set valid_to = current_date where id = r_sec_d;

  select count(*) into v_n from core.company_level_rule
  where company_id = v_a and level_id = pg_temp.lvl('section') and valid_to is null;
  if v_n <> 0 then raise exception 'FAIL: Section still enabled after its unit was closed and the rules closed'; end if;
end $$;

rollback;

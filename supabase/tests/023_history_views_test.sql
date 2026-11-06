-- 023_history_views_test.sql
-- Test for 023_history_views.sql. Run in the Supabase SQL Editor (dev project only).
-- Needs the dev data: one company with level rules (seed_dev_tenant.sql and
-- seed_dev_org_sample.sql). Rolls back at the end, so nothing is kept.
-- "Success. No rows returned" = pass. An error starting with FAIL: = a check failed.
--
-- Not covered: what a user from another tenant sees. The views use the same
-- security_invoker and row level security pattern as the *_current views (010).

begin;

-- 1. The views hold exactly the closed rows of core, and never an open row
do $$
declare
  v_n integer;
  v_c integer;
begin
  select count(*) into v_n from public.company_level_rules_closed;
  select count(*) into v_c from core.company_level_rule where valid_to is not null;
  if v_n <> v_c then
    raise exception 'FAIL: company_level_rules_closed has % rows, core has %', v_n, v_c;
  end if;

  select count(*) into v_n from public.org_units_closed;
  select count(*) into v_c from core.org_unit where valid_to is not null;
  if v_n <> v_c then
    raise exception 'FAIL: org_units_closed has % rows, core has %', v_n, v_c;
  end if;

  select count(*) into v_n from public.pos_units_closed;
  select count(*) into v_c from core.pos_unit where valid_to is not null;
  if v_n <> v_c then
    raise exception 'FAIL: pos_units_closed has % rows, core has %', v_n, v_c;
  end if;

  if exists (
    select 1
    from public.company_level_rules_current c
    join public.company_level_rules_closed x using (rule_id)
  ) then
    raise exception 'FAIL: a rule is in both the current and the closed view';
  end if;

  if exists (
    select 1 from public.org_units_current c join public.org_units_closed x using (unit_id)
  ) then
    raise exception 'FAIL: an org unit is in both the current and the closed view';
  end if;

  if exists (
    select 1 from public.pos_units_current c join public.pos_units_closed x using (unit_id)
  ) then
    raise exception 'FAIL: a position unit is in both the current and the closed view';
  end if;
end $$;

-- 2. A rule that is enabled and then disabled shows up as closed
do $$
declare
  v_company  integer;
  v_level    integer;
  v_parent   integer;
  v_rule     integer;
  v_row      record;
begin
  select id into v_company from core.parent_company order by id limit 1;
  if v_company is null then
    raise exception 'FAIL: no company in the dev data. Run seed_dev_tenant.sql first';
  end if;

  -- a level / parent level pair that is allowed but not enabled yet
  select l.id, p.id into v_level, v_parent
  from core.hierarchy_level l
  join core.hierarchy_level p on p.tree = l.tree and p.rank < l.rank
  where exists (
          select 1 from core.company_level_rule r
          where r.company_id = v_company and r.level_id = p.id and r.valid_to is null)
    and not exists (
          select 1 from core.company_level_rule r
          where r.company_id = v_company and r.level_id = l.id
            and r.parent_level_id = p.id and r.valid_to is null)
  order by l.id, p.id
  limit 1;

  if v_level is null then
    raise exception 'FAIL: no free level and parent combination to test with';
  end if;

  v_rule := private.enable_level_rule(v_company, v_level, v_parent);

  if exists (select 1 from public.company_level_rules_closed where rule_id = v_rule) then
    raise exception 'FAIL: an open rule is in the closed view';
  end if;

  perform private.disable_level_rule(v_company, v_rule, current_date);

  select * into v_row from public.company_level_rules_closed where rule_id = v_rule;
  if not found then
    raise exception 'FAIL: the closed rule is not in company_level_rules_closed';
  end if;
  if v_row.valid_to is null
     or v_row.level_id <> v_level
     or v_row.parent_level_id is distinct from v_parent
     or v_row.parent_level_code is null then
    raise exception 'FAIL: the closed rule row has wrong values';
  end if;

  if exists (select 1 from public.company_level_rules_current where rule_id = v_rule) then
    raise exception 'FAIL: the closed rule is still in the current view';
  end if;
end $$;

-- 3. A closed org unit, and a closed child that remembers its parent
do $$
declare
  v_company      integer;
  v_level        integer;
  v_child_level  integer;
  v_unit         integer;
  v_child        integer;
  v_row          record;
begin
  select id into v_company from core.parent_company order by id limit 1;

  select r.level_id into v_level
  from core.company_level_rule r
  where r.company_id = v_company and r.tree = 'org'
    and r.parent_level_id is null and r.valid_to is null
  order by r.id
  limit 1;
  if v_level is null then
    raise exception 'FAIL: no org level is enabled directly under the company';
  end if;

  v_unit := private.create_org_unit(v_company, v_level, null, 'TEST HISTORY ROOT UNIT', null);

  -- optional child, only when a rule allows a level under this one
  select r.level_id into v_child_level
  from core.company_level_rule r
  where r.company_id = v_company and r.tree = 'org'
    and r.parent_level_id = v_level and r.valid_to is null
  order by r.id
  limit 1;

  if v_child_level is not null then
    v_child := private.create_org_unit(v_company, v_child_level, v_unit, 'TEST HISTORY CHILD UNIT', null);
    perform private.close_org_unit(v_company, v_child, current_date);
  end if;

  if exists (select 1 from public.org_units_closed where unit_id = v_unit) then
    raise exception 'FAIL: an open org unit is in the closed view';
  end if;

  perform private.close_org_unit(v_company, v_unit, current_date);

  select * into v_row from public.org_units_closed where unit_id = v_unit;
  if not found then
    raise exception 'FAIL: the closed org unit is not in org_units_closed';
  end if;
  if v_row.valid_to is null
     or v_row.parent_unit_id is not null
     or v_row.parent_name_en is not null
     or v_row.name_en <> 'TEST HISTORY ROOT UNIT'
     or v_row.level_code is null then
    raise exception 'FAIL: the closed root org unit row has wrong values';
  end if;

  if v_child is not null then
    select * into v_row from public.org_units_closed where unit_id = v_child;
    if not found then
      raise exception 'FAIL: the closed child org unit is not in org_units_closed';
    end if;
    if v_row.parent_unit_id is distinct from v_unit
       or v_row.parent_name_en is distinct from 'TEST HISTORY ROOT UNIT' then
      raise exception 'FAIL: the closed child org unit does not show its parent';
    end if;
  end if;

  if exists (select 1 from public.org_units_current where unit_id in (v_unit, coalesce(v_child, 0))) then
    raise exception 'FAIL: a closed org unit is still in the current view';
  end if;
end $$;

-- 4. A closed Department (position tree)
do $$
declare
  v_company  integer;
  v_level    integer;
  v_unit     integer;
  v_row      record;
begin
  select id into v_company from core.parent_company order by id limit 1;

  select r.level_id into v_level
  from core.company_level_rule r
  where r.company_id = v_company and r.tree = 'pos'
    and r.parent_level_id is null and r.valid_to is null
  order by r.id
  limit 1;
  if v_level is null then
    raise exception 'FAIL: no position level is enabled at the top of the position tree';
  end if;

  v_unit := private.create_pos_unit(v_company, v_level, null, 'TEST HISTORY DEPARTMENT', null);
  perform private.close_pos_unit(v_company, v_unit, current_date);

  select * into v_row from public.pos_units_closed where unit_id = v_unit;
  if not found then
    raise exception 'FAIL: the closed Department is not in pos_units_closed';
  end if;
  if v_row.valid_to is null
     or v_row.parent_unit_id is not null
     or v_row.name_en <> 'TEST HISTORY DEPARTMENT' then
    raise exception 'FAIL: the closed Department row has wrong values';
  end if;

  if exists (select 1 from public.pos_units_current where unit_id = v_unit) then
    raise exception 'FAIL: the closed Department is still in the current view';
  end if;
end $$;

-- 5. anon gets nothing
set local role anon;

do $$
begin
  begin
    perform 1 from public.company_level_rules_closed limit 1;
    raise exception 'FAIL: anon can read company_level_rules_closed';
  exception when insufficient_privilege then
    null;
  end;
end $$;

do $$
begin
  begin
    perform 1 from public.org_units_closed limit 1;
    raise exception 'FAIL: anon can read org_units_closed';
  exception when insufficient_privilege then
    null;
  end;
end $$;

do $$
begin
  begin
    perform 1 from public.pos_units_closed limit 1;
    raise exception 'FAIL: anon can read pos_units_closed';
  exception when insufficient_privilege then
    null;
  end;
end $$;

reset role;

rollback;

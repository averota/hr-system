-- 008: close-unit functions (roadmap Stage 6b)
--
-- One controlled way to close an org unit or a position unit.
-- The guards (003 to 006) already do the real work when valid_to is set:
--   * refuse if open child units exist
--   * (Department) refuse if open job positions exist
--   * close the open parent link, allocations and eligibility rows
-- These functions add what the guards cannot:
--   * the unit must be an open unit of the stated company
--   * a close date earlier than any row about to be closed is refused with a
--     clear message (instead of a raw check-constraint error)
--   * the unit row is locked while closing
--
-- p_close_date defaults to today. Not exposed to the frontend yet:
-- service_role only, like the create functions.

-- ---------------------------------------------------------------
-- Org unit
-- ---------------------------------------------------------------
create function private.close_org_unit(
  p_company_id  integer,
  p_unit_id     integer,
  p_close_date  date default current_date
)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_from   date;
  v_latest date;
begin
  select valid_from into v_from
  from core.org_unit
  where id = p_unit_id
    and company_id = p_company_id
    and valid_to is null
  for update;

  if not found then
    raise exception 'Org unit % is not an open unit of this company', p_unit_id;
  end if;

  -- latest start date among the unit and everything that will be closed with it
  select greatest(v_from, max(x.valid_from)) into v_latest
  from (
    select valid_from from core.org_unit_parent
    where unit_id = p_unit_id and valid_to is null
    union all
    select valid_from from core.org_unit_department
    where org_unit_id = p_unit_id and valid_to is null
    union all
    select valid_from from core.position_allocation
    where org_unit_id = p_unit_id and valid_to is null
  ) x;

  if p_close_date < v_latest then
    raise exception 'Close date % is earlier than %, when this unit or something under it started',
      p_close_date, v_latest;
  end if;

  update core.org_unit
  set valid_to = p_close_date
  where id = p_unit_id;
end;
$$;

revoke execute on function private.close_org_unit(integer, integer, date)
  from public, anon, authenticated;
grant execute on function private.close_org_unit(integer, integer, date)
  to service_role;

-- ---------------------------------------------------------------
-- Position unit (Department, Office, Section, Group)
-- ---------------------------------------------------------------
create function private.close_pos_unit(
  p_company_id  integer,
  p_unit_id     integer,
  p_close_date  date default current_date
)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_from   date;
  v_latest date;
begin
  select valid_from into v_from
  from core.pos_unit
  where id = p_unit_id
    and company_id = p_company_id
    and valid_to is null
  for update;

  if not found then
    raise exception 'Position unit % is not an open unit of this company', p_unit_id;
  end if;

  select greatest(v_from, max(x.valid_from)) into v_latest
  from (
    select valid_from from core.pos_unit_parent
    where unit_id = p_unit_id and valid_to is null
    union all
    select valid_from from core.org_unit_department
    where department_id = p_unit_id and valid_to is null
    union all
    select valid_from from core.position_allocation
    where valid_to is null
      and (pos_unit_id = p_unit_id or department_id = p_unit_id)
  ) x;

  if p_close_date < v_latest then
    raise exception 'Close date % is earlier than %, when this unit or something under it started',
      p_close_date, v_latest;
  end if;

  update core.pos_unit
  set valid_to = p_close_date
  where id = p_unit_id;
end;
$$;

revoke execute on function private.close_pos_unit(integer, integer, date)
  from public, anon, authenticated;
grant execute on function private.close_pos_unit(integer, integer, date)
  to service_role;

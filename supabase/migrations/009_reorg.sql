-- 009: reorg functions (roadmap Stage 6c)
--
-- Move a unit under a new parent (or to the root, when a rule allows it).
-- The unit keeps its ID. The open parent link is closed and a new one is opened,
-- so history stays readable. Units under the moved unit stay attached to it.
--
-- Checked by the functions:
--   * the unit is an open unit of the stated company
--   * the new parent is a different, open unit of the same company
--   * an active rule allows this level under the new parent's level
--     (this also makes it impossible to move a unit under itself or under
--      one of its own descendants, because a parent level must rank higher)
--   * the effective date is not earlier than the start of the old link or of
--     the new parent
--
-- Position tree only: a unit (or anything under it) that has open allocations
-- cannot be moved into a different Department's tree, because an allocation's
-- position unit must stay inside its job's Department.
--
-- Dates: the old link ends on the effective date and the new link starts on it.
-- Not exposed to the frontend yet: service_role only.

-- ---------------------------------------------------------------
-- Helper: the Department at the top of a position unit's branch
-- ---------------------------------------------------------------
create function private.pos_department_of(p_unit_id integer)
returns integer
language sql
stable
set search_path = ''
as $$
  with recursive up(unit_id, parent_unit_id) as (
    select p.unit_id, p.parent_unit_id
    from core.pos_unit_parent p
    where p.unit_id = p_unit_id
      and p.valid_to is null
    union all
    select p.unit_id, p.parent_unit_id
    from core.pos_unit_parent p
    join up on p.unit_id = up.parent_unit_id
    where p.valid_to is null
  )
  select unit_id from up where parent_unit_id is null
$$;

revoke execute on function private.pos_department_of(integer)
  from public, anon, authenticated;
grant execute on function private.pos_department_of(integer)
  to service_role;

-- ---------------------------------------------------------------
-- Org unit
-- ---------------------------------------------------------------
create function private.reorg_org_unit(
  p_company_id      integer,
  p_unit_id         integer,
  p_new_parent_id   integer,
  p_effective_date  date default current_date
)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_unit         core.org_unit%rowtype;
  v_old          core.org_unit_parent%rowtype;
  v_parent_level integer;
  v_parent_from  date;
  v_rule_id      integer;
begin
  select * into v_unit
  from core.org_unit
  where id = p_unit_id
    and company_id = p_company_id
    and valid_to is null
  for update;

  if not found then
    raise exception 'Org unit % is not an open unit of this company', p_unit_id;
  end if;

  select * into v_old
  from core.org_unit_parent
  where unit_id = p_unit_id
    and valid_to is null;

  if v_old.parent_unit_id is not distinct from p_new_parent_id then
    raise exception 'The unit is already under this parent';
  end if;

  if p_effective_date < v_old.valid_from then
    raise exception 'Effective date % is earlier than %, when the current parent link started',
      p_effective_date, v_old.valid_from;
  end if;

  if p_new_parent_id is not null then
    select level_id, valid_from into v_parent_level, v_parent_from
    from core.org_unit
    where id = p_new_parent_id
      and company_id = p_company_id
      and valid_to is null;

    if not found then
      raise exception 'New parent % is not an open unit of this company', p_new_parent_id;
    end if;

    if p_effective_date < v_parent_from then
      raise exception 'Effective date % is earlier than %, when the new parent started',
        p_effective_date, v_parent_from;
    end if;
  end if;

  select id into v_rule_id
  from core.company_level_rule
  where company_id = p_company_id
    and level_id = v_unit.level_id
    and parent_level_key = coalesce(v_parent_level, 0)
    and valid_to is null;

  if v_rule_id is null then
    raise exception 'No active rule allows this level under this parent';
  end if;

  update core.org_unit_parent
  set valid_to = p_effective_date
  where id = v_old.id;

  insert into core.org_unit_parent
    (company_id, unit_id, level_id, parent_unit_id, parent_level_id, rule_id, valid_from)
  values
    (p_company_id, p_unit_id, v_unit.level_id, p_new_parent_id, v_parent_level, v_rule_id,
     p_effective_date);
end;
$$;

revoke execute on function private.reorg_org_unit(integer, integer, integer, date)
  from public, anon, authenticated;
grant execute on function private.reorg_org_unit(integer, integer, integer, date)
  to service_role;

-- ---------------------------------------------------------------
-- Position unit (Office, Section, Group). Departments cannot be moved.
-- ---------------------------------------------------------------
create function private.reorg_pos_unit(
  p_company_id      integer,
  p_unit_id         integer,
  p_new_parent_id   integer,
  p_effective_date  date default current_date
)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_unit         core.pos_unit%rowtype;
  v_old          core.pos_unit_parent%rowtype;
  v_parent_level integer;
  v_parent_from  date;
  v_rule_id      integer;
begin
  select * into v_unit
  from core.pos_unit
  where id = p_unit_id
    and company_id = p_company_id
    and valid_to is null
  for update;

  if not found then
    raise exception 'Position unit % is not an open unit of this company', p_unit_id;
  end if;

  select * into v_old
  from core.pos_unit_parent
  where unit_id = p_unit_id
    and valid_to is null;

  if v_old.parent_unit_id is not distinct from p_new_parent_id then
    raise exception 'The unit is already under this parent';
  end if;

  if p_effective_date < v_old.valid_from then
    raise exception 'Effective date % is earlier than %, when the current parent link started',
      p_effective_date, v_old.valid_from;
  end if;

  if p_new_parent_id is not null then
    select level_id, valid_from into v_parent_level, v_parent_from
    from core.pos_unit
    where id = p_new_parent_id
      and company_id = p_company_id
      and valid_to is null;

    if not found then
      raise exception 'New parent % is not an open unit of this company', p_new_parent_id;
    end if;

    if p_effective_date < v_parent_from then
      raise exception 'Effective date % is earlier than %, when the new parent started',
        p_effective_date, v_parent_from;
    end if;
  end if;

  select id into v_rule_id
  from core.company_level_rule
  where company_id = p_company_id
    and level_id = v_unit.level_id
    and parent_level_key = coalesce(v_parent_level, 0)
    and valid_to is null;

  if v_rule_id is null then
    raise exception 'No active rule allows this level under this parent';
  end if;

  -- Moving into another Department's tree: no open allocation may sit at this
  -- unit or anywhere under it
  if private.pos_department_of(p_unit_id)
       is distinct from private.pos_department_of(p_new_parent_id) then
    if exists (
      with recursive down(id) as (
        select p_unit_id
        union all
        select p.unit_id
        from core.pos_unit_parent p
        join down d on p.parent_unit_id = d.id
        where p.valid_to is null
      )
      select 1
      from core.position_allocation a
      join down d on a.pos_unit_id = d.id
      where a.valid_to is null
    ) then
      raise exception 'Open allocations sit at this unit or under it. Close them before moving it to another Department';
    end if;
  end if;

  update core.pos_unit_parent
  set valid_to = p_effective_date
  where id = v_old.id;

  insert into core.pos_unit_parent
    (company_id, unit_id, level_id, parent_unit_id, parent_level_id, rule_id, valid_from)
  values
    (p_company_id, p_unit_id, v_unit.level_id, p_new_parent_id, v_parent_level, v_rule_id,
     p_effective_date);
end;
$$;

revoke execute on function private.reorg_pos_unit(integer, integer, integer, date)
  from public, anon, authenticated;
grant execute on function private.reorg_pos_unit(integer, integer, integer, date)
  to service_role;

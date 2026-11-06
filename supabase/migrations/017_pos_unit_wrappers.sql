-- 017: position unit write wrappers (ORG Stage 9c-4)
--
-- Public write wrappers for position units (Department, Office, Section, Group),
-- callable by logged-in users. Each one checks permission pos.unit.write with
-- private.has_permission, then calls the private write function (004, 008, 009).
-- Needs 016 (private.is_company_member).
--
--   public.create_pos_unit(company, level, parent unit, name EN, name KM)
--       checked at the Department of the parent unit.
--       No parent (a new Department): only a company-wide or tenant-wide role passes.
--   public.close_pos_unit(company, unit, close date)
--       checked at the unit's Department.
--       Closing a Department itself: only a company-wide or tenant-wide role passes
--       (same as creating one).
--   public.reorg_pos_unit(company, unit, new parent, effective date)
--       must pass for the unit being moved AND at the Department of the new parent.
--
-- Helper: private.can_manage_pos_unit(company, unit)
--   true when the caller may change that unit itself (see rules above).
--
-- Errors:
--   no permission (or not a member of the company's tenant):
--       'You do not have permission to manage position units here' (code 42501)
--   a member naming a unit that is not open in this company:
--       'Position unit % is not an open unit of this company'
--       'Parent unit % is not an open unit of this company'
--       'New parent % is not an open unit of this company'
--   blank English name:
--       'The English name is required'
-- Rules, dates and cascades (closing a unit closes the allocations placed at it)
-- are unchanged: they live in the private functions.

-- ---------------------------------------------------------------
-- Helper
-- ---------------------------------------------------------------
create function private.can_manage_pos_unit(
  p_company_id  integer,
  p_unit_id     integer
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_dept integer;
begin
  v_dept := private.pos_department_of(p_unit_id);

  if v_dept is null then
    return false;
  end if;

  -- a Department itself is managed by company-wide or tenant-wide roles only
  if v_dept = p_unit_id then
    return private.has_permission(p_company_id, 'pos.unit.write');
  end if;

  return private.has_permission(p_company_id, 'pos.unit.write', null, v_dept);
end;
$$;

revoke execute on function private.can_manage_pos_unit(integer, integer)
  from public, anon, authenticated;
grant execute on function private.can_manage_pos_unit(integer, integer)
  to service_role;

-- ---------------------------------------------------------------
-- Public wrappers
-- security definer: they read and write core as the function owner, and
-- decide access themselves with private.has_permission (the caller's login).
-- ---------------------------------------------------------------
create function public.create_pos_unit(
  p_company_id      integer,
  p_level_id        integer,
  p_parent_unit_id  integer,
  p_name_en         text,
  p_name_km         text default null
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_parent_unit_id is null then
    -- a new Department
    if not private.has_permission(p_company_id, 'pos.unit.write') then
      raise exception 'You do not have permission to manage position units here'
        using errcode = '42501';
    end if;
  else
    if not exists (
      select 1
      from core.pos_unit u
      where u.id = p_parent_unit_id
        and u.company_id = p_company_id
        and u.valid_to is null
    ) then
      if private.is_company_member(p_company_id) then
        raise exception 'Parent unit % is not an open unit of this company', p_parent_unit_id;
      end if;

      raise exception 'You do not have permission to manage position units here'
        using errcode = '42501';
    end if;

    if not private.has_permission(p_company_id, 'pos.unit.write', null,
                                  private.pos_department_of(p_parent_unit_id)) then
      raise exception 'You do not have permission to manage position units here'
        using errcode = '42501';
    end if;
  end if;

  if p_name_en is null or btrim(p_name_en) = '' then
    raise exception 'The English name is required';
  end if;

  return private.create_pos_unit(
    p_company_id, p_level_id, p_parent_unit_id, p_name_en, p_name_km);
end;
$$;

create function public.close_pos_unit(
  p_company_id  integer,
  p_unit_id     integer,
  p_close_date  date default current_date
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1
    from core.pos_unit u
    where u.id = p_unit_id
      and u.company_id = p_company_id
      and u.valid_to is null
  ) then
    if private.is_company_member(p_company_id) then
      raise exception 'Position unit % is not an open unit of this company', p_unit_id;
    end if;

    raise exception 'You do not have permission to manage position units here'
      using errcode = '42501';
  end if;

  if not private.can_manage_pos_unit(p_company_id, p_unit_id) then
    raise exception 'You do not have permission to manage position units here'
      using errcode = '42501';
  end if;

  perform private.close_pos_unit(p_company_id, p_unit_id, p_close_date);
end;
$$;

create function public.reorg_pos_unit(
  p_company_id      integer,
  p_unit_id         integer,
  p_new_parent_id   integer,
  p_effective_date  date default current_date
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1
    from core.pos_unit u
    where u.id = p_unit_id
      and u.company_id = p_company_id
      and u.valid_to is null
  ) then
    if private.is_company_member(p_company_id) then
      raise exception 'Position unit % is not an open unit of this company', p_unit_id;
    end if;

    raise exception 'You do not have permission to manage position units here'
      using errcode = '42501';
  end if;

  -- the caller must manage the unit being moved
  if not private.can_manage_pos_unit(p_company_id, p_unit_id) then
    raise exception 'You do not have permission to manage position units here'
      using errcode = '42501';
  end if;

  if p_new_parent_id is not null then
    -- the caller is now known to be an authorised member, so a plain message is safe
    if not exists (
      select 1
      from core.pos_unit u
      where u.id = p_new_parent_id
        and u.company_id = p_company_id
        and u.valid_to is null
    ) then
      raise exception 'New parent % is not an open unit of this company', p_new_parent_id;
    end if;

    -- ... and the Department it is moving into
    if not private.has_permission(p_company_id, 'pos.unit.write', null,
                                  private.pos_department_of(p_new_parent_id)) then
      raise exception 'You do not have permission to manage position units here'
        using errcode = '42501';
    end if;
  elsif not private.has_permission(p_company_id, 'pos.unit.write') then
    -- moving to the top of the tree: company-wide or tenant-wide roles only
    raise exception 'You do not have permission to manage position units here'
      using errcode = '42501';
  end if;

  perform private.reorg_pos_unit(p_company_id, p_unit_id, p_new_parent_id, p_effective_date);
end;
$$;

-- ---------------------------------------------------------------
-- Privileges: logged-in users only (Supabase grants new public objects
-- to anon and authenticated by default, so revoke first)
-- ---------------------------------------------------------------
revoke execute on function
  public.create_pos_unit(integer, integer, integer, text, text),
  public.close_pos_unit(integer, integer, date),
  public.reorg_pos_unit(integer, integer, integer, date)
from public, anon, authenticated;

grant execute on function
  public.create_pos_unit(integer, integer, integer, text, text),
  public.close_pos_unit(integer, integer, date),
  public.reorg_pos_unit(integer, integer, integer, date)
to authenticated, service_role;

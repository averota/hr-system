-- 016: org unit write wrappers (ORG Stage 9c-3)
--
-- Public write wrappers for org units, callable by logged-in users.
-- Each one checks permission org.unit.write with private.has_permission,
-- then calls the private write function (003, 008, 009).
--
--   public.create_org_unit(company, level, parent unit, name EN, name KM)
--       checked at the parent unit (subtree scope included).
--       No parent (directly under the company): only a company-wide or
--       tenant-wide role passes.
--   public.close_org_unit(company, unit, close date)
--       checked at the unit being closed.
--   public.reorg_org_unit(company, unit, new parent, effective date)
--       must pass at the unit being moved AND at the new parent.
--       Moving to the root: only a company-wide or tenant-wide role passes.
--
-- Also adds private.is_company_member(company): true when the caller belongs
-- to the company's tenant. Used to decide between a plain message and no hint.
--
-- Errors:
--   no permission (or not a member of the company's tenant):
--       'You do not have permission to manage org units here' (code 42501)
--   a member naming a unit that is not open in this company:
--       'Org unit % is not an open unit of this company'
--       'Parent unit % is not an open unit of this company'
--       'New parent % is not an open unit of this company'
--   blank English name:
--       'The English name is required'
-- Rules, dates and cascades (closing a unit closes its allocations and
-- Department listings) are unchanged: they live in the private functions.

-- ---------------------------------------------------------------
-- Helper
-- ---------------------------------------------------------------
create function private.is_company_member(p_company_id integer)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from core.parent_company c
    where c.id = p_company_id
      and c.tenant_id in (select private.user_tenant_ids())
  )
$$;

revoke execute on function private.is_company_member(integer)
  from public, anon, authenticated;
grant execute on function private.is_company_member(integer)
  to service_role;

-- ---------------------------------------------------------------
-- Public wrappers
-- security definer: they read and write core as the function owner, and
-- decide access themselves with private.has_permission (the caller's login).
-- ---------------------------------------------------------------
create function public.create_org_unit(
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
  if p_parent_unit_id is not null and not exists (
    select 1
    from core.org_unit u
    where u.id = p_parent_unit_id
      and u.company_id = p_company_id
      and u.valid_to is null
  ) then
    if private.is_company_member(p_company_id) then
      raise exception 'Parent unit % is not an open unit of this company', p_parent_unit_id;
    end if;

    raise exception 'You do not have permission to manage org units here'
      using errcode = '42501';
  end if;

  if not private.has_permission(p_company_id, 'org.unit.write', p_parent_unit_id) then
    raise exception 'You do not have permission to manage org units here'
      using errcode = '42501';
  end if;

  if p_name_en is null or btrim(p_name_en) = '' then
    raise exception 'The English name is required';
  end if;

  return private.create_org_unit(
    p_company_id, p_level_id, p_parent_unit_id, p_name_en, p_name_km);
end;
$$;

create function public.close_org_unit(
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
    from core.org_unit u
    where u.id = p_unit_id
      and u.company_id = p_company_id
      and u.valid_to is null
  ) then
    if private.is_company_member(p_company_id) then
      raise exception 'Org unit % is not an open unit of this company', p_unit_id;
    end if;

    raise exception 'You do not have permission to manage org units here'
      using errcode = '42501';
  end if;

  if not private.has_permission(p_company_id, 'org.unit.write', p_unit_id) then
    raise exception 'You do not have permission to manage org units here'
      using errcode = '42501';
  end if;

  perform private.close_org_unit(p_company_id, p_unit_id, p_close_date);
end;
$$;

create function public.reorg_org_unit(
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
    from core.org_unit u
    where u.id = p_unit_id
      and u.company_id = p_company_id
      and u.valid_to is null
  ) then
    if private.is_company_member(p_company_id) then
      raise exception 'Org unit % is not an open unit of this company', p_unit_id;
    end if;

    raise exception 'You do not have permission to manage org units here'
      using errcode = '42501';
  end if;

  -- the caller must manage the unit being moved
  if not private.has_permission(p_company_id, 'org.unit.write', p_unit_id) then
    raise exception 'You do not have permission to manage org units here'
      using errcode = '42501';
  end if;

  -- the caller is now known to be an authorised member, so a plain message is safe
  if p_new_parent_id is not null and not exists (
    select 1
    from core.org_unit u
    where u.id = p_new_parent_id
      and u.company_id = p_company_id
      and u.valid_to is null
  ) then
    raise exception 'New parent % is not an open unit of this company', p_new_parent_id;
  end if;

  -- ... and the place it is moving to (null = the root, company-wide roles only)
  if not private.has_permission(p_company_id, 'org.unit.write', p_new_parent_id) then
    raise exception 'You do not have permission to manage org units here'
      using errcode = '42501';
  end if;

  perform private.reorg_org_unit(p_company_id, p_unit_id, p_new_parent_id, p_effective_date);
end;
$$;

-- ---------------------------------------------------------------
-- Privileges: logged-in users only (Supabase grants new public objects
-- to anon and authenticated by default, so revoke first)
-- ---------------------------------------------------------------
revoke execute on function
  public.create_org_unit(integer, integer, integer, text, text),
  public.close_org_unit(integer, integer, date),
  public.reorg_org_unit(integer, integer, integer, date)
from public, anon, authenticated;

grant execute on function
  public.create_org_unit(integer, integer, integer, text, text),
  public.close_org_unit(integer, integer, date),
  public.reorg_org_unit(integer, integer, integer, date)
to authenticated, service_role;

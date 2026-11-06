-- 022: rename org units and position units (ORG Stage 9f-1)
--
-- Private functions (service_role only):
--   private.rename_org_unit(company, unit, name EN, name KM)
--   private.rename_pos_unit(company, unit, name EN, name KM)
--       The unit must be open and belong to the company.
--       English name required. Both names are trimmed.
--       An empty Khmer name clears it (stored as null).
--       Only the names change (the guards from 006 already allow that).
--
-- Public wrappers (logged-in users, checked with private.has_permission):
--   public.rename_org_unit(company, unit, name EN, name KM)
--       org.unit.write at the unit (a role on a unit covers its subtree).
--   public.rename_pos_unit(company, unit, name EN, name KM)
--       pos.unit.write at the unit's Department, same rule as close_pos_unit
--       (private.can_manage_pos_unit, 017): renaming a Department itself needs
--       a company-wide or tenant-wide role.
--
-- Errors (same pattern as 016 and 017):
--   no permission (or not a member of the company's tenant):
--       'You do not have permission to manage org units here' (code 42501)
--       'You do not have permission to manage position units here' (code 42501)
--   a member naming a unit that is not open in this company:
--       'Org unit % is not an open unit of this company'
--       'Position unit % is not an open unit of this company'
--   blank English name: 'The English name is required'
-- Needs 016 (private.is_company_member) and 017 (private.can_manage_pos_unit).

-- ---------------------------------------------------------------
-- Private functions
-- ---------------------------------------------------------------
create function private.rename_org_unit(
  p_company_id  integer,
  p_unit_id     integer,
  p_name_en     text,
  p_name_km     text default null
)
returns void
language plpgsql
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
    raise exception 'Org unit % is not an open unit of this company', p_unit_id;
  end if;

  if p_name_en is null or btrim(p_name_en) = '' then
    raise exception 'The English name is required';
  end if;

  update core.org_unit
  set name_en = btrim(p_name_en),
      name_km = nullif(btrim(coalesce(p_name_km, '')), '')
  where id = p_unit_id
    and company_id = p_company_id;
end;
$$;

create function private.rename_pos_unit(
  p_company_id  integer,
  p_unit_id     integer,
  p_name_en     text,
  p_name_km     text default null
)
returns void
language plpgsql
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
    raise exception 'Position unit % is not an open unit of this company', p_unit_id;
  end if;

  if p_name_en is null or btrim(p_name_en) = '' then
    raise exception 'The English name is required';
  end if;

  update core.pos_unit
  set name_en = btrim(p_name_en),
      name_km = nullif(btrim(coalesce(p_name_km, '')), '')
  where id = p_unit_id
    and company_id = p_company_id;
end;
$$;

revoke execute on function
  private.rename_org_unit(integer, integer, text, text),
  private.rename_pos_unit(integer, integer, text, text)
from public, anon, authenticated;

grant execute on function
  private.rename_org_unit(integer, integer, text, text),
  private.rename_pos_unit(integer, integer, text, text)
to service_role;

-- ---------------------------------------------------------------
-- Public wrappers
-- ---------------------------------------------------------------
create function public.rename_org_unit(
  p_company_id  integer,
  p_unit_id     integer,
  p_name_en     text,
  p_name_km     text default null
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

  if p_name_en is null or btrim(p_name_en) = '' then
    raise exception 'The English name is required';
  end if;

  perform private.rename_org_unit(p_company_id, p_unit_id, p_name_en, p_name_km);
end;
$$;

create function public.rename_pos_unit(
  p_company_id  integer,
  p_unit_id     integer,
  p_name_en     text,
  p_name_km     text default null
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

  if p_name_en is null or btrim(p_name_en) = '' then
    raise exception 'The English name is required';
  end if;

  perform private.rename_pos_unit(p_company_id, p_unit_id, p_name_en, p_name_km);
end;
$$;

-- ---------------------------------------------------------------
-- Privileges: logged-in users only
-- ---------------------------------------------------------------
revoke execute on function
  public.rename_org_unit(integer, integer, text, text),
  public.rename_pos_unit(integer, integer, text, text)
from public, anon, authenticated;

grant execute on function
  public.rename_org_unit(integer, integer, text, text),
  public.rename_pos_unit(integer, integer, text, text)
to authenticated, service_role;

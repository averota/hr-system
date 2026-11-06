-- 019: Department listing write functions and wrappers (ORG Stage 9c-6)
--
-- A "listing" is a row in core.org_unit_department: it says which Departments an
-- org unit may use. Allocations can only be made for listed Departments.
--
-- Part A: private write functions (service_role only), the missing single write
--         path for listings:
--   private.add_department_listing(company, org unit, Department, start date)
--   private.remove_department_listing(company, org unit, Department, close date)
--
-- Part B: public wrappers, callable by logged-in users. Each one checks
--         permission org.eligibility.write at the org unit (subtree scope
--         included), then calls the private function.
--   public.add_department_listing(company, org unit, Department, start date)
--   public.remove_department_listing(company, org unit, Department, close date)
-- Needs 016 (private.is_company_member).
--
-- Rules:
--   * add: the org unit must be open in the company, the Department must be an
--     open Department of the company, and it must not already be listed.
--     The start date (default today, server date UTC) cannot be earlier than the
--     start of the org unit or the Department, or the end of an earlier listing
--     of the same pair.
--   * remove: closes the open listing. Refused while open allocations use it
--     (guard from 006: 'Open allocations still use this Department at this org
--     unit. Close them first'). The close date cannot be earlier than the
--     listing's start.
--   * A listing is found by org unit + Department, not by its own ID.
--
-- Errors:
--   no permission (or not a member of the company's tenant):
--       'You do not have permission to manage Department listings here' (code 42501)
--   a member naming an org unit that is not open in this company:
--       'Org unit % is not an open unit of this company'
--   'Department % is not an open Department of this company'
--   'Department % is already listed for org unit %'
--   'Department % is not listed for org unit %'
--   'Start date % is earlier than %, ...' / 'Close date % is earlier than %, ...'

-- ---------------------------------------------------------------
-- Part A: private functions
-- ---------------------------------------------------------------
create function private.add_department_listing(
  p_company_id     integer,
  p_org_unit_id    integer,
  p_department_id  integer,
  p_start_date     date default current_date
)
returns integer
language plpgsql
set search_path = ''
as $$
declare
  v_unit_from date;
  v_dept_from date;
  v_prev_end  date;
  v_latest    date;
  v_id        integer;
begin
  select valid_from into v_unit_from
  from core.org_unit
  where id = p_org_unit_id
    and company_id = p_company_id
    and valid_to is null;

  if not found then
    raise exception 'Org unit % is not an open unit of this company', p_org_unit_id;
  end if;

  select u.valid_from into v_dept_from
  from core.pos_unit u
  join core.hierarchy_level h on h.id = u.level_id
  where u.id = p_department_id
    and u.company_id = p_company_id
    and u.valid_to is null
    and h.code = 'department';

  if not found then
    raise exception 'Department % is not an open Department of this company', p_department_id;
  end if;

  if exists (
    select 1
    from core.org_unit_department e
    where e.org_unit_id = p_org_unit_id
      and e.department_id = p_department_id
      and e.valid_to is null
  ) then
    raise exception 'Department % is already listed for org unit %', p_department_id, p_org_unit_id;
  end if;

  select max(e.valid_to) into v_prev_end
  from core.org_unit_department e
  where e.org_unit_id = p_org_unit_id
    and e.department_id = p_department_id;

  v_latest := greatest(v_unit_from, v_dept_from, v_prev_end);

  if p_start_date < v_latest then
    raise exception 'Start date % is earlier than %, when the org unit or Department started or a previous listing ended',
      p_start_date, v_latest;
  end if;

  insert into core.org_unit_department (company_id, org_unit_id, department_id, valid_from)
  values (p_company_id, p_org_unit_id, p_department_id, p_start_date)
  returning id into v_id;

  return v_id;
end;
$$;

create function private.remove_department_listing(
  p_company_id     integer,
  p_org_unit_id    integer,
  p_department_id  integer,
  p_close_date     date default current_date
)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_id   integer;
  v_from date;
begin
  select e.id, e.valid_from into v_id, v_from
  from core.org_unit_department e
  where e.company_id = p_company_id
    and e.org_unit_id = p_org_unit_id
    and e.department_id = p_department_id
    and e.valid_to is null
  for update;

  if not found then
    raise exception 'Department % is not listed for org unit %', p_department_id, p_org_unit_id;
  end if;

  if p_close_date < v_from then
    raise exception 'Close date % is earlier than %, when this listing started',
      p_close_date, v_from;
  end if;

  -- the guard refuses while open allocations still use this listing
  update core.org_unit_department
  set valid_to = p_close_date
  where id = v_id;
end;
$$;

revoke execute on function
  private.add_department_listing(integer, integer, integer, date),
  private.remove_department_listing(integer, integer, integer, date)
from public, anon, authenticated;

grant execute on function
  private.add_department_listing(integer, integer, integer, date),
  private.remove_department_listing(integer, integer, integer, date)
to service_role;

-- ---------------------------------------------------------------
-- Part B: public wrappers
-- security definer: they read and write core as the function owner, and
-- decide access themselves with private.has_permission (the caller's login).
-- ---------------------------------------------------------------
create function public.add_department_listing(
  p_company_id     integer,
  p_org_unit_id    integer,
  p_department_id  integer,
  p_start_date     date default current_date
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1
    from core.org_unit u
    where u.id = p_org_unit_id
      and u.company_id = p_company_id
      and u.valid_to is null
  ) then
    if private.is_company_member(p_company_id) then
      raise exception 'Org unit % is not an open unit of this company', p_org_unit_id;
    end if;

    raise exception 'You do not have permission to manage Department listings here'
      using errcode = '42501';
  end if;

  if not private.has_permission(p_company_id, 'org.eligibility.write', p_org_unit_id) then
    raise exception 'You do not have permission to manage Department listings here'
      using errcode = '42501';
  end if;

  return private.add_department_listing(
    p_company_id, p_org_unit_id, p_department_id, p_start_date);
end;
$$;

create function public.remove_department_listing(
  p_company_id     integer,
  p_org_unit_id    integer,
  p_department_id  integer,
  p_close_date     date default current_date
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
    where u.id = p_org_unit_id
      and u.company_id = p_company_id
      and u.valid_to is null
  ) then
    if private.is_company_member(p_company_id) then
      raise exception 'Org unit % is not an open unit of this company', p_org_unit_id;
    end if;

    raise exception 'You do not have permission to manage Department listings here'
      using errcode = '42501';
  end if;

  if not private.has_permission(p_company_id, 'org.eligibility.write', p_org_unit_id) then
    raise exception 'You do not have permission to manage Department listings here'
      using errcode = '42501';
  end if;

  perform private.remove_department_listing(
    p_company_id, p_org_unit_id, p_department_id, p_close_date);
end;
$$;

-- ---------------------------------------------------------------
-- Privileges: logged-in users only (Supabase grants new public objects
-- to anon and authenticated by default, so revoke first)
-- ---------------------------------------------------------------
revoke execute on function
  public.add_department_listing(integer, integer, integer, date),
  public.remove_department_listing(integer, integer, integer, date)
from public, anon, authenticated;

grant execute on function
  public.add_department_listing(integer, integer, integer, date),
  public.remove_department_listing(integer, integer, integer, date)
to authenticated, service_role;

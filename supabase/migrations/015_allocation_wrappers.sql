-- 015: allocation write wrappers (ORG Stage 9c-2)
--
-- Part A: replaces private.create_allocation (previous version: 006).
--         It now takes a start date (default today, server date UTC) and refuses a
--         start date earlier than the start of the org unit, the Department
--         listing, the job or the position unit. Existing 5-argument calls keep
--         working because the new argument has a default.
--
-- Part B: public write wrappers for allocations, callable by logged-in users.
--         Each one checks permission org.allocation.write with
--         private.has_permission, passing the allocation's org unit and the job's
--         Department, then calls the private write function.
--
--   public.create_allocation(company, org unit, job, position unit, headcount, start date)
--   public.close_allocation(company, allocation, close date)
--   public.change_allocation_headcount(company, allocation, new headcount, effective date)
--       closes the allocation and creates its replacement on the same date,
--       in one transaction (everything or nothing)
--
-- Errors:
--   no permission (or not a member of the company's tenant):
--       'You do not have permission to manage allocations here' (code 42501)
--   a member asking about an allocation that is not open:
--       'Allocation % is not an open allocation of this company'
--   headcount change to the same number:
--       'The new headcount is the same as the current headcount'
--
-- Dates: the frontend passes dates explicitly. A future date takes effect
-- immediately ("current" means valid_to is empty).

-- ---------------------------------------------------------------
-- Part A: create_allocation with a start date
-- ---------------------------------------------------------------
drop function private.create_allocation(integer, integer, integer, integer, integer);

create function private.create_allocation(
  p_company_id      integer,
  p_org_unit_id     integer,
  p_job_position_id integer,
  p_pos_unit_id     integer,
  p_headcount       integer,
  p_start_date      date default current_date
)
returns integer
language plpgsql
set search_path = ''
as $$
declare
  v_eligibility_id integer;
  v_department_id  integer;
  v_latest         date;
  v_id             integer;
begin
  select e.id, e.department_id
  into v_eligibility_id, v_department_id
  from core.job_position j
  join core.org_unit_department e
    on e.company_id = j.company_id
   and e.department_id = j.department_id
  where j.id = p_job_position_id
    and j.company_id = p_company_id
    and j.valid_to is null
    and e.org_unit_id = p_org_unit_id
    and e.valid_to is null;

  if not found then
    raise exception 'This job position is not offered at this org unit';
  end if;

  -- latest start among the things this allocation depends on
  select greatest(e.valid_from, j.valid_from, ou.valid_from,
                  coalesce(pu.valid_from, e.valid_from))
  into v_latest
  from core.org_unit_department e
  join core.job_position j on j.id = p_job_position_id
  join core.org_unit ou on ou.id = e.org_unit_id
  left join core.pos_unit pu on pu.id = p_pos_unit_id
  where e.id = v_eligibility_id;

  if p_start_date < v_latest then
    raise exception 'Start date % is earlier than %, when the org unit, listing, job or position unit started',
      p_start_date, v_latest;
  end if;

  insert into core.position_allocation
    (company_id, org_unit_id, department_id, eligibility_id,
     job_position_id, pos_unit_id, approved_headcount, valid_from)
  values
    (p_company_id, p_org_unit_id, v_department_id, v_eligibility_id,
     p_job_position_id, p_pos_unit_id, p_headcount, p_start_date)
  returning id into v_id;

  return v_id;
end;
$$;

revoke execute on function private.create_allocation(integer, integer, integer, integer, integer, date)
  from public, anon, authenticated;
grant execute on function private.create_allocation(integer, integer, integer, integer, integer, date)
  to service_role;

-- ---------------------------------------------------------------
-- Part B: public wrappers
-- security definer: they read and write core as the function owner, and
-- decide access themselves with private.has_permission (the caller's login).
-- ---------------------------------------------------------------
create function public.create_allocation(
  p_company_id      integer,
  p_org_unit_id     integer,
  p_job_position_id integer,
  p_pos_unit_id     integer,
  p_headcount       integer,
  p_start_date      date default current_date
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_department_id integer;
begin
  select j.department_id into v_department_id
  from core.job_position j
  where j.id = p_job_position_id
    and j.company_id = p_company_id
    and j.valid_to is null;

  if not private.has_permission(p_company_id, 'org.allocation.write',
                                p_org_unit_id, v_department_id) then
    raise exception 'You do not have permission to manage allocations here'
      using errcode = '42501';
  end if;

  return private.create_allocation(
    p_company_id, p_org_unit_id, p_job_position_id, p_pos_unit_id,
    p_headcount, p_start_date);
end;
$$;

create function public.close_allocation(
  p_company_id     integer,
  p_allocation_id  integer,
  p_close_date     date default current_date
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_org_unit_id   integer;
  v_department_id integer;
begin
  select a.org_unit_id, a.department_id
  into v_org_unit_id, v_department_id
  from core.position_allocation a
  where a.id = p_allocation_id
    and a.company_id = p_company_id
    and a.valid_to is null;

  if not found then
    -- members of the company's tenant get the plain message, everyone else none
    if exists (
      select 1
      from core.parent_company c
      where c.id = p_company_id
        and c.tenant_id in (select private.user_tenant_ids())
    ) then
      raise exception 'Allocation % is not an open allocation of this company', p_allocation_id;
    end if;

    raise exception 'You do not have permission to manage allocations here'
      using errcode = '42501';
  end if;

  if not private.has_permission(p_company_id, 'org.allocation.write',
                                v_org_unit_id, v_department_id) then
    raise exception 'You do not have permission to manage allocations here'
      using errcode = '42501';
  end if;

  perform private.close_allocation(p_company_id, p_allocation_id, p_close_date);
end;
$$;

create function public.change_allocation_headcount(
  p_company_id      integer,
  p_allocation_id   integer,
  p_new_headcount   integer,
  p_effective_date  date default current_date
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_org_unit_id   integer;
  v_department_id integer;
  v_job_id        integer;
  v_pos_unit_id   integer;
  v_headcount     integer;
begin
  select a.org_unit_id, a.department_id, a.job_position_id, a.pos_unit_id,
         a.approved_headcount
  into v_org_unit_id, v_department_id, v_job_id, v_pos_unit_id, v_headcount
  from core.position_allocation a
  where a.id = p_allocation_id
    and a.company_id = p_company_id
    and a.valid_to is null;

  if not found then
    if exists (
      select 1
      from core.parent_company c
      where c.id = p_company_id
        and c.tenant_id in (select private.user_tenant_ids())
    ) then
      raise exception 'Allocation % is not an open allocation of this company', p_allocation_id;
    end if;

    raise exception 'You do not have permission to manage allocations here'
      using errcode = '42501';
  end if;

  if not private.has_permission(p_company_id, 'org.allocation.write',
                                v_org_unit_id, v_department_id) then
    raise exception 'You do not have permission to manage allocations here'
      using errcode = '42501';
  end if;

  if p_new_headcount = v_headcount then
    raise exception 'The new headcount is the same as the current headcount';
  end if;

  -- close the old allocation and open its replacement on the same date.
  -- Any error rolls back both.
  perform private.close_allocation(p_company_id, p_allocation_id, p_effective_date);

  return private.create_allocation(
    p_company_id, v_org_unit_id, v_job_id, v_pos_unit_id,
    p_new_headcount, p_effective_date);
end;
$$;

-- ---------------------------------------------------------------
-- Privileges: logged-in users only (Supabase grants new public objects
-- to anon and authenticated by default, so revoke first)
-- ---------------------------------------------------------------
revoke execute on function
  public.create_allocation(integer, integer, integer, integer, integer, date),
  public.close_allocation(integer, integer, date),
  public.change_allocation_headcount(integer, integer, integer, date)
from public, anon, authenticated;

grant execute on function
  public.create_allocation(integer, integer, integer, integer, integer, date),
  public.close_allocation(integer, integer, date),
  public.change_allocation_headcount(integer, integer, integer, date)
to authenticated, service_role;

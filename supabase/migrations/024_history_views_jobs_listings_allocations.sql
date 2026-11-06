-- 024: history views for jobs, Department listings and allocations (ORG Stage 9i, part 2)
--
-- Read-only views of CLOSED records (valid_to is not null), same pattern as the
-- "current" views in 010: security_invoker (the caller's row level security still
-- applies), logged-in users only.
--
--   job_positions_closed            closed jobs, with their Department's name
--   org_unit_departments_closed     closed Department listings, with org unit and Department names
--   position_allocations_closed     closed allocations (headcount history), with names
--
-- Names are the current names of the units and jobs (a rename changes them everywhere).
-- Nothing is changed in core.

-- ---------------------------------------------------------------
-- Views
-- ---------------------------------------------------------------
create view public.job_positions_closed
with (security_invoker = true) as
select
  j.id          as job_position_id,
  j.company_id,
  j.department_id,
  d.name_en     as department_name_en,
  d.name_km     as department_name_km,
  j.name_en,
  j.name_km,
  j.valid_from,
  j.valid_to
from core.job_position j
join core.pos_unit d on d.id = j.department_id
where j.valid_to is not null;

create view public.org_unit_departments_closed
with (security_invoker = true) as
select
  e.id          as eligibility_id,
  e.company_id,
  e.org_unit_id,
  ou.name_en    as org_unit_name_en,
  ou.name_km    as org_unit_name_km,
  e.department_id,
  d.name_en     as department_name_en,
  d.name_km     as department_name_km,
  e.valid_from,
  e.valid_to
from core.org_unit_department e
join core.org_unit ou on ou.id = e.org_unit_id
join core.pos_unit d  on d.id  = e.department_id
where e.valid_to is not null;

create view public.position_allocations_closed
with (security_invoker = true) as
select
  a.id                  as allocation_id,
  a.company_id,
  a.org_unit_id,
  ou.name_en            as org_unit_name_en,
  ou.name_km            as org_unit_name_km,
  a.department_id,
  d.name_en             as department_name_en,
  d.name_km             as department_name_km,
  a.job_position_id,
  j.name_en             as job_name_en,
  j.name_km             as job_name_km,
  a.pos_unit_id,
  pu.name_en            as pos_unit_name_en,
  pu.name_km            as pos_unit_name_km,
  pl.code               as pos_level_code,
  a.approved_headcount,
  a.valid_from,
  a.valid_to
from core.position_allocation a
join core.org_unit ou        on ou.id = a.org_unit_id
join core.pos_unit d         on d.id  = a.department_id
join core.job_position j     on j.id  = a.job_position_id
join core.pos_unit pu        on pu.id = a.pos_unit_id
join core.hierarchy_level pl on pl.id = pu.level_id
where a.valid_to is not null;

-- ---------------------------------------------------------------
-- Privileges: logged-in users only.
-- Supabase grants new public objects to anon and authenticated by default,
-- so those are removed explicitly first.
-- ---------------------------------------------------------------
revoke all on
  public.job_positions_closed,
  public.org_unit_departments_closed,
  public.position_allocations_closed
from anon, authenticated;

grant select on
  public.job_positions_closed,
  public.org_unit_departments_closed,
  public.position_allocations_closed
to authenticated, service_role;

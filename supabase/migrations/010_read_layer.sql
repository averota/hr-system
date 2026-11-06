-- 010: read layer (roadmap Stage 7)
--
-- Everything the frontend reads lives here in public. Nothing in core or
-- private is exposed.
--
-- Views (security_invoker, so the caller's row level security still applies):
--   company_level_rules_current   enabled levels and what they sit under
--   org_units_current             open org units with their current parent
--   pos_units_current             open position units with their current parent
--   org_unit_departments_current  Departments each org unit may use
--   job_positions_current         open job positions
--   position_allocations_current  open allocations with names (headcount grid)
--
-- Functions, one per step of the cascading allocation form:
--   org_options(company, parent_org_unit)          org locations, level by level
--                                                  (parent null = directly under the company)
--   eligible_departments(company, org_unit)        Departments this org unit may use
--   pos_options(company, parent_pos_unit)          Offices / Sections / Groups directly under a unit
--                                                  (top level Departments come from eligible_departments)
--   eligible_jobs(company, org_unit, department)   jobs offered at that org unit for that Department
--
-- "Current" means valid_to is null, the same convention as the rest of the schema.
-- Read-only. Logged-in users only: anon gets nothing.

-- Views read core tables as the logged-in user, so that role needs to see the schema
grant usage on schema core to authenticated;

-- ---------------------------------------------------------------
-- Views
-- ---------------------------------------------------------------
create view public.company_level_rules_current
with (security_invoker = true) as
select
  r.id                as rule_id,
  r.company_id,
  r.tree,
  r.level_id,
  l.code              as level_code,
  l.rank              as level_rank,
  l.name_en           as level_name_en,
  l.name_km           as level_name_km,
  r.parent_level_id,
  pl.code             as parent_level_code,
  pl.name_en          as parent_level_name_en,
  pl.name_km          as parent_level_name_km,
  r.valid_from
from core.company_level_rule r
join core.hierarchy_level l  on l.id = r.level_id
left join core.hierarchy_level pl on pl.id = r.parent_level_id
where r.valid_to is null;

create view public.org_units_current
with (security_invoker = true) as
select
  u.id          as unit_id,
  u.company_id,
  u.level_id,
  l.code        as level_code,
  l.rank        as level_rank,
  l.name_en     as level_name_en,
  l.name_km     as level_name_km,
  u.name_en,
  u.name_km,
  p.parent_unit_id,
  u.valid_from
from core.org_unit u
join core.hierarchy_level l on l.id = u.level_id
join core.org_unit_parent p on p.unit_id = u.id and p.valid_to is null
where u.valid_to is null;

create view public.pos_units_current
with (security_invoker = true) as
select
  u.id          as unit_id,
  u.company_id,
  u.level_id,
  l.code        as level_code,
  l.rank        as level_rank,
  l.name_en     as level_name_en,
  l.name_km     as level_name_km,
  u.name_en,
  u.name_km,
  p.parent_unit_id,
  u.valid_from
from core.pos_unit u
join core.hierarchy_level l on l.id = u.level_id
join core.pos_unit_parent p on p.unit_id = u.id and p.valid_to is null
where u.valid_to is null;

create view public.org_unit_departments_current
with (security_invoker = true) as
select
  e.id          as eligibility_id,
  e.company_id,
  e.org_unit_id,
  e.department_id,
  e.valid_from
from core.org_unit_department e
where e.valid_to is null;

create view public.job_positions_current
with (security_invoker = true) as
select
  j.id          as job_position_id,
  j.company_id,
  j.department_id,
  j.name_en,
  j.name_km,
  j.valid_from
from core.job_position j
where j.valid_to is null;

create view public.position_allocations_current
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
  a.valid_from
from core.position_allocation a
join core.org_unit ou       on ou.id = a.org_unit_id
join core.pos_unit d        on d.id  = a.department_id
join core.job_position j    on j.id  = a.job_position_id
join core.pos_unit pu       on pu.id = a.pos_unit_id
join core.hierarchy_level pl on pl.id = pu.level_id
where a.valid_to is null;

-- ---------------------------------------------------------------
-- Cascade functions (security invoker: row level security applies)
-- Option functions share one return shape so the frontend can reuse
-- a single dropdown component.
-- ---------------------------------------------------------------
create function public.org_options(
  p_company_id      integer,
  p_parent_unit_id  integer default null
)
returns table (unit_id integer, level_id integer, level_code text, name_en text, name_km text)
language sql
stable
set search_path = ''
as $$
  select u.unit_id, u.level_id, u.level_code, u.name_en, u.name_km
  from public.org_units_current u
  where u.company_id = p_company_id
    and u.parent_unit_id is not distinct from p_parent_unit_id
  order by u.level_rank, u.name_en
$$;

create function public.eligible_departments(
  p_company_id   integer,
  p_org_unit_id  integer
)
returns table (unit_id integer, level_id integer, level_code text, name_en text, name_km text)
language sql
stable
set search_path = ''
as $$
  select d.unit_id, d.level_id, d.level_code, d.name_en, d.name_km
  from public.org_unit_departments_current e
  join public.pos_units_current d on d.unit_id = e.department_id
  where e.company_id = p_company_id
    and e.org_unit_id = p_org_unit_id
  order by d.name_en
$$;

create function public.pos_options(
  p_company_id      integer,
  p_parent_unit_id  integer
)
returns table (unit_id integer, level_id integer, level_code text, name_en text, name_km text)
language sql
stable
set search_path = ''
as $$
  select u.unit_id, u.level_id, u.level_code, u.name_en, u.name_km
  from public.pos_units_current u
  where u.company_id = p_company_id
    and u.parent_unit_id = p_parent_unit_id
  order by u.level_rank, u.name_en
$$;

create function public.eligible_jobs(
  p_company_id     integer,
  p_org_unit_id    integer,
  p_department_id  integer
)
returns table (job_position_id integer, name_en text, name_km text)
language sql
stable
set search_path = ''
as $$
  select j.job_position_id, j.name_en, j.name_km
  from public.job_positions_current j
  where j.company_id = p_company_id
    and j.department_id = p_department_id
    and exists (
      select 1
      from public.org_unit_departments_current e
      where e.company_id = j.company_id
        and e.org_unit_id = p_org_unit_id
        and e.department_id = j.department_id
    )
  order by j.name_en
$$;

-- ---------------------------------------------------------------
-- Privileges: logged-in users only.
-- Supabase grants new public objects to anon and authenticated by default,
-- so those are removed explicitly first.
-- ---------------------------------------------------------------
revoke all on
  public.company_level_rules_current,
  public.org_units_current,
  public.pos_units_current,
  public.org_unit_departments_current,
  public.job_positions_current,
  public.position_allocations_current
from anon, authenticated;

grant select on
  public.company_level_rules_current,
  public.org_units_current,
  public.pos_units_current,
  public.org_unit_departments_current,
  public.job_positions_current,
  public.position_allocations_current
to authenticated, service_role;

revoke execute on function
  public.org_options(integer, integer),
  public.eligible_departments(integer, integer),
  public.pos_options(integer, integer),
  public.eligible_jobs(integer, integer, integer)
from public, anon, authenticated;

grant execute on function
  public.org_options(integer, integer),
  public.eligible_departments(integer, integer),
  public.pos_options(integer, integer),
  public.eligible_jobs(integer, integer, integer)
to authenticated, service_role;

-- 028: history reads (ORG Stage 9k, database part)
--
-- Part A: reorg history. Views of CLOSED parent links of units. A unit that is
--         still open but was moved shows its old links here. A unit that was
--         closed shows its last link too (unit_valid_to tells them apart:
--         empty = the unit is still open, so the link ended by a reorg).
--
--   org_unit_parent_links_closed
--   pos_unit_parent_links_closed
--
-- Part B: as-of date reads. Each function shows the records as they stood on a
--         given date. The date is required (the server runs on UTC, so the
--         frontend passes the user's date).
--
--   org_units_as_of(company, date)
--   pos_units_as_of(company, date)
--   position_allocations_as_of(company, date)    allocations and headcount
--   org_unit_departments_as_of(company, date)    Department listings
--
-- Date rule (ORG-D12): valid_to is the LAST valid day (inclusive). A replacement
-- (reorg, headcount change, re-listing) starts on the date the old row ends, so
-- two rows can touch on one date. The row that started later wins; if both
-- started on the same date, the higher id wins.
--
-- Notes:
--   * Names are the current names (name history was dropped in 027).
--   * A reorg with a future effective date takes effect immediately in the
--     *_current views (valid_to is empty), but an as-of read before that date
--     still shows the old parent.
--   * Not paged. Supabase returns at most 1000 rows per request.
--   * Security invoker: the caller's row level security still applies.
--     Logged-in users only: anon gets nothing.
-- Needs 003, 004, 005, 006, 010, 023 and 024. Nothing in core is changed.

-- ---------------------------------------------------------------
-- Part A: reorg history views
-- ---------------------------------------------------------------
create view public.org_unit_parent_links_closed
with (security_invoker = true) as
select
  lp.id           as link_id,
  lp.company_id,
  lp.unit_id,
  u.name_en,
  u.name_km,
  u.level_id,
  l.code          as level_code,
  l.rank          as level_rank,
  l.name_en       as level_name_en,
  l.name_km       as level_name_km,
  lp.parent_unit_id,
  pu.name_en      as parent_name_en,
  pu.name_km      as parent_name_km,
  lp.valid_from,
  lp.valid_to,
  u.valid_to      as unit_valid_to
from core.org_unit_parent lp
join core.org_unit u         on u.id = lp.unit_id
join core.hierarchy_level l  on l.id = u.level_id
left join core.org_unit pu   on pu.id = lp.parent_unit_id
where lp.valid_to is not null;

create view public.pos_unit_parent_links_closed
with (security_invoker = true) as
select
  lp.id           as link_id,
  lp.company_id,
  lp.unit_id,
  u.name_en,
  u.name_km,
  u.level_id,
  l.code          as level_code,
  l.rank          as level_rank,
  l.name_en       as level_name_en,
  l.name_km       as level_name_km,
  lp.parent_unit_id,
  pu.name_en      as parent_name_en,
  pu.name_km      as parent_name_km,
  lp.valid_from,
  lp.valid_to,
  u.valid_to      as unit_valid_to
from core.pos_unit_parent lp
join core.pos_unit u         on u.id = lp.unit_id
join core.hierarchy_level l  on l.id = u.level_id
left join core.pos_unit pu   on pu.id = lp.parent_unit_id
where lp.valid_to is not null;

-- ---------------------------------------------------------------
-- Part B: as-of date functions
-- ---------------------------------------------------------------
create function public.org_units_as_of(
  p_company_id  integer,
  p_as_of       date
)
returns table (
  unit_id         integer,
  level_id        integer,
  level_code      text,
  level_rank      integer,
  level_name_en   text,
  level_name_km   text,
  name_en         text,
  name_km         text,
  parent_unit_id  integer,
  valid_from      date,
  valid_to        date
)
language sql
stable
set search_path = ''
as $$
  select
    u.id::integer,
    u.level_id::integer,
    l.code::text,
    l.rank::integer,
    l.name_en::text,
    l.name_km::text,
    u.name_en::text,
    u.name_km::text,
    p.parent_unit_id::integer,
    u.valid_from,
    u.valid_to
  from core.org_unit u
  join core.hierarchy_level l on l.id = u.level_id
  join lateral (
    select lp.parent_unit_id
    from core.org_unit_parent lp
    where lp.unit_id = u.id
      and lp.valid_from <= p_as_of
      and (lp.valid_to is null or lp.valid_to >= p_as_of)
    order by lp.valid_from desc, lp.id desc
    limit 1
  ) p on true
  where u.company_id = p_company_id
    and u.valid_from <= p_as_of
    and (u.valid_to is null or u.valid_to >= p_as_of)
  order by l.rank, u.name_en
$$;

create function public.pos_units_as_of(
  p_company_id  integer,
  p_as_of       date
)
returns table (
  unit_id         integer,
  level_id        integer,
  level_code      text,
  level_rank      integer,
  level_name_en   text,
  level_name_km   text,
  name_en         text,
  name_km         text,
  parent_unit_id  integer,
  valid_from      date,
  valid_to        date
)
language sql
stable
set search_path = ''
as $$
  select
    u.id::integer,
    u.level_id::integer,
    l.code::text,
    l.rank::integer,
    l.name_en::text,
    l.name_km::text,
    u.name_en::text,
    u.name_km::text,
    p.parent_unit_id::integer,
    u.valid_from,
    u.valid_to
  from core.pos_unit u
  join core.hierarchy_level l on l.id = u.level_id
  join lateral (
    select lp.parent_unit_id
    from core.pos_unit_parent lp
    where lp.unit_id = u.id
      and lp.valid_from <= p_as_of
      and (lp.valid_to is null or lp.valid_to >= p_as_of)
    order by lp.valid_from desc, lp.id desc
    limit 1
  ) p on true
  where u.company_id = p_company_id
    and u.valid_from <= p_as_of
    and (u.valid_to is null or u.valid_to >= p_as_of)
  order by l.rank, u.name_en
$$;

create function public.position_allocations_as_of(
  p_company_id  integer,
  p_as_of       date
)
returns table (
  allocation_id       integer,
  company_id          integer,
  org_unit_id         integer,
  org_unit_name_en    text,
  org_unit_name_km    text,
  department_id       integer,
  department_name_en  text,
  department_name_km  text,
  job_position_id     integer,
  job_name_en         text,
  job_name_km         text,
  pos_unit_id         integer,
  pos_unit_name_en    text,
  pos_unit_name_km    text,
  pos_level_code      text,
  approved_headcount  integer,
  valid_from          date,
  valid_to            date
)
language sql
stable
set search_path = ''
as $$
  select
    x.allocation_id,
    x.company_id,
    x.org_unit_id,
    x.org_unit_name_en,
    x.org_unit_name_km,
    x.department_id,
    x.department_name_en,
    x.department_name_km,
    x.job_position_id,
    x.job_name_en,
    x.job_name_km,
    x.pos_unit_id,
    x.pos_unit_name_en,
    x.pos_unit_name_km,
    x.pos_level_code,
    x.approved_headcount,
    x.valid_from,
    x.valid_to
  from (
    select distinct on (a.org_unit_id, a.pos_unit_id, a.job_position_id)
      a.id::integer                 as allocation_id,
      a.company_id::integer         as company_id,
      a.org_unit_id::integer        as org_unit_id,
      ou.name_en::text              as org_unit_name_en,
      ou.name_km::text              as org_unit_name_km,
      a.department_id::integer     as department_id,
      d.name_en::text               as department_name_en,
      d.name_km::text               as department_name_km,
      a.job_position_id::integer    as job_position_id,
      j.name_en::text               as job_name_en,
      j.name_km::text               as job_name_km,
      a.pos_unit_id::integer        as pos_unit_id,
      pu.name_en::text              as pos_unit_name_en,
      pu.name_km::text              as pos_unit_name_km,
      pl.code::text                 as pos_level_code,
      a.approved_headcount::integer as approved_headcount,
      a.valid_from                  as valid_from,
      a.valid_to                    as valid_to
    from core.position_allocation a
    join core.org_unit ou        on ou.id = a.org_unit_id
    join core.pos_unit d         on d.id  = a.department_id
    join core.job_position j     on j.id  = a.job_position_id
    join core.pos_unit pu        on pu.id = a.pos_unit_id
    join core.hierarchy_level pl on pl.id = pu.level_id
    where a.company_id = p_company_id
      and a.valid_from <= p_as_of
      and (a.valid_to is null or a.valid_to >= p_as_of)
    order by a.org_unit_id, a.pos_unit_id, a.job_position_id,
             a.valid_from desc, a.id desc
  ) x
  order by x.org_unit_name_en, x.department_name_en, x.job_name_en
$$;

create function public.org_unit_departments_as_of(
  p_company_id  integer,
  p_as_of       date
)
returns table (
  eligibility_id  integer,
  company_id      integer,
  org_unit_id     integer,
  department_id   integer,
  valid_from      date,
  valid_to        date
)
language sql
stable
set search_path = ''
as $$
  select distinct on (e.org_unit_id, e.department_id)
    e.id::integer,
    e.company_id::integer,
    e.org_unit_id::integer,
    e.department_id::integer,
    e.valid_from,
    e.valid_to
  from core.org_unit_department e
  where e.company_id = p_company_id
    and e.valid_from <= p_as_of
    and (e.valid_to is null or e.valid_to >= p_as_of)
  order by e.org_unit_id, e.department_id, e.valid_from desc, e.id desc
$$;

-- ---------------------------------------------------------------
-- Privileges: logged-in users only.
-- Supabase grants new public objects to anon and authenticated by default,
-- so those are removed explicitly first.
-- ---------------------------------------------------------------
revoke all on
  public.org_unit_parent_links_closed,
  public.pos_unit_parent_links_closed
from anon, authenticated;

grant select on
  public.org_unit_parent_links_closed,
  public.pos_unit_parent_links_closed
to authenticated, service_role;

revoke execute on function
  public.org_units_as_of(integer, date),
  public.pos_units_as_of(integer, date),
  public.position_allocations_as_of(integer, date),
  public.org_unit_departments_as_of(integer, date)
from public, anon, authenticated;

grant execute on function
  public.org_units_as_of(integer, date),
  public.pos_units_as_of(integer, date),
  public.position_allocations_as_of(integer, date),
  public.org_unit_departments_as_of(integer, date)
to authenticated, service_role;

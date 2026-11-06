-- 006: position allocation (approved headcount)
--
--   position_allocation : "this org unit has this job, placed at this position
--                         unit, with this approved headcount".
--
-- What the database enforces:
--   * The job's Department must be listed for the org unit (foreign key to
--     org_unit_department). So "Architect in the IT Department" or
--     "Architect in a Banking Division" cannot be saved.
--   * The job belongs to that same Department (foreign key to job_position).
--   * The position unit is the job's Department itself, or an open Office,
--     Section or Group somewhere under it (trigger, because a foreign key
--     cannot check tree membership).
--   * Allocations always sit at an org unit (never directly at the company).
--
-- Allocations are versioned like links: closed, never edited. To change a
-- headcount, close the allocation and create a new one.
-- Closing an org unit, a position unit or a job closes its open allocations.
-- A listed Department cannot be removed from an org unit while allocations use it.

-- ---------------------------------------------------------------
-- Table
-- ---------------------------------------------------------------
create table core.position_allocation (
  id                  integer generated always as identity primary key,
  company_id          integer not null,
  org_unit_id         integer not null,
  department_id       integer not null,
  eligibility_id      integer not null,
  job_position_id     integer not null,
  pos_unit_id         integer not null,
  approved_headcount  integer not null check (approved_headcount >= 0),
  valid_from          date not null default current_date,
  valid_to            date,
  created_at          timestamptz not null default now(),

  -- the org unit is allowed to use this Department (and is in this company)
  foreign key (eligibility_id, company_id, org_unit_id, department_id)
    references core.org_unit_department (id, company_id, org_unit_id, department_id),

  -- the job belongs to that same Department
  foreign key (job_position_id, company_id, department_id)
    references core.job_position (id, company_id, department_id),

  -- the position unit is in the same company
  foreign key (pos_unit_id, company_id)
    references core.pos_unit (id, company_id),

  check (valid_to is null or valid_to >= valid_from)
);

-- One open allocation per org unit + position unit + job
create unique index position_allocation_open_uq
  on core.position_allocation (org_unit_id, pos_unit_id, job_position_id)
  where valid_to is null;

create index position_allocation_company_idx
  on core.position_allocation (company_id);

create index position_allocation_org_unit_idx
  on core.position_allocation (org_unit_id) where valid_to is null;

create index position_allocation_department_idx
  on core.position_allocation (department_id) where valid_to is null;

create index position_allocation_eligibility_idx
  on core.position_allocation (eligibility_id) where valid_to is null;

create index position_allocation_job_idx
  on core.position_allocation (job_position_id) where valid_to is null;

create index position_allocation_pos_unit_idx
  on core.position_allocation (pos_unit_id) where valid_to is null;

-- ---------------------------------------------------------------
-- Guard: position_allocation
-- ---------------------------------------------------------------
create function private.position_allocation_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_inside boolean;
begin
  if tg_op = 'INSERT' then
    if new.valid_to is not null then
      raise exception 'A new allocation must be open (valid_to must be empty)';
    end if;

    if not exists (
      select 1 from core.org_unit_department e
      where e.id = new.eligibility_id and e.valid_to is null
    ) then
      raise exception 'The org unit no longer lists this Department (eligibility row is closed)';
    end if;

    if not exists (
      select 1 from core.job_position j
      where j.id = new.job_position_id and j.valid_to is null
    ) then
      raise exception 'The job position is closed';
    end if;

    if not exists (
      select 1 from core.pos_unit u
      where u.id = new.pos_unit_id and u.valid_to is null
    ) then
      raise exception 'The position unit is closed';
    end if;

    -- the position unit must be the Department itself or sit under it
    if new.pos_unit_id <> new.department_id then
      select exists (
        with recursive up as (
          select p.unit_id, p.parent_unit_id
          from core.pos_unit_parent p
          where p.unit_id = new.pos_unit_id
            and p.valid_to is null
          union all
          select p.unit_id, p.parent_unit_id
          from core.pos_unit_parent p
          join up on p.unit_id = up.parent_unit_id
          where p.valid_to is null
        )
        select 1 from up where up.parent_unit_id = new.department_id
      ) into v_inside;

      if not v_inside then
        raise exception 'The position unit is not inside the Department of this job';
      end if;
    end if;

    return new;
  end if;

  -- UPDATE: an allocation is never edited, only closed
  if (new.id, new.company_id, new.org_unit_id, new.department_id, new.eligibility_id,
      new.job_position_id, new.pos_unit_id, new.approved_headcount, new.valid_from)
     is distinct from
     (old.id, old.company_id, old.org_unit_id, old.department_id, old.eligibility_id,
      old.job_position_id, old.pos_unit_id, old.approved_headcount, old.valid_from) then
    raise exception 'Allocations cannot be edited. Close the allocation and create a new one';
  end if;

  if old.valid_to is not null and new.valid_to is distinct from old.valid_to then
    raise exception 'A closed allocation cannot be changed';
  end if;

  return new;
end;
$$;

create trigger position_allocation_guard
  before insert or update on core.position_allocation
  for each row execute function private.position_allocation_guard();

-- ---------------------------------------------------------------
-- Create an allocation (single write path)
-- Finds the matching open eligibility row itself, and refuses a job whose
-- Department the org unit does not list. Not exposed to the frontend yet.
-- ---------------------------------------------------------------
create function private.create_allocation(
  p_company_id      integer,
  p_org_unit_id     integer,
  p_job_position_id integer,
  p_pos_unit_id     integer,
  p_headcount       integer
)
returns integer
language plpgsql
set search_path = ''
as $$
declare
  v_eligibility_id integer;
  v_department_id  integer;
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

  insert into core.position_allocation
    (company_id, org_unit_id, department_id, eligibility_id,
     job_position_id, pos_unit_id, approved_headcount)
  values
    (p_company_id, p_org_unit_id, v_department_id, v_eligibility_id,
     p_job_position_id, p_pos_unit_id, p_headcount)
  returning id into v_id;

  return v_id;
end;
$$;

revoke execute on function private.create_allocation(integer, integer, integer, integer, integer)
  from public, anon;
grant execute on function private.create_allocation(integer, integer, integer, integer, integer)
  to service_role;

-- ---------------------------------------------------------------
-- Replace the guards from 005 so closing cascades to allocations.
-- Everything else in these functions is unchanged.
--   org_unit_guard            : closing a unit closes its allocations
--   pos_unit_guard            : closing a unit closes allocations placed at it
--   job_position_guard        : closing a job closes its allocations
--   org_unit_department_guard : a listing cannot be closed while allocations use it
-- ---------------------------------------------------------------
create or replace function private.org_unit_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if new.valid_to is not null then
      raise exception 'A new org unit must be open (valid_to must be empty)';
    end if;

    if not exists (
      select 1
      from core.company_level_rule r
      where r.company_id = new.company_id
        and r.level_id = new.level_id
        and r.valid_to is null
    ) then
      raise exception 'This level is not enabled for the company';
    end if;

    return new;
  end if;

  -- UPDATE: names can change. Company, level and start date cannot.
  if (new.id, new.company_id, new.tree, new.level_id, new.valid_from)
     is distinct from
     (old.id, old.company_id, old.tree, old.level_id, old.valid_from) then
    raise exception 'Company, level and start date of an org unit cannot be changed';
  end if;

  if old.valid_to is not null and new.valid_to is distinct from old.valid_to then
    raise exception 'A closed org unit cannot be changed';
  end if;

  if old.valid_to is null and new.valid_to is not null then
    if exists (
      select 1
      from core.org_unit_parent p
      where p.parent_unit_id = old.id
        and p.valid_to is null
    ) then
      raise exception 'This unit still has active units under it';
    end if;

    -- allocations first, then the eligibility rows they point at
    update core.position_allocation
    set valid_to = new.valid_to
    where org_unit_id = old.id
      and valid_to is null;

    update core.org_unit_department
    set valid_to = new.valid_to
    where org_unit_id = old.id
      and valid_to is null;

    -- a closed unit must not keep an open link
    update core.org_unit_parent
    set valid_to = new.valid_to
    where unit_id = old.id
      and valid_to is null;
  end if;

  return new;
end;
$$;

create or replace function private.pos_unit_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if new.valid_to is not null then
      raise exception 'A new position unit must be open (valid_to must be empty)';
    end if;

    if not exists (
      select 1
      from core.company_level_rule r
      where r.company_id = new.company_id
        and r.level_id = new.level_id
        and r.valid_to is null
    ) then
      raise exception 'This level is not enabled for the company';
    end if;

    return new;
  end if;

  -- UPDATE: names can change. Company, level and start date cannot.
  if (new.id, new.company_id, new.tree, new.level_id, new.valid_from)
     is distinct from
     (old.id, old.company_id, old.tree, old.level_id, old.valid_from) then
    raise exception 'Company, level and start date of a position unit cannot be changed';
  end if;

  if old.valid_to is not null and new.valid_to is distinct from old.valid_to then
    raise exception 'A closed position unit cannot be changed';
  end if;

  if old.valid_to is null and new.valid_to is not null then
    if exists (
      select 1
      from core.pos_unit_parent p
      where p.parent_unit_id = old.id
        and p.valid_to is null
    ) then
      raise exception 'This unit still has active units under it';
    end if;

    if exists (
      select 1
      from core.job_position j
      where j.department_id = old.id
        and j.valid_to is null
    ) then
      raise exception 'This Department still has active job positions';
    end if;

    -- allocations first, then the eligibility rows they point at
    update core.position_allocation
    set valid_to = new.valid_to
    where valid_to is null
      and (pos_unit_id = old.id or department_id = old.id);

    update core.org_unit_department
    set valid_to = new.valid_to
    where department_id = old.id
      and valid_to is null;

    -- a closed unit must not keep an open link
    update core.pos_unit_parent
    set valid_to = new.valid_to
    where unit_id = old.id
      and valid_to is null;
  end if;

  return new;
end;
$$;

create or replace function private.job_position_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_code text;
begin
  if tg_op = 'INSERT' then
    if new.valid_to is not null then
      raise exception 'A new job position must be open (valid_to must be empty)';
    end if;

    select h.code into v_code
    from core.pos_unit u
    join core.hierarchy_level h on h.id = u.level_id
    where u.id = new.department_id
      and u.valid_to is null;

    if v_code is distinct from 'department' then
      raise exception 'A job position must belong to an open Department';
    end if;

    return new;
  end if;

  -- UPDATE: names can change. Company, department and start date cannot.
  if (new.id, new.company_id, new.department_id, new.valid_from)
     is distinct from
     (old.id, old.company_id, old.department_id, old.valid_from) then
    raise exception 'Company, department and start date of a job position cannot be changed';
  end if;

  if old.valid_to is not null and new.valid_to is distinct from old.valid_to then
    raise exception 'A closed job position cannot be changed';
  end if;

  if old.valid_to is null and new.valid_to is not null then
    update core.position_allocation
    set valid_to = new.valid_to
    where job_position_id = old.id
      and valid_to is null;
  end if;

  return new;
end;
$$;

create or replace function private.org_unit_department_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_code text;
begin
  if tg_op = 'INSERT' then
    if new.valid_to is not null then
      raise exception 'A new eligibility row must be open (valid_to must be empty)';
    end if;

    if not exists (
      select 1 from core.org_unit u
      where u.id = new.org_unit_id and u.valid_to is null
    ) then
      raise exception 'The org unit is closed';
    end if;

    select h.code into v_code
    from core.pos_unit u
    join core.hierarchy_level h on h.id = u.level_id
    where u.id = new.department_id
      and u.valid_to is null;

    if v_code is distinct from 'department' then
      raise exception 'Only an open Department can be listed for an org unit';
    end if;

    return new;
  end if;

  -- UPDATE: never edited, only closed
  if (new.id, new.company_id, new.org_unit_id, new.department_id, new.valid_from)
     is distinct from
     (old.id, old.company_id, old.org_unit_id, old.department_id, old.valid_from) then
    raise exception 'Eligibility rows cannot be edited. Close the row and create a new one';
  end if;

  if old.valid_to is not null and new.valid_to is distinct from old.valid_to then
    raise exception 'A closed eligibility row cannot be changed';
  end if;

  if old.valid_to is null and new.valid_to is not null then
    if exists (
      select 1
      from core.position_allocation a
      where a.eligibility_id = old.id
        and a.valid_to is null
    ) then
      raise exception 'Open allocations still use this Department at this org unit. Close them first';
    end if;
  end if;

  return new;
end;
$$;

-- ---------------------------------------------------------------
-- Row level security and privileges (read-only for logged-in users)
-- ---------------------------------------------------------------
alter table core.position_allocation enable row level security;

create policy position_allocation_select on core.position_allocation
  for select to authenticated
  using (company_id in (select id from core.parent_company));

grant select on core.position_allocation to authenticated;
grant all on core.position_allocation to service_role;

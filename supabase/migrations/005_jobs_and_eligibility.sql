-- 005: job positions and department eligibility
--
--   job_position        : company-wide catalog of titles (e.g. Architect).
--                         Each title belongs to exactly one Department.
--   org_unit_department : which Departments each org unit (Business Unit,
--                         Branch, Division) is allowed to use.
--                         Listed per unit, no inheritance from the parent.
--
-- Together they are what lets allocation (next migration) reject
-- "Architect in the IT Department" or "Architect in a Banking Division":
-- an allocation will only be accepted when the job's Department is listed
-- for the chosen org unit.
--
-- Eligibility rows are versioned like links: closed, never edited. Allocations
-- will point at the exact eligibility row they were made under.

-- ---------------------------------------------------------------
-- Foreign key targets
-- ---------------------------------------------------------------
alter table core.org_unit
  add constraint org_unit_id_company_key unique (id, company_id);

alter table core.pos_unit
  add constraint pos_unit_id_company_key unique (id, company_id);

-- ---------------------------------------------------------------
-- Job positions
-- ---------------------------------------------------------------
create table core.job_position (
  id             integer generated always as identity primary key,
  company_id     integer not null,
  department_id  integer not null,
  name_en        text not null,
  name_km        text,
  valid_from     date not null default current_date,
  valid_to       date,
  created_at     timestamptz not null default now(),

  -- the department exists in the same company
  foreign key (department_id, company_id)
    references core.pos_unit (id, company_id),

  check (valid_to is null or valid_to >= valid_from),

  -- target for composite foreign keys (allocation)
  unique (id, company_id, department_id)
);

-- A title is unique inside its Department while it is open
create unique index job_position_open_name_uq
  on core.job_position (department_id, name_en)
  where valid_to is null;

create index job_position_company_idx on core.job_position (company_id);

-- ---------------------------------------------------------------
-- Department eligibility per org unit
-- ---------------------------------------------------------------
create table core.org_unit_department (
  id             integer generated always as identity primary key,
  company_id     integer not null,
  org_unit_id    integer not null,
  department_id  integer not null,
  valid_from     date not null default current_date,
  valid_to       date,
  created_at     timestamptz not null default now(),

  foreign key (org_unit_id, company_id)
    references core.org_unit (id, company_id),
  foreign key (department_id, company_id)
    references core.pos_unit (id, company_id),

  check (valid_to is null or valid_to >= valid_from),

  -- target for composite foreign keys (allocation)
  unique (id, company_id, org_unit_id, department_id)
);

-- One open row per org unit + department
create unique index org_unit_department_open_uq
  on core.org_unit_department (org_unit_id, department_id)
  where valid_to is null;

create index org_unit_department_company_idx
  on core.org_unit_department (company_id);

create index org_unit_department_dept_idx
  on core.org_unit_department (department_id);

-- ---------------------------------------------------------------
-- Guard: job_position
-- ---------------------------------------------------------------
create function private.job_position_guard()
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

  return new;
end;
$$;

create trigger job_position_guard
  before insert or update on core.job_position
  for each row execute function private.job_position_guard();

-- ---------------------------------------------------------------
-- Guard: org_unit_department
-- ---------------------------------------------------------------
create function private.org_unit_department_guard()
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

  return new;
end;
$$;

create trigger org_unit_department_guard
  before insert or update on core.org_unit_department
  for each row execute function private.org_unit_department_guard();

-- ---------------------------------------------------------------
-- Replace the unit guards from 003 and 004 so closing a unit also
--   - closes its open eligibility rows (they are configuration, not history)
--   - for a Department: refuses while it still has open job positions
-- Everything else in these functions is unchanged.
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

-- ---------------------------------------------------------------
-- Row level security and privileges (read-only for logged-in users)
-- ---------------------------------------------------------------
alter table core.job_position        enable row level security;
alter table core.org_unit_department enable row level security;

create policy job_position_select on core.job_position
  for select to authenticated
  using (company_id in (select id from core.parent_company));

create policy org_unit_department_select on core.org_unit_department
  for select to authenticated
  using (company_id in (select id from core.parent_company));

grant select on core.job_position, core.org_unit_department to authenticated;
grant all on core.job_position, core.org_unit_department to service_role;

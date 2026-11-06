-- 012: roles and permissions (ORG Stage 9b-1)
--
--   app_role            : the 3 starting roles (tenant_admin, hr_admin, viewer)
--   permission          : permission codes, with the narrowest scope each one can be checked at
--   app_role_permission : which role holds which permission
--   member_role_scope   : a role given to a tenant member for one scope:
--                         all companies of the tenant, one company, one org unit
--                         (Business Unit / Branch / Division, subtree included),
--                         or one Department
--
-- This migration only stores roles. It does not change who can read or write.
-- Reads stay open to every tenant member. The check function that resolves a
-- member's permission ("narrower scope replaces the broader one") comes in the
-- next migration. Write functions are still service_role only.
--
-- Table is called app_role (not role) to avoid confusion with database roles
-- such as authenticated and service_role.
--
-- Existing tenant members are given the tenant_admin role for the whole tenant,
-- so nobody is locked out.

-- ---------------------------------------------------------------
-- Small additions to 003 and 004 so a role scope can use composite
-- foreign keys (unit must belong to the stated company)
-- ---------------------------------------------------------------
alter table core.org_unit
  add constraint org_unit_id_company_id_key unique (id, company_id);

alter table core.pos_unit
  add constraint pos_unit_id_company_id_key unique (id, company_id);

-- ---------------------------------------------------------------
-- Role catalog
-- ---------------------------------------------------------------
create table core.app_role (
  id          integer generated always as identity primary key,
  code        text not null unique,
  name_en     text not null,
  name_km     text,
  created_at  timestamptz not null default now()
);

-- applies_to_org_unit / applies_to_department: whether the permission can be
-- checked at that narrower scope. Both false = checked at company or tenant level only.
create table core.permission (
  id                     integer generated always as identity primary key,
  code                   text not null unique,
  name_en                text not null,
  name_km                text,
  applies_to_org_unit    boolean not null default false,
  applies_to_department  boolean not null default false,
  created_at             timestamptz not null default now()
);

create table core.app_role_permission (
  role_id        integer not null references core.app_role (id),
  permission_id  integer not null references core.permission (id),
  created_at     timestamptz not null default now(),
  primary key (role_id, permission_id)
);

-- ---------------------------------------------------------------
-- Role assignments
-- ---------------------------------------------------------------
create table core.member_role_scope (
  id            integer generated always as identity primary key,
  tenant_id     integer not null,
  user_id       uuid not null,
  role_id       integer not null references core.app_role (id),
  scope_kind    text not null
                check (scope_kind in ('tenant', 'company', 'org_unit', 'department')),
  company_id    integer,
  org_unit_id   integer,
  pos_unit_id   integer,   -- the Department (a position unit)
  created_at    timestamptz not null default now(),

  -- the user is a member of the tenant
  foreign key (tenant_id, user_id)
    references core.tenant_member (tenant_id, user_id) on delete cascade,

  -- the company belongs to the member's tenant
  foreign key (tenant_id, company_id)
    references core.parent_company (tenant_id, id),

  -- the unit belongs to the stated company
  foreign key (org_unit_id, company_id)
    references core.org_unit (id, company_id),

  foreign key (pos_unit_id, company_id)
    references core.pos_unit (id, company_id),

  -- each scope kind points at exactly one place
  check (
    (scope_kind = 'tenant'
       and company_id is null and org_unit_id is null and pos_unit_id is null)
    or (scope_kind = 'company'
       and company_id is not null and org_unit_id is null and pos_unit_id is null)
    or (scope_kind = 'org_unit'
       and company_id is not null and org_unit_id is not null and pos_unit_id is null)
    or (scope_kind = 'department'
       and company_id is not null and org_unit_id is null and pos_unit_id is not null)
  )
);

-- One assignment per member per scope
create unique index member_role_scope_tenant_uq
  on core.member_role_scope (tenant_id, user_id)
  where scope_kind = 'tenant';

create unique index member_role_scope_company_uq
  on core.member_role_scope (tenant_id, user_id, company_id)
  where scope_kind = 'company';

create unique index member_role_scope_org_unit_uq
  on core.member_role_scope (tenant_id, user_id, org_unit_id)
  where scope_kind = 'org_unit';

create unique index member_role_scope_department_uq
  on core.member_role_scope (tenant_id, user_id, pos_unit_id)
  where scope_kind = 'department';

create index member_role_scope_user_id_idx
  on core.member_role_scope (user_id);

-- ---------------------------------------------------------------
-- Guard: member_role_scope
-- A new org unit or Department scope must point at an open unit of the
-- stated company (a Department scope must be a real Department).
-- The role can be changed later. The scope cannot: remove and recreate.
-- A unit closed later keeps its assignment, which then grants nothing.
-- ---------------------------------------------------------------
create function private.member_role_scope_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if new.scope_kind = 'org_unit' and not exists (
      select 1
      from core.org_unit u
      where u.id = new.org_unit_id
        and u.company_id = new.company_id
        and u.valid_to is null
    ) then
      raise exception 'The org unit is not an open unit of this company';
    end if;

    if new.scope_kind = 'department' and not exists (
      select 1
      from core.pos_unit p
      join core.hierarchy_level l on l.id = p.level_id
      where p.id = new.pos_unit_id
        and p.company_id = new.company_id
        and p.valid_to is null
        and l.code = 'department'
    ) then
      raise exception 'The position unit is not an open Department of this company';
    end if;

    return new;
  end if;

  -- UPDATE
  if (new.id, new.tenant_id, new.user_id, new.scope_kind,
      new.company_id, new.org_unit_id, new.pos_unit_id)
     is distinct from
     (old.id, old.tenant_id, old.user_id, old.scope_kind,
      old.company_id, old.org_unit_id, old.pos_unit_id) then
    raise exception 'The scope of a role assignment cannot be changed. Remove it and create a new one';
  end if;

  return new;
end;
$$;

create trigger member_role_scope_guard
  before insert or update on core.member_role_scope
  for each row execute function private.member_role_scope_guard();

-- ---------------------------------------------------------------
-- Seed: roles and permissions (reference data the system needs to run)
-- ---------------------------------------------------------------
insert into core.app_role (code, name_en) values
  ('tenant_admin', 'Tenant administrator'),
  ('hr_admin',     'HR administrator'),
  ('viewer',       'Viewer');

insert into core.permission
  (code, name_en, applies_to_org_unit, applies_to_department) values
  ('org.read',              'View organization structure',            false, false),
  ('org.config.write',      'Change hierarchy rules',                 false, false),
  ('org.unit.write',        'Create, close, move org units',          true,  false),
  ('org.eligibility.write', 'List Departments for org units',         true,  false),
  ('pos.unit.write',        'Create, close, move position units',     false, true),
  ('pos.job.write',         'Manage job positions',                   false, true),
  ('org.allocation.write',  'Manage approved headcount allocations',  true,  true),
  ('members.manage',        'Manage members and roles',               false, false);

insert into core.app_role_permission (role_id, permission_id)
select r.id, p.id
from core.app_role r
join core.permission p
  on  r.code = 'tenant_admin'
  or (r.code = 'hr_admin' and p.code <> 'members.manage')
  or (r.code = 'viewer'   and p.code = 'org.read');

-- Existing members become tenant administrators for the whole tenant
insert into core.member_role_scope (tenant_id, user_id, role_id, scope_kind)
select m.tenant_id, m.user_id, r.id, 'tenant'
from core.tenant_member m
cross join core.app_role r
where r.code = 'tenant_admin';

-- ---------------------------------------------------------------
-- Row level security and privileges
-- Catalog tables: readable by logged-in users.
-- Assignments: a user sees only their own rows for now.
-- ---------------------------------------------------------------
alter table core.app_role            enable row level security;
alter table core.permission          enable row level security;
alter table core.app_role_permission enable row level security;
alter table core.member_role_scope   enable row level security;

create policy app_role_select on core.app_role
  for select to authenticated
  using (true);

create policy permission_select on core.permission
  for select to authenticated
  using (true);

create policy app_role_permission_select on core.app_role_permission
  for select to authenticated
  using (true);

create policy member_role_scope_select on core.member_role_scope
  for select to authenticated
  using (user_id = (select auth.uid()));

grant select on
  core.app_role, core.permission, core.app_role_permission, core.member_role_scope
  to authenticated;

grant all on
  core.app_role, core.permission, core.app_role_permission, core.member_role_scope
  to service_role;

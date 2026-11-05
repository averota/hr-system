-- 001: tenancy
--   tenant         : the HRIS account (usually one)
--   parent_company : belongs to one tenant; root of the org structure
--   tenant_member  : which logged-in users can see which tenant
--
-- Access rule (for now): a member sees everything inside their tenant.
-- Roles and per-company access come in a later migration.
-- Frontend users get read-only access here. Writes will go through
-- controlled functions in later migrations.

-- ---------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------
create table core.tenant (
  id          integer generated always as identity primary key,
  name_en     text not null,
  name_km     text,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now()
);

create table core.parent_company (
  id          integer generated always as identity primary key,
  tenant_id   integer not null references core.tenant (id),
  name_en     text not null,
  name_km     text,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  unique (tenant_id, name_en),
  -- target for composite foreign keys in later migrations
  unique (tenant_id, id)
);

create table core.tenant_member (
  tenant_id   integer not null references core.tenant (id),
  user_id     uuid not null references auth.users (id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (tenant_id, user_id)
);

create index tenant_member_user_id_idx on core.tenant_member (user_id);
create index parent_company_tenant_id_idx on core.parent_company (tenant_id);

-- ---------------------------------------------------------------
-- Helper: tenants the current user belongs to
-- security definer so it can read tenant_member without recursive RLS
-- ---------------------------------------------------------------
create function private.user_tenant_ids()
returns setof integer
language sql
stable
security definer
set search_path = ''
as $$
  select tenant_id
  from core.tenant_member
  where user_id = (select auth.uid())
$$;

revoke execute on function private.user_tenant_ids() from public, anon;
grant execute on function private.user_tenant_ids() to authenticated;

-- ---------------------------------------------------------------
-- Row level security
-- ---------------------------------------------------------------
alter table core.tenant         enable row level security;
alter table core.parent_company enable row level security;
alter table core.tenant_member  enable row level security;

create policy tenant_select on core.tenant
  for select to authenticated
  using (id in (select private.user_tenant_ids()));

create policy parent_company_select on core.parent_company
  for select to authenticated
  using (tenant_id in (select private.user_tenant_ids()));

create policy tenant_member_select on core.tenant_member
  for select to authenticated
  using (user_id = (select auth.uid()));

-- ---------------------------------------------------------------
-- Privileges: read-only for logged-in users, full for service_role
-- ---------------------------------------------------------------
grant select on core.tenant, core.parent_company, core.tenant_member
  to authenticated;

grant all on core.tenant, core.parent_company, core.tenant_member
  to service_role;

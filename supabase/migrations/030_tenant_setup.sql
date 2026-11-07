-- 030: tenant setup (PLT Stage 1)
--
--   private.create_tenant_setup(tenant name, company name, admin email)
--       Creates, in one transaction:
--         1. the tenant
--         2. its first parent company
--         3. the membership of the first administrator
--         4. the tenant-wide tenant_admin role for that administrator
--       The login of the administrator must already exist in auth.users
--       (created first by scripts/create-first-admin.mjs, PLT-T012).
--
-- Repeat safe: running it again with the same names and email creates nothing
-- new and returns the same ids (created_* flags are false).
--   - A tenant is found by its English name (ignoring case and outer spaces).
--   - A company is found by its English name inside that tenant.
--   - A different company name for an existing tenant adds a new company.
--
-- Refused with a plain message:
--   - empty tenant name, company name or email
--   - no login exists for the email
--   - the login already belongs to another tenant (one tenant per login, PLT-D12)
--   - the login already has a tenant-wide role other than tenant_admin
--
-- Callable by service_role only (run it in the SQL editor or with the
-- service_role connection). It writes no business date, so it needs no
-- private.org_today().

create function private.create_tenant_setup(
  p_tenant_name   text,
  p_company_name  text,
  p_admin_email   text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tenant_name   text := nullif(btrim(p_tenant_name), '');
  v_company_name  text := nullif(btrim(p_company_name), '');
  v_email         text := nullif(lower(btrim(p_admin_email)), '');
  v_user_id       uuid;
  v_tenant_id     integer;
  v_company_id    integer;
  v_role_id       integer;
  v_assigned_role integer;
  v_new_tenant    boolean := false;
  v_new_company   boolean := false;
  v_new_member    boolean := false;
  v_new_role      boolean := false;
begin
  if v_tenant_name is null then
    raise exception 'The tenant name is required';
  end if;
  if v_company_name is null then
    raise exception 'The company name is required';
  end if;
  if v_email is null then
    raise exception 'The administrator email is required';
  end if;

  -- Two runs at the same moment for the same tenant name wait for each other
  perform pg_advisory_xact_lock(hashtext('create_tenant_setup:' || lower(v_tenant_name)));

  select u.id into v_user_id
  from auth.users u
  where lower(u.email) = v_email
  limit 1;

  if v_user_id is null then
    raise exception 'No login exists for this email. Create the login first';
  end if;

  select r.id into v_role_id
  from core.app_role r
  where r.code = 'tenant_admin';

  if v_role_id is null then
    raise exception 'The tenant_admin role is missing. Apply migration 012 first';
  end if;

  -- Tenant: find by name, else create
  select t.id into v_tenant_id
  from core.tenant t
  where lower(btrim(t.name_en)) = lower(v_tenant_name)
  order by t.id
  limit 1;

  -- One tenant per login (PLT-D12)
  if exists (
    select 1
    from core.tenant_member m
    where m.user_id = v_user_id
      and m.tenant_id is distinct from v_tenant_id
  ) then
    raise exception 'This login already belongs to another tenant';
  end if;

  if v_tenant_id is null then
    insert into core.tenant (name_en)
    values (v_tenant_name)
    returning id into v_tenant_id;
    v_new_tenant := true;
  end if;

  -- Company: find by name inside the tenant, else create
  select c.id into v_company_id
  from core.parent_company c
  where c.tenant_id = v_tenant_id
    and lower(btrim(c.name_en)) = lower(v_company_name)
  order by c.id
  limit 1;

  if v_company_id is null then
    insert into core.parent_company (tenant_id, name_en)
    values (v_tenant_id, v_company_name)
    returning id into v_company_id;
    v_new_company := true;
  end if;

  -- Membership
  insert into core.tenant_member (tenant_id, user_id)
  values (v_tenant_id, v_user_id)
  on conflict (tenant_id, user_id) do nothing;
  v_new_member := found;

  -- Tenant-wide tenant_admin
  insert into core.member_role_scope (tenant_id, user_id, role_id, scope_kind)
  values (v_tenant_id, v_user_id, v_role_id, 'tenant')
  on conflict (tenant_id, user_id) where scope_kind = 'tenant' do nothing;
  v_new_role := found;

  if not v_new_role then
    select s.role_id into v_assigned_role
    from core.member_role_scope s
    where s.tenant_id = v_tenant_id
      and s.user_id = v_user_id
      and s.scope_kind = 'tenant';

    if v_assigned_role is distinct from v_role_id then
      raise exception 'This login already has a tenant-wide role other than tenant_admin';
    end if;
  end if;

  return jsonb_build_object(
    'tenant_id',       v_tenant_id,
    'company_id',      v_company_id,
    'user_id',         v_user_id,
    'created_tenant',  v_new_tenant,
    'created_company', v_new_company,
    'created_member',  v_new_member,
    'created_role',    v_new_role
  );
end;
$$;

revoke execute on function private.create_tenant_setup(text, text, text)
  from public, anon, authenticated;
grant execute on function private.create_tenant_setup(text, text, text)
  to service_role;

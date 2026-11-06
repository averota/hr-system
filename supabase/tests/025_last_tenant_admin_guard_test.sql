-- Test for 025_last_tenant_admin_guard.sql
-- Paste into Supabase Dashboard -> SQL Editor (dev project only).
-- Creates its own tenant and users. Rolls back at the end.
-- "Success. No rows returned" = pass. An error starting with FAIL: = a check failed.

begin;

create function pg_temp.expect_blocked(p_label text, p_sql text)
returns void
language plpgsql
as $$
begin
  begin
    execute p_sql;
  exception when others then
    if sqlerrm = 'A tenant must keep at least one tenant-wide tenant administrator' then
      return;
    end if;
    raise exception 'FAIL: % raised the wrong error: %', p_label, sqlerrm;
  end;
  raise exception 'FAIL: % was not blocked', p_label;
end;
$$;

do $$
declare
  v_tenant   integer;
  v_company  integer;
  v_admin    integer;
  v_viewer   integer;
  v_a        uuid := gen_random_uuid();
  v_b        uuid := gen_random_uuid();
  v_c        uuid := gen_random_uuid();
  v_count    integer;
begin
  select id into v_admin  from core.app_role where code = 'tenant_admin';
  select id into v_viewer from core.app_role where code = 'viewer';

  -- Setup: tenant, company, 3 users
  insert into core.tenant (name_en) values ('Last admin test') returning id into v_tenant;
  insert into core.parent_company (tenant_id, name_en)
    values (v_tenant, 'Last admin test company') returning id into v_company;

  insert into auth.users (id, email) values
    (v_a, 'last-admin-a@test.invalid'),
    (v_b, 'last-admin-b@test.invalid'),
    (v_c, 'last-admin-c@test.invalid');

  insert into core.tenant_member (tenant_id, user_id) values
    (v_tenant, v_a), (v_tenant, v_b), (v_tenant, v_c);

  -- A and B: tenant-wide tenant_admin. C: tenant_admin for one company only (does not count)
  insert into core.member_role_scope (tenant_id, user_id, role_id, scope_kind) values
    (v_tenant, v_a, v_admin, 'tenant'),
    (v_tenant, v_b, v_admin, 'tenant');
  insert into core.member_role_scope (tenant_id, user_id, role_id, scope_kind, company_id)
    values (v_tenant, v_c, v_admin, 'company', v_company);

  -- 1. Downgrading one admin is allowed while another remains
  update core.member_role_scope
     set role_id = v_viewer
   where tenant_id = v_tenant and user_id = v_a and scope_kind = 'tenant';

  -- B is now the last tenant-wide tenant_admin (C is company-scoped and does not count)
  -- 2. Deleting B's assignment is blocked
  perform pg_temp.expect_blocked('delete last admin assignment', format(
    'delete from core.member_role_scope where tenant_id = %s and user_id = %L and scope_kind = ''tenant''',
    v_tenant, v_b));

  -- 3. Changing B's role is blocked
  perform pg_temp.expect_blocked('downgrade last admin', format(
    'update core.member_role_scope set role_id = %s where tenant_id = %s and user_id = %L and scope_kind = ''tenant''',
    v_viewer, v_tenant, v_b));

  -- 4. Removing B from the tenant is blocked (cascade)
  perform pg_temp.expect_blocked('remove last admin member', format(
    'delete from core.tenant_member where tenant_id = %s and user_id = %L',
    v_tenant, v_b));

  -- 5. Deleting B's auth user is blocked (cascade)
  perform pg_temp.expect_blocked('delete last admin user', format(
    'delete from auth.users where id = %L', v_b));

  -- B and C are untouched
  select count(*) into v_count from core.member_role_scope
   where tenant_id = v_tenant and user_id in (v_b, v_c);
  if v_count <> 2 then
    raise exception 'FAIL: blocked changes left % rows for B and C, expected 2', v_count;
  end if;

  -- 6. Removing a non-admin assignment is allowed (A is a viewer now)
  delete from core.member_role_scope
   where tenant_id = v_tenant and user_id = v_a and scope_kind = 'tenant';

  -- 7. An admin can remove their own role when another admin exists
  insert into core.member_role_scope (tenant_id, user_id, role_id, scope_kind)
    values (v_tenant, v_a, v_admin, 'tenant');
  delete from core.member_role_scope
   where tenant_id = v_tenant and user_id = v_a and scope_kind = 'tenant';

  -- 8. Explicit tenant teardown is allowed
  perform set_config('hris.tenant_teardown', 'on', true);
  delete from core.member_role_scope
   where tenant_id = v_tenant and user_id = v_b and scope_kind = 'tenant';
  perform set_config('hris.tenant_teardown', 'off', true);

  select count(*) into v_count from core.member_role_scope
   where tenant_id = v_tenant and scope_kind = 'tenant';
  if v_count <> 0 then
    raise exception 'FAIL: teardown left % tenant-wide assignments, expected 0', v_count;
  end if;
end;
$$;

rollback;

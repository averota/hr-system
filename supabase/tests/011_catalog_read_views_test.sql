-- Test for 011_catalog_read_views.sql
-- Run in Supabase Dashboard -> SQL Editor (dev project only).
-- Rolls back at the end. "Success. No rows returned" = pass.

begin;

do $$
declare
  v_user_a     uuid := gen_random_uuid();
  v_user_b     uuid := gen_random_uuid();
  v_user_none  uuid := gen_random_uuid();
  v_tenant_a   integer;
  v_tenant_b   integer;
  v_comp_a1    integer;
  v_comp_a2    integer;
  v_comp_b1    integer;
begin
  -- 1. Seed test users in auth.users
  insert into auth.users (id, email)
  values
    (v_user_a,    'user_a@test.local'),
    (v_user_b,    'user_b@test.local'),
    (v_user_none, 'user_none@test.local');

  -- 2. Seed two tenants and three companies
  insert into core.tenant (name_en) values ('Tenant A') returning id into v_tenant_a;
  insert into core.tenant (name_en) values ('Tenant B') returning id into v_tenant_b;

  insert into core.parent_company (tenant_id, name_en, name_km, is_active)
  values (v_tenant_a, 'Alpha Corp', 'ក្រុមហ៊ុន អាល់ហ្វា', true)
  returning id into v_comp_a1;

  insert into core.parent_company (tenant_id, name_en, is_active)
  values (v_tenant_a, 'Alpha Inactive Co', false)
  returning id into v_comp_a2;

  insert into core.parent_company (tenant_id, name_en, is_active)
  values (v_tenant_b, 'Beta Corp', true)
  returning id into v_comp_b1;

  insert into core.tenant_member (tenant_id, user_id)
  values
    (v_tenant_a, v_user_a),
    (v_tenant_b, v_user_b);

  -- 3. Switch to authenticated User A
  execute format('set local request.jwt.claim.sub = %L', v_user_a::text);
  execute format(
    'set local request.jwt.claims = %L',
    json_build_object('sub', v_user_a::text, 'role', 'authenticated')::text
  );
  set local role authenticated;

  -- Check parent_companies visibility for User A (sees Tenant A companies only)
  if (
    select count(*)
    from public.parent_companies
    where company_id in (v_comp_a1, v_comp_a2, v_comp_b1)
  ) <> 2 then
    raise exception 'FAIL: User A should see exactly 2 companies from Tenant A';
  end if;

  if exists (
    select 1 from public.parent_companies where company_id = v_comp_b1
  ) then
    raise exception 'FAIL: User A must not see Tenant B company';
  end if;

  if not exists (
    select 1
    from public.parent_companies
    where company_id = v_comp_a1
      and tenant_id = v_tenant_a
      and name_en = 'Alpha Corp'
      and name_km = 'ក្រុមហ៊ុន អាល់ហ្វា'
      and is_active = true
  ) then
    raise exception 'FAIL: parent_companies columns do not match expected values for Alpha Corp';
  end if;

  -- Check hierarchy_levels returns the 7 seeded levels (3 org, 4 pos)
  if (select count(*) from public.hierarchy_levels) <> 7 then
    raise exception 'FAIL: hierarchy_levels should return 7 rows';
  end if;

  if (select count(*) from public.hierarchy_levels where tree = 'org') <> 3
     or (select count(*) from public.hierarchy_levels where tree = 'pos') <> 4 then
    raise exception 'FAIL: hierarchy_levels tree counts should be 3 org and 4 pos';
  end if;

  if not exists (
    select 1
    from public.hierarchy_levels
    where code = 'department'
      and tree = 'pos'
      and rank = 1
      and can_be_root = true
      and is_required = true
  ) then
    raise exception 'FAIL: department row in hierarchy_levels does not match expected flags';
  end if;

  -- 4. Switch to authenticated user with no tenant membership
  set local role postgres;
  execute format('set local request.jwt.claim.sub = %L', v_user_none::text);
  execute format(
    'set local request.jwt.claims = %L',
    json_build_object('sub', v_user_none::text, 'role', 'authenticated')::text
  );
  set local role authenticated;

  if (
    select count(*)
    from public.parent_companies
    where company_id in (v_comp_a1, v_comp_a2, v_comp_b1)
  ) <> 0 then
    raise exception 'FAIL: User with no tenant membership should see 0 parent_companies';
  end if;

  -- 5. Check write rejection on views for authenticated
  begin
    delete from public.parent_companies where company_id = v_comp_a1;
    raise exception 'FAIL: authenticated user must not be able to delete from parent_companies';
  exception
    when insufficient_privilege or object_not_in_prerequisite_state then
      null;
  end;

  -- 6. Switch to anon and verify access is denied on both views
  set local role postgres;
  set local role anon;

  begin
    perform count(*) from public.parent_companies;
    raise exception 'FAIL: anon must not be able to select from parent_companies';
  exception
    when insufficient_privilege then
      null;
  end;

  begin
    perform count(*) from public.hierarchy_levels;
    raise exception 'FAIL: anon must not be able to select from hierarchy_levels';
  exception
    when insufficient_privilege then
      null;
  end;

  set local role postgres;
end;
$$;

rollback;
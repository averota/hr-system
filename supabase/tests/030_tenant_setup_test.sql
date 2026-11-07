-- 030 test: tenant setup (PLT Stage 1)
-- Run in the Supabase SQL editor (one statement, no temp table).
-- The test always ends with an error message, which rolls everything back:
--   "TEST PASSED: all N checks ok"   -> good
--   "TEST FAILED. Failed checks: ..." -> send me the list
--
-- Date check (DT-10): the function writes no business date, so there is
-- nothing to compare with the Phnom Penh date.

do $$
declare
  v_suffix   text := replace(gen_random_uuid()::text, '-', '');
  v_tenant   text := 'PLT Test Tenant ' || v_suffix;
  v_company  text := 'PLT Test Company ' || v_suffix;
  v_user1    uuid := gen_random_uuid();
  v_user2    uuid := gen_random_uuid();
  v_email1   text := 'plt_admin1_' || v_suffix || '@example.test';
  v_email2   text := 'plt_admin2_' || v_suffix || '@example.test';
  r1         jsonb;
  r2         jsonb;
  r3         jsonb;
  v_n        integer;
  v_ok       boolean;
  v_total    integer := 0;
  v_fail     text := '';
begin
  insert into auth.users (id, email) values (v_user1, v_email1), (v_user2, v_email2);

  -- 1. First run creates everything
  r1 := private.create_tenant_setup(v_tenant, v_company, v_email1);
  v_total := v_total + 1;
  if not coalesce(((r1->>'created_tenant')::boolean and (r1->>'created_company')::boolean
    and (r1->>'created_member')::boolean and (r1->>'created_role')::boolean), false) then v_fail := v_fail || E'\n - ' || 'first run creates tenant, company, member, role'; end if;

  v_total := v_total + 1;
  if not coalesce((exists (select 1 from core.tenant where id = (r1->>'tenant_id')::int and name_en = v_tenant)), false) then v_fail := v_fail || E'\n - ' || 'tenant row exists'; end if;
  v_total := v_total + 1;
  if not coalesce((exists (select 1 from core.parent_company
            where id = (r1->>'company_id')::int and tenant_id = (r1->>'tenant_id')::int)), false) then v_fail := v_fail || E'\n - ' || 'company belongs to the tenant'; end if;
  v_total := v_total + 1;
  if not coalesce((exists (select 1 from core.tenant_member
            where tenant_id = (r1->>'tenant_id')::int and user_id = v_user1)), false) then v_fail := v_fail || E'\n - ' || 'membership exists'; end if;
  v_total := v_total + 1;
  if not coalesce((exists (select 1 from core.member_role_scope s
            join core.app_role r on r.id = s.role_id
            where s.tenant_id = (r1->>'tenant_id')::int and s.user_id = v_user1
              and s.scope_kind = 'tenant' and r.code = 'tenant_admin')), false) then v_fail := v_fail || E'\n - ' || 'tenant-wide tenant_admin exists'; end if;

  -- 2. Second run (same input) creates nothing new
  r2 := private.create_tenant_setup(v_tenant, v_company, v_email1);
  v_total := v_total + 1;
  if not coalesce((not (r2->>'created_tenant')::boolean and not (r2->>'created_company')::boolean
    and not (r2->>'created_member')::boolean and not (r2->>'created_role')::boolean), false) then v_fail := v_fail || E'\n - ' || 'second run creates nothing new'; end if;
  v_total := v_total + 1;
  if not coalesce((r1->>'tenant_id' = r2->>'tenant_id' and r1->>'company_id' = r2->>'company_id'), false) then v_fail := v_fail || E'\n - ' || 'second run returns the same ids'; end if;

  -- 3. Different case and spaces still find the same tenant and company
  r3 := private.create_tenant_setup('  ' || upper(v_tenant) || ' ', lower(v_company), upper(v_email1));
  v_total := v_total + 1;
  if not coalesce((r1->>'tenant_id' = r3->>'tenant_id' and r1->>'company_id' = r3->>'company_id'
    and not (r3->>'created_tenant')::boolean and not (r3->>'created_company')::boolean), false) then v_fail := v_fail || E'\n - ' || 'case and spaces reuse the same tenant and company'; end if;

  select count(*) into v_n from core.tenant where lower(name_en) = lower(v_tenant);
  v_total := v_total + 1;
  if not coalesce((v_n = 1), false) then v_fail := v_fail || E'\n - ' || 'no duplicate tenant'; end if;
  select count(*) into v_n from core.parent_company where tenant_id = (r1->>'tenant_id')::int;
  v_total := v_total + 1;
  if not coalesce((v_n = 1), false) then v_fail := v_fail || E'\n - ' || 'no duplicate company'; end if;
  select count(*) into v_n from core.member_role_scope
    where tenant_id = (r1->>'tenant_id')::int and user_id = v_user1;
  v_total := v_total + 1;
  if not coalesce((v_n = 1), false) then v_fail := v_fail || E'\n - ' || 'no duplicate role assignment'; end if;

  -- 4. A new company name for an existing tenant adds a second company
  r3 := private.create_tenant_setup(v_tenant, v_company || ' B', v_email1);
  v_total := v_total + 1;
  if not coalesce((r1->>'tenant_id' = r3->>'tenant_id' and (r3->>'created_company')::boolean), false) then v_fail := v_fail || E'\n - ' || 'new company name adds a company to the same tenant'; end if;

  -- 5. Refusals
  v_ok := false;
  begin
    perform private.create_tenant_setup(v_tenant || ' X', v_company, 'nobody_' || v_suffix || '@example.test');
  exception when others then
    v_ok := position('Create the login first' in sqlerrm) > 0;
  end;
  v_total := v_total + 1;
  if not coalesce((v_ok), false) then v_fail := v_fail || E'\n - ' || 'unknown email is refused with a plain message'; end if;

  v_ok := false;
  begin
    perform private.create_tenant_setup('   ', v_company, v_email1);
  exception when others then
    v_ok := position('tenant name is required' in sqlerrm) > 0;
  end;
  v_total := v_total + 1;
  if not coalesce((v_ok), false) then v_fail := v_fail || E'\n - ' || 'empty tenant name is refused'; end if;

  v_ok := false;
  begin
    perform private.create_tenant_setup(v_tenant, '', v_email1);
  exception when others then
    v_ok := position('company name is required' in sqlerrm) > 0;
  end;
  v_total := v_total + 1;
  if not coalesce((v_ok), false) then v_fail := v_fail || E'\n - ' || 'empty company name is refused'; end if;

  v_ok := false;
  begin
    perform private.create_tenant_setup(v_tenant, v_company, '');
  exception when others then
    v_ok := position('email is required' in sqlerrm) > 0;
  end;
  v_total := v_total + 1;
  if not coalesce((v_ok), false) then v_fail := v_fail || E'\n - ' || 'empty email is refused'; end if;

  -- A login of tenant 1 cannot start a second tenant (PLT-D12)
  v_ok := false;
  begin
    perform private.create_tenant_setup(v_tenant || ' Second', v_company, v_email1);
  exception when others then
    v_ok := position('already belongs to another tenant' in sqlerrm) > 0;
  end;
  v_total := v_total + 1;
  if not coalesce((v_ok), false) then v_fail := v_fail || E'\n - ' || 'login of another tenant is refused'; end if;
  select count(*) into v_n from core.tenant where lower(name_en) = lower(v_tenant || ' Second');
  v_total := v_total + 1;
  if not coalesce((v_n = 0), false) then v_fail := v_fail || E'\n - ' || 'refused run left no tenant behind'; end if;

  -- A login with another tenant-wide role is refused
  r3 := private.create_tenant_setup(v_tenant, v_company, v_email2);   -- second admin
  update core.member_role_scope
     set role_id = (select id from core.app_role where code = 'viewer')
   where tenant_id = (r1->>'tenant_id')::int and user_id = v_user1 and scope_kind = 'tenant';
  v_ok := false;
  begin
    perform private.create_tenant_setup(v_tenant, v_company, v_email1);
  exception when others then
    v_ok := position('other than tenant_admin' in sqlerrm) > 0;
  end;
  v_total := v_total + 1;
  if not coalesce((v_ok), false) then v_fail := v_fail || E'\n - ' || 'login with a different tenant-wide role is refused'; end if;

  -- 6. Privileges
  v_total := v_total + 1;
  if not coalesce((not has_function_privilege('anon', 'private.create_tenant_setup(text, text, text)', 'execute')), false) then v_fail := v_fail || E'\n - ' || 'anon cannot run it'; end if;
  v_total := v_total + 1;
  if not coalesce((not has_function_privilege('authenticated', 'private.create_tenant_setup(text, text, text)', 'execute')), false) then v_fail := v_fail || E'\n - ' || 'authenticated cannot run it'; end if;
  v_total := v_total + 1;
  if not coalesce((has_function_privilege('service_role', 'private.create_tenant_setup(text, text, text)', 'execute')), false) then v_fail := v_fail || E'\n - ' || 'service_role can run it'; end if;

  if v_fail = '' then
    raise exception 'TEST PASSED: all % checks ok (everything rolled back)', v_total;
  else
    raise exception 'TEST FAILED. Failed checks:%', v_fail;
  end if;
end;
$$;

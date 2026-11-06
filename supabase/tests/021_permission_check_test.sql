-- 021 test: public.check_permissions (ORG Stage 9e)
-- DEV project only. Paste into Supabase Dashboard -> SQL Editor.
-- Needs the dev sample data (seed_dev_org_sample.sql):
--   - an org unit that sits under another org unit (two levels)
--   - at least one open Department in the same company
-- Optional (a notice is printed when missing, and those checks are skipped):
--   - a second Department
-- Rolls back at the end. "Success. No rows returned" = pass. "FAIL: ..." = a check failed.

begin;

-- Test helpers (temporary, dropped at the end of the session)
create function pg_temp.new_user(p_tenant integer, p_name text)
returns uuid
language plpgsql
as $$
declare
  v_id uuid := gen_random_uuid();
begin
  insert into auth.users (id, email) values (v_id, p_name || '@check-test.invalid');
  insert into core.tenant_member (tenant_id, user_id) values (p_tenant, v_id);
  return v_id;
end;
$$;

create function pg_temp.assign(
  p_tenant   integer,
  p_user     uuid,
  p_role     text,
  p_kind     text,
  p_company  integer default null,
  p_org_unit integer default null,
  p_pos_unit integer default null
)
returns void
language sql
as $$
  insert into core.member_role_scope
    (tenant_id, user_id, role_id, scope_kind, company_id, org_unit_id, pos_unit_id)
  select p_tenant, p_user, r.id, p_kind, p_company, p_org_unit, p_pos_unit
  from core.app_role r
  where r.code = p_role;
$$;

create function pg_temp.act_as(p_user uuid)
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claim.sub', p_user::text, true);
  perform set_config('request.jwt.claims', json_build_object('sub', p_user)::text, true);
end;
$$;

create function pg_temp.expect(p_label text, p_actual boolean, p_expected boolean)
returns void
language plpgsql
as $$
begin
  if p_actual is distinct from p_expected then
    raise exception 'FAIL: % (expected %, got %)', p_label, p_expected, p_actual;
  end if;
end;
$$;

-- One target through check_permissions
create function pg_temp.allowed(
  p_company integer,
  p_code    text,
  p_org     integer default null,
  p_dept    integer default null
)
returns boolean
language sql
as $$
  select cp.allowed
  from public.check_permissions(
    p_company,
    p_code,
    jsonb_build_array(jsonb_build_object('org_unit_id', p_org, 'department_id', p_dept))
  ) cp
$$;

-- check_permissions must give the same answer as private.has_permission
create function pg_temp.same(
  p_label   text,
  p_company integer,
  p_code    text,
  p_org     integer,
  p_dept    integer
)
returns void
language plpgsql
as $$
begin
  perform pg_temp.expect(
    p_label,
    pg_temp.allowed(p_company, p_code, p_org, p_dept),
    private.has_permission(p_company, p_code, p_org, p_dept)
  );
end;
$$;

do $$
declare
  v_tenant     integer;
  v_company    integer;
  v_tenant2    integer;
  v_company2   integer;
  v_child      integer;
  v_parent     integer;
  v_dept1      integer;
  v_dept2      integer;

  u_none   uuid;
  u_hr     uuid;
  u_view   uuid;
  u_unit   uuid;
  u_dview  uuid;
  u_other  uuid;
  v_user   uuid;

  v_rows   integer;
  v_a      boolean;
  v_b      boolean;
  v_failed boolean;
begin
  -- ------------------------------------------------------------
  -- Pick sample data
  -- ------------------------------------------------------------
  select l.unit_id, l.parent_unit_id, l.company_id
  into v_child, v_parent, v_company
  from core.org_unit_parent l
  join core.org_unit u on u.id = l.unit_id and u.valid_to is null
  where l.valid_to is null
    and l.parent_unit_id is not null
  order by l.unit_id
  limit 1;

  if v_child is null then
    raise exception 'FAIL: test needs the dev sample data - no org unit sitting under another org unit';
  end if;

  select p.id into v_dept1
  from core.pos_unit p
  join core.hierarchy_level l on l.id = p.level_id
  where p.company_id = v_company and p.valid_to is null and l.code = 'department'
  order by p.id
  limit 1;

  if v_dept1 is null then
    raise exception 'FAIL: test needs the dev sample data - no open Department in the company';
  end if;

  select p.id into v_dept2
  from core.pos_unit p
  join core.hierarchy_level l on l.id = p.level_id
  where p.company_id = v_company and p.valid_to is null and l.code = 'department'
    and p.id <> v_dept1
  order by p.id
  limit 1;

  if v_dept2 is null then
    raise notice 'NOTE: only one Department in the sample data, the batch check is skipped';
  end if;

  select tenant_id into v_tenant from core.parent_company where id = v_company;

  insert into core.tenant (name_en) values ('check test tenant')
  returning id into v_tenant2;
  insert into core.parent_company (tenant_id, name_en)
  values (v_tenant2, 'check test company')
  returning id into v_company2;

  -- ------------------------------------------------------------
  -- Users and assignments
  -- ------------------------------------------------------------
  u_none  := pg_temp.new_user(v_tenant, 'none');
  u_hr    := pg_temp.new_user(v_tenant, 'hr');
  u_view  := pg_temp.new_user(v_tenant, 'view');
  u_unit  := pg_temp.new_user(v_tenant, 'unit');
  u_dview := pg_temp.new_user(v_tenant, 'dview');
  u_other := pg_temp.new_user(v_tenant2, 'other');

  perform pg_temp.assign(v_tenant, u_hr,   'hr_admin', 'tenant');
  perform pg_temp.assign(v_tenant, u_view, 'viewer',   'tenant');
  perform pg_temp.assign(v_tenant, u_unit, 'hr_admin', 'org_unit', v_company, v_parent);
  -- company hr_admin, viewer on one Department
  perform pg_temp.assign(v_tenant, u_dview, 'hr_admin', 'company', v_company);
  perform pg_temp.assign(v_tenant, u_dview, 'viewer', 'department', v_company, null, v_dept1);
  perform pg_temp.assign(v_tenant2, u_other, 'tenant_admin', 'tenant');

  -- ------------------------------------------------------------
  -- No login
  -- ------------------------------------------------------------
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claims', '', true);
  perform pg_temp.expect('no login: org.read',
    pg_temp.allowed(v_company, 'org.read'), false);
  perform pg_temp.expect('no login: allocation',
    pg_temp.allowed(v_company, 'org.allocation.write', v_child, v_dept1), false);

  -- ------------------------------------------------------------
  -- Member with no assignment
  -- ------------------------------------------------------------
  perform pg_temp.act_as(u_none);
  perform pg_temp.expect('no assignment: org.read',
    pg_temp.allowed(v_company, 'org.read'), false);
  perform pg_temp.expect('no assignment: allocation',
    pg_temp.allowed(v_company, 'org.allocation.write', v_child, v_dept1), false);

  -- ------------------------------------------------------------
  -- Tenant-wide roles
  -- ------------------------------------------------------------
  perform pg_temp.act_as(u_hr);
  perform pg_temp.expect('hr_admin: org.config.write (default target)',
    pg_temp.allowed(v_company, 'org.config.write'), true);
  perform pg_temp.expect('hr_admin: allocation',
    pg_temp.allowed(v_company, 'org.allocation.write', v_child, v_dept1), true);
  perform pg_temp.expect('hr_admin: org.unit.write at unit',
    pg_temp.allowed(v_company, 'org.unit.write', v_child), true);
  perform pg_temp.expect('hr_admin: pos.job.write at Department',
    pg_temp.allowed(v_company, 'pos.job.write', null, v_dept1), true);
  perform pg_temp.expect('hr_admin: members.manage',
    pg_temp.allowed(v_company, 'members.manage'), false);
  perform pg_temp.expect('hr_admin: unknown permission code',
    pg_temp.allowed(v_company, 'org.nothing'), false);
  perform pg_temp.expect('hr_admin: unknown company',
    pg_temp.allowed(-1, 'org.read'), false);

  -- omitted targets = one empty target
  select count(*) into v_rows
  from public.check_permissions(v_company, 'org.config.write');
  perform pg_temp.expect('default targets give exactly one row', v_rows = 1, true);

  perform pg_temp.act_as(u_view);
  perform pg_temp.expect('viewer: org.read',
    pg_temp.allowed(v_company, 'org.read'), true);
  perform pg_temp.expect('viewer: org.config.write',
    pg_temp.allowed(v_company, 'org.config.write'), false);
  perform pg_temp.expect('viewer: allocation',
    pg_temp.allowed(v_company, 'org.allocation.write', v_child, v_dept1), false);

  -- ------------------------------------------------------------
  -- Org unit scope
  -- ------------------------------------------------------------
  perform pg_temp.act_as(u_unit);
  perform pg_temp.expect('unit admin: org.unit.write at a unit below',
    pg_temp.allowed(v_company, 'org.unit.write', v_child), true);
  perform pg_temp.expect('unit admin: org.unit.write, no unit given',
    pg_temp.allowed(v_company, 'org.unit.write'), false);
  perform pg_temp.expect('unit admin: allocation at unit below',
    pg_temp.allowed(v_company, 'org.allocation.write', v_child, v_dept1), true);
  perform pg_temp.expect('unit admin: org.config.write',
    pg_temp.allowed(v_company, 'org.config.write'), false);

  -- ------------------------------------------------------------
  -- Batch: several targets in one call, restriction on one Department
  -- ------------------------------------------------------------
  perform pg_temp.act_as(u_dview);
  perform pg_temp.expect('restricted Department: allocation for it',
    pg_temp.allowed(v_company, 'org.allocation.write', v_child, v_dept1), false);

  if v_dept2 is not null then
    -- the first target is sent twice: it must come back once
    select count(*) into v_rows
    from public.check_permissions(
      v_company,
      'org.allocation.write',
      jsonb_build_array(
        jsonb_build_object('org_unit_id', v_child, 'department_id', v_dept1),
        jsonb_build_object('org_unit_id', v_child, 'department_id', v_dept2),
        jsonb_build_object('org_unit_id', v_child, 'department_id', v_dept1)
      )
    );
    perform pg_temp.expect('batch: duplicate targets come back once', v_rows = 2, true);

    select cp.allowed into v_a
    from public.check_permissions(
      v_company,
      'org.allocation.write',
      jsonb_build_array(
        jsonb_build_object('org_unit_id', v_child, 'department_id', v_dept1),
        jsonb_build_object('org_unit_id', v_child, 'department_id', v_dept2)
      )
    ) cp
    where cp.department_id = v_dept1;

    select cp.allowed into v_b
    from public.check_permissions(
      v_company,
      'org.allocation.write',
      jsonb_build_array(
        jsonb_build_object('org_unit_id', v_child, 'department_id', v_dept1),
        jsonb_build_object('org_unit_id', v_child, 'department_id', v_dept2)
      )
    ) cp
    where cp.department_id = v_dept2;

    perform pg_temp.expect('batch: restricted Department denied', v_a, false);
    perform pg_temp.expect('batch: other Department allowed', v_b, true);
  end if;

  -- ------------------------------------------------------------
  -- Another tenant
  -- ------------------------------------------------------------
  perform pg_temp.act_as(u_other);
  perform pg_temp.expect('other tenant admin: our company',
    pg_temp.allowed(v_company, 'org.config.write'), false);
  perform pg_temp.expect('other tenant admin: their company',
    pg_temp.allowed(v_company2, 'org.config.write'), true);

  -- ------------------------------------------------------------
  -- Same answer as private.has_permission, for every test user
  -- ------------------------------------------------------------
  foreach v_user in array array[u_none, u_hr, u_view, u_unit, u_dview, u_other]
  loop
    perform pg_temp.act_as(v_user);
    perform pg_temp.same('same as has_permission: org.read',
      v_company, 'org.read', null, null);
    perform pg_temp.same('same as has_permission: org.config.write',
      v_company, 'org.config.write', null, null);
    perform pg_temp.same('same as has_permission: org.unit.write',
      v_company, 'org.unit.write', v_child, null);
    perform pg_temp.same('same as has_permission: pos.job.write',
      v_company, 'pos.job.write', null, v_dept1);
    perform pg_temp.same('same as has_permission: org.allocation.write',
      v_company, 'org.allocation.write', v_child, v_dept1);
  end loop;

  -- ------------------------------------------------------------
  -- Input checks
  -- ------------------------------------------------------------
  perform pg_temp.act_as(u_hr);

  select count(*) into v_rows
  from public.check_permissions(v_company, 'org.read', '[]'::jsonb);
  perform pg_temp.expect('empty target list gives no rows', v_rows = 0, true);

  v_failed := false;
  begin
    perform 1 from public.check_permissions(
      v_company, 'org.read', '{"org_unit_id": 1}'::jsonb);
  exception when others then
    v_failed := true;
  end;
  perform pg_temp.expect('an object instead of an array is refused', v_failed, true);

  v_failed := false;
  begin
    perform 1 from public.check_permissions(
      v_company, 'org.read', (select jsonb_agg('{}'::jsonb) from generate_series(1, 501)));
  exception when others then
    v_failed := true;
  end;
  perform pg_temp.expect('more than 500 targets is refused', v_failed, true);

  -- ------------------------------------------------------------
  -- Privileges
  -- ------------------------------------------------------------
  perform pg_temp.expect('anon cannot execute',
    has_function_privilege('anon', 'public.check_permissions(integer, text, jsonb)', 'execute'),
    false);
  perform pg_temp.expect('authenticated can execute',
    has_function_privilege('authenticated', 'public.check_permissions(integer, text, jsonb)', 'execute'),
    true);
  perform pg_temp.expect('service_role can execute',
    has_function_privilege('service_role', 'public.check_permissions(integer, text, jsonb)', 'execute'),
    true);
end;
$$;

rollback;

-- 012 test: roles and permissions (ORG Stage 9b-1)
-- DEV project only. Paste into Supabase Dashboard -> SQL Editor.
-- Needs the dev sample data (seed_dev_org_sample.sql): at least one open org unit
-- and one open Department in the same company.
-- Rolls back at the end. "Success. No rows returned" = pass. "FAIL: ..." = a check failed.

begin;

do $$
declare
  v_tenant       integer;
  v_company      integer;
  v_org_unit     integer;
  v_dept         integer;
  v_other_pos    integer;
  v_leaf         integer;
  v_leaf_from    date;
  v_tenant2      integer;
  v_company2     integer;
  v_user_a       uuid := gen_random_uuid();
  v_user_b       uuid := gen_random_uuid();
  v_admin_role   integer;
  v_hr_role      integer;
  v_viewer_role  integer;
  v_scope_id     integer;
  v_cnt          integer;
  v_cnt_a        integer;
  v_seen         integer;
  v_seen_others  integer;
  v_seen_roles   integer;
  v_write_ok     boolean;
  v_anon_ok      boolean;
begin
  -- ------------------------------------------------------------
  -- 1. Seed data
  -- ------------------------------------------------------------
  select id into v_admin_role  from core.app_role where code = 'tenant_admin';
  select id into v_hr_role     from core.app_role where code = 'hr_admin';
  select id into v_viewer_role from core.app_role where code = 'viewer';

  if v_admin_role is null or v_hr_role is null or v_viewer_role is null then
    raise exception 'FAIL: the 3 roles are not all seeded';
  end if;

  select count(*) into v_cnt from core.app_role;
  if v_cnt <> 3 then
    raise exception 'FAIL: expected 3 roles, found %', v_cnt;
  end if;

  select count(*) into v_cnt from core.permission;
  if v_cnt <> 8 then
    raise exception 'FAIL: expected 8 permissions, found %', v_cnt;
  end if;

  select count(*) into v_cnt from core.app_role_permission where role_id = v_admin_role;
  if v_cnt <> 8 then
    raise exception 'FAIL: tenant_admin should hold 8 permissions, found %', v_cnt;
  end if;

  select count(*) into v_cnt from core.app_role_permission where role_id = v_hr_role;
  if v_cnt <> 7 then
    raise exception 'FAIL: hr_admin should hold 7 permissions, found %', v_cnt;
  end if;

  if exists (
    select 1
    from core.app_role_permission rp
    join core.permission p on p.id = rp.permission_id
    where rp.role_id = v_hr_role and p.code = 'members.manage'
  ) then
    raise exception 'FAIL: hr_admin must not hold members.manage';
  end if;

  select count(*) into v_cnt from core.app_role_permission where role_id = v_viewer_role;
  if v_cnt <> 1 or not exists (
    select 1
    from core.app_role_permission rp
    join core.permission p on p.id = rp.permission_id
    where rp.role_id = v_viewer_role and p.code = 'org.read'
  ) then
    raise exception 'FAIL: viewer should hold only org.read';
  end if;

  -- scope flags
  if not exists (select 1 from core.permission
                 where code = 'org.allocation.write'
                   and applies_to_org_unit and applies_to_department) then
    raise exception 'FAIL: org.allocation.write should apply to org unit and Department';
  end if;

  if not exists (select 1 from core.permission
                 where code in ('org.unit.write', 'org.eligibility.write')
                   and applies_to_org_unit and not applies_to_department
                 having count(*) = 2) then
    raise exception 'FAIL: org.unit.write and org.eligibility.write should apply to org unit only';
  end if;

  if not exists (select 1 from core.permission
                 where code in ('pos.unit.write', 'pos.job.write')
                   and applies_to_department and not applies_to_org_unit
                 having count(*) = 2) then
    raise exception 'FAIL: pos.unit.write and pos.job.write should apply to Department only';
  end if;

  if exists (select 1 from core.permission
             where code in ('org.read', 'org.config.write', 'members.manage')
               and (applies_to_org_unit or applies_to_department)) then
    raise exception 'FAIL: org.read, org.config.write and members.manage should apply at company or tenant level only';
  end if;

  -- ------------------------------------------------------------
  -- 2. Existing members were migrated to tenant_admin
  -- ------------------------------------------------------------
  select count(*) into v_cnt
  from core.tenant_member m
  where not exists (
    select 1 from core.member_role_scope s
    where s.tenant_id = m.tenant_id
      and s.user_id = m.user_id
      and s.scope_kind = 'tenant'
  );
  if v_cnt <> 0 then
    raise exception 'FAIL: % tenant member(s) have no tenant-wide role (migration should have made them tenant_admin)', v_cnt;
  end if;

  -- ------------------------------------------------------------
  -- 3. Test data (rolled back at the end)
  -- ------------------------------------------------------------
  select u.id, u.company_id into v_org_unit, v_company
  from core.org_unit u
  where u.valid_to is null
  order by u.id
  limit 1;

  if v_org_unit is null then
    raise exception 'FAIL: test needs the dev sample data - no open org unit found';
  end if;

  select p.id into v_dept
  from core.pos_unit p
  join core.hierarchy_level l on l.id = p.level_id
  where p.company_id = v_company
    and p.valid_to is null
    and l.code = 'department'
  order by p.id
  limit 1;

  if v_dept is null then
    raise exception 'FAIL: test needs the dev sample data - no open Department in the same company as the org unit';
  end if;

  select tenant_id into v_tenant from core.parent_company where id = v_company;

  insert into core.tenant (name_en) values ('roles test tenant')
  returning id into v_tenant2;

  insert into core.parent_company (tenant_id, name_en)
  values (v_tenant2, 'roles test company')
  returning id into v_company2;

  insert into auth.users (id, email) values
    (v_user_a, 'roles-test-a@example.invalid'),
    (v_user_b, 'roles-test-b@example.invalid');

  insert into core.tenant_member (tenant_id, user_id) values
    (v_tenant, v_user_a),
    (v_tenant, v_user_b);

  -- ------------------------------------------------------------
  -- 4. Valid assignments
  -- ------------------------------------------------------------
  insert into core.member_role_scope (tenant_id, user_id, role_id, scope_kind, company_id)
  values (v_tenant, v_user_a, v_hr_role, 'company', v_company);

  insert into core.member_role_scope
    (tenant_id, user_id, role_id, scope_kind, company_id, org_unit_id)
  values (v_tenant, v_user_a, v_viewer_role, 'org_unit', v_company, v_org_unit);

  insert into core.member_role_scope
    (tenant_id, user_id, role_id, scope_kind, company_id, pos_unit_id)
  values (v_tenant, v_user_a, v_viewer_role, 'department', v_company, v_dept);

  insert into core.member_role_scope (tenant_id, user_id, role_id, scope_kind)
  values (v_tenant, v_user_b, v_admin_role, 'tenant');

  -- ------------------------------------------------------------
  -- 5. One assignment per scope
  -- ------------------------------------------------------------
  begin
    insert into core.member_role_scope (tenant_id, user_id, role_id, scope_kind, company_id)
    values (v_tenant, v_user_a, v_viewer_role, 'company', v_company);
    raise exception 'FAIL: a second company assignment for the same member was accepted';
  exception
    when unique_violation then null;
  end;

  begin
    insert into core.member_role_scope
      (tenant_id, user_id, role_id, scope_kind, company_id, org_unit_id)
    values (v_tenant, v_user_a, v_hr_role, 'org_unit', v_company, v_org_unit);
    raise exception 'FAIL: a second org unit assignment for the same member was accepted';
  exception
    when unique_violation then null;
  end;

  begin
    insert into core.member_role_scope
      (tenant_id, user_id, role_id, scope_kind, company_id, pos_unit_id)
    values (v_tenant, v_user_a, v_hr_role, 'department', v_company, v_dept);
    raise exception 'FAIL: a second Department assignment for the same member was accepted';
  exception
    when unique_violation then null;
  end;

  begin
    insert into core.member_role_scope (tenant_id, user_id, role_id, scope_kind)
    values (v_tenant, v_user_b, v_hr_role, 'tenant');
    raise exception 'FAIL: a second tenant-wide assignment for the same member was accepted';
  exception
    when unique_violation then null;
  end;

  -- ------------------------------------------------------------
  -- 6. Each scope kind must point at exactly one place
  -- ------------------------------------------------------------
  begin
    insert into core.member_role_scope (tenant_id, user_id, role_id, scope_kind, company_id)
    values (v_tenant, v_user_a, v_viewer_role, 'tenant', v_company);
    raise exception 'FAIL: tenant scope with a company was accepted';
  exception
    when check_violation then null;
  end;

  begin
    insert into core.member_role_scope (tenant_id, user_id, role_id, scope_kind)
    values (v_tenant, v_user_a, v_viewer_role, 'company');
    raise exception 'FAIL: company scope without a company was accepted';
  exception
    when check_violation then null;
  end;

  begin
    insert into core.member_role_scope
      (tenant_id, user_id, role_id, scope_kind, company_id, org_unit_id, pos_unit_id)
    values (v_tenant, v_user_b, v_viewer_role, 'department', v_company, v_org_unit, v_dept);
    raise exception 'FAIL: Department scope with an org unit was accepted';
  exception
    when check_violation then null;
  end;

  begin
    insert into core.member_role_scope (tenant_id, user_id, role_id, scope_kind)
    values (v_tenant, v_user_b, v_viewer_role, 'branch');
    raise exception 'FAIL: unknown scope kind was accepted';
  exception
    when check_violation then null;
  end;

  -- ------------------------------------------------------------
  -- 7. Company and unit must belong to the right tenant / company
  -- ------------------------------------------------------------
  begin
    insert into core.member_role_scope (tenant_id, user_id, role_id, scope_kind, company_id)
    values (v_tenant, v_user_b, v_viewer_role, 'company', v_company2);
    raise exception 'FAIL: a company of another tenant was accepted';
  exception
    when foreign_key_violation then null;
  end;

  begin
    insert into core.member_role_scope
      (tenant_id, user_id, role_id, scope_kind, company_id, org_unit_id)
    values (v_tenant, v_user_b, v_viewer_role, 'org_unit', v_company2, v_org_unit);
    raise exception 'FAIL: an org unit with another company was accepted';
  exception
    when raise_exception then
      if sqlerrm like 'FAIL:%' then raise; end if;
      if sqlerrm not like '%is not an open unit of this company%' then
        raise exception 'FAIL: wrong error message: %', sqlerrm;
      end if;
  end;

  begin
    insert into core.member_role_scope
      (tenant_id, user_id, role_id, scope_kind, company_id, pos_unit_id)
    values (v_tenant, v_user_b, v_viewer_role, 'department', v_company2, v_dept);
    raise exception 'FAIL: a Department with another company was accepted';
  exception
    when raise_exception then
      if sqlerrm like 'FAIL:%' then raise; end if;
      if sqlerrm not like '%is not an open Department of this company%' then
        raise exception 'FAIL: wrong error message: %', sqlerrm;
      end if;
  end;

  -- Department scope must be a Department (not an Office, Section or Group)
  select p.id into v_other_pos
  from core.pos_unit p
  join core.hierarchy_level l on l.id = p.level_id
  where p.company_id = v_company
    and p.valid_to is null
    and l.code <> 'department'
  order by p.id
  limit 1;

  if v_other_pos is null then
    raise notice 'SKIPPED: no Office, Section or Group in the sample data, "must be a Department" not tested';
  else
    begin
      insert into core.member_role_scope
        (tenant_id, user_id, role_id, scope_kind, company_id, pos_unit_id)
      values (v_tenant, v_user_b, v_viewer_role, 'department', v_company, v_other_pos);
      raise exception 'FAIL: a non-Department position unit was accepted as a Department scope';
    exception
      when raise_exception then
        if sqlerrm like 'FAIL:%' then raise; end if;
        if sqlerrm not like '%is not an open Department of this company%' then
          raise exception 'FAIL: wrong error message: %', sqlerrm;
        end if;
    end;
  end if;

  -- A closed org unit cannot be given as a new scope
  select u.id, u.valid_from into v_leaf, v_leaf_from
  from core.org_unit u
  where u.valid_to is null
    and u.company_id = v_company
    and not exists (
      select 1 from core.org_unit_parent p
      where p.parent_unit_id = u.id and p.valid_to is null
    )
  order by u.id
  limit 1;

  if v_leaf is null then
    raise notice 'SKIPPED: no org unit without children in the sample data, "closed unit" not tested';
  else
    perform private.close_org_unit(v_company, v_leaf, greatest(current_date, v_leaf_from));

    begin
      insert into core.member_role_scope
        (tenant_id, user_id, role_id, scope_kind, company_id, org_unit_id)
      values (v_tenant, v_user_b, v_viewer_role, 'org_unit', v_company, v_leaf);
      raise exception 'FAIL: a closed org unit was accepted as a scope';
    exception
      when raise_exception then
        if sqlerrm like 'FAIL:%' then raise; end if;
        if sqlerrm not like '%is not an open unit of this company%' then
          raise exception 'FAIL: wrong error message: %', sqlerrm;
        end if;
    end;
  end if;

  -- ------------------------------------------------------------
  -- 8. Scope cannot change, role can
  -- ------------------------------------------------------------
  select id into v_scope_id
  from core.member_role_scope
  where user_id = v_user_a and scope_kind = 'company';

  begin
    update core.member_role_scope
    set scope_kind = 'tenant', company_id = null
    where id = v_scope_id;
    raise exception 'FAIL: the scope of an assignment was changed';
  exception
    when raise_exception then
      if sqlerrm like 'FAIL:%' then raise; end if;
      if sqlerrm not like '%cannot be changed%' then
        raise exception 'FAIL: wrong error message: %', sqlerrm;
      end if;
  end;

  update core.member_role_scope set role_id = v_viewer_role where id = v_scope_id;

  if not exists (select 1 from core.member_role_scope
                 where id = v_scope_id and role_id = v_viewer_role) then
    raise exception 'FAIL: the role of an assignment could not be changed';
  end if;

  -- ------------------------------------------------------------
  -- 9. Visibility for logged-in users and anonymous visitors
  -- ------------------------------------------------------------
  select count(*) into v_cnt_a from core.member_role_scope where user_id = v_user_a;
  if v_cnt_a <> 3 then
    raise exception 'FAIL: user A should have 3 assignments, found %', v_cnt_a;
  end if;

  perform set_config('request.jwt.claim.sub', v_user_a::text, true);
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_user_a, 'role', 'authenticated')::text, true);

  set local role authenticated;

  select count(*) into v_seen from core.member_role_scope;
  select count(*) into v_seen_others from core.member_role_scope where user_id <> v_user_a;
  select count(*) into v_seen_roles from core.app_role;

  begin
    insert into core.member_role_scope (tenant_id, user_id, role_id, scope_kind)
    values (v_tenant, v_user_a, v_admin_role, 'tenant');
    v_write_ok := true;
  exception
    when insufficient_privilege then v_write_ok := false;
  end;

  reset role;

  if v_seen <> v_cnt_a then
    raise exception 'FAIL: a user should see only their own assignments (expected %, saw %)', v_cnt_a, v_seen;
  end if;
  if v_seen_others <> 0 then
    raise exception 'FAIL: a user saw assignments of other users';
  end if;
  if v_seen_roles <> 3 then
    raise exception 'FAIL: a logged-in user should read the 3 roles, saw %', v_seen_roles;
  end if;
  if v_write_ok then
    raise exception 'FAIL: a logged-in user could write role assignments';
  end if;

  set local role anon;

  begin
    select count(*) into v_seen from core.member_role_scope;
    v_anon_ok := true;
  exception
    when insufficient_privilege then v_anon_ok := false;
  end;

  reset role;

  if v_anon_ok then
    raise exception 'FAIL: an anonymous visitor could read role assignments';
  end if;
end;
$$;

rollback;

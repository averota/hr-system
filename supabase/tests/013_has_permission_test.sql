-- 013 test: permission check (ORG Stage 9b-2)
-- DEV project only. Paste into Supabase Dashboard -> SQL Editor.
-- Needs the dev sample data (seed_dev_org_sample.sql):
--   - an org unit that sits under another org unit (two levels)
--   - at least one open Department in the same company
-- Optional (a notice is printed when missing, and those checks are skipped):
--   - a second Department, an org unit outside the parent's subtree,
--     an Office/Section/Group
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
  insert into auth.users (id, email) values (v_id, p_name || '@roles-test.invalid');
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

do $$
declare
  v_tenant     integer;
  v_company    integer;
  v_tenant2    integer;
  v_company2   integer;
  v_child      integer;
  v_parent     integer;
  v_other      integer;
  v_dept1      integer;
  v_dept2      integer;
  v_other_pos  integer;

  u_none   uuid;
  u_hr     uuid;
  u_admin  uuid;
  u_view   uuid;
  u_unit   uuid;
  u_up     uuid;
  u_down   uuid;
  u_near   uuid;
  u_dept   uuid;
  u_dview  uuid;
  u_mix    uuid;
  u_other  uuid;
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

  select p.id into v_other_pos
  from core.pos_unit p
  join core.hierarchy_level l on l.id = p.level_id
  where p.company_id = v_company and p.valid_to is null and l.code <> 'department'
  order by p.id
  limit 1;

  -- an open org unit outside the parent's subtree
  select u.id into v_other
  from core.org_unit u
  where u.company_id = v_company
    and u.valid_to is null
    and u.id not in (
      with recursive down as (
        select v_parent as id
        union all
        select l.unit_id
        from down d
        join core.org_unit_parent l
          on l.parent_unit_id = d.id and l.valid_to is null
      )
      select id from down
    )
  order by u.id
  limit 1;

  if v_dept2 is null then
    raise notice 'NOTE: only one Department in the sample data, some Department checks are skipped';
  end if;
  if v_other is null then
    raise notice 'NOTE: no org unit outside the parent''s subtree, some org unit checks are skipped';
  end if;
  if v_other_pos is null then
    raise notice 'NOTE: no Office/Section/Group in the sample data, "not a Department" check is skipped';
  end if;

  select tenant_id into v_tenant from core.parent_company where id = v_company;

  insert into core.tenant (name_en) values ('perm test tenant')
  returning id into v_tenant2;
  insert into core.parent_company (tenant_id, name_en)
  values (v_tenant2, 'perm test company')
  returning id into v_company2;

  -- ------------------------------------------------------------
  -- Users and assignments
  -- ------------------------------------------------------------
  u_none  := pg_temp.new_user(v_tenant, 'none');
  u_hr    := pg_temp.new_user(v_tenant, 'hr');
  u_admin := pg_temp.new_user(v_tenant, 'admin');
  u_view  := pg_temp.new_user(v_tenant, 'view');
  u_unit  := pg_temp.new_user(v_tenant, 'unit');
  u_up    := pg_temp.new_user(v_tenant, 'up');
  u_down  := pg_temp.new_user(v_tenant, 'down');
  u_near  := pg_temp.new_user(v_tenant, 'near');
  u_dept  := pg_temp.new_user(v_tenant, 'dept');
  u_dview := pg_temp.new_user(v_tenant, 'dview');
  u_mix   := pg_temp.new_user(v_tenant, 'mix');
  u_other := pg_temp.new_user(v_tenant2, 'other');

  perform pg_temp.assign(v_tenant, u_hr,    'hr_admin',     'tenant');
  perform pg_temp.assign(v_tenant, u_admin, 'tenant_admin', 'tenant');
  perform pg_temp.assign(v_tenant, u_view,  'viewer',       'tenant');

  -- hr_admin on the parent org unit only
  perform pg_temp.assign(v_tenant, u_unit, 'hr_admin', 'org_unit', v_company, v_parent);

  -- tenant viewer, upgraded on the parent org unit
  perform pg_temp.assign(v_tenant, u_up, 'viewer',   'tenant');
  perform pg_temp.assign(v_tenant, u_up, 'hr_admin', 'org_unit', v_company, v_parent);

  -- tenant hr_admin, restricted on the parent org unit
  perform pg_temp.assign(v_tenant, u_down, 'hr_admin', 'tenant');
  perform pg_temp.assign(v_tenant, u_down, 'viewer',   'org_unit', v_company, v_parent);

  -- parent: hr_admin, child: viewer (nearest wins)
  perform pg_temp.assign(v_tenant, u_near, 'hr_admin', 'org_unit', v_company, v_parent);
  perform pg_temp.assign(v_tenant, u_near, 'viewer',   'org_unit', v_company, v_child);

  -- hr_admin on one Department only
  perform pg_temp.assign(v_tenant, u_dept, 'hr_admin', 'department', v_company, null, v_dept1);

  -- company hr_admin, restricted on one Department
  perform pg_temp.assign(v_tenant, u_dview, 'hr_admin', 'company', v_company);
  perform pg_temp.assign(v_tenant, u_dview, 'viewer',   'department', v_company, null, v_dept1);

  -- hr_admin on the parent org unit, viewer on one Department
  perform pg_temp.assign(v_tenant, u_mix, 'hr_admin', 'org_unit', v_company, v_parent);
  perform pg_temp.assign(v_tenant, u_mix, 'viewer',   'department', v_company, null, v_dept1);

  perform pg_temp.assign(v_tenant2, u_other, 'tenant_admin', 'tenant');

  -- ------------------------------------------------------------
  -- No login
  -- ------------------------------------------------------------
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claims', '', true);
  perform pg_temp.expect('no login: org.read',
    private.has_permission(v_company, 'org.read'), false);
  perform pg_temp.expect('no login: members.manage (tenant)',
    private.has_tenant_permission(v_tenant, 'members.manage'), false);

  -- ------------------------------------------------------------
  -- Member with no assignment
  -- ------------------------------------------------------------
  perform pg_temp.act_as(u_none);
  perform pg_temp.expect('no assignment: org.read',
    private.has_permission(v_company, 'org.read'), false);
  perform pg_temp.expect('no assignment: org.unit.write at unit',
    private.has_permission(v_company, 'org.unit.write', v_child), false);

  -- ------------------------------------------------------------
  -- Tenant-wide roles
  -- ------------------------------------------------------------
  perform pg_temp.act_as(u_hr);
  perform pg_temp.expect('hr_admin: org.unit.write, no unit given',
    private.has_permission(v_company, 'org.unit.write'), true);
  perform pg_temp.expect('hr_admin: org.unit.write at unit',
    private.has_permission(v_company, 'org.unit.write', v_child), true);
  perform pg_temp.expect('hr_admin: org.config.write',
    private.has_permission(v_company, 'org.config.write'), true);
  perform pg_temp.expect('hr_admin: pos.job.write at Department',
    private.has_permission(v_company, 'pos.job.write', null, v_dept1), true);
  perform pg_temp.expect('hr_admin: org.allocation.write',
    private.has_permission(v_company, 'org.allocation.write', v_child, v_dept1), true);
  perform pg_temp.expect('hr_admin: members.manage',
    private.has_permission(v_company, 'members.manage'), false);
  perform pg_temp.expect('hr_admin: members.manage (tenant)',
    private.has_tenant_permission(v_tenant, 'members.manage'), false);
  perform pg_temp.expect('unknown permission code',
    private.has_permission(v_company, 'org.nothing'), false);
  perform pg_temp.expect('unknown company',
    private.has_permission(-1, 'org.read'), false);
  if v_other_pos is not null then
    perform pg_temp.expect('Department id that is not a Department',
      private.has_permission(v_company, 'pos.job.write', null, v_other_pos), false);
  end if;

  perform pg_temp.act_as(u_admin);
  perform pg_temp.expect('tenant_admin: members.manage',
    private.has_permission(v_company, 'members.manage'), true);
  perform pg_temp.expect('tenant_admin: members.manage (tenant)',
    private.has_tenant_permission(v_tenant, 'members.manage'), true);

  perform pg_temp.act_as(u_view);
  perform pg_temp.expect('viewer: org.read',
    private.has_permission(v_company, 'org.read'), true);
  perform pg_temp.expect('viewer: org.unit.write at unit',
    private.has_permission(v_company, 'org.unit.write', v_child), false);
  perform pg_temp.expect('viewer: org.allocation.write',
    private.has_permission(v_company, 'org.allocation.write', v_child, v_dept1), false);

  -- ------------------------------------------------------------
  -- Another tenant
  -- ------------------------------------------------------------
  perform pg_temp.act_as(u_other);
  perform pg_temp.expect('other tenant admin: org.config.write on our company',
    private.has_permission(v_company, 'org.config.write'), false);
  perform pg_temp.expect('other tenant admin: members.manage (our tenant)',
    private.has_tenant_permission(v_tenant, 'members.manage'), false);
  perform pg_temp.expect('other tenant admin: org.config.write on their company',
    private.has_permission(v_company2, 'org.config.write'), true);
  perform pg_temp.expect('org unit of another company is not a valid target',
    private.has_permission(v_company2, 'org.unit.write', v_child), false);

  -- ------------------------------------------------------------
  -- Org unit scope (subtree included)
  -- ------------------------------------------------------------
  perform pg_temp.act_as(u_unit);
  perform pg_temp.expect('unit admin: org.unit.write at the unit',
    private.has_permission(v_company, 'org.unit.write', v_parent), true);
  perform pg_temp.expect('unit admin: org.unit.write at a unit below',
    private.has_permission(v_company, 'org.unit.write', v_child), true);
  perform pg_temp.expect('unit admin: org.unit.write, no unit given',
    private.has_permission(v_company, 'org.unit.write'), false);
  perform pg_temp.expect('unit admin: org.config.write',
    private.has_permission(v_company, 'org.config.write'), false);
  perform pg_temp.expect('unit admin: org.read (no broad role)',
    private.has_permission(v_company, 'org.read'), false);
  perform pg_temp.expect('unit admin: allocation at unit below, any Department',
    private.has_permission(v_company, 'org.allocation.write', v_child, v_dept1), true);
  perform pg_temp.expect('unit admin: pos.job.write (Department side, no assignment)',
    private.has_permission(v_company, 'pos.job.write', null, v_dept1), false);
  if v_other is not null then
    perform pg_temp.expect('unit admin: org.unit.write outside the subtree',
      private.has_permission(v_company, 'org.unit.write', v_other), false);
    perform pg_temp.expect('unit admin: allocation outside the subtree',
      private.has_permission(v_company, 'org.allocation.write', v_other, v_dept1), false);
  end if;

  -- narrower replaces broader: viewer everywhere, hr_admin on the unit
  perform pg_temp.act_as(u_up);
  perform pg_temp.expect('upgraded: org.unit.write at unit below',
    private.has_permission(v_company, 'org.unit.write', v_child), true);
  perform pg_temp.expect('upgraded: org.config.write (broad viewer)',
    private.has_permission(v_company, 'org.config.write'), false);
  perform pg_temp.expect('upgraded: org.read (broad viewer)',
    private.has_permission(v_company, 'org.read'), true);
  if v_other is not null then
    perform pg_temp.expect('upgraded: org.unit.write outside the subtree',
      private.has_permission(v_company, 'org.unit.write', v_other), false);
  end if;

  -- narrower replaces broader: hr_admin everywhere, viewer on the unit
  perform pg_temp.act_as(u_down);
  perform pg_temp.expect('restricted: org.unit.write at unit below',
    private.has_permission(v_company, 'org.unit.write', v_child), false);
  perform pg_temp.expect('restricted: org.config.write (broad hr_admin)',
    private.has_permission(v_company, 'org.config.write'), true);
  if v_other is not null then
    perform pg_temp.expect('restricted: org.unit.write outside the unit',
      private.has_permission(v_company, 'org.unit.write', v_other), true);
  end if;

  -- nearest assignment wins
  perform pg_temp.act_as(u_near);
  perform pg_temp.expect('nearest: org.unit.write at the parent',
    private.has_permission(v_company, 'org.unit.write', v_parent), true);
  perform pg_temp.expect('nearest: org.unit.write at the child (viewer)',
    private.has_permission(v_company, 'org.unit.write', v_child), false);

  -- ------------------------------------------------------------
  -- Department scope
  -- ------------------------------------------------------------
  perform pg_temp.act_as(u_dept);
  perform pg_temp.expect('Department admin: pos.job.write at the Department',
    private.has_permission(v_company, 'pos.job.write', null, v_dept1), true);
  perform pg_temp.expect('Department admin: pos.job.write, no Department given',
    private.has_permission(v_company, 'pos.job.write'), false);
  perform pg_temp.expect('Department admin: org.unit.write (org-only permission)',
    private.has_permission(v_company, 'org.unit.write', v_child), false);
  perform pg_temp.expect('Department admin: org.config.write',
    private.has_permission(v_company, 'org.config.write'), false);
  perform pg_temp.expect('Department admin: allocation for own Department, any org unit',
    private.has_permission(v_company, 'org.allocation.write', v_child, v_dept1), true);
  if v_dept2 is not null then
    perform pg_temp.expect('Department admin: pos.job.write at another Department',
      private.has_permission(v_company, 'pos.job.write', null, v_dept2), false);
    perform pg_temp.expect('Department admin: allocation for another Department',
      private.has_permission(v_company, 'org.allocation.write', v_child, v_dept2), false);
  end if;

  -- company hr_admin, viewer on one Department
  perform pg_temp.act_as(u_dview);
  perform pg_temp.expect('restricted Department: pos.job.write there',
    private.has_permission(v_company, 'pos.job.write', null, v_dept1), false);
  perform pg_temp.expect('restricted Department: allocation for it',
    private.has_permission(v_company, 'org.allocation.write', v_child, v_dept1), false);
  perform pg_temp.expect('restricted Department: org.unit.write is not affected',
    private.has_permission(v_company, 'org.unit.write', v_child), true);
  if v_dept2 is not null then
    perform pg_temp.expect('restricted Department: pos.job.write at another Department',
      private.has_permission(v_company, 'pos.job.write', null, v_dept2), true);
    perform pg_temp.expect('restricted Department: allocation for another Department',
      private.has_permission(v_company, 'org.allocation.write', v_child, v_dept2), true);
  end if;

  -- ------------------------------------------------------------
  -- Both sides: restriction wins
  -- ------------------------------------------------------------
  perform pg_temp.act_as(u_mix);
  perform pg_temp.expect('mixed: org admin but Department viewer -> denied',
    private.has_permission(v_company, 'org.allocation.write', v_child, v_dept1), false);
  if v_dept2 is not null then
    perform pg_temp.expect('mixed: org admin, other Department has no restriction -> allowed',
      private.has_permission(v_company, 'org.allocation.write', v_child, v_dept2), true);
  end if;
end;
$$;

rollback;

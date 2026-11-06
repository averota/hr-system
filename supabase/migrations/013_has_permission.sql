-- 013: permission check (ORG Stage 9b-2)
--
--   private.has_permission(company, permission code, org unit, Department)
--       Does the logged-in user hold this permission for this target?
--   private.has_tenant_permission(tenant, permission code)
--       Same, for permissions that only make sense for the whole tenant
--       (members.manage). Only a tenant-wide assignment counts.
--   private.role_has_permission(role, permission)
--       Small helper used by has_permission.
--
-- How has_permission decides (all based on auth.uid(), the caller's own assignments):
--   1. The permission must exist, the company must exist, and the user must be
--      a member of the company's tenant. Otherwise false.
--   2. Which sides are looked at:
--        org side        : only when the permission applies to org units
--                          AND p_org_unit_id is given
--        Department side : only when the permission applies to Departments
--                          AND p_department_id is given
--      An id for a side the permission does not apply to is ignored, so
--      company-level actions are never decided by Department assignments.
--      A given id must be an open org unit / open Department of the company,
--      otherwise false.
--   3. Narrow assignments (org unit scope, Department scope):
--        org side        : the nearest assignment on the unit or above it
--                          (the unit itself, then its parent, and so on)
--        Department side : the assignment on that Department
--      Units closed later grant nothing (a closed unit is never a valid target).
--   4. If any narrow assignment applies, it decides and the company and
--      tenant-wide assignments are ignored (narrower replaces broader).
--      Every narrow assignment that applies must hold the permission
--      (restriction wins). A side with no narrow assignment has no say.
--   5. If no narrow assignment applies, the company assignment decides,
--      else the tenant-wide assignment. No assignment at all = false.
--
-- These functions only answer the question. Nothing calls them yet.
-- Assumption: members.manage is tenant-wide only (a company-scoped
-- tenant_admin cannot manage members).

-- ---------------------------------------------------------------
-- Helper
-- ---------------------------------------------------------------
create function private.role_has_permission(
  p_role_id       integer,
  p_permission_id integer
)
returns boolean
language sql
stable
set search_path = ''
as $$
  select exists (
    select 1
    from core.app_role_permission rp
    where rp.role_id = p_role_id
      and rp.permission_id = p_permission_id
  )
$$;

revoke execute on function private.role_has_permission(integer, integer)
  from public, anon;
grant execute on function private.role_has_permission(integer, integer)
  to service_role;

-- ---------------------------------------------------------------
-- Main check
-- ---------------------------------------------------------------
create function private.has_permission(
  p_company_id      integer,
  p_permission_code text,
  p_org_unit_id     integer default null,
  p_department_id   integer default null
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user          uuid := auth.uid();
  v_tenant        integer;
  v_perm_id       integer;
  v_applies_org   boolean;
  v_applies_dept  boolean;
  v_org_role      integer;
  v_dept_role     integer;
  v_broad_role    integer;
begin
  if v_user is null then
    return false;
  end if;

  select p.id, p.applies_to_org_unit, p.applies_to_department
  into v_perm_id, v_applies_org, v_applies_dept
  from core.permission p
  where p.code = p_permission_code;

  if v_perm_id is null then
    return false;
  end if;

  select c.tenant_id into v_tenant
  from core.parent_company c
  where c.id = p_company_id;

  if v_tenant is null then
    return false;
  end if;

  if not exists (
    select 1
    from core.tenant_member m
    where m.tenant_id = v_tenant
      and m.user_id = v_user
  ) then
    return false;
  end if;

  -- Org side: nearest org unit assignment on the unit or above it
  if v_applies_org and p_org_unit_id is not null then
    if not exists (
      select 1
      from core.org_unit u
      where u.id = p_org_unit_id
        and u.company_id = p_company_id
        and u.valid_to is null
    ) then
      return false;
    end if;

    with recursive chain as (
      select p_org_unit_id as unit_id, 0 as depth
      union all
      select l.parent_unit_id, c.depth + 1
      from chain c
      join core.org_unit_parent l
        on l.unit_id = c.unit_id
       and l.valid_to is null
       and l.parent_unit_id is not null
    )
    select s.role_id into v_org_role
    from chain c
    join core.member_role_scope s
      on s.scope_kind = 'org_unit'
     and s.org_unit_id = c.unit_id
     and s.user_id = v_user
     and s.tenant_id = v_tenant
     and s.company_id = p_company_id
    join core.org_unit u
      on u.id = s.org_unit_id
     and u.valid_to is null
    order by c.depth
    limit 1;
  end if;

  -- Department side: the assignment on that Department
  if v_applies_dept and p_department_id is not null then
    if not exists (
      select 1
      from core.pos_unit p
      join core.hierarchy_level l on l.id = p.level_id
      where p.id = p_department_id
        and p.company_id = p_company_id
        and p.valid_to is null
        and l.code = 'department'
    ) then
      return false;
    end if;

    select s.role_id into v_dept_role
    from core.member_role_scope s
    where s.scope_kind = 'department'
      and s.pos_unit_id = p_department_id
      and s.user_id = v_user
      and s.tenant_id = v_tenant
      and s.company_id = p_company_id;
  end if;

  -- Narrow assignments decide. All that apply must hold the permission.
  if v_org_role is not null or v_dept_role is not null then
    if v_org_role is not null
       and not private.role_has_permission(v_org_role, v_perm_id) then
      return false;
    end if;

    if v_dept_role is not null
       and not private.role_has_permission(v_dept_role, v_perm_id) then
      return false;
    end if;

    return true;
  end if;

  -- No narrow assignment: company assignment, else tenant-wide assignment
  select s.role_id into v_broad_role
  from core.member_role_scope s
  where s.scope_kind = 'company'
    and s.company_id = p_company_id
    and s.user_id = v_user
    and s.tenant_id = v_tenant;

  if v_broad_role is null then
    select s.role_id into v_broad_role
    from core.member_role_scope s
    where s.scope_kind = 'tenant'
      and s.user_id = v_user
      and s.tenant_id = v_tenant;
  end if;

  if v_broad_role is null then
    return false;
  end if;

  return private.role_has_permission(v_broad_role, v_perm_id);
end;
$$;

revoke execute on function private.has_permission(integer, text, integer, integer)
  from public, anon;
grant execute on function private.has_permission(integer, text, integer, integer)
  to authenticated, service_role;

-- ---------------------------------------------------------------
-- Tenant-wide check (members.manage and similar)
-- Only a tenant-wide assignment counts. Not found = false.
-- ---------------------------------------------------------------
create function private.has_tenant_permission(
  p_tenant_id       integer,
  p_permission_code text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from core.member_role_scope s
    join core.app_role_permission rp on rp.role_id = s.role_id
    join core.permission p on p.id = rp.permission_id
    where s.user_id = auth.uid()
      and s.tenant_id = p_tenant_id
      and s.scope_kind = 'tenant'
      and p.code = p_permission_code
  )
$$;

revoke execute on function private.has_tenant_permission(integer, text)
  from public, anon;
grant execute on function private.has_tenant_permission(integer, text)
  to authenticated, service_role;

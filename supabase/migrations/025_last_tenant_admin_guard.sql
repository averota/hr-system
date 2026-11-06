-- 025: last tenant administrator guard (platform)
--
-- A tenant must always keep at least one tenant-wide tenant_admin.
-- Only tenant-wide assignments count. A tenant_admin given for one company,
-- one org unit or one Department does not count (members.manage is tenant-wide only).
--
-- The guard refuses, for the last tenant-wide tenant_admin of a tenant:
--   - deleting the assignment from core.member_role_scope
--   - changing its role to another role
--   - removing the member from core.tenant_member (the delete cascades to the
--     assignment, so the same check stops it)
--   - deleting the auth user (cascades the same way)
-- It applies to everyone, including service_role and manual SQL.
-- A user may remove or downgrade their own tenant_admin role while another
-- tenant-wide tenant_admin exists.
--
-- Concurrency: the check locks the tenant row first, so two administrators
-- cannot remove each other at the same moment.
--
-- Tenant teardown: to delete a whole tenant, run this first in the same
-- transaction, then delete the tenant's rows:
--   select set_config('hris.tenant_teardown', 'on', true);
-- The setting lasts until the transaction ends.
--
-- Not retroactive: a tenant that has no tenant-wide tenant_admin today is not
-- changed. Only removing an existing one is checked.

create function private.member_role_scope_last_admin_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_admin_role_id integer;
begin
  -- Explicit tenant teardown
  if coalesce(current_setting('hris.tenant_teardown', true), '') = 'on' then
    if tg_op = 'DELETE' then return old; end if;
    return new;
  end if;

  select id into v_admin_role_id
  from core.app_role
  where code = 'tenant_admin';

  -- Only a tenant-wide tenant_admin assignment is protected
  if old.scope_kind <> 'tenant' or old.role_id <> v_admin_role_id then
    if tg_op = 'DELETE' then return old; end if;
    return new;
  end if;

  -- An update that keeps the role is fine
  if tg_op = 'UPDATE' and new.role_id = old.role_id then
    return new;
  end if;

  -- Serialize with other changes to this tenant's administrators.
  -- No tenant row means the tenant itself is being removed.
  perform 1 from core.tenant where id = old.tenant_id for update;
  if not found then
    if tg_op = 'DELETE' then return old; end if;
    return new;
  end if;

  if not exists (
    select 1
    from core.member_role_scope s
    where s.tenant_id = old.tenant_id
      and s.scope_kind = 'tenant'
      and s.role_id = v_admin_role_id
      and s.id <> old.id
  ) then
    raise exception 'A tenant must keep at least one tenant-wide tenant administrator';
  end if;

  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

revoke execute on function private.member_role_scope_last_admin_guard()
  from public, anon, authenticated;

create trigger member_role_scope_last_admin_guard
  before update or delete on core.member_role_scope
  for each row execute function private.member_role_scope_last_admin_guard();

-- DEV ONLY seed: one tenant, one parent company, and your membership.
-- Run once in Supabase Dashboard -> SQL Editor (dev project).
-- Edit the two names below first if you want real names.

do $$
declare
  v_tenant_id  integer;
  v_user_id    uuid := '5a539ef9-e6e6-443b-a8c0-bf718798c7b1';
begin
  if exists (select 1 from core.tenant) then
    raise exception 'core.tenant already has rows. Seed not run.';
  end if;

  insert into core.tenant (name_en)
  values ('Dev Tenant')
  returning id into v_tenant_id;

  insert into core.parent_company (tenant_id, name_en)
  values (v_tenant_id, 'Dev Parent Company');

  insert into core.tenant_member (tenant_id, user_id)
  values (v_tenant_id, v_user_id);
end $$;

-- Check: should show 1 tenant, 1 company, 1 member
select
  (select count(*) from core.tenant)         as tenants,
  (select count(*) from core.parent_company) as companies,
  (select count(*) from core.tenant_member)  as members;

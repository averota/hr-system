-- 011: catalog read views (ORG Stage 7b)
--
-- Closes read gaps G1 and G2 before ORG Stage 8 (frontend):
--   parent_companies   companies in the caller's tenant(s)
--   hierarchy_levels   global 7-level catalog for org and position trees
--
-- Both views use security_invoker = true so caller RLS on core tables applies.
-- Read-only for authenticated and service_role; anon gets nothing.

-- ---------------------------------------------------------------
-- Views
-- ---------------------------------------------------------------
create view public.parent_companies
with (security_invoker = true) as
select
  c.id          as company_id,
  c.tenant_id,
  c.name_en,
  c.name_km,
  c.is_active
from core.parent_company c;

create view public.hierarchy_levels
with (security_invoker = true) as
select
  l.id          as level_id,
  l.tree,
  l.code,
  l.rank,
  l.name_en,
  l.name_km,
  l.can_be_root,
  l.is_required
from core.hierarchy_level l;

-- ---------------------------------------------------------------
-- Privileges: logged-in users only
-- ---------------------------------------------------------------
revoke all on
  public.parent_companies,
  public.hierarchy_levels
from public, anon, authenticated;

grant select on
  public.parent_companies,
  public.hierarchy_levels
to authenticated, service_role;
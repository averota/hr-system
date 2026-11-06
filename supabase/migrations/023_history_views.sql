-- 023: history views (ORG Stage 9i, database part)
--
-- Read-only views for closed (history) records, the counterpart of the *_current
-- views in 010. "Closed" means valid_to is not null.
--
-- Views (security_invoker, so the caller's row level security still applies):
--   company_level_rules_closed   closed level rules, with the level and parent level
--   org_units_closed             closed org units, with the parent they had when they closed
--   pos_units_closed             closed position units, with the parent they had when they closed
--
-- Scope: closed rules and closed units only. A unit that is still open but was
-- moved (reorg) is not history here, its old links are not shown.
-- Closed jobs, Department listings and allocations are not included.
--
-- Parent of a closed unit = its latest parent link (latest start, then highest
-- id). A closed unit has no open link, so this is the link it had when it closed.
-- parent_unit_id null = it sat directly under the company (org tree) or was a
-- Department (position tree). The parent may itself be closed by now.
--
-- Read-only. Logged-in users only: anon gets nothing.
-- Needs 002, 003, 004 and 010 (grant usage on schema core to authenticated).

-- ---------------------------------------------------------------
-- Views
-- ---------------------------------------------------------------
create view public.company_level_rules_closed
with (security_invoker = true) as
select
  r.id                as rule_id,
  r.company_id,
  r.tree,
  r.level_id,
  l.code              as level_code,
  l.rank              as level_rank,
  l.name_en           as level_name_en,
  l.name_km           as level_name_km,
  r.parent_level_id,
  pl.code             as parent_level_code,
  pl.name_en          as parent_level_name_en,
  pl.name_km          as parent_level_name_km,
  r.valid_from,
  r.valid_to
from core.company_level_rule r
join core.hierarchy_level l  on l.id = r.level_id
left join core.hierarchy_level pl on pl.id = r.parent_level_id
where r.valid_to is not null;

create view public.org_units_closed
with (security_invoker = true) as
select
  u.id          as unit_id,
  u.company_id,
  u.level_id,
  l.code        as level_code,
  l.rank        as level_rank,
  l.name_en     as level_name_en,
  l.name_km     as level_name_km,
  u.name_en,
  u.name_km,
  p.parent_unit_id,
  pu.name_en    as parent_name_en,
  pu.name_km    as parent_name_km,
  u.valid_from,
  u.valid_to
from core.org_unit u
join core.hierarchy_level l on l.id = u.level_id
left join lateral (
  select lp.parent_unit_id
  from core.org_unit_parent lp
  where lp.unit_id = u.id
  order by lp.valid_from desc, lp.id desc
  limit 1
) p on true
left join core.org_unit pu on pu.id = p.parent_unit_id
where u.valid_to is not null;

create view public.pos_units_closed
with (security_invoker = true) as
select
  u.id          as unit_id,
  u.company_id,
  u.level_id,
  l.code        as level_code,
  l.rank        as level_rank,
  l.name_en     as level_name_en,
  l.name_km     as level_name_km,
  u.name_en,
  u.name_km,
  p.parent_unit_id,
  pu.name_en    as parent_name_en,
  pu.name_km    as parent_name_km,
  u.valid_from,
  u.valid_to
from core.pos_unit u
join core.hierarchy_level l on l.id = u.level_id
left join lateral (
  select lp.parent_unit_id
  from core.pos_unit_parent lp
  where lp.unit_id = u.id
  order by lp.valid_from desc, lp.id desc
  limit 1
) p on true
left join core.pos_unit pu on pu.id = p.parent_unit_id
where u.valid_to is not null;

-- ---------------------------------------------------------------
-- Privileges: logged-in users only.
-- Supabase grants new public objects to anon and authenticated by default,
-- so those are removed explicitly first.
-- ---------------------------------------------------------------
revoke all on
  public.company_level_rules_closed,
  public.org_units_closed,
  public.pos_units_closed
from anon, authenticated;

grant select on
  public.company_level_rules_closed,
  public.org_units_closed,
  public.pos_units_closed
to authenticated, service_role;

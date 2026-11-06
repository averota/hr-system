-- 020: hierarchy rule write functions and wrappers (ORG Stage 9c-7)
--
-- A "rule" is a row in core.company_level_rule: it says a level is enabled for a
-- company and which level it sits under (or directly under the root).
-- A level can have several rules (example: Branch under the root and Branch
-- under Business Unit). One call adds one rule, one call closes one rule.
--
-- Part A: private write functions (service_role only), the missing single write
--         path for rules:
--   private.enable_level_rule(company, level, parent level)
--   private.disable_level_rule(company, rule, close date)
--
-- Part B: public wrappers, callable by logged-in users. Each one checks
--         permission org.config.write at company or tenant level only
--         (a Department or org unit role never affects hierarchy rules).
--   public.enable_level_rule(company, level, parent level)
--   public.disable_level_rule(company, rule, close date)
--
-- What the private functions add on top of the guard (002, 004, 007):
--   enable : clear messages instead of raw constraint errors (level missing,
--            parent in another tree, parent not higher up, rule already enabled)
--   disable: the rule must be open and belong to the company, and the close date
--            cannot be earlier than the rule's start
-- The guard still decides the rest and its messages come through unchanged:
--   'Level "x" cannot sit directly under the root'
--   'The parent level is not enabled for this company'
--   'Level "x" is required and cannot be disabled'
--   'Other active rules still use level "x" as their parent'
--   'Level "x" still has active units. Close them before disabling the level'
-- Existing units are never rearranged: a unit keeps the rule it was created under,
-- even after that rule is closed (it needs an open rule only to be moved).
--
-- Errors from the wrappers:
--   no permission (or not a member of the company's tenant):
--       'You do not have permission to change hierarchy rules here' (code 42501)
--   a member naming a rule that is not open in this company:
--       'Rule % is not an open rule of this company'
-- Needs 016 (private.is_company_member).

-- ---------------------------------------------------------------
-- Part A: private functions
-- ---------------------------------------------------------------
create function private.enable_level_rule(
  p_company_id       integer,
  p_level_id         integer,
  p_parent_level_id  integer default null
)
returns integer
language plpgsql
set search_path = ''
as $$
declare
  v_tree   text;
  v_rank   smallint;
  v_ptree  text;
  v_prank  smallint;
  v_id     integer;
begin
  if not exists (select 1 from core.parent_company c where c.id = p_company_id) then
    raise exception 'Company % not found', p_company_id;
  end if;

  select h.tree, h.rank into v_tree, v_rank
  from core.hierarchy_level h
  where h.id = p_level_id;

  if not found then
    raise exception 'Level % does not exist', p_level_id;
  end if;

  if p_parent_level_id is not null then
    select h.tree, h.rank into v_ptree, v_prank
    from core.hierarchy_level h
    where h.id = p_parent_level_id;

    if not found then
      raise exception 'Level % does not exist', p_parent_level_id;
    end if;

    if v_ptree <> v_tree then
      raise exception 'The parent level must be in the same tree as the level';
    end if;

    if v_prank >= v_rank then
      raise exception 'A parent level must be higher up than its child level';
    end if;
  end if;

  if exists (
    select 1
    from core.company_level_rule r
    where r.company_id = p_company_id
      and r.level_id = p_level_id
      and coalesce(r.parent_level_id, 0) = coalesce(p_parent_level_id, 0)
      and r.valid_to is null
  ) then
    raise exception 'This rule is already enabled for the company';
  end if;

  -- the guard checks "can sit under the root" and "parent level is enabled"
  insert into core.company_level_rule
    (company_id, tree, level_id, level_rank, parent_level_id, parent_level_rank)
  values
    (p_company_id, v_tree, p_level_id, v_rank, p_parent_level_id, v_prank)
  returning id into v_id;

  return v_id;
end;
$$;

create function private.disable_level_rule(
  p_company_id  integer,
  p_rule_id     integer,
  p_close_date  date default current_date
)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_from date;
begin
  select valid_from into v_from
  from core.company_level_rule
  where id = p_rule_id
    and company_id = p_company_id
    and valid_to is null
  for update;

  if not found then
    raise exception 'Rule % is not an open rule of this company', p_rule_id;
  end if;

  if p_close_date < v_from then
    raise exception 'Close date % is earlier than %, when this rule started',
      p_close_date, v_from;
  end if;

  -- the guard refuses when this would really disable a level that is still in use
  update core.company_level_rule
  set valid_to = p_close_date
  where id = p_rule_id;
end;
$$;

revoke execute on function
  private.enable_level_rule(integer, integer, integer),
  private.disable_level_rule(integer, integer, date)
from public, anon, authenticated;

grant execute on function
  private.enable_level_rule(integer, integer, integer),
  private.disable_level_rule(integer, integer, date)
to service_role;

-- ---------------------------------------------------------------
-- Part B: public wrappers
-- security definer: they read and write core as the function owner, and
-- decide access themselves with private.has_permission (the caller's login).
-- ---------------------------------------------------------------
create function public.enable_level_rule(
  p_company_id       integer,
  p_level_id         integer,
  p_parent_level_id  integer default null
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.has_permission(p_company_id, 'org.config.write') then
    raise exception 'You do not have permission to change hierarchy rules here'
      using errcode = '42501';
  end if;

  return private.enable_level_rule(p_company_id, p_level_id, p_parent_level_id);
end;
$$;

create function public.disable_level_rule(
  p_company_id  integer,
  p_rule_id     integer,
  p_close_date  date default current_date
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1
    from core.company_level_rule r
    where r.id = p_rule_id
      and r.company_id = p_company_id
      and r.valid_to is null
  ) then
    if private.is_company_member(p_company_id) then
      raise exception 'Rule % is not an open rule of this company', p_rule_id;
    end if;

    raise exception 'You do not have permission to change hierarchy rules here'
      using errcode = '42501';
  end if;

  if not private.has_permission(p_company_id, 'org.config.write') then
    raise exception 'You do not have permission to change hierarchy rules here'
      using errcode = '42501';
  end if;

  perform private.disable_level_rule(p_company_id, p_rule_id, p_close_date);
end;
$$;

-- ---------------------------------------------------------------
-- Privileges: logged-in users only (Supabase grants new public objects
-- to anon and authenticated by default, so revoke first)
-- ---------------------------------------------------------------
revoke execute on function
  public.enable_level_rule(integer, integer, integer),
  public.disable_level_rule(integer, integer, date)
from public, anon, authenticated;

grant execute on function
  public.enable_level_rule(integer, integer, integer),
  public.disable_level_rule(integer, integer, date)
to authenticated, service_role;

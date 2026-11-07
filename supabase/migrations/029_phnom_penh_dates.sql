-- 029: Phnom Penh date for new records (ORG-T021, part 1 of 2)
--
-- Problem: new records got their start date from the server date (UTC). Between
-- 00:00 and 07:00 in Phnom Penh (UTC+7) the UTC date is still "yesterday", so a
-- unit created in the early morning started one day too early.
--
-- Fix: one helper, private.org_today(), returns today's date in Phnom Penh.
-- The functions below now pass this date as valid_from explicitly, so they no
-- longer depend on the column default.
--
--   * private.create_org_unit      (026): unit and its parent link start today (PP)
--   * private.create_pos_unit      (026): unit and its parent link start today (PP)
--   * private.create_job_position  (018): job starts today (PP)
--   * private.enable_level_rule    (020): rule starts today (PP)
--
-- The rename functions need no change: since 027 (name history reverted) they
-- only update the name columns and use no date.
--
-- Rules, messages, return values and privileges are unchanged.
-- Not in this migration (part 2, ORG-T021b): the "default current_date"
-- parameters of the close, reorg, listing, allocation and disable-rule functions.

-- ---------------------------------------------------------------
-- Helper
-- ---------------------------------------------------------------
create or replace function private.org_today()
returns date
language sql
stable
set search_path = ''
as $$
  select (now() at time zone 'Asia/Phnom_Penh')::date
$$;

revoke execute on function private.org_today()
  from public, anon, authenticated;
grant execute on function private.org_today()
  to service_role;

-- ---------------------------------------------------------------
-- Clean-up: name history was removed by 027. Make sure no leftover function
-- exists (safe if it is already gone).
-- ---------------------------------------------------------------
drop function if exists private.name_history_sync();

-- ---------------------------------------------------------------
-- create_org_unit (from 026)
-- ---------------------------------------------------------------
create or replace function private.create_org_unit(
  p_company_id     integer,
  p_level_id       integer,
  p_parent_unit_id integer,
  p_name_en        text,
  p_name_km        text default null
)
returns integer
language plpgsql
set search_path = ''
as $$
declare
  v_name_en         text := btrim(p_name_en);
  v_name_km         text := nullif(btrim(p_name_km), '');
  v_today           date := private.org_today();
  v_parent_level_id integer;
  v_rule_id         integer;
  v_unit_id         integer;
begin
  if v_name_en is null or v_name_en = '' then
    raise exception 'The English name is required';
  end if;

  if p_parent_unit_id is not null then
    select level_id into v_parent_level_id
    from core.org_unit
    where id = p_parent_unit_id
      and company_id = p_company_id
      and valid_to is null;

    if not found then
      raise exception 'Parent unit % is not an open unit of this company', p_parent_unit_id;
    end if;
  end if;

  select id into v_rule_id
  from core.company_level_rule
  where company_id = p_company_id
    and level_id = p_level_id
    and parent_level_key = coalesce(v_parent_level_id, 0)
    and valid_to is null;

  if v_rule_id is null then
    raise exception 'No active rule allows this level under this parent';
  end if;

  insert into core.org_unit (company_id, level_id, name_en, name_km, valid_from)
  values (p_company_id, p_level_id, v_name_en, v_name_km, v_today)
  returning id into v_unit_id;

  insert into core.org_unit_parent
    (company_id, unit_id, level_id, parent_unit_id, parent_level_id, rule_id, valid_from)
  values
    (p_company_id, v_unit_id, p_level_id, p_parent_unit_id, v_parent_level_id, v_rule_id, v_today);

  return v_unit_id;
end;
$$;

-- ---------------------------------------------------------------
-- create_pos_unit (from 026)
-- ---------------------------------------------------------------
create or replace function private.create_pos_unit(
  p_company_id     integer,
  p_level_id       integer,
  p_parent_unit_id integer,
  p_name_en        text,
  p_name_km        text default null
)
returns integer
language plpgsql
set search_path = ''
as $$
declare
  v_name_en         text := btrim(p_name_en);
  v_name_km         text := nullif(btrim(p_name_km), '');
  v_today           date := private.org_today();
  v_parent_level_id integer;
  v_rule_id         integer;
  v_unit_id         integer;
begin
  if v_name_en is null or v_name_en = '' then
    raise exception 'The English name is required';
  end if;

  if p_parent_unit_id is not null then
    select level_id into v_parent_level_id
    from core.pos_unit
    where id = p_parent_unit_id
      and company_id = p_company_id
      and valid_to is null;

    if not found then
      raise exception 'Parent unit % is not an open unit of this company', p_parent_unit_id;
    end if;
  end if;

  select id into v_rule_id
  from core.company_level_rule
  where company_id = p_company_id
    and level_id = p_level_id
    and parent_level_key = coalesce(v_parent_level_id, 0)
    and valid_to is null;

  if v_rule_id is null then
    raise exception 'No active rule allows this level under this parent';
  end if;

  insert into core.pos_unit (company_id, level_id, name_en, name_km, valid_from)
  values (p_company_id, p_level_id, v_name_en, v_name_km, v_today)
  returning id into v_unit_id;

  insert into core.pos_unit_parent
    (company_id, unit_id, level_id, parent_unit_id, parent_level_id, rule_id, valid_from)
  values
    (p_company_id, v_unit_id, p_level_id, p_parent_unit_id, v_parent_level_id, v_rule_id, v_today);

  return v_unit_id;
end;
$$;

-- ---------------------------------------------------------------
-- create_job_position (from 018)
-- ---------------------------------------------------------------
create or replace function private.create_job_position(
  p_company_id     integer,
  p_department_id  integer,
  p_name_en        text,
  p_name_km        text default null
)
returns integer
language plpgsql
set search_path = ''
as $$
declare
  v_name_en text := btrim(p_name_en);
  v_name_km text := nullif(btrim(p_name_km), '');
  v_id      integer;
begin
  if not exists (
    select 1
    from core.pos_unit u
    join core.hierarchy_level h on h.id = u.level_id
    where u.id = p_department_id
      and u.company_id = p_company_id
      and u.valid_to is null
      and h.code = 'department'
  ) then
    raise exception 'Department % is not an open Department of this company', p_department_id;
  end if;

  if v_name_en is null or v_name_en = '' then
    raise exception 'The English name is required';
  end if;

  if exists (
    select 1
    from core.job_position j
    where j.department_id = p_department_id
      and j.name_en = v_name_en
      and j.valid_to is null
  ) then
    raise exception 'A job position named "%" already exists in this Department', v_name_en;
  end if;

  insert into core.job_position (company_id, department_id, name_en, name_km, valid_from)
  values (p_company_id, p_department_id, v_name_en, v_name_km, private.org_today())
  returning id into v_id;

  return v_id;
end;
$$;

-- ---------------------------------------------------------------
-- enable_level_rule (from 020)
-- ---------------------------------------------------------------
create or replace function private.enable_level_rule(
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
    (company_id, tree, level_id, level_rank, parent_level_id, parent_level_rank, valid_from)
  values
    (p_company_id, v_tree, p_level_id, v_rank, p_parent_level_id, v_prank, private.org_today())
  returning id into v_id;

  return v_id;
end;
$$;
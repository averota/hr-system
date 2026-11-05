-- 004: position tree (Department -> Office -> Section -> Group)
--
--   pos_unit        : Department / Office / Section / Group records (stable IDs)
--   pos_unit_parent : effective-dated link from a unit to its parent
--                     (parent_unit_id null = top of the tree, i.e. a Department)
--
-- This is a Parent-Company-wide catalog. It is linked to org locations only
-- through allocations (a later migration). It follows the same pattern as the
-- org tree in 003, so the behaviour is identical: no placeholder rows,
-- versioned rules, reorgs by closing and reopening links.
--
-- Part A also refines the rule guard from 002 (see below).

-- ---------------------------------------------------------------
-- Part A: refine private.company_level_rule_guard()
-- Closing ONE rule must not count as disabling the level while another
-- open rule for the same level remains (e.g. Section under Office closed,
-- Section under Department still open).
-- ---------------------------------------------------------------
create or replace function private.company_level_rule_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_level      core.hierarchy_level%rowtype;
  v_other_open boolean;
begin
  if tg_op = 'INSERT' then
    if new.valid_to is not null then
      raise exception 'A new rule must be open (valid_to must be empty)';
    end if;

    select * into v_level from core.hierarchy_level where id = new.level_id;

    if new.parent_level_id is null then
      if not v_level.can_be_root then
        raise exception 'Level "%" cannot sit directly under the root', v_level.code;
      end if;
    elsif not exists (
      select 1
      from core.company_level_rule r
      where r.company_id = new.company_id
        and r.level_id = new.parent_level_id
        and r.valid_to is null
    ) then
      raise exception 'The parent level is not enabled for this company';
    end if;

    return new;
  end if;

  -- UPDATE: rules are never edited, only closed
  if (new.id, new.company_id, new.tree, new.level_id, new.level_rank,
      new.parent_level_id, new.parent_level_rank, new.valid_from)
     is distinct from
     (old.id, old.company_id, old.tree, old.level_id, old.level_rank,
      old.parent_level_id, old.parent_level_rank, old.valid_from) then
    raise exception 'Rules cannot be edited. Close the rule and create a new one';
  end if;

  if old.valid_to is not null and new.valid_to is distinct from old.valid_to then
    raise exception 'A closed rule cannot be changed';
  end if;

  if old.valid_to is null and new.valid_to is not null then
    select * into v_level from core.hierarchy_level where id = old.level_id;

    select exists (
      select 1
      from core.company_level_rule r
      where r.company_id = old.company_id
        and r.level_id = old.level_id
        and r.valid_to is null
        and r.id <> old.id
    ) into v_other_open;

    -- Only when this is the last open rule is the level really being disabled
    if not v_other_open then
      if v_level.is_required then
        raise exception 'Level "%" is required and cannot be disabled', v_level.code;
      end if;

      if exists (
        select 1
        from core.company_level_rule r
        where r.company_id = old.company_id
          and r.parent_level_id = old.level_id
          and r.valid_to is null
      ) then
        raise exception 'Other active rules still use level "%" as their parent', v_level.code;
      end if;
    end if;
  end if;

  return new;
end;
$$;

-- ---------------------------------------------------------------
-- Part B: position units
-- ---------------------------------------------------------------
create table core.pos_unit (
  id          integer generated always as identity primary key,
  company_id  integer not null references core.parent_company (id),
  tree        text not null default 'pos' check (tree = 'pos'),
  level_id    integer not null,
  name_en     text not null,
  name_km     text,
  valid_from  date not null default current_date,
  valid_to    date,
  created_at  timestamptz not null default now(),

  foreign key (level_id, tree) references core.hierarchy_level (id, tree),
  check (valid_to is null or valid_to >= valid_from),

  -- target for composite foreign keys
  unique (id, company_id, level_id)
);

create index pos_unit_company_idx on core.pos_unit (company_id);

create table core.pos_unit_parent (
  id                integer generated always as identity primary key,
  company_id        integer not null,
  unit_id           integer not null,
  level_id          integer not null,
  parent_unit_id    integer,
  parent_level_id   integer,
  parent_level_key  integer generated always as (coalesce(parent_level_id, 0)) stored,
  rule_id           integer not null,
  valid_from        date not null default current_date,
  valid_to          date,
  created_at        timestamptz not null default now(),

  foreign key (unit_id, company_id, level_id)
    references core.pos_unit (id, company_id, level_id),

  foreign key (parent_unit_id, company_id, parent_level_id)
    references core.pos_unit (id, company_id, level_id),

  foreign key (rule_id, company_id, level_id, parent_level_key)
    references core.company_level_rule (id, company_id, level_id, parent_level_key),

  check ((parent_unit_id is null) = (parent_level_id is null)),
  check (valid_to is null or valid_to >= valid_from)
);

create unique index pos_unit_parent_open_uq
  on core.pos_unit_parent (unit_id)
  where valid_to is null;

create index pos_unit_parent_parent_idx
  on core.pos_unit_parent (parent_unit_id)
  where valid_to is null;

create index pos_unit_parent_company_idx
  on core.pos_unit_parent (company_id);

-- ---------------------------------------------------------------
-- Guard: pos_unit
-- ---------------------------------------------------------------
create function private.pos_unit_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if new.valid_to is not null then
      raise exception 'A new position unit must be open (valid_to must be empty)';
    end if;

    if not exists (
      select 1
      from core.company_level_rule r
      where r.company_id = new.company_id
        and r.level_id = new.level_id
        and r.valid_to is null
    ) then
      raise exception 'This level is not enabled for the company';
    end if;

    return new;
  end if;

  -- UPDATE: names can change. Company, level and start date cannot.
  if (new.id, new.company_id, new.tree, new.level_id, new.valid_from)
     is distinct from
     (old.id, old.company_id, old.tree, old.level_id, old.valid_from) then
    raise exception 'Company, level and start date of a position unit cannot be changed';
  end if;

  if old.valid_to is not null and new.valid_to is distinct from old.valid_to then
    raise exception 'A closed position unit cannot be changed';
  end if;

  if old.valid_to is null and new.valid_to is not null then
    if exists (
      select 1
      from core.pos_unit_parent p
      where p.parent_unit_id = old.id
        and p.valid_to is null
    ) then
      raise exception 'This unit still has active units under it';
    end if;

    -- a closed unit must not keep an open link
    update core.pos_unit_parent
    set valid_to = new.valid_to
    where unit_id = old.id
      and valid_to is null;
  end if;

  return new;
end;
$$;

create trigger pos_unit_guard
  before insert or update on core.pos_unit
  for each row execute function private.pos_unit_guard();

-- ---------------------------------------------------------------
-- Guard: pos_unit_parent
-- ---------------------------------------------------------------
create function private.pos_unit_parent_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if new.valid_to is not null then
      raise exception 'A new link must be open (valid_to must be empty)';
    end if;

    if not exists (
      select 1 from core.pos_unit u
      where u.id = new.unit_id and u.valid_to is null
    ) then
      raise exception 'The unit is closed';
    end if;

    if new.parent_unit_id is not null and not exists (
      select 1 from core.pos_unit u
      where u.id = new.parent_unit_id and u.valid_to is null
    ) then
      raise exception 'The parent unit is closed';
    end if;

    if not exists (
      select 1 from core.company_level_rule r
      where r.id = new.rule_id and r.valid_to is null
    ) then
      raise exception 'The rule is closed. Use a currently active rule';
    end if;

    return new;
  end if;

  -- UPDATE: a link is never edited, only closed
  if (new.id, new.company_id, new.unit_id, new.level_id, new.parent_unit_id,
      new.parent_level_id, new.rule_id, new.valid_from)
     is distinct from
     (old.id, old.company_id, old.unit_id, old.level_id, old.parent_unit_id,
      old.parent_level_id, old.rule_id, old.valid_from) then
    raise exception 'Links cannot be edited. Close the link and create a new one';
  end if;

  if old.valid_to is not null and new.valid_to is distinct from old.valid_to then
    raise exception 'A closed link cannot be changed';
  end if;

  return new;
end;
$$;

create trigger pos_unit_parent_guard
  before insert or update on core.pos_unit_parent
  for each row execute function private.pos_unit_parent_guard();

-- ---------------------------------------------------------------
-- Deferred check: an open unit must always end up with an open link
-- ---------------------------------------------------------------
create function private.pos_unit_link_check()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_unit_id integer;
begin
  if tg_table_name = 'pos_unit' then
    v_unit_id := new.id;
  else
    v_unit_id := new.unit_id;
  end if;

  if exists (
       select 1 from core.pos_unit u
       where u.id = v_unit_id and u.valid_to is null
     )
     and not exists (
       select 1 from core.pos_unit_parent p
       where p.unit_id = v_unit_id and p.valid_to is null
     ) then
    raise exception 'Position unit % must have an open parent link', v_unit_id;
  end if;

  return null;
end;
$$;

create constraint trigger pos_unit_needs_link
  after insert or update on core.pos_unit
  deferrable initially deferred
  for each row execute function private.pos_unit_link_check();

create constraint trigger pos_unit_parent_keeps_link
  after insert or update on core.pos_unit_parent
  deferrable initially deferred
  for each row execute function private.pos_unit_link_check();

-- ---------------------------------------------------------------
-- Create a unit together with its parent link (single write path)
-- Not exposed to the frontend yet.
-- ---------------------------------------------------------------
create function private.create_pos_unit(
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
  v_parent_level_id integer;
  v_rule_id         integer;
  v_unit_id         integer;
begin
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

  insert into core.pos_unit (company_id, level_id, name_en, name_km)
  values (p_company_id, p_level_id, p_name_en, p_name_km)
  returning id into v_unit_id;

  insert into core.pos_unit_parent
    (company_id, unit_id, level_id, parent_unit_id, parent_level_id, rule_id)
  values
    (p_company_id, v_unit_id, p_level_id, p_parent_unit_id, v_parent_level_id, v_rule_id);

  return v_unit_id;
end;
$$;

revoke execute on function private.create_pos_unit(integer, integer, integer, text, text)
  from public, anon;
grant execute on function private.create_pos_unit(integer, integer, integer, text, text)
  to service_role;

-- ---------------------------------------------------------------
-- Row level security and privileges (read-only for logged-in users)
-- ---------------------------------------------------------------
alter table core.pos_unit        enable row level security;
alter table core.pos_unit_parent enable row level security;

create policy pos_unit_select on core.pos_unit
  for select to authenticated
  using (company_id in (select id from core.parent_company));

create policy pos_unit_parent_select on core.pos_unit_parent
  for select to authenticated
  using (company_id in (select id from core.parent_company));

grant select on core.pos_unit, core.pos_unit_parent to authenticated;
grant all on core.pos_unit, core.pos_unit_parent to service_role;

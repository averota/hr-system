-- 003: org tree
--
--   org_unit        : Business Unit / Branch / Division records (stable IDs)
--   org_unit_parent : effective-dated link from a unit to its parent
--                     (a unit, or the Parent Company when parent_unit_id is null)
--
-- The Parent Company is the root, so it has no org_unit row.
-- A reorg = close the old link and open a new one. The unit keeps its ID.
-- Every link points at the company rule that allows it. Changing rules later
-- never touches existing links.

-- ---------------------------------------------------------------
-- Small additions to 002 so foreign keys can enforce the rules,
-- including for units directly under the Parent Company
-- ---------------------------------------------------------------
alter table core.hierarchy_level
  add constraint hierarchy_level_id_tree_key unique (id, tree);

-- 0 stands for "directly under the root" (a key only, not a record)
alter table core.company_level_rule
  add column parent_level_key integer
    generated always as (coalesce(parent_level_id, 0)) stored;

alter table core.company_level_rule
  add constraint company_level_rule_link_key
  unique (id, company_id, level_id, parent_level_key);

-- ---------------------------------------------------------------
-- Org units
-- ---------------------------------------------------------------
create table core.org_unit (
  id          integer generated always as identity primary key,
  company_id  integer not null references core.parent_company (id),
  tree        text not null default 'org' check (tree = 'org'),
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

create index org_unit_company_idx on core.org_unit (company_id);

-- ---------------------------------------------------------------
-- Parent links (history of who sat under whom)
-- ---------------------------------------------------------------
create table core.org_unit_parent (
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

  -- the unit belongs to this company and has this level
  foreign key (unit_id, company_id, level_id)
    references core.org_unit (id, company_id, level_id),

  -- the parent unit is in the same company and really has the stated level
  foreign key (parent_unit_id, company_id, parent_level_id)
    references core.org_unit (id, company_id, level_id),

  -- the rule belongs to the same company, covers this level and this parent level
  foreign key (rule_id, company_id, level_id, parent_level_key)
    references core.company_level_rule (id, company_id, level_id, parent_level_key),

  check ((parent_unit_id is null) = (parent_level_id is null)),
  check (valid_to is null or valid_to >= valid_from)
);

-- One open parent link per unit
create unique index org_unit_parent_open_uq
  on core.org_unit_parent (unit_id)
  where valid_to is null;

create index org_unit_parent_parent_idx
  on core.org_unit_parent (parent_unit_id)
  where valid_to is null;

create index org_unit_parent_company_idx
  on core.org_unit_parent (company_id);

-- ---------------------------------------------------------------
-- Guard: org_unit
-- ---------------------------------------------------------------
create function private.org_unit_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if new.valid_to is not null then
      raise exception 'A new org unit must be open (valid_to must be empty)';
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
    raise exception 'Company, level and start date of an org unit cannot be changed';
  end if;

  if old.valid_to is not null and new.valid_to is distinct from old.valid_to then
    raise exception 'A closed org unit cannot be changed';
  end if;

  if old.valid_to is null and new.valid_to is not null then
    if exists (
      select 1
      from core.org_unit_parent p
      where p.parent_unit_id = old.id
        and p.valid_to is null
    ) then
      raise exception 'This unit still has active units under it';
    end if;

    -- a closed unit must not keep an open link
    update core.org_unit_parent
    set valid_to = new.valid_to
    where unit_id = old.id
      and valid_to is null;
  end if;

  return new;
end;
$$;

create trigger org_unit_guard
  before insert or update on core.org_unit
  for each row execute function private.org_unit_guard();

-- ---------------------------------------------------------------
-- Guard: org_unit_parent
-- ---------------------------------------------------------------
create function private.org_unit_parent_guard()
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
      select 1 from core.org_unit u
      where u.id = new.unit_id and u.valid_to is null
    ) then
      raise exception 'The unit is closed';
    end if;

    if new.parent_unit_id is not null and not exists (
      select 1 from core.org_unit u
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

create trigger org_unit_parent_guard
  before insert or update on core.org_unit_parent
  for each row execute function private.org_unit_parent_guard();

-- ---------------------------------------------------------------
-- Deferred check: an open unit must always end up with an open link
-- (runs at commit, so a unit and its link can be created together)
-- ---------------------------------------------------------------
create function private.org_unit_link_check()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_unit_id integer;
begin
  if tg_table_name = 'org_unit' then
    v_unit_id := new.id;
  else
    v_unit_id := new.unit_id;
  end if;

  if exists (
       select 1 from core.org_unit u
       where u.id = v_unit_id and u.valid_to is null
     )
     and not exists (
       select 1 from core.org_unit_parent p
       where p.unit_id = v_unit_id and p.valid_to is null
     ) then
    raise exception 'Org unit % must have an open parent link', v_unit_id;
  end if;

  return null;
end;
$$;

create constraint trigger org_unit_needs_link
  after insert or update on core.org_unit
  deferrable initially deferred
  for each row execute function private.org_unit_link_check();

create constraint trigger org_unit_parent_keeps_link
  after insert or update on core.org_unit_parent
  deferrable initially deferred
  for each row execute function private.org_unit_link_check();

-- ---------------------------------------------------------------
-- Create a unit together with its parent link (single write path)
-- Finds the matching open rule itself, so callers cannot pick a wrong one.
-- Not exposed to the frontend yet.
-- ---------------------------------------------------------------
create function private.create_org_unit(
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

  insert into core.org_unit (company_id, level_id, name_en, name_km)
  values (p_company_id, p_level_id, p_name_en, p_name_km)
  returning id into v_unit_id;

  insert into core.org_unit_parent
    (company_id, unit_id, level_id, parent_unit_id, parent_level_id, rule_id)
  values
    (p_company_id, v_unit_id, p_level_id, p_parent_unit_id, v_parent_level_id, v_rule_id);

  return v_unit_id;
end;
$$;

revoke execute on function private.create_org_unit(integer, integer, integer, text, text)
  from public, anon;
grant execute on function private.create_org_unit(integer, integer, integer, text, text)
  to service_role;

-- ---------------------------------------------------------------
-- Row level security and privileges (read-only for logged-in users)
-- ---------------------------------------------------------------
alter table core.org_unit        enable row level security;
alter table core.org_unit_parent enable row level security;

create policy org_unit_select on core.org_unit
  for select to authenticated
  using (company_id in (select id from core.parent_company));

create policy org_unit_parent_select on core.org_unit_parent
  for select to authenticated
  using (company_id in (select id from core.parent_company));

grant select on core.org_unit, core.org_unit_parent to authenticated;
grant all on core.org_unit, core.org_unit_parent to service_role;

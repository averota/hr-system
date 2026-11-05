-- 002: hierarchy levels and per-company level rules
--
--   hierarchy_level    : global catalog of levels (same for every company)
--   company_level_rule : which levels a Parent Company uses, and which level
--                        each one sits under. Skipping a level = pointing the
--                        next level at the real parent. No placeholder rows.
--
-- Org tree      : Parent Company (root) -> Business Unit -> Branch -> Division
-- Position tree : Department -> Office -> Section -> Group
--                 ("Position" itself is a job catalog, added in a later migration)
--
-- Rules are versioned: never edited, only closed (valid_to) and replaced.

-- ---------------------------------------------------------------
-- Level catalog (global reference data)
-- ---------------------------------------------------------------
create table core.hierarchy_level (
  id           integer generated always as identity primary key,
  tree         text not null check (tree in ('org', 'pos')),
  code         text not null,
  rank         smallint not null check (rank > 0),   -- order inside the tree
  name_en      text not null,
  name_km      text,
  can_be_root  boolean not null,  -- may sit directly under the root
  is_required  boolean not null,  -- cannot be disabled
  unique (tree, code),
  unique (tree, rank),
  unique (id, tree, rank)
);

insert into core.hierarchy_level (tree, code, rank, name_en, can_be_root, is_required)
values
  ('org', 'business_unit', 1, 'Business Unit', true,  false),
  ('org', 'branch',        2, 'Branch',        true,  false),
  ('org', 'division',      3, 'Division',      true,  false),
  ('pos', 'department',    1, 'Department',    true,  true),
  ('pos', 'office',        2, 'Office',        false, false),
  ('pos', 'section',       3, 'Section',       false, false),
  ('pos', 'group',         4, 'Group',         false, false);

-- ---------------------------------------------------------------
-- Per-company rules
-- parent_level_id null = the level sits directly under the root
-- (the Parent Company for the org tree, the top of the position tree).
-- ---------------------------------------------------------------
create table core.company_level_rule (
  id                 integer generated always as identity primary key,
  company_id         integer not null references core.parent_company (id),
  tree               text not null,
  level_id           integer not null,
  level_rank         smallint not null,
  parent_level_id    integer,
  parent_level_rank  smallint,
  valid_from         date not null default current_date,
  valid_to           date,
  created_at         timestamptz not null default now(),

  -- level and parent level must exist, in the same tree, with matching rank
  foreign key (level_id, tree, level_rank)
    references core.hierarchy_level (id, tree, rank),
  foreign key (parent_level_id, tree, parent_level_rank)
    references core.hierarchy_level (id, tree, rank),

  check ((parent_level_id is null) = (parent_level_rank is null)),
  -- a parent level must be higher up than its child
  check (parent_level_rank is null or parent_level_rank < level_rank),
  check (valid_to is null or valid_to >= valid_from),

  -- target for composite foreign keys in later migrations
  unique (id, company_id, level_id)
);

-- Only one open rule per company + level + parent level
create unique index company_level_rule_open_uq
  on core.company_level_rule (company_id, level_id, coalesce(parent_level_id, 0))
  where valid_to is null;

create index company_level_rule_company_idx
  on core.company_level_rule (company_id);

-- ---------------------------------------------------------------
-- Guard: rules that FKs and checks cannot express
-- ---------------------------------------------------------------
create function private.company_level_rule_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_level core.hierarchy_level%rowtype;
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

  return new;
end;
$$;

create trigger company_level_rule_guard
  before insert or update on core.company_level_rule
  for each row execute function private.company_level_rule_guard();

-- ---------------------------------------------------------------
-- Row level security and privileges (read-only for logged-in users)
-- ---------------------------------------------------------------
alter table core.hierarchy_level    enable row level security;
alter table core.company_level_rule enable row level security;

create policy hierarchy_level_select on core.hierarchy_level
  for select to authenticated
  using (true);

create policy company_level_rule_select on core.company_level_rule
  for select to authenticated
  using (company_id in (select id from core.parent_company));

grant select on core.hierarchy_level, core.company_level_rule to authenticated;
grant all on core.hierarchy_level, core.company_level_rule to service_role;

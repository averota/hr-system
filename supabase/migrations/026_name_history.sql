-- 026: name history and trimmed names on create (ORG Stage 9j)
--
-- Part A: core.name_history keeps every name an org unit, position unit or job
--         position has had, with the dates it was valid (valid_to empty = current
--         name). It is filled by triggers, so every write path is covered
--         (functions, seed scripts, manual SQL). The name columns on org_unit,
--         pos_unit and job_position stay as the current name, so the existing
--         views and the frontend keep working.
--
--   * Rename on a later day: the old row is closed with valid_to = today and a
--     new row starts today. This is the same "close and replace on the same date"
--     pattern as a headcount change. When reading a date where two rows touch,
--     the row that started later wins.
--   * A second rename on the same day replaces the first one (no extra row).
--   * Closing a unit or job closes its open name row on the same date. If the
--     close date is earlier than a later rename, the names that would start after
--     the close date are dropped and the previous row is ended on the close date.
--   * Names before this migration are not known. Existing records get one row
--     with their current name, starting on the record's own start date.
--   * No foreign key on entity_id (one table serves three entities). Rows are
--     written only by the trigger, and ids are never reused.
--   * Nothing reads this table yet. Migration 027 uses it for history views.
--   * Dates use the server date (UTC), like every function without a date parameter.
--
-- Part B: replaces private.create_org_unit (003) and private.create_pos_unit (004).
--         Names are trimmed (an empty Khmer name is stored as null) and a blank
--         English name is refused ('The English name is required'), so the
--         database no longer depends on the frontend trimming names.
--         Rules and return value are unchanged.

-- ---------------------------------------------------------------
-- Part A: name history
-- ---------------------------------------------------------------
create table core.name_history (
  id          integer generated always as identity primary key,
  company_id  integer not null references core.parent_company (id),
  entity      text not null check (entity in ('org_unit', 'pos_unit', 'job_position')),
  entity_id   integer not null,
  name_en     text not null,
  name_km     text,
  valid_from  date not null,
  valid_to    date,
  created_at  timestamptz not null default now(),

  check (valid_to is null or valid_to >= valid_from)
);

-- One open name per record
create unique index name_history_open_uq
  on core.name_history (entity, entity_id)
  where valid_to is null;

create index name_history_entity_idx
  on core.name_history (entity, entity_id, valid_from);

create index name_history_company_idx
  on core.name_history (company_id);

-- Existing records: one row with the current name
insert into core.name_history
  (company_id, entity, entity_id, name_en, name_km, valid_from, valid_to)
select company_id, 'org_unit', id, name_en, name_km, valid_from, valid_to
from core.org_unit
union all
select company_id, 'pos_unit', id, name_en, name_km, valid_from, valid_to
from core.pos_unit
union all
select company_id, 'job_position', id, name_en, name_km, valid_from, valid_to
from core.job_position;

-- ---------------------------------------------------------------
-- Trigger function (the entity is passed as the trigger argument)
-- ---------------------------------------------------------------
create function private.name_history_sync()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_entity text := tg_argv[0];
  v_from   date;
begin
  if tg_op = 'INSERT' then
    insert into core.name_history
      (company_id, entity, entity_id, name_en, name_km, valid_from, valid_to)
    values
      (new.company_id, v_entity, new.id, new.name_en, new.name_km, new.valid_from, new.valid_to);
    return null;
  end if;

  -- Closing the record ends its name row on the same date
  if old.valid_to is null and new.valid_to is not null then
    delete from core.name_history
    where entity = v_entity
      and entity_id = new.id
      and valid_from > new.valid_to;

    update core.name_history
    set valid_to = new.valid_to
    where entity = v_entity
      and entity_id = new.id
      and (valid_to is null or valid_to > new.valid_to);

    return null;
  end if;

  -- Name change on an open record
  if new.valid_to is null
     and (new.name_en, new.name_km) is distinct from (old.name_en, old.name_km) then

    select h.valid_from into v_from
    from core.name_history h
    where h.entity = v_entity
      and h.entity_id = new.id
      and h.valid_to is null;

    if not found then
      insert into core.name_history
        (company_id, entity, entity_id, name_en, name_km, valid_from)
      values
        (new.company_id, v_entity, new.id, new.name_en, new.name_km, new.valid_from);

    elsif v_from >= current_date then
      -- the current name started today: the new name replaces it
      update core.name_history
      set name_en = new.name_en,
          name_km = new.name_km
      where entity = v_entity
        and entity_id = new.id
        and valid_to is null;

    else
      update core.name_history
      set valid_to = current_date
      where entity = v_entity
        and entity_id = new.id
        and valid_to is null;

      insert into core.name_history
        (company_id, entity, entity_id, name_en, name_km, valid_from)
      values
        (new.company_id, v_entity, new.id, new.name_en, new.name_km, current_date);
    end if;
  end if;

  return null;
end;
$$;

revoke execute on function private.name_history_sync()
  from public, anon, authenticated;

create trigger org_unit_name_history
  after insert or update of name_en, name_km, valid_to on core.org_unit
  for each row execute function private.name_history_sync('org_unit');

create trigger pos_unit_name_history
  after insert or update of name_en, name_km, valid_to on core.pos_unit
  for each row execute function private.name_history_sync('pos_unit');

create trigger job_position_name_history
  after insert or update of name_en, name_km, valid_to on core.job_position
  for each row execute function private.name_history_sync('job_position');

-- ---------------------------------------------------------------
-- Row level security and privileges (read-only for logged-in users)
-- ---------------------------------------------------------------
alter table core.name_history enable row level security;

create policy name_history_select on core.name_history
  for select to authenticated
  using (company_id in (select id from core.parent_company));

grant select on core.name_history to authenticated;
grant all on core.name_history to service_role;

-- ---------------------------------------------------------------
-- Part B: trimmed names in the create functions
-- (privileges stay as granted in 003 and 004)
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

  insert into core.org_unit (company_id, level_id, name_en, name_km)
  values (p_company_id, p_level_id, v_name_en, v_name_km)
  returning id into v_unit_id;

  insert into core.org_unit_parent
    (company_id, unit_id, level_id, parent_unit_id, parent_level_id, rule_id)
  values
    (p_company_id, v_unit_id, p_level_id, p_parent_unit_id, v_parent_level_id, v_rule_id);

  return v_unit_id;
end;
$$;

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

  insert into core.pos_unit (company_id, level_id, name_en, name_km)
  values (p_company_id, p_level_id, v_name_en, v_name_km)
  returning id into v_unit_id;

  insert into core.pos_unit_parent
    (company_id, unit_id, level_id, parent_unit_id, parent_level_id, rule_id)
  values
    (p_company_id, v_unit_id, p_level_id, p_parent_unit_id, v_parent_level_id, v_rule_id);

  return v_unit_id;
end;
$$;

-- 007: block disabling a level that still has active units (roadmap Stage 6a)
--
-- Replaces private.company_level_rule_guard() (latest version was in 004).
-- The only change: when the LAST open rule of a level is being closed, the
-- level is really being disabled, so it is refused while any open unit
-- (org_unit or pos_unit) still exists at that level for the company.
--
-- Open allocations always sit on open units, so checking units also covers them.
-- Closing a rule while another open rule for the same level remains is still
-- allowed, exactly as in 004.

create or replace function private.company_level_rule_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_level      core.hierarchy_level%rowtype;
  v_other_open boolean;
  v_has_units  boolean;
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

      -- NEW in 007: no open units may remain at this level
      if v_level.tree = 'org' then
        select exists (
          select 1 from core.org_unit u
          where u.company_id = old.company_id
            and u.level_id = old.level_id
            and u.valid_to is null
        ) into v_has_units;
      else
        select exists (
          select 1 from core.pos_unit u
          where u.company_id = old.company_id
            and u.level_id = old.level_id
            and u.valid_to is null
        ) into v_has_units;
      end if;

      if v_has_units then
        raise exception 'Level "%" still has active units. Close them before disabling the level', v_level.code;
      end if;
    end if;
  end if;

  return new;
end;
$$;

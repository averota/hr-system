-- 029_phnom_penh_dates_test.sql
-- Dev project only. Paste into Supabase Dashboard -> SQL Editor.
-- Rolls back at the end. "Success. No rows returned" = pass. "FAIL: ..." = a check failed.
-- Needs seed_dev_tenant.sql, seed_dev_org_sample.sql and migrations 026, 027 and 029.
-- Most meaningful between 00:00 and 07:00 Phnom Penh time (the UTC date is still
-- the day before then), but it passes at any time.

begin;

do $$
declare
  v_today    date := (now() at time zone 'Asia/Phnom_Penh')::date;
  v_company  integer;
  v_level    integer;
  v_parent   integer;
  v_unit     integer;
  v_dept     integer;
  v_job      integer;
  v_rule     integer;
  v_from     date;
  r          record;
begin
  -- ---------------------------------------------------------
  -- 1. Helper
  -- ---------------------------------------------------------
  if private.org_today() is distinct from v_today then
    raise exception 'FAIL 1a: org_today() is %, expected %', private.org_today(), v_today;
  end if;

  if has_function_privilege('anon', 'private.org_today()', 'execute')
     or has_function_privilege('authenticated', 'private.org_today()', 'execute') then
    raise exception 'FAIL 1b: anon or authenticated can call private.org_today()';
  end if;

  if to_regclass('core.name_history') is not null then
    raise exception 'FAIL 1c: core.name_history still exists (migration 027 not applied)';
  end if;

  if to_regprocedure('private.name_history_sync()') is not null then
    raise exception 'FAIL 1d: private.name_history_sync() still exists (run migration 029)';
  end if;

  -- ---------------------------------------------------------
  -- 2. Org unit
  -- ---------------------------------------------------------
  select r2.company_id, r2.level_id into v_company, v_level
  from core.company_level_rule r2
  join core.hierarchy_level h on h.id = r2.level_id
  where h.tree = 'org' and r2.parent_level_id is null and r2.valid_to is null
  order by r2.company_id, r2.id
  limit 1;

  if v_company is null then
    raise exception 'FAIL: needs an open org rule directly under the root (dev seed data)';
  end if;

  v_unit := private.create_org_unit(v_company, v_level, null, '  T029 unit  ', '   ');

  select valid_from, name_en, name_km into r from core.org_unit where id = v_unit;
  if r.valid_from <> v_today then
    raise exception 'FAIL 2a: org unit valid_from is %, expected %', r.valid_from, v_today;
  end if;
  if r.name_en <> 'T029 unit' or r.name_km is not null then
    raise exception 'FAIL 2b: org unit names not trimmed (% / %)', r.name_en, r.name_km;
  end if;

  select valid_from into v_from from core.org_unit_parent where unit_id = v_unit;
  if v_from is distinct from v_today then
    raise exception 'FAIL 2c: org unit parent link valid_from is %, expected %', v_from, v_today;
  end if;

  -- ---------------------------------------------------------
  -- 3. Department and job position
  -- ---------------------------------------------------------
  select r2.company_id, r2.level_id into v_company, v_level
  from core.company_level_rule r2
  join core.hierarchy_level h on h.id = r2.level_id
  where h.tree = 'pos' and h.code = 'department'
    and r2.parent_level_id is null and r2.valid_to is null
  order by r2.company_id, r2.id
  limit 1;

  if v_company is null then
    raise exception 'FAIL: needs an open Department rule (dev seed data)';
  end if;

  v_dept := private.create_pos_unit(v_company, v_level, null, '  T029 dept ', null);

  select valid_from into v_from from core.pos_unit where id = v_dept;
  if v_from <> v_today then
    raise exception 'FAIL 3a: position unit valid_from is %, expected %', v_from, v_today;
  end if;

  select valid_from into v_from from core.pos_unit_parent where unit_id = v_dept;
  if v_from is distinct from v_today then
    raise exception 'FAIL 3b: position unit parent link valid_from is %, expected %', v_from, v_today;
  end if;

  v_job := private.create_job_position(v_company, v_dept, '  T029 job ', '');

  select valid_from, name_en, name_km into r from core.job_position where id = v_job;
  if r.valid_from <> v_today then
    raise exception 'FAIL 3c: job valid_from is %, expected %', r.valid_from, v_today;
  end if;
  if r.name_en <> 'T029 job' or r.name_km is not null then
    raise exception 'FAIL 3d: job names not trimmed (% / %)', r.name_en, r.name_km;
  end if;

  -- ---------------------------------------------------------
  -- 4. enable_level_rule (uses a rule that is not enabled yet, if one exists)
  -- ---------------------------------------------------------
  select r2.company_id, c.id, p.id into v_company, v_level, v_parent
  from core.company_level_rule r2
  join core.hierarchy_level p on p.id = r2.level_id
  join core.hierarchy_level c on c.tree = p.tree and c.rank > p.rank
  where r2.valid_to is null
    and not exists (
      select 1 from core.company_level_rule x
      where x.company_id = r2.company_id
        and x.level_id = c.id
        and coalesce(x.parent_level_id, 0) = p.id
        and x.valid_to is null)
  order by r2.company_id, c.id, p.id
  limit 1;

  if v_company is null then
    raise notice 'Check 4 skipped: every possible rule is already enabled';
  else
    v_rule := private.enable_level_rule(v_company, v_level, v_parent);
    select valid_from into v_from from core.company_level_rule where id = v_rule;
    if v_from is distinct from v_today then
      raise exception 'FAIL 4a: rule valid_from is %, expected %', v_from, v_today;
    end if;
  end if;
end;
$$;

rollback;

-- 014 test: close one allocation (ORG Stage 9c-1)
-- DEV project only. Paste into Supabase Dashboard -> SQL Editor.
-- Needs the dev sample data (seed_dev_org_sample.sql): at least one open allocation.
-- Rolls back at the end. "Success. No rows returned" = pass. "FAIL: ..." = a check failed.

begin;

do $$
declare
  v_id            integer;
  v_company       integer;
  v_org_unit      integer;
  v_job           integer;
  v_pos           integer;
  v_from          date;
  v_headcount     integer;
  v_close_date    date;
  v_others_before integer;
  v_others_after  integer;
  v_new_id        integer;
  v_denied        boolean;
begin
  select a.id, a.company_id, a.org_unit_id, a.job_position_id, a.pos_unit_id,
         a.valid_from, a.approved_headcount
  into v_id, v_company, v_org_unit, v_job, v_pos, v_from, v_headcount
  from core.position_allocation a
  where a.valid_to is null
  order by a.id
  limit 1;

  if v_id is null then
    raise exception 'FAIL: test needs the dev sample data - no open allocation found';
  end if;

  select count(*) into v_others_before
  from core.position_allocation
  where valid_to is null and id <> v_id;

  -- 1. Unknown company
  begin
    perform private.close_allocation(-1, v_id);
    raise exception 'FAIL: an allocation was closed with the wrong company';
  exception
    when raise_exception then
      if sqlerrm like 'FAIL:%' then raise; end if;
      if sqlerrm not like '%is not an open allocation of this company%' then
        raise exception 'FAIL: wrong error message: %', sqlerrm;
      end if;
  end;

  -- 2. Unknown allocation
  begin
    perform private.close_allocation(v_company, -1);
    raise exception 'FAIL: an unknown allocation was closed';
  exception
    when raise_exception then
      if sqlerrm like 'FAIL:%' then raise; end if;
      if sqlerrm not like '%is not an open allocation of this company%' then
        raise exception 'FAIL: wrong error message: %', sqlerrm;
      end if;
  end;

  -- 3. Close date before the allocation started
  begin
    perform private.close_allocation(v_company, v_id, v_from - 1);
    raise exception 'FAIL: a close date before the start date was accepted';
  exception
    when raise_exception then
      if sqlerrm like 'FAIL:%' then raise; end if;
      if sqlerrm not like '%is earlier than%' then
        raise exception 'FAIL: wrong error message: %', sqlerrm;
      end if;
  end;

  if not exists (select 1 from core.position_allocation where id = v_id and valid_to is null) then
    raise exception 'FAIL: a refused close still changed the allocation';
  end if;

  -- 4. Valid close
  v_close_date := greatest(current_date, v_from);
  perform private.close_allocation(v_company, v_id, v_close_date);

  if not exists (select 1 from core.position_allocation
                 where id = v_id and valid_to = v_close_date) then
    raise exception 'FAIL: the allocation was not closed on the given date';
  end if;

  if exists (select 1 from public.position_allocations_current where allocation_id = v_id) then
    raise exception 'FAIL: a closed allocation still shows in position_allocations_current';
  end if;

  select count(*) into v_others_after
  from core.position_allocation
  where valid_to is null and id <> v_id;

  if v_others_after <> v_others_before then
    raise exception 'FAIL: closing one allocation changed other allocations (before %, after %)',
      v_others_before, v_others_after;
  end if;

  if not exists (
    select 1
    from core.position_allocation a
    join core.org_unit_department e on e.id = a.eligibility_id
    where a.id = v_id and e.valid_to is null
  ) then
    raise exception 'FAIL: closing an allocation closed its Department listing';
  end if;

  -- 5. Closing again
  begin
    perform private.close_allocation(v_company, v_id);
    raise exception 'FAIL: a closed allocation was closed again';
  exception
    when raise_exception then
      if sqlerrm like 'FAIL:%' then raise; end if;
      if sqlerrm not like '%is not an open allocation of this company%' then
        raise exception 'FAIL: wrong error message: %', sqlerrm;
      end if;
  end;

  -- 6. Headcount change flow: a new allocation can replace the closed one
  v_new_id := private.create_allocation(v_company, v_org_unit, v_job, v_pos, v_headcount + 1);

  if not exists (select 1 from core.position_allocation
                 where id = v_new_id and valid_to is null
                   and approved_headcount = v_headcount + 1) then
    raise exception 'FAIL: the replacement allocation was not created as open';
  end if;

  -- 7. Not callable by logged-in users or anonymous visitors
  set local role authenticated;
  begin
    perform private.close_allocation(v_company, v_new_id);
    v_denied := false;
  exception
    when insufficient_privilege then v_denied := true;
  end;
  reset role;

  if not v_denied then
    raise exception 'FAIL: a logged-in user could call private.close_allocation';
  end if;

  set local role anon;
  begin
    perform private.close_allocation(v_company, v_new_id);
    v_denied := false;
  exception
    when insufficient_privilege then v_denied := true;
  end;
  reset role;

  if not v_denied then
    raise exception 'FAIL: an anonymous visitor could call private.close_allocation';
  end if;
end;
$$;

rollback;

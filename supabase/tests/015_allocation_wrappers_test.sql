-- 015 test: allocation write wrappers (ORG Stage 9c-2)
-- DEV project only. Paste into Supabase Dashboard -> SQL Editor.
-- Needs migration 015 applied and the dev sample data (002_seed_dev_org_sample.sql),
-- unchanged: company "Dev Parent Company" with exactly ONE open allocation
-- (Software Engineer at Head Office, headcount 5).
-- Rolls back at the end. "Success. No rows returned" = pass. "FAIL: ..." = a check failed.

begin;

-- ---------------------------------------------------------------
-- Test helpers (temporary, dropped at the end of the session)
-- ---------------------------------------------------------------
create function pg_temp.new_user(p_tenant integer, p_name text)
returns uuid
language plpgsql
as $$
declare
  v_id uuid := gen_random_uuid();
begin
  insert into auth.users (id, email) values (v_id, p_name || '@alloc-test.invalid');
  insert into core.tenant_member (tenant_id, user_id) values (p_tenant, v_id);
  return v_id;
end;
$$;

create function pg_temp.assign(
  p_tenant   integer,
  p_user     uuid,
  p_role     text,
  p_kind     text,
  p_company  integer default null,
  p_org_unit integer default null,
  p_pos_unit integer default null
)
returns void
language sql
as $$
  insert into core.member_role_scope
    (tenant_id, user_id, role_id, scope_kind, company_id, org_unit_id, pos_unit_id)
  select p_tenant, p_user, r.id, p_kind, p_company, p_org_unit, p_pos_unit
  from core.app_role r
  where r.code = p_role;
$$;

create function pg_temp.act_as(p_user uuid)
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claim.sub', p_user::text, true);
  perform set_config('request.jwt.claims', json_build_object('sub', p_user)::text, true);
end;
$$;

create function pg_temp.no_login()
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claim.sub', '', true);
  perform set_config('request.jwt.claims', '', true);
end;
$$;

-- compare two values as text (null-safe)
create function pg_temp.eq(p_label text, p_actual text, p_expected text)
returns void
language plpgsql
as $$
begin
  if p_actual is distinct from p_expected then
    raise exception 'FAIL: % (expected %, got %)',
      p_label, coalesce(p_expected, 'null'), coalesce(p_actual, 'null');
  end if;
end;
$$;

-- run a statement that must succeed
create function pg_temp.run(p_label text, p_sql text)
returns void
language plpgsql
as $$
begin
  execute p_sql;
exception when others then
  raise exception 'FAIL: % (unexpected error: %)', p_label, sqlerrm;
end;
$$;

-- run a statement that must succeed and return one integer
create function pg_temp.run_int(p_label text, p_sql text)
returns integer
language plpgsql
as $$
declare
  v integer;
begin
  execute p_sql into v;
  return v;
exception when others then
  raise exception 'FAIL: % (unexpected error: %)', p_label, sqlerrm;
end;
$$;

-- run a statement that must fail (message part and error code are checked)
create function pg_temp.expect_error(
  p_label text, p_sql text, p_msg text, p_state text default null
)
returns void
language plpgsql
as $$
declare
  v_state text;
  v_msg   text;
begin
  begin
    execute p_sql;
  exception when others then
    get stacked diagnostics v_state = returned_sqlstate, v_msg = message_text;
    if position(p_msg in v_msg) = 0 then
      raise exception 'FAIL: % (expected message containing "%", got "%")',
        p_label, p_msg, v_msg;
    end if;
    if p_state is not null and v_state <> p_state then
      raise exception 'FAIL: % (expected error code %, got %)', p_label, p_state, v_state;
    end if;
    return;
  end;
  raise exception 'FAIL: % (expected an error, but the call succeeded)', p_label;
end;
$$;

-- allocation readers
create function pg_temp.a_from(p_id integer) returns text language sql as $$
  select valid_from::text from core.position_allocation where id = p_id $$;
create function pg_temp.a_to(p_id integer) returns text language sql as $$
  select valid_to::text from core.position_allocation where id = p_id $$;
create function pg_temp.a_head(p_id integer) returns text language sql as $$
  select approved_headcount::text from core.position_allocation where id = p_id $$;
create function pg_temp.open_count(p_org integer, p_job integer, p_pos integer)
returns text language sql as $$
  select count(*)::text from core.position_allocation
  where org_unit_id = p_org and job_position_id = p_job and pos_unit_id = p_pos
    and valid_to is null $$;

-- SQL text builders
create function pg_temp.q_create(c integer, o integer, j integer, p integer, h integer, d date default null)
returns text language sql as $$
  select case when d is null
    then format('select public.create_allocation(%s,%s,%s,%s,%s)', c, o, j, p, h)
    else format('select public.create_allocation(%s,%s,%s,%s,%s,%L::date)', c, o, j, p, h, d) end $$;

create function pg_temp.q_priv(c integer, o integer, j integer, p integer, h integer, d date default null)
returns text language sql as $$
  select case when d is null
    then format('select private.create_allocation(%s,%s,%s,%s,%s)', c, o, j, p, h)
    else format('select private.create_allocation(%s,%s,%s,%s,%s,%L::date)', c, o, j, p, h, d) end $$;

create function pg_temp.q_close(c integer, a integer, d date default null)
returns text language sql as $$
  select case when d is null
    then format('select public.close_allocation(%s,%s)', c, a)
    else format('select public.close_allocation(%s,%s,%L::date)', c, a, d) end $$;

create function pg_temp.q_change(c integer, a integer, h integer, d date default null)
returns text language sql as $$
  select case when d is null
    then format('select public.change_allocation_headcount(%s,%s,%s)', c, a, h)
    else format('select public.change_allocation_headcount(%s,%s,%s,%L::date)', c, a, h, d) end $$;

-- ---------------------------------------------------------------
-- Tests
-- ---------------------------------------------------------------
do $$
declare
  v_company  integer;
  v_tenant   integer;
  v_tenant2  integer;

  v_swe      integer;
  v_sysadm   integer;
  v_acct     integer;
  v_finmgr   integer;
  v_hro      integer;

  v_it       integer;   -- Departments
  v_fin      integer;
  v_hr       integer;

  v_ho       integer;   -- org units
  v_pp       integer;
  v_sr       integer;

  v_backend  integer;   -- position unit of the seed allocation
  v_acctsec  integer;   -- a Section under Finance

  v_a0       integer;   -- seed allocation
  v_a0_head  integer;
  v_a1       integer;
  v_a2       integer;
  v_w1       integer;
  v_w2       integer;
  v_w6       integer;
  v_w7       integer;
  v_n        integer;
  v_x        integer;
  v_x2       integer;
  v_x3       integer;

  u_admin    uuid;
  u_hr       uuid;
  u_view     uuid;
  u_none     uuid;
  u_outsider uuid;
  u_dept     uuid;   -- hr_admin on the IT Department only
  u_unit     uuid;   -- hr_admin on Phnom Penh Branch only

  c_denied constant text := 'You do not have permission to manage allocations here';
  c_notopen constant text := 'is not an open allocation of this company';
  c_early  constant text := 'is earlier than';
  v_sig    text;
begin
  -- ------------------------------------------------------------
  -- Pick sample data
  -- ------------------------------------------------------------
  select c.id, c.tenant_id into v_company, v_tenant
  from core.parent_company c
  where c.name_en = 'Dev Parent Company';

  if v_company is null then
    raise exception 'FAIL: company "Dev Parent Company" not found. Run the dev seeds first';
  end if;

  select id into v_swe    from core.job_position where company_id = v_company and valid_to is null and name_en = 'Software Engineer';
  select id into v_sysadm from core.job_position where company_id = v_company and valid_to is null and name_en = 'System Administrator';
  select id into v_acct   from core.job_position where company_id = v_company and valid_to is null and name_en = 'Accountant';
  select id into v_finmgr from core.job_position where company_id = v_company and valid_to is null and name_en = 'Finance Manager';
  select id into v_hro    from core.job_position where company_id = v_company and valid_to is null and name_en = 'HR Officer';

  if v_swe is null or v_sysadm is null or v_acct is null or v_finmgr is null or v_hro is null then
    raise exception 'FAIL: test needs the 5 sample job positions from 002_seed_dev_org_sample.sql';
  end if;

  select department_id into v_it  from core.job_position where id = v_swe;
  select department_id into v_fin from core.job_position where id = v_acct;
  select department_id into v_hr  from core.job_position where id = v_hro;

  select e.org_unit_id into v_ho
  from core.org_unit_department e
  where e.company_id = v_company and e.department_id = v_it and e.valid_to is null
  order by e.org_unit_id limit 1;

  select e.org_unit_id into v_pp
  from core.org_unit_department e
  where e.company_id = v_company and e.department_id = v_fin and e.valid_to is null
    and e.org_unit_id <> v_ho
  order by e.org_unit_id limit 1;

  select e.org_unit_id into v_sr
  from core.org_unit_department e
  where e.company_id = v_company and e.department_id = v_hr and e.valid_to is null
    and e.org_unit_id not in (v_ho, v_pp)
  order by e.org_unit_id limit 1;

  if v_ho is null or v_pp is null or v_sr is null then
    raise exception 'FAIL: test needs the 3 sample org units with Department listings (Head Office, Phnom Penh Branch, Siem Reap Branch)';
  end if;

  if (select count(*) from core.position_allocation
      where company_id = v_company and valid_to is null) <> 1 then
    raise exception 'FAIL: test expects exactly one open allocation in the company (the seed one)';
  end if;

  select a.id, a.pos_unit_id, a.approved_headcount
  into v_a0, v_backend, v_a0_head
  from core.position_allocation a
  where a.company_id = v_company and a.org_unit_id = v_ho
    and a.job_position_id = v_swe and a.valid_to is null;

  if v_a0 is null then
    raise exception 'FAIL: seed allocation (Software Engineer at Head Office) not found';
  end if;

  select p.unit_id into v_acctsec
  from core.pos_unit_parent p
  join core.pos_unit u on u.id = p.unit_id and u.valid_to is null
  where p.parent_unit_id = v_fin and p.valid_to is null
  order by p.unit_id limit 1;

  if v_acctsec is null then
    raise exception 'FAIL: test needs an open Section under the Finance Department';
  end if;

  insert into core.tenant (name_en) values ('alloc test tenant')
  returning id into v_tenant2;

  -- ------------------------------------------------------------
  -- Users and assignments
  -- ------------------------------------------------------------
  u_admin    := pg_temp.new_user(v_tenant, 'admin');
  u_hr       := pg_temp.new_user(v_tenant, 'hr');
  u_view     := pg_temp.new_user(v_tenant, 'view');
  u_none     := pg_temp.new_user(v_tenant, 'none');
  u_dept     := pg_temp.new_user(v_tenant, 'dept');
  u_unit     := pg_temp.new_user(v_tenant, 'unit');
  u_outsider := pg_temp.new_user(v_tenant2, 'outsider');

  perform pg_temp.assign(v_tenant,  u_admin,    'tenant_admin', 'tenant');
  perform pg_temp.assign(v_tenant,  u_hr,       'hr_admin',     'tenant');
  perform pg_temp.assign(v_tenant,  u_view,     'viewer',       'tenant');
  perform pg_temp.assign(v_tenant,  u_dept,     'hr_admin',     'department', v_company, null, v_it);
  perform pg_temp.assign(v_tenant,  u_unit,     'hr_admin',     'org_unit',   v_company, v_pp);
  perform pg_temp.assign(v_tenant2, u_outsider, 'tenant_admin', 'tenant');

  -- ------------------------------------------------------------
  -- 0. Signatures and privileges
  -- ------------------------------------------------------------
  perform pg_temp.eq('old 5-argument private.create_allocation is gone',
    (to_regprocedure('private.create_allocation(integer,integer,integer,integer,integer)') is null)::text,
    'true');

  foreach v_sig in array array[
    'public.create_allocation(integer,integer,integer,integer,integer,date)',
    'public.close_allocation(integer,integer,date)',
    'public.change_allocation_headcount(integer,integer,integer,date)'
  ] loop
    perform pg_temp.eq('authenticated can run ' || v_sig,
      has_function_privilege('authenticated', v_sig, 'execute')::text, 'true');
    perform pg_temp.eq('service_role can run ' || v_sig,
      has_function_privilege('service_role', v_sig, 'execute')::text, 'true');
    perform pg_temp.eq('anon cannot run ' || v_sig,
      has_function_privilege('anon', v_sig, 'execute')::text, 'false');
  end loop;

  v_sig := 'private.create_allocation(integer,integer,integer,integer,integer,date)';
  perform pg_temp.eq('authenticated cannot run ' || v_sig,
    has_function_privilege('authenticated', v_sig, 'execute')::text, 'false');
  perform pg_temp.eq('anon cannot run ' || v_sig,
    has_function_privilege('anon', v_sig, 'execute')::text, 'false');
  perform pg_temp.eq('service_role can run ' || v_sig,
    has_function_privilege('service_role', v_sig, 'execute')::text, 'true');

  -- ------------------------------------------------------------
  -- A. private.create_allocation with a start date
  -- ------------------------------------------------------------
  perform pg_temp.no_login();

  v_a1 := pg_temp.run_int('A: 5-argument call still works',
    pg_temp.q_priv(v_company, v_pp, v_acct, v_fin, 2));
  perform pg_temp.eq('A: default start date is today', pg_temp.a_from(v_a1), current_date::text);
  perform pg_temp.eq('A: new allocation is open', pg_temp.a_to(v_a1), null);

  perform pg_temp.expect_error('A: start date before everything started',
    pg_temp.q_priv(v_company, v_pp, v_finmgr, v_fin, 1, current_date - 36500),
    c_early);
  perform pg_temp.eq('A: refused start date created nothing',
    pg_temp.open_count(v_pp, v_finmgr, v_fin), '0');

  perform pg_temp.expect_error('A: job not offered at this org unit',
    pg_temp.q_priv(v_company, v_pp, v_swe, v_it, 1),
    'This job position is not offered at this org unit');

  v_a2 := pg_temp.run_int('A: future start date',
    pg_temp.q_priv(v_company, v_pp, v_hro, v_hr, 1, current_date + 30));
  perform pg_temp.eq('A: future start date stored', pg_temp.a_from(v_a2), (current_date + 30)::text);
  perform pg_temp.eq('A: future allocation is open', pg_temp.a_to(v_a2), null);

  -- ------------------------------------------------------------
  -- B1. public.create_allocation
  -- ------------------------------------------------------------
  perform pg_temp.act_as(u_admin);
  v_w1 := pg_temp.run_int('create: tenant_admin',
    pg_temp.q_create(v_company, v_pp, v_finmgr, v_fin, 3));
  perform pg_temp.eq('create: headcount saved', pg_temp.a_head(v_w1), '3');
  perform pg_temp.eq('create: start date defaults to today', pg_temp.a_from(v_w1), current_date::text);
  perform pg_temp.eq('create: allocation is open', pg_temp.a_to(v_w1), null);

  perform pg_temp.act_as(u_hr);
  v_w2 := pg_temp.run_int('create: hr_admin with explicit date',
    pg_temp.q_create(v_company, v_sr, v_hro, v_hr, 4, current_date));
  perform pg_temp.eq('create: explicit start date saved', pg_temp.a_from(v_w2), current_date::text);

  perform pg_temp.act_as(u_view);
  perform pg_temp.expect_error('create: viewer is denied',
    pg_temp.q_create(v_company, v_ho, v_hro, v_hr, 1), c_denied, '42501');
  perform pg_temp.eq('create: viewer created nothing', pg_temp.open_count(v_ho, v_hro, v_hr), '0');

  perform pg_temp.act_as(u_none);
  perform pg_temp.expect_error('create: member with no role is denied',
    pg_temp.q_create(v_company, v_ho, v_hro, v_hr, 1), c_denied, '42501');

  perform pg_temp.act_as(u_outsider);
  perform pg_temp.expect_error('create: other tenant is denied',
    pg_temp.q_create(v_company, v_ho, v_hro, v_hr, 1), c_denied, '42501');

  perform pg_temp.no_login();
  perform pg_temp.expect_error('create: no login is denied',
    pg_temp.q_create(v_company, v_ho, v_hro, v_hr, 1), c_denied, '42501');
  perform pg_temp.eq('create: denied callers created nothing', pg_temp.open_count(v_ho, v_hro, v_hr), '0');

  perform pg_temp.act_as(u_dept);
  v_w6 := pg_temp.run_int('create: IT Department admin, IT job',
    pg_temp.q_create(v_company, v_ho, v_sysadm, v_it, 1));
  perform pg_temp.expect_error('create: IT Department admin, Finance job is denied',
    pg_temp.q_create(v_company, v_ho, v_finmgr, v_fin, 1), c_denied, '42501');
  perform pg_temp.eq('create: Finance job not created', pg_temp.open_count(v_ho, v_finmgr, v_fin), '0');

  perform pg_temp.act_as(u_unit);
  v_w7 := pg_temp.run_int('create: Phnom Penh admin, at Phnom Penh',
    pg_temp.q_create(v_company, v_pp, v_acct, v_acctsec, 1));
  perform pg_temp.expect_error('create: Phnom Penh admin, at Head Office is denied',
    pg_temp.q_create(v_company, v_ho, v_acct, v_acctsec, 1), c_denied, '42501');
  perform pg_temp.eq('create: Head Office allocation not created', pg_temp.open_count(v_ho, v_acct, v_acctsec), '0');

  perform pg_temp.act_as(u_admin);
  perform pg_temp.expect_error('create: job not offered at the org unit',
    pg_temp.q_create(v_company, v_pp, v_swe, v_it, 1),
    'This job position is not offered at this org unit');
  perform pg_temp.expect_error('create: start date before everything started',
    pg_temp.q_create(v_company, v_ho, v_sysadm, v_backend, 1, current_date - 36500), c_early);
  perform pg_temp.expect_error('create: duplicate open allocation',
    pg_temp.q_create(v_company, v_pp, v_finmgr, v_fin, 1), '', '23505');
  perform pg_temp.expect_error('create: negative headcount',
    pg_temp.q_create(v_company, v_ho, v_hro, v_hr, -1), '', '23514');
  perform pg_temp.eq('create: failed calls created nothing', pg_temp.open_count(v_ho, v_hro, v_hr), '0');

  -- ------------------------------------------------------------
  -- B2. public.close_allocation
  -- ------------------------------------------------------------
  perform pg_temp.act_as(u_view);
  perform pg_temp.expect_error('close: viewer is denied',
    pg_temp.q_close(v_company, v_w1), c_denied, '42501');
  perform pg_temp.eq('close: viewer left it open', pg_temp.a_to(v_w1), null);

  perform pg_temp.act_as(u_outsider);
  perform pg_temp.expect_error('close: other tenant is denied',
    pg_temp.q_close(v_company, v_w1), c_denied, '42501');
  perform pg_temp.expect_error('close: other tenant, unknown id gets no hint',
    pg_temp.q_close(v_company, -1), c_denied, '42501');

  perform pg_temp.no_login();
  perform pg_temp.expect_error('close: no login is denied',
    pg_temp.q_close(v_company, v_w1), c_denied, '42501');

  perform pg_temp.act_as(u_admin);
  perform pg_temp.expect_error('close: member, unknown id',
    pg_temp.q_close(v_company, -1), c_notopen);

  perform pg_temp.act_as(u_dept);
  perform pg_temp.expect_error('close: IT Department admin, Finance allocation is denied',
    pg_temp.q_close(v_company, v_a1), c_denied, '42501');
  perform pg_temp.run('close: IT Department admin, IT allocation',
    pg_temp.q_close(v_company, v_w6));
  perform pg_temp.eq('close: IT allocation closed today', pg_temp.a_to(v_w6), current_date::text);

  perform pg_temp.act_as(u_unit);
  perform pg_temp.expect_error('close: Phnom Penh admin, Head Office allocation is denied',
    pg_temp.q_close(v_company, v_a0), c_denied, '42501');
  perform pg_temp.eq('close: Head Office allocation still open', pg_temp.a_to(v_a0), null);
  perform pg_temp.run('close: Phnom Penh admin, Phnom Penh allocation',
    pg_temp.q_close(v_company, v_w7));
  perform pg_temp.eq('close: Phnom Penh allocation closed', pg_temp.a_to(v_w7), current_date::text);

  perform pg_temp.act_as(u_admin);
  perform pg_temp.run('close: tenant_admin', pg_temp.q_close(v_company, v_w1, current_date));
  perform pg_temp.eq('close: closed on the given date', pg_temp.a_to(v_w1), current_date::text);
  perform pg_temp.expect_error('close: already closed',
    pg_temp.q_close(v_company, v_w1), c_notopen);

  perform pg_temp.expect_error('close: date before the allocation started',
    pg_temp.q_close(v_company, v_w2, current_date - 5), c_early);
  perform pg_temp.eq('close: refused date left it open', pg_temp.a_to(v_w2), null);

  perform pg_temp.act_as(u_hr);
  perform pg_temp.run('close: future date', pg_temp.q_close(v_company, v_w2, current_date + 10));
  perform pg_temp.eq('close: future date stored', pg_temp.a_to(v_w2), (current_date + 10)::text);

  -- ------------------------------------------------------------
  -- B3. public.change_allocation_headcount
  -- ------------------------------------------------------------
  perform pg_temp.act_as(u_view);
  perform pg_temp.expect_error('change: viewer is denied',
    pg_temp.q_change(v_company, v_a0, v_a0_head + 3), c_denied, '42501');

  perform pg_temp.no_login();
  perform pg_temp.expect_error('change: no login is denied',
    pg_temp.q_change(v_company, v_a0, v_a0_head + 3), c_denied, '42501');

  perform pg_temp.act_as(u_dept);
  perform pg_temp.expect_error('change: IT Department admin, Finance allocation is denied',
    pg_temp.q_change(v_company, v_a1, 9), c_denied, '42501');
  perform pg_temp.eq('change: denied calls left the seed allocation alone', pg_temp.a_to(v_a0), null);
  perform pg_temp.eq('change: denied calls left the headcount alone', pg_temp.a_head(v_a0), v_a0_head::text);
  perform pg_temp.eq('change: Finance allocation unchanged', pg_temp.a_head(v_a1), '2');

  perform pg_temp.act_as(u_admin);
  perform pg_temp.expect_error('change: same headcount',
    pg_temp.q_change(v_company, v_a0, v_a0_head),
    'The new headcount is the same as the current headcount');
  perform pg_temp.eq('change: same headcount left it open', pg_temp.a_to(v_a0), null);

  perform pg_temp.expect_error('change: member, unknown id',
    pg_temp.q_change(v_company, -1, 9), c_notopen);

  -- normal change
  v_n := pg_temp.run_int('change: tenant_admin',
    pg_temp.q_change(v_company, v_a0, v_a0_head + 3, current_date));
  perform pg_temp.eq('change: new allocation is a different row', (v_n <> v_a0)::text, 'true');
  perform pg_temp.eq('change: old allocation closed on the date', pg_temp.a_to(v_a0), current_date::text);
  perform pg_temp.eq('change: new allocation starts on the same date', pg_temp.a_from(v_n), current_date::text);
  perform pg_temp.eq('change: new allocation is open', pg_temp.a_to(v_n), null);
  perform pg_temp.eq('change: new headcount', pg_temp.a_head(v_n), (v_a0_head + 3)::text);
  perform pg_temp.eq('change: one open allocation for the same place',
    pg_temp.open_count(v_ho, v_swe, v_backend), '1');
  perform pg_temp.eq('change: same org unit, job and position unit',
    (select (org_unit_id = v_ho and job_position_id = v_swe and pos_unit_id = v_backend)::text
     from core.position_allocation where id = v_n), 'true');

  -- change on the day the allocation started (zero-length old row)
  v_x := pg_temp.run_int('change: create allocation to change today',
    pg_temp.q_create(v_company, v_ho, v_sysadm, v_backend, 2));
  v_x2 := pg_temp.run_int('change: same-day change',
    pg_temp.q_change(v_company, v_x, 3, current_date));
  perform pg_temp.eq('change: same-day old row closed on its start date', pg_temp.a_to(v_x), current_date::text);
  perform pg_temp.eq('change: same-day old row start date', pg_temp.a_from(v_x), current_date::text);
  perform pg_temp.eq('change: same-day new row open', pg_temp.a_to(v_x2), null);
  perform pg_temp.eq('change: same-day new headcount', pg_temp.a_head(v_x2), '3');

  -- Department admin can change an allocation of their own Department
  perform pg_temp.act_as(u_dept);
  v_x3 := pg_temp.run_int('change: IT Department admin, IT allocation',
    pg_temp.q_change(v_company, v_x2, 4, current_date));
  perform pg_temp.eq('change: Department admin new headcount', pg_temp.a_head(v_x3), '4');

  -- all or nothing: the replacement fails, so the close must roll back too
  perform pg_temp.act_as(u_admin);
  perform pg_temp.expect_error('change: negative headcount is refused',
    pg_temp.q_change(v_company, v_x3, -1), '', '23514');
  perform pg_temp.eq('change: failed change left the old row open', pg_temp.a_to(v_x3), null);
  perform pg_temp.eq('change: failed change left the old headcount', pg_temp.a_head(v_x3), '4');
  perform pg_temp.eq('change: failed change created no new row',
    pg_temp.open_count(v_ho, v_sysadm, v_backend), '1');

  perform pg_temp.expect_error('change: date before the allocation started',
    pg_temp.q_change(v_company, v_x3, 5, current_date - 5), c_early);
  perform pg_temp.eq('change: refused date left the old row open', pg_temp.a_to(v_x3), null);
  perform pg_temp.eq('change: refused date created no new row',
    pg_temp.open_count(v_ho, v_sysadm, v_backend), '1');
end;
$$;

rollback;

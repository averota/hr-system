-- 016-020 test: write wrappers for org units, position units, job positions,
-- Department listings and hierarchy rules (ORG Stage 9c-3 to 9c-7)
-- DEV project only. Paste into Supabase Dashboard -> SQL Editor.
-- Needs migrations 015 to 020 applied and the dev sample data
-- (002_seed_dev_org_sample.sql), unchanged: company "Dev Parent Company" with
-- its 8 rules, 6 org units, 6 position units, 6 listings, 5 jobs and exactly
-- ONE open allocation (Software Engineer at Head Office, headcount 5).
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
  insert into auth.users (id, email) values (v_id, p_name || '@wrap-test.invalid');
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

-- the statement must be refused with the "no permission" error (42501) for each
-- listed user and for a caller who is not logged in
create function pg_temp.deny_each(
  p_label text, p_sql text, p_msg text, p_users uuid[]
)
returns void
language plpgsql
as $$
declare
  v_user uuid;
  v_i    integer := 0;
begin
  foreach v_user in array p_users loop
    v_i := v_i + 1;
    perform pg_temp.act_as(v_user);
    perform pg_temp.expect_error(p_label || ' (caller ' || v_i || ')', p_sql, p_msg, '42501');
  end loop;

  perform pg_temp.no_login();
  perform pg_temp.expect_error(p_label || ' (no login)', p_sql, p_msg, '42501');
end;
$$;

-- lookups
create function pg_temp.lvl(p_code text) returns integer language sql as $$
  select id from core.hierarchy_level where code = p_code $$;
create function pg_temp.org_id(p_company integer, p_name text) returns integer language sql as $$
  select id from core.org_unit where company_id = p_company and name_en = p_name and valid_to is null $$;
create function pg_temp.pos_id(p_company integer, p_name text) returns integer language sql as $$
  select id from core.pos_unit where company_id = p_company and name_en = p_name and valid_to is null $$;
create function pg_temp.job_id(p_company integer, p_name text) returns integer language sql as $$
  select id from core.job_position where company_id = p_company and name_en = p_name and valid_to is null $$;
create function pg_temp.rule_id(p_company integer, p_level text, p_parent text) returns integer language sql as $$
  select r.id
  from core.company_level_rule r
  join core.hierarchy_level l on l.id = r.level_id
  left join core.hierarchy_level pl on pl.id = r.parent_level_id
  where r.company_id = p_company and r.valid_to is null
    and l.code = p_level and pl.code is not distinct from p_parent $$;

-- readers (all return text)
create function pg_temp.org_to(p_id integer) returns text language sql as $$
  select valid_to::text from core.org_unit where id = p_id $$;
create function pg_temp.pos_to(p_id integer) returns text language sql as $$
  select valid_to::text from core.pos_unit where id = p_id $$;
create function pg_temp.org_name(p_id integer) returns text language sql as $$
  select name_en from core.org_unit where id = p_id $$;
create function pg_temp.pos_name(p_id integer) returns text language sql as $$
  select name_en from core.pos_unit where id = p_id $$;
create function pg_temp.org_parent(p_id integer) returns text language sql as $$
  select parent_unit_id::text from core.org_unit_parent where unit_id = p_id and valid_to is null $$;
create function pg_temp.pos_parent(p_id integer) returns text language sql as $$
  select parent_unit_id::text from core.pos_unit_parent where unit_id = p_id and valid_to is null $$;
create function pg_temp.job_name(p_id integer) returns text language sql as $$
  select name_en from core.job_position where id = p_id $$;
create function pg_temp.job_km(p_id integer) returns text language sql as $$
  select name_km from core.job_position where id = p_id $$;
create function pg_temp.job_to(p_id integer) returns text language sql as $$
  select valid_to::text from core.job_position where id = p_id $$;
create function pg_temp.job_count(p_dept integer, p_name text) returns text language sql as $$
  select count(*)::text from core.job_position where department_id = p_dept and name_en = p_name and valid_to is null $$;
create function pg_temp.alloc_to(p_id integer) returns text language sql as $$
  select valid_to::text from core.position_allocation where id = p_id $$;
create function pg_temp.listing_count(p_org integer, p_dept integer) returns text language sql as $$
  select count(*)::text from core.org_unit_department
  where org_unit_id = p_org and department_id = p_dept and valid_to is null $$;
create function pg_temp.rule_to(p_id integer) returns text language sql as $$
  select valid_to::text from core.company_level_rule where id = p_id $$;

-- ---------------------------------------------------------------
-- Tests
-- ---------------------------------------------------------------
do $$
declare
  v_company  integer;
  v_tenant   integer;
  v_tenant2  integer;

  lv_bu integer; lv_branch integer; lv_division integer;
  lv_dept integer; lv_office integer; lv_section integer; lv_group integer;

  o_retail integer; o_pp integer; o_sr integer; o_ho integer; o_cs integer; o_ops integer;
  p_it integer; p_fin integer; p_hr integer; p_devoff integer; p_backend integer; p_acctsec integer;
  j_swe integer; j_acct integer;

  u_admin uuid; u_hr uuid; u_view uuid; u_none uuid; u_outsider uuid;
  u_unit uuid;   -- hr_admin on Retail Banking (and below)
  u_ho uuid;     -- hr_admin on Head Office (and below)
  u_dept uuid;   -- hr_admin on the IT Department

  v_a integer; v_b integer; v_c integer; v_d integer;
  v_to integer; v_ts integer; v_ts2 integer; v_td integer;
  v_j1 integer; v_j2 integer; v_alloc integer;
  v_r1 integer; v_r2 integer; v_r3 integer;
  v_sig text;

  c_ou  constant text := 'You do not have permission to manage org units here';
  c_pu  constant text := 'You do not have permission to manage position units here';
  c_jb  constant text := 'You do not have permission to manage job positions here';
  c_dl  constant text := 'You do not have permission to manage Department listings here';
  c_cfg constant text := 'You do not have permission to change hierarchy rules here';
begin
  -- ------------------------------------------------------------
  -- Pick sample data
  -- ------------------------------------------------------------
  select c.id, c.tenant_id into v_company, v_tenant
  from core.parent_company c where c.name_en = 'Dev Parent Company';

  if v_company is null then
    raise exception 'FAIL: company "Dev Parent Company" not found. Run the dev seeds first';
  end if;

  lv_bu := pg_temp.lvl('business_unit'); lv_branch := pg_temp.lvl('branch');
  lv_division := pg_temp.lvl('division'); lv_dept := pg_temp.lvl('department');
  lv_office := pg_temp.lvl('office'); lv_section := pg_temp.lvl('section');
  lv_group := pg_temp.lvl('group');

  o_retail := pg_temp.org_id(v_company, 'Retail Banking');
  o_pp     := pg_temp.org_id(v_company, 'Phnom Penh Branch');
  o_sr     := pg_temp.org_id(v_company, 'Siem Reap Branch');
  o_ho     := pg_temp.org_id(v_company, 'Head Office');
  o_cs     := pg_temp.org_id(v_company, 'Customer Service');
  o_ops    := pg_temp.org_id(v_company, 'Operations');
  p_it     := pg_temp.pos_id(v_company, 'Information Technology');
  p_fin    := pg_temp.pos_id(v_company, 'Finance');
  p_hr     := pg_temp.pos_id(v_company, 'Human Resources');
  p_devoff := pg_temp.pos_id(v_company, 'Software Development Office');
  p_backend := pg_temp.pos_id(v_company, 'Backend Section');
  p_acctsec := pg_temp.pos_id(v_company, 'Accounting Section');
  j_swe    := pg_temp.job_id(v_company, 'Software Engineer');
  j_acct   := pg_temp.job_id(v_company, 'Accountant');

  if o_retail is null or o_pp is null or o_sr is null or o_ho is null or o_cs is null or o_ops is null
     or p_it is null or p_fin is null or p_hr is null or p_devoff is null or p_backend is null
     or p_acctsec is null or j_swe is null or j_acct is null then
    raise exception 'FAIL: test needs the unchanged sample data from 002_seed_dev_org_sample.sql';
  end if;

  if (select count(*) from core.position_allocation
      where company_id = v_company and valid_to is null) <> 1 then
    raise exception 'FAIL: test expects exactly one open allocation in the company (the seed one)';
  end if;

  insert into core.tenant (name_en) values ('wrap test tenant')
  returning id into v_tenant2;

  u_admin    := pg_temp.new_user(v_tenant, 'admin');
  u_hr       := pg_temp.new_user(v_tenant, 'hr');
  u_view     := pg_temp.new_user(v_tenant, 'view');
  u_none     := pg_temp.new_user(v_tenant, 'none');
  u_unit     := pg_temp.new_user(v_tenant, 'unit');
  u_ho       := pg_temp.new_user(v_tenant, 'ho');
  u_dept     := pg_temp.new_user(v_tenant, 'dept');
  u_outsider := pg_temp.new_user(v_tenant2, 'outsider');

  perform pg_temp.assign(v_tenant,  u_admin,    'tenant_admin', 'tenant');
  perform pg_temp.assign(v_tenant,  u_hr,       'hr_admin',     'tenant');
  perform pg_temp.assign(v_tenant,  u_view,     'viewer',       'tenant');
  perform pg_temp.assign(v_tenant,  u_unit,     'hr_admin',     'org_unit',   v_company, o_retail);
  perform pg_temp.assign(v_tenant,  u_ho,       'hr_admin',     'org_unit',   v_company, o_ho);
  perform pg_temp.assign(v_tenant,  u_dept,     'hr_admin',     'department', v_company, null, p_it);
  perform pg_temp.assign(v_tenant2, u_outsider, 'tenant_admin', 'tenant');

  -- ------------------------------------------------------------
  -- 0. Privileges and helpers
  -- ------------------------------------------------------------
  foreach v_sig in array array[
    'public.create_org_unit(integer,integer,integer,text,text)',
    'public.close_org_unit(integer,integer,date)',
    'public.reorg_org_unit(integer,integer,integer,date)',
    'public.create_pos_unit(integer,integer,integer,text,text)',
    'public.close_pos_unit(integer,integer,date)',
    'public.reorg_pos_unit(integer,integer,integer,date)',
    'public.create_job_position(integer,integer,text,text)',
    'public.rename_job_position(integer,integer,text,text)',
    'public.close_job_position(integer,integer,date)',
    'public.add_department_listing(integer,integer,integer,date)',
    'public.remove_department_listing(integer,integer,integer,date)',
    'public.enable_level_rule(integer,integer,integer)',
    'public.disable_level_rule(integer,integer,date)'
  ] loop
    perform pg_temp.eq('authenticated can run ' || v_sig,
      has_function_privilege('authenticated', v_sig, 'execute')::text, 'true');
    perform pg_temp.eq('service_role can run ' || v_sig,
      has_function_privilege('service_role', v_sig, 'execute')::text, 'true');
    perform pg_temp.eq('anon cannot run ' || v_sig,
      has_function_privilege('anon', v_sig, 'execute')::text, 'false');
  end loop;

  foreach v_sig in array array[
    'private.is_company_member(integer)',
    'private.can_manage_pos_unit(integer,integer)',
    'private.create_job_position(integer,integer,text,text)',
    'private.rename_job_position(integer,integer,text,text)',
    'private.close_job_position(integer,integer,date)',
    'private.add_department_listing(integer,integer,integer,date)',
    'private.remove_department_listing(integer,integer,integer,date)',
    'private.enable_level_rule(integer,integer,integer)',
    'private.disable_level_rule(integer,integer,date)'
  ] loop
    perform pg_temp.eq('authenticated cannot run ' || v_sig,
      has_function_privilege('authenticated', v_sig, 'execute')::text, 'false');
    perform pg_temp.eq('anon cannot run ' || v_sig,
      has_function_privilege('anon', v_sig, 'execute')::text, 'false');
    perform pg_temp.eq('service_role can run ' || v_sig,
      has_function_privilege('service_role', v_sig, 'execute')::text, 'true');
  end loop;

  perform pg_temp.act_as(u_admin);
  perform pg_temp.eq('is_company_member: member', private.is_company_member(v_company)::text, 'true');
  perform pg_temp.act_as(u_outsider);
  perform pg_temp.eq('is_company_member: other tenant', private.is_company_member(v_company)::text, 'false');
  perform pg_temp.no_login();
  perform pg_temp.eq('is_company_member: no login', private.is_company_member(v_company)::text, 'false');

  -- ============================================================
  -- 016: org units (org.unit.write)
  -- ============================================================
  -- create
  perform pg_temp.act_as(u_admin);
  v_a := pg_temp.run_int('org create: tenant_admin under Siem Reap',
    format('select public.create_org_unit(%L,%L,%L,%L,%L)',
           v_company, lv_division, o_sr, 'Test Division A', 'ផ្នែក ក'));
  perform pg_temp.eq('org create: name saved', pg_temp.org_name(v_a), 'Test Division A');
  perform pg_temp.eq('org create: parent saved', pg_temp.org_parent(v_a), o_sr::text);
  perform pg_temp.eq('org create: unit is open', pg_temp.org_to(v_a), null);

  v_c := pg_temp.run_int('org create: tenant_admin, Division C under Phnom Penh',
    format('select public.create_org_unit(%L,%L,%L,%L)', v_company, lv_division, o_pp, 'Test Division C'));

  perform pg_temp.act_as(u_unit);
  v_b := pg_temp.run_int('org create: Retail Banking admin, under Phnom Penh',
    format('select public.create_org_unit(%L,%L,%L,%L)', v_company, lv_division, o_pp, 'Test Division B'));

  perform pg_temp.act_as(u_admin);
  v_d := pg_temp.run_int('org create: tenant_admin, Branch directly under the company',
    format('select public.create_org_unit(%L,%L,%L,%L)', v_company, lv_branch, null, 'Test Root Branch'));
  perform pg_temp.eq('org create: root unit has no parent', pg_temp.org_parent(v_d), null);

  perform pg_temp.deny_each('org create: denied under Siem Reap',
    format('select public.create_org_unit(%L,%L,%L,%L)', v_company, lv_division, o_sr, 'Denied Division'),
    c_ou, array[u_view, u_none, u_outsider, u_ho, u_dept]);
  perform pg_temp.act_as(u_unit);
  perform pg_temp.expect_error('org create: Retail Banking admin at Head Office',
    format('select public.create_org_unit(%L,%L,%L,%L)', v_company, lv_division, o_ho, 'Denied Division'),
    c_ou, '42501');
  perform pg_temp.expect_error('org create: Retail Banking admin directly under the company',
    format('select public.create_org_unit(%L,%L,%L,%L)', v_company, lv_branch, null, 'Denied Branch'),
    c_ou, '42501');
  perform pg_temp.act_as(u_hr);
  perform pg_temp.run('org create: hr_admin directly under the company is allowed (company-wide role)',
    format('select public.create_org_unit(%L,%L,%L,%L)', v_company, lv_branch, null, 'Test Root Branch 2'));

  perform pg_temp.act_as(u_admin);
  perform pg_temp.expect_error('org create: blank English name',
    format('select public.create_org_unit(%L,%L,%L,%L)', v_company, lv_division, o_sr, '   '),
    'The English name is required');
  perform pg_temp.expect_error('org create: unknown parent (member)',
    format('select public.create_org_unit(%L,%L,%L,%L)', v_company, lv_division, -1, 'X'),
    'Parent unit -1 is not an open unit of this company');
  perform pg_temp.act_as(u_outsider);
  perform pg_temp.expect_error('org create: unknown parent (other tenant gets no hint)',
    format('select public.create_org_unit(%L,%L,%L,%L)', v_company, lv_division, -1, 'X'),
    c_ou, '42501');
  perform pg_temp.act_as(u_admin);
  perform pg_temp.expect_error('org create: no rule allows a Division directly under the company',
    format('select public.create_org_unit(%L,%L,%L,%L)', v_company, lv_division, null, 'X'),
    'No active rule allows this level under this parent');

  -- close
  perform pg_temp.deny_each('org close: denied',
    format('select public.close_org_unit(%L,%L)', v_company, v_a),
    c_ou, array[u_view, u_none, u_outsider, u_ho, u_dept]);
  perform pg_temp.eq('org close: denied callers left it open', pg_temp.org_to(v_a), null);

  perform pg_temp.act_as(u_admin);
  perform pg_temp.expect_error('org close: unknown unit (member)',
    format('select public.close_org_unit(%L,%L)', v_company, -1),
    'Org unit -1 is not an open unit of this company');
  perform pg_temp.act_as(u_outsider);
  perform pg_temp.expect_error('org close: unknown unit (other tenant gets no hint)',
    format('select public.close_org_unit(%L,%L)', v_company, -1), c_ou, '42501');

  perform pg_temp.act_as(u_unit);
  perform pg_temp.expect_error('org close: Retail Banking admin, Head Office unit',
    format('select public.close_org_unit(%L,%L)', v_company, o_ops), c_ou, '42501');
  perform pg_temp.eq('org close: Operations still open', pg_temp.org_to(o_ops), null);
  perform pg_temp.run('org close: Retail Banking admin, unit below',
    format('select public.close_org_unit(%L,%L)', v_company, v_b));
  perform pg_temp.eq('org close: closed today', pg_temp.org_to(v_b), current_date::text);

  perform pg_temp.act_as(u_admin);
  perform pg_temp.expect_error('org close: unit with active units under it',
    format('select public.close_org_unit(%L,%L)', v_company, o_pp),
    'still has active units under it');
  perform pg_temp.expect_error('org close: date before the unit started',
    format('select public.close_org_unit(%L,%L,%L)', v_company, v_a, current_date - 5),
    'is earlier than');
  perform pg_temp.eq('org close: refused date left it open', pg_temp.org_to(v_a), null);
  perform pg_temp.run('org close: tenant_admin with date',
    format('select public.close_org_unit(%L,%L,%L)', v_company, v_a, current_date));
  perform pg_temp.expect_error('org close: already closed',
    format('select public.close_org_unit(%L,%L)', v_company, v_a),
    'is not an open unit of this company');

  -- reorg (Division C is under Phnom Penh)
  perform pg_temp.deny_each('org reorg: denied',
    format('select public.reorg_org_unit(%L,%L,%L)', v_company, v_c, o_sr),
    c_ou, array[u_view, u_none, u_outsider, u_ho, u_dept]);
  perform pg_temp.eq('org reorg: denied callers left it in place', pg_temp.org_parent(v_c), o_pp::text);

  perform pg_temp.act_as(u_unit);
  perform pg_temp.run('org reorg: Retail Banking admin, between two branches below it',
    format('select public.reorg_org_unit(%L,%L,%L)', v_company, v_c, o_sr));
  perform pg_temp.eq('org reorg: new parent', pg_temp.org_parent(v_c), o_sr::text);
  perform pg_temp.expect_error('org reorg: Retail Banking admin, into Head Office (no permission there)',
    format('select public.reorg_org_unit(%L,%L,%L)', v_company, v_c, o_ho), c_ou, '42501');
  perform pg_temp.eq('org reorg: refused move left it in place', pg_temp.org_parent(v_c), o_sr::text);
  perform pg_temp.expect_error('org reorg: Retail Banking admin, to the root (company-wide roles only)',
    format('select public.reorg_org_unit(%L,%L,%L)', v_company, v_c, null), c_ou, '42501');

  perform pg_temp.act_as(u_admin);
  perform pg_temp.expect_error('org reorg: to the root, no rule allows it',
    format('select public.reorg_org_unit(%L,%L,%L)', v_company, v_c, null),
    'No active rule allows this level under this parent');
  perform pg_temp.expect_error('org reorg: unknown new parent',
    format('select public.reorg_org_unit(%L,%L,%L)', v_company, v_c, -1),
    'New parent -1 is not an open unit of this company');
  perform pg_temp.expect_error('org reorg: already under this parent',
    format('select public.reorg_org_unit(%L,%L,%L)', v_company, v_c, o_sr),
    'The unit is already under this parent');
  perform pg_temp.expect_error('org reorg: unknown unit (member)',
    format('select public.reorg_org_unit(%L,%L,%L)', v_company, -1, o_sr),
    'Org unit -1 is not an open unit of this company');
  perform pg_temp.act_as(u_outsider);
  perform pg_temp.expect_error('org reorg: unknown unit (other tenant gets no hint)',
    format('select public.reorg_org_unit(%L,%L,%L)', v_company, -1, o_sr), c_ou, '42501');
  perform pg_temp.act_as(u_admin);
  perform pg_temp.expect_error('org reorg: date before the link started',
    format('select public.reorg_org_unit(%L,%L,%L,%L)', v_company, v_c, o_pp, current_date - 5),
    'is earlier than');
  perform pg_temp.run('org reorg: tenant_admin with date',
    format('select public.reorg_org_unit(%L,%L,%L,%L)', v_company, v_c, o_pp, current_date));
  perform pg_temp.eq('org reorg: moved back', pg_temp.org_parent(v_c), o_pp::text);

  -- ============================================================
  -- 017: position units (pos.unit.write)
  -- ============================================================
  -- create
  perform pg_temp.act_as(u_dept);
  v_to := pg_temp.run_int('pos create: IT Department admin, Office under IT',
    format('select public.create_pos_unit(%L,%L,%L,%L)', v_company, lv_office, p_it, 'Test Office IT'));
  perform pg_temp.eq('pos create: name saved', pg_temp.pos_name(v_to), 'Test Office IT');
  perform pg_temp.eq('pos create: parent saved', pg_temp.pos_parent(v_to), p_it::text);
  perform pg_temp.expect_error('pos create: IT Department admin, under Finance',
    format('select public.create_pos_unit(%L,%L,%L,%L)', v_company, lv_office, p_fin, 'Denied Office'),
    c_pu, '42501');
  perform pg_temp.expect_error('pos create: IT Department admin, a new Department',
    format('select public.create_pos_unit(%L,%L,%L,%L)', v_company, lv_dept, null, 'Denied Department'),
    c_pu, '42501');

  perform pg_temp.act_as(u_admin);
  v_td := pg_temp.run_int('pos create: tenant_admin, a new Department',
    format('select public.create_pos_unit(%L,%L,%L,%L)', v_company, lv_dept, null, 'Test Department'));
  perform pg_temp.eq('pos create: new Department has no parent', pg_temp.pos_parent(v_td), null);
  v_ts := pg_temp.run_int('pos create: tenant_admin, Section under an Office',
    format('select public.create_pos_unit(%L,%L,%L,%L)', v_company, lv_section, p_devoff, 'Test Section'));

  perform pg_temp.deny_each('pos create: denied under IT',
    format('select public.create_pos_unit(%L,%L,%L,%L)', v_company, lv_office, p_it, 'Denied Office'),
    c_pu, array[u_view, u_none, u_outsider, u_ho, u_unit]);
  perform pg_temp.act_as(u_admin);
  perform pg_temp.expect_error('pos create: blank English name',
    format('select public.create_pos_unit(%L,%L,%L,%L)', v_company, lv_office, p_it, ' '),
    'The English name is required');
  perform pg_temp.expect_error('pos create: unknown parent (member)',
    format('select public.create_pos_unit(%L,%L,%L,%L)', v_company, lv_office, -1, 'X'),
    'Parent unit -1 is not an open unit of this company');
  perform pg_temp.act_as(u_outsider);
  perform pg_temp.expect_error('pos create: unknown parent (other tenant gets no hint)',
    format('select public.create_pos_unit(%L,%L,%L,%L)', v_company, lv_office, -1, 'X'), c_pu, '42501');
  perform pg_temp.act_as(u_admin);
  perform pg_temp.expect_error('pos create: no rule allows an Office under an Office',
    format('select public.create_pos_unit(%L,%L,%L,%L)', v_company, lv_office, p_devoff, 'X'),
    'No active rule allows this level under this parent');

  -- close
  perform pg_temp.deny_each('pos close: denied',
    format('select public.close_pos_unit(%L,%L)', v_company, v_ts),
    c_pu, array[u_view, u_none, u_outsider, u_ho, u_unit]);
  perform pg_temp.eq('pos close: denied callers left it open', pg_temp.pos_to(v_ts), null);

  perform pg_temp.act_as(u_dept);
  perform pg_temp.expect_error('pos close: IT Department admin, Finance unit',
    format('select public.close_pos_unit(%L,%L)', v_company, p_acctsec), c_pu, '42501');
  perform pg_temp.expect_error('pos close: IT Department admin, the Department itself',
    format('select public.close_pos_unit(%L,%L)', v_company, p_it), c_pu, '42501');
  perform pg_temp.run('pos close: IT Department admin, Office under IT',
    format('select public.close_pos_unit(%L,%L)', v_company, v_to));
  perform pg_temp.eq('pos close: closed today', pg_temp.pos_to(v_to), current_date::text);

  perform pg_temp.act_as(u_admin);
  perform pg_temp.run('pos close: tenant_admin, an empty Department',
    format('select public.close_pos_unit(%L,%L)', v_company, v_td));
  perform pg_temp.eq('pos close: Department closed', pg_temp.pos_to(v_td), current_date::text);
  perform pg_temp.expect_error('pos close: Department with active units under it',
    format('select public.close_pos_unit(%L,%L)', v_company, p_fin),
    'still has active units under it');
  perform pg_temp.expect_error('pos close: date before the unit started',
    format('select public.close_pos_unit(%L,%L,%L)', v_company, v_ts, current_date - 5),
    'is earlier than');
  perform pg_temp.expect_error('pos close: unknown unit (member)',
    format('select public.close_pos_unit(%L,%L)', v_company, -1),
    'Position unit -1 is not an open unit of this company');
  perform pg_temp.act_as(u_outsider);
  perform pg_temp.expect_error('pos close: unknown unit (other tenant gets no hint)',
    format('select public.close_pos_unit(%L,%L)', v_company, -1), c_pu, '42501');

  -- reorg
  perform pg_temp.act_as(u_admin);
  v_ts2 := pg_temp.run_int('pos reorg: create Section directly under IT',
    format('select public.create_pos_unit(%L,%L,%L,%L)', v_company, lv_section, p_it, 'Test Section 2'));

  perform pg_temp.deny_each('pos reorg: denied',
    format('select public.reorg_pos_unit(%L,%L,%L)', v_company, v_ts2, p_devoff),
    c_pu, array[u_view, u_none, u_outsider, u_ho, u_unit]);
  perform pg_temp.eq('pos reorg: denied callers left it in place', pg_temp.pos_parent(v_ts2), p_it::text);

  perform pg_temp.act_as(u_dept);
  perform pg_temp.run('pos reorg: IT Department admin, inside IT',
    format('select public.reorg_pos_unit(%L,%L,%L)', v_company, v_ts2, p_devoff));
  perform pg_temp.eq('pos reorg: new parent', pg_temp.pos_parent(v_ts2), p_devoff::text);
  perform pg_temp.expect_error('pos reorg: IT Department admin, into Finance (no permission there)',
    format('select public.reorg_pos_unit(%L,%L,%L)', v_company, v_ts2, p_fin), c_pu, '42501');
  perform pg_temp.eq('pos reorg: refused move left it in place', pg_temp.pos_parent(v_ts2), p_devoff::text);
  perform pg_temp.expect_error('pos reorg: IT Department admin, to the top (company-wide roles only)',
    format('select public.reorg_pos_unit(%L,%L,%L)', v_company, v_ts, null), c_pu, '42501');
  perform pg_temp.expect_error('pos reorg: IT Department admin, the Department itself',
    format('select public.reorg_pos_unit(%L,%L,%L)', v_company, p_it, p_fin), c_pu, '42501');

  perform pg_temp.act_as(u_admin);
  perform pg_temp.run('pos reorg: tenant_admin, into another Department',
    format('select public.reorg_pos_unit(%L,%L,%L)', v_company, v_ts2, p_fin));
  perform pg_temp.eq('pos reorg: now under Finance', pg_temp.pos_parent(v_ts2), p_fin::text);

  perform pg_temp.act_as(u_dept);
  perform pg_temp.expect_error('pos reorg: IT Department admin, unit that is now in Finance',
    format('select public.reorg_pos_unit(%L,%L,%L)', v_company, v_ts2, p_it), c_pu, '42501');

  perform pg_temp.act_as(u_admin);
  perform pg_temp.expect_error('pos reorg: to the top, no rule allows it',
    format('select public.reorg_pos_unit(%L,%L,%L)', v_company, v_ts, null),
    'No active rule allows this level under this parent');
  perform pg_temp.expect_error('pos reorg: a Department cannot move',
    format('select public.reorg_pos_unit(%L,%L,%L)', v_company, p_hr, p_it),
    'No active rule allows this level under this parent');
  perform pg_temp.expect_error('pos reorg: unknown new parent',
    format('select public.reorg_pos_unit(%L,%L,%L)', v_company, v_ts, -1),
    'New parent -1 is not an open unit of this company');
  perform pg_temp.expect_error('pos reorg: already under this parent',
    format('select public.reorg_pos_unit(%L,%L,%L)', v_company, v_ts, p_devoff),
    'The unit is already under this parent');
  perform pg_temp.expect_error('pos reorg: date before the link started',
    format('select public.reorg_pos_unit(%L,%L,%L,%L)', v_company, v_ts, p_it, current_date - 5),
    'is earlier than');
  perform pg_temp.expect_error('pos reorg: unknown unit (member)',
    format('select public.reorg_pos_unit(%L,%L,%L)', v_company, -1, p_it),
    'Position unit -1 is not an open unit of this company');
  perform pg_temp.act_as(u_outsider);
  perform pg_temp.expect_error('pos reorg: unknown unit (other tenant gets no hint)',
    format('select public.reorg_pos_unit(%L,%L,%L)', v_company, -1, p_it), c_pu, '42501');

  -- ============================================================
  -- 018: job positions (pos.job.write)
  -- ============================================================
  -- create
  perform pg_temp.act_as(u_dept);
  v_j1 := pg_temp.run_int('job create: IT Department admin',
    format('select public.create_job_position(%L,%L,%L,%L)', v_company, p_it, '  Test Job IT  ', 'ការងារ'));
  perform pg_temp.eq('job create: name is trimmed', pg_temp.job_name(v_j1), 'Test Job IT');
  perform pg_temp.eq('job create: Khmer name saved', pg_temp.job_km(v_j1), 'ការងារ');
  perform pg_temp.expect_error('job create: IT Department admin, Finance Department',
    format('select public.create_job_position(%L,%L,%L)', v_company, p_fin, 'Denied Job'),
    c_jb, '42501');
  perform pg_temp.eq('job create: Finance job not created', pg_temp.job_count(p_fin, 'Denied Job'), '0');

  perform pg_temp.deny_each('job create: denied in IT',
    format('select public.create_job_position(%L,%L,%L)', v_company, p_it, 'Denied Job'),
    c_jb, array[u_view, u_none, u_outsider, u_ho, u_unit]);
  perform pg_temp.eq('job create: denied callers created nothing', pg_temp.job_count(p_it, 'Denied Job'), '0');

  perform pg_temp.act_as(u_admin);
  perform pg_temp.expect_error('job create: duplicate name in the Department',
    format('select public.create_job_position(%L,%L,%L)', v_company, p_it, 'Software Engineer'),
    'already exists in this Department');
  perform pg_temp.expect_error('job create: blank English name',
    format('select public.create_job_position(%L,%L,%L)', v_company, p_it, '  '),
    'The English name is required');
  perform pg_temp.expect_error('job create: not a Department (member)',
    format('select public.create_job_position(%L,%L,%L)', v_company, p_backend, 'X'),
    'is not an open Department of this company');
  perform pg_temp.act_as(u_outsider);
  perform pg_temp.expect_error('job create: not a Department (other tenant gets no hint)',
    format('select public.create_job_position(%L,%L,%L)', v_company, -1, 'X'), c_jb, '42501');

  -- rename
  perform pg_temp.deny_each('job rename: denied',
    format('select public.rename_job_position(%L,%L,%L)', v_company, v_j1, 'Denied Name'),
    c_jb, array[u_view, u_none, u_outsider, u_ho, u_unit]);
  perform pg_temp.eq('job rename: denied callers left the name', pg_temp.job_name(v_j1), 'Test Job IT');

  perform pg_temp.act_as(u_dept);
  perform pg_temp.run('job rename: IT Department admin, clears the Khmer name',
    format('select public.rename_job_position(%L,%L,%L)', v_company, v_j1, 'Test Job IT Renamed'));
  perform pg_temp.eq('job rename: new name', pg_temp.job_name(v_j1), 'Test Job IT Renamed');
  perform pg_temp.eq('job rename: Khmer name cleared', pg_temp.job_km(v_j1), null);
  perform pg_temp.expect_error('job rename: IT Department admin, Finance job',
    format('select public.rename_job_position(%L,%L,%L)', v_company, j_acct, 'Denied Name'),
    c_jb, '42501');
  perform pg_temp.expect_error('job rename: name already used in the Department',
    format('select public.rename_job_position(%L,%L,%L)', v_company, v_j1, 'Software Engineer'),
    'already exists in this Department');
  perform pg_temp.expect_error('job rename: blank English name',
    format('select public.rename_job_position(%L,%L,%L)', v_company, v_j1, ' '),
    'The English name is required');
  perform pg_temp.act_as(u_admin);
  perform pg_temp.expect_error('job rename: unknown job (member)',
    format('select public.rename_job_position(%L,%L,%L)', v_company, -1, 'X'),
    'Job position -1 is not an open job position of this company');
  perform pg_temp.act_as(u_outsider);
  perform pg_temp.expect_error('job rename: unknown job (other tenant gets no hint)',
    format('select public.rename_job_position(%L,%L,%L)', v_company, -1, 'X'), c_jb, '42501');

  -- close (with an allocation, to see it close too)
  perform pg_temp.act_as(u_admin);
  v_alloc := pg_temp.run_int('job close: create an allocation for the new job',
    format('select public.create_allocation(%L,%L,%L,%L,%L)', v_company, o_ho, v_j1, p_it, 2));

  perform pg_temp.deny_each('job close: denied',
    format('select public.close_job_position(%L,%L)', v_company, v_j1),
    c_jb, array[u_view, u_none, u_outsider, u_ho, u_unit]);
  perform pg_temp.eq('job close: denied callers left it open', pg_temp.job_to(v_j1), null);

  perform pg_temp.act_as(u_dept);
  perform pg_temp.run('job close: IT Department admin',
    format('select public.close_job_position(%L,%L)', v_company, v_j1));
  perform pg_temp.eq('job close: job closed today', pg_temp.job_to(v_j1), current_date::text);
  perform pg_temp.eq('job close: its allocation closed too', pg_temp.alloc_to(v_alloc), current_date::text);
  perform pg_temp.expect_error('job close: already closed',
    format('select public.close_job_position(%L,%L)', v_company, v_j1),
    'is not an open job position of this company');

  perform pg_temp.act_as(u_admin);
  v_j2 := pg_temp.run_int('job close: create a Finance job',
    format('select public.create_job_position(%L,%L,%L)', v_company, p_fin, 'Test Job Fin'));
  perform pg_temp.expect_error('job close: date before the job started',
    format('select public.close_job_position(%L,%L,%L)', v_company, v_j2, current_date - 5),
    'is earlier than');
  perform pg_temp.act_as(u_dept);
  perform pg_temp.expect_error('job close: IT Department admin, Finance job',
    format('select public.close_job_position(%L,%L)', v_company, v_j2), c_jb, '42501');
  perform pg_temp.act_as(u_admin);
  perform pg_temp.run('job close: tenant_admin, Finance job',
    format('select public.close_job_position(%L,%L)', v_company, v_j2));
  perform pg_temp.expect_error('job close: unknown job (member)',
    format('select public.close_job_position(%L,%L)', v_company, -1),
    'Job position -1 is not an open job position of this company');
  perform pg_temp.act_as(u_outsider);
  perform pg_temp.expect_error('job close: unknown job (other tenant gets no hint)',
    format('select public.close_job_position(%L,%L)', v_company, -1), c_jb, '42501');

  -- ============================================================
  -- 019: Department listings (org.eligibility.write)
  -- Siem Reap lists HR only. Phnom Penh lists Finance and HR. Head Office lists IT, Finance, HR.
  -- ============================================================
  -- add
  perform pg_temp.act_as(u_unit);
  perform pg_temp.run_int('listing add: Retail Banking admin, Finance at Siem Reap',
    format('select public.add_department_listing(%L,%L,%L)', v_company, o_sr, p_fin));
  perform pg_temp.eq('listing add: listed', pg_temp.listing_count(o_sr, p_fin), '1');
  perform pg_temp.expect_error('listing add: already listed',
    format('select public.add_department_listing(%L,%L,%L)', v_company, o_sr, p_fin),
    'is already listed for org unit');

  perform pg_temp.deny_each('listing add: denied at Siem Reap',
    format('select public.add_department_listing(%L,%L,%L)', v_company, o_sr, p_it),
    c_dl, array[u_view, u_none, u_outsider, u_ho, u_dept]);
  perform pg_temp.eq('listing add: denied callers added nothing', pg_temp.listing_count(o_sr, p_it), '0');

  perform pg_temp.act_as(u_admin);
  perform pg_temp.expect_error('listing add: not a Department',
    format('select public.add_department_listing(%L,%L,%L)', v_company, o_sr, p_backend),
    'is not an open Department of this company');
  perform pg_temp.expect_error('listing add: unknown org unit (member)',
    format('select public.add_department_listing(%L,%L,%L)', v_company, -1, p_it),
    'Org unit -1 is not an open unit of this company');
  perform pg_temp.act_as(u_outsider);
  perform pg_temp.expect_error('listing add: unknown org unit (other tenant gets no hint)',
    format('select public.add_department_listing(%L,%L,%L)', v_company, -1, p_it), c_dl, '42501');
  perform pg_temp.act_as(u_admin);
  perform pg_temp.expect_error('listing add: start date before everything started',
    format('select public.add_department_listing(%L,%L,%L,%L)', v_company, o_pp, p_it, current_date - 36500),
    'is earlier than');
  perform pg_temp.eq('listing add: refused date added nothing', pg_temp.listing_count(o_pp, p_it), '0');
  perform pg_temp.run_int('listing add: tenant_admin, IT at Phnom Penh',
    format('select public.add_department_listing(%L,%L,%L,%L)', v_company, o_pp, p_it, current_date));
  perform pg_temp.eq('listing add: IT listed at Phnom Penh', pg_temp.listing_count(o_pp, p_it), '1');

  -- remove
  perform pg_temp.deny_each('listing remove: denied at Siem Reap',
    format('select public.remove_department_listing(%L,%L,%L)', v_company, o_sr, p_fin),
    c_dl, array[u_view, u_none, u_outsider, u_ho, u_dept]);
  perform pg_temp.eq('listing remove: denied callers left it listed', pg_temp.listing_count(o_sr, p_fin), '1');

  perform pg_temp.act_as(u_admin);
  perform pg_temp.expect_error('listing remove: open allocations still use it',
    format('select public.remove_department_listing(%L,%L,%L)', v_company, o_ho, p_it),
    'Open allocations still use this Department at this org unit');
  perform pg_temp.expect_error('listing remove: date before the listing started',
    format('select public.remove_department_listing(%L,%L,%L,%L)', v_company, o_pp, p_it, current_date - 5),
    'is earlier than');
  perform pg_temp.eq('listing remove: refused date left it listed', pg_temp.listing_count(o_pp, p_it), '1');
  perform pg_temp.expect_error('listing remove: unknown org unit (member)',
    format('select public.remove_department_listing(%L,%L,%L)', v_company, -1, p_it),
    'Org unit -1 is not an open unit of this company');
  perform pg_temp.act_as(u_outsider);
  perform pg_temp.expect_error('listing remove: unknown org unit (other tenant gets no hint)',
    format('select public.remove_department_listing(%L,%L,%L)', v_company, -1, p_it), c_dl, '42501');

  perform pg_temp.act_as(u_unit);
  perform pg_temp.run('listing remove: Retail Banking admin, Finance at Siem Reap',
    format('select public.remove_department_listing(%L,%L,%L)', v_company, o_sr, p_fin));
  perform pg_temp.eq('listing remove: no longer listed', pg_temp.listing_count(o_sr, p_fin), '0');
  perform pg_temp.expect_error('listing remove: not listed',
    format('select public.remove_department_listing(%L,%L,%L)', v_company, o_sr, p_fin),
    'is not listed for org unit');

  perform pg_temp.act_as(u_admin);
  perform pg_temp.run('listing remove: tenant_admin, IT at Phnom Penh',
    format('select public.remove_department_listing(%L,%L,%L)', v_company, o_pp, p_it));
  perform pg_temp.eq('listing remove: IT no longer listed at Phnom Penh', pg_temp.listing_count(o_pp, p_it), '0');

  -- list again after removal
  perform pg_temp.expect_error('listing add again: start date before the earlier listing ended',
    format('select public.add_department_listing(%L,%L,%L,%L)', v_company, o_sr, p_fin, current_date - 1),
    'is earlier than');
  perform pg_temp.run_int('listing add again: same day the earlier listing ended',
    format('select public.add_department_listing(%L,%L,%L,%L)', v_company, o_sr, p_fin, current_date));
  perform pg_temp.eq('listing add again: listed once', pg_temp.listing_count(o_sr, p_fin), '1');

  -- ============================================================
  -- 020: hierarchy rules (org.config.write, company or tenant level only)
  -- ============================================================
  -- enable
  perform pg_temp.act_as(u_admin);
  v_r1 := pg_temp.run_int('rule enable: tenant_admin, Group under Section',
    format('select public.enable_level_rule(%L,%L,%L)', v_company, lv_group, lv_section));
  perform pg_temp.eq('rule enable: new rule is open', pg_temp.rule_to(v_r1), null);
  perform pg_temp.expect_error('rule enable: already enabled',
    format('select public.enable_level_rule(%L,%L,%L)', v_company, lv_group, lv_section),
    'This rule is already enabled for the company');

  perform pg_temp.act_as(u_hr);
  v_r2 := pg_temp.run_int('rule enable: hr_admin, Group under Office',
    format('select public.enable_level_rule(%L,%L,%L)', v_company, lv_group, lv_office));

  perform pg_temp.deny_each('rule enable: denied',
    format('select public.enable_level_rule(%L,%L,%L)', v_company, lv_group, lv_dept),
    c_cfg, array[u_view, u_none, u_outsider, u_unit, u_ho, u_dept]);
  perform pg_temp.eq('rule enable: denied callers added nothing',
    (select count(*)::text from core.company_level_rule
     where company_id = v_company and level_id = lv_group and parent_level_id = lv_dept and valid_to is null),
    '0');

  perform pg_temp.act_as(u_admin);
  perform pg_temp.expect_error('rule enable: parent in another tree',
    format('select public.enable_level_rule(%L,%L,%L)', v_company, lv_group, lv_bu),
    'The parent level must be in the same tree as the level');
  perform pg_temp.expect_error('rule enable: parent not higher up',
    format('select public.enable_level_rule(%L,%L,%L)', v_company, lv_section, lv_group),
    'A parent level must be higher up than its child level');
  perform pg_temp.expect_error('rule enable: unknown level',
    format('select public.enable_level_rule(%L,%L,%L)', v_company, -1, lv_section),
    'Level -1 does not exist');
  perform pg_temp.expect_error('rule enable: unknown parent level',
    format('select public.enable_level_rule(%L,%L,%L)', v_company, lv_group, -1),
    'Level -1 does not exist');
  perform pg_temp.expect_error('rule enable: level that cannot sit under the root',
    format('select public.enable_level_rule(%L,%L)', v_company, lv_office),
    'cannot sit directly under the root');

  -- disable
  perform pg_temp.deny_each('rule disable: denied',
    format('select public.disable_level_rule(%L,%L)', v_company, v_r1),
    c_cfg, array[u_view, u_none, u_outsider, u_unit, u_ho, u_dept]);
  perform pg_temp.eq('rule disable: denied callers left it open', pg_temp.rule_to(v_r1), null);

  perform pg_temp.act_as(u_admin);
  perform pg_temp.expect_error('rule disable: unknown rule (member)',
    format('select public.disable_level_rule(%L,%L)', v_company, -1),
    'Rule -1 is not an open rule of this company');
  perform pg_temp.act_as(u_outsider);
  perform pg_temp.expect_error('rule disable: unknown rule (other tenant gets no hint)',
    format('select public.disable_level_rule(%L,%L)', v_company, -1), c_cfg, '42501');

  perform pg_temp.act_as(u_admin);
  perform pg_temp.run('rule disable: tenant_admin',
    format('select public.disable_level_rule(%L,%L)', v_company, v_r1));
  perform pg_temp.eq('rule disable: closed today', pg_temp.rule_to(v_r1), current_date::text);
  perform pg_temp.expect_error('rule disable: already closed',
    format('select public.disable_level_rule(%L,%L)', v_company, v_r1),
    'is not an open rule of this company');
  perform pg_temp.expect_error('rule disable: date before the rule started',
    format('select public.disable_level_rule(%L,%L,%L)', v_company, v_r2, current_date - 5),
    'is earlier than');
  perform pg_temp.eq('rule disable: refused date left it open', pg_temp.rule_to(v_r2), null);
  perform pg_temp.act_as(u_hr);
  perform pg_temp.run('rule disable: hr_admin',
    format('select public.disable_level_rule(%L,%L)', v_company, v_r2));

  -- guard messages come through
  perform pg_temp.act_as(u_admin);
  perform pg_temp.expect_error('rule disable: required level',
    format('select public.disable_level_rule(%L,%L)', v_company, pg_temp.rule_id(v_company, 'department', null)),
    'is required and cannot be disabled');
  perform pg_temp.expect_error('rule disable: level that still has active units',
    format('select public.disable_level_rule(%L,%L)', v_company, pg_temp.rule_id(v_company, 'division', 'branch')),
    'still has active units');

  -- one of two rules of a level can be closed, and enabled again
  v_r3 := pg_temp.rule_id(v_company, 'branch', 'business_unit');
  perform pg_temp.run('rule disable: Branch under Business Unit (Branch under the root remains)',
    format('select public.disable_level_rule(%L,%L)', v_company, v_r3));
  perform pg_temp.eq('rule disable: that rule is closed', pg_temp.rule_to(v_r3), current_date::text);
  perform pg_temp.eq('rule disable: existing units keep their place', pg_temp.org_parent(o_pp), o_retail::text);
  perform pg_temp.run_int('rule enable: Branch under Business Unit again',
    format('select public.enable_level_rule(%L,%L,%L)', v_company, lv_branch, lv_bu));
  perform pg_temp.eq('rule enable: open again',
    pg_temp.rule_to(pg_temp.rule_id(v_company, 'branch', 'business_unit')), null);
end;
$$;

rollback;

-- 022_rename_unit_test.sql
-- Dev project only. Paste into Supabase Dashboard -> SQL Editor.
-- Rolls back at the end. "Success. No rows returned" = pass. "FAIL: ..." = a check failed.
-- Needs seed_dev_tenant.sql, seed_dev_org_sample.sql and migration 022.
-- v_admin_email must be a tenant member with the tenant_admin role (tenant-wide).

begin;

do $$
declare
  v_admin_email text := 'mek.rotha@gmail.com';
  v_company  integer;
  v_org      integer;
  v_sec      integer;
  v_dept     integer;
  v_admin    uuid;
  v_stranger uuid := gen_random_uuid();
  v_msg      text;
  v_state    text;
  r          record;
begin
  select c.id into v_company from core.parent_company c order by c.id limit 1;

  select u.id into v_org
  from core.org_unit u
  where u.company_id = v_company and u.valid_to is null
  order by u.id limit 1;

  select u.id into v_sec
  from core.pos_unit u join core.hierarchy_level h on h.id = u.level_id
  where u.company_id = v_company and u.valid_to is null and h.code = 'section'
  order by u.id limit 1;

  select u.id into v_dept
  from core.pos_unit u join core.hierarchy_level h on h.id = u.level_id
  where u.company_id = v_company and u.valid_to is null and h.code = 'department'
  order by u.id limit 1;

  select id into v_admin from auth.users where email = v_admin_email;

  if v_company is null or v_org is null or v_sec is null or v_dept is null or v_admin is null then
    raise exception 'FAIL: needs the dev seed data and the user %', v_admin_email;
  end if;

  -- ---------------------------------------------------------
  -- 1. Private functions (run as the SQL Editor role)
  -- ---------------------------------------------------------
  perform private.rename_org_unit(v_company, v_org, '  Renamed Org  ', '  Khmer Name  ');
  select name_en, name_km into r from core.org_unit where id = v_org;
  if r.name_en <> 'Renamed Org' or r.name_km is distinct from 'Khmer Name' then
    raise exception 'FAIL 1a: org names not saved trimmed (% / %)', r.name_en, r.name_km;
  end if;

  perform private.rename_org_unit(v_company, v_org, 'Renamed Org', '   ');
  select name_km into r from core.org_unit where id = v_org;
  if r.name_km is not null then
    raise exception 'FAIL 1b: empty Khmer name was not cleared';
  end if;

  v_msg := null;
  begin
    perform private.rename_org_unit(v_company, v_org, '   ', null);
  exception when others then v_msg := sqlerrm;
  end;
  if v_msg is distinct from 'The English name is required' then
    raise exception 'FAIL 1c: blank English name, got %', v_msg;
  end if;

  v_msg := null;
  begin
    perform private.rename_org_unit(v_company, -1, 'X', null);
  exception when others then v_msg := sqlerrm;
  end;
  if v_msg is distinct from 'Org unit -1 is not an open unit of this company' then
    raise exception 'FAIL 1d: unknown org unit, got %', v_msg;
  end if;

  perform private.rename_pos_unit(v_company, v_sec, '  Renamed Section ', 'Khmer Section');
  select name_en, name_km into r from core.pos_unit where id = v_sec;
  if r.name_en <> 'Renamed Section' or r.name_km is distinct from 'Khmer Section' then
    raise exception 'FAIL 1e: position names not saved (% / %)', r.name_en, r.name_km;
  end if;

  v_msg := null;
  begin
    perform private.rename_pos_unit(v_company, -1, 'X', null);
  exception when others then v_msg := sqlerrm;
  end;
  if v_msg is distinct from 'Position unit -1 is not an open unit of this company' then
    raise exception 'FAIL 1f: unknown position unit, got %', v_msg;
  end if;

  -- ---------------------------------------------------------
  -- 2. Public wrappers as a tenant-wide tenant_admin
  -- ---------------------------------------------------------
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
  set local role authenticated;

  perform public.rename_org_unit(v_company, v_org, 'Admin Org', 'Admin Org KM');
  perform public.rename_pos_unit(v_company, v_sec, 'Admin Section', null);
  perform public.rename_pos_unit(v_company, v_dept, 'Admin Department', null);

  v_msg := null;
  begin
    perform public.rename_org_unit(v_company, -1, 'X', null);
  exception when others then v_msg := sqlerrm;
  end;

  v_msg := coalesce(v_msg, '');
  if v_msg <> 'Org unit -1 is not an open unit of this company' then
    reset role;
    raise exception 'FAIL 2d: member naming an unknown unit, got %', v_msg;
  end if;

  v_msg := null;
  begin
    perform public.rename_org_unit(v_company, v_org, '  ', null);
  exception when others then v_msg := sqlerrm;
  end;
  if v_msg is distinct from 'The English name is required' then
    reset role;
    raise exception 'FAIL 2e: blank English name via wrapper, got %', v_msg;
  end if;
  reset role;

  select name_en, name_km into r from core.org_unit where id = v_org;
  if r.name_en <> 'Admin Org' or r.name_km is distinct from 'Admin Org KM' then
    raise exception 'FAIL 2a: wrapper did not rename the org unit';
  end if;
  select name_en, name_km into r from core.pos_unit where id = v_sec;
  if r.name_en <> 'Admin Section' or r.name_km is not null then
    raise exception 'FAIL 2b: wrapper did not rename the Section';
  end if;
  select name_en into r from core.pos_unit where id = v_dept;
  if r.name_en <> 'Admin Department' then
    raise exception 'FAIL 2c: tenant_admin could not rename a Department';
  end if;

  -- ---------------------------------------------------------
  -- 3. Public wrappers as a user who is not a member of the tenant
  -- ---------------------------------------------------------
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_stranger, 'role', 'authenticated')::text, true);
  set local role authenticated;

  v_state := null;
  begin
    perform public.rename_org_unit(v_company, v_org, 'Hacked', null);
  exception when others then get stacked diagnostics v_state = returned_sqlstate;
  end;
  if v_state is distinct from '42501' then
    reset role;
    raise exception 'FAIL 3a: non-member org rename, sqlstate %', v_state;
  end if;

  v_state := null;
  begin
    perform public.rename_pos_unit(v_company, v_sec, 'Hacked', null);
  exception when others then get stacked diagnostics v_state = returned_sqlstate;
  end;
  if v_state is distinct from '42501' then
    reset role;
    raise exception 'FAIL 3b: non-member position rename, sqlstate %', v_state;
  end if;
  reset role;

  select name_en into r from core.org_unit where id = v_org;
  if r.name_en <> 'Admin Org' then
    raise exception 'FAIL 3c: a non-member changed the org unit name';
  end if;

  -- ---------------------------------------------------------
  -- 4. Privileges
  -- ---------------------------------------------------------
  if has_function_privilege('anon', 'public.rename_org_unit(integer,integer,text,text)', 'execute')
     or has_function_privilege('anon', 'public.rename_pos_unit(integer,integer,text,text)', 'execute') then
    raise exception 'FAIL 4a: anon can call a rename wrapper';
  end if;
  if not has_function_privilege('authenticated', 'public.rename_org_unit(integer,integer,text,text)', 'execute')
     or not has_function_privilege('authenticated', 'public.rename_pos_unit(integer,integer,text,text)', 'execute') then
    raise exception 'FAIL 4b: authenticated cannot call a rename wrapper';
  end if;
  if has_function_privilege('authenticated', 'private.rename_org_unit(integer,integer,text,text)', 'execute')
     or has_function_privilege('authenticated', 'private.rename_pos_unit(integer,integer,text,text)', 'execute') then
    raise exception 'FAIL 4c: authenticated can call a private rename function';
  end if;
end;
$$;

rollback;

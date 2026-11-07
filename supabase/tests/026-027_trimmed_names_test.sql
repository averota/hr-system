-- Test for Part B of 026_name_history.sql (trimmed names in the create functions)
-- Paste into Supabase Dashboard -> SQL Editor (dev project only).
-- Creates its own tenant and company. Rolls back at the end.
-- "Success. No rows returned" = pass. An error starting with FAIL: = a check failed.
-- Uses private.enable_level_rule(company, level, parent level) from 020.

begin;

do $$
declare
  v_tenant   integer;
  v_company  integer;
  v_dept_lvl integer;
  v_bu_lvl   integer;
  v_dept     integer;
  v_org      integer;
  v_text     text;
begin
  -- Setup
  insert into core.tenant (name_en) values ('Trimmed names test') returning id into v_tenant;
  insert into core.parent_company (tenant_id, name_en)
    values (v_tenant, 'Trimmed names company') returning id into v_company;
  select id into v_dept_lvl from core.hierarchy_level where code = 'department';
  select id into v_bu_lvl   from core.hierarchy_level where code = 'business_unit';
  perform private.enable_level_rule(v_company, v_dept_lvl, null);
  perform private.enable_level_rule(v_company, v_bu_lvl, null);

  -- 1. Names are trimmed on create
  v_dept := private.create_pos_unit(v_company, v_dept_lvl, null, '  Finance  ', '  KM Finance  ');
  select name_en || '|' || name_km into v_text from core.pos_unit where id = v_dept;
  if v_text <> 'Finance|KM Finance' then
    raise exception 'FAIL: position unit names were not trimmed: %', v_text;
  end if;

  v_org := private.create_org_unit(v_company, v_bu_lvl, null, '  Head Office ', '   ');
  select name_en || '|' || coalesce(name_km, 'null') into v_text from core.org_unit where id = v_org;
  if v_text <> 'Head Office|null' then
    raise exception 'FAIL: org unit names were not trimmed: %', v_text;
  end if;

  -- 2. A blank English name is refused
  begin
    perform private.create_pos_unit(v_company, v_dept_lvl, null, '   ');
    raise exception 'FAIL: blank position unit name was accepted';
  exception when others then
    if sqlerrm <> 'The English name is required' then raise; end if;
  end;

  begin
    perform private.create_org_unit(v_company, v_bu_lvl, null, '   ');
    raise exception 'FAIL: blank org unit name was accepted';
  exception when others then
    if sqlerrm <> 'The English name is required' then raise; end if;
  end;
end;
$$;

rollback;

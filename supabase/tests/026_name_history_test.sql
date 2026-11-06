-- Test for 026_name_history.sql
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
  v_org2     integer;
  v_job      integer;
  v_rows     integer;
  v_text     text;
begin
  -- 1. Backfill: every existing record has a name history row
  select count(*) into v_rows from core.org_unit u
   where not exists (select 1 from core.name_history h
                      where h.entity = 'org_unit' and h.entity_id = u.id);
  if v_rows <> 0 then raise exception 'FAIL: % org units have no name history', v_rows; end if;

  select count(*) into v_rows from core.pos_unit u
   where not exists (select 1 from core.name_history h
                      where h.entity = 'pos_unit' and h.entity_id = u.id);
  if v_rows <> 0 then raise exception 'FAIL: % position units have no name history', v_rows; end if;

  select count(*) into v_rows from core.job_position j
   where not exists (select 1 from core.name_history h
                      where h.entity = 'job_position' and h.entity_id = j.id);
  if v_rows <> 0 then raise exception 'FAIL: % jobs have no name history', v_rows; end if;

  -- Setup
  insert into core.tenant (name_en) values ('Name history test') returning id into v_tenant;
  insert into core.parent_company (tenant_id, name_en)
    values (v_tenant, 'Name history company') returning id into v_company;
  select id into v_dept_lvl from core.hierarchy_level where code = 'department';
  select id into v_bu_lvl   from core.hierarchy_level where code = 'business_unit';
  perform private.enable_level_rule(v_company, v_dept_lvl, null);
  perform private.enable_level_rule(v_company, v_bu_lvl, null);

  -- 2. Names are trimmed on create
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

  -- 3. A blank English name is refused
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

  -- 4. Creating a unit writes one open name row starting on its start date
  select count(*) into v_rows from core.name_history
   where entity = 'pos_unit' and entity_id = v_dept and valid_to is null
     and valid_from = current_date and name_en = 'Finance';
  if v_rows <> 1 then raise exception 'FAIL: create did not write one open name row'; end if;

  -- 5. A rename on the same day replaces the first name
  perform private.rename_pos_unit(v_company, v_dept, 'Finance and Accounting', null);
  select count(*) into v_rows from core.name_history
   where entity = 'pos_unit' and entity_id = v_dept;
  if v_rows <> 1 then raise exception 'FAIL: same-day rename left % rows, expected 1', v_rows; end if;
  select count(*) into v_rows from core.name_history
   where entity = 'pos_unit' and entity_id = v_dept
     and valid_to is null and name_en = 'Finance and Accounting';
  if v_rows <> 1 then raise exception 'FAIL: same-day rename did not replace the name'; end if;

  -- 6. A rename on a later day closes the old row and starts a new one
  update core.name_history set valid_from = current_date - 10
   where entity = 'pos_unit' and entity_id = v_dept;
  perform private.rename_pos_unit(v_company, v_dept, 'Finance Dept', null);

  select count(*) into v_rows from core.name_history
   where entity = 'pos_unit' and entity_id = v_dept;
  if v_rows <> 2 then raise exception 'FAIL: later rename left % rows, expected 2', v_rows; end if;
  select count(*) into v_rows from core.name_history
   where entity = 'pos_unit' and entity_id = v_dept and name_en = 'Finance and Accounting'
     and valid_from = current_date - 10 and valid_to = current_date;
  if v_rows <> 1 then raise exception 'FAIL: old name row was not closed correctly'; end if;
  select count(*) into v_rows from core.name_history
   where entity = 'pos_unit' and entity_id = v_dept and name_en = 'Finance Dept'
     and valid_from = current_date and valid_to is null;
  if v_rows <> 1 then raise exception 'FAIL: new name row was not opened correctly'; end if;

  -- 7. A second rename on the same day replaces the new row, the old row stays
  perform private.rename_pos_unit(v_company, v_dept, 'Finance Division', null);
  select count(*) into v_rows from core.name_history
   where entity = 'pos_unit' and entity_id = v_dept;
  if v_rows <> 2 then raise exception 'FAIL: second same-day rename left % rows, expected 2', v_rows; end if;
  select count(*) into v_rows from core.name_history
   where entity = 'pos_unit' and entity_id = v_dept and name_en = 'Finance Division'
     and valid_to is null;
  if v_rows <> 1 then raise exception 'FAIL: second same-day rename did not replace the open name'; end if;
  select count(*) into v_rows from core.name_history
   where entity = 'pos_unit' and entity_id = v_dept and name_en = 'Finance and Accounting'
     and valid_to = current_date;
  if v_rows <> 1 then raise exception 'FAIL: second same-day rename changed the closed row'; end if;

  -- 8. Job positions follow the same rules
  v_job := private.create_job_position(v_company, v_dept, 'Accountant', null);
  select count(*) into v_rows from core.name_history
   where entity = 'job_position' and entity_id = v_job and valid_to is null and name_en = 'Accountant';
  if v_rows <> 1 then raise exception 'FAIL: job create did not write one open name row'; end if;

  update core.name_history set valid_from = current_date - 5
   where entity = 'job_position' and entity_id = v_job;
  perform private.rename_job_position(v_company, v_job, 'Senior Accountant', null);
  select count(*) into v_rows from core.name_history
   where entity = 'job_position' and entity_id = v_job;
  if v_rows <> 2 then raise exception 'FAIL: job rename left % rows, expected 2', v_rows; end if;

  -- 9. Closing a unit ends its name row on the close date
  perform private.close_org_unit(v_company, v_org, current_date);
  select count(*) into v_rows from core.name_history
   where entity = 'org_unit' and entity_id = v_org and valid_to = current_date;
  if v_rows <> 1 then raise exception 'FAIL: close did not end the name row'; end if;

  -- 10. Close date earlier than a later rename: the later name is dropped
  insert into core.org_unit (company_id, level_id, name_en, valid_from)
    values (v_company, v_bu_lvl, 'Old Name', current_date - 20)
    returning id into v_org2;
  update core.org_unit set name_en = 'New Name' where id = v_org2;

  select count(*) into v_rows from core.name_history
   where entity = 'org_unit' and entity_id = v_org2;
  if v_rows <> 2 then raise exception 'FAIL: backdated setup left % rows, expected 2', v_rows; end if;

  update core.org_unit set valid_to = current_date - 5 where id = v_org2;

  select count(*) into v_rows from core.name_history
   where entity = 'org_unit' and entity_id = v_org2;
  if v_rows <> 1 then raise exception 'FAIL: backdated close left % rows, expected 1', v_rows; end if;
  select count(*) into v_rows from core.name_history
   where entity = 'org_unit' and entity_id = v_org2
     and name_en = 'Old Name' and valid_to = current_date - 5;
  if v_rows <> 1 then raise exception 'FAIL: backdated close did not end the earlier name'; end if;
end;
$$;

rollback;

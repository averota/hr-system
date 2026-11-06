-- DEV ONLY seed: sample ORG data for "Dev Parent Company"
-- Run once in Supabase Dashboard -> SQL Editor (dev project).
-- Runs in one transaction: if anything fails, nothing is saved.
-- Refuses to run if the company already has rules, units or jobs.
--
-- Creates:
--   8 level rules   org: Business Unit, Branch (root and under BU), Division under Branch
--                   pos: Department, Office under Department, Section under Office and under Department
--   6 org units     Retail Banking > (Phnom Penh Branch > Customer Service, Siem Reap Branch)
--                   Head Office (Branch directly under the company) > Operations
--   6 position units  IT, Finance, HR Departments + Office and Sections
--   6 Department listings (Customer Service and Operations get none on purpose,
--                   so you can see the "not configured" message)
--   5 job positions
--   1 allocation    Software Engineer at Head Office, Backend Section, headcount 5
--                   (lets you see the "allocation already exists" warning)
-- Khmer names are samples for testing the EN / KH switch only.

do $$
declare
  v_company     integer;

  v_bu          integer;
  v_branch      integer;
  v_division    integer;
  v_dept        integer;
  v_office      integer;
  v_section     integer;

  o_retail      integer;
  o_pp          integer;
  o_cs          integer;
  o_sr          integer;
  o_ho          integer;
  o_ops         integer;

  p_it          integer;
  p_fin         integer;
  p_hr          integer;
  p_dev_office  integer;
  p_backend     integer;
  p_acct        integer;

  j_swe         integer;
  j_sysadmin    integer;
  j_acct        integer;
  j_finmgr      integer;
  j_hro         integer;

  r             record;
begin
  select id into v_company
  from core.parent_company
  where name_en = 'Dev Parent Company';

  if v_company is null then
    raise exception 'Company "Dev Parent Company" not found. Run seed_dev_tenant.sql first.';
  end if;

  if exists (select 1 from core.company_level_rule where company_id = v_company)
     or exists (select 1 from core.org_unit        where company_id = v_company)
     or exists (select 1 from core.pos_unit        where company_id = v_company)
     or exists (select 1 from core.job_position    where company_id = v_company) then
    raise exception 'Company % already has ORG data. Seed not run.', v_company;
  end if;

  select id into v_bu       from core.hierarchy_level where code = 'business_unit';
  select id into v_branch   from core.hierarchy_level where code = 'branch';
  select id into v_division from core.hierarchy_level where code = 'division';
  select id into v_dept     from core.hierarchy_level where code = 'department';
  select id into v_office   from core.hierarchy_level where code = 'office';
  select id into v_section  from core.hierarchy_level where code = 'section';

  -- -------------------------------------------------------------
  -- 1. Level rules (a parent level must be enabled before its children)
  -- -------------------------------------------------------------
  for r in
    select *
    from (values
      (1, 'business_unit', null),
      (2, 'branch',        null),
      (3, 'branch',        'business_unit'),
      (4, 'division',      'branch'),
      (5, 'department',    null),
      (6, 'office',        'department'),
      (7, 'section',       'office'),
      (8, 'section',       'department')
    ) as t(ord, level_code, parent_code)
    order by ord
  loop
    insert into core.company_level_rule
      (company_id, tree, level_id, level_rank, parent_level_id, parent_level_rank)
    select v_company, l.tree, l.id, l.rank, p.id, p.rank
    from core.hierarchy_level l
    left join core.hierarchy_level p on p.code = r.parent_code
    where l.code = r.level_code;
  end loop;

  -- -------------------------------------------------------------
  -- 2. Org tree
  -- -------------------------------------------------------------
  o_retail := private.create_org_unit(v_company, v_bu,       null,     'Retail Banking',      null);
  o_pp     := private.create_org_unit(v_company, v_branch,   o_retail, 'Phnom Penh Branch',   'សាខាភ្នំពេញ');
  o_cs     := private.create_org_unit(v_company, v_division, o_pp,     'Customer Service',    null);
  o_sr     := private.create_org_unit(v_company, v_branch,   o_retail, 'Siem Reap Branch',    'សាខាសៀមរាប');
  o_ho     := private.create_org_unit(v_company, v_branch,   null,     'Head Office',         'ការិយាល័យកណ្តាល');
  o_ops    := private.create_org_unit(v_company, v_division, o_ho,     'Operations',          null);

  -- -------------------------------------------------------------
  -- 3. Position tree
  -- -------------------------------------------------------------
  p_it         := private.create_pos_unit(v_company, v_dept,    null,         'Information Technology', 'បច្ចេកវិទ្យាព័ត៌មាន');
  p_fin        := private.create_pos_unit(v_company, v_dept,    null,         'Finance',                'ហិរញ្ញវត្ថុ');
  p_hr         := private.create_pos_unit(v_company, v_dept,    null,         'Human Resources',        'ធនធានមនុស្ស');
  p_dev_office := private.create_pos_unit(v_company, v_office,  p_it,         'Software Development Office', null);
  p_backend    := private.create_pos_unit(v_company, v_section, p_dev_office, 'Backend Section',        null);
  p_acct       := private.create_pos_unit(v_company, v_section, p_fin,        'Accounting Section',     null);

  -- -------------------------------------------------------------
  -- 4. Department listings (which Departments each org unit may use)
  -- -------------------------------------------------------------
  insert into core.org_unit_department (company_id, org_unit_id, department_id)
  values
    (v_company, o_ho, p_it),
    (v_company, o_ho, p_fin),
    (v_company, o_ho, p_hr),
    (v_company, o_pp, p_fin),
    (v_company, o_pp, p_hr),
    (v_company, o_sr, p_hr);

  -- -------------------------------------------------------------
  -- 5. Job positions (each belongs to one Department)
  -- -------------------------------------------------------------
  insert into core.job_position (company_id, department_id, name_en, name_km)
  values (v_company, p_it, 'Software Engineer', null)
  returning id into j_swe;

  insert into core.job_position (company_id, department_id, name_en, name_km)
  values (v_company, p_it, 'System Administrator', null)
  returning id into j_sysadmin;

  insert into core.job_position (company_id, department_id, name_en, name_km)
  values (v_company, p_fin, 'Accountant', 'គណនេយ្យករ')
  returning id into j_acct;

  insert into core.job_position (company_id, department_id, name_en, name_km)
  values (v_company, p_fin, 'Finance Manager', null)
  returning id into j_finmgr;

  insert into core.job_position (company_id, department_id, name_en, name_km)
  values (v_company, p_hr, 'HR Officer', null)
  returning id into j_hro;

  -- -------------------------------------------------------------
  -- 6. One allocation, to test the duplicate warning in the form
  -- -------------------------------------------------------------
  perform private.create_allocation(v_company, o_ho, j_swe, p_backend, 5);

  raise notice 'Seed done for company %.', v_company;
end $$;

-- Check. Expected: rules 8, org_units 6, pos_units 6, listings 6, jobs 5, allocations 1
select
  (select count(*) from public.company_level_rules_current  where company_id = c.id) as rules,
  (select count(*) from public.org_units_current            where company_id = c.id) as org_units,
  (select count(*) from public.pos_units_current            where company_id = c.id) as pos_units,
  (select count(*) from public.org_unit_departments_current where company_id = c.id) as listings,
  (select count(*) from public.job_positions_current        where company_id = c.id) as jobs,
  (select count(*) from public.position_allocations_current where company_id = c.id) as allocations
from core.parent_company c
where c.name_en = 'Dev Parent Company';

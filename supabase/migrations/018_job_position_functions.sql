-- 018: job position write functions and wrappers (ORG Stage 9c-5)
--
-- Part A: private write functions (service_role only), the missing single write
--         path for job positions:
--   private.create_job_position(company, Department, name EN, name KM)
--   private.rename_job_position(company, job, name EN, name KM)
--   private.close_job_position(company, job, close date)
--
-- Part B: public wrappers, callable by logged-in users. Each one checks
--         permission pos.job.write with private.has_permission, passing the
--         job's Department, then calls the private function.
--   public.create_job_position(company, Department, name EN, name KM)
--   public.rename_job_position(company, job, name EN, name KM)
--   public.close_job_position(company, job, close date)
-- Needs 016 (private.is_company_member).
--
-- Rules kept by the private functions:
--   * the Department must be an open Department of the company
--   * the English name is required (spaces at both ends are removed) and must be
--     unique among the open jobs of the same Department
--   * rename replaces both names; an empty Khmer name clears it
--   * closing a job closes its open allocations (guard from 006). The close date
--     cannot be earlier than the start of the job or of those allocations
--
-- Errors:
--   no permission (or not a member of the company's tenant):
--       'You do not have permission to manage job positions here' (code 42501)
--   a member naming something that is not open in this company:
--       'Department % is not an open Department of this company'
--       'Job position % is not an open job position of this company'
--   'The English name is required'
--   'A job position named "%" already exists in this Department'
--   'Close date % is earlier than %, when this job or an allocation of it started'

-- ---------------------------------------------------------------
-- Part A: private functions
-- ---------------------------------------------------------------
create function private.create_job_position(
  p_company_id     integer,
  p_department_id  integer,
  p_name_en        text,
  p_name_km        text default null
)
returns integer
language plpgsql
set search_path = ''
as $$
declare
  v_name_en text := btrim(p_name_en);
  v_name_km text := nullif(btrim(p_name_km), '');
  v_id      integer;
begin
  if not exists (
    select 1
    from core.pos_unit u
    join core.hierarchy_level h on h.id = u.level_id
    where u.id = p_department_id
      and u.company_id = p_company_id
      and u.valid_to is null
      and h.code = 'department'
  ) then
    raise exception 'Department % is not an open Department of this company', p_department_id;
  end if;

  if v_name_en is null or v_name_en = '' then
    raise exception 'The English name is required';
  end if;

  if exists (
    select 1
    from core.job_position j
    where j.department_id = p_department_id
      and j.name_en = v_name_en
      and j.valid_to is null
  ) then
    raise exception 'A job position named "%" already exists in this Department', v_name_en;
  end if;

  insert into core.job_position (company_id, department_id, name_en, name_km)
  values (p_company_id, p_department_id, v_name_en, v_name_km)
  returning id into v_id;

  return v_id;
end;
$$;

create function private.rename_job_position(
  p_company_id  integer,
  p_job_id      integer,
  p_name_en     text,
  p_name_km     text default null
)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_name_en text := btrim(p_name_en);
  v_name_km text := nullif(btrim(p_name_km), '');
  v_dept    integer;
begin
  select department_id into v_dept
  from core.job_position
  where id = p_job_id
    and company_id = p_company_id
    and valid_to is null
  for update;

  if not found then
    raise exception 'Job position % is not an open job position of this company', p_job_id;
  end if;

  if v_name_en is null or v_name_en = '' then
    raise exception 'The English name is required';
  end if;

  if exists (
    select 1
    from core.job_position j
    where j.department_id = v_dept
      and j.name_en = v_name_en
      and j.valid_to is null
      and j.id <> p_job_id
  ) then
    raise exception 'A job position named "%" already exists in this Department', v_name_en;
  end if;

  update core.job_position
  set name_en = v_name_en,
      name_km = v_name_km
  where id = p_job_id;
end;
$$;

create function private.close_job_position(
  p_company_id  integer,
  p_job_id      integer,
  p_close_date  date default current_date
)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_from   date;
  v_latest date;
begin
  select valid_from into v_from
  from core.job_position
  where id = p_job_id
    and company_id = p_company_id
    and valid_to is null
  for update;

  if not found then
    raise exception 'Job position % is not an open job position of this company', p_job_id;
  end if;

  -- latest start among the job and the open allocations that close with it
  select greatest(v_from, max(a.valid_from)) into v_latest
  from core.position_allocation a
  where a.job_position_id = p_job_id
    and a.valid_to is null;

  if p_close_date < v_latest then
    raise exception 'Close date % is earlier than %, when this job or an allocation of it started',
      p_close_date, v_latest;
  end if;

  update core.job_position
  set valid_to = p_close_date
  where id = p_job_id;
end;
$$;

revoke execute on function
  private.create_job_position(integer, integer, text, text),
  private.rename_job_position(integer, integer, text, text),
  private.close_job_position(integer, integer, date)
from public, anon, authenticated;

grant execute on function
  private.create_job_position(integer, integer, text, text),
  private.rename_job_position(integer, integer, text, text),
  private.close_job_position(integer, integer, date)
to service_role;

-- ---------------------------------------------------------------
-- Part B: public wrappers
-- security definer: they read and write core as the function owner, and
-- decide access themselves with private.has_permission (the caller's login).
-- ---------------------------------------------------------------
create function public.create_job_position(
  p_company_id     integer,
  p_department_id  integer,
  p_name_en        text,
  p_name_km        text default null
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1
    from core.pos_unit u
    join core.hierarchy_level h on h.id = u.level_id
    where u.id = p_department_id
      and u.company_id = p_company_id
      and u.valid_to is null
      and h.code = 'department'
  ) then
    if private.is_company_member(p_company_id) then
      raise exception 'Department % is not an open Department of this company', p_department_id;
    end if;

    raise exception 'You do not have permission to manage job positions here'
      using errcode = '42501';
  end if;

  if not private.has_permission(p_company_id, 'pos.job.write', null, p_department_id) then
    raise exception 'You do not have permission to manage job positions here'
      using errcode = '42501';
  end if;

  return private.create_job_position(p_company_id, p_department_id, p_name_en, p_name_km);
end;
$$;

create function public.rename_job_position(
  p_company_id  integer,
  p_job_id      integer,
  p_name_en     text,
  p_name_km     text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_dept integer;
begin
  select j.department_id into v_dept
  from core.job_position j
  where j.id = p_job_id
    and j.company_id = p_company_id
    and j.valid_to is null;

  if not found then
    if private.is_company_member(p_company_id) then
      raise exception 'Job position % is not an open job position of this company', p_job_id;
    end if;

    raise exception 'You do not have permission to manage job positions here'
      using errcode = '42501';
  end if;

  if not private.has_permission(p_company_id, 'pos.job.write', null, v_dept) then
    raise exception 'You do not have permission to manage job positions here'
      using errcode = '42501';
  end if;

  perform private.rename_job_position(p_company_id, p_job_id, p_name_en, p_name_km);
end;
$$;

create function public.close_job_position(
  p_company_id  integer,
  p_job_id      integer,
  p_close_date  date default current_date
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_dept integer;
begin
  select j.department_id into v_dept
  from core.job_position j
  where j.id = p_job_id
    and j.company_id = p_company_id
    and j.valid_to is null;

  if not found then
    if private.is_company_member(p_company_id) then
      raise exception 'Job position % is not an open job position of this company', p_job_id;
    end if;

    raise exception 'You do not have permission to manage job positions here'
      using errcode = '42501';
  end if;

  if not private.has_permission(p_company_id, 'pos.job.write', null, v_dept) then
    raise exception 'You do not have permission to manage job positions here'
      using errcode = '42501';
  end if;

  perform private.close_job_position(p_company_id, p_job_id, p_close_date);
end;
$$;

-- ---------------------------------------------------------------
-- Privileges: logged-in users only (Supabase grants new public objects
-- to anon and authenticated by default, so revoke first)
-- ---------------------------------------------------------------
revoke execute on function
  public.create_job_position(integer, integer, text, text),
  public.rename_job_position(integer, integer, text, text),
  public.close_job_position(integer, integer, date)
from public, anon, authenticated;

grant execute on function
  public.create_job_position(integer, integer, text, text),
  public.rename_job_position(integer, integer, text, text),
  public.close_job_position(integer, integer, date)
to authenticated, service_role;

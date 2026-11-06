-- 021: permission check for the frontend (ORG Stage 9e)
--
-- Closes gap G8: the frontend could not tell what the logged-in user may do, so
-- it could not hide or disable buttons. This adds one read function.
--
--   public.check_permissions(company, permission code, targets)
--       Asks private.has_permission (013) the same question the write wrappers
--       ask, so the frontend and the database can never disagree.
--       targets is a JSON array of { "org_unit_id": n, "department_id": n } objects.
--       Either key can be missing or null. The default is one empty target,
--       which is the right question for company-level permissions
--       (for example org.config.write).
--       Returns one row per distinct target: org_unit_id, department_id, allowed.
--
-- Which key matters depends on the permission (see 012 and 013):
--   org.allocation.write      org_unit_id and department_id
--   org.unit.write            org_unit_id
--   org.eligibility.write     org_unit_id
--   pos.unit.write            department_id
--   pos.job.write             department_id
--   org.config.write          none (company or tenant level)
--
-- It only answers for the logged-in user's own assignments. A caller who is not a
-- member, or who is not logged in, gets allowed = false for everything. It does not
-- hide anything the user could not already read, and it does not replace the checks
-- inside the write wrappers (those still run on every write).
--
-- At most 500 targets per call (the frontend sends larger lists in chunks).
-- Granted to authenticated and service_role only.

create function public.check_permissions(
  p_company_id       integer,
  p_permission_code  text,
  p_targets          jsonb default '[{}]'::jsonb
)
returns table (
  org_unit_id    integer,
  department_id  integer,
  allowed        boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
begin
  if p_targets is null or jsonb_typeof(p_targets) <> 'array' then
    raise exception 'Targets must be a JSON array of {org_unit_id, department_id} objects';
  end if;

  if jsonb_array_length(p_targets) > 500 then
    raise exception 'At most 500 targets can be checked in one call';
  end if;

  return query
  select
    t.org_unit_id,
    t.department_id,
    private.has_permission(p_company_id, p_permission_code, t.org_unit_id, t.department_id)
  from (
    select distinct
      (e.value ->> 'org_unit_id')::integer   as org_unit_id,
      (e.value ->> 'department_id')::integer as department_id
    from jsonb_array_elements(p_targets) as e(value)
  ) t;
end;
$$;

-- ---------------------------------------------------------------
-- Privileges: logged-in users only (Supabase grants new public objects
-- to anon and authenticated by default, so revoke first)
-- ---------------------------------------------------------------
revoke execute on function public.check_permissions(integer, text, jsonb)
  from public, anon, authenticated;

grant execute on function public.check_permissions(integer, text, jsonb)
  to authenticated, service_role;

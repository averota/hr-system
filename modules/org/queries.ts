// modules/org/queries.ts
// Browser-side wrappers for the ORG cascade functions in `public`.
// Each one returns narrowed rows and throws an Error when Supabase returns one.
import { createClient } from "@/lib/supabase/client";
import type { JobOption, UnitOption } from "@/modules/org/types";

interface OptionRow {
  unit_id: number;
  level_id: number;
  level_code: string;
  name_en: string;
  name_km: string | null;
}

function toUnitOptions(rows: OptionRow[] | null): UnitOption[] {
  return (rows ?? []).map((r) => ({
    unit_id: r.unit_id,
    level_id: r.level_id,
    level_code: r.level_code,
    name_en: r.name_en,
    name_km: r.name_km ?? null,
  }));
}

/** Direct children of an org unit. parentUnitId null = directly under the company. */
export async function fetchOrgOptions(
  companyId: number,
  parentUnitId: number | null
): Promise<UnitOption[]> {
  const { data, error } = await createClient().rpc("org_options", {
    p_company_id: companyId,
    p_parent_unit_id: parentUnitId ?? undefined,
  });
  if (error) throw new Error(error.message);
  return toUnitOptions(data);
}

/** Offices, Sections or Groups directly under a position unit. */
export async function fetchPosOptions(
  companyId: number,
  parentUnitId: number
): Promise<UnitOption[]> {
  const { data, error } = await createClient().rpc("pos_options", {
    p_company_id: companyId,
    p_parent_unit_id: parentUnitId,
  });
  if (error) throw new Error(error.message);
  return toUnitOptions(data);
}

/** Departments listed for an org unit (not inherited from its parent). */
export async function fetchEligibleDepartments(
  companyId: number,
  orgUnitId: number
): Promise<UnitOption[]> {
  const { data, error } = await createClient().rpc("eligible_departments", {
    p_company_id: companyId,
    p_org_unit_id: orgUnitId,
  });
  if (error) throw new Error(error.message);
  return toUnitOptions(data);
}

/**
 * Looks for an open allocation with the same org unit, position unit and job.
 * The database allows at most one (unique index position_allocation_open_uq).
 * Returns null when none exists.
 */
export async function fetchExistingAllocation(
  companyId: number,
  orgUnitId: number,
  posUnitId: number,
  jobPositionId: number
): Promise<{ allocation_id: number; approved_headcount: number } | null> {
  const { data, error } = await createClient()
    .from("position_allocations_current")
    .select("allocation_id, approved_headcount")
    .eq("company_id", companyId)
    .eq("org_unit_id", orgUnitId)
    .eq("pos_unit_id", posUnitId)
    .eq("job_position_id", jobPositionId)
    .maybeSingle();
  if (error) throw new Error(error.message);
  if (!data || data.allocation_id === null) return null;
  return {
    allocation_id: data.allocation_id,
    approved_headcount: data.approved_headcount ?? 0,
  };
}

/** Open jobs of a Department, only if the org unit lists that Department. */
export async function fetchEligibleJobs(
  companyId: number,
  orgUnitId: number,
  departmentId: number
): Promise<JobOption[]> {
  const { data, error } = await createClient().rpc("eligible_jobs", {
    p_company_id: companyId,
    p_org_unit_id: orgUnitId,
    p_department_id: departmentId,
  });
  if (error) throw new Error(error.message);
  return (data ?? []).map((r) => ({
    job_position_id: r.job_position_id,
    name_en: r.name_en,
    name_km: r.name_km ?? null,
  }));
}

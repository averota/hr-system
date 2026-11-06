// modules/org/queries.ts
// Browser-side wrappers for the ORG functions in `public`.
// Read functions return narrowed rows. Write functions return nothing.
// Each one throws an Error when Supabase returns one.
import { createClient } from "@/lib/supabase/client";
import type { JobOption, TreeKind, UnitOption } from "@/modules/org/types";

// Largest value the database integer column accepts.
export const MAX_HEADCOUNT = 2147483647;

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

/**
 * Turns a database error from a write function into a readable Error.
 * Permission errors (42501) and rule errors already carry a readable message,
 * so they pass through unchanged. Only raw constraint errors are replaced.
 */
function writeError(error: { code?: string; message: string }): Error {
  switch (error.code) {
    case "23505":
      return new Error(
        "An open allocation already exists for this combination. Refresh the page and change its headcount instead."
      );
    case "23514":
      return new Error("Approved headcount must be a whole number of 0 or more.");
    case "23503":
      return new Error(
        "This combination is not valid any more. Refresh the page and try again."
      );
    default:
      return new Error(error.message);
  }
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

// ---------------------------------------------------------------
// Writes (public wrappers from migrations 015). Dates are "YYYY-MM-DD".
// ---------------------------------------------------------------

export interface CreateAllocationInput {
  companyId: number;
  orgUnitId: number;
  jobPositionId: number;
  posUnitId: number;
  headcount: number;
  startDate: string;
}

/** Creates an allocation. Needs org.allocation.write at the org unit and the job's Department. */
export async function createAllocation(input: CreateAllocationInput): Promise<void> {
  const { error } = await createClient().rpc("create_allocation", {
    p_company_id: input.companyId,
    p_org_unit_id: input.orgUnitId,
    p_job_position_id: input.jobPositionId,
    p_pos_unit_id: input.posUnitId,
    p_headcount: input.headcount,
    p_start_date: input.startDate,
  });
  if (error) throw writeError(error);
}

/** Closes the allocation and creates its replacement on the same date, in one transaction. */
export async function changeAllocationHeadcount(
  companyId: number,
  allocationId: number,
  newHeadcount: number,
  effectiveDate: string
): Promise<void> {
  const { error } = await createClient().rpc("change_allocation_headcount", {
    p_company_id: companyId,
    p_allocation_id: allocationId,
    p_new_headcount: newHeadcount,
    p_effective_date: effectiveDate,
  });
  if (error) throw writeError(error);
}

/** Closes one allocation. Nothing else is touched. */
export async function closeAllocation(
  companyId: number,
  allocationId: number,
  closeDate: string
): Promise<void> {
  const { error } = await createClient().rpc("close_allocation", {
    p_company_id: companyId,
    p_allocation_id: allocationId,
    p_close_date: closeDate,
  });
  if (error) throw writeError(error);
}
// ---------------------------------------------------------------
// Unit writes (public wrappers from migrations 016, 017 and 022).
// The same functions serve both trees: pass "org" or "pos". Dates are "YYYY-MM-DD".
// A new unit starts today by the server's date (no date parameter).
// ---------------------------------------------------------------

/**
 * Readable Error for a unit write. Permission errors (42501) and rule errors already
 * carry a readable message, so they pass through. Only raw constraint errors are replaced.
 */
function unitWriteError(error: { code?: string; message: string }): Error {
  switch (error.code) {
    case "23505":
    case "23503":
    case "23514":
      return new Error("This change is not valid any more. Refresh the page and try again.");
    default:
      return new Error(error.message);
  }
}

export interface CreateUnitInput {
  companyId: number;
  levelId: number;
  /** null = directly under the company (org tree) or a new Department (position tree). */
  parentUnitId: number | null;
  nameEn: string;
  nameKm: string;
}

/** Creates a unit. Needs org.unit.write (org) or pos.unit.write (pos) at the parent. */
export async function createUnit(tree: TreeKind, input: CreateUnitInput): Promise<void> {
  const supabase = createClient();
  const args = {
    p_company_id: input.companyId,
    p_level_id: input.levelId,
    // The generated type says number, but the function accepts null (see the reference, section 10).
    p_parent_unit_id: input.parentUnitId as number,
    p_name_en: input.nameEn.trim(),
    p_name_km: input.nameKm.trim() || undefined,
  };
  const { error } =
    tree === "org"
      ? await supabase.rpc("create_org_unit", args)
      : await supabase.rpc("create_pos_unit", args);
  if (error) throw unitWriteError(error);
}

/** Replaces both names of an open unit. An empty Khmer name clears it. */
export async function renameUnit(
  tree: TreeKind,
  companyId: number,
  unitId: number,
  nameEn: string,
  nameKm: string
): Promise<void> {
  const supabase = createClient();
  const args = {
    p_company_id: companyId,
    p_unit_id: unitId,
    p_name_en: nameEn.trim(),
    p_name_km: nameKm.trim() || undefined,
  };
  const { error } =
    tree === "org"
      ? await supabase.rpc("rename_org_unit", args)
      : await supabase.rpc("rename_pos_unit", args);
  if (error) throw unitWriteError(error);
}

/** Closes a unit. The database refuses it while open units are still under it. */
export async function closeUnit(
  tree: TreeKind,
  companyId: number,
  unitId: number,
  closeDate: string
): Promise<void> {
  const supabase = createClient();
  const args = { p_company_id: companyId, p_unit_id: unitId, p_close_date: closeDate };
  const { error } =
    tree === "org"
      ? await supabase.rpc("close_org_unit", args)
      : await supabase.rpc("close_pos_unit", args);
  if (error) throw unitWriteError(error);
}

/** Moves a unit with its whole subtree. newParentId null = to the root. */
export async function reorgUnit(
  tree: TreeKind,
  companyId: number,
  unitId: number,
  newParentId: number | null,
  effectiveDate: string
): Promise<void> {
  const supabase = createClient();
  const args = {
    p_company_id: companyId,
    p_unit_id: unitId,
    // The generated type says number, but the function accepts null.
    p_new_parent_id: newParentId as number,
    p_effective_date: effectiveDate,
  };
  const { error } =
    tree === "org"
      ? await supabase.rpc("reorg_org_unit", args)
      : await supabase.rpc("reorg_pos_unit", args);
  if (error) throw unitWriteError(error);
}
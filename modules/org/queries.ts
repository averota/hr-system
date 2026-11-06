// modules/org/queries.ts
// Browser-side wrappers for the ORG functions in `public`.
// Read functions return narrowed rows. Write functions return nothing.
// Each one throws an Error when Supabase returns one.
import { createClient } from "@/lib/supabase/client";
import type {
  ClosedAllocationRow,
  ClosedJobRow,
  ClosedListingRow,
  ClosedRuleRow,
  ClosedUnitRow,
  JobOption,
  JobRow,
  ListingRow,
  TreeKind,
  UnitOption,
} from "@/modules/org/types";

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
 * Readable Error for a write (units, jobs, Department listings). Permission errors (42501) and rule errors already
 * carry a readable message, so they pass through. Only raw constraint errors are replaced.
 */
function rpcWriteError(error: { code?: string; message: string }): Error {
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
  if (error) throw rpcWriteError(error);
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
  if (error) throw rpcWriteError(error);
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
  if (error) throw rpcWriteError(error);
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
  if (error) throw rpcWriteError(error);
}

// ---------------------------------------------------------------
// Jobs and Department listings (public wrappers from migrations 018 and 019).
// Dates are "YYYY-MM-DD". A new job starts today by the server's date.
// ---------------------------------------------------------------

/** Open job positions of a company, all Departments. */
export async function fetchJobs(companyId: number): Promise<JobRow[]> {
  const { data, error } = await createClient()
    .from("job_positions_current")
    .select("*")
    .eq("company_id", companyId)
    .order("name_en");
  if (error) throw new Error(error.message);

  const rows: JobRow[] = [];
  for (const r of data ?? []) {
    if (
      r.job_position_id === null ||
      r.company_id === null ||
      r.department_id === null ||
      r.name_en === null ||
      r.valid_from === null
    ) {
      continue;
    }
    rows.push({
      job_position_id: r.job_position_id,
      company_id: r.company_id,
      department_id: r.department_id,
      name_en: r.name_en,
      name_km: r.name_km,
      valid_from: r.valid_from,
    });
  }
  return rows;
}

/** Open Department listings of a company, all org units. */
export async function fetchListings(companyId: number): Promise<ListingRow[]> {
  const { data, error } = await createClient()
    .from("org_unit_departments_current")
    .select("*")
    .eq("company_id", companyId);
  if (error) throw new Error(error.message);

  const rows: ListingRow[] = [];
  for (const r of data ?? []) {
    if (
      r.eligibility_id === null ||
      r.company_id === null ||
      r.org_unit_id === null ||
      r.department_id === null ||
      r.valid_from === null
    ) {
      continue;
    }
    rows.push({
      eligibility_id: r.eligibility_id,
      company_id: r.company_id,
      org_unit_id: r.org_unit_id,
      department_id: r.department_id,
      valid_from: r.valid_from,
    });
  }
  return rows;
}

/** Creates a job position in a Department. Needs pos.job.write at the Department. */
export async function createJob(
  companyId: number,
  departmentId: number,
  nameEn: string,
  nameKm: string
): Promise<void> {
  const { error } = await createClient().rpc("create_job_position", {
    p_company_id: companyId,
    p_department_id: departmentId,
    p_name_en: nameEn.trim(),
    p_name_km: nameKm.trim() || undefined,
  });
  if (error) throw rpcWriteError(error);
}

/** Replaces both names of a job. An empty Khmer name clears it. */
export async function renameJob(
  companyId: number,
  jobId: number,
  nameEn: string,
  nameKm: string
): Promise<void> {
  const { error } = await createClient().rpc("rename_job_position", {
    p_company_id: companyId,
    p_job_id: jobId,
    p_name_en: nameEn.trim(),
    p_name_km: nameKm.trim() || undefined,
  });
  if (error) throw rpcWriteError(error);
}

/** Closes a job. Its open allocations are closed with it. */
export async function closeJob(
  companyId: number,
  jobId: number,
  closeDate: string
): Promise<void> {
  const { error } = await createClient().rpc("close_job_position", {
    p_company_id: companyId,
    p_job_id: jobId,
    p_close_date: closeDate,
  });
  if (error) throw rpcWriteError(error);
}

/** Lists a Department for an org unit. Needs org.eligibility.write at the org unit. */
export async function addListing(
  companyId: number,
  orgUnitId: number,
  departmentId: number,
  startDate: string
): Promise<void> {
  const { error } = await createClient().rpc("add_department_listing", {
    p_company_id: companyId,
    p_org_unit_id: orgUnitId,
    p_department_id: departmentId,
    p_start_date: startDate,
  });
  if (error) throw rpcWriteError(error);
}

/** Removes a listing. The database refuses it while open allocations use it. */
export async function removeListing(
  companyId: number,
  orgUnitId: number,
  departmentId: number,
  closeDate: string
): Promise<void> {
  const { error } = await createClient().rpc("remove_department_listing", {
    p_company_id: companyId,
    p_org_unit_id: orgUnitId,
    p_department_id: departmentId,
    p_close_date: closeDate,
  });
  if (error) throw rpcWriteError(error);
}

// ---------------------------------------------------------------
// Hierarchy level rules (public wrappers from migration 020).
// Needs org.config.write at company or tenant level. Dates are "YYYY-MM-DD".
// ---------------------------------------------------------------

/**
 * Enables a level for a company under one parent level. parentLevelId null = directly
 * under the root. The rule starts today by the server's date. A level can have several rules.
 */
export async function enableLevelRule(
  companyId: number,
  levelId: number,
  parentLevelId: number | null
): Promise<void> {
  const { error } = await createClient().rpc("enable_level_rule", {
    p_company_id: companyId,
    p_level_id: levelId,
    p_parent_level_id: parentLevelId ?? undefined,
  });
  if (error) throw rpcWriteError(error);
}

/**
 * Closes one rule. The database refuses it while the level is required, used as a parent
 * by other rules, or has open units. Existing units are never rearranged.
 */
export async function disableLevelRule(
  companyId: number,
  ruleId: number,
  closeDate: string
): Promise<void> {
  const { error } = await createClient().rpc("disable_level_rule", {
    p_company_id: companyId,
    p_rule_id: ruleId,
    p_close_date: closeDate,
  });
  if (error) throw rpcWriteError(error);
}

// ---------------------------------------------------------------
// History (closed records), read from the *_closed views.
// Newest closed first. Rows with an empty key column are skipped.
// Supabase returns at most 1000 rows per request (not paged yet).
// ---------------------------------------------------------------

/** Closed level rules of a company, both trees. */
export async function fetchClosedRules(companyId: number): Promise<ClosedRuleRow[]> {
  const { data, error } = await createClient()
    .from("company_level_rules_closed")
    .select("*")
    .eq("company_id", companyId)
    .order("valid_to", { ascending: false })
    .order("rule_id", { ascending: false });
  if (error) throw new Error(error.message);

  const rows: ClosedRuleRow[] = [];
  for (const r of data ?? []) {
    if (
      r.rule_id === null ||
      r.company_id === null ||
      (r.tree !== "org" && r.tree !== "pos") ||
      r.level_id === null ||
      r.level_rank === null ||
      r.level_name_en === null ||
      r.valid_from === null ||
      r.valid_to === null
    ) {
      continue;
    }
    rows.push({
      rule_id: r.rule_id,
      company_id: r.company_id,
      tree: r.tree,
      level_id: r.level_id,
      level_rank: r.level_rank,
      level_name_en: r.level_name_en,
      level_name_km: r.level_name_km,
      parent_level_id: r.parent_level_id,
      parent_level_name_en: r.parent_level_name_en,
      parent_level_name_km: r.parent_level_name_km,
      valid_from: r.valid_from,
      valid_to: r.valid_to,
    });
  }
  return rows;
}

interface ClosedUnitRaw {
  unit_id: number | null;
  company_id: number | null;
  level_id: number | null;
  level_rank: number | null;
  level_name_en: string | null;
  level_name_km: string | null;
  name_en: string | null;
  name_km: string | null;
  parent_unit_id: number | null;
  parent_name_en: string | null;
  parent_name_km: string | null;
  valid_from: string | null;
  valid_to: string | null;
}

/** Closed units of one tree, with the parent each had when it closed. */
export async function fetchClosedUnits(
  tree: TreeKind,
  companyId: number
): Promise<ClosedUnitRow[]> {
  const supabase = createClient();
  const { data, error } =
    tree === "org"
      ? await supabase
          .from("org_units_closed")
          .select("*")
          .eq("company_id", companyId)
          .order("valid_to", { ascending: false })
          .order("unit_id", { ascending: false })
      : await supabase
          .from("pos_units_closed")
          .select("*")
          .eq("company_id", companyId)
          .order("valid_to", { ascending: false })
          .order("unit_id", { ascending: false });
  if (error) throw new Error(error.message);

  const rows: ClosedUnitRow[] = [];
  for (const r of (data ?? []) as ClosedUnitRaw[]) {
    if (
      r.unit_id === null ||
      r.company_id === null ||
      r.level_id === null ||
      r.level_rank === null ||
      r.level_name_en === null ||
      r.name_en === null ||
      r.valid_from === null ||
      r.valid_to === null
    ) {
      continue;
    }
    rows.push({
      unit_id: r.unit_id,
      company_id: r.company_id,
      level_id: r.level_id,
      level_rank: r.level_rank,
      level_name_en: r.level_name_en,
      level_name_km: r.level_name_km,
      name_en: r.name_en,
      name_km: r.name_km,
      parent_unit_id: r.parent_unit_id,
      parent_name_en: r.parent_name_en,
      parent_name_km: r.parent_name_km,
      valid_from: r.valid_from,
      valid_to: r.valid_to,
    });
  }
  return rows;
}

/** Closed allocations of a company (headcount history). */
export async function fetchClosedAllocations(
  companyId: number
): Promise<ClosedAllocationRow[]> {
  const { data, error } = await createClient()
    .from("position_allocations_closed")
    .select("*")
    .eq("company_id", companyId)
    .order("valid_to", { ascending: false })
    .order("allocation_id", { ascending: false });
  if (error) throw new Error(error.message);

  const rows: ClosedAllocationRow[] = [];
  for (const r of data ?? []) {
    if (
      r.allocation_id === null ||
      r.company_id === null ||
      r.org_unit_id === null ||
      r.org_unit_name_en === null ||
      r.department_id === null ||
      r.department_name_en === null ||
      r.job_position_id === null ||
      r.job_name_en === null ||
      r.pos_unit_id === null ||
      r.pos_unit_name_en === null ||
      r.pos_level_code === null ||
      r.approved_headcount === null ||
      r.valid_from === null ||
      r.valid_to === null
    ) {
      continue;
    }
    rows.push({
      allocation_id: r.allocation_id,
      company_id: r.company_id,
      org_unit_id: r.org_unit_id,
      org_unit_name_en: r.org_unit_name_en,
      org_unit_name_km: r.org_unit_name_km,
      department_id: r.department_id,
      department_name_en: r.department_name_en,
      department_name_km: r.department_name_km,
      job_position_id: r.job_position_id,
      job_name_en: r.job_name_en,
      job_name_km: r.job_name_km,
      pos_unit_id: r.pos_unit_id,
      pos_unit_name_en: r.pos_unit_name_en,
      pos_unit_name_km: r.pos_unit_name_km,
      pos_level_code: r.pos_level_code,
      approved_headcount: r.approved_headcount,
      valid_from: r.valid_from,
      valid_to: r.valid_to,
    });
  }
  return rows;
}

/** Closed job positions of a company. */
export async function fetchClosedJobs(companyId: number): Promise<ClosedJobRow[]> {
  const { data, error } = await createClient()
    .from("job_positions_closed")
    .select("*")
    .eq("company_id", companyId)
    .order("valid_to", { ascending: false })
    .order("job_position_id", { ascending: false });
  if (error) throw new Error(error.message);

  const rows: ClosedJobRow[] = [];
  for (const r of data ?? []) {
    if (
      r.job_position_id === null ||
      r.company_id === null ||
      r.department_id === null ||
      r.department_name_en === null ||
      r.name_en === null ||
      r.valid_from === null ||
      r.valid_to === null
    ) {
      continue;
    }
    rows.push({
      job_position_id: r.job_position_id,
      company_id: r.company_id,
      department_id: r.department_id,
      department_name_en: r.department_name_en,
      department_name_km: r.department_name_km,
      name_en: r.name_en,
      name_km: r.name_km,
      valid_from: r.valid_from,
      valid_to: r.valid_to,
    });
  }
  return rows;
}

/** Closed Department listings of a company. */
export async function fetchClosedListings(companyId: number): Promise<ClosedListingRow[]> {
  const { data, error } = await createClient()
    .from("org_unit_departments_closed")
    .select("*")
    .eq("company_id", companyId)
    .order("valid_to", { ascending: false })
    .order("eligibility_id", { ascending: false });
  if (error) throw new Error(error.message);

  const rows: ClosedListingRow[] = [];
  for (const r of data ?? []) {
    if (
      r.eligibility_id === null ||
      r.company_id === null ||
      r.org_unit_id === null ||
      r.org_unit_name_en === null ||
      r.department_id === null ||
      r.department_name_en === null ||
      r.valid_from === null ||
      r.valid_to === null
    ) {
      continue;
    }
    rows.push({
      eligibility_id: r.eligibility_id,
      company_id: r.company_id,
      org_unit_id: r.org_unit_id,
      org_unit_name_en: r.org_unit_name_en,
      org_unit_name_km: r.org_unit_name_km,
      department_id: r.department_id,
      department_name_en: r.department_name_en,
      department_name_km: r.department_name_km,
      valid_from: r.valid_from,
      valid_to: r.valid_to,
    });
  }
  return rows;
}
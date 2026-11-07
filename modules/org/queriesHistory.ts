// modules/org/queriesHistory.ts
// Browser-side reads for ORG Stage 9k (as-of date reads and reorg history, migration 028).
// Each function throws an Error when Supabase returns one.
// Not paged: Supabase returns at most 1000 rows per request.
import { createClient } from "@/lib/supabase/client";
import type {
  AsOfAllocationRow,
  AsOfListingRow,
  TreeKind,
  UnitMoveRow,
  UnitRow,
} from "@/modules/org/types";
import { isRowLimitReached } from "@/modules/org/limits";
import type { LimitedRows } from "@/modules/org/queries";

/**
 * Units of one tree as they stood on a date ("YYYY-MM-DD").
 * valid_to is the last valid day (inclusive). Names are the current names.
 */
export async function fetchUnitsAsOf(
  tree: TreeKind,
  companyId: number,
  asOf: string
): Promise<LimitedRows<UnitRow>> {
  const supabase = createClient();
  const args = { p_company_id: companyId, p_as_of: asOf };
  const { data, error } =
    tree === "org"
      ? await supabase.rpc("org_units_as_of", args)
      : await supabase.rpc("pos_units_as_of", args);
  if (error) throw new Error(error.message);

  const rows = (data ?? []).map((r) => ({
    unit_id: r.unit_id,
    company_id: companyId,
    level_id: r.level_id,
    level_code: r.level_code,
    level_rank: r.level_rank,
    level_name_en: r.level_name_en,
    level_name_km: r.level_name_km ?? null,
    name_en: r.name_en,
    name_km: r.name_km ?? null,
    // The generated type says number, but a top-level unit has no parent.
    parent_unit_id: r.parent_unit_id as number | null,
    valid_from: r.valid_from,
  }));
  return { rows, limitReached: isRowLimitReached((data ?? []).length) };
}

/** Allocations (approved headcount) as they stood on a date. */
export async function fetchAllocationsAsOf(
  companyId: number,
  asOf: string
): Promise<LimitedRows<AsOfAllocationRow>> {
  const { data, error } = await createClient().rpc("position_allocations_as_of", {
    p_company_id: companyId,
    p_as_of: asOf,
  });
  if (error) throw new Error(error.message);

  const rows = (data ?? []).map((r) => ({
    allocation_id: r.allocation_id,
    company_id: r.company_id,
    org_unit_id: r.org_unit_id,
    org_unit_name_en: r.org_unit_name_en,
    org_unit_name_km: r.org_unit_name_km ?? null,
    department_id: r.department_id,
    department_name_en: r.department_name_en,
    department_name_km: r.department_name_km ?? null,
    job_position_id: r.job_position_id,
    job_name_en: r.job_name_en,
    job_name_km: r.job_name_km ?? null,
    pos_unit_id: r.pos_unit_id,
    pos_unit_name_en: r.pos_unit_name_en,
    pos_unit_name_km: r.pos_unit_name_km ?? null,
    pos_level_code: r.pos_level_code,
    approved_headcount: r.approved_headcount,
    valid_from: r.valid_from,
    // The generated type says string, but an open allocation has no end date.
    valid_to: r.valid_to as string | null,
  }));
  return { rows, limitReached: isRowLimitReached((data ?? []).length) };
}

/** Department listings as they stood on a date. */
export async function fetchListingsAsOf(
  companyId: number,
  asOf: string
): Promise<LimitedRows<AsOfListingRow>> {
  const { data, error } = await createClient().rpc("org_unit_departments_as_of", {
    p_company_id: companyId,
    p_as_of: asOf,
  });
  if (error) throw new Error(error.message);

  const rows = (data ?? []).map((r) => ({
    eligibility_id: r.eligibility_id,
    company_id: r.company_id,
    org_unit_id: r.org_unit_id,
    department_id: r.department_id,
    valid_from: r.valid_from,
    valid_to: r.valid_to as string | null,
  }));
  return { rows, limitReached: isRowLimitReached((data ?? []).length) };
}

interface UnitMoveRaw {
  link_id: number | null;
  company_id: number | null;
  unit_id: number | null;
  name_en: string | null;
  name_km: string | null;
  level_id: number | null;
  level_rank: number | null;
  level_name_en: string | null;
  level_name_km: string | null;
  parent_unit_id: number | null;
  parent_name_en: string | null;
  parent_name_km: string | null;
  valid_from: string | null;
  valid_to: string | null;
  unit_valid_to: string | null;
}

/**
 * Past parent links of units that were moved (reorg), newest move first.
 * A link counts as a move when the unit is still open, or when the link ended
 * before the unit closed. A unit that was moved and closed on the same day is
 * the one case this cannot tell apart from a plain close.
 */
export async function fetchUnitMoves(
  tree: TreeKind,
  companyId: number
): Promise<LimitedRows<UnitMoveRow>> {
  const supabase = createClient();
  const { data, error } =
    tree === "org"
      ? await supabase
          .from("org_unit_parent_links_closed")
          .select("*")
          .eq("company_id", companyId)
          .order("valid_to", { ascending: false })
          .order("link_id", { ascending: false })
      : await supabase
          .from("pos_unit_parent_links_closed")
          .select("*")
          .eq("company_id", companyId)
          .order("valid_to", { ascending: false })
          .order("link_id", { ascending: false });
  if (error) throw new Error(error.message);

  const rows: UnitMoveRow[] = [];
  for (const r of (data ?? []) as UnitMoveRaw[]) {
    if (
      r.link_id === null ||
      r.company_id === null ||
      r.unit_id === null ||
      r.name_en === null ||
      r.level_id === null ||
      r.level_rank === null ||
      r.level_name_en === null ||
      r.valid_from === null ||
      r.valid_to === null
    ) {
      continue;
    }
    const isMove = r.unit_valid_to === null || r.valid_to < r.unit_valid_to;
    if (!isMove) continue;

    rows.push({
      link_id: r.link_id,
      company_id: r.company_id,
      unit_id: r.unit_id,
      name_en: r.name_en,
      name_km: r.name_km,
      level_id: r.level_id,
      level_rank: r.level_rank,
      level_name_en: r.level_name_en,
      level_name_km: r.level_name_km,
      parent_unit_id: r.parent_unit_id,
      parent_name_en: r.parent_name_en,
      parent_name_km: r.parent_name_km,
      valid_from: r.valid_from,
      valid_to: r.valid_to,
    });
  }
  return { rows, limitReached: isRowLimitReached((data ?? []).length) };
}
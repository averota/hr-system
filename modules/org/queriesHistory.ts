// modules/org/queriesHistory.ts
// Browser-side reads for ORG Stage 9k (as-of date reads, migration 028).
// Each function throws an Error when Supabase returns one.
import { createClient } from "@/lib/supabase/client";
import type { TreeKind, UnitRow } from "@/modules/org/types";

/**
 * Units of one tree as they stood on a date ("YYYY-MM-DD").
 * valid_to is the last valid day (inclusive). Names are the current names.
 * Not paged (Supabase returns at most 1000 rows per request).
 */
export async function fetchUnitsAsOf(
  tree: TreeKind,
  companyId: number,
  asOf: string
): Promise<UnitRow[]> {
  const supabase = createClient();
  const args = { p_company_id: companyId, p_as_of: asOf };
  const { data, error } =
    tree === "org"
      ? await supabase.rpc("org_units_as_of", args)
      : await supabase.rpc("pos_units_as_of", args);
  if (error) throw new Error(error.message);

  return (data ?? []).map((r) => ({
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
}
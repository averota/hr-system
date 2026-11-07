// modules/org/serverQueries.ts
// Server-side loaders for the first data OrgConfigView needs.
// (queries.ts is browser-only, so it can't be used from a Server Component.)
// Rows with an empty key column are skipped, same as in queries.ts.
import { createClient } from "@/lib/supabase/server";
import type { Database } from "@/lib/supabase/database.types";
import { isRowLimitReached } from "@/modules/org/limits";
import type {
  CompanyLevelRule,
  HierarchyLevel,
  ParentCompany,
  PositionAllocation,
  TreeKind,
  UnitRow,
} from "@/modules/org/types";

type Views = Database["public"]["Views"];

export interface OrgPageData {
  companies: ParentCompany[];
  levels: HierarchyLevel[];
  rules: CompanyLevelRule[];
  orgUnits: UnitRow[];
  posUnits: UnitRow[];
  allocations: PositionAllocation[];
  /** True when the allocations request returned the maximum number of rows (may be cut off). */
  allocationsLimitReached: boolean;
}

function toTree(value: string | null): TreeKind | null {
  return value === "org" || value === "pos" ? value : null;
}

// org_units_current and pos_units_current have the same columns.
function toUnitRows(data: Views["org_units_current"]["Row"][] | null): UnitRow[] {
  const rows: UnitRow[] = [];
  for (const r of data ?? []) {
    if (
      r.unit_id === null ||
      r.company_id === null ||
      r.level_id === null ||
      r.level_code === null ||
      r.level_rank === null ||
      r.level_name_en === null ||
      r.name_en === null ||
      r.valid_from === null
    ) {
      continue;
    }
    rows.push({
      unit_id: r.unit_id,
      company_id: r.company_id,
      level_id: r.level_id,
      level_code: r.level_code,
      level_rank: r.level_rank,
      level_name_en: r.level_name_en,
      level_name_km: r.level_name_km,
      name_en: r.name_en,
      name_km: r.name_km,
      parent_unit_id: r.parent_unit_id,
      valid_from: r.valid_from,
    });
  }
  return rows;
}

/** Loads everything the Organization page needs, in parallel. Throws on any database error. */
export async function loadOrgPageData(): Promise<OrgPageData> {
  const supabase = await createClient();

  const [companiesRes, levelsRes, rulesRes, orgRes, posRes, allocRes] = await Promise.all([
    supabase.from("parent_companies").select("*").order("name_en"),
    supabase.from("hierarchy_levels").select("*").order("rank"),
    supabase.from("company_level_rules_current").select("*").order("rule_id"),
    supabase.from("org_units_current").select("*").order("unit_id"),
    supabase.from("pos_units_current").select("*").order("unit_id"),
    supabase.from("position_allocations_current").select("*").order("allocation_id"),
  ]);

  for (const res of [companiesRes, levelsRes, rulesRes, orgRes, posRes, allocRes]) {
    if (res.error) throw new Error(res.error.message);
  }

  const companies: ParentCompany[] = [];
  for (const r of companiesRes.data ?? []) {
    if (
      r.company_id === null ||
      r.tenant_id === null ||
      r.name_en === null ||
      r.is_active === null
    ) {
      continue;
    }
    companies.push({
      company_id: r.company_id,
      tenant_id: r.tenant_id,
      name_en: r.name_en,
      name_km: r.name_km,
      is_active: r.is_active,
    });
  }

  const levels: HierarchyLevel[] = [];
  for (const r of levelsRes.data ?? []) {
    const tree = toTree(r.tree);
    if (
      r.level_id === null ||
      tree === null ||
      r.code === null ||
      r.rank === null ||
      r.name_en === null ||
      r.can_be_root === null ||
      r.is_required === null
    ) {
      continue;
    }
    levels.push({
      level_id: r.level_id,
      tree,
      code: r.code,
      rank: r.rank,
      name_en: r.name_en,
      name_km: r.name_km,
      can_be_root: r.can_be_root,
      is_required: r.is_required,
    });
  }

  const rules: CompanyLevelRule[] = [];
  for (const r of rulesRes.data ?? []) {
    const tree = toTree(r.tree);
    if (
      r.rule_id === null ||
      r.company_id === null ||
      tree === null ||
      r.level_id === null ||
      r.level_code === null ||
      r.level_rank === null ||
      r.level_name_en === null ||
      r.valid_from === null
    ) {
      continue;
    }
    rules.push({
      rule_id: r.rule_id,
      company_id: r.company_id,
      tree,
      level_id: r.level_id,
      level_code: r.level_code,
      level_rank: r.level_rank,
      level_name_en: r.level_name_en,
      level_name_km: r.level_name_km,
      parent_level_id: r.parent_level_id,
      parent_level_code: r.parent_level_code,
      parent_level_name_en: r.parent_level_name_en,
      parent_level_name_km: r.parent_level_name_km,
      valid_from: r.valid_from,
    });
  }

  const allocations: PositionAllocation[] = [];
  for (const r of allocRes.data ?? []) {
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
      r.valid_from === null
    ) {
      continue;
    }
    allocations.push({
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
    });
  }

  return {
    companies,
    levels,
    rules,
    orgUnits: toUnitRows(orgRes.data),
    posUnits: toUnitRows(posRes.data),
    allocations,
    allocationsLimitReached: isRowLimitReached((allocRes.data ?? []).length),
  };
}
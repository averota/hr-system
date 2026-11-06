// app/page.tsx
import { Suspense } from "react";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import type { Tables } from "@/lib/supabase/database.types";
import { OrgConfigView } from "@/modules/org/components/OrgConfigView";
import type {
  CompanyLevelRule,
  HierarchyLevel,
  ParentCompany,
  PositionAllocation,
  TreeKind,
  UnitRow,
} from "@/modules/org/types";

// org_units_current and pos_units_current have the same columns.
function toUnitRows(rows: Tables<"org_units_current">[] | null): UnitRow[] {
  const result: UnitRow[] = [];
  for (const r of rows ?? []) {
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
    result.push({
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
  return result;
}

function toAllocations(
  rows: Tables<"position_allocations_current">[] | null
): PositionAllocation[] {
  const result: PositionAllocation[] = [];
  for (const r of rows ?? []) {
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
    result.push({
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
  return result;
}

async function OrgConfigLoader() {
  const supabase = await createClient();

  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login");
  }

  const [
    companiesRes,
    levelsRes,
    rulesRes,
    orgUnitsRes,
    posUnitsRes,
    allocationsRes,
  ] = await Promise.all([
    supabase.from("parent_companies").select("*").order("company_id"),
    supabase.from("hierarchy_levels").select("*").order("tree").order("rank"),
    supabase.from("company_level_rules_current").select("*").order("level_rank"),
    supabase
      .from("org_units_current")
      .select("*")
      .order("level_rank")
      .order("name_en"),
    supabase
      .from("pos_units_current")
      .select("*")
      .order("level_rank")
      .order("name_en"),
    supabase
      .from("position_allocations_current")
      .select("*")
      .order("allocation_id"),
  ]);

  const companies: ParentCompany[] = (companiesRes.data ?? [])
    .filter(
      (c): c is NonNullable<typeof c> & {
        company_id: number;
        tenant_id: number;
        name_en: string;
        is_active: boolean;
      } =>
        c.company_id !== null &&
        c.tenant_id !== null &&
        c.name_en !== null &&
        c.is_active !== null
    )
    .map((c) => ({
      company_id: c.company_id,
      tenant_id: c.tenant_id,
      name_en: c.name_en,
      name_km: c.name_km,
      is_active: c.is_active,
    }));

  const levels: HierarchyLevel[] = (levelsRes.data ?? [])
    .filter(
      (l): l is NonNullable<typeof l> & {
        level_id: number;
        tree: string;
        code: string;
        rank: number;
        name_en: string;
        can_be_root: boolean;
        is_required: boolean;
      } =>
        l.level_id !== null &&
        (l.tree === "org" || l.tree === "pos") &&
        l.code !== null &&
        l.rank !== null &&
        l.name_en !== null &&
        l.can_be_root !== null &&
        l.is_required !== null
    )
    .map((l) => ({
      level_id: l.level_id,
      tree: l.tree as TreeKind,
      code: l.code,
      rank: l.rank,
      name_en: l.name_en,
      name_km: l.name_km,
      can_be_root: l.can_be_root,
      is_required: l.is_required,
    }));

  const rules: CompanyLevelRule[] = (rulesRes.data ?? [])
    .filter(
      (r): r is NonNullable<typeof r> & {
        rule_id: number;
        company_id: number;
        tree: string;
        level_id: number;
        level_code: string;
        level_rank: number;
        level_name_en: string;
        valid_from: string;
      } =>
        r.rule_id !== null &&
        r.company_id !== null &&
        (r.tree === "org" || r.tree === "pos") &&
        r.level_id !== null &&
        r.level_code !== null &&
        r.level_rank !== null &&
        r.level_name_en !== null &&
        r.valid_from !== null
    )
    .map((r) => ({
      rule_id: r.rule_id,
      company_id: r.company_id,
      tree: r.tree as TreeKind,
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
    }));

  return (
    <OrgConfigView
      userEmail={user.email ?? ""}
      companies={companies}
      levels={levels}
      rules={rules}
      orgUnits={toUnitRows(orgUnitsRes.data)}
      posUnits={toUnitRows(posUnitsRes.data)}
      allocations={toAllocations(allocationsRes.data)}
    />
  );
}

export default function HomePage() {
  return (
    <Suspense
      fallback={
        <div className="flex min-h-screen items-center justify-center bg-zinc-50 text-sm text-zinc-500">
          Loading organization...
        </div>
      }
    >
      <OrgConfigLoader />
    </Suspense>
  );
}
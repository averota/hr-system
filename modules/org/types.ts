// modules/org/types.ts
// Narrowed non-null types for ORG public views and RPC functions.
// (Supabase generates view columns as nullable; these represent validated rows.)

export type TreeKind = "org" | "pos";

export interface ParentCompany {
  company_id: number;
  tenant_id: number;
  name_en: string;
  name_km: string | null;
  is_active: boolean;
}

export interface HierarchyLevel {
  level_id: number;
  tree: TreeKind;
  code: string;
  rank: number;
  name_en: string;
  name_km: string | null;
  can_be_root: boolean;
  is_required: boolean;
}

export interface CompanyLevelRule {
  rule_id: number;
  company_id: number;
  tree: TreeKind;
  level_id: number;
  level_code: string;
  level_rank: number;
  level_name_en: string;
  level_name_km: string | null;
  parent_level_id: number | null;
  parent_level_code: string | null;
  parent_level_name_en: string | null;
  parent_level_name_km: string | null;
  valid_from: string;
}

export interface UnitRow {
  unit_id: number;
  company_id: number;
  level_id: number;
  level_code: string;
  level_rank: number;
  level_name_en: string;
  level_name_km: string | null;
  name_en: string;
  name_km: string | null;
  parent_unit_id: number | null;
  valid_from: string;
}

export interface UnitOption {
  unit_id: number;
  level_id: number;
  level_code: string;
  name_en: string;
  name_km: string | null;
}

export interface JobOption {
  job_position_id: number;
  name_en: string;
  name_km: string | null;
}

export interface PositionAllocation {
  allocation_id: number;
  company_id: number;
  org_unit_id: number;
  org_unit_name_en: string;
  org_unit_name_km: string | null;
  department_id: number;
  department_name_en: string;
  department_name_km: string | null;
  job_position_id: number;
  job_name_en: string;
  job_name_km: string | null;
  pos_unit_id: number;
  pos_unit_name_en: string;
  pos_unit_name_km: string | null;
  pos_level_code: string;
  approved_headcount: number;
  valid_from: string;
}
export interface JobRow {
  job_position_id: number;
  company_id: number;
  department_id: number;
  name_en: string;
  name_km: string | null;
  valid_from: string;
}

export interface ListingRow {
  eligibility_id: number;
  company_id: number;
  org_unit_id: number;
  department_id: number;
  valid_from: string;
}

export interface ClosedRuleRow {
  rule_id: number;
  company_id: number;
  tree: TreeKind;
  level_id: number;
  level_rank: number;
  level_name_en: string;
  level_name_km: string | null;
  parent_level_id: number | null;
  parent_level_name_en: string | null;
  parent_level_name_km: string | null;
  valid_from: string;
  valid_to: string;
}

export interface ClosedUnitRow {
  unit_id: number;
  company_id: number;
  level_id: number;
  level_rank: number;
  level_name_en: string;
  level_name_km: string | null;
  name_en: string;
  name_km: string | null;
  /** The parent it had when it closed. Null = directly under the company, or a Department. */
  parent_unit_id: number | null;
  parent_name_en: string | null;
  parent_name_km: string | null;
  valid_from: string;
  valid_to: string;
}

/** A closed allocation (headcount history). Same fields as PositionAllocation plus the end date. */
export interface ClosedAllocationRow extends PositionAllocation {
  valid_to: string;
}

export interface ClosedJobRow {
  job_position_id: number;
  company_id: number;
  department_id: number;
  department_name_en: string;
  department_name_km: string | null;
  name_en: string;
  name_km: string | null;
  valid_from: string;
  valid_to: string;
}

export interface ClosedListingRow {
  eligibility_id: number;
  company_id: number;
  org_unit_id: number;
  org_unit_name_en: string;
  org_unit_name_km: string | null;
  department_id: number;
  department_name_en: string;
  department_name_km: string | null;
  valid_from: string;
  valid_to: string;
}

// ---------------------------------------------------------------
// ORG Stage 9k (as-of date reads and reorg history, migration 028)
// ---------------------------------------------------------------

/** An allocation as it stood on a date. valid_to empty = still open today. */
export interface AsOfAllocationRow extends PositionAllocation {
  valid_to: string | null;
}

/** A Department listing as it stood on a date. valid_to empty = still open today. */
export interface AsOfListingRow {
  eligibility_id: number;
  company_id: number;
  org_unit_id: number;
  department_id: number;
  valid_from: string;
  valid_to: string | null;
}

/**
 * One past parent link of a unit that was moved (reorg).
 * valid_to is the date the move took effect (the unit was under this parent until then).
 */
export interface UnitMoveRow {
  link_id: number;
  company_id: number;
  unit_id: number;
  name_en: string;
  name_km: string | null;
  level_id: number;
  level_rank: number;
  level_name_en: string;
  level_name_km: string | null;
  /** The parent the unit had during this link. Null = directly under the company. */
  parent_unit_id: number | null;
  parent_name_en: string | null;
  parent_name_km: string | null;
  valid_from: string;
  valid_to: string;
}
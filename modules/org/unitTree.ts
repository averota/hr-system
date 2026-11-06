// modules/org/unitTree.ts
// Pure helpers for working with a list of open units (org tree or position tree)
// and the company's level rules. Used by the tree explorer and the unit dialog.
import type { CompanyLevelRule, TreeKind, UnitRow } from "@/modules/org/types";

/** Ids of every unit below the given unit, at any depth. */
export function descendantIds(units: UnitRow[], unitId: number): Set<number> {
  const kids = new Map<number, number[]>();
  for (const u of units) {
    if (u.parent_unit_id === null) continue;
    const list = kids.get(u.parent_unit_id);
    if (list) list.push(u.unit_id);
    else kids.set(u.parent_unit_id, [u.unit_id]);
  }

  const result = new Set<number>();
  const stack = [unitId];
  while (stack.length > 0) {
    const id = stack.pop() as number;
    for (const kid of kids.get(id) ?? []) {
      if (!result.has(kid)) {
        result.add(kid);
        stack.push(kid);
      }
    }
  }
  return result;
}

/** Position tree: the Department a unit belongs to (the top ancestor). Null if not found. */
export function departmentIdOf(units: UnitRow[], unitId: number): number | null {
  const byId = new Map(units.map((u) => [u.unit_id, u]));
  let current = byId.get(unitId);
  let guard = 0;
  while (current && current.parent_unit_id !== null && guard < 50) {
    current = byId.get(current.parent_unit_id);
    guard++;
  }
  return current && current.parent_unit_id === null ? current.unit_id : null;
}

/**
 * Levels that may be created directly under `parent` (null = directly under the
 * company, or the top of the position tree), from the company's open rules.
 */
export function childLevelRules(
  tree: TreeKind,
  parent: UnitRow | null,
  rules: CompanyLevelRule[]
): CompanyLevelRule[] {
  const parentLevelId = parent ? parent.level_id : null;
  const byLevel = new Map<number, CompanyLevelRule>();
  for (const r of rules) {
    if (r.tree === tree && r.parent_level_id === parentLevelId) {
      byLevel.set(r.level_id, r);
    }
  }
  return [...byLevel.values()].sort((a, b) => a.level_rank - b.level_rank);
}

/**
 * Places a unit may move to, from the open rules. Never includes the unit itself,
 * anything below it, or its current parent. The database still checks every move.
 */
export function moveTargets(
  tree: TreeKind,
  unit: UnitRow,
  units: UnitRow[],
  rules: CompanyLevelRule[]
): { rootAllowed: boolean; parents: UnitRow[] } {
  const levelRules = rules.filter((r) => r.tree === tree && r.level_id === unit.level_id);
  const rootAllowed =
    unit.parent_unit_id !== null && levelRules.some((r) => r.parent_level_id === null);

  const blocked = descendantIds(units, unit.unit_id);
  blocked.add(unit.unit_id);

  const parentLevelIds = new Set<number>();
  for (const r of levelRules) {
    if (r.parent_level_id !== null) parentLevelIds.add(r.parent_level_id);
  }

  const parents = units.filter(
    (p) =>
      !blocked.has(p.unit_id) &&
      p.unit_id !== unit.parent_unit_id &&
      parentLevelIds.has(p.level_id)
  );
  return { rootAllowed, parents };
}
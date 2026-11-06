// modules/org/labels.ts
// Small display helpers shared by the ORG components.
import { displayName, type Locale } from "@/lib/i18n";
import type { HierarchyLevel, TreeKind } from "@/modules/org/types";

/** Level name (for example "Branch") in the active language. Falls back to the level code. */
export function levelLabel(
  levels: HierarchyLevel[],
  locale: Locale,
  levelId: number,
  fallbackCode: string
): string {
  const level = levels.find((l) => l.level_id === levelId);
  return level ? displayName(locale, level.name_en, level.name_km) : fallbackCode;
}

/** What "no parent" means in each tree. Used by the level tables and the history views. */
export const ROOT_LABEL: Record<TreeKind, string> = {
  org: "Directly under Parent Company",
  pos: "Top of Position Tree (Root)",
};
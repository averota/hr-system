// modules/org/components/UnitActionDialog.tsx
"use client";

import { useMemo, useState } from "react";
import { isIsoDate, todayInPhnomPenh } from "@/lib/dates";
import { displayName, type Locale } from "@/lib/i18n";
import { levelLabel } from "@/modules/org/labels";
import { closeUnit, createUnit, renameUnit, reorgUnit } from "@/modules/org/queries";
import type {
  CompanyLevelRule,
  HierarchyLevel,
  TreeKind,
  UnitRow,
} from "@/modules/org/types";
import { childLevelRules, moveTargets } from "@/modules/org/unitTree";
import { selectClassName } from "./AsyncSelect";

export type UnitAction = "create" | "rename" | "close" | "move";

interface UnitActionDialogProps {
  tree: TreeKind;
  companyId: number;
  levels: HierarchyLevel[];
  /** The selected company's open rules (both trees). */
  rules: CompanyLevelRule[];
  /** Open units of this tree for the selected company. */
  units: UnitRow[];
  locale: Locale;
  action: UnitAction;
  /** The unit to rename, close or move. Null for "create". */
  unit: UnitRow | null;
  /** Where a new unit goes. Null = directly under the company (org) or a new Department (pos). */
  parent: UnitRow | null;
  onCancel: () => void;
  /** Called after a successful save with a message to show the user. */
  onDone: (message: string) => void;
}

const ROOT_VALUE = "root";

/** One modal for the four unit actions: add, rename, close and move. */
export function UnitActionDialog({
  tree,
  companyId,
  levels,
  rules,
  units,
  locale,
  action,
  unit,
  parent,
  onCancel,
  onDone,
}: UnitActionDialogProps) {
  const allowedLevels = useMemo(
    () => (action === "create" ? childLevelRules(tree, parent, rules) : []),
    [action, tree, parent, rules]
  );
  const targets = useMemo(
    () =>
      action === "move" && unit
        ? moveTargets(tree, unit, units, rules)
        : { rootAllowed: false, parents: [] as UnitRow[] },
    [action, tree, unit, units, rules]
  );

  const [nameEn, setNameEn] = useState(action === "rename" && unit ? unit.name_en : "");
  const [nameKm, setNameKm] = useState(
    action === "rename" && unit ? (unit.name_km ?? "") : ""
  );
  const [levelId, setLevelId] = useState(
    allowedLevels.length === 1 ? String(allowedLevels[0].level_id) : ""
  );
  const [date, setDate] = useState(() => todayInPhnomPenh());
  const [newParent, setNewParent] = useState("");
  const [isSaving, setIsSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const name = (u: { name_en: string; name_km: string | null }) =>
    displayName(locale, u.name_en, u.name_km);
  const unitLabel = (u: UnitRow) =>
    `${name(u)} (${levelLabel(levels, locale, u.level_id, u.level_code)})`;

  const treeWord = tree === "org" ? "org unit" : "position unit";
  const rootLabel = tree === "org" ? "Directly under the company" : "Top of the position tree";

  const dateIsValid = isIsoDate(date);
  const hasOpenChildren =
    unit !== null && units.some((u) => u.parent_unit_id === unit.unit_id);
  const nameChanged =
    unit !== null &&
    (nameEn.trim() !== unit.name_en || nameKm.trim() !== (unit.name_km ?? ""));

  const sortedParents = useMemo(
    () =>
      [...targets.parents].sort((a, b) =>
        displayName(locale, a.name_en, a.name_km).localeCompare(
          displayName(locale, b.name_en, b.name_km)
        )
      ),
    [targets.parents, locale]
  );

  let canSubmit = false;
  if (action === "create") {
    canSubmit = allowedLevels.length > 0 && levelId !== "" && nameEn.trim() !== "";
  } else if (action === "rename") {
    canSubmit = nameEn.trim() !== "" && nameChanged;
  } else if (action === "close") {
    canSubmit = dateIsValid && !hasOpenChildren;
  } else {
    canSubmit = newParent !== "" && dateIsValid;
  }

  async function handleSubmit() {
    if (!canSubmit) return;
    setIsSaving(true);
    setError(null);
    try {
      if (action === "create") {
        await createUnit(tree, {
          companyId,
          levelId: Number(levelId),
          parentUnitId: parent ? parent.unit_id : null,
          nameEn,
          nameKm,
        });
        onDone(`Added "${nameEn.trim()}".`);
      } else if (action === "rename" && unit) {
        await renameUnit(tree, companyId, unit.unit_id, nameEn, nameKm);
        onDone(`Renamed "${unit.name_en}" to "${nameEn.trim()}".`);
      } else if (action === "close" && unit) {
        await closeUnit(tree, companyId, unit.unit_id, date);
        onDone(`Closed "${unit.name_en}".`);
      } else if (action === "move" && unit) {
        await reorgUnit(
          tree,
          companyId,
          unit.unit_id,
          newParent === ROOT_VALUE ? null : Number(newParent),
          date
        );
        onDone(`Moved "${unit.name_en}".`);
      }
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "Save failed");
      setIsSaving(false);
    }
  }

  const titles: Record<UnitAction, string> = {
    create: parent ? `Add under ${name(parent)}` : "Add top-level unit",
    rename: "Rename unit",
    close: "Close unit",
    move: "Move unit",
  };
  const submitLabels: Record<UnitAction, string> = {
    create: "Add",
    rename: "Save name",
    close: "Close unit",
    move: "Move unit",
  };

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4"
      role="dialog"
      aria-modal="true"
      aria-labelledby="unit-dialog-title"
    >
      <div className="w-full max-w-md rounded-lg bg-white p-5 shadow-lg">
        <h3 id="unit-dialog-title" className="text-base font-semibold text-zinc-900">
          {titles[action]}
        </h3>

        {unit && (
          <p className="mt-2 text-sm text-zinc-700">
            {unitLabel(unit)}
          </p>
        )}

        {action === "create" &&
          (allowedLevels.length === 0 ? (
            <p className="mt-3 rounded-md bg-amber-50 px-3 py-2 text-xs text-amber-800">
              No level is enabled under this parent for this company.
            </p>
          ) : (
            <>
              <label
                htmlFor="unit-level"
                className="mb-1 mt-3 block text-xs font-medium text-zinc-600"
              >
                Level
              </label>
              <select
                id="unit-level"
                value={levelId}
                onChange={(e) => {
                  setError(null);
                  setLevelId(e.target.value);
                }}
                className={selectClassName}
              >
                <option value="">Select level</option>
                {allowedLevels.map((r) => (
                  <option key={r.level_id} value={r.level_id}>
                    {displayName(locale, r.level_name_en, r.level_name_km)}
                  </option>
                ))}
              </select>
            </>
          ))}

        {(action === "create" || action === "rename") && (
          <>
            <label
              htmlFor="unit-name-en"
              className="mb-1 mt-3 block text-xs font-medium text-zinc-600"
            >
              English name (required)
            </label>
            <input
              id="unit-name-en"
              type="text"
              value={nameEn}
              onChange={(e) => {
                setError(null);
                setNameEn(e.target.value);
              }}
              className={selectClassName}
            />
            <label
              htmlFor="unit-name-km"
              className="mb-1 mt-3 block text-xs font-medium text-zinc-600"
            >
              Khmer name (optional)
            </label>
            <input
              id="unit-name-km"
              type="text"
              value={nameKm}
              onChange={(e) => {
                setError(null);
                setNameKm(e.target.value);
              }}
              className={selectClassName}
            />
            {action === "create" && (
              <p className="mt-2 text-xs text-zinc-500">
                The {treeWord} starts today (server date).
              </p>
            )}
          </>
        )}

        {action === "close" && (
          <>
            {hasOpenChildren ? (
              <p className="mt-3 rounded-md bg-amber-50 px-3 py-2 text-xs text-amber-800">
                This unit still has open units under it. Close or move them first.
              </p>
            ) : (
              <p className="mt-3 text-xs text-zinc-500">
                {tree === "org"
                  ? "Headcount allocations and Department listings at this unit are closed with it."
                  : "Headcount allocations placed at this unit are closed with it."}
              </p>
            )}
          </>
        )}

        {action === "move" && (
          <>
            <p className="mt-3 text-xs text-zinc-500">
              The unit moves with everything under it. Allocations and Department
              listings stay attached to it.
            </p>
            {!targets.rootAllowed && sortedParents.length === 0 ? (
              <p className="mt-3 rounded-md bg-amber-50 px-3 py-2 text-xs text-amber-800">
                No other place allows this level under it.
              </p>
            ) : (
              <>
                <label
                  htmlFor="unit-new-parent"
                  className="mb-1 mt-3 block text-xs font-medium text-zinc-600"
                >
                  New parent
                </label>
                <select
                  id="unit-new-parent"
                  value={newParent}
                  onChange={(e) => {
                    setError(null);
                    setNewParent(e.target.value);
                  }}
                  className={selectClassName}
                >
                  <option value="">Select new parent</option>
                  {targets.rootAllowed && <option value={ROOT_VALUE}>{rootLabel}</option>}
                  {sortedParents.map((p) => (
                    <option key={p.unit_id} value={p.unit_id}>
                      {unitLabel(p)}
                    </option>
                  ))}
                </select>
              </>
            )}
          </>
        )}

        {(action === "close" || action === "move") && (
          <>
            <label
              htmlFor="unit-date"
              className="mb-1 mt-3 block text-xs font-medium text-zinc-600"
            >
              {action === "close" ? "Close date" : "Effective date"}
            </label>
            <input
              id="unit-date"
              type="date"
              value={date}
              onChange={(e) => {
                setError(null);
                setDate(e.target.value);
              }}
              className={selectClassName}
            />
          </>
        )}

        {error && (
          <p role="alert" className="mt-3 text-xs text-red-700">
            {error}
          </p>
        )}

        <div className="mt-5 flex justify-end gap-2">
          <button
            type="button"
            onClick={onCancel}
            disabled={isSaving}
            className="rounded-md border border-zinc-300 bg-white px-3 py-1.5 text-sm font-medium text-zinc-700 hover:bg-zinc-50 disabled:opacity-50"
          >
            Cancel
          </button>
          <button
            type="button"
            onClick={handleSubmit}
            disabled={!canSubmit || isSaving}
            className="rounded-md bg-zinc-900 px-3 py-1.5 text-sm font-medium text-white hover:bg-zinc-800 disabled:cursor-not-allowed disabled:bg-zinc-300 disabled:text-zinc-600"
          >
            {isSaving ? "Saving..." : submitLabels[action]}
          </button>
        </div>
      </div>
    </div>
  );
}
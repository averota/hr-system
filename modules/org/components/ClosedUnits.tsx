// modules/org/components/ClosedUnits.tsx
"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { displayName, type Locale } from "@/lib/i18n";
import { ROOT_LABEL } from "@/modules/org/labels";
import {
  PERM_ORG_UNIT_WRITE,
  PERM_POS_UNIT_WRITE,
  usePermissions,
  type PermissionTarget,
} from "@/modules/org/permissions";
import { fetchClosedUnits } from "@/modules/org/queries";
import type {
  ClosedUnitRow,
  CompanyLevelRule,
  HierarchyLevel,
  TreeKind,
  UnitRow,
} from "@/modules/org/types";
import { childLevelRules, departmentIdOf } from "@/modules/org/unitTree";
import { selectClassName } from "./AsyncSelect";
import { UnitActionDialog } from "./UnitActionDialog";

interface ClosedUnitsProps {
  tree: TreeKind;
  companyId: number;
  locale: Locale;
  levels: HierarchyLevel[];
  /** The selected company's open rules (both trees). */
  rules: CompanyLevelRule[];
  /** Open units of this tree for the selected company. */
  units: UnitRow[];
}

type RecreateState =
  | { kind: "ready"; parent: UnitRow | null }
  | { kind: "blocked"; reason: string }
  | { kind: "hidden" };

interface OpenRecreate {
  row: ClosedUnitRow;
  parent: UnitRow | null;
}

const COPY: Record<TreeKind, { title: string; description: string; empty: string }> = {
  org: {
    title: "Closed Org Units",
    description:
      "Org units that were closed, with the parent they had when they closed. Newest closed first.",
    empty: "No org units have been closed for this company.",
  },
  pos: {
    title: "Closed Position Units",
    description:
      "Departments, Offices, Sections and Groups that were closed, with the parent they had when they closed. Newest closed first.",
    empty: "No Departments or position units have been closed for this company.",
  },
};

/**
 * List of closed units of one tree. Each row has a Re-create button that opens the
 * add dialog pre-filled from the closed unit (a closed unit is never re-opened, the
 * new unit gets a new ID). Give it a `key` that includes the tree and the company id.
 */
export function ClosedUnits({
  tree,
  companyId,
  locale,
  levels,
  rules,
  units,
}: ClosedUnitsProps) {
  const router = useRouter();
  const [rows, setRows] = useState<ClosedUnitRow[] | null>(null);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [search, setSearch] = useState("");
  const [dialog, setDialog] = useState<OpenRecreate | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    fetchClosedUnits(tree, companyId)
      .then((data) => {
        if (cancelled) return;
        setRows(data);
        setLoadError(null);
      })
      .catch((e: unknown) => {
        if (!cancelled) setLoadError(e instanceof Error ? e.message : "Load failed");
      });
    return () => {
      cancelled = true;
    };
  }, [tree, companyId]);

  const shown = useMemo(() => {
    const q = search.trim().toLowerCase();
    if (q === "") return rows ?? [];
    return (rows ?? []).filter((r) => `${r.name_en} ${r.name_km ?? ""}`.toLowerCase().includes(q));
  }, [rows, search]);

  const openById = useMemo(() => new Map(units.map((u) => [u.unit_id, u])), [units]);

  // Where the permission is checked for adding under a parent (same rule as the tree screens).
  function parentTarget(parentId: number | null): PermissionTarget {
    if (parentId === null) return {};
    return tree === "org"
      ? { orgUnitId: parentId }
      : { departmentId: departmentIdOf(units, parentId) };
  }

  // One batched permission check for every row whose old parent is still open.
  const permissionTargets = useMemo(() => {
    const list: PermissionTarget[] = [];
    for (const r of rows ?? []) {
      if (r.parent_unit_id === null || openById.has(r.parent_unit_id)) {
        list.push(parentTarget(r.parent_unit_id));
      }
    }
    return list;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [rows, openById, tree, units]);
  const permission = usePermissions(
    companyId,
    tree === "pos" ? PERM_POS_UNIT_WRITE : PERM_ORG_UNIT_WRITE,
    permissionTargets
  );

  function recreateState(r: ClosedUnitRow): RecreateState {
    let parent: UnitRow | null = null;
    if (r.parent_unit_id !== null) {
      const found = openById.get(r.parent_unit_id);
      if (!found) return { kind: "blocked", reason: "The parent it had is closed." };
      parent = found;
    }
    if (!childLevelRules(tree, parent, rules).some((x) => x.level_id === r.level_id)) {
      return { kind: "blocked", reason: "This level is not enabled under that parent any more." };
    }
    const t = parentTarget(r.parent_unit_id);
    if (!permission.can(t.orgUnitId, t.departmentId)) return { kind: "hidden" };
    return { kind: "ready", parent };
  }

  function handleDone(message: string) {
    setDialog(null);
    setNotice(message);
    router.refresh(); // reload open units from the database
  }

  // Level name of any unit shown here, so a parent (open or closed) can show its level.
  const levelNameById = useMemo(() => {
    const map = new Map<number, string>();
    for (const r of rows ?? []) {
      map.set(r.unit_id, displayName(locale, r.level_name_en, r.level_name_km));
    }
    for (const u of units) {
      map.set(u.unit_id, displayName(locale, u.level_name_en, u.level_name_km));
    }
    return map;
  }, [rows, units, locale]);

  const copy = COPY[tree];

  return (
    <section className="rounded-lg border border-zinc-200 bg-white shadow-sm">
      <div className="border-b border-zinc-200 px-4 py-3">
        <h2 className="text-base font-semibold text-zinc-900">{copy.title}</h2>
        <p className="mt-0.5 text-sm text-zinc-600">{copy.description}</p>
      </div>

      {notice && (
        <p
          role="status"
          className="mx-4 mt-4 rounded-md bg-emerald-50 px-3 py-2 text-sm text-emerald-800"
        >
          {notice}
        </p>
      )}

      {loadError ? (
        <p className="m-4 rounded-md bg-red-50 px-3 py-2 text-sm text-red-700">{loadError}</p>
      ) : rows === null ? (
        <p className="m-4 text-sm text-zinc-500">Loading...</p>
      ) : rows.length === 0 ? (
        <p className="m-4 rounded-md bg-zinc-100 px-3 py-2 text-sm text-zinc-700">{copy.empty}</p>
      ) : (
        <>
          <div className="grid gap-3 border-b border-zinc-200 p-4 sm:grid-cols-3">
            <div>
              <label
                htmlFor={`closed-search-${tree}`}
                className="mb-1 block text-xs font-medium text-zinc-600"
              >
                Search
              </label>
              <input
                id={`closed-search-${tree}`}
                type="search"
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                placeholder="Name..."
                className={selectClassName}
              />
            </div>
            <div className="flex items-end text-xs text-zinc-600 sm:col-span-2">
              Showing {shown.length} of {rows.length} closed units
            </div>
          </div>

          {shown.length === 0 ? (
            <p className="m-4 rounded-md bg-zinc-100 px-3 py-2 text-sm text-zinc-700">
              No closed units match the search.
            </p>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-left text-sm">
                <thead className="border-b border-zinc-200 bg-zinc-50 text-xs uppercase text-zinc-600">
                  <tr>
                    <th className="px-4 py-2.5">Name</th>
                    <th className="px-4 py-2.5">Level</th>
                    <th className="px-4 py-2.5">Was under</th>
                    <th className="px-4 py-2.5">Started</th>
                    <th className="px-4 py-2.5">Closed</th>
                    <th className="px-4 py-2.5"></th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-zinc-200">
                  {shown.map((r) => (
                    <tr key={r.unit_id} className="align-top">
                      <td className="px-4 py-3 font-medium text-zinc-900">
                        {displayName(locale, r.name_en, r.name_km)}
                      </td>
                      <td className="px-4 py-3">
                        <span className="inline-block rounded bg-zinc-100 px-1.5 py-0.5 text-xs text-zinc-700">
                          {displayName(locale, r.level_name_en, r.level_name_km)}
                        </span>
                      </td>
                      <td className="px-4 py-3 text-zinc-700">
                        {r.parent_unit_id === null ? (
                          ROOT_LABEL[tree]
                        ) : (
                          <>
                            {displayName(locale, r.parent_name_en ?? "", r.parent_name_km)}
                            {tree === "pos" && levelNameById.has(r.parent_unit_id) && (
                              <span className="ml-2 inline-block rounded bg-zinc-100 px-1.5 py-0.5 text-xs text-zinc-700">
                                {levelNameById.get(r.parent_unit_id)}
                              </span>
                            )}
                          </>
                        )}
                      </td>
                      <td className="whitespace-nowrap px-4 py-3 text-xs text-zinc-500">
                        {r.valid_from}
                      </td>
                      <td className="whitespace-nowrap px-4 py-3 text-xs text-zinc-500">
                        {r.valid_to}
                      </td>
                      <td className="whitespace-nowrap px-4 py-3 text-right">
                        {(() => {
                          const state = recreateState(r);
                          if (state.kind === "hidden") return null;
                          return (
                            <button
                              type="button"
                              disabled={state.kind === "blocked"}
                              title={state.kind === "blocked" ? state.reason : undefined}
                              onClick={() => {
                                if (state.kind !== "ready") return;
                                setNotice(null);
                                setDialog({ row: r, parent: state.parent });
                              }}
                              className="rounded border border-zinc-300 bg-white px-2 py-0.5 text-xs font-medium text-zinc-700 hover:bg-zinc-50 disabled:cursor-not-allowed disabled:opacity-50"
                            >
                              Re-create
                            </button>
                          );
                        })()}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </>
      )}

      {dialog && (
        <UnitActionDialog
          key={`recreate-${dialog.row.unit_id}`}
          tree={tree}
          companyId={companyId}
          levels={levels}
          rules={rules}
          units={units}
          locale={locale}
          action="create"
          unit={null}
          parent={dialog.parent}
          prefill={{
            nameEn: dialog.row.name_en,
            nameKm: dialog.row.name_km,
            levelId: dialog.row.level_id,
          }}
          onCancel={() => setDialog(null)}
          onDone={handleDone}
        />
      )}
    </section>
  );
}
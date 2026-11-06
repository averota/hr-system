// modules/org/components/DepartmentListings.tsx
"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { displayName, type Locale } from "@/lib/i18n";
import { levelLabel } from "@/modules/org/labels";
import { fetchListings } from "@/modules/org/queries";
import { PERM_ELIGIBILITY_WRITE, usePermissions } from "@/modules/org/permissions";
import type {
  HierarchyLevel,
  ListingRow,
  PositionAllocation,
  UnitRow,
} from "@/modules/org/types";
import { ListingDialog, type ListingAction } from "./ListingDialog";

interface DepartmentListingsProps {
  companyId: number;
  levels: HierarchyLevel[];
  /** Open org units of the selected company. */
  orgUnits: UnitRow[];
  /** Open Departments of the selected company. */
  departments: UnitRow[];
  /** Open allocations of the selected company (to see which listings are in use). */
  allocations: PositionAllocation[];
  locale: Locale;
}

interface OpenDialog {
  action: ListingAction;
  orgUnit: UnitRow;
  department: UnitRow | null;
}

/**
 * Which Departments each org unit may use. Listings are not inherited.
 * Buttons show only where the user has org.eligibility.write at the org unit.
 * Give it a `key` that includes the company id.
 */
export function DepartmentListings({
  companyId,
  levels,
  orgUnits,
  departments,
  allocations,
  locale,
}: DepartmentListingsProps) {
  const router = useRouter();
  const [listings, setListings] = useState<ListingRow[] | null>(null);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [reloadKey, setReloadKey] = useState(0);
  const [dialog, setDialog] = useState<OpenDialog | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    fetchListings(companyId)
      .then((rows) => {
        if (cancelled) return;
        setListings(rows);
        setLoadError(null);
      })
      .catch((e: unknown) => {
        if (!cancelled) setLoadError(e instanceof Error ? e.message : "Load failed");
      });
    return () => {
      cancelled = true;
    };
  }, [companyId, reloadKey]);

  const permissionTargets = useMemo(
    () => orgUnits.map((u) => ({ orgUnitId: u.unit_id })),
    [orgUnits]
  );
  const permission = usePermissions(companyId, PERM_ELIGIBILITY_WRITE, permissionTargets);

  const departmentById = useMemo(
    () => new Map(departments.map((d) => [d.unit_id, d])),
    [departments]
  );

  const listedByOrgUnit = useMemo(() => {
    const map = new Map<number, UnitRow[]>();
    const collator = new Intl.Collator(locale === "km" ? "km" : "en");
    for (const l of listings ?? []) {
      const dept = departmentById.get(l.department_id);
      if (!dept) continue;
      const list = map.get(l.org_unit_id);
      if (list) list.push(dept);
      else map.set(l.org_unit_id, [dept]);
    }
    for (const list of map.values()) {
      list.sort((a, b) =>
        collator.compare(
          displayName(locale, a.name_en, a.name_km),
          displayName(locale, b.name_en, b.name_km)
        )
      );
    }
    return map;
  }, [listings, departmentById, locale]);

  // "orgUnitId:departmentId" -> number of open allocations that use the listing
  const allocationCounts = useMemo(() => {
    const map = new Map<string, number>();
    for (const a of allocations) {
      const key = `${a.org_unit_id}:${a.department_id}`;
      map.set(key, (map.get(key) ?? 0) + 1);
    }
    return map;
  }, [allocations]);

  const sortedOrgUnits = useMemo(() => {
    const collator = new Intl.Collator(locale === "km" ? "km" : "en");
    return [...orgUnits].sort(
      (a, b) =>
        a.level_rank - b.level_rank ||
        collator.compare(
          displayName(locale, a.name_en, a.name_km),
          displayName(locale, b.name_en, b.name_km)
        )
    );
  }, [orgUnits, locale]);

  function openDialog(next: OpenDialog) {
    setNotice(null);
    setDialog(next);
  }

  function handleDone(message: string) {
    setDialog(null);
    setNotice(message);
    setReloadKey((k) => k + 1); // reload the listings
    router.refresh();
  }

  return (
    <section className="rounded-lg border border-zinc-200 bg-white shadow-sm">
      <div className="border-b border-zinc-200 px-4 py-3">
        <h2 className="text-base font-semibold text-zinc-900">Department Listings</h2>
        <p className="mt-0.5 text-sm text-zinc-600">
          The Departments each org unit may use. They are not inherited from the parent
          org unit. A listing cannot be removed while allocations use it.
        </p>
      </div>

      {notice && (
        <p
          role="status"
          className="mx-4 mt-4 rounded-md bg-emerald-50 px-3 py-2 text-sm text-emerald-800"
        >
          {notice}
        </p>
      )}

      {orgUnits.length === 0 ? (
        <p className="m-4 rounded-md bg-amber-50 px-3 py-2 text-sm text-amber-800">
          No org units exist for this company yet. Add one on the Org tree tab first.
        </p>
      ) : loadError ? (
        <p className="m-4 rounded-md bg-red-50 px-3 py-2 text-sm text-red-700">{loadError}</p>
      ) : listings === null ? (
        <p className="m-4 text-sm text-zinc-500">Loading...</p>
      ) : (
        <div className="overflow-x-auto">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-zinc-200 bg-zinc-50 text-xs uppercase text-zinc-600">
              <tr>
                <th className="px-4 py-2.5">Org unit</th>
                <th className="px-4 py-2.5">Listed Departments</th>
                <th className="px-4 py-2.5 text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-zinc-200">
              {sortedOrgUnits.map((u) => {
                const listed = listedByOrgUnit.get(u.unit_id) ?? [];
                const canWrite = permission.can(u.unit_id, null);
                const listedIds = new Set(listed.map((d) => d.unit_id));
                const available = departments.filter((d) => !listedIds.has(d.unit_id));

                return (
                  <tr key={u.unit_id} className="align-top">
                    <td className="px-4 py-3">
                      <div className="font-medium text-zinc-900">
                        {displayName(locale, u.name_en, u.name_km)}
                      </div>
                      <span className="mt-0.5 inline-block rounded bg-zinc-100 px-1.5 py-0.5 text-xs text-zinc-700">
                        {levelLabel(levels, locale, u.level_id, u.level_code)}
                      </span>
                    </td>
                    <td className="px-4 py-3">
                      {listed.length === 0 ? (
                        <span className="text-zinc-400">No Department listed</span>
                      ) : (
                        <ul className="flex flex-wrap gap-2">
                          {listed.map((d) => (
                            <li
                              key={d.unit_id}
                              className="inline-flex items-center gap-1.5 rounded-full bg-zinc-100 px-2.5 py-0.5 text-xs text-zinc-800"
                            >
                              {displayName(locale, d.name_en, d.name_km)}
                              {canWrite && (
                                <button
                                  type="button"
                                  aria-label={`Remove ${displayName(locale, d.name_en, d.name_km)}`}
                                  onClick={() =>
                                    openDialog({ action: "remove", orgUnit: u, department: d })
                                  }
                                  className="text-zinc-500 hover:text-red-700"
                                >
                                  ✕
                                </button>
                              )}
                            </li>
                          ))}
                        </ul>
                      )}
                    </td>
                    <td className="whitespace-nowrap px-4 py-3 text-right">
                      {canWrite ? (
                        <button
                          type="button"
                          onClick={() =>
                            openDialog({ action: "add", orgUnit: u, department: null })
                          }
                          disabled={available.length === 0}
                          className="rounded-md border border-zinc-300 bg-white px-2.5 py-1 text-xs font-medium text-zinc-700 hover:bg-zinc-50 disabled:cursor-not-allowed disabled:opacity-50"
                        >
                          Add Department
                        </button>
                      ) : (
                        !permission.isLoading && (
                          <span className="text-xs text-zinc-400">View only</span>
                        )
                      )}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}

      {dialog && (
        <ListingDialog
          key={`${dialog.action}-${dialog.orgUnit.unit_id}-${dialog.department?.unit_id ?? "new"}`}
          action={dialog.action}
          companyId={companyId}
          locale={locale}
          orgUnit={dialog.orgUnit}
          availableDepartments={departments.filter(
            (d) =>
              !(listedByOrgUnit.get(dialog.orgUnit.unit_id) ?? []).some(
                (l) => l.unit_id === d.unit_id
              )
          )}
          department={dialog.department}
          allocationCount={
            dialog.department
              ? (allocationCounts.get(`${dialog.orgUnit.unit_id}:${dialog.department.unit_id}`) ?? 0)
              : 0
          }
          onCancel={() => setDialog(null)}
          onDone={handleDone}
        />
      )}
    </section>
  );
}
// modules/org/components/HeadcountGrid.tsx
"use client";

import { useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { displayName, type Locale } from "@/lib/i18n";
import { PERM_ALLOCATION_WRITE, usePermissions } from "@/modules/org/permissions";
import type { HierarchyLevel, PositionAllocation } from "@/modules/org/types";
import {
  AllocationActionDialog,
  type AllocationAction,
} from "./AllocationActionDialog";
import { selectClassName } from "./AsyncSelect";

interface HeadcountGridProps {
  companyId: number;
  allocations: PositionAllocation[];
  levels: HierarchyLevel[];
  locale: Locale;
}

interface FilterOption {
  id: number;
  label: string;
}

interface OpenDialog {
  allocation: PositionAllocation;
  action: AllocationAction;
}

function uniqueOptions(items: FilterOption[], collator: Intl.Collator): FilterOption[] {
  const map = new Map<number, FilterOption>();
  for (const item of items) map.set(item.id, item);
  return [...map.values()].sort((a, b) => collator.compare(a.label, b.label));
}

/**
 * Table of open allocations with change-headcount and close actions.
 * The parent passes only the selected company's rows.
 * Give it a `key` that includes the company id so the filters reset on company change.
 */
export function HeadcountGrid({ companyId, allocations, levels, locale }: HeadcountGridProps) {
  const router = useRouter();
  const [search, setSearch] = useState("");
  const [orgUnitId, setOrgUnitId] = useState("");
  const [departmentId, setDepartmentId] = useState("");
  const [dialog, setDialog] = useState<OpenDialog | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  // One batched permission check for every org unit + Department pair in the list.
  const permissionTargets = useMemo(
    () =>
      allocations.map((a) => ({
        orgUnitId: a.org_unit_id,
        departmentId: a.department_id,
      })),
    [allocations]
  );
  const permission = usePermissions(companyId, PERM_ALLOCATION_WRITE, permissionTargets);

  const collator = useMemo(
    () => new Intl.Collator(locale === "km" ? "km" : "en"),
    [locale]
  );

  const orgUnitOptions = useMemo(
    () =>
      uniqueOptions(
        allocations.map((a) => ({
          id: a.org_unit_id,
          label: displayName(locale, a.org_unit_name_en, a.org_unit_name_km),
        })),
        collator
      ),
    [allocations, locale, collator]
  );

  const departmentOptions = useMemo(
    () =>
      uniqueOptions(
        allocations.map((a) => ({
          id: a.department_id,
          label: displayName(locale, a.department_name_en, a.department_name_km),
        })),
        collator
      ),
    [allocations, locale, collator]
  );

  const rows = useMemo(() => {
    const q = search.trim().toLowerCase();
    return allocations
      .filter((a) => {
        if (orgUnitId !== "" && a.org_unit_id !== Number(orgUnitId)) return false;
        if (departmentId !== "" && a.department_id !== Number(departmentId)) return false;
        if (q === "") return true;
        // Search both languages, whichever one is shown.
        const haystack = [
          a.org_unit_name_en,
          a.org_unit_name_km,
          a.department_name_en,
          a.department_name_km,
          a.pos_unit_name_en,
          a.pos_unit_name_km,
          a.job_name_en,
          a.job_name_km,
        ]
          .filter(Boolean)
          .join(" ")
          .toLowerCase();
        return haystack.includes(q);
      })
      .sort(
        (a, b) =>
          collator.compare(
            displayName(locale, a.org_unit_name_en, a.org_unit_name_km),
            displayName(locale, b.org_unit_name_en, b.org_unit_name_km)
          ) ||
          collator.compare(
            displayName(locale, a.department_name_en, a.department_name_km),
            displayName(locale, b.department_name_en, b.department_name_km)
          ) ||
          collator.compare(
            displayName(locale, a.pos_unit_name_en, a.pos_unit_name_km),
            displayName(locale, b.pos_unit_name_en, b.pos_unit_name_km)
          ) ||
          collator.compare(
            displayName(locale, a.job_name_en, a.job_name_km),
            displayName(locale, b.job_name_en, b.job_name_km)
          )
      );
  }, [allocations, search, orgUnitId, departmentId, locale, collator]);

  const totalHeadcount = rows.reduce((sum, a) => sum + a.approved_headcount, 0);
  const isFiltered = search.trim() !== "" || orgUnitId !== "" || departmentId !== "";

  function clearFilters() {
    setSearch("");
    setOrgUnitId("");
    setDepartmentId("");
  }

  function posLevelName(code: string): string {
    const level = levels.find((l) => l.code === code);
    return level ? displayName(locale, level.name_en, level.name_km) : code;
  }

  function openDialog(allocation: PositionAllocation, action: AllocationAction) {
    setNotice(null);
    setDialog({ allocation, action });
  }

  function handleDone(message: string) {
    setDialog(null);
    setNotice(message);
    router.refresh(); // reload allocations from the database
  }

  return (
    <section className="rounded-lg border border-zinc-200 bg-white shadow-sm">
      <div className="border-b border-zinc-200 px-4 py-3">
        <h2 className="text-base font-semibold text-zinc-900">Approved Headcount</h2>
        <p className="mt-0.5 text-sm text-zinc-600">
          Open allocations for the selected company. Changing a headcount closes the
          allocation and starts a new one on the date you pick.
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

      {allocations.length === 0 ? (
        <p className="m-4 rounded-md bg-zinc-100 px-3 py-2 text-sm text-zinc-700">
          No open allocations exist for this company yet.
        </p>
      ) : (
        <>
          <div className="grid gap-3 border-b border-zinc-200 p-4 sm:grid-cols-2 lg:grid-cols-4">
            <div>
              <label
                htmlFor="hc-search"
                className="mb-1 block text-xs font-medium text-zinc-600"
              >
                Search
              </label>
              <input
                id="hc-search"
                type="search"
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                placeholder="Org unit, department, job..."
                className={selectClassName}
              />
            </div>
            <div>
              <label
                htmlFor="hc-org"
                className="mb-1 block text-xs font-medium text-zinc-600"
              >
                Org unit
              </label>
              <select
                id="hc-org"
                value={orgUnitId}
                onChange={(e) => setOrgUnitId(e.target.value)}
                className={selectClassName}
              >
                <option value="">All org units</option>
                {orgUnitOptions.map((o) => (
                  <option key={o.id} value={o.id}>
                    {o.label}
                  </option>
                ))}
              </select>
            </div>
            <div>
              <label
                htmlFor="hc-dept"
                className="mb-1 block text-xs font-medium text-zinc-600"
              >
                Department
              </label>
              <select
                id="hc-dept"
                value={departmentId}
                onChange={(e) => setDepartmentId(e.target.value)}
                className={selectClassName}
              >
                <option value="">All Departments</option>
                {departmentOptions.map((o) => (
                  <option key={o.id} value={o.id}>
                    {o.label}
                  </option>
                ))}
              </select>
            </div>
            <div className="flex items-end justify-between gap-3 text-xs text-zinc-600">
              <span>
                Showing {rows.length} of {allocations.length} allocations
              </span>
              {isFiltered && (
                <button
                  type="button"
                  onClick={clearFilters}
                  className="rounded-md border border-zinc-300 px-2.5 py-1.5 font-medium text-zinc-700 hover:bg-zinc-50"
                >
                  Clear filters
                </button>
              )}
            </div>
          </div>

          {rows.length === 0 ? (
            <p className="m-4 rounded-md bg-zinc-100 px-3 py-2 text-sm text-zinc-700">
              No allocations match the filters.
            </p>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-left text-sm">
                <thead className="border-b border-zinc-200 bg-zinc-50 text-xs uppercase text-zinc-600">
                  <tr>
                    <th className="px-4 py-2.5">Org unit</th>
                    <th className="px-4 py-2.5">Department</th>
                    <th className="px-4 py-2.5">Position unit</th>
                    <th className="px-4 py-2.5">Job position</th>
                    <th className="px-4 py-2.5 text-right">Approved headcount</th>
                    <th className="px-4 py-2.5">Since</th>
                    <th className="px-4 py-2.5 text-right">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-zinc-200">
                  {rows.map((a) => (
                    <tr key={a.allocation_id} className="align-top">
                      <td className="px-4 py-3 text-zinc-900">
                        {displayName(locale, a.org_unit_name_en, a.org_unit_name_km)}
                      </td>
                      <td className="px-4 py-3 text-zinc-700">
                        {displayName(locale, a.department_name_en, a.department_name_km)}
                      </td>
                      <td className="px-4 py-3 text-zinc-700">
                        <div>
                          {displayName(locale, a.pos_unit_name_en, a.pos_unit_name_km)}
                        </div>
                        <span className="mt-0.5 inline-block rounded bg-zinc-100 px-1.5 py-0.5 text-xs text-zinc-700">
                          {posLevelName(a.pos_level_code)}
                        </span>
                      </td>
                      <td className="px-4 py-3 font-medium text-zinc-900">
                        {displayName(locale, a.job_name_en, a.job_name_km)}
                      </td>
                      <td className="px-4 py-3 text-right font-mono text-zinc-900">
                        {a.approved_headcount}
                      </td>
                      <td className="px-4 py-3 text-xs text-zinc-400">{a.valid_from}</td>
                      <td className="whitespace-nowrap px-4 py-3 text-right">
                        {permission.can(a.org_unit_id, a.department_id) ? (
                          <>
                            <button
                              type="button"
                              onClick={() => openDialog(a, "change")}
                              className="rounded-md border border-zinc-300 bg-white px-2.5 py-1 text-xs font-medium text-zinc-700 hover:bg-zinc-50"
                            >
                              Change
                            </button>
                            <button
                              type="button"
                              onClick={() => openDialog(a, "close")}
                              className="ml-2 rounded-md border border-zinc-300 bg-white px-2.5 py-1 text-xs font-medium text-red-700 hover:bg-red-50"
                            >
                              Close
                            </button>
                          </>
                        ) : (
                          !permission.isLoading && (
                            <span className="text-xs text-zinc-400">View only</span>
                          )
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
                <tfoot className="border-t border-zinc-200 bg-zinc-50">
                  <tr>
                    <td colSpan={4} className="px-4 py-2.5 text-xs font-medium text-zinc-600">
                      {isFiltered ? "Total (filtered)" : "Total"}
                    </td>
                    <td className="px-4 py-2.5 text-right font-mono font-semibold text-zinc-900">
                      {totalHeadcount}
                    </td>
                    <td colSpan={2} />
                  </tr>
                </tfoot>
              </table>
            </div>
          )}
        </>
      )}

      {dialog && (
        <AllocationActionDialog
          key={`${dialog.action}-${dialog.allocation.allocation_id}`}
          companyId={companyId}
          allocation={dialog.allocation}
          action={dialog.action}
          locale={locale}
          onCancel={() => setDialog(null)}
          onDone={handleDone}
        />
      )}
    </section>
  );
}
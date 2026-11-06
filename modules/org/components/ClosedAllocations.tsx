// modules/org/components/ClosedAllocations.tsx
"use client";

import { useEffect, useMemo, useState } from "react";
import { displayName, type Locale } from "@/lib/i18n";
import { fetchClosedAllocations } from "@/modules/org/queries";
import type { ClosedAllocationRow, HierarchyLevel } from "@/modules/org/types";
import { selectClassName } from "./AsyncSelect";

interface ClosedAllocationsProps {
  companyId: number;
  levels: HierarchyLevel[];
  locale: Locale;
}

interface FilterOption {
  id: number;
  label: string;
}

function uniqueOptions(items: FilterOption[], collator: Intl.Collator): FilterOption[] {
  const map = new Map<number, FilterOption>();
  for (const item of items) map.set(item.id, item);
  return [...map.values()].sort((a, b) => collator.compare(a.label, b.label));
}

/**
 * Read-only list of closed allocations (headcount history), newest closed first.
 * A headcount change shows as one closed row (the old headcount) plus a new open one.
 * Give it a `key` that includes the company id.
 */
export function ClosedAllocations({ companyId, levels, locale }: ClosedAllocationsProps) {
  const [rows, setRows] = useState<ClosedAllocationRow[] | null>(null);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [search, setSearch] = useState("");
  const [orgUnitId, setOrgUnitId] = useState("");
  const [departmentId, setDepartmentId] = useState("");

  useEffect(() => {
    let cancelled = false;
    fetchClosedAllocations(companyId)
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
  }, [companyId]);

  const collator = useMemo(
    () => new Intl.Collator(locale === "km" ? "km" : "en"),
    [locale]
  );

  const orgUnitOptions = useMemo(
    () =>
      uniqueOptions(
        (rows ?? []).map((a) => ({
          id: a.org_unit_id,
          label: displayName(locale, a.org_unit_name_en, a.org_unit_name_km),
        })),
        collator
      ),
    [rows, locale, collator]
  );

  const departmentOptions = useMemo(
    () =>
      uniqueOptions(
        (rows ?? []).map((a) => ({
          id: a.department_id,
          label: displayName(locale, a.department_name_en, a.department_name_km),
        })),
        collator
      ),
    [rows, locale, collator]
  );

  // The list keeps the database order (newest closed first).
  const shown = useMemo(() => {
    const q = search.trim().toLowerCase();
    return (rows ?? []).filter((a) => {
      if (orgUnitId !== "" && a.org_unit_id !== Number(orgUnitId)) return false;
      if (departmentId !== "" && a.department_id !== Number(departmentId)) return false;
      if (q === "") return true;
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
    });
  }, [rows, search, orgUnitId, departmentId]);

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

  return (
    <section className="rounded-lg border border-zinc-200 bg-white shadow-sm">
      <div className="border-b border-zinc-200 px-4 py-3">
        <h2 className="text-base font-semibold text-zinc-900">Closed Allocations</h2>
        <p className="mt-0.5 text-sm text-zinc-600">
          Allocations that were closed, including the old headcount after a change. Newest
          closed first.
        </p>
      </div>

      {loadError ? (
        <p className="m-4 rounded-md bg-red-50 px-3 py-2 text-sm text-red-700">{loadError}</p>
      ) : rows === null ? (
        <p className="m-4 text-sm text-zinc-500">Loading...</p>
      ) : rows.length === 0 ? (
        <p className="m-4 rounded-md bg-zinc-100 px-3 py-2 text-sm text-zinc-700">
          No allocations have been closed for this company.
        </p>
      ) : (
        <>
          <div className="grid gap-3 border-b border-zinc-200 p-4 sm:grid-cols-2 lg:grid-cols-4">
            <div>
              <label
                htmlFor="closed-hc-search"
                className="mb-1 block text-xs font-medium text-zinc-600"
              >
                Search
              </label>
              <input
                id="closed-hc-search"
                type="search"
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                placeholder="Org unit, department, job..."
                className={selectClassName}
              />
            </div>
            <div>
              <label
                htmlFor="closed-hc-org"
                className="mb-1 block text-xs font-medium text-zinc-600"
              >
                Org unit
              </label>
              <select
                id="closed-hc-org"
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
                htmlFor="closed-hc-dept"
                className="mb-1 block text-xs font-medium text-zinc-600"
              >
                Department
              </label>
              <select
                id="closed-hc-dept"
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
                Showing {shown.length} of {rows.length} closed allocations
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

          {shown.length === 0 ? (
            <p className="m-4 rounded-md bg-zinc-100 px-3 py-2 text-sm text-zinc-700">
              No closed allocations match the filters.
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
                    <th className="px-4 py-2.5">Started</th>
                    <th className="px-4 py-2.5">Closed</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-zinc-200">
                  {shown.map((a) => (
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
                      <td className="whitespace-nowrap px-4 py-3 text-xs text-zinc-500">
                        {a.valid_from}
                      </td>
                      <td className="whitespace-nowrap px-4 py-3 text-xs text-zinc-500">
                        {a.valid_to}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </>
      )}
    </section>
  );
}
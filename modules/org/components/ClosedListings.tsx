// modules/org/components/ClosedListings.tsx
"use client";

import { useEffect, useMemo, useState } from "react";
import { displayName, type Locale } from "@/lib/i18n";
import { PERM_ELIGIBILITY_WRITE, usePermissions } from "@/modules/org/permissions";
import { fetchClosedListings, fetchListings } from "@/modules/org/queries";
import type { ClosedListingRow, ListingRow, UnitRow } from "@/modules/org/types";
import { selectClassName } from "./AsyncSelect";
import { ListingDialog } from "./ListingDialog";

interface ClosedListingsProps {
  companyId: number;
  locale: Locale;
  /** Open org units of the selected company. */
  orgUnits: UnitRow[];
  /** Open Departments of the selected company. */
  departments: UnitRow[];
}

type RecreateState =
  | { kind: "ready"; orgUnit: UnitRow; department: UnitRow }
  | { kind: "blocked"; reason: string }
  | { kind: "hidden" };

interface OpenRecreate {
  orgUnit: UnitRow;
  department: UnitRow;
}

/**
 * List of closed Department listings, newest closed first. Each row has a Re-create
 * button that opens the list-a-Department dialog pre-filled from the closed listing
 * (the new listing gets a new ID). Give it a `key` that includes the company id.
 */
export function ClosedListings({ companyId, locale, orgUnits, departments }: ClosedListingsProps) {
  const [rows, setRows] = useState<ClosedListingRow[] | null>(null);
  const [openListings, setOpenListings] = useState<ListingRow[] | null>(null);
  const [reloadKey, setReloadKey] = useState(0);
  const [recreate, setRecreate] = useState<OpenRecreate | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [search, setSearch] = useState("");
  const [departmentId, setDepartmentId] = useState("");

  useEffect(() => {
    let cancelled = false;
    Promise.all([fetchClosedListings(companyId), fetchListings(companyId)])
      .then(([data, open]) => {
        if (cancelled) return;
        setRows(data);
        setOpenListings(open);
        setLoadError(null);
      })
      .catch((e: unknown) => {
        if (!cancelled) setLoadError(e instanceof Error ? e.message : "Load failed");
      });
    return () => {
      cancelled = true;
    };
  }, [companyId, reloadKey]);

  const departmentOptions = useMemo(() => {
    const collator = new Intl.Collator(locale === "km" ? "km" : "en");
    const map = new Map<number, string>();
    for (const r of rows ?? []) {
      map.set(r.department_id, displayName(locale, r.department_name_en, r.department_name_km));
    }
    return [...map.entries()]
      .map(([id, label]) => ({ id, label }))
      .sort((a, b) => collator.compare(a.label, b.label));
  }, [rows, locale]);

  // The list keeps the database order (newest closed first).
  const shown = useMemo(() => {
    const q = search.trim().toLowerCase();
    return (rows ?? []).filter((r) => {
      if (departmentId !== "" && r.department_id !== Number(departmentId)) return false;
      if (q === "") return true;
      return `${r.org_unit_name_en} ${r.org_unit_name_km ?? ""} ${r.department_name_en} ${
        r.department_name_km ?? ""
      }`
        .toLowerCase()
        .includes(q);
    });
  }, [rows, search, departmentId]);

  const orgById = useMemo(() => new Map(orgUnits.map((u) => [u.unit_id, u])), [orgUnits]);
  const departmentById = useMemo(
    () => new Map(departments.map((d) => [d.unit_id, d])),
    [departments]
  );
  // "orgUnitId:departmentId" of every open listing
  const openKeys = useMemo(
    () => new Set((openListings ?? []).map((l) => `${l.org_unit_id}:${l.department_id}`)),
    [openListings]
  );

  // One batched permission check for every row whose org unit is still open.
  const permissionTargets = useMemo(
    () =>
      [...new Set((rows ?? []).map((r) => r.org_unit_id))]
        .filter((id) => orgById.has(id))
        .map((id) => ({ orgUnitId: id })),
    [rows, orgById]
  );
  const permission = usePermissions(companyId, PERM_ELIGIBILITY_WRITE, permissionTargets);

  function recreateState(r: ClosedListingRow): RecreateState {
    const orgUnit = orgById.get(r.org_unit_id);
    if (!orgUnit) return { kind: "blocked", reason: "The org unit is closed." };
    const department = departmentById.get(r.department_id);
    if (!department) return { kind: "blocked", reason: "The Department is closed." };
    if (openKeys.has(`${r.org_unit_id}:${r.department_id}`)) {
      return { kind: "blocked", reason: "This Department is already listed for the org unit." };
    }
    if (!permission.can(r.org_unit_id, null)) return { kind: "hidden" };
    return { kind: "ready", orgUnit, department };
  }

  function handleDone(message: string) {
    setRecreate(null);
    setNotice(message);
    setReloadKey((k) => k + 1); // reload, so the new listing counts as open
  }

  return (
    <section className="rounded-lg border border-zinc-200 bg-white shadow-sm">
      <div className="border-b border-zinc-200 px-4 py-3">
        <h2 className="text-base font-semibold text-zinc-900">Closed Department Listings</h2>
        <p className="mt-0.5 text-sm text-zinc-600">
          Departments that were removed from an org unit, or closed with it. Newest closed
          first.
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

      {loadError ? (
        <p className="m-4 rounded-md bg-red-50 px-3 py-2 text-sm text-red-700">{loadError}</p>
      ) : rows === null ? (
        <p className="m-4 text-sm text-zinc-500">Loading...</p>
      ) : rows.length === 0 ? (
        <p className="m-4 rounded-md bg-zinc-100 px-3 py-2 text-sm text-zinc-700">
          No Department listings have been closed for this company.
        </p>
      ) : (
        <>
          <div className="grid gap-3 border-b border-zinc-200 p-4 sm:grid-cols-3">
            <div>
              <label
                htmlFor="closed-listing-search"
                className="mb-1 block text-xs font-medium text-zinc-600"
              >
                Search
              </label>
              <input
                id="closed-listing-search"
                type="search"
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                placeholder="Org unit or Department..."
                className={selectClassName}
              />
            </div>
            <div>
              <label
                htmlFor="closed-listing-dept"
                className="mb-1 block text-xs font-medium text-zinc-600"
              >
                Department
              </label>
              <select
                id="closed-listing-dept"
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
            <div className="flex items-end text-xs text-zinc-600">
              Showing {shown.length} of {rows.length} closed listings
            </div>
          </div>

          {shown.length === 0 ? (
            <p className="m-4 rounded-md bg-zinc-100 px-3 py-2 text-sm text-zinc-700">
              No closed listings match the filters.
            </p>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-left text-sm">
                <thead className="border-b border-zinc-200 bg-zinc-50 text-xs uppercase text-zinc-600">
                  <tr>
                    <th className="px-4 py-2.5">Org unit</th>
                    <th className="px-4 py-2.5">Department</th>
                    <th className="px-4 py-2.5">Started</th>
                    <th className="px-4 py-2.5">Closed</th>
                    <th className="px-4 py-2.5"></th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-zinc-200">
                  {shown.map((r) => (
                    <tr key={r.eligibility_id} className="align-top">
                      <td className="px-4 py-3 font-medium text-zinc-900">
                        {displayName(locale, r.org_unit_name_en, r.org_unit_name_km)}
                      </td>
                      <td className="px-4 py-3 text-zinc-700">
                        {displayName(locale, r.department_name_en, r.department_name_km)}
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
                                setRecreate({
                                  orgUnit: state.orgUnit,
                                  department: state.department,
                                });
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

      {recreate && (
        <ListingDialog
          key={`recreate-${recreate.orgUnit.unit_id}-${recreate.department.unit_id}`}
          action="add"
          companyId={companyId}
          locale={locale}
          orgUnit={recreate.orgUnit}
          availableDepartments={[recreate.department]}
          department={null}
          allocationCount={0}
          prefillDepartmentId={recreate.department.unit_id}
          onCancel={() => setRecreate(null)}
          onDone={handleDone}
        />
      )}
    </section>
  );
}
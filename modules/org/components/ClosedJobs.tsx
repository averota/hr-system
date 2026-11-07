// modules/org/components/ClosedJobs.tsx
"use client";

import { useEffect, useMemo, useState } from "react";
import { displayName, type Locale } from "@/lib/i18n";
import { PERM_JOB_WRITE, usePermissions } from "@/modules/org/permissions";
import { fetchClosedJobs } from "@/modules/org/queries";
import type { ClosedJobRow, UnitRow } from "@/modules/org/types";
import { selectClassName } from "./AsyncSelect";
import { JobDialog } from "./JobDialog";

interface ClosedJobsProps {
  companyId: number;
  locale: Locale;
  /** Open Departments of the selected company. */
  departments: UnitRow[];
}

type RecreateState =
  | { kind: "ready" }
  | { kind: "blocked"; reason: string }
  | { kind: "hidden" };

/**
 * List of closed job positions, newest closed first. Each row has a Re-create button
 * that opens the add dialog pre-filled from the closed job (the new job gets a new ID).
 * Give it a `key` that includes the company id.
 */
export function ClosedJobs({ companyId, locale, departments }: ClosedJobsProps) {
  const [rows, setRows] = useState<ClosedJobRow[] | null>(null);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [search, setSearch] = useState("");
  const [departmentId, setDepartmentId] = useState("");
  const [recreateRow, setRecreateRow] = useState<ClosedJobRow | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    fetchClosedJobs(companyId)
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
      return `${r.name_en} ${r.name_km ?? ""}`.toLowerCase().includes(q);
    });
  }, [rows, search, departmentId]);

  const openDepartmentIds = useMemo(
    () => new Set(departments.map((d) => d.unit_id)),
    [departments]
  );

  // One batched permission check for every row whose Department is still open.
  const permissionTargets = useMemo(
    () =>
      [...new Set((rows ?? []).map((r) => r.department_id))]
        .filter((id) => openDepartmentIds.has(id))
        .map((id) => ({ departmentId: id })),
    [rows, openDepartmentIds]
  );
  const permission = usePermissions(companyId, PERM_JOB_WRITE, permissionTargets);

  function recreateState(r: ClosedJobRow): RecreateState {
    if (!openDepartmentIds.has(r.department_id)) {
      return { kind: "blocked", reason: "The Department of this job is closed." };
    }
    if (!permission.can(null, r.department_id)) return { kind: "hidden" };
    return { kind: "ready" };
  }

  function handleDone(message: string) {
    setRecreateRow(null);
    setNotice(message);
  }

  return (
    <section className="rounded-lg border border-zinc-200 bg-white shadow-sm">
      <div className="border-b border-zinc-200 px-4 py-3">
        <h2 className="text-base font-semibold text-zinc-900">Closed Job Positions</h2>
        <p className="mt-0.5 text-sm text-zinc-600">
          Job positions that were closed. Their allocations closed with them. Newest closed
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
          No job positions have been closed for this company.
        </p>
      ) : (
        <>
          <div className="grid gap-3 border-b border-zinc-200 p-4 sm:grid-cols-3">
            <div>
              <label
                htmlFor="closed-job-search"
                className="mb-1 block text-xs font-medium text-zinc-600"
              >
                Search
              </label>
              <input
                id="closed-job-search"
                type="search"
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                placeholder="Job name..."
                className={selectClassName}
              />
            </div>
            <div>
              <label
                htmlFor="closed-job-dept"
                className="mb-1 block text-xs font-medium text-zinc-600"
              >
                Department
              </label>
              <select
                id="closed-job-dept"
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
              Showing {shown.length} of {rows.length} closed jobs
            </div>
          </div>

          {shown.length === 0 ? (
            <p className="m-4 rounded-md bg-zinc-100 px-3 py-2 text-sm text-zinc-700">
              No closed jobs match the filters.
            </p>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-left text-sm">
                <thead className="border-b border-zinc-200 bg-zinc-50 text-xs uppercase text-zinc-600">
                  <tr>
                    <th className="px-4 py-2.5">Department</th>
                    <th className="px-4 py-2.5">Job position</th>
                    <th className="px-4 py-2.5">Started</th>
                    <th className="px-4 py-2.5">Closed</th>
                    <th className="px-4 py-2.5"></th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-zinc-200">
                  {shown.map((r) => (
                    <tr key={r.job_position_id} className="align-top">
                      <td className="px-4 py-3 text-zinc-700">
                        {displayName(locale, r.department_name_en, r.department_name_km)}
                      </td>
                      <td className="px-4 py-3 font-medium text-zinc-900">
                        {displayName(locale, r.name_en, r.name_km)}
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
                                setRecreateRow(r);
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

      {recreateRow && (
        <JobDialog
          key={`recreate-${recreateRow.job_position_id}`}
          action="create"
          companyId={companyId}
          locale={locale}
          departments={departments.filter((d) => d.unit_id === recreateRow.department_id)}
          job={null}
          defaultDepartmentId={recreateRow.department_id}
          allocationCount={0}
          prefill={{ nameEn: recreateRow.name_en, nameKm: recreateRow.name_km }}
          onCancel={() => setRecreateRow(null)}
          onDone={handleDone}
        />
      )}
    </section>
  );
}
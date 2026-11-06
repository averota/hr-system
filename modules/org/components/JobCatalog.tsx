// modules/org/components/JobCatalog.tsx
"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { displayName, type Locale } from "@/lib/i18n";
import { fetchJobs } from "@/modules/org/queries";
import { PERM_JOB_WRITE, usePermissions } from "@/modules/org/permissions";
import type { JobRow, PositionAllocation, UnitRow } from "@/modules/org/types";
import { selectClassName } from "./AsyncSelect";
import { JobDialog, type JobAction } from "./JobDialog";

interface JobCatalogProps {
  companyId: number;
  /** Open Departments of the selected company. */
  departments: UnitRow[];
  /** Open allocations of the selected company (to show how many use each job). */
  allocations: PositionAllocation[];
  locale: Locale;
}

interface OpenDialog {
  action: JobAction;
  job: JobRow | null;
}

/**
 * Job catalog: open job positions grouped by Department, with add, rename and close.
 * Buttons show only where the user has pos.job.write for the job's Department.
 * Give it a `key` that includes the company id.
 */
export function JobCatalog({ companyId, departments, allocations, locale }: JobCatalogProps) {
  const router = useRouter();
  const [jobs, setJobs] = useState<JobRow[] | null>(null);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [reloadKey, setReloadKey] = useState(0);
  const [departmentFilter, setDepartmentFilter] = useState("");
  const [search, setSearch] = useState("");
  const [dialog, setDialog] = useState<OpenDialog | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    fetchJobs(companyId)
      .then((rows) => {
        if (cancelled) return;
        setJobs(rows);
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
    () => departments.map((d) => ({ departmentId: d.unit_id })),
    [departments]
  );
  const permission = usePermissions(companyId, PERM_JOB_WRITE, permissionTargets);
  const writableDepartments = departments.filter((d) => permission.can(null, d.unit_id));

  const departmentName = useMemo(() => {
    const map = new Map<number, string>();
    for (const d of departments) map.set(d.unit_id, displayName(locale, d.name_en, d.name_km));
    return map;
  }, [departments, locale]);

  const allocationCountByJob = useMemo(() => {
    const map = new Map<number, number>();
    for (const a of allocations) {
      map.set(a.job_position_id, (map.get(a.job_position_id) ?? 0) + 1);
    }
    return map;
  }, [allocations]);

  const rows = useMemo(() => {
    const collator = new Intl.Collator(locale === "km" ? "km" : "en");
    const q = search.trim().toLowerCase();
    return (jobs ?? [])
      .filter((j) => {
        if (departmentFilter !== "" && j.department_id !== Number(departmentFilter)) {
          return false;
        }
        if (q === "") return true;
        return `${j.name_en} ${j.name_km ?? ""}`.toLowerCase().includes(q);
      })
      .sort(
        (a, b) =>
          collator.compare(
            departmentName.get(a.department_id) ?? "",
            departmentName.get(b.department_id) ?? ""
          ) || collator.compare(
            displayName(locale, a.name_en, a.name_km),
            displayName(locale, b.name_en, b.name_km)
          )
      );
  }, [jobs, departmentFilter, search, locale, departmentName]);

  function openDialog(next: OpenDialog) {
    setNotice(null);
    setDialog(next);
  }

  function handleDone(message: string) {
    setDialog(null);
    setNotice(message);
    setReloadKey((k) => k + 1); // reload the job list
    router.refresh(); // job names and closed allocations also show on the Headcount tab
  }

  return (
    <section className="rounded-lg border border-zinc-200 bg-white shadow-sm">
      <div className="flex flex-wrap items-start justify-between gap-3 border-b border-zinc-200 px-4 py-3">
        <div>
          <h2 className="text-base font-semibold text-zinc-900">Job Positions</h2>
          <p className="mt-0.5 text-sm text-zinc-600">
            Open job positions by Department. Closing a job also closes its allocations.
          </p>
        </div>
        {writableDepartments.length > 0 && (
          <button
            type="button"
            onClick={() => openDialog({ action: "create", job: null })}
            className="rounded-md bg-zinc-900 px-2.5 py-1 text-xs font-medium text-white hover:bg-zinc-800"
          >
            Add job position
          </button>
        )}
      </div>

      {notice && (
        <p
          role="status"
          className="mx-4 mt-4 rounded-md bg-emerald-50 px-3 py-2 text-sm text-emerald-800"
        >
          {notice}
        </p>
      )}

      {departments.length === 0 ? (
        <p className="m-4 rounded-md bg-amber-50 px-3 py-2 text-sm text-amber-800">
          No Departments exist for this company yet. Add one on the Position tree tab first.
        </p>
      ) : loadError ? (
        <p className="m-4 rounded-md bg-red-50 px-3 py-2 text-sm text-red-700">{loadError}</p>
      ) : jobs === null ? (
        <p className="m-4 text-sm text-zinc-500">Loading...</p>
      ) : (
        <>
          <div className="grid gap-3 border-b border-zinc-200 p-4 sm:grid-cols-3">
            <div>
              <label
                htmlFor="job-search"
                className="mb-1 block text-xs font-medium text-zinc-600"
              >
                Search
              </label>
              <input
                id="job-search"
                type="search"
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                placeholder="Job name..."
                className={selectClassName}
              />
            </div>
            <div>
              <label
                htmlFor="job-dept-filter"
                className="mb-1 block text-xs font-medium text-zinc-600"
              >
                Department
              </label>
              <select
                id="job-dept-filter"
                value={departmentFilter}
                onChange={(e) => setDepartmentFilter(e.target.value)}
                className={selectClassName}
              >
                <option value="">All Departments</option>
                {departments.map((d) => (
                  <option key={d.unit_id} value={d.unit_id}>
                    {departmentName.get(d.unit_id)}
                  </option>
                ))}
              </select>
            </div>
            <div className="flex items-end text-xs text-zinc-600">
              Showing {rows.length} of {jobs.length} jobs
            </div>
          </div>

          {rows.length === 0 ? (
            <p className="m-4 rounded-md bg-zinc-100 px-3 py-2 text-sm text-zinc-700">
              {jobs.length === 0
                ? "No open job positions exist for this company yet."
                : "No jobs match the filters."}
            </p>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-left text-sm">
                <thead className="border-b border-zinc-200 bg-zinc-50 text-xs uppercase text-zinc-600">
                  <tr>
                    <th className="px-4 py-2.5">Department</th>
                    <th className="px-4 py-2.5">Job position</th>
                    <th className="px-4 py-2.5 text-right">Open allocations</th>
                    <th className="px-4 py-2.5">Since</th>
                    <th className="px-4 py-2.5 text-right">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-zinc-200">
                  {rows.map((j) => (
                    <tr key={j.job_position_id} className="align-top">
                      <td className="px-4 py-3 text-zinc-700">
                        {departmentName.get(j.department_id) ?? `Department ${j.department_id}`}
                      </td>
                      <td className="px-4 py-3 font-medium text-zinc-900">
                        {displayName(locale, j.name_en, j.name_km)}
                      </td>
                      <td className="px-4 py-3 text-right font-mono text-zinc-900">
                        {allocationCountByJob.get(j.job_position_id) ?? 0}
                      </td>
                      <td className="px-4 py-3 text-xs text-zinc-400">{j.valid_from}</td>
                      <td className="whitespace-nowrap px-4 py-3 text-right">
                        {permission.can(null, j.department_id) ? (
                          <>
                            <button
                              type="button"
                              onClick={() => openDialog({ action: "rename", job: j })}
                              className="rounded-md border border-zinc-300 bg-white px-2.5 py-1 text-xs font-medium text-zinc-700 hover:bg-zinc-50"
                            >
                              Rename
                            </button>
                            <button
                              type="button"
                              onClick={() => openDialog({ action: "close", job: j })}
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
              </table>
            </div>
          )}
        </>
      )}

      {dialog && (
        <JobDialog
          key={`${dialog.action}-${dialog.job?.job_position_id ?? "new"}`}
          action={dialog.action}
          companyId={companyId}
          locale={locale}
          departments={writableDepartments}
          job={dialog.job}
          defaultDepartmentId={departmentFilter === "" ? null : Number(departmentFilter)}
          allocationCount={
            dialog.job ? (allocationCountByJob.get(dialog.job.job_position_id) ?? 0) : 0
          }
          onCancel={() => setDialog(null)}
          onDone={handleDone}
        />
      )}
    </section>
  );
}
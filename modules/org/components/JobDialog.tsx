// modules/org/components/JobDialog.tsx
"use client";

import { useState } from "react";
import { isIsoDate, todayInPhnomPenh } from "@/lib/dates";
import { displayName, type Locale } from "@/lib/i18n";
import { closeJob, createJob, renameJob } from "@/modules/org/queries";
import type { JobRow, UnitRow } from "@/modules/org/types";
import { selectClassName } from "./AsyncSelect";
import { Modal } from "./Modal";

export type JobAction = "create" | "rename" | "close";

interface JobDialogProps {
  action: JobAction;
  companyId: number;
  locale: Locale;
  /** Departments the user may add jobs to (used by "create"). */
  departments: UnitRow[];
  /** The job to rename or close. Null for "create". */
  job: JobRow | null;
  /** Department to preselect for "create". */
  defaultDepartmentId: number | null;
  /** Open allocations that use the job (shown when closing). */
  allocationCount: number;
  /** Re-create: pre-fills the add form from a closed job. Only used with "create". */
  prefill?: { nameEn: string; nameKm: string | null };
  onCancel: () => void;
  /** Called after a successful save with a message to show the user. */
  onDone: (message: string) => void;
}

/** Modal to add, rename or close one job position. */
export function JobDialog({
  action,
  companyId,
  locale,
  departments,
  job,
  defaultDepartmentId,
  allocationCount,
  prefill,
  onCancel,
  onDone,
}: JobDialogProps) {
  const [departmentId, setDepartmentId] = useState(() => {
    if (defaultDepartmentId !== null) return String(defaultDepartmentId);
    return departments.length === 1 ? String(departments[0].unit_id) : "";
  });
  const [nameEn, setNameEn] = useState(
    action === "rename" && job ? job.name_en : (prefill?.nameEn ?? "")
  );
  const [nameKm, setNameKm] = useState(
    action === "rename" && job ? (job.name_km ?? "") : (prefill?.nameKm ?? "")
  );
  const [date, setDate] = useState(() => todayInPhnomPenh());
  const [isSaving, setIsSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const dateIsValid = isIsoDate(date);
  const nameChanged =
    job !== null &&
    (nameEn.trim() !== job.name_en || nameKm.trim() !== (job.name_km ?? ""));

  let canSubmit = false;
  if (action === "create") canSubmit = departmentId !== "" && nameEn.trim() !== "";
  else if (action === "rename") canSubmit = nameEn.trim() !== "" && nameChanged;
  else canSubmit = dateIsValid;

  async function handleSubmit() {
    if (!canSubmit) return;
    setIsSaving(true);
    setError(null);
    try {
      if (action === "create") {
        await createJob(companyId, Number(departmentId), nameEn, nameKm);
        onDone(`${prefill ? "Re-created" : "Added"} job "${nameEn.trim()}".`);
      } else if (action === "rename" && job) {
        await renameJob(companyId, job.job_position_id, nameEn, nameKm);
        onDone(`Renamed "${job.name_en}" to "${nameEn.trim()}".`);
      } else if (action === "close" && job) {
        await closeJob(companyId, job.job_position_id, date);
        onDone(`Closed job "${job.name_en}".`);
      }
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "Save failed");
      setIsSaving(false);
    }
  }

  const titles: Record<JobAction, string> = {
    create: prefill ? "Re-create job position" : "Add job position",
    rename: "Rename job position",
    close: "Close job position",
  };
  const submitLabels: Record<JobAction, string> = {
    create: prefill ? "Re-create" : "Add",
    rename: "Save name",
    close: "Close job",
  };

  return (
    <Modal
      title={titles[action]}
      submitLabel={submitLabels[action]}
      canSubmit={canSubmit}
      isSaving={isSaving}
      error={error}
      onSubmit={handleSubmit}
      onCancel={onCancel}
    >
      {job && (
        <p className="mt-2 text-sm text-zinc-700">
          {displayName(locale, job.name_en, job.name_km)}
        </p>
      )}

      {action === "create" && (
        <>
          <label
            htmlFor="job-department"
            className="mb-1 mt-3 block text-xs font-medium text-zinc-600"
          >
            Department
          </label>
          <select
            id="job-department"
            value={departmentId}
            onChange={(e) => {
              setError(null);
              setDepartmentId(e.target.value);
            }}
            className={selectClassName}
          >
            <option value="">Select Department</option>
            {departments.map((d) => (
              <option key={d.unit_id} value={d.unit_id}>
                {displayName(locale, d.name_en, d.name_km)}
              </option>
            ))}
          </select>
        </>
      )}

      {(action === "create" || action === "rename") && (
        <>
          <label
            htmlFor="job-name-en"
            className="mb-1 mt-3 block text-xs font-medium text-zinc-600"
          >
            English name (required, unique inside the Department)
          </label>
          <input
            id="job-name-en"
            type="text"
            value={nameEn}
            onChange={(e) => {
              setError(null);
              setNameEn(e.target.value);
            }}
            className={selectClassName}
          />
          <label
            htmlFor="job-name-km"
            className="mb-1 mt-3 block text-xs font-medium text-zinc-600"
          >
            Khmer name (optional)
          </label>
          <input
            id="job-name-km"
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
              The job starts today (server date).
            </p>
          )}
        </>
      )}

      {action === "close" && (
        <>
          <p className="mt-3 text-xs text-zinc-500">
            {allocationCount > 0
              ? `The ${allocationCount} open allocation(s) of this job are closed with it.`
              : "No open allocations use this job."}
          </p>
          <label
            htmlFor="job-date"
            className="mb-1 mt-3 block text-xs font-medium text-zinc-600"
          >
            Close date
          </label>
          <input
            id="job-date"
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
    </Modal>
  );
}
// modules/org/components/AllocationForm.tsx
"use client";

import { useCallback, useState, type ReactNode } from "react";
import { useRouter } from "next/navigation";
import { isIsoDate, todayInPhnomPenh } from "@/lib/dates";
import { displayName, type Locale } from "@/lib/i18n";
import { levelLabel } from "@/modules/org/labels";
import {
  MAX_HEADCOUNT,
  createAllocation,
  fetchEligibleDepartments,
  fetchEligibleJobs,
  fetchExistingAllocation,
  fetchOrgOptions,
  fetchPosOptions,
} from "@/modules/org/queries";
import { PERM_ALLOCATION_WRITE, usePermissions } from "@/modules/org/permissions";
import type { HierarchyLevel, JobOption, UnitOption } from "@/modules/org/types";
import { AsyncSelect, selectClassName } from "./AsyncSelect";
import { CascadeSelector } from "./CascadeSelector";

interface AllocationFormProps {
  companyId: number;
  locale: Locale;
  levels: HierarchyLevel[];
}

interface ExistingCheck {
  key: string;
  headcount: number | null; // null = no open allocation
  error?: string;
}

function Step({ number, title, children }: { number: number; title: string; children: ReactNode }) {
  return (
    <div className="rounded-md border border-zinc-200 p-4">
      <h3 className="mb-3 text-sm font-semibold text-zinc-900">
        {number}. {title}
      </h3>
      {children}
    </div>
  );
}

export function AllocationForm({ companyId, locale, levels }: AllocationFormProps) {
  const router = useRouter();
  const [orgUnit, setOrgUnit] = useState<UnitOption | null>(null);
  const [department, setDepartment] = useState<UnitOption | null>(null);
  const [deeperPosUnit, setDeeperPosUnit] = useState<UnitOption | null>(null);
  const [job, setJob] = useState<JobOption | null>(null);
  const [headcount, setHeadcount] = useState("");
  const [startDate, setStartDate] = useState(() => todayInPhnomPenh());
  const [existing, setExisting] = useState<ExistingCheck | null>(null);
  const [isSaving, setIsSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [savedMessage, setSavedMessage] = useState<string | null>(null);
  // Bumped after a save so the job dropdown reloads and clears.
  const [resetKey, setResetKey] = useState(0);

  // The position unit is the deepest one picked, or the Department itself.
  const posUnit = deeperPosUnit ?? department;

  const orgUnitId = orgUnit?.unit_id ?? null;
  const departmentId = department?.unit_id ?? null;

  // Can the user write allocations at this org unit and Department?
  const permission = usePermissions(
    companyId,
    PERM_ALLOCATION_WRITE,
    orgUnitId !== null && departmentId !== null ? [{ orgUnitId, departmentId }] : []
  );
  const canWrite = permission.can(orgUnitId, departmentId);

  const loadOrgChildren = useCallback(
    (parentId: number | null) => fetchOrgOptions(companyId, parentId),
    [companyId]
  );
  const loadPosChildren = useCallback(
    (parentId: number | null) =>
      parentId === null
        ? Promise.resolve<UnitOption[]>([])
        : fetchPosOptions(companyId, parentId),
    [companyId]
  );
  const loadDepartments = useCallback(
    () =>
      orgUnitId === null
        ? Promise.resolve<UnitOption[]>([])
        : fetchEligibleDepartments(companyId, orgUnitId),
    [companyId, orgUnitId]
  );
  const loadJobs = useCallback(
    () =>
      orgUnitId === null || departmentId === null
        ? Promise.resolve<JobOption[]>([])
        : fetchEligibleJobs(companyId, orgUnitId, departmentId),
    [companyId, orgUnitId, departmentId]
  );

  function clearStatus() {
    setSaveError(null);
    setSavedMessage(null);
  }

  function refreshExisting(
    org: UnitOption | null,
    pos: UnitOption | null,
    selectedJob: JobOption | null
  ) {
    if (!org || !pos || !selectedJob) {
      setExisting(null);
      return;
    }
    const key = `${org.unit_id}:${pos.unit_id}:${selectedJob.job_position_id}`;
    fetchExistingAllocation(companyId, org.unit_id, pos.unit_id, selectedJob.job_position_id)
      .then((row) => setExisting({ key, headcount: row ? row.approved_headcount : null }))
      .catch((e: unknown) =>
        setExisting({
          key,
          headcount: null,
          error: e instanceof Error ? e.message : "Check failed",
        })
      );
  }

  function handleOrgChange(unit: UnitOption | null) {
    clearStatus();
    setOrgUnit(unit);
    setDepartment(null);
    setDeeperPosUnit(null);
    setJob(null);
    setExisting(null);
  }

  function handleDepartmentChange(dept: UnitOption | null) {
    clearStatus();
    setDepartment(dept);
    setDeeperPosUnit(null);
    setJob(null);
    setExisting(null);
  }

  function handlePosChange(unit: UnitOption | null) {
    clearStatus();
    setDeeperPosUnit(unit);
    refreshExisting(orgUnit, unit ?? department, job);
  }

  function handleJobChange(selectedJob: JobOption | null) {
    clearStatus();
    setJob(selectedJob);
    refreshExisting(orgUnit, posUnit, selectedJob);
  }

  const name = (u: { name_en: string; name_km: string | null }) =>
    displayName(locale, u.name_en, u.name_km);

  const headcountIsValid =
    /^\d+$/.test(headcount) && Number(headcount) <= MAX_HEADCOUNT;
  const startDateIsValid = isIsoDate(startDate);

  const currentKey =
    orgUnit && posUnit && job
      ? `${orgUnit.unit_id}:${posUnit.unit_id}:${job.job_position_id}`
      : null;
  const existingForCurrent =
    currentKey !== null && existing?.key === currentKey ? existing : null;
  const isDuplicate =
    existingForCurrent !== null && existingForCurrent.headcount !== null;

  // Wait for the duplicate check. If the check itself failed, the database still
  // rejects a duplicate, so saving stays possible.
  const canSave =
    canWrite &&
    orgUnit !== null &&
    posUnit !== null &&
    job !== null &&
    headcountIsValid &&
    startDateIsValid &&
    existingForCurrent !== null &&
    !isDuplicate;

  async function handleSave() {
    if (!orgUnit || !posUnit || !job || !canSave) return;

    const message = `Saved: ${name(job)} at ${name(orgUnit)}, approved headcount ${headcount}.`;
    setIsSaving(true);
    clearStatus();
    try {
      await createAllocation({
        companyId,
        orgUnitId: orgUnit.unit_id,
        jobPositionId: job.job_position_id,
        posUnitId: posUnit.unit_id,
        headcount: Number(headcount),
        startDate,
      });
      setSavedMessage(message);
      setJob(null);
      setHeadcount("");
      setExisting(null);
      setResetKey((k) => k + 1);
      router.refresh(); // reload the allocation list for the Headcount tab
    } catch (e: unknown) {
      setSaveError(e instanceof Error ? e.message : "Save failed");
    } finally {
      setIsSaving(false);
    }
  }

  return (
    <section className="rounded-lg border border-zinc-200 bg-white shadow-sm">
      <div className="border-b border-zinc-200 px-4 py-3">
        <h2 className="text-base font-semibold text-zinc-900">
          Approved Headcount Allocation
        </h2>
        <p className="mt-0.5 text-sm text-zinc-600">
          Pick each step in order. Every list only offers valid choices.
        </p>
      </div>

      {savedMessage && (
        <p
          role="status"
          className="mx-4 mt-4 rounded-md bg-emerald-50 px-3 py-2 text-sm text-emerald-800"
        >
          {savedMessage}
        </p>
      )}

      <div className="grid gap-4 p-4 lg:grid-cols-2">
        <Step number={1} title="Org location">
          <CascadeSelector
            key={`org-${companyId}`}
            label="Org location"
            placeholder="Select org location"
            emptyText="No org units exist for this company yet."
            emptyTone="warning"
            locale={locale}
            levels={levels}
            rootParentId={null}
            fetchChildren={loadOrgChildren}
            onChange={handleOrgChange}
          />
        </Step>

        {orgUnit && (
          <Step number={2} title="Department">
            <AsyncSelect
              key={`dept-${orgUnit.unit_id}`}
              label="Department"
              placeholder="Select Department"
              emptyText="No Department is listed for this org unit. Eligibility is not inherited from the parent."
              load={loadDepartments}
              getId={(d: UnitOption) => d.unit_id}
              getLabel={name}
              onChange={handleDepartmentChange}
            />
          </Step>
        )}

        {department && (
          <Step number={3} title="Position unit">
            <p className="mb-3 text-xs text-zinc-500">
              Default is the Department itself. Go deeper only if the job belongs in an
              Office, Section or Group.
            </p>
            <CascadeSelector
              key={`pos-${department.unit_id}`}
              label="Position unit"
              placeholder="Use the Department itself"
              emptyText="No Office, Section or Group under this Department. The Department itself is the position unit."
              emptyTone="info"
              locale={locale}
              levels={levels}
              rootParentId={department.unit_id}
              fetchChildren={loadPosChildren}
              onChange={handlePosChange}
            />
          </Step>
        )}

        {orgUnit && department && (
          <Step number={4} title="Job position">
            <AsyncSelect
              key={`job-${orgUnit.unit_id}-${department.unit_id}-${resetKey}`}
              label="Job position"
              placeholder="Select job"
              emptyText="No open job positions exist for this Department."
              load={loadJobs}
              getId={(j: JobOption) => j.job_position_id}
              getLabel={name}
              onChange={handleJobChange}
            />
          </Step>
        )}

        {job && (
          <Step number={5} title="Approved headcount and start date">
            <label
              htmlFor="headcount"
              className="mb-1 block text-xs font-medium text-zinc-600"
            >
              Approved headcount (whole number, 0 or more)
            </label>
            <input
              id="headcount"
              type="text"
              inputMode="numeric"
              value={headcount}
              onChange={(e) => {
                clearStatus();
                setHeadcount(e.target.value.trim());
              }}
              className={selectClassName}
            />
            {headcount !== "" && !headcountIsValid && (
              <p className="mt-1 text-xs text-red-700">
                Enter a whole number from 0 to {MAX_HEADCOUNT}.
              </p>
            )}

            <label
              htmlFor="start-date"
              className="mb-1 mt-4 block text-xs font-medium text-zinc-600"
            >
              Start date
            </label>
            <input
              id="start-date"
              type="date"
              value={startDate}
              onChange={(e) => {
                clearStatus();
                setStartDate(e.target.value);
              }}
              className={selectClassName}
            />
            {!startDateIsValid && (
              <p className="mt-1 text-xs text-red-700">Pick a start date.</p>
            )}
          </Step>
        )}
      </div>

      {orgUnit && department && posUnit && job && (
        <div className="border-t border-zinc-200 bg-zinc-50 px-4 py-4 text-sm">
          <h3 className="mb-2 font-semibold text-zinc-900">Allocation summary</h3>
          <dl className="grid grid-cols-[10rem_1fr] gap-y-1 text-zinc-700">
            <dt className="text-zinc-500">Org location</dt>
            <dd>
              {name(orgUnit)} ({levelLabel(levels, locale, orgUnit.level_id, orgUnit.level_code)})
            </dd>
            <dt className="text-zinc-500">Department</dt>
            <dd>{name(department)}</dd>
            <dt className="text-zinc-500">Position unit</dt>
            <dd>
              {name(posUnit)} ({levelLabel(levels, locale, posUnit.level_id, posUnit.level_code)})
            </dd>
            <dt className="text-zinc-500">Job position</dt>
            <dd>{name(job)}</dd>
            <dt className="text-zinc-500">Approved headcount</dt>
            <dd>{headcountIsValid ? headcount : "-"}</dd>
            <dt className="text-zinc-500">Start date</dt>
            <dd>{startDateIsValid ? startDate : "-"}</dd>
          </dl>

          <div className="mt-3 space-y-1 text-xs">
            {existingForCurrent === null && (
              <p className="text-zinc-500">Checking for an existing allocation...</p>
            )}
            {existingForCurrent?.error && (
              <p className="text-red-700">{existingForCurrent.error}</p>
            )}
            {existingForCurrent && !existingForCurrent.error && existingForCurrent.headcount === null && (
              <p className="text-emerald-700">
                No open allocation exists for this combination.
              </p>
            )}
            {isDuplicate && (
              <p className="text-amber-800">
                An open allocation already exists with headcount{" "}
                {existingForCurrent?.headcount}. To change it, use the Headcount tab.
              </p>
            )}
          </div>

          {permission.isLoading && (
            <p className="mt-3 text-xs text-zinc-500">Checking your permission...</p>
          )}
          {!permission.isLoading && !canWrite && (
            <p role="status" className="mt-3 text-xs text-amber-800">
              You do not have permission to manage allocations for this org unit and
              Department.
            </p>
          )}

          <button
            type="button"
            onClick={handleSave}
            disabled={!canSave || isSaving}
            className="mt-4 rounded-md bg-zinc-900 px-4 py-2 text-sm font-medium text-white hover:bg-zinc-800 disabled:cursor-not-allowed disabled:bg-zinc-300 disabled:text-zinc-600"
          >
            {isSaving ? "Saving..." : "Save allocation"}
          </button>

          {saveError && (
            <p role="alert" className="mt-2 text-xs text-red-700">
              {saveError}
            </p>
          )}
        </div>
      )}
    </section>
  );
}
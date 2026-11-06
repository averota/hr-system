// modules/org/components/AllocationActionDialog.tsx
"use client";

import { useState } from "react";
import { isIsoDate, todayInPhnomPenh } from "@/lib/dates";
import { displayName, type Locale } from "@/lib/i18n";
import {
  MAX_HEADCOUNT,
  changeAllocationHeadcount,
  closeAllocation,
} from "@/modules/org/queries";
import type { PositionAllocation } from "@/modules/org/types";
import { selectClassName } from "./AsyncSelect";

export type AllocationAction = "change" | "close";

interface AllocationActionDialogProps {
  companyId: number;
  allocation: PositionAllocation;
  action: AllocationAction;
  locale: Locale;
  onCancel: () => void;
  /** Called after a successful save with a message to show the user. */
  onDone: (message: string) => void;
}

/** Modal to change the headcount of one allocation, or to close it. */
export function AllocationActionDialog({
  companyId,
  allocation,
  action,
  locale,
  onCancel,
  onDone,
}: AllocationActionDialogProps) {
  const [date, setDate] = useState(() => todayInPhnomPenh());
  const [headcount, setHeadcount] = useState(String(allocation.approved_headcount));
  const [isSaving, setIsSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const jobName = displayName(locale, allocation.job_name_en, allocation.job_name_km);
  const orgName = displayName(
    locale,
    allocation.org_unit_name_en,
    allocation.org_unit_name_km
  );
  const posName = displayName(
    locale,
    allocation.pos_unit_name_en,
    allocation.pos_unit_name_km
  );

  const dateIsValid = isIsoDate(date);
  const headcountIsValid =
    /^\d+$/.test(headcount) && Number(headcount) <= MAX_HEADCOUNT;
  const headcountChanged = Number(headcount) !== allocation.approved_headcount;

  const canSubmit =
    dateIsValid && (action === "close" || (headcountIsValid && headcountChanged));

  async function handleSubmit() {
    if (!canSubmit) return;
    setIsSaving(true);
    setError(null);
    try {
      if (action === "change") {
        await changeAllocationHeadcount(
          companyId,
          allocation.allocation_id,
          Number(headcount),
          date
        );
        onDone(
          `Headcount for ${jobName} at ${orgName} changed from ${allocation.approved_headcount} to ${headcount}.`
        );
      } else {
        await closeAllocation(companyId, allocation.allocation_id, date);
        onDone(`Allocation for ${jobName} at ${orgName} closed.`);
      }
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "Save failed");
      setIsSaving(false);
    }
  }

  const title = action === "change" ? "Change approved headcount" : "Close allocation";

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4"
      role="dialog"
      aria-modal="true"
      aria-labelledby="allocation-dialog-title"
    >
      <div className="w-full max-w-md rounded-lg bg-white p-5 shadow-lg">
        <h3 id="allocation-dialog-title" className="text-base font-semibold text-zinc-900">
          {title}
        </h3>

        <dl className="mt-3 grid grid-cols-[7rem_1fr] gap-y-1 text-sm text-zinc-700">
          <dt className="text-zinc-500">Org unit</dt>
          <dd>{orgName}</dd>
          <dt className="text-zinc-500">Position unit</dt>
          <dd>{posName}</dd>
          <dt className="text-zinc-500">Job position</dt>
          <dd>{jobName}</dd>
          <dt className="text-zinc-500">Headcount</dt>
          <dd>{allocation.approved_headcount}</dd>
        </dl>

        {action === "change" ? (
          <>
            <p className="mt-3 text-xs text-zinc-500">
              The current allocation is closed and a new one starts on the date below.
            </p>
            <label
              htmlFor="dialog-headcount"
              className="mb-1 mt-3 block text-xs font-medium text-zinc-600"
            >
              New approved headcount
            </label>
            <input
              id="dialog-headcount"
              type="text"
              inputMode="numeric"
              value={headcount}
              onChange={(e) => {
                setError(null);
                setHeadcount(e.target.value.trim());
              }}
              className={selectClassName}
            />
            {headcount !== "" && !headcountIsValid && (
              <p className="mt-1 text-xs text-red-700">
                Enter a whole number from 0 to {MAX_HEADCOUNT}.
              </p>
            )}
            {headcountIsValid && !headcountChanged && (
              <p className="mt-1 text-xs text-amber-800">
                The new headcount is the same as the current headcount.
              </p>
            )}
          </>
        ) : (
          <p className="mt-3 text-xs text-zinc-500">
            Only this allocation is closed. The org unit, Department listing, job and
            position unit are not changed.
          </p>
        )}

        <label
          htmlFor="dialog-date"
          className="mb-1 mt-3 block text-xs font-medium text-zinc-600"
        >
          {action === "change" ? "Effective date" : "Close date"}
        </label>
        <input
          id="dialog-date"
          type="date"
          value={date}
          onChange={(e) => {
            setError(null);
            setDate(e.target.value);
          }}
          className={selectClassName}
        />

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
            {isSaving ? "Saving..." : action === "change" ? "Save change" : "Close allocation"}
          </button>
        </div>
      </div>
    </div>
  );
}
// modules/org/components/ListingDialog.tsx
"use client";

import { useState } from "react";
import { isIsoDate, todayInPhnomPenh } from "@/lib/dates";
import { displayName, type Locale } from "@/lib/i18n";
import { addListing, removeListing } from "@/modules/org/queries";
import type { UnitRow } from "@/modules/org/types";
import { selectClassName } from "./AsyncSelect";
import { Modal } from "./Modal";

export type ListingAction = "add" | "remove";

interface ListingDialogProps {
  action: ListingAction;
  companyId: number;
  locale: Locale;
  orgUnit: UnitRow;
  /** Departments that can still be added to this org unit (used by "add"). */
  availableDepartments: UnitRow[];
  /** The listed Department to remove (used by "remove"). */
  department: UnitRow | null;
  /** Open allocations that use this listing (shown when removing). */
  allocationCount: number;
  onCancel: () => void;
  /** Called after a successful save with a message to show the user. */
  onDone: (message: string) => void;
}

/** Modal to list a Department for an org unit, or to remove a listing. */
export function ListingDialog({
  action,
  companyId,
  locale,
  orgUnit,
  availableDepartments,
  department,
  allocationCount,
  onCancel,
  onDone,
}: ListingDialogProps) {
  const [departmentId, setDepartmentId] = useState("");
  const [date, setDate] = useState(() => todayInPhnomPenh());
  const [isSaving, setIsSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const orgName = displayName(locale, orgUnit.name_en, orgUnit.name_km);
  const deptName = department
    ? displayName(locale, department.name_en, department.name_km)
    : "";
  const dateIsValid = isIsoDate(date);

  // The database refuses a removal while allocations use the listing, so block it here too.
  const canSubmit =
    dateIsValid &&
    (action === "add" ? departmentId !== "" : department !== null && allocationCount === 0);

  async function handleSubmit() {
    if (!canSubmit) return;
    setIsSaving(true);
    setError(null);
    try {
      if (action === "add") {
        const chosen = availableDepartments.find((d) => String(d.unit_id) === departmentId);
        await addListing(companyId, orgUnit.unit_id, Number(departmentId), date);
        onDone(
          `Listed ${chosen ? displayName(locale, chosen.name_en, chosen.name_km) : "Department"} for ${orgName}.`
        );
      } else if (department) {
        await removeListing(companyId, orgUnit.unit_id, department.unit_id, date);
        onDone(`Removed ${deptName} from ${orgName}.`);
      }
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "Save failed");
      setIsSaving(false);
    }
  }

  return (
    <Modal
      title={action === "add" ? "List a Department" : "Remove Department listing"}
      submitLabel={action === "add" ? "List Department" : "Remove listing"}
      canSubmit={canSubmit}
      isSaving={isSaving}
      error={error}
      onSubmit={handleSubmit}
      onCancel={onCancel}
    >
      <p className="mt-2 text-sm text-zinc-700">{orgName}</p>

      {action === "add" ? (
        <>
          {availableDepartments.length === 0 ? (
            <p className="mt-3 rounded-md bg-amber-50 px-3 py-2 text-xs text-amber-800">
              Every open Department is already listed for this org unit.
            </p>
          ) : (
            <>
              <label
                htmlFor="listing-department"
                className="mb-1 mt-3 block text-xs font-medium text-zinc-600"
              >
                Department
              </label>
              <select
                id="listing-department"
                value={departmentId}
                onChange={(e) => {
                  setError(null);
                  setDepartmentId(e.target.value);
                }}
                className={selectClassName}
              >
                <option value="">Select Department</option>
                {availableDepartments.map((d) => (
                  <option key={d.unit_id} value={d.unit_id}>
                    {displayName(locale, d.name_en, d.name_km)}
                  </option>
                ))}
              </select>
            </>
          )}
          <p className="mt-2 text-xs text-zinc-500">
            Listings are not inherited. Child org units need their own listing.
          </p>
        </>
      ) : (
        <>
          <p className="mt-1 text-sm text-zinc-700">{deptName}</p>
          {allocationCount > 0 ? (
            <p className="mt-3 rounded-md bg-amber-50 px-3 py-2 text-xs text-amber-800">
              {allocationCount} open allocation(s) still use this Department at this org
              unit. Close them on the Headcount tab first.
            </p>
          ) : (
            <p className="mt-3 text-xs text-zinc-500">
              No open allocations use this listing.
            </p>
          )}
        </>
      )}

      <label
        htmlFor="listing-date"
        className="mb-1 mt-3 block text-xs font-medium text-zinc-600"
      >
        {action === "add" ? "Start date" : "Close date"}
      </label>
      <input
        id="listing-date"
        type="date"
        value={date}
        onChange={(e) => {
          setError(null);
          setDate(e.target.value);
        }}
        className={selectClassName}
      />
    </Modal>
  );
}
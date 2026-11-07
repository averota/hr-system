// modules/org/components/AsOfListings.tsx
"use client";

import { useMemo, useState } from "react";
import { todayInPhnomPenh } from "@/lib/dates";
import { displayName, type Locale } from "@/lib/i18n";
import { fetchListingsAsOf, fetchUnitsAsOf } from "@/modules/org/queriesHistory";
import { useAsOfLoad } from "@/modules/org/useAsOfLoad";
import { AsOfDatePicker } from "./AsOfDatePicker";

interface AsOfListingsProps {
  companyId: number;
  locale: Locale;
}

/** Read-only Department listings as they stood on a chosen date. */
export function AsOfListings({ companyId, locale }: AsOfListingsProps) {
  const [asOf, setAsOf] = useState<string>(() => todayInPhnomPenh());

  const load = useMemo(
    () =>
      asOf
        ? () =>
            Promise.all([
              fetchListingsAsOf(companyId, asOf),
              fetchUnitsAsOf("org", companyId, asOf),
              fetchUnitsAsOf("pos", companyId, asOf),
            ])
        : null,
    [companyId, asOf]
  );
  const { data, error, isLoading } = useAsOfLoad(load);

  const rows = useMemo(() => {
    if (!data) return [];
    const [listings, orgUnits, posUnits] = data;

    const departmentName = new Map(
      posUnits.map((u) => [u.unit_id, displayName(locale, u.name_en, u.name_km)])
    );
    const listedByOrgUnit = new Map<number, string[]>();
    for (const l of listings) {
      const list = listedByOrgUnit.get(l.org_unit_id) ?? [];
      list.push(departmentName.get(l.department_id) ?? `#${l.department_id}`);
      listedByOrgUnit.set(l.org_unit_id, list);
    }

    return [...orgUnits]
      .sort((a, b) => a.level_rank - b.level_rank || a.name_en.localeCompare(b.name_en))
      .map((u) => ({
        unit: u,
        departments: (listedByOrgUnit.get(u.unit_id) ?? []).sort((a, b) =>
          a.localeCompare(b)
        ),
      }));
  }, [data, locale]);

  return (
    <div className="space-y-4">
      <AsOfDatePicker
        id="as-of-listings"
        value={asOf}
        onChange={setAsOf}
        note="Shows which Departments each org unit could use on this day. Names are the current names."
      />

      {!asOf ? (
        <p className="text-sm text-zinc-600">Pick a date to see the listings.</p>
      ) : isLoading ? (
        <p className="text-sm text-zinc-600">Loading...</p>
      ) : error ? (
        <p role="alert" className="text-sm text-red-700">
          {error}
        </p>
      ) : (
        <div className="rounded-lg border border-zinc-200 bg-white p-4">
          <h2 className="mb-3 text-sm font-semibold text-zinc-900">
            Department listings as of {asOf}
          </h2>

          {rows.length === 0 ? (
            <p className="text-sm text-zinc-600">No org units existed on this date.</p>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-left text-sm">
                <thead className="border-b border-zinc-200 text-xs text-zinc-500">
                  <tr>
                    <th className="py-2 pr-3 font-medium">Org unit</th>
                    <th className="py-2 pr-3 font-medium">Level</th>
                    <th className="py-2 font-medium">Listed Departments</th>
                  </tr>
                </thead>
                <tbody>
                  {rows.map(({ unit, departments }) => (
                    <tr key={unit.unit_id} className="border-b border-zinc-100">
                      <td className="py-2 pr-3">
                        {displayName(locale, unit.name_en, unit.name_km)}
                      </td>
                      <td className="py-2 pr-3 text-zinc-600">
                        {displayName(locale, unit.level_name_en, unit.level_name_km)}
                      </td>
                      <td className="py-2">
                        {departments.length === 0 ? (
                          <span className="text-zinc-400">None</span>
                        ) : (
                          departments.join(", ")
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
// modules/org/components/AsOfHeadcount.tsx
"use client";

import { useMemo, useState } from "react";
import { todayInPhnomPenh } from "@/lib/dates";
import { displayName, type Locale } from "@/lib/i18n";
import { fetchAllocationsAsOf } from "@/modules/org/queriesHistory";
import { useAsOfLoad } from "@/modules/org/useAsOfLoad";
import { AsOfDatePicker } from "./AsOfDatePicker";

interface AsOfHeadcountProps {
  companyId: number;
  locale: Locale;
}

/** Read-only approved headcount as it stood on a chosen date. */
export function AsOfHeadcount({ companyId, locale }: AsOfHeadcountProps) {
  const [asOf, setAsOf] = useState<string>(() => todayInPhnomPenh());
  const [search, setSearch] = useState("");

  const load = useMemo(
    () => (asOf ? () => fetchAllocationsAsOf(companyId, asOf) : null),
    [companyId, asOf]
  );
  const { data, error, isLoading } = useAsOfLoad(load);

  const rows = useMemo(() => {
    const all = data ?? [];
    const q = search.trim().toLowerCase();
    if (!q) return all;
    return all.filter((r) =>
      [
        r.org_unit_name_en,
        r.org_unit_name_km,
        r.department_name_en,
        r.department_name_km,
        r.pos_unit_name_en,
        r.pos_unit_name_km,
        r.job_name_en,
        r.job_name_km,
      ]
        .filter((v): v is string => !!v)
        .some((v) => v.toLowerCase().includes(q))
    );
  }, [data, search]);

  const total = rows.reduce((sum, r) => sum + r.approved_headcount, 0);

  return (
    <div className="space-y-4">
      <AsOfDatePicker
        id="as-of-headcount"
        value={asOf}
        onChange={setAsOf}
        note="Shows the approved headcount valid on this day. A headcount changed on this day shows the new number. Names are the current names."
      />

      {!asOf ? (
        <p className="text-sm text-zinc-600">Pick a date to see the headcount.</p>
      ) : isLoading ? (
        <p className="text-sm text-zinc-600">Loading...</p>
      ) : error ? (
        <p role="alert" className="text-sm text-red-700">
          {error}
        </p>
      ) : (
        <div className="rounded-lg border border-zinc-200 bg-white p-4">
          <div className="mb-3 flex flex-wrap items-center justify-between gap-3">
            <h2 className="text-sm font-semibold text-zinc-900">
              Headcount as of {asOf}
            </h2>
            <input
              type="search"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search org unit, Department, position or job"
              aria-label="Search headcount"
              className="w-72 rounded-md border border-zinc-300 px-2.5 py-1.5 text-sm focus:border-zinc-900 focus:outline-none"
            />
          </div>

          {rows.length === 0 ? (
            <p className="text-sm text-zinc-600">
              {(data ?? []).length === 0
                ? "No allocations existed on this date."
                : "No allocations match the search."}
            </p>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-left text-sm">
                <thead className="border-b border-zinc-200 text-xs text-zinc-500">
                  <tr>
                    <th className="py-2 pr-3 font-medium">Org unit</th>
                    <th className="py-2 pr-3 font-medium">Department</th>
                    <th className="py-2 pr-3 font-medium">Position unit</th>
                    <th className="py-2 pr-3 font-medium">Job</th>
                    <th className="py-2 pr-3 text-right font-medium">Headcount</th>
                    <th className="py-2 pr-3 font-medium">Started</th>
                    <th className="py-2 font-medium">Ends</th>
                  </tr>
                </thead>
                <tbody>
                  {rows.map((r) => (
                    <tr key={r.allocation_id} className="border-b border-zinc-100">
                      <td className="py-2 pr-3">
                        {displayName(locale, r.org_unit_name_en, r.org_unit_name_km)}
                      </td>
                      <td className="py-2 pr-3">
                        {displayName(locale, r.department_name_en, r.department_name_km)}
                      </td>
                      <td className="py-2 pr-3">
                        {displayName(locale, r.pos_unit_name_en, r.pos_unit_name_km)}
                      </td>
                      <td className="py-2 pr-3">
                        {displayName(locale, r.job_name_en, r.job_name_km)}
                      </td>
                      <td className="py-2 pr-3 text-right tabular-nums">
                        {r.approved_headcount}
                      </td>
                      <td className="py-2 pr-3 tabular-nums">{r.valid_from}</td>
                      <td className="py-2 tabular-nums">{r.valid_to ?? "Open"}</td>
                    </tr>
                  ))}
                </tbody>
                <tfoot>
                  <tr>
                    <td colSpan={4} className="pt-2 pr-3 text-xs text-zinc-500">
                      Showing {rows.length} of {(data ?? []).length}
                    </td>
                    <td className="pt-2 pr-3 text-right font-semibold tabular-nums">
                      {total}
                    </td>
                    <td colSpan={2} />
                  </tr>
                </tfoot>
              </table>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
// modules/org/components/UnitMoves.tsx
"use client";

import { useMemo, useState } from "react";
import { displayName, type Locale } from "@/lib/i18n";
import { fetchUnitMoves } from "@/modules/org/queriesHistory";
import type { TreeKind } from "@/modules/org/types";
import { useAsOfLoad } from "@/modules/org/useAsOfLoad";
import { RowLimitWarning } from "./RowLimitWarning";

interface UnitMovesProps {
  tree: TreeKind;
  companyId: number;
  locale: Locale;
}

/** Reorg history: where units used to sit before they were moved. Read-only. */
export function UnitMoves({ tree, companyId, locale }: UnitMovesProps) {
  const [search, setSearch] = useState("");

  const load = useMemo(() => () => fetchUnitMoves(tree, companyId), [tree, companyId]);
  const { data, error, isLoading } = useAsOfLoad(load);

  const rows = useMemo(() => {
    const all = data?.rows ?? [];
    const q = search.trim().toLowerCase();
    if (!q) return all;
    return all.filter((r) =>
      [r.name_en, r.name_km, r.parent_name_en, r.parent_name_km]
        .filter((v): v is string => !!v)
        .some((v) => v.toLowerCase().includes(q))
    );
  }, [data, search]);

  const noParentLabel = tree === "org" ? "Directly under the company" : "Top level";

  if (isLoading) return <p className="text-sm text-zinc-600">Loading...</p>;
  if (error) {
    return (
      <p role="alert" className="text-sm text-red-700">
        {error}
      </p>
    );
  }

  return (
    <div className="rounded-lg border border-zinc-200 bg-white p-4">
      {data?.limitReached && <RowLimitWarning what="past parent links" className="mb-3" />}
      <div className="mb-3 flex flex-wrap items-center justify-between gap-3">
        <div>
          <h2 className="text-sm font-semibold text-zinc-900">
            {tree === "org" ? "Org unit moves" : "Position unit moves"}
          </h2>
          <p className="text-xs text-zinc-500">
            Each row is a place a unit used to sit. It moved on the date shown (the new
            parent applies from that day). Names are the current names.
          </p>
        </div>
        <input
          type="search"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Search unit or previous parent"
          aria-label="Search moves"
          className="w-64 rounded-md border border-zinc-300 px-2.5 py-1.5 text-sm focus:border-zinc-900 focus:outline-none"
        />
      </div>

      {rows.length === 0 ? (
        <p className="text-sm text-zinc-600">
          {(data?.rows ?? []).length === 0
            ? "No unit has been moved yet."
            : "No moves match the search."}
        </p>
      ) : (
        <div className="overflow-x-auto">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-zinc-200 text-xs text-zinc-500">
              <tr>
                <th className="py-2 pr-3 font-medium">Unit</th>
                <th className="py-2 pr-3 font-medium">Level</th>
                <th className="py-2 pr-3 font-medium">Previous parent</th>
                <th className="py-2 pr-3 font-medium">Under it from</th>
                <th className="py-2 font-medium">Moved on</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((r) => (
                <tr key={r.link_id} className="border-b border-zinc-100">
                  <td className="py-2 pr-3">{displayName(locale, r.name_en, r.name_km)}</td>
                  <td className="py-2 pr-3 text-zinc-600">
                    {displayName(locale, r.level_name_en, r.level_name_km)}
                  </td>
                  <td className="py-2 pr-3">
                    {r.parent_name_en
                      ? displayName(locale, r.parent_name_en, r.parent_name_km)
                      : noParentLabel}
                  </td>
                  <td className="py-2 pr-3 tabular-nums">{r.valid_from}</td>
                  <td className="py-2 tabular-nums">{r.valid_to}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
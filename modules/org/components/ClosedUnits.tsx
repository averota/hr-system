// modules/org/components/ClosedUnits.tsx
"use client";

import { useEffect, useMemo, useState } from "react";
import { displayName, type Locale } from "@/lib/i18n";
import { ROOT_LABEL } from "@/modules/org/labels";
import { fetchClosedUnits } from "@/modules/org/queries";
import type { ClosedUnitRow, TreeKind } from "@/modules/org/types";
import { selectClassName } from "./AsyncSelect";

interface ClosedUnitsProps {
  tree: TreeKind;
  companyId: number;
  locale: Locale;
}

const COPY: Record<TreeKind, { title: string; description: string; empty: string }> = {
  org: {
    title: "Closed Org Units",
    description:
      "Org units that were closed, with the parent they had when they closed. Newest closed first.",
    empty: "No org units have been closed for this company.",
  },
  pos: {
    title: "Closed Position Units",
    description:
      "Departments, Offices, Sections and Groups that were closed, with the parent they had when they closed. Newest closed first.",
    empty: "No Departments or position units have been closed for this company.",
  },
};

/**
 * Read-only list of closed units of one tree.
 * Give it a `key` that includes the tree and the company id.
 */
export function ClosedUnits({ tree, companyId, locale }: ClosedUnitsProps) {
  const [rows, setRows] = useState<ClosedUnitRow[] | null>(null);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [search, setSearch] = useState("");

  useEffect(() => {
    let cancelled = false;
    fetchClosedUnits(tree, companyId)
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
  }, [tree, companyId]);

  const shown = useMemo(() => {
    const q = search.trim().toLowerCase();
    if (q === "") return rows ?? [];
    return (rows ?? []).filter((r) => `${r.name_en} ${r.name_km ?? ""}`.toLowerCase().includes(q));
  }, [rows, search]);

  const copy = COPY[tree];

  return (
    <section className="rounded-lg border border-zinc-200 bg-white shadow-sm">
      <div className="border-b border-zinc-200 px-4 py-3">
        <h2 className="text-base font-semibold text-zinc-900">{copy.title}</h2>
        <p className="mt-0.5 text-sm text-zinc-600">{copy.description}</p>
      </div>

      {loadError ? (
        <p className="m-4 rounded-md bg-red-50 px-3 py-2 text-sm text-red-700">{loadError}</p>
      ) : rows === null ? (
        <p className="m-4 text-sm text-zinc-500">Loading...</p>
      ) : rows.length === 0 ? (
        <p className="m-4 rounded-md bg-zinc-100 px-3 py-2 text-sm text-zinc-700">{copy.empty}</p>
      ) : (
        <>
          <div className="grid gap-3 border-b border-zinc-200 p-4 sm:grid-cols-3">
            <div>
              <label
                htmlFor={`closed-search-${tree}`}
                className="mb-1 block text-xs font-medium text-zinc-600"
              >
                Search
              </label>
              <input
                id={`closed-search-${tree}`}
                type="search"
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                placeholder="Name..."
                className={selectClassName}
              />
            </div>
            <div className="flex items-end text-xs text-zinc-600 sm:col-span-2">
              Showing {shown.length} of {rows.length} closed units
            </div>
          </div>

          {shown.length === 0 ? (
            <p className="m-4 rounded-md bg-zinc-100 px-3 py-2 text-sm text-zinc-700">
              No closed units match the search.
            </p>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-left text-sm">
                <thead className="border-b border-zinc-200 bg-zinc-50 text-xs uppercase text-zinc-600">
                  <tr>
                    <th className="px-4 py-2.5">Name</th>
                    <th className="px-4 py-2.5">Level</th>
                    <th className="px-4 py-2.5">Was under</th>
                    <th className="px-4 py-2.5">Started</th>
                    <th className="px-4 py-2.5">Closed</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-zinc-200">
                  {shown.map((r) => (
                    <tr key={r.unit_id} className="align-top">
                      <td className="px-4 py-3 font-medium text-zinc-900">
                        {displayName(locale, r.name_en, r.name_km)}
                      </td>
                      <td className="px-4 py-3">
                        <span className="inline-block rounded bg-zinc-100 px-1.5 py-0.5 text-xs text-zinc-700">
                          {displayName(locale, r.level_name_en, r.level_name_km)}
                        </span>
                      </td>
                      <td className="px-4 py-3 text-zinc-700">
                        {r.parent_unit_id === null
                          ? ROOT_LABEL[tree]
                          : displayName(locale, r.parent_name_en ?? "", r.parent_name_km)}
                      </td>
                      <td className="whitespace-nowrap px-4 py-3 text-xs text-zinc-500">
                        {r.valid_from}
                      </td>
                      <td className="whitespace-nowrap px-4 py-3 text-xs text-zinc-500">
                        {r.valid_to}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </>
      )}
    </section>
  );
}
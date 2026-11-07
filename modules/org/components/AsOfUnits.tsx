// modules/org/components/AsOfUnits.tsx
"use client";

import { useEffect, useState } from "react";
import { todayInPhnomPenh } from "@/lib/dates";
import type { Locale } from "@/lib/i18n";
import { fetchUnitsAsOf } from "@/modules/org/queriesHistory";
import type { TreeKind, UnitRow } from "@/modules/org/types";
import { OrgTreeExplorer } from "./OrgTreeExplorer";

interface AsOfUnitsProps {
  tree: TreeKind;
  companyId: number;
  locale: Locale;
}

interface Result {
  key: string;
  units: UnitRow[];
  error: string | null;
}

/** Read-only tree as it stood on a chosen date. */
export function AsOfUnits({ tree, companyId, locale }: AsOfUnitsProps) {
  const [asOf, setAsOf] = useState<string>(() => todayInPhnomPenh());
  const [result, setResult] = useState<Result | null>(null);

  const key = `${tree}-${companyId}-${asOf}`;

  useEffect(() => {
    if (!asOf) return;
    let cancelled = false;
    fetchUnitsAsOf(tree, companyId, asOf)
      .then((units) => {
        if (!cancelled) setResult({ key, units, error: null });
      })
      .catch((e: unknown) => {
        if (!cancelled) {
          setResult({
            key,
            units: [],
            error: e instanceof Error ? e.message : "Could not load the structure.",
          });
        }
      });
    return () => {
      cancelled = true;
    };
  }, [key, tree, companyId, asOf]);

  const isLoading = asOf !== "" && result?.key !== key;
  const current = result?.key === key ? result : null;
  const title = tree === "org" ? "Organization Tree" : "Position Tree";

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center gap-3 rounded-lg border border-zinc-200 bg-white p-4">
        <label htmlFor={`as-of-${tree}`} className="text-sm font-medium text-zinc-700">
          As of date
        </label>
        <input
          id={`as-of-${tree}`}
          type="date"
          value={asOf}
          onChange={(e) => setAsOf(e.target.value)}
          className="rounded-md border border-zinc-300 bg-white px-2.5 py-1.5 text-sm text-zinc-900 focus:border-zinc-900 focus:outline-none"
        />
        <p className="text-xs text-zinc-500">
          Shows the structure as it stood on this day (a unit closed on this day still
          shows). Names are the current names.
        </p>
      </div>

      {!asOf ? (
        <p className="text-sm text-zinc-600">Pick a date to see the structure.</p>
      ) : isLoading ? (
        <p className="text-sm text-zinc-600">Loading...</p>
      ) : current?.error ? (
        <p role="alert" className="text-sm text-red-700">
          {current.error}
        </p>
      ) : (
        <OrgTreeExplorer
          key={key}
          title={`${title} as of ${asOf}`}
          description="Read-only view of the units valid on the chosen date."
          emptyText="No units existed on this date."
          units={current?.units ?? []}
          locale={locale}
        />
      )}
    </div>
  );
}
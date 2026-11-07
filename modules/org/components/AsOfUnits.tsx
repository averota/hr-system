// modules/org/components/AsOfUnits.tsx
"use client";

import { useMemo, useState } from "react";
import { todayInPhnomPenh } from "@/lib/dates";
import type { Locale } from "@/lib/i18n";
import { fetchUnitsAsOf } from "@/modules/org/queriesHistory";
import type { TreeKind } from "@/modules/org/types";
import { useAsOfLoad } from "@/modules/org/useAsOfLoad";
import { AsOfDatePicker } from "./AsOfDatePicker";
import { OrgTreeExplorer } from "./OrgTreeExplorer";

interface AsOfUnitsProps {
  tree: TreeKind;
  companyId: number;
  locale: Locale;
}

/** Read-only tree as it stood on a chosen date. */
export function AsOfUnits({ tree, companyId, locale }: AsOfUnitsProps) {
  const [asOf, setAsOf] = useState<string>(() => todayInPhnomPenh());

  const load = useMemo(
    () => (asOf ? () => fetchUnitsAsOf(tree, companyId, asOf) : null),
    [tree, companyId, asOf]
  );
  const { data, error, isLoading } = useAsOfLoad(load);

  const title = tree === "org" ? "Organization Tree" : "Position Tree";

  return (
    <div className="space-y-4">
      <AsOfDatePicker
        id={`as-of-${tree}`}
        value={asOf}
        onChange={setAsOf}
        note="Shows the structure as it stood on this day (a unit closed on this day still shows). Names are the current names."
      />

      {!asOf ? (
        <p className="text-sm text-zinc-600">Pick a date to see the structure.</p>
      ) : isLoading ? (
        <p className="text-sm text-zinc-600">Loading...</p>
      ) : error ? (
        <p role="alert" className="text-sm text-red-700">
          {error}
        </p>
      ) : (
        <OrgTreeExplorer
          key={`${tree}-${companyId}-${asOf}`}
          title={`${title} as of ${asOf}`}
          description="Read-only view of the units valid on the chosen date."
          emptyText="No units existed on this date."
          units={data ?? []}
          locale={locale}
        />
      )}
    </div>
  );
}
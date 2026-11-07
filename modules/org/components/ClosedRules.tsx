// modules/org/components/ClosedRules.tsx
"use client";

import { useEffect, useState } from "react";
import { displayName, type Locale } from "@/lib/i18n";
import { ROOT_LABEL } from "@/modules/org/labels";
import { fetchClosedRules } from "@/modules/org/queries";
import type { ClosedRuleRow, TreeKind } from "@/modules/org/types";
import { RowLimitWarning } from "./RowLimitWarning";

interface ClosedRulesProps {
  companyId: number;
  locale: Locale;
}

const TREES: { tree: TreeKind; title: string }[] = [
  { tree: "org", title: "Closed rules: Organization Structure Levels (org)" },
  { tree: "pos", title: "Closed rules: Position Structure Levels (pos)" },
];

/**
 * Read-only list of closed level rules, newest closed first.
 * Give it a `key` that includes the company id.
 */
export function ClosedRules({ companyId, locale }: ClosedRulesProps) {
  const [rows, setRows] = useState<ClosedRuleRow[] | null>(null);
  const [limitReached, setLimitReached] = useState(false);
  const [loadError, setLoadError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    fetchClosedRules(companyId)
      .then((data) => {
        if (cancelled) return;
        setRows(data.rows);
        setLimitReached(data.limitReached);
        setLoadError(null);
      })
      .catch((e: unknown) => {
        if (!cancelled) setLoadError(e instanceof Error ? e.message : "Load failed");
      });
    return () => {
      cancelled = true;
    };
  }, [companyId]);

  return (
    <>
      <div>
        <h1 className="text-lg font-semibold text-zinc-900">Closed Hierarchy Rules</h1>
        <p className="mt-0.5 text-sm text-zinc-600">
          Rules that were disabled. Units created under them keep their place. Newest closed
          first.
        </p>
      </div>

      {limitReached && <RowLimitWarning what="closed rules" className="" />}

      {loadError ? (
        <p className="rounded-md bg-red-50 px-3 py-2 text-sm text-red-700">{loadError}</p>
      ) : rows === null ? (
        <p className="text-sm text-zinc-500">Loading...</p>
      ) : (
        <div className="grid gap-6 lg:grid-cols-2">
          {TREES.map(({ tree, title }) => {
            const treeRows = rows.filter((r) => r.tree === tree);
            return (
              <section
                key={tree}
                className="rounded-lg border border-zinc-200 bg-white shadow-sm"
              >
                <div className="border-b border-zinc-200 px-4 py-3">
                  <h2 className="text-base font-semibold text-zinc-900">{title}</h2>
                </div>
                {treeRows.length === 0 ? (
                  <p className="m-4 rounded-md bg-zinc-100 px-3 py-2 text-sm text-zinc-700">
                    No closed rules yet.
                  </p>
                ) : (
                  <div className="overflow-x-auto">
                    <table className="w-full text-left text-sm">
                      <thead className="border-b border-zinc-200 bg-zinc-50 text-xs uppercase text-zinc-600">
                        <tr>
                          <th className="px-4 py-2.5">Level</th>
                          <th className="px-4 py-2.5">Was allowed</th>
                          <th className="px-4 py-2.5">Started</th>
                          <th className="px-4 py-2.5">Closed</th>
                        </tr>
                      </thead>
                      <tbody className="divide-y divide-zinc-200">
                        {treeRows.map((r) => (
                          <tr key={r.rule_id} className="align-top">
                            <td className="px-4 py-3 font-medium text-zinc-900">
                              {displayName(locale, r.level_name_en, r.level_name_km)}
                            </td>
                            <td className="px-4 py-3 text-zinc-700">
                              {r.parent_level_id === null
                                ? ROOT_LABEL[tree]
                                : `Under ${displayName(
                                    locale,
                                    r.parent_level_name_en ?? "",
                                    r.parent_level_name_km
                                  )}`}
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
              </section>
            );
          })}
        </div>
      )}
    </>
  );
}
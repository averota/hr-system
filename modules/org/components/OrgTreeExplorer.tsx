// modules/org/components/OrgTreeExplorer.tsx
"use client";

import { useMemo, useState } from "react";
import { displayName, type Locale } from "@/lib/i18n";
import type { UnitRow } from "@/modules/org/types";

interface OrgTreeExplorerProps {
  title: string;
  description: string;
  emptyText: string;
  units: UnitRow[];
  locale: Locale;
}

interface TreeNodeProps {
  unit: UnitRow;
  childrenOf: Map<number | null, UnitRow[]>;
  expanded: Set<number>;
  onToggle: (id: number) => void;
  locale: Locale;
}

function TreeNode({ unit, childrenOf, expanded, onToggle, locale }: TreeNodeProps) {
  const kids = childrenOf.get(unit.unit_id) ?? [];
  const isOpen = expanded.has(unit.unit_id);

  return (
    <li>
      <div className="flex flex-wrap items-center gap-2 py-1">
        {kids.length > 0 ? (
          <button
            type="button"
            aria-expanded={isOpen}
            onClick={() => onToggle(unit.unit_id)}
            className="w-5 text-zinc-500 hover:text-zinc-900"
          >
            {isOpen ? "▾" : "▸"}
          </button>
        ) : (
          <span className="inline-block w-5" />
        )}
        <span className="text-sm font-medium text-zinc-900">
          {displayName(locale, unit.name_en, unit.name_km)}
        </span>
        <span className="rounded bg-zinc-100 px-1.5 py-0.5 text-xs text-zinc-700">
          {displayName(locale, unit.level_name_en, unit.level_name_km)}
        </span>
        {kids.length > 0 && (
          <span className="text-xs text-zinc-400">{kids.length} under</span>
        )}
        <span className="text-xs text-zinc-400">since {unit.valid_from}</span>
      </div>
      {kids.length > 0 && isOpen && (
        <ul className="ml-2.5 border-l border-zinc-200 pl-3">
          {kids.map((kid) => (
            <TreeNode
              key={kid.unit_id}
              unit={kid}
              childrenOf={childrenOf}
              expanded={expanded}
              onToggle={onToggle}
              locale={locale}
            />
          ))}
        </ul>
      )}
    </li>
  );
}

/**
 * Read-only expandable tree of open units. Works for both the org tree and the position tree.
 * Give it a `key` that includes the company id so the open/closed state resets on company change.
 */
export function OrgTreeExplorer({
  title,
  description,
  emptyText,
  units,
  locale,
}: OrgTreeExplorerProps) {
  const { roots, childrenOf, branchIds } = useMemo(() => {
    const map = new Map<number | null, UnitRow[]>();
    for (const u of units) {
      const list = map.get(u.parent_unit_id);
      if (list) list.push(u);
      else map.set(u.parent_unit_id, [u]);
    }
    for (const list of map.values()) {
      list.sort((a, b) => a.level_rank - b.level_rank || a.name_en.localeCompare(b.name_en));
    }
    return {
      roots: map.get(null) ?? [],
      childrenOf: map,
      branchIds: [...map.keys()].filter((k): k is number => k !== null),
    };
  }, [units]);

  const [expanded, setExpanded] = useState<Set<number>>(
    () => new Set(roots.map((r) => r.unit_id))
  );

  function toggle(id: number) {
    setExpanded((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }

  return (
    <section className="rounded-lg border border-zinc-200 bg-white shadow-sm">
      <div className="flex flex-wrap items-start justify-between gap-3 border-b border-zinc-200 px-4 py-3">
        <div>
          <h2 className="text-base font-semibold text-zinc-900">{title}</h2>
          <p className="mt-0.5 text-sm text-zinc-600">{description}</p>
        </div>
        {units.length > 0 && (
          <div className="flex items-center gap-2 text-xs">
            <span className="text-zinc-500">{units.length} open units</span>
            <button
              type="button"
              onClick={() => setExpanded(new Set(branchIds))}
              className="rounded-md border border-zinc-300 px-2.5 py-1 font-medium text-zinc-700 hover:bg-zinc-50"
            >
              Expand all
            </button>
            <button
              type="button"
              onClick={() => setExpanded(new Set())}
              className="rounded-md border border-zinc-300 px-2.5 py-1 font-medium text-zinc-700 hover:bg-zinc-50"
            >
              Collapse all
            </button>
          </div>
        )}
      </div>

      <div className="p-4">
        {units.length === 0 ? (
          <p className="rounded-md bg-zinc-100 px-3 py-2 text-sm text-zinc-700">
            {emptyText}
          </p>
        ) : (
          <ul>
            {roots.map((root) => (
              <TreeNode
                key={root.unit_id}
                unit={root}
                childrenOf={childrenOf}
                expanded={expanded}
                onToggle={toggle}
                locale={locale}
              />
            ))}
          </ul>
        )}
      </div>
    </section>
  );
}

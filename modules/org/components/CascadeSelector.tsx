// modules/org/components/CascadeSelector.tsx
"use client";

import { useEffect, useRef, useState } from "react";
import { displayName, type Locale } from "@/lib/i18n";
import { levelLabel } from "@/modules/org/labels";
import type { HierarchyLevel, UnitOption } from "@/modules/org/types";
import { selectClassName } from "./AsyncSelect";

interface Column {
  options: UnitOption[];
  selectedId: number | null;
}

interface CascadeSelectorProps {
  label: string;
  placeholder: string;
  /** Shown when nothing exists under the root. */
  emptyText: string;
  emptyTone: "warning" | "info";
  locale: Locale;
  levels: HierarchyLevel[];
  /** Parent of the first dropdown. null = directly under the company. */
  rootParentId: number | null;
  /** Must be memoised (useCallback). Returns the direct children of a unit. */
  fetchChildren: (parentId: number | null) => Promise<UnitOption[]>;
  /** Called with the deepest unit picked so far, or null when nothing is picked. */
  onChange: (unit: UnitOption | null) => void;
}

function deepest(columns: Column[]): UnitOption | null {
  for (let i = columns.length - 1; i >= 0; i--) {
    const col = columns[i];
    if (col.selectedId !== null) {
      return col.options.find((o) => o.unit_id === col.selectedId) ?? null;
    }
  }
  return null;
}

/**
 * One dropdown per level. Picking a unit loads the next dropdown with its children,
 * if it has any. The user can stop at any depth (leave the next dropdown empty).
 * To reset it, give it a `key` that includes whatever it depends on.
 */
export function CascadeSelector({
  label,
  placeholder,
  emptyText,
  emptyTone,
  locale,
  levels,
  rootParentId,
  fetchChildren,
  onChange,
}: CascadeSelectorProps) {
  const [columns, setColumns] = useState<Column[]>([]);
  const [rootLoaded, setRootLoaded] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const requestSeq = useRef(0);

  useEffect(() => {
    let cancelled = false;
    fetchChildren(rootParentId)
      .then((options) => {
        if (cancelled) return;
        setColumns(options.length > 0 ? [{ options, selectedId: null }] : []);
        setRootLoaded(true);
      })
      .catch((e: unknown) => {
        if (cancelled) return;
        setError(e instanceof Error ? e.message : "Load failed");
        setRootLoaded(true);
      });
    return () => {
      cancelled = true;
    };
  }, [fetchChildren, rootParentId]);

  async function handleSelect(depth: number, raw: string) {
    const seq = ++requestSeq.current;
    setError(null);

    const selectedId = raw === "" ? null : Number(raw);
    const kept = columns
      .slice(0, depth + 1)
      .map((c, i) => (i === depth ? { ...c, selectedId } : c));
    setColumns(kept);
    onChange(deepest(kept));

    if (selectedId === null) {
      setBusy(false);
      return;
    }

    setBusy(true);
    try {
      const children = await fetchChildren(selectedId);
      if (seq !== requestSeq.current) return;
      if (children.length > 0) {
        setColumns([...kept, { options: children, selectedId: null }]);
      }
    } catch (e) {
      if (seq === requestSeq.current) {
        setError(e instanceof Error ? e.message : "Load failed");
      }
    } finally {
      if (seq === requestSeq.current) setBusy(false);
    }
  }

  if (!rootLoaded) {
    return <p className="text-xs text-zinc-500">Loading...</p>;
  }

  return (
    <div className="space-y-3">
      {columns.length === 0 && !error && (
        <p
          className={`rounded-md px-3 py-2 text-xs ${
            emptyTone === "warning"
              ? "bg-amber-50 text-amber-800"
              : "bg-zinc-100 text-zinc-700"
          }`}
        >
          {emptyText}
        </p>
      )}

      {columns.map((col, depth) => (
        <div key={depth}>
          <label className="mb-1 block text-xs font-medium text-zinc-600">
            {depth === 0 ? label : "Go deeper (optional)"}
          </label>
          <select
            value={col.selectedId ?? ""}
            onChange={(e) => handleSelect(depth, e.target.value)}
            className={selectClassName}
          >
            <option value="">
              {depth === 0 ? placeholder : "Stop at the level above"}
            </option>
            {col.options.map((o) => (
              <option key={o.unit_id} value={o.unit_id}>
                {displayName(locale, o.name_en, o.name_km)} (
                {levelLabel(levels, locale, o.level_id, o.level_code)})
              </option>
            ))}
          </select>
        </div>
      ))}

      {busy && <p className="text-xs text-zinc-500">Loading...</p>}
      {error && (
        <p className="rounded-md bg-red-50 px-3 py-2 text-xs text-red-700">{error}</p>
      )}
    </div>
  );
}

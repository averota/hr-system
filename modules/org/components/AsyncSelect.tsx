// modules/org/components/AsyncSelect.tsx
"use client";

import { useEffect, useId, useState } from "react";

export const selectClassName =
  "w-full rounded-md border border-zinc-300 bg-white px-2.5 py-1.5 text-sm text-zinc-900 focus:border-zinc-900 focus:outline-none";

interface AsyncSelectProps<T> {
  label: string;
  placeholder: string;
  /** Shown instead of the dropdown when the list comes back empty. */
  emptyText: string;
  /** Must be memoised (useCallback). The list loads once on mount and again if this changes. */
  load: () => Promise<T[]>;
  getId: (item: T) => number;
  getLabel: (item: T) => string;
  onChange: (item: T | null) => void;
}

/**
 * Dropdown that loads its own options.
 * To reset it when a parent choice changes, give it a `key` that includes that choice.
 */
export function AsyncSelect<T>({
  label,
  placeholder,
  emptyText,
  load,
  getId,
  getLabel,
  onChange,
}: AsyncSelectProps<T>) {
  const selectId = useId();
  const [items, setItems] = useState<T[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [value, setValue] = useState("");

  useEffect(() => {
    let cancelled = false;
    load()
      .then((rows) => {
        if (!cancelled) setItems(rows);
      })
      .catch((e: unknown) => {
        if (!cancelled) setError(e instanceof Error ? e.message : "Load failed");
      });
    return () => {
      cancelled = true;
    };
  }, [load]);

  function handleChange(next: string) {
    setValue(next);
    const item =
      next === "" ? null : (items?.find((i) => String(getId(i)) === next) ?? null);
    onChange(item);
  }

  return (
    <div>
      <label htmlFor={selectId} className="mb-1 block text-xs font-medium text-zinc-600">
        {label}
      </label>
      {error ? (
        <p className="rounded-md bg-red-50 px-3 py-2 text-xs text-red-700">{error}</p>
      ) : items === null ? (
        <p className="text-xs text-zinc-500">Loading...</p>
      ) : items.length === 0 ? (
        <p className="rounded-md bg-amber-50 px-3 py-2 text-xs text-amber-800">
          {emptyText}
        </p>
      ) : (
        <select
          id={selectId}
          value={value}
          onChange={(e) => handleChange(e.target.value)}
          className={selectClassName}
        >
          <option value="">{placeholder}</option>
          {items.map((item) => (
            <option key={getId(item)} value={getId(item)}>
              {getLabel(item)}
            </option>
          ))}
        </select>
      )}
    </div>
  );
}

// modules/org/components/HistoryToggle.tsx
"use client";

export type ViewMode = "current" | "closed" | "asof";

interface HistoryToggleProps {
  mode: ViewMode;
  onChange: (mode: ViewMode) => void;
  /** Offer the "As of date" option (only on tabs that support it). */
  allowAsOf?: boolean;
}

/** Switch between current records, closed (history) records and an as-of date view on a tab. */
export function HistoryToggle({ mode, onChange, allowAsOf = false }: HistoryToggleProps) {
  const base = "rounded px-2.5 py-1";
  const active = "bg-zinc-900 text-white";
  const idle = "text-zinc-700 hover:text-zinc-900";

  const options: { id: ViewMode; label: string }[] = [
    { id: "current", label: "Current" },
    { id: "closed", label: "Closed (history)" },
    ...(allowAsOf ? [{ id: "asof" as const, label: "As of date" }] : []),
  ];

  return (
    <div
      role="group"
      aria-label="Show current records, closed records or a past date"
      className="inline-flex rounded-md border border-zinc-300 bg-zinc-50 p-0.5 text-xs font-medium"
    >
      {options.map((o) => (
        <button
          key={o.id}
          type="button"
          aria-pressed={mode === o.id}
          onClick={() => onChange(o.id)}
          className={`${base} ${mode === o.id ? active : idle}`}
        >
          {o.label}
        </button>
      ))}
    </div>
  );
}
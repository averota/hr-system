// modules/org/components/HistoryToggle.tsx
"use client";

export type ViewMode = "current" | "closed" | "asof" | "moves";

const LABELS: Record<ViewMode, string> = {
  current: "Current",
  closed: "Closed (history)",
  asof: "As of date",
  moves: "Moves (reorg)",
};

interface HistoryToggleProps {
  mode: ViewMode;
  onChange: (mode: ViewMode) => void;
  /** Modes offered besides Current and Closed (history), in the order shown. */
  extraModes?: ViewMode[];
}

/** Switch between current records, closed records and the extra history views on a tab. */
export function HistoryToggle({ mode, onChange, extraModes = [] }: HistoryToggleProps) {
  const base = "rounded px-2.5 py-1";
  const active = "bg-zinc-900 text-white";
  const idle = "text-zinc-700 hover:text-zinc-900";

  const options: ViewMode[] = ["current", "closed", ...extraModes];

  return (
    <div
      role="group"
      aria-label="Show current records, closed records or another history view"
      className="inline-flex rounded-md border border-zinc-300 bg-zinc-50 p-0.5 text-xs font-medium"
    >
      {options.map((id) => (
        <button
          key={id}
          type="button"
          aria-pressed={mode === id}
          onClick={() => onChange(id)}
          className={`${base} ${mode === id ? active : idle}`}
        >
          {LABELS[id]}
        </button>
      ))}
    </div>
  );
}
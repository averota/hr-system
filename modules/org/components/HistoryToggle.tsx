// modules/org/components/HistoryToggle.tsx
"use client";

interface HistoryToggleProps {
  /** True when the closed (history) records are shown. */
  showHistory: boolean;
  onChange: (showHistory: boolean) => void;
}

/** Switch between current records and closed (history) records on a tab. */
export function HistoryToggle({ showHistory, onChange }: HistoryToggleProps) {
  const base = "rounded px-2.5 py-1";
  const active = "bg-zinc-900 text-white";
  const idle = "text-zinc-700 hover:text-zinc-900";

  return (
    <div
      role="group"
      aria-label="Show current or closed records"
      className="inline-flex rounded-md border border-zinc-300 bg-zinc-50 p-0.5 text-xs font-medium"
    >
      <button
        type="button"
        aria-pressed={!showHistory}
        onClick={() => onChange(false)}
        className={`${base} ${showHistory ? idle : active}`}
      >
        Current
      </button>
      <button
        type="button"
        aria-pressed={showHistory}
        onClick={() => onChange(true)}
        className={`${base} ${showHistory ? active : idle}`}
      >
        Closed (history)
      </button>
    </div>
  );
}
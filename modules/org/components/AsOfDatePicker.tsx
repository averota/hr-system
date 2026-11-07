// modules/org/components/AsOfDatePicker.tsx
"use client";

interface AsOfDatePickerProps {
  id: string;
  value: string;
  onChange: (value: string) => void;
  note?: string;
}

/** Date field with a short note, shared by the as-of history views. */
export function AsOfDatePicker({ id, value, onChange, note }: AsOfDatePickerProps) {
  return (
    <div className="flex flex-wrap items-center gap-3 rounded-lg border border-zinc-200 bg-white p-4">
      <label htmlFor={id} className="text-sm font-medium text-zinc-700">
        As of date
      </label>
      <input
        id={id}
        type="date"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className="rounded-md border border-zinc-300 bg-white px-2.5 py-1.5 text-sm text-zinc-900 focus:border-zinc-900 focus:outline-none"
      />
      {note && <p className="text-xs text-zinc-500">{note}</p>}
    </div>
  );
}
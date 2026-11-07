// modules/org/components/RowLimitWarning.tsx
import { MAX_ROWS } from "@/modules/org/limits";

interface RowLimitWarningProps {
  /** What was loaded, in plain words (for example "allocations"). */
  what: string;
  /** Spacing classes. The default suits a card; pass "" where the warning sits outside a card. */
  className?: string;
}

/** Shared warning for any list or total that may be cut off at the Supabase row limit. */
export function RowLimitWarning({ what, className = "mx-4 mt-4" }: RowLimitWarningProps) {
  return (
    <p
      role="alert"
      className={`rounded-md border border-amber-200 bg-amber-50 px-3 py-2 text-sm text-amber-900 ${className}`}
    >
      Only the first {MAX_ROWS} {what} were loaded. Some rows may be missing, so lists and
      totals can be too low.
    </p>
  );
}
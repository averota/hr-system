// modules/org/useAsOfLoad.ts
// Loads data for a history screen. Pass a memoised loader (useMemo or useCallback) that
// changes when its inputs change, or null to load nothing. The result is tied to the loader
// that produced it, so a stale answer is never shown for a newer date or company.
import { useEffect, useState } from "react";

interface Settled<T> {
  load: () => Promise<T>;
  data: T | null;
  error: string | null;
}

export function useAsOfLoad<T>(load: (() => Promise<T>) | null) {
  const [settled, setSettled] = useState<Settled<T> | null>(null);

  useEffect(() => {
    if (!load) return;
    let cancelled = false;
    load()
      .then((data) => {
        if (!cancelled) setSettled({ load, data, error: null });
      })
      .catch((e: unknown) => {
        if (!cancelled) {
          setSettled({
            load,
            data: null,
            error: e instanceof Error ? e.message : "Could not load the data.",
          });
        }
      });
    return () => {
      cancelled = true;
    };
  }, [load]);

  const current = load !== null && settled?.load === load ? settled : null;

  return {
    data: current?.data ?? null,
    error: current?.error ?? null,
    isLoading: load !== null && current === null,
  };
}
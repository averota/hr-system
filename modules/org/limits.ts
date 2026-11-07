// modules/org/limits.ts
// Supabase returns at most this many rows per request. A list that reaches it may be cut off.
// To test the warning, lower this value temporarily (for example to 1).
export const MAX_ROWS = 1000;

/** True when a request returned as many rows as the limit allows, so more may exist. */
export function isRowLimitReached(rowCount: number): boolean {
  return rowCount >= MAX_ROWS;
}
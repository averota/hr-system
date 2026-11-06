// lib/dates.ts
// Date helpers shared by all modules.

/**
 * Today's date in Phnom Penh as "YYYY-MM-DD".
 * Use it as the default for date inputs. The database server runs on UTC, so its
 * "today" can be one day behind early in the morning in Cambodia. Always send
 * the date explicitly to write functions.
 */
export function todayInPhnomPenh(): string {
  // The "en-CA" locale formats dates as YYYY-MM-DD.
  return new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Phnom_Penh" }).format(
    new Date()
  );
}

/** True for a "YYYY-MM-DD" string (what <input type="date"> returns). */
export function isIsoDate(value: string): boolean {
  return /^\d{4}-\d{2}-\d{2}$/.test(value);
}
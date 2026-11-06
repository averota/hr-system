// lib/i18n.ts
// Shared bilingual helper following HRIS_PROJECT_OVERVIEW.md section 5.6:
// Show name_km when the interface is Khmer and it is not empty, otherwise name_en.

export type Locale = "en" | "km";

export function displayName(
  locale: Locale,
  nameEn: string,
  nameKm?: string | null
): string {
  if (locale === "km" && nameKm && nameKm.trim().length > 0) {
    return nameKm;
  }
  return nameEn;
}
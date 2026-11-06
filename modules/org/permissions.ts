// modules/org/permissions.ts
// Asks the database which actions the signed-in user may perform (public.check_permissions).
// This only hides or disables what would fail. The write wrappers still check on every write.
"use client";

import { useEffect, useState } from "react";
import { createClient } from "@/lib/supabase/client";

/** Permission codes used by the frontend (seeded in migration 012). */
export const PERM_ALLOCATION_WRITE = "org.allocation.write";
export const PERM_ORG_UNIT_WRITE = "org.unit.write";
export const PERM_POS_UNIT_WRITE = "pos.unit.write";

// The database refuses more than 500 targets per call.
const MAX_TARGETS_PER_CALL = 500;

export interface PermissionTarget {
  orgUnitId?: number | null;
  departmentId?: number | null;
}

function keyOf(
  orgUnitId: number | null | undefined,
  departmentId: number | null | undefined
): string {
  return `${orgUnitId ?? ""}:${departmentId ?? ""}`;
}

function targetFromKey(key: string): PermissionTarget {
  const [org, dept] = key.split(":");
  return {
    orgUnitId: org ? Number(org) : null,
    departmentId: dept ? Number(dept) : null,
  };
}

/**
 * Checks one permission code for a list of targets, in as few calls as possible.
 * Returns a map of target key -> allowed. Any error counts as "not allowed".
 */
export async function checkPermissions(
  companyId: number,
  code: string,
  targets: PermissionTarget[]
): Promise<Map<string, boolean>> {
  const keys = [...new Set(targets.map((t) => keyOf(t.orgUnitId, t.departmentId)))];
  const result = new Map<string, boolean>(keys.map((k) => [k, false]));
  if (keys.length === 0) return result;

  const chunks: string[][] = [];
  for (let i = 0; i < keys.length; i += MAX_TARGETS_PER_CALL) {
    chunks.push(keys.slice(i, i + MAX_TARGETS_PER_CALL));
  }

  const supabase = createClient();
  await Promise.all(
    chunks.map(async (chunk) => {
      const { data, error } = await supabase.rpc("check_permissions", {
        p_company_id: companyId,
        p_permission_code: code,
        p_targets: chunk.map((k) => {
          const t = targetFromKey(k);
          return { org_unit_id: t.orgUnitId ?? null, department_id: t.departmentId ?? null };
        }),
      });
      if (error) {
        console.error("check_permissions failed:", error.message);
        return; // keys stay false
      }
      for (const row of data ?? []) {
        result.set(keyOf(row.org_unit_id, row.department_id), row.allowed === true);
      }
    })
  );
  return result;
}

interface PermissionResult {
  requestKey: string;
  allowed: Map<string, boolean>;
}

/**
 * Loads permissions for the given targets whenever they change.
 * `can(orgUnitId, departmentId)` is false until the answer arrives, so nothing
 * is shown as allowed by mistake. `isLoading` is true while waiting.
 */
export function usePermissions(
  companyId: number,
  code: string,
  targets: PermissionTarget[]
) {
  const signature = [
    ...new Set(targets.map((t) => keyOf(t.orgUnitId, t.departmentId))),
  ]
    .sort()
    .join(",");
  const requestKey = `${companyId}|${code}|${signature}`;
  const [result, setResult] = useState<PermissionResult | null>(null);

  useEffect(() => {
    if (signature === "") return;
    let cancelled = false;
    checkPermissions(companyId, code, signature.split(",").map(targetFromKey)).then(
      (allowed) => {
        if (!cancelled) setResult({ requestKey, allowed });
      }
    );
    return () => {
      cancelled = true;
    };
  }, [companyId, code, signature, requestKey]);

  const isCurrent = result?.requestKey === requestKey;

  return {
    isLoading: signature !== "" && !isCurrent,
    can: (orgUnitId?: number | null, departmentId?: number | null): boolean =>
      isCurrent && result.allowed.get(keyOf(orgUnitId, departmentId)) === true,
  };
}
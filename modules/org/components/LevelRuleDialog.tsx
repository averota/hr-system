// modules/org/components/LevelRuleDialog.tsx
"use client";

import { useState } from "react";
import { isIsoDate, todayInPhnomPenh } from "@/lib/dates";
import { displayName, type Locale } from "@/lib/i18n";
import { disableLevelRule, enableLevelRule } from "@/modules/org/queries";
import type { CompanyLevelRule, HierarchyLevel } from "@/modules/org/types";
import { selectClassName } from "./AsyncSelect";
import { Modal } from "./Modal";

export type RuleAction = "enable" | "disable";

/** One place a level may sit. value is "root" or a parent level ID. */
export interface ParentOption {
  value: string;
  label: string;
}

interface LevelRuleDialogProps {
  action: RuleAction;
  companyId: number;
  locale: Locale;
  level: HierarchyLevel;
  /** Places the level can still be enabled under (used by "enable"). */
  parentOptions: ParentOption[];
  /** The rule to close (used by "disable"). */
  rule: CompanyLevelRule | null;
  /** Readable position of the rule, for example "Under Business Unit" (used by "disable"). */
  ruleLabel: string;
  onCancel: () => void;
  /** Called after a successful save with a message to show the user. */
  onDone: (message: string) => void;
}

/** Modal to enable a level under a parent, or to close one rule. */
export function LevelRuleDialog({
  action,
  companyId,
  locale,
  level,
  parentOptions,
  rule,
  ruleLabel,
  onCancel,
  onDone,
}: LevelRuleDialogProps) {
  const [parent, setParent] = useState(() =>
    parentOptions.length === 1 ? parentOptions[0].value : ""
  );
  const [date, setDate] = useState(() => todayInPhnomPenh());
  const [isSaving, setIsSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const levelName = displayName(locale, level.name_en, level.name_km);
  const dateIsValid = isIsoDate(date);
  // ISO dates compare correctly as text.
  const dateBeforeStart = rule !== null && dateIsValid && date < rule.valid_from;

  const canSubmit =
    action === "enable"
      ? parent !== ""
      : rule !== null && dateIsValid && !dateBeforeStart;

  async function handleSubmit() {
    if (!canSubmit) return;
    setIsSaving(true);
    setError(null);
    try {
      if (action === "enable") {
        const chosen = parentOptions.find((o) => o.value === parent);
        await enableLevelRule(companyId, level.level_id, parent === "root" ? null : Number(parent));
        onDone(`Enabled ${levelName}${chosen ? `: ${chosen.label}` : ""}.`);
      } else if (rule) {
        await disableLevelRule(companyId, rule.rule_id, date);
        onDone(`Disabled rule for ${levelName}: ${ruleLabel}.`);
      }
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : "Save failed");
      setIsSaving(false);
    }
  }

  return (
    <Modal
      title={action === "enable" ? "Enable level" : "Disable level rule"}
      submitLabel={action === "enable" ? "Enable" : "Disable rule"}
      canSubmit={canSubmit}
      isSaving={isSaving}
      error={error}
      onSubmit={handleSubmit}
      onCancel={onCancel}
    >
      <p className="mt-2 text-sm text-zinc-700">{levelName}</p>

      {action === "enable" ? (
        <>
          {parentOptions.length === 0 ? (
            <p className="mt-3 rounded-md bg-amber-50 px-3 py-2 text-xs text-amber-800">
              No place is left for this level. Enable a higher level first, or every option
              is already enabled.
            </p>
          ) : (
            <>
              <label
                htmlFor="rule-parent"
                className="mb-1 mt-3 block text-xs font-medium text-zinc-600"
              >
                Where may this level sit?
              </label>
              <select
                id="rule-parent"
                value={parent}
                onChange={(e) => {
                  setError(null);
                  setParent(e.target.value);
                }}
                className={selectClassName}
              >
                <option value="">Select</option>
                {parentOptions.map((o) => (
                  <option key={o.value} value={o.value}>
                    {o.label}
                  </option>
                ))}
              </select>
            </>
          )}
          <p className="mt-2 text-xs text-zinc-500">
            The rule starts today (server date). Existing units are not changed.
          </p>
        </>
      ) : (
        <>
          <p className="mt-1 text-sm text-zinc-700">{ruleLabel}</p>
          <p className="mt-3 text-xs text-zinc-500">
            Existing units keep their place. The database refuses this while the level is
            required, is the parent of another rule, or still has open units, and shows why.
          </p>
          <label
            htmlFor="rule-date"
            className="mb-1 mt-3 block text-xs font-medium text-zinc-600"
          >
            Close date
          </label>
          <input
            id="rule-date"
            type="date"
            value={date}
            onChange={(e) => {
              setError(null);
              setDate(e.target.value);
            }}
            className={selectClassName}
          />
          {dateBeforeStart && rule && (
            <p className="mt-2 text-xs text-red-700">
              The close date cannot be before {rule.valid_from}, when this rule started.
            </p>
          )}
        </>
      )}
    </Modal>
  );
}
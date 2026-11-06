// modules/org/components/HierarchyConfig.tsx
"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { displayName, type Locale } from "@/lib/i18n";
import { PERM_CONFIG_WRITE, usePermissions, type PermissionTarget } from "@/modules/org/permissions";
import type { CompanyLevelRule, HierarchyLevel, TreeKind } from "@/modules/org/types";
import { LevelRuleDialog, type ParentOption, type RuleAction } from "./LevelRuleDialog";

interface HierarchyConfigProps {
  companyId: number;
  levels: HierarchyLevel[];
  /** Open rules of the selected company. */
  rules: CompanyLevelRule[];
  locale: Locale;
}

interface OpenDialog {
  action: RuleAction;
  level: HierarchyLevel;
  rule: CompanyLevelRule | null;
}

const TREES: { tree: TreeKind; title: string; rootLabel: string }[] = [
  { tree: "org", title: "Organization Structure Levels (org)", rootLabel: "Directly under Parent Company" },
  { tree: "pos", title: "Position Structure Levels (pos)", rootLabel: "Top of Position Tree (Root)" },
];

// org.config.write is a company-level permission, so there is one empty target.
const COMPANY_TARGET: PermissionTarget[] = [{}];

/**
 * Hierarchy configuration: which levels are enabled for the company and under which parent.
 * Enable and Disable buttons show only where the user has org.config.write.
 * Give it a `key` that includes the company id.
 */
export function HierarchyConfig({ companyId, levels, rules, locale }: HierarchyConfigProps) {
  const router = useRouter();
  const permission = usePermissions(companyId, PERM_CONFIG_WRITE, COMPANY_TARGET);
  const canWrite = permission.can(null, null);
  const [dialog, setDialog] = useState<OpenDialog | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  function ruleLabel(rule: CompanyLevelRule, rootLabel: string): string {
    return rule.parent_level_id === null
      ? rootLabel
      : `Under ${displayName(locale, rule.parent_level_name_en ?? "", rule.parent_level_name_km)}`;
  }

  /** Places a level can still be enabled under: the root, or an enabled higher level of the same tree. */
  function parentOptionsFor(level: HierarchyLevel, rootLabel: string): ParentOption[] {
    const used = new Set(
      rules.filter((r) => r.level_id === level.level_id).map((r) => r.parent_level_id)
    );
    const enabledLevelIds = new Set(rules.map((r) => r.level_id));
    const options: ParentOption[] = [];

    if (level.can_be_root && !used.has(null)) {
      options.push({ value: "root", label: rootLabel });
    }
    levels
      .filter((l) => l.tree === level.tree && l.rank < level.rank)
      .sort((a, b) => a.rank - b.rank)
      .forEach((p) => {
        if (enabledLevelIds.has(p.level_id) && !used.has(p.level_id)) {
          options.push({
            value: String(p.level_id),
            label: `Under ${displayName(locale, p.name_en, p.name_km)}`,
          });
        }
      });
    return options;
  }

  function openDialog(next: OpenDialog) {
    setNotice(null);
    setDialog(next);
  }

  function handleDone(message: string) {
    setDialog(null);
    setNotice(message);
    router.refresh(); // rules come from the page loader and feed the tree screens too
  }

  function renderTree(tree: TreeKind, title: string, rootLabel: string) {
    const treeLevels = levels.filter((l) => l.tree === tree).sort((a, b) => a.rank - b.rank);

    return (
      <section key={tree} className="rounded-lg border border-zinc-200 bg-white shadow-sm">
        <div className="border-b border-zinc-200 px-4 py-3">
          <h2 className="text-base font-semibold text-zinc-900">{title}</h2>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-zinc-200 bg-zinc-50 text-xs uppercase text-zinc-600">
              <tr>
                <th className="px-4 py-2.5">Rank</th>
                <th className="px-4 py-2.5">Level</th>
                <th className="px-4 py-2.5">Code</th>
                <th className="px-4 py-2.5">Status</th>
                <th className="px-4 py-2.5">Allowed Parent(s)</th>
                {canWrite && <th className="px-4 py-2.5 text-right">Actions</th>}
              </tr>
            </thead>
            <tbody className="divide-y divide-zinc-200">
              {treeLevels.map((level) => {
                const activeRules = rules.filter((r) => r.level_id === level.level_id);
                const isEnabled = activeRules.length > 0;
                const options = canWrite ? parentOptionsFor(level, rootLabel) : [];

                return (
                  <tr key={level.level_id} className="align-top">
                    <td className="px-4 py-3 font-mono text-xs text-zinc-500">{level.rank}</td>
                    <td className="px-4 py-3">
                      <div className="font-medium text-zinc-900">
                        {displayName(locale, level.name_en, level.name_km)}
                      </div>
                      <div className="mt-0.5 flex gap-1.5 text-xs text-zinc-500">
                        {level.is_required && (
                          <span className="rounded bg-amber-50 px-1.5 py-0.5 text-amber-800">
                            Required
                          </span>
                        )}
                        {level.can_be_root && (
                          <span className="rounded bg-zinc-100 px-1.5 py-0.5 text-zinc-700">
                            Can be root
                          </span>
                        )}
                      </div>
                    </td>
                    <td className="px-4 py-3 font-mono text-xs text-zinc-600">{level.code}</td>
                    <td className="px-4 py-3">
                      {isEnabled ? (
                        <span className="inline-flex items-center rounded-full bg-emerald-50 px-2.5 py-0.5 text-xs font-medium text-emerald-700">
                          Enabled
                        </span>
                      ) : (
                        <span className="inline-flex items-center rounded-full bg-zinc-100 px-2.5 py-0.5 text-xs font-medium text-zinc-600">
                          Disabled
                        </span>
                      )}
                    </td>
                    <td className="px-4 py-3 text-zinc-700">
                      {!isEnabled ? (
                        <span className="text-zinc-400">Not enabled for this company</span>
                      ) : (
                        <ul className="space-y-1">
                          {activeRules.map((rule) => (
                            <li key={rule.rule_id} className="flex flex-wrap items-center gap-2">
                              <span>{ruleLabel(rule, rootLabel)}</span>
                              <span className="text-xs text-zinc-400">(since {rule.valid_from})</span>
                              {canWrite && (
                                <button
                                  type="button"
                                  onClick={() => openDialog({ action: "disable", level, rule })}
                                  className="rounded-md border border-zinc-300 bg-white px-2 py-0.5 text-xs font-medium text-red-700 hover:bg-red-50"
                                >
                                  Disable
                                </button>
                              )}
                            </li>
                          ))}
                        </ul>
                      )}
                    </td>
                    {canWrite && (
                      <td className="whitespace-nowrap px-4 py-3 text-right">
                        <button
                          type="button"
                          onClick={() => openDialog({ action: "enable", level, rule: null })}
                          disabled={options.length === 0}
                          title={
                            options.length === 0
                              ? "No place left for this level. Enable a higher level first."
                              : undefined
                          }
                          className="rounded-md border border-zinc-300 bg-white px-2.5 py-1 text-xs font-medium text-zinc-700 hover:bg-zinc-50 disabled:cursor-not-allowed disabled:opacity-50"
                        >
                          {isEnabled ? "Add parent option" : "Enable level"}
                        </button>
                      </td>
                    )}
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </section>
    );
  }

  const dialogRootLabel = dialog
    ? (TREES.find((t) => t.tree === dialog.level.tree)?.rootLabel ?? "")
    : "";

  return (
    <>
      <div>
        <h1 className="text-lg font-semibold text-zinc-900">Hierarchy Configuration</h1>
        <p className="mt-0.5 text-sm text-zinc-600">
          Levels enabled for the selected company and where each may sit.
          {canWrite
            ? " Existing units are never rearranged when a rule changes."
            : " You can view the rules but not change them."}
        </p>
      </div>

      {notice && (
        <p role="status" className="rounded-md bg-emerald-50 px-3 py-2 text-sm text-emerald-800">
          {notice}
        </p>
      )}

      <div className="grid gap-6 lg:grid-cols-2">
        {TREES.map((t) => renderTree(t.tree, t.title, t.rootLabel))}
      </div>

      {dialog && (
        <LevelRuleDialog
          key={`${dialog.action}-${dialog.level.level_id}-${dialog.rule?.rule_id ?? "new"}`}
          action={dialog.action}
          companyId={companyId}
          locale={locale}
          level={dialog.level}
          parentOptions={
            dialog.action === "enable" ? parentOptionsFor(dialog.level, dialogRootLabel) : []
          }
          rule={dialog.rule}
          ruleLabel={dialog.rule ? ruleLabel(dialog.rule, dialogRootLabel) : ""}
          onCancel={() => setDialog(null)}
          onDone={handleDone}
        />
      )}
    </>
  );
}
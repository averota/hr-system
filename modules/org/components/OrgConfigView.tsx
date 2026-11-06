// modules/org/components/OrgConfigView.tsx
"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import { displayName, type Locale } from "@/lib/i18n";
import type {
  CompanyLevelRule,
  HierarchyLevel,
  ParentCompany,
  PositionAllocation,
  TreeKind,
  UnitRow,
} from "@/modules/org/types";
import { AllocationForm } from "./AllocationForm";
import { HeadcountGrid } from "./HeadcountGrid";
import { OrgTreeExplorer } from "./OrgTreeExplorer";

type TabId = "config" | "org-tree" | "pos-tree" | "allocation" | "headcount";

const TABS: { id: TabId; label: string }[] = [
  { id: "config", label: "Configuration" },
  { id: "org-tree", label: "Org tree" },
  { id: "pos-tree", label: "Position tree" },
  { id: "allocation", label: "Allocation form" },
  { id: "headcount", label: "Headcount" },
];

interface OrgConfigViewProps {
  userEmail: string;
  companies: ParentCompany[];
  levels: HierarchyLevel[];
  rules: CompanyLevelRule[];
  orgUnits: UnitRow[];
  posUnits: UnitRow[];
  allocations: PositionAllocation[];
}

export function OrgConfigView({
  userEmail,
  companies,
  levels,
  rules,
  orgUnits,
  posUnits,
  allocations,
}: OrgConfigViewProps) {
  const router = useRouter();
  const [locale, setLocale] = useState<Locale>("en");
  const [activeTab, setActiveTab] = useState<TabId>("config");
  const [selectedCompanyId, setSelectedCompanyId] = useState<number | null>(
    companies[0]?.company_id ?? null
  );
  const [isSigningOut, setIsSigningOut] = useState(false);

  async function handleSignOut() {
    setIsSigningOut(true);
    const supabase = createClient();
    await supabase.auth.signOut();
    router.push("/login");
    router.refresh();
  }

  const companyRules = rules.filter((r) => r.company_id === selectedCompanyId);
  const companyOrgUnits = orgUnits.filter((u) => u.company_id === selectedCompanyId);
  const companyPosUnits = posUnits.filter((u) => u.company_id === selectedCompanyId);
  const companyAllocations = allocations.filter(
    (a) => a.company_id === selectedCompanyId
  );

  function renderTreeTable(tree: TreeKind, title: string, rootLabel: string) {
    const treeLevels = levels
      .filter((l) => l.tree === tree)
      .sort((a, b) => a.rank - b.rank);

    return (
      <section className="rounded-lg border border-zinc-200 bg-white shadow-sm">
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
              </tr>
            </thead>
            <tbody className="divide-y divide-zinc-200">
              {treeLevels.map((level) => {
                const activeRules = companyRules.filter(
                  (r) => r.level_id === level.level_id
                );
                const isEnabled = activeRules.length > 0;

                return (
                  <tr key={level.level_id} className="align-top">
                    <td className="px-4 py-3 font-mono text-xs text-zinc-500">
                      {level.rank}
                    </td>
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
                    <td className="px-4 py-3 font-mono text-xs text-zinc-600">
                      {level.code}
                    </td>
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
                        <span className="text-zinc-400">
                          Not enabled for this company
                        </span>
                      ) : (
                        <ul className="space-y-1">
                          {activeRules.map((rule) => (
                            <li
                              key={rule.rule_id}
                              className="flex flex-wrap items-center gap-2"
                            >
                              <span>
                                {rule.parent_level_id === null
                                  ? rootLabel
                                  : `Under ${displayName(
                                      locale,
                                      rule.parent_level_name_en ?? "",
                                      rule.parent_level_name_km
                                    )}`}
                              </span>
                              <span className="text-xs text-zinc-400">
                                (since {rule.valid_from})
                              </span>
                            </li>
                          ))}
                        </ul>
                      )}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </section>
    );
  }

  return (
    <div className="min-h-screen bg-zinc-50">
      {/* Shared App Header */}
      <header className="border-b border-zinc-200 bg-white">
        <div className="mx-auto flex max-w-6xl flex-wrap items-center justify-between gap-4 px-4 py-3">
          <div className="flex items-center gap-4">
            <span className="text-base font-semibold text-zinc-900">
              HRIS · Organization
            </span>

            {companies.length > 0 && (
              <div className="flex items-center gap-2">
                <label
                  htmlFor="company-select"
                  className="text-xs font-medium text-zinc-500"
                >
                  Company
                </label>
                <select
                  id="company-select"
                  value={selectedCompanyId ?? ""}
                  onChange={(e) => setSelectedCompanyId(Number(e.target.value))}
                  className="rounded-md border border-zinc-300 bg-white px-2.5 py-1.5 text-sm text-zinc-900 focus:border-zinc-900 focus:outline-none"
                >
                  {companies.map((c) => (
                    <option key={c.company_id} value={c.company_id}>
                      {displayName(locale, c.name_en, c.name_km)}
                      {!c.is_active ? " (Inactive)" : ""}
                    </option>
                  ))}
                </select>
              </div>
            )}
          </div>

          <div className="flex items-center gap-3">
            {/* Language Toggle (EN / KM) */}
            <div
              role="group"
              aria-label="Interface language"
              className="inline-flex rounded-md border border-zinc-300 bg-zinc-50 p-0.5 text-xs font-medium"
            >
              <button
                type="button"
                onClick={() => setLocale("en")}
                className={`rounded px-2.5 py-1 ${
                  locale === "en"
                    ? "bg-zinc-900 text-white"
                    : "text-zinc-700 hover:text-zinc-900"
                }`}
              >
                EN
              </button>
              <button
                type="button"
                onClick={() => setLocale("km")}
                className={`rounded px-2.5 py-1 ${
                  locale === "km"
                    ? "bg-zinc-900 text-white"
                    : "text-zinc-700 hover:text-zinc-900"
                }`}
              >
                ខ្មែរ
              </button>
            </div>

            <span className="text-xs text-zinc-500">{userEmail}</span>

            <button
              type="button"
              onClick={handleSignOut}
              disabled={isSigningOut}
              className="rounded-md border border-zinc-300 bg-white px-3 py-1.5 text-xs font-medium text-zinc-700 hover:bg-zinc-50 disabled:opacity-50"
            >
              {isSigningOut ? "Signing out..." : "Sign out"}
            </button>
          </div>
        </div>

        {/* Tabs */}
        {companies.length > 0 && (
          <nav
            role="tablist"
            aria-label="Organization sections"
            className="mx-auto flex max-w-6xl gap-1 px-4"
          >
            {TABS.map((tab) => (
              <button
                key={tab.id}
                type="button"
                role="tab"
                aria-selected={activeTab === tab.id}
                onClick={() => setActiveTab(tab.id)}
                className={`border-b-2 px-3 py-2 text-sm font-medium ${
                  activeTab === tab.id
                    ? "border-zinc-900 text-zinc-900"
                    : "border-transparent text-zinc-500 hover:text-zinc-800"
                }`}
              >
                {tab.label}
              </button>
            ))}
          </nav>
        )}
      </header>

      {/* Main Content */}
      <main className="mx-auto max-w-6xl space-y-6 px-4 py-6">
        {companies.length === 0 || selectedCompanyId === null ? (
          <div className="rounded-lg border border-amber-200 bg-amber-50 p-6 text-sm text-amber-900">
            <p className="font-medium">No companies visible for your account</p>
            <p className="mt-1 text-amber-800">
              Your logged-in user (<code>{userEmail}</code>) is not linked to any
              tenant in <code>core.tenant_member</code> yet, or your tenant has
              no companies in <code>core.parent_company</code>.
            </p>
          </div>
        ) : (
          <>
            {activeTab === "config" && (
              <>
                <div>
                  <h1 className="text-lg font-semibold text-zinc-900">
                    Hierarchy Configuration (Read-Only)
                  </h1>
                  <p className="mt-0.5 text-sm text-zinc-600">
                    Active levels and allowed parent-child rules configured for the
                    selected company.
                  </p>
                </div>

                <div className="grid gap-6 lg:grid-cols-2">
                  {renderTreeTable(
                    "org",
                    "Organization Structure Levels (org)",
                    "Directly under Parent Company"
                  )}
                  {renderTreeTable(
                    "pos",
                    "Position Structure Levels (pos)",
                    "Top of Position Tree (Root)"
                  )}
                </div>
              </>
            )}

            {activeTab === "org-tree" && (
              <OrgTreeExplorer
                key={`org-${selectedCompanyId}`}
                title="Organization Tree"
                description="Open org units under the selected company."
                emptyText="No org units exist for this company yet."
                units={companyOrgUnits}
                locale={locale}
                manage={{
                  tree: "org",
                  companyId: selectedCompanyId,
                  levels,
                  rules: companyRules,
                }}
              />
            )}

            {activeTab === "pos-tree" && (
              <OrgTreeExplorer
                key={`pos-${selectedCompanyId}`}
                title="Position Tree"
                description="Open Departments and the Offices, Sections and Groups below them."
                emptyText="No Departments or position units exist for this company yet."
                units={companyPosUnits}
                locale={locale}
                manage={{
                  tree: "pos",
                  companyId: selectedCompanyId,
                  levels,
                  rules: companyRules,
                }}
              />
            )}

            {activeTab === "allocation" && (
              <AllocationForm
                key={selectedCompanyId}
                companyId={selectedCompanyId}
                locale={locale}
                levels={levels}
              />
            )}

            {activeTab === "headcount" && (
              <HeadcountGrid
                key={`hc-${selectedCompanyId}`}
                companyId={selectedCompanyId}
                allocations={companyAllocations}
                levels={levels}
                locale={locale}
              />
            )}
          </>
        )}
      </main>
    </div>
  );
}
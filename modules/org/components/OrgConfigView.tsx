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
  UnitRow,
} from "@/modules/org/types";
import { AllocationForm } from "./AllocationForm";
import { AsOfHeadcount } from "./AsOfHeadcount";
import { AsOfListings } from "./AsOfListings";
import { AsOfUnits } from "./AsOfUnits";
import { ClosedAllocations } from "./ClosedAllocations";
import { ClosedJobs } from "./ClosedJobs";
import { ClosedListings } from "./ClosedListings";
import { ClosedRules } from "./ClosedRules";
import { ClosedUnits } from "./ClosedUnits";
import { DepartmentListings } from "./DepartmentListings";
import { HeadcountGrid } from "./HeadcountGrid";
import { HierarchyConfig } from "./HierarchyConfig";
import { HistoryToggle, type ViewMode } from "./HistoryToggle";
import { JobCatalog } from "./JobCatalog";
import { OrgTreeExplorer } from "./OrgTreeExplorer";
import { UnitMoves } from "./UnitMoves";

type TabId =
  | "config"
  | "org-tree"
  | "pos-tree"
  | "jobs"
  | "listings"
  | "allocation"
  | "headcount";

const TABS: { id: TabId; label: string }[] = [
  { id: "config", label: "Configuration" },
  { id: "org-tree", label: "Org tree" },
  { id: "pos-tree", label: "Position tree" },
  { id: "jobs", label: "Jobs" },
  { id: "listings", label: "Department listings" },
  { id: "allocation", label: "Allocation form" },
  { id: "headcount", label: "Headcount" },
];

// History views per tab. Every listed tab has Current and Closed (history).
// The extra modes are the ORG Stage 9k views (as of date, reorg moves).
const HISTORY_MODES: Partial<Record<TabId, ViewMode[]>> = {
  config: [],
  "org-tree": ["asof", "moves"],
  "pos-tree": ["asof", "moves"],
  jobs: [],
  listings: ["asof"],
  headcount: ["asof"],
};

interface OrgConfigViewProps {
  userEmail: string;
  companies: ParentCompany[];
  levels: HierarchyLevel[];
  rules: CompanyLevelRule[];
  orgUnits: UnitRow[];
  posUnits: UnitRow[];
  allocations: PositionAllocation[];
  /** True when the allocations request returned the maximum number of rows (may be cut off). */
  allocationsLimitReached: boolean;
}

export function OrgConfigView({
  userEmail,
  companies,
  levels,
  rules,
  orgUnits,
  posUnits,
  allocations,
  allocationsLimitReached,
}: OrgConfigViewProps) {
  const router = useRouter();
  const [locale, setLocale] = useState<Locale>("en");
  const [activeTab, setActiveTab] = useState<TabId>("config");
  const [mode, setMode] = useState<ViewMode>("current");
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

  function selectTab(tab: TabId) {
    setActiveTab(tab);
    setMode("current");
  }

  const companyRules = rules.filter((r) => r.company_id === selectedCompanyId);
  const companyOrgUnits = orgUnits.filter((u) => u.company_id === selectedCompanyId);
  const companyPosUnits = posUnits.filter((u) => u.company_id === selectedCompanyId);
  // Departments are the position units with no parent.
  const companyDepartments = companyPosUnits.filter((u) => u.parent_unit_id === null);
  const companyAllocations = allocations.filter(
    (a) => a.company_id === selectedCompanyId
  );

  const extraModes = HISTORY_MODES[activeTab];

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
                onClick={() => selectTab(tab.id)}
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
            {extraModes !== undefined && (
              <div className="flex justify-end">
                <HistoryToggle mode={mode} onChange={setMode} extraModes={extraModes} />
              </div>
            )}

            {activeTab === "config" &&
              (mode === "closed" ? (
                <ClosedRules
                  key={`closed-cfg-${selectedCompanyId}`}
                  companyId={selectedCompanyId}
                  locale={locale}
                />
              ) : (
                <HierarchyConfig
                  key={`cfg-${selectedCompanyId}`}
                  companyId={selectedCompanyId}
                  levels={levels}
                  rules={companyRules}
                  locale={locale}
                />
              ))}

            {activeTab === "org-tree" &&
              (mode === "closed" ? (
                <ClosedUnits
                  key={`closed-org-${selectedCompanyId}`}
                  tree="org"
                  companyId={selectedCompanyId}
                  locale={locale}
                  levels={levels}
                  rules={companyRules}
                  units={companyOrgUnits}
                />
              ) : mode === "asof" ? (
                <AsOfUnits
                  key={`asof-org-${selectedCompanyId}`}
                  tree="org"
                  companyId={selectedCompanyId}
                  locale={locale}
                />
              ) : mode === "moves" ? (
                <UnitMoves
                  key={`moves-org-${selectedCompanyId}`}
                  tree="org"
                  companyId={selectedCompanyId}
                  locale={locale}
                />
              ) : (
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
              ))}

            {activeTab === "pos-tree" &&
              (mode === "closed" ? (
                <ClosedUnits
                  key={`closed-pos-${selectedCompanyId}`}
                  tree="pos"
                  companyId={selectedCompanyId}
                  locale={locale}
                  levels={levels}
                  rules={companyRules}
                  units={companyPosUnits}
                />
              ) : mode === "asof" ? (
                <AsOfUnits
                  key={`asof-pos-${selectedCompanyId}`}
                  tree="pos"
                  companyId={selectedCompanyId}
                  locale={locale}
                />
              ) : mode === "moves" ? (
                <UnitMoves
                  key={`moves-pos-${selectedCompanyId}`}
                  tree="pos"
                  companyId={selectedCompanyId}
                  locale={locale}
                />
              ) : (
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
              ))}

            {activeTab === "jobs" &&
              (mode === "closed" ? (
                <ClosedJobs
                  key={`closed-jobs-${selectedCompanyId}`}
                  companyId={selectedCompanyId}
                  locale={locale}
                  departments={companyDepartments}
                />
              ) : (
                <JobCatalog
                  key={`jobs-${selectedCompanyId}`}
                  companyId={selectedCompanyId}
                  departments={companyDepartments}
                  allocations={companyAllocations}
                  locale={locale}
                />
              ))}

            {activeTab === "listings" &&
              (mode === "closed" ? (
                <ClosedListings
                  key={`closed-listings-${selectedCompanyId}`}
                  companyId={selectedCompanyId}
                  locale={locale}
                  orgUnits={companyOrgUnits}
                  departments={companyDepartments}
                />
              ) : mode === "asof" ? (
                <AsOfListings
                  key={`asof-listings-${selectedCompanyId}`}
                  companyId={selectedCompanyId}
                  locale={locale}
                />
              ) : (
                <DepartmentListings
                  key={`listings-${selectedCompanyId}`}
                  companyId={selectedCompanyId}
                  levels={levels}
                  orgUnits={companyOrgUnits}
                  departments={companyDepartments}
                  allocations={companyAllocations}
                  locale={locale}
                />
              ))}

            {activeTab === "allocation" && (
              <AllocationForm
                key={selectedCompanyId}
                companyId={selectedCompanyId}
                locale={locale}
                levels={levels}
              />
            )}

            {activeTab === "headcount" &&
              (mode === "closed" ? (
                <ClosedAllocations
                  key={`closed-hc-${selectedCompanyId}`}
                  companyId={selectedCompanyId}
                  levels={levels}
                  locale={locale}
                />
              ) : mode === "asof" ? (
                <AsOfHeadcount
                  key={`asof-hc-${selectedCompanyId}`}
                  companyId={selectedCompanyId}
                  locale={locale}
                />
              ) : (
                <HeadcountGrid
                  key={`hc-${selectedCompanyId}`}
                  companyId={selectedCompanyId}
                  allocations={companyAllocations}
                  levels={levels}
                  locale={locale}
                  limitReached={allocationsLimitReached}
                />
              ))}
          </>
        )}
      </main>
    </div>
  );
}
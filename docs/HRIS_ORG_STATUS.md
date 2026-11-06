# HRIS ORG Module: Status and History

Last updated: 2026-11-06
Purpose: Where the Organization structure (ORG) module is: scope, decisions, what has been created, stages and open items.
Read together with: `HRIS_PROJECT_OVERVIEW.md` (shared setup and conventions), `HRIS_ORG_FRONTEND_REFERENCE.md` (what the frontend can use), `HRIS_NAMING_CONVENTION.md`

Module code: `ORG`. Stages are written "ORG Stage N". Migration headers that say "roadmap Stage X" mean ORG Stage X.

---

## 1. Scope

**In this module:**

* Org structure: Tenant -> Parent Company -> Business Unit -> Branch -> Division
* Position structure: Department -> Office -> Section -> Group, plus a job catalog (job positions) that belongs to Departments
* Department eligibility per org unit
* Approved headcount allocation (org unit + job + position unit)
* Closing units and reorganizing them
* History: read-only view of closed rules, units, jobs, Department listings and allocations

**Not in this module:** employees, hiring, transfers, promotions (later module, linking to ORG allocations), leave, attendance, payroll.

---

## 2. Requirements and rules

* Users pick from predetermined structures. Invalid combinations are never selectable (no Architect in an IT Department, none in a Banking Division).
* Levels are configurable and optional. **No placeholder records** ("N/A Division", "No Office"). The next active level links directly to its real parent.
* Cascading form: org location -> Department -> Office/Section/Group (filtered) -> eligible Position -> approved headcount.
* Every name supports English and Khmer.
* Rules that must hold: (1) a company cannot use another company's hierarchy; (2) disabling a level never silently invalidates records; (3) employee assignments stay historically consistent; (4) rule changes never rearrange existing records; (5) the design supports future hiring, transfers, promotions and allocation.

---

## 3. Decisions

### Your decisions

| Topic | Decision |
|---|---|
| Config scope | Hierarchy config is per **Parent Company** |
| Catalog | Departments and job positions are a Parent-Company-wide catalog |
| Position tree | Shared catalog, linked to org locations **only through allocations** |
| Reorgs | Needed (rarely) |
| Stage 2b (Khmer level names) | **Skipped for now.** Add later as a small seed migration when names are supplied |
| Roles (9a) | Three starting roles: `tenant_admin`, `hr_admin`, `viewer`. Permissions are stored as codes. Reads stay open to every tenant member. Existing members became `tenant_admin`. Role changes are not logged |
| Role scope (9a) | A role is given for one scope: all companies of the tenant, one company, one org unit (subtree included) or one Department. The narrower scope replaces the broader one |
| 9c permissions | The permission each wrapper checks was built as planned (section 4, "Public write wrappers") |
| History (9i) | History covers closed rules, units, jobs, Department listings and allocations. Closed records are **not re-opened**. To bring something back, create it again (see "Design choices") |

### Design choices

* **Two node tables, one pattern:** `org_unit` (Business Unit, Branch, Division) and `pos_unit` (Department, Office, Section, Group), sharing the level and rule tables.
* **Validity by composite foreign keys**, not triggers, wherever possible.
* **Versioned, never edited:** rules, parent links, eligibility rows and allocations are closed (`valid_to`) and replaced. "Current" means `valid_to is null`, everywhere including the read layer.
* **No re-open:** every guard refuses changing a closed record. Closing cascades (a closed unit also closes its links, listings and allocations), so re-opening would have to undo exactly those and could clash with newer records or a closed rule. To bring something back, create it again: Enable level (rule), Add (unit, job), List the Department again (listing), Allocation form (allocation). A re-created unit gets a new ID. A possible later convenience is a "Re-create" button on a history row that pre-fills the add form (frontend only, not built).
* **History is read-only views:** `*_closed` views (`valid_to is not null`) with the same security as the `*_current` views. Names shown are the current names of units and jobs (a rename changes them everywhere, also in history).
* **Stable IDs:** a unit keeps its ID through a reorg. Its parent lives in an effective-dated link table.
* **Root-level units:** generated `parent_level_key` (0 = directly under the root) is part of the foreign key to the rule.
* **Deferred check:** an open unit must end with an open parent link (checked at commit).
* **Closing cascades:** closing a unit closes its parent link, allocations and eligibility rows. A unit with open children cannot be closed. A Department with open jobs cannot be closed. Closing a job closes its allocations. A Department listing cannot be closed while allocations use it.
* **Rule guard:** closing the last open rule of a level is refused if the level is required, used as a parent by other rules, or has open units (`007`). Other rules of the same level may stay open, so closing one rule of a level is allowed.
* **No company-level allocation:** every allocation sits at an org unit. A flat company enables one org level and creates one unit.
* **Position placement:** an allocation points to the job's own Department or any open descendant of it, at any depth (trigger-checked).

### Reorg behaviour (`009`)

* Moves one unit with its whole subtree. The unit ID never changes. Old link closes, new link opens.
* New parent must be an open unit of the same company, and an open rule must allow the level under it (this also blocks moving a unit under its own descendants).
* Effective date defaults to today and cannot be earlier than the current link's start or the new parent's start. A future date takes effect immediately (no "no future dates" check, because UTC would wrongly reject early-morning Phnom Penh dates).
* Eligibility rows and allocations stay attached to the unit.
* A position unit whose subtree has open allocations cannot move into another Department's tree. Departments cannot move. Org tree moves have no allocation restriction.

### Permission resolution (9a, `private.has_permission`)

* Org side: nearest org unit assignment on the unit or above. Department side: the assignment on that Department.
* If a narrow assignment applies, it decides and company/tenant-wide roles are ignored. Every narrow assignment that applies must hold the permission (restriction wins). A side with no narrow assignment has no say.
* With no narrow assignment: company role, else tenant-wide role, else no.
* Closed, missing, other-company targets (or a non-Department for Department scope) are never valid. An assignment on a unit closed later grants nothing. A scope follows the unit's stable ID, so a reorg keeps the unit's admins.
* Hierarchy rules: company or tenant-wide assignments only.

### Assumptions (not yet confirmed by you)

* Any tenant member sees everything in their tenant for now (this includes history).
* `name_km` is optional, `name_en` is required.
* Business Unit, Branch and Division may each sit directly under the Parent Company.
* Position tree: Department is required and the only top level. Office, Section, Group are optional.
* Khmer level names stay empty until supplied.
* `members.manage` is tenant-wide only.
* Renaming a Department itself needs a company-wide or tenant-wide role (same as creating or closing one). Renaming any other position unit needs `pos.unit.write` at its Department.
* Reference data the system needs (7 levels, roles, permission codes) is seeded inside its own migration (`002`, `012`). Sample and dev data stays outside migrations.

---

## 4. What has been created

All migrations are applied to the dev project. Migrations are one chain shared by all modules (`000`, `001` are shared platform files). Tests for `000` to `013`, `021` and `022` were run and **passed**. Test results for `014` to `020` are **not yet confirmed** (see section 6), although the allocation wrappers (`015`, with `014`) worked in the ORG Stage 9d browser test. `023` and `024` were checked in the browser (ORG Stage 9i test, passed).

| Migration | Test | Purpose |
|---|---|---|
| `000_create_schemas.sql` | n/a | `core` and `private` schemas, minimal grants |
| `001_tenancy.sql` | `001_tenancy_test.sql` | `tenant`, `parent_company`, `tenant_member`, `private.user_tenant_ids()`, RLS |
| `002_hierarchy_levels.sql` | `002_hierarchy_levels_test.sql` | `hierarchy_level` (7 seeded), versioned `company_level_rule`, guard, RLS |
| `003_org_tree.sql` | `003_org_tree_test.sql` | `org_unit`, `org_unit_parent`, guards, `private.create_org_unit` |
| `004_position_tree.sql` | `004_position_tree_test.sql` | `pos_unit`, `pos_unit_parent`, `private.create_pos_unit` |
| `005_jobs_and_eligibility.sql` | `005_jobs_and_eligibility_test.sql` | `job_position`, `org_unit_department` |
| `006_allocation.sql` | passed (file name not recorded) | `position_allocation`, `private.create_allocation`, allocation guard, closing cascades |
| `007_level_disable_guard.sql` | passed (file name not recorded) | Level cannot be disabled while open units exist |
| `008_close_unit.sql` | passed (file name not recorded) | `private.close_org_unit`, `private.close_pos_unit` |
| `009_reorg.sql` | `009_010_reorg_read_layer_test.sql` | `private.reorg_org_unit`, `private.reorg_pos_unit`, `private.pos_department_of` |
| `010_read_layer.sql` | `009_010_reorg_read_layer_test.sql` | Read views and cascade functions in `public` |
| `011_catalog_read_views.sql` | passed (file name not recorded) | `public.parent_companies`, `public.hierarchy_levels` |
| `012_roles.sql` | `012_roles_test.sql` | `app_role`, `permission`, `app_role_permission`, `member_role_scope`, 3 roles, 8 permission codes, scope guard, RLS. Unique `(id, company_id)` on `org_unit` and `pos_unit` |
| `013_has_permission.sql` | `013_has_permission_test.sql` | `private.has_permission`, `private.has_tenant_permission`, `private.role_has_permission` |
| `014_close_allocation.sql` | `014_close_allocation_test.sql` | `private.close_allocation` |
| `015_allocation_wrappers.sql` | `015_allocation_wrappers_test.sql` | `private.create_allocation` replaced, public allocation wrappers |
| `016_org_unit_wrappers.sql` | `016_020_wrappers_test.sql` | Public org unit wrappers, `private.is_company_member` |
| `017_pos_unit_wrappers.sql` | `016_020_wrappers_test.sql` | Public position unit wrappers, `private.can_manage_pos_unit` |
| `018_job_position_functions.sql` | `016_020_wrappers_test.sql` | Private and public job position functions |
| `019_department_listing_functions.sql` | `016_020_wrappers_test.sql` | Private and public Department listing functions |
| `020_level_rule_functions.sql` | `016_020_wrappers_test.sql` | Private and public level rule functions |
| `021_permission_check.sql` | `021_permission_check_test.sql` | `public.check_permissions` (ORG Stage 9e, database part) |
| `022_rename_unit.sql` | `022_rename_unit_test.sql` | `private.rename_org_unit`, `private.rename_pos_unit`, public wrappers `rename_org_unit`, `rename_pos_unit` (ORG Stage 9f-1) |
| `023` (file name not recorded) | browser test (ORG Stage 9i) | Read-only history views `company_level_rules_closed`, `org_units_closed`, `pos_units_closed` (ORG Stage 9i, part 1) |
| `024_history_views_jobs_listings_allocations.sql` | browser test (ORG Stage 9i) | Read-only history views `job_positions_closed`, `org_unit_departments_closed`, `position_allocations_closed` (ORG Stage 9i, part 2) |

### Tables

`core.hierarchy_level`, `core.company_level_rule`, `core.org_unit`, `core.org_unit_parent`, `core.pos_unit`, `core.pos_unit_parent`, `core.job_position`, `core.org_unit_department` (Departments each org unit may use, no inheritance), `core.position_allocation`, plus roles: `core.app_role`, `core.permission`, `core.app_role_permission`, `core.member_role_scope`.

### Public views (read layer)

* **Current** (`010`, `011`): `company_level_rules_current`, `org_units_current`, `pos_units_current`, `org_unit_departments_current`, `job_positions_current`, `position_allocations_current`, `parent_companies`, `hierarchy_levels`.
* **Closed / history** (`023`, `024`, `valid_to is not null`, same security as the current views):
  * `company_level_rules_closed`: level, parent level, start and end date.
  * `org_units_closed`, `pos_units_closed`: name, level, the parent the unit had when it closed, start and end date.
  * `job_positions_closed`: job and its Department's name, start and end date.
  * `org_unit_departments_closed`: org unit and Department names, start and end date.
  * `position_allocations_closed`: same columns as `position_allocations_current` plus `valid_to`.

### Permission codes (seeded in `012`)

| Code | Covers | Narrowest scope checked | Held by |
|---|---|---|---|
| `org.read` | View structure (not enforced, reads are open) | company or tenant | all three roles |
| `org.config.write` | Hierarchy rules | company or tenant | `tenant_admin`, `hr_admin` |
| `org.unit.write` | Create, close, move org units | org unit | `tenant_admin`, `hr_admin` |
| `org.eligibility.write` | List Departments for org units | org unit | `tenant_admin`, `hr_admin` |
| `pos.unit.write` | Create, close, move position units | Department | `tenant_admin`, `hr_admin` |
| `pos.job.write` | Manage job positions | Department | `tenant_admin`, `hr_admin` |
| `org.allocation.write` | Approved headcount allocations | org unit and Department | `tenant_admin`, `hr_admin` |
| `members.manage` | Members and roles | tenant | `tenant_admin` only |

### Private write functions added in 9c (`service_role` only)

| Function | Behaviour |
|---|---|
| `private.close_allocation(company, allocation, close_date)` (`014`) | Allocation must be open and belong to the company. Close date cannot be before the allocation's start. Closes only that allocation. A headcount change is close + create |
| `private.create_allocation` (replaced in `015`) | New `p_start_date`. Refuses a start before the org unit, listing, job or position unit started |
| `private.create_job_position(company, Department, name EN, name KM)` (`018`) | Needs an open Department of the company. English name required, trimmed, unique among the Department's open jobs (clear duplicate message) |
| `private.rename_job_position(company, job, name EN, name KM)` (`018`) | Replaces both names. Empty Khmer name clears it |
| `private.close_job_position(company, job, close date)` (`018`) | Closes the job, the existing guard closes its allocations. Close date cannot be before the job's or its allocations' start |
| `private.add_department_listing(company, org unit, Department, start date)` (`019`) | Open org unit and open Department of the same company. Refuses an already-listed Department. Start date defaults to today and cannot be before the org unit's or Department's start, or the end of an earlier listing of the same pair |
| `private.remove_department_listing(company, org unit, Department, close date)` (`019`) | Closes the open listing. Refused while open allocations use it. Close date cannot be before the listing's start. A listing is found by org unit + Department, not by ID |
| `private.enable_level_rule(company, level, parent level or none)` (`020`) | Adds one rule. Clear messages for unknown level, parent in another tree, parent not higher, rule already enabled. Existing guard still decides "cannot sit under the root" and "parent level not enabled" |
| `private.disable_level_rule(company, rule, close date)` (`020`) | Closes one rule by ID. Close date cannot be before the rule's start. Existing guard still refuses closing a required level, a parent level, or a level with open units |

### Public write wrappers (9c)

All are `security definer`, call `private.has_permission`, and are granted to `authenticated` and `service_role` only.

| Wrapper | Permission and where it is checked |
|---|---|
| `create_allocation`, `close_allocation`, `change_allocation_headcount` (`015`) | `org.allocation.write`. Headcount change closes and recreates in one transaction |
| `create_org_unit(company, level, parent, name EN, name KM)` (`016`) | `org.unit.write` at the parent unit (a role on a unit covers its subtree). No parent: company or tenant-wide role only. Blank English name refused |
| `close_org_unit(company, unit, close date)` (`016`) | `org.unit.write` at the unit |
| `reorg_org_unit(company, unit, new parent, effective date)` (`016`) | `org.unit.write` on the unit and on the new parent. To the root: company or tenant-wide role |
| `create_pos_unit(company, level, parent, name EN, name KM)` (`017`) | `pos.unit.write` at the parent's Department. New Department: company or tenant-wide role. Blank English name refused |
| `close_pos_unit(company, unit, close date)` (`017`) | `pos.unit.write` at the unit's Department. Closing a Department itself: company or tenant-wide role only |
| `reorg_pos_unit(company, unit, new parent, effective date)` (`017`) | `pos.unit.write` on the unit's Department and the new parent's Department. To the top: company or tenant-wide role. Departments still cannot move |
| `create_job_position`, `rename_job_position`, `close_job_position` (`018`) | `pos.job.write` at the job's Department (a Department-scoped admin manages only their own Department's jobs) |
| `add_department_listing`, `remove_department_listing` (`019`) | `org.eligibility.write` at the org unit (a Branch role covers its Divisions). Department-scoped roles have no say (agreed in 9a) |
| `enable_level_rule`, `disable_level_rule` (`020`) | `org.config.write` at company or tenant level only |

**Helpers:** `private.is_company_member(company)` (`016`, replaces the repeated tenant-membership query in the allocation wrappers, which are otherwise unchanged). `private.can_manage_pos_unit(company, unit)` (`017`, the "may the caller change this unit" rule shared by close and reorg).

**Error behaviour** (same pattern for org and position units, wording says "org units" or "position units"):

* Not a member, or no permission: "You do not have permission to manage org units here" (42501).
* A member naming a unit that is not open in the company: a plain "not an open unit" message.
* Level rules: a non-member asking about an unknown rule gets only "no permission"; a member gets "Rule % is not an open rule of this company".
* Everything else (rules, dates, "unit still has active units under it") comes from the private functions.

### Permission check for the frontend (9e, `021`)

`public.check_permissions(p_company_id, p_permission_code, p_targets)` closes gap G8 on the database side.

* `p_targets` is a JSON array of `{org_unit_id, department_id}` objects (either key can be missing or null). Default is one empty target, for company-level permissions such as `org.config.write`. At most 500 targets per call.
* Returns `org_unit_id`, `department_id`, `allowed` for each distinct target.
* Calls `private.has_permission`, the same check the write wrappers use, so the frontend and the database cannot disagree. A caller who is not logged in or not a member gets `allowed = false` for everything.
* Which key matters: `org.allocation.write` org unit and Department; `org.unit.write` and `org.eligibility.write` org unit; `pos.unit.write` and `pos.job.write` Department; `org.config.write` none.
* Granted to `authenticated` and `service_role` only. It only hides what would fail. The wrappers still check on every write.

### Current versions of replaced functions

Start from the **latest** version when changing these:

* `private.company_level_rule_guard()` -> `007`
* `private.org_unit_guard()`, `private.pos_unit_guard()`, `private.job_position_guard()`, `private.org_unit_department_guard()` -> `006`
* `private.position_allocation_guard()` -> `006`
* `private.create_allocation` -> `015`

### Dev seed data (not migrations, dev only)

* `seed_dev_tenant.sql`: 1 tenant ("Dev Tenant"), 1 parent company ("Dev Parent Company"), membership for `mek.rotha@gmail.com`. Refuses to run if `core.tenant` has rows.
* `seed_dev_org_sample.sql`: 8 level rules, 6 org units, 6 position units, 6 Department listings, 5 jobs, 1 allocation (Software Engineer, Head Office, Backend Section, headcount 5). Inserts rules, listings and jobs straight into `core` and uses the private create functions for the rest. Refuses to run if the company already has ORG data. Khmer names are test samples.

### Frontend files (ORG Stages 8, 9d, 9e, 9f, 9g, 9h and 9i)

| File | What it does |
|---|---|
| `lib/supabase/client.ts`, `lib/supabase/server.ts` | Supabase clients typed with `<Database>` from `./database.types` |
| `proxy.ts` | Refreshes the session cookie, redirects signed-out visitors to `/login` and signed-in users away from it |
| `app/login/page.tsx` | Sign-in form (`signInWithPassword`) |
| `lib/i18n.ts` | `displayName(locale, nameEn, nameKm)`: Khmer when active and not empty, else English |
| `modules/org/types.ts` | Narrowed types: `ParentCompany`, `HierarchyLevel`, `CompanyLevelRule`, `UnitRow`, `UnitOption`, `JobOption`, `PositionAllocation`. **9g:** also `JobRow` (open job: ID, company, Department, names, start date) and `ListingRow` (open Department listing: ID, company, org unit, Department, start date). **9i:** also `ClosedRuleRow`, `ClosedUnitRow`, `ClosedAllocationRow` (`PositionAllocation` plus `valid_to`), `ClosedJobRow`, `ClosedListingRow` |
| `lib/dates.ts` | `todayInPhnomPenh()` (default for date fields, the server runs on UTC) and `isIsoDate()` |
| `modules/org/queries.ts` | **9f:** also `createUnit`, `renameUnit`, `closeUnit`, `reorgUnit` (one set for both trees, pass `"org"` or `"pos"`, with a readable message mapping for raw constraint errors). Browser wrappers for `org_options`, `pos_options`, `eligible_departments`, `eligible_jobs`, `fetchExistingAllocation`. **9d:** also `createAllocation`, `changeAllocationHeadcount`, `closeAllocation`, `MAX_HEADCOUNT`, and a message mapping for raw constraint errors (`23505`, `23514`, `23503`). Permission (`42501`) and rule messages pass through. **9g:** also `fetchJobs` and `fetchListings` (read `job_positions_current` and `org_unit_departments_current`, rows with an empty key column are skipped) and the writes `createJob`, `renameJob`, `closeJob`, `addListing`, `removeListing`. New `rpcWriteError` is shared by the unit, job and listing writes: it replaces raw constraint errors (`23505`, `23503`, `23514`) with "This change is not valid any more. Refresh the page and try again.", other messages pass through. Allocation writes keep `writeError`. **9h:** also `enableLevelRule` and `disableLevelRule`. **9i:** also `fetchClosedRules`, `fetchClosedUnits` (one function for both trees), `fetchClosedAllocations`, `fetchClosedJobs`, `fetchClosedListings`. Each reads its `*_closed` view for one company, newest closed first, skipping rows with an empty key column. Not paged (Supabase returns at most 1000 rows per request) |
| `modules/org/permissions.ts` | **9e, new.** `checkPermissions(company, code, targets)` calls `check_permissions` in batches of up to 500 targets (any error = not allowed). `usePermissions(company, code, targets)` hook returns `can(orgUnitId, departmentId)` (false until the answer arrives) and `isLoading`. Constants `PERM_ALLOCATION_WRITE`, `PERM_ORG_UNIT_WRITE`, `PERM_POS_UNIT_WRITE`. **9g:** also `PERM_JOB_WRITE` (`pos.job.write`) and `PERM_ELIGIBILITY_WRITE` (`org.eligibility.write`). **9h:** also `PERM_CONFIG_WRITE` (`org.config.write`) |
| `modules/org/labels.ts` | `levelLabel()` in the active language, falls back to the level code. **9i:** also `ROOT_LABEL` (what "no parent" means in each tree, used by the level tables and the history views) |
| `modules/org/components/AsyncSelect.tsx` | Dropdown that loads its own options, shows a reason when empty, reset with a `key`. Also exports `selectClassName` |
| `modules/org/components/CascadeSelector.tsx` | One dropdown per level, user can stop at any depth |
| `modules/org/components/OrgTreeExplorer.tsx` | Expandable tree with Expand all / Collapse all (org and position trees). **9f:** optional `manage` prop adds Add, Rename, Move and Close buttons per unit and "Add top-level unit", shown only where `check_permissions` allows (one batched call). Refreshes the page after each save |
| `modules/org/components/UnitActionDialog.tsx` | **9f, new.** One modal for add, rename, close and move. Add offers only the levels the company's rules allow under that parent. Move offers only valid parents (never the unit itself or anything below it). Close is blocked in the form while open units are under it |
| `modules/org/unitTree.ts` | **9f, new.** Pure helpers: `descendantIds`, `departmentIdOf`, `childLevelRules`, `moveTargets` |
| `modules/org/components/AllocationForm.tsx` | Org location -> Department -> position unit -> job -> headcount and start date. Duplicate check. **9d:** Save calls `create_allocation`, is blocked while the duplicate check runs or when an open allocation exists, clears job and headcount after saving, and refreshes the data. **9e:** Save is disabled with a reason when the user lacks `org.allocation.write` for the selected org unit and Department |
| `modules/org/components/AllocationActionDialog.tsx` | **9d, new.** Modal to change the headcount of one allocation or close it, with an effective or close date |
| `modules/org/components/HeadcountGrid.tsx` | Open allocations with search, org unit and Department filters, totals. Not paged. **9d:** Change and Close buttons on every row (new `companyId` prop). **9e:** one batched permission check for all rows. Change and Close show only where allowed, other rows show "View only" |
| `modules/org/components/Modal.tsx` | **9g, new.** Shared modal frame: title, content, error line, Cancel and submit buttons (submit disabled while saving or when `canSubmit` is false). Used by `JobDialog`, `ListingDialog` and `LevelRuleDialog` |
| `modules/org/components/JobCatalog.tsx` | **9g, new.** Jobs tab. Loads open jobs with `fetchJobs`, search by name, Department filter, "Showing x of y", sorted by Department then job name. Shows open allocations per job. Add job position button shows only if the user has `pos.job.write` for at least one Department. Rename and Close per row show only where allowed (one batched check), other rows show "View only". Shows a message when the company has no Department. Reloads its list and refreshes the page after each save |
| `modules/org/components/JobDialog.tsx` | **9g, new.** Modal to add, rename or close one job. Add: Department (only Departments the user may write to), English name (required), Khmer name (optional); the job starts on the server's date. Rename: Save is disabled until a name changed. Close: close date (defaults to today's Phnom Penh date) and a note on how many open allocations close with the job |
| `modules/org/components/DepartmentListings.tsx` | **9g, new.** Department listings tab. One row per org unit (sorted by level, then name) with its listed Departments. Loads listings with `fetchListings`. Add Department and the remove (✕) button show only where the user has `org.eligibility.write` at that org unit (one batched check), other rows show "View only". Add is disabled when every Department is already listed. Reloads and refreshes the page after each save |
| `modules/org/components/ListingDialog.tsx` | **9g, new.** Modal to list a Department for an org unit (Department not yet listed there, start date) or remove a listing (close date). Remove is blocked in the form while open allocations use the listing, and tells the user to close them on the Headcount tab first |
| `modules/org/components/HierarchyConfig.tsx` | **9h, new.** Configuration tab: the org and pos level tables (status, allowed parents). "Enable level" or "Add parent option" per level and "Disable" per rule, shown only where the user has `org.config.write` (company-level check, one empty target). Parent choices are the root (only if the level can be root) or an enabled higher level of the same tree, never one that already exists. The button is disabled with a hint when no choice is left. Refreshes the page after each save |
| `modules/org/components/LevelRuleDialog.tsx` | **9h, new.** Modal (uses `Modal`) to enable a level under a parent (the rule starts on the server's date) or disable one rule (close date, default today's Phnom Penh date, not before the rule's start). Database guard messages (`007`, `020`) are shown in the dialog |
| `modules/org/components/HistoryToggle.tsx` | **9i, new.** "Current / Closed (history)" switch shown at the top of a tab |
| `modules/org/components/ClosedRules.tsx` | **9i, new.** Closed level rules of both trees (level, what it was allowed under, started, closed) |
| `modules/org/components/ClosedUnits.tsx` | **9i, new.** Closed org or position units (one component, `tree` prop): name, level, the parent it had when it closed, started, closed. Search by name |
| `modules/org/components/ClosedAllocations.tsx` | **9i, new.** Closed allocations (headcount history): org unit, Department, position unit, job, approved headcount, started, closed. Search, org unit and Department filters. A headcount change shows as one closed row with the old headcount |
| `modules/org/components/ClosedJobs.tsx` | **9i, new.** Closed job positions: Department, job, started, closed. Search and Department filter |
| `modules/org/components/ClosedListings.tsx` | **9i, new.** Closed Department listings: org unit, Department, started, closed. Search and Department filter |
| `modules/org/components/OrgConfigView.tsx` | Header (company selector, EN / ខ្មែរ switch, sign out) and tabs: Configuration, Org tree, Position tree, Jobs, Department listings, Allocation form, Headcount. **9d:** passes `companyId` to the grid. **9g:** two new tabs, Jobs and Department listings. Departments are the position units with no parent, passed to both new tabs. Each tab is keyed by company. **9h:** the Configuration tab renders `HierarchyConfig`. **9i:** a `HistoryToggle` on six tabs (Configuration, Org tree, Position tree, Jobs, Department listings, Headcount). Closed shows the matching closed list instead of the current screen. The toggle goes back to Current when you switch tabs. The Allocation form tab has no history |
| `app/page.tsx` | Server loader inside `<Suspense>`: companies, levels, rules, org and position units, current allocations |

### How tests work

Plain SQL files. Paste one into Supabase Dashboard -> SQL Editor (dev project only). Each rolls back at the end. "Success. No rows returned" means pass. An error starting with `FAIL:` means a check failed. Tests `009_010`, `012` and `013` create temporary users and switch role to `authenticated` and `anon`. Tests `012` and `013` need `seed_dev_org_sample.sql`. `016_020_wrappers_test.sql` covers the wrappers and private functions of `016` to `020`. `021_permission_check_test.sql` uses temporary users and the sample data like `013`. `022_rename_unit_test.sql` needs the sample data and a `tenant_admin` user (set `v_admin_email` at the top). The history views (`023`, `024`) were checked in the browser, there is no SQL test file for them.

---

## 5. ORG stages

| Stage | Name | Deliverable | State |
|---|---|---|---|
| 0-1 | Schemas, tenancy | `000`, `001` | Done, passed |
| 2 | Level catalog and company rules | `002` | Done, passed |
| 3 | Org tree | `003` | Done, passed |
| 4 | Position tree, jobs, eligibility | `004`, `005` | Done, passed |
| 5 | Allocation and headcount | `006` | Done, passed |
| 6a / 6b / 6c | Level disable guard, close functions, reorg functions | `007`, `008`, `009` | Done, passed |
| 7 / 7b | Read layer, catalog read views | `010`, `011` | Done, passed |
| 2b | Khmer level names | Small seed migration | **Skipped for now** |
| 8a-8d | Read-only frontend: foundation, config screen, trees and allocation form, headcount grid | Section 4 | Done, passed |
| 9a | Roles and permissions design | Section 3 | Done, agreed |
| 9b-1 / 9b-2 | Role tables, permission check | `012`, `013` | Done, passed |
| 9c | Write wrappers: allocations, org units, position units, jobs, Department listings, level rules | `014` to `020` | Done, passed |
| 9d | Allocation save and headcount grid actions | Allocation form Save calls `create_allocation` (start date, duplicate check). Headcount grid row actions: change headcount and close, each with an effective date. Clear message on `42501`, lists refresh after save. Date fields default to today's Phnom Penh date. Frontend only | Done, passed |
| 9e | Own permissions and role-aware buttons | **Database:** `021` `public.check_permissions` (closes gap G8). **Frontend:** permission helper (`modules/org/permissions.ts`), then disable Save on the allocation form and hide Change/Close on the headcount grid when not allowed | **Done, passed** (database and frontend) |
| 9f | Org tree and position tree management | **Database:** `022` rename functions and wrappers. **Frontend:** add, rename, move and close units on both trees (`OrgTreeExplorer` with `manage`, `UnitActionDialog`, `unitTree.ts`), buttons hidden by `check_permissions` | **Done, passed** |
| 9g | Job catalog and Department listings | Screens for `create/rename/close_job_position` and `add/remove_department_listing`. **Jobs tab:** list with search and Department filter, add, rename, close (closing also closes the job's allocations). **Department listings tab:** per org unit, add a Department or remove a listing with a start or close date, removal blocked in the form while allocations use it. Buttons hidden by `check_permissions` (`pos.job.write` at the Department, `org.eligibility.write` at the org unit). Frontend only | **Done, passed** |
| 9h | Hierarchy configuration screen | Enable a level under a parent and disable one rule (`enable_level_rule`, `disable_level_rule`) on the Configuration tab (`HierarchyConfig`, `LevelRuleDialog`). Buttons hidden by `check_permissions` (`org.config.write`). Frontend only | **Done.** Disabling was confirmed in the browser (guard message seen, then Section "Under Office" and Office disabled). Enabling a level was not separately recorded |
| 9i | History view (closed rules, units, jobs, listings, allocations) | **Database:** `023` (closed rules and units views) and `024` (closed jobs, listings and allocations views), read-only. **Frontend:** a Current / Closed (history) toggle on six tabs, with `ClosedRules`, `ClosedUnits`, `ClosedAllocations`, `ClosedJobs`, `ClosedListings` and `HistoryToggle` | **Done, passed** |

**Remaining ORG work: none planned.** Optional items are listed below.

Not counted in the stages:

* **Members, roles and setup** (create tenant, company, membership, give and remove roles). Probably a platform stage rather than ORG, handled as its own module.
* **Optional:** Khmer level names (2b), paging the headcount grid and the history lists, a "Re-create" button on history rows (pre-fills the add form).

Employee hooks (hiring, transfers, promotions) belong to a later Employee module, not ORG.

---

## 6. Where we are now

1. ORG Stages 0 to 9i are complete. The database (`000` to `024`) is applied to the dev project.
2. **Permissions are enforced on writes** through the wrappers. Reads are still open to every tenant member (history included). The private write functions stay `service_role` only.
3. The frontend can read and manage everything in the ORG scope: levels (9h), units on both trees (9f), jobs and Department listings (9g), allocations and headcount (9d, 9e), and shows closed records on six tabs (9i). Buttons are hidden by `check_permissions` where the user lacks the permission.
4. Skipped for now: ORG Stage 2b (Khmer level names).
5. Next: decide the next module or platform stage (members, roles and setup, section 5). Nothing further is planned in ORG.

### Still missing

* Write functions not covered by `014` to `022`: create tenant, company and membership (do these by hand with `service_role`; a member added later has no role until one is given).
* **Role management:** no function or screen gives or removes roles. A user sees only their own assignments (row level security). Decide who may see all assignments in a tenant when the members screen is built. Nothing stops the last `tenant_admin` from being removed.
* **Paging:** the headcount grid and the history lists are not paged. Supabase returns at most 1000 rows per request, so a list or total would be too low beyond that. Fix when real data volume is known.

### Pending from you

* Confirm the tests `014_close_allocation_test.sql`, `015_allocation_wrappers_test.sql` and `016_020_wrappers_test.sql` passed.
* Confirm the ORG Stage 9h enable-level browser test (enable a level, new levels appear in the tree screens).
* Confirm the file names of migration `023` and its test, if you want them recorded.
* Confirm the assumptions in section 3.
* Supply the Khmer names for the 7 levels when ready.
* Test file names for `006`, `007`, `008` and `011` if you want them recorded.

---

## 7. Lessons (ORG only)

* Migration numbers and ORG stages are not the same thing (for example ORG Stage 9c is migrations `014` to `020`; ORG Stage 5 is `006`; ORG Stages 6a/6b/6c are `007`/`008`/`009`; ORG Stage 9i is `023` and `024`).
* An empty dev database shows "No companies visible for your account". This is expected until a tenant, a company and a `tenant_member` row exist. Check those three tables before debugging frontend code.
* Departments are not created under a Business Unit or the Parent Company. Create a Department on the Position tree tab ("Add top-level unit"), then list it for an org unit on the Department listings tab. Listings sit on org units only (not on the Parent Company) and are not inherited, so each Business Unit, Branch or Division that needs the Department needs its own listing.
* The current screens show only open records (`valid_to is null`). A closed record is not deleted: it stays in `core` and shows under **Closed (history)** on its tab.
* A level cannot be disabled while another open rule uses it as parent. The blocker is a **rule**, not a unit, so it never shows on the tree screens. Example: Office could not be disabled because Section still had an open rule "Under Office". Disable the child rules first (for example Section and Group "Under Office"), then the parent level. Closing one rule of a level is allowed while another open rule of that level remains (Section "Under Department" can stay). To find the blocker, check the open rules of the company in `core.company_level_rule` (`valid_to is null`).
* Closed records are never re-opened. Create them again instead (section 3, "Design choices").
* When a database function gains new views or columns, regenerate `database.types.ts` before writing the frontend queries, so the narrowing code matches the real columns.

Project-wide lessons are in `HRIS_PROJECT_OVERVIEW.md`, section 6.

---

## 8. How to resume ORG work

1. Open a new chat in the same Project and attach `HRIS_PROJECT_OVERVIEW.md`, this file and `package.json`.
2. For any ORG frontend change, also attach `HRIS_ORG_FRONTEND_REFERENCE.md`, the file list of `app/`, `lib/supabase/` and `modules/org/`, `database.types.ts`, and the files the change builds on (section 4).
3. For database changes, attach the migration files the change depends on. If a guard function is involved, use the latest version (section 4, "Current versions of replaced functions").
4. Say which stage you are on and paste any error text exactly.
5. If a file is missing, say so and Claude will ask whether to generate it.

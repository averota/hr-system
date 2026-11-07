# HRIS ORG Status

Last updated: 2026-11-07
Purpose: The plan and progress of the Organization structure (ORG) module: Stages planned and passed, tasks, files created, tests, issues, next steps and known limitations. What the module is, and why, is in the Blueprint.
Read together with: `HRIS_PROJECT_OVERVIEW.md`, `HRIS_ORG_BLUEPRINT.md`, `HRIS_ORG_FRONTEND_REFERENCE.md`

Module code: `ORG`. Stages are written "ORG Stage N". Migration headers that say "roadmap Stage X" mean ORG Stage X.

*Update rule: at the end of each Stage, update sections 1 to 6 and 8 in one go, and the module row in `HRIS_MODULE_REGISTER.md` if the state changed.*

---

## 1. Where we are

| Item | Value |
|---|---|
| Phase now | P4-P5 (Stage 9l passed for units, jobs and listings) |
| Blueprint state | Written after the build began (not gated). Awaiting your approval. See Blueprint section 5. Updated for 9k and 9l on 2026-11-07 |
| Current Stage | None in progress |
| Last Stage passed | ORG Stage 9l: Re-create on closed units, jobs and Department listings (browser checks passed on 2026-11-07). Before it, ORG Stage 9k (`028`) |
| Next | Update `HRIS_ORG_FRONTEND_REFERENCE.md` (`ORG-T009`, waits for `queriesHistory.ts`), then the gap fixes (`ORG-T020` to `ORG-T022`) |
| Blocking | None. `ORG-T022` waits for the Khmer names |

* The database (`000` to `028`) is applied to the dev project. `028` has no SQL test file (checked in the browser).
* **Permissions are enforced on writes** through the wrappers. Reads are open to every tenant member, history included. The private write functions stay `service_role` only.
* The frontend can read and manage everything in the ORG scope: levels (9h), units on both trees (9f), jobs and Department listings (9g), allocations and headcount (9d, 9e). Closed records show on six tabs (9i). As of date views exist on the Org tree, Position tree, Department listings and Headcount tabs, and a Moves (reorg) view on both trees (9k). Buttons are hidden by `check_permissions` where the user lacks the permission.
* Gap fixes planned after 9l (section 3): 1000-row warning (`ORG-T020`), Phnom Penh date defaults (`ORG-T021`), Khmer level names (`ORG-T022`, Stage 2b).

---

## 2. Stage plan

*Blueprint references use the IDs of `HRIS_ORG_BLUEPRINT.md`. "Depends on" follows the build order.*

| Stage | Capability | Blueprint items covered | Migrations | Frontend | Depends on | State |
|---|---|---|---|---|---|---|
| 0-1 | Schemas and tenancy | Overview 5.2 | `000`, `001` | none | none | Passed |
| 2 | A company sets its level rules | 4.2 (`hierarchy_level`, `company_level_rule`), `ORG-D01`, `ORG-D16` | `002` | none | 0-1 | Passed |
| 2b | Khmer level names | `ORG-D05`, `ORG-Q05` | A small seed migration (`ORG-T022`) | none | 2 | **Planned (needs the names)** |
| 3 | Org tree | `ORG-D14`, `ORG-D18`, `ORG-D19`, `ORG-D20` | `003` | none | 2 | Passed |
| 4 | Position tree, jobs, eligibility | `ORG-D02`, `ORG-D03`, `ORG-D14` | `004`, `005` | none | 3 | Passed |
| 5 | Allocation and headcount | `ORG-D21`, `ORG-D23`, `ORG-D24` | `006` | none | 3, 4 | Passed |
| 6a | Level disable guard | `ORG-D22` | `007` | none | 2, 3 | Passed |
| 6b | Close functions | `ORG-D21` | `008` | none | 3, 4, 5 | Passed |
| 6c | Reorg functions | `ORG-D04`, `ORG-D25` | `009` | none | 3, 4, 6b | Passed |
| 7 / 7b | Read layer and catalog read views | 4.5, 4.6 | `010`, `011` | none | 2 to 6c | Passed |
| 8a-8d | Read-only frontend: foundation, config screen, trees and allocation form, headcount grid | 3.1 | none | Section 5.2 | 7 / 7b | Passed |
| 9a | Roles and permissions design | `ORG-D06`, `ORG-D07`, `ORG-D26` | none (design) | none | 7 | Passed (agreed) |
| 9b-1 / 9b-2 | Role tables, permission check | 4.4 | `012`, `013` | none | 9a | Passed |
| 9c | Write wrappers: allocations, org units, position units, jobs, Department listings, level rules | `ORG-D08`, 4.4 | `014` to `020` | none | 9b | Passed |
| 9d | Allocation save and headcount grid actions (create, change headcount, close, each with an effective date; date fields default to today's Phnom Penh date) | 1.2 (workflow 5) | none | Frontend only | 9c | Passed |
| 9e | Own permissions and role-aware buttons (`public.check_permissions`, permission helper, buttons hidden or disabled where not allowed) | 4.4 | `021` | `modules/org/permissions.ts` and screens | 9c | Passed |
| 9f | Org tree and position tree management: rename functions and wrappers, then add, rename, move and close units on both trees | 3.2, 4.3 | `022` | `OrgTreeExplorer` (`manage`), `UnitActionDialog`, `unitTree.ts` | 9e | Passed |
| 9g | Job catalog and Department listings screens | 1.2 (workflows 3, 4) | none | Jobs tab, Department listings tab | 9e | Passed |
| 9h | Hierarchy configuration screen (enable a level under a parent, disable one rule) | 1.2 (workflow 1) | none | `HierarchyConfig`, `LevelRuleDialog` | 9e | Passed (disabling and enabling confirmed in the browser, guard message seen) |
| 9i | History view of closed rules, units, jobs, listings and allocations (Current / Closed toggle on six tabs) | `ORG-D09`, `ORG-D17` | `023`, `024` | `Closed*` lists, `HistoryToggle` | 9c | Passed |
| 9j | Name history, then reverted (a corrected name shows everywhere regardless of date). Trimmed names in the create functions stay | `ORG-D11` (reversed) | `026`, `027` | none | 9i | **Passed (reverted)** |
| 9k | History reads: reorg history views and as-of functions (`028`), as-of views on both trees, Headcount and Department listings, Moves (reorg) view | `ORG-D12`, `ORG-D13`, `ORG-Q09` | `028` | `queriesHistory.ts`, `AsOf*`, `UnitMoves`, `HistoryToggle` | 9i | **Passed** |
| 9l | Re-create button on history rows of units, jobs and Department listings: opens the add dialog pre-filled from the closed record, disabled when the old parent, org unit or Department is closed. Frontend only. Closed level rules and allocations were left out on purpose (create them again by hand) | `ORG-D09`, 3.2 (journey 4) | none | `ClosedUnits`, `ClosedJobs`, `ClosedListings` and their add dialogs | 9i, 9k | **Passed (units, jobs, listings)** |
| Platform | Last tenant admin guard (belongs to the members, roles and setup work) | `ORG-D10` | `025` | none | `012` | Applied to dev. Test passed (2026-11-07) |

**Not counted in the stages**

* **Members, roles and setup** (create tenant, company, membership, give and remove roles): a platform stage, handled as its own module (`PLT`). Planning document first (section 6, step 6). The last tenant admin guard (`025`) is already written.
* **Optional:** paging the headcount grid and the history lists (after the 1000-row warning, `ORG-T020`).
* Employee hooks (hiring, transfers, promotions) belong to a later module (`LCY`), not ORG.

---

## 3. Task list

*Tasks of the current Stage and the next one only.*

| Task | Stage | Task | Type | Blueprint ref | Who | State | Done on | Note |
|---|---|---|---|---|---|---|---|---|
| `ORG-T008` | 9k | `028_history_reads_test.sql` (SQL test) | SQL test | 4.8 | Claude | To do (optional) | | Needs `026_trimmed_names_test.sql` as a template (or `001_tenancy.sql`). The four as-of functions and the two link views were checked in the browser only |
| `ORG-T009` | 9k, 9l | Update `HRIS_ORG_FRONTEND_REFERENCE.md`: the `028` objects, the 9k and 9l frontend files, gaps G6, G7, G9, source map | Document | | Claude | To do | | Needs `queriesHistory.ts` (parameter names of the `028` functions). The Blueprint is done |
| `ORG-T020` | Gap | Show a visible warning when a list or total reaches 1000 rows (Supabase limit): Headcount grid, six Closed lists, as-of views, Moves, Jobs, Department listings. One shared warning, used by every list | Frontend | `ORG-Q11` | Claude | To do | | Needs `queries.ts`, `queriesHistory.ts` and the list components (section 7) |
| `ORG-T021` | Gap | Server-date defaults use the Phnom Penh date (UTC+7) instead of UTC in `create_org_unit`, `create_pos_unit`, `create_job_position`, `enable_level_rule` and the rename functions. New migration | Migration | `ORG-Q10` (settled) | Claude | To do | | Needs the latest function files (section 7). Also check the other functions for the same default |
| `ORG-T022` | 2b | Seed the Khmer names of the 7 levels (small seed migration on `hierarchy_level`) | Migration | `ORG-D05`, `ORG-Q05` | You / Claude | Blocked | | Needs the 7 Khmer names from you and `002_hierarchy_levels.sql` |

---

## 4. Stage log

Stages 0 to 9k all passed (SQL tests and browser checks, file by file in section 5). Dates were not recorded before 2026-11-07. Notes still needed: 2b is planned (`ORG-T022`); 9j name history was added and reverted (`027`); `028` was checked in the browser only (`ORG-T008`).

---

## 5. Files

Migrations `000` to `028` are applied to the dev project. Migrations are one chain shared by all modules (`000`, `001` are shared platform files).

### 5.1 Migrations and tests

| File | Stage | What it adds | Test file |
|---|---|---|---|
| `000_create_schemas.sql` | 0-1 | `core` and `private` schemas, minimal grants | n/a |
| `001_tenancy.sql` | 0-1 | `tenant`, `parent_company`, `tenant_member`, `private.user_tenant_ids()`, RLS | `001_tenancy_test.sql` |
| `002_hierarchy_levels.sql` | 2 | `hierarchy_level` (7 seeded), versioned `company_level_rule`, guard, RLS | `002_hierarchy_levels_test.sql` |
| `003_org_tree.sql` | 3 | `org_unit`, `org_unit_parent`, guards, `private.create_org_unit` | `003_org_tree_test.sql` |
| `004_position_tree.sql` | 4 | `pos_unit`, `pos_unit_parent`, `private.create_pos_unit` | `004_position_tree_test.sql` |
| `005_jobs_and_eligibility.sql` | 4 | `job_position`, `org_unit_department` | `005_jobs_and_eligibility_test.sql` |
| `006_allocation.sql` | 5 | `position_allocation`, `private.create_allocation`, allocation guard, closing cascades | passed (file name not recorded) |
| `007_level_disable_guard.sql` | 6a | Level cannot be disabled while open units exist | passed (file name not recorded) |
| `008_close_unit.sql` | 6b | `private.close_org_unit`, `private.close_pos_unit` | passed (file name not recorded) |
| `009_reorg.sql` | 6c | `private.reorg_org_unit`, `private.reorg_pos_unit`, `private.pos_department_of` | `009_010_reorg_read_layer_test.sql` |
| `010_read_layer.sql` | 7 | Read views and cascade functions in `public` | `009_010_reorg_read_layer_test.sql` |
| `011_catalog_read_views.sql` | 7b | `public.parent_companies`, `public.hierarchy_levels` | passed (file name not recorded) |
| `012_roles.sql` | 9b-1 | `app_role`, `permission`, `app_role_permission`, `member_role_scope`, 3 roles, 8 permission codes, scope guard, RLS. Unique `(id, company_id)` on `org_unit` and `pos_unit` | `012_roles_test.sql` |
| `013_has_permission.sql` | 9b-2 | `private.has_permission`, `private.has_tenant_permission`, `private.role_has_permission` | `013_has_permission_test.sql` |
| `014_close_allocation.sql` | 9c | `private.close_allocation` | `014_close_allocation_test.sql` |
| `015_allocation_wrappers.sql` | 9c | `private.create_allocation` replaced, public allocation wrappers | `015_allocation_wrappers_test.sql` |
| `016_org_unit_wrappers.sql` | 9c | Public org unit wrappers, `private.is_company_member` | `016_020_wrappers_test.sql` |
| `017_pos_unit_wrappers.sql` | 9c | Public position unit wrappers, `private.can_manage_pos_unit` | `016_020_wrappers_test.sql` |
| `018_job_position_functions.sql` | 9c | Private and public job position functions | `016_020_wrappers_test.sql` |
| `019_department_listing_functions.sql` | 9c | Private and public Department listing functions | `016_020_wrappers_test.sql` |
| `020_level_rule_functions.sql` | 9c | Private and public level rule functions | `016_020_wrappers_test.sql` |
| `021_permission_check.sql` | 9e | `public.check_permissions` (ORG Stage 9e, database part) | `021_permission_check_test.sql` |
| `022_rename_unit.sql` | 9f | `private.rename_org_unit`, `private.rename_pos_unit`, public wrappers `rename_org_unit`, `rename_pos_unit` (ORG Stage 9f-1) | `022_rename_unit_test.sql` |
| `023` (file name not recorded) | 9i | Read-only history views `company_level_rules_closed`, `org_units_closed`, `pos_units_closed` (ORG Stage 9i, part 1) | browser test (ORG Stage 9i) |
| `024_history_views_jobs_listings_allocations.sql` | 9i | Read-only history views `job_positions_closed`, `org_unit_departments_closed`, `position_allocations_closed` (ORG Stage 9i, part 2) | browser test (ORG Stage 9i) |
| `025_last_tenant_admin_guard.sql` (platform) | Platform (written for ORG) | Trigger on `core.member_role_scope` that refuses deleting or downgrading the last tenant-wide `tenant_admin`, also through removing the member or the auth user. **Applied to dev. Test passed (2026-11-07)** | `025_last_tenant_admin_guard_test.sql` |
| `026_name_history.sql` | 9j | `private.create_org_unit` and `private.create_pos_unit` replaced (names trimmed, an empty Khmer name stored as null, blank English name refused). The name history part was removed by `027` | `026_trimmed_names_test.sql` |
| `027_revert_name_history.sql` | 9j | Drops the name history triggers, function and table. Nothing else changes | `026_trimmed_names_test.sql` |
| `028_history_reads.sql` | 9k | Views `org_unit_parent_links_closed`, `pos_unit_parent_links_closed` (closed parent links, `unit_valid_to` empty = the unit is still open, so the link ended by a reorg). Functions `org_units_as_of`, `pos_units_as_of`, `position_allocations_as_of`, `org_unit_departments_as_of` (each `(company, date)`, date required). Date rule: `valid_to` is the last valid day, inclusive. Where two rows touch on one date the later start wins, then the higher id. Nothing in `core` changes | browser test (ORG Stage 9k). No SQL test file (`ORG-T008`) |

**How tests work.** Plain SQL files. Paste one into Supabase Dashboard -> SQL Editor (dev project only). Each rolls back at the end. "Success. No rows returned" means pass. An error starting with `FAIL:` means a check failed. Tests `009_010`, `012` and `013` create temporary users and switch role to `authenticated` and `anon`. Tests `012` and `013` need `seed_dev_org_sample.sql`. `016_020_wrappers_test.sql` covers the wrappers and private functions of `016` to `020`. `021_permission_check_test.sql` uses temporary users and the sample data like `013`. `022_rename_unit_test.sql` needs the sample data and a `tenant_admin` user (set `v_admin_email` at the top). The history views (`023`, `024`) and the `028` objects were checked in the browser, there is no SQL test file for them. `026_trimmed_names_test.sql` creates its own tenant and company and needs no sample data.

### 5.2 Frontend files (ORG Stages 8, 9d, 9e, 9f, 9g, 9h, 9i and 9k)

*Stage notes ("9f:", "9g:") sit inside each description. They show which Stage added or changed the file.*

| File | What it does |
|---|---|
| `lib/supabase/client.ts`, `lib/supabase/server.ts` | Supabase clients typed with `<Database>` from `./database.types` |
| `proxy.ts` | Refreshes the session cookie, redirects signed-out visitors to `/login` and signed-in users away from it |
| `app/login/page.tsx` | Sign-in form (`signInWithPassword`) |
| `lib/i18n.ts` | `displayName(locale, nameEn, nameKm)`: Khmer when active and not empty, else English |
| `modules/org/types.ts` | Narrowed types: `ParentCompany`, `HierarchyLevel`, `CompanyLevelRule`, `UnitRow`, `UnitOption`, `JobOption`, `PositionAllocation`. **9g:** also `JobRow` (open job: ID, company, Department, names, start date) and `ListingRow` (open Department listing: ID, company, org unit, Department, start date). **9i:** also `ClosedRuleRow`, `ClosedUnitRow`, `ClosedAllocationRow` (`PositionAllocation` plus `valid_to`), `ClosedJobRow`, `ClosedListingRow`. **9k:** also `AsOfAllocationRow` (`PositionAllocation` plus a nullable `valid_to`), `AsOfListingRow` and `UnitMoveRow` (one past parent link of a moved unit) |
| `lib/dates.ts` | `todayInPhnomPenh()` (default for date fields, the server runs on UTC) and `isIsoDate()` |
| `modules/org/queries.ts` | **9f:** also `createUnit`, `renameUnit`, `closeUnit`, `reorgUnit` (one set for both trees, pass `"org"` or `"pos"`, with a readable message mapping for raw constraint errors). Browser wrappers for `org_options`, `pos_options`, `eligible_departments`, `eligible_jobs`, `fetchExistingAllocation`. **9d:** also `createAllocation`, `changeAllocationHeadcount`, `closeAllocation`, `MAX_HEADCOUNT`, and a message mapping for raw constraint errors (`23505`, `23514`, `23503`). Permission (`42501`) and rule messages pass through. **9g:** also `fetchJobs` and `fetchListings` (read `job_positions_current` and `org_unit_departments_current`, rows with an empty key column are skipped) and the writes `createJob`, `renameJob`, `closeJob`, `addListing`, `removeListing`. New `rpcWriteError` is shared by the unit, job and listing writes: it replaces raw constraint errors (`23505`, `23503`, `23514`) with "This change is not valid any more. Refresh the page and try again.", other messages pass through. Allocation writes keep `writeError`. **9h:** also `enableLevelRule` and `disableLevelRule`. **9i:** also `fetchClosedRules`, `fetchClosedUnits` (one function for both trees), `fetchClosedAllocations`, `fetchClosedJobs`, `fetchClosedListings`. Each reads its `*_closed` view for one company, newest closed first, skipping rows with an empty key column. Not paged (Supabase returns at most 1000 rows per request) |
| `modules/org/queriesHistory.ts` | **9k, new.** Reads for the 9k views, kept apart from `queries.ts`: `fetchUnitsAsOf(tree, companyId, asOf)`, `fetchAllocationsAsOf`, `fetchListingsAsOf` (the `028` functions) and `fetchUnitMoves(tree, companyId)` (reads the `*_parent_links_closed` views, keeps only links that ended by a reorg, newest first). Not paged |
| `modules/org/useAsOfLoad.ts` | **9k, new.** Hook for the history screens. Takes a memoised loader (or null) and returns `data`, `error`, `isLoading`. A result is tied to the loader that produced it, so an old answer is never shown for a newer date or company |
| `modules/org/permissions.ts` | **9e, new.** `checkPermissions(company, code, targets)` calls `check_permissions` in batches of up to 500 targets (any error = not allowed). `usePermissions(company, code, targets)` hook returns `can(orgUnitId, departmentId)` (false until the answer arrives) and `isLoading`. Constants `PERM_ALLOCATION_WRITE`, `PERM_ORG_UNIT_WRITE`, `PERM_POS_UNIT_WRITE`. **9g:** also `PERM_JOB_WRITE` (`pos.job.write`) and `PERM_ELIGIBILITY_WRITE` (`org.eligibility.write`). **9h:** also `PERM_CONFIG_WRITE` (`org.config.write`) |
| `modules/org/labels.ts` | `levelLabel()` in the active language, falls back to the level code. **9i:** also `ROOT_LABEL` (what "no parent" means in each tree, used by the level tables and the history views) |
| `modules/org/components/AsyncSelect.tsx` | Dropdown that loads its own options, shows a reason when empty, reset with a `key`. Also exports `selectClassName` |
| `modules/org/components/CascadeSelector.tsx` | One dropdown per level, user can stop at any depth |
| `modules/org/components/OrgTreeExplorer.tsx` | Expandable tree with Expand all / Collapse all (org and position trees). **9f:** optional `manage` prop adds Add, Rename, Move and Close buttons per unit and "Add top-level unit", shown only where `check_permissions` allows (one batched call). Refreshes the page after each save. Without `manage` it is read-only (used by the as-of view, 9k) |
| `modules/org/components/UnitActionDialog.tsx` | **9f, new.** One modal for add, rename, close and move. Add offers only the levels the company's rules allow under that parent. Move offers only valid parents (never the unit itself or anything below it). Close is blocked in the form while open units are under it **9l:** optional `prefill` (names and level) for add, titled Re-create |
| `modules/org/unitTree.ts` | **9f, new.** Pure helpers: `descendantIds`, `departmentIdOf`, `childLevelRules`, `moveTargets` |
| `modules/org/components/AllocationForm.tsx` | Org location -> Department -> position unit -> job -> headcount and start date. Duplicate check. **9d:** Save calls `create_allocation`, is blocked while the duplicate check runs or when an open allocation exists, clears job and headcount after saving, and refreshes the data. **9e:** Save is disabled with a reason when the user lacks `org.allocation.write` for the selected org unit and Department |
| `modules/org/components/AllocationActionDialog.tsx` | **9d, new.** Modal to change the headcount of one allocation or close it, with an effective or close date |
| `modules/org/components/HeadcountGrid.tsx` | Open allocations with search, org unit and Department filters, totals. Not paged. **9d:** Change and Close buttons on every row (new `companyId` prop). **9e:** one batched permission check for all rows. Change and Close show only where allowed, other rows show "View only" |
| `modules/org/components/Modal.tsx` | **9g, new.** Shared modal frame: title, content, error line, Cancel and submit buttons (submit disabled while saving or when `canSubmit` is false). Used by `JobDialog`, `ListingDialog` and `LevelRuleDialog` |
| `modules/org/components/JobCatalog.tsx` | **9g, new.** Jobs tab. Loads open jobs with `fetchJobs`, search by name, Department filter, "Showing x of y", sorted by Department then job name. Shows open allocations per job. Add job position button shows only if the user has `pos.job.write` for at least one Department. Rename and Close per row show only where allowed (one batched check), other rows show "View only". Shows a message when the company has no Department. Reloads its list and refreshes the page after each save |
| `modules/org/components/JobDialog.tsx` | **9g, new.** Modal to add, rename or close one job. Add: Department (only Departments the user may write to), English name (required), Khmer name (optional); the job starts on the server's date. Rename: Save is disabled until a name changed. Close: close date (defaults to today's Phnom Penh date) and a note on how many open allocations close with the job **9l:** optional `prefill` (names) for add, titled Re-create |
| `modules/org/components/DepartmentListings.tsx` | **9g, new.** Department listings tab. One row per org unit (sorted by level, then name) with its listed Departments. Loads listings with `fetchListings`. Add Department and the remove (✕) button show only where the user has `org.eligibility.write` at that org unit (one batched check), other rows show "View only". Add is disabled when every Department is already listed. Reloads and refreshes the page after each save |
| `modules/org/components/ListingDialog.tsx` | **9g, new.** Modal to list a Department for an org unit (Department not yet listed there, start date) or remove a listing (close date). Remove is blocked in the form while open allocations use the listing, and tells the user to close them on the Headcount tab first **9l:** optional `prefillDepartmentId` for add, titled Re-create |
| `modules/org/components/HierarchyConfig.tsx` | **9h, new.** Configuration tab: the org and pos level tables (status, allowed parents). "Enable level" or "Add parent option" per level and "Disable" per rule, shown only where the user has `org.config.write` (company-level check, one empty target). Parent choices are the root (only if the level can be root) or an enabled higher level of the same tree, never one that already exists. The button is disabled with a hint when no choice is left. Refreshes the page after each save |
| `modules/org/components/LevelRuleDialog.tsx` | **9h, new.** Modal (uses `Modal`) to enable a level under a parent (the rule starts on the server's date) or disable one rule (close date, default today's Phnom Penh date, not before the rule's start). Database guard messages (`007`, `020`) are shown in the dialog |
| `modules/org/components/HistoryToggle.tsx` | **9i, new. 9k:** exports `ViewMode` (`"current"`, `"closed"`, `"asof"`, `"moves"`). Always shows Current and Closed (history), plus the `extraModes` the tab passes (As of date, Moves (reorg)) |
| `modules/org/components/AsOfDatePicker.tsx` | **9k, new.** Date field with a short note, shared by the three as-of views |
| `modules/org/components/AsOfUnits.tsx` | **9k, new.** As of date view of the Org tree and Position tree: a read-only `OrgTreeExplorer` of the units valid on the chosen date (`fetchUnitsAsOf`) |
| `modules/org/components/AsOfHeadcount.tsx` | **9k, new.** As of date view of the Headcount tab: read-only table of the approved headcount on the chosen date (`fetchAllocationsAsOf`), with search, total and start and end dates. Separate from `HeadcountGrid` because that one has Change and Close buttons |
| `modules/org/components/AsOfListings.tsx` | **9k, new.** As of date view of the Department listings tab: one row per org unit valid on the date with the Departments it listed (reads the listings and both as-of trees, so units closed since still show) |
| `modules/org/components/UnitMoves.tsx` | **9k, new.** Moves (reorg) view of the Org tree and Position tree: where moved units used to sit, the date they started under that parent and the date they moved (`fetchUnitMoves`). Search by unit or previous parent |
| `modules/org/components/ClosedRules.tsx` | **9i, new.** Closed level rules of both trees (level, what it was allowed under, started, closed) |
| `modules/org/components/ClosedUnits.tsx` | **9i, new.** Closed org or position units (one component, `tree` prop): name, level, the parent it had when it closed, started, closed. Search by name **9l:** Re-create button per row (disabled with a reason when the old parent is closed or the level is not enabled under it, hidden without the unit write permission). Position tree: the parent's level shows next to its name in Was under |
| `modules/org/components/ClosedAllocations.tsx` | **9i, new.** Closed allocations (headcount history): org unit, Department, position unit, job, approved headcount, started, closed. Search, org unit and Department filters. A headcount change shows as one closed row with the old headcount |
| `modules/org/components/ClosedJobs.tsx` | **9i, new.** Closed job positions: Department, job, started, closed. Search and Department filter **9l:** Re-create button per row (disabled when the Department is closed, hidden without `pos.job.write`). Takes the open Departments |
| `modules/org/components/ClosedListings.tsx` | **9i, new.** Closed Department listings: org unit, Department, started, closed. Search and Department filter **9l:** Re-create button per row (disabled when the org unit or Department is closed or the listing is already open, hidden without `org.eligibility.write`). Takes the open org units and Departments and also loads the open listings |
| `modules/org/components/OrgConfigView.tsx` | Header (company selector, EN / ខ្មែរ switch, sign out) and tabs: Configuration, Org tree, Position tree, Jobs, Department listings, Allocation form, Headcount. **9d:** passes `companyId` to the grid. **9g:** two new tabs, Jobs and Department listings. Departments are the position units with no parent, passed to both new tabs. Each tab is keyed by company. **9h:** the Configuration tab renders `HierarchyConfig`. **9i:** a `HistoryToggle` on six tabs (Configuration, Org tree, Position tree, Jobs, Department listings, Headcount). Closed shows the matching closed list instead of the current screen. The toggle goes back to Current when you switch tabs. The Allocation form tab has no history. **9k:** the toggle state is `mode`. A `HISTORY_MODES` table sets the extra modes per tab: Org tree and Position tree offer As of date and Moves (reorg), Department listings and Headcount offer As of date **9l:** passes the levels, rules and open units or Departments to the Closed units, jobs and listings screens |
| `app/page.tsx` | Server loader inside `<Suspense>`: companies, levels, rules, org and position units, current allocations |

### 5.3 Current versions of replaced functions

Start from the **latest** version when changing these:

* `private.company_level_rule_guard()` -> `007`
* `private.org_unit_guard()`, `private.pos_unit_guard()`, `private.job_position_guard()`, `private.org_unit_department_guard()` -> `006`
* `private.position_allocation_guard()` -> `006`
* `private.create_allocation` -> `015`
* `private.create_org_unit`, `private.create_pos_unit` -> `026`
* `private.member_role_scope_last_admin_guard()` -> `025` (second trigger on `core.member_role_scope`, next to `private.member_role_scope_guard()` from `012`)

### 5.4 Dev seed data (not migrations, dev only)

* `seed_dev_tenant.sql`: 1 tenant ("Dev Tenant"), 1 parent company ("Dev Parent Company"), membership for `mek.rotha@gmail.com`. Refuses to run if `core.tenant` has rows.
* `seed_dev_org_sample.sql`: 8 level rules, 6 org units, 6 position units, 6 Department listings, 5 jobs, 1 allocation (Software Engineer, Head Office, Backend Section, headcount 5). Inserts rules, listings and jobs straight into `core` and uses the private create functions for the rest. Refuses to run if the company already has ORG data. Khmer names are test samples.

---

## 6. Next plan

Do the steps in order. Each one is validated before the next starts.

1. **Test `025`:** passed on 2026-11-07.
2. **Close ORG Stages 9k and 9l on paper.** The Blueprint is updated (2026-11-07). Left: `HRIS_ORG_FRONTEND_REFERENCE.md` (`ORG-T009`). Optional: the `028` SQL test (`ORG-T008`).
3. **ORG Stage 9l: Re-create button on history rows. Passed** for units, jobs and Department listings (checked in the browser on 2026-11-07). Level rules and allocations were not built on purpose.
4. **Gap fixes** (tasks `ORG-T020` to `ORG-T022`). Add the 1000-row warning, move the server-date defaults to the Phnom Penh date (`ORG-Q10` settled: UTC+7), seed the Khmer level names once supplied. One task at a time. Done when each is checked in the browser or with a SQL test.
5. **Settle the assumptions** (`ORG-Q01` to `ORG-Q08` in the Blueprint). Go through them one by one. Each becomes a decision or changes. Start with "any tenant member sees everything", since the Employee module depends on it. Done when each item is marked Settled.
6. **Members, roles and setup: planning document.** Written before any code, in the same style as the Blueprint. Choose a module code (`PLT` is proposed, waiting for your confirmation) and create `HRIS_<CODE>_BLUEPRINT.md` and `HRIS_<CODE>_STATUS.md` from the templates. Cover: scope; setup functions (create tenant, company, membership); role management functions (give and remove a role, change a role); who may see all assignments of a tenant; what `members.manage` allows; how reads are governed (decision on `org.read`); screens; stages. The last admin guard (`025`) is already part of it. Done when the document is agreed.
7. **Build Members, roles and setup in small stages.** Database functions and tests first, then the members screen.

**Later or optional (not scheduled)**

* **Production setup:** only the dev Supabase project exists and nothing is deployed to Vercel. Create a production Supabase project and agree a migration deploy process (Supabase CLI) before many more migrations pile up.
* **Reads and the Employee module:** decide the read rule before employee data is stored (`ORG-Q01`).
* **Housekeeping:** record the file name of `023` and the test file names for `006`, `007`, `008` and `011`.
* **Optional from before:** real paging (after the warning).
* **Proposed UAT scenarios** (Blueprint 1.6): confirm or change before P6.

---

## 7. Pending from you

* For `ORG-T020`: `queriesHistory.ts`, `HeadcountGrid.tsx` and the list components and the Closed* and list components.
* For `ORG-T021`: the files of `018`, `020`, `022` and `026` (the latest versions of the functions, section 5.3).
* Optional: send `026_trimmed_names_test.sql` (or `001_tenancy.sql`) if you want the `028` SQL test (`ORG-T008`).
* Send `modules/org/queriesHistory.ts` for `ORG-T009` (and `database.types.ts` if the `028` columns are needed).
* Confirm the file names of migration `023` and its test, if you want them recorded.
* Settle the assumptions in the Blueprint, section 2 (Next plan, step 5).
* Choose the module code for Members, roles and setup (Next plan, step 6).
* Supply the Khmer names for the 7 levels when ready (`ORG-T022`).
* Test file names for `006`, `007`, `008` and `011` if you want them recorded.
* Review `HRIS_ORG_BLUEPRINT.md`: approve it, or correct it (especially the "Not recorded" scenario answers, `ORG-Q14`, `ORG-Q15`, and the Proposed UAT scenarios).

---

## 8. UAT coverage and results (P6)

*P6 has not started. Scenarios are the Proposed list in Blueprint 1.6 (`ORG-Q12`). "Covered in Stage" is derived from the stage plan and is to be confirmed.*

| Scenario | Covered in Stage | Result | Date | Note |
|---|---|---|---|---|
| `ORG-UAT01` Cascading selection | 8, 9d | Not run | | |
| `ORG-UAT02` Create allocation, duplicate blocked | 9d | Not run | | |
| `ORG-UAT03` Change headcount | 9d, 9i, 9k | Not run | | |
| `ORG-UAT04` Close a unit | 6b, 9f | Not run | | |
| `ORG-UAT05` Reorg | 6c, 9f, 9k | Not run | | |
| `ORG-UAT06` Viewer cannot write | 9c, 9e | Not run | | |
| `ORG-UAT07` Department-scoped admin | 9c, 9g | Not run | | |
| `ORG-UAT08` Disable level blocked | 6a, 9h | Not run | | |
| `ORG-UAT09` Other tenant's data | 0-1, 7 | Not run | | |
| `ORG-UAT10` Names at the time | none | Dropped | 2026-11-07 | Name history reverted (`027`). Names always show the current name |
| `ORG-UAT11` Re-create | 9l | Not run | | Proposed in Blueprint 1.6 |

---

## 9. Issues log

| ID | Stage | Problem | Found by | State | Fix or decision |
|---|---|---|---|---|---|
| `ORG-I03` | Housekeeping | File name of `023` and test file names of `006`, `007`, `008`, `011` not recorded | Old Status | Open | Supply the names or accept |
| `ORG-I05` | 9j | The Blueprint decision `ORG-D11` and section 4.6 were written for name history. The decision was reversed | Your decision | Closed | Blueprint updated on 2026-11-07 (`ORG-D11` reversed, `ORG-UAT10` dropped) |

---

## 10. Deployment checklist (P7)

* [ ] Migrations applied to the test environment (dev project has `000` to `028`. No separate test or production project)
* [ ] Environment variables set (nothing deployed to Vercel yet)
* [ ] Workflows checked with real roles

---

## 11. Known limitations (P8)

| Limitation | Impact | Planned fix |
|---|---|---|
| History views and as-of reads show the **current** names of units and jobs (by design: name history was dropped in `027`) | A rename changes names everywhere, also in history. This is wanted: a corrected name shows everywhere | None |
| A reorg with a future effective date takes effect immediately in the `*_current` views (the new link has an empty `valid_to`), but an as-of read before that date still shows the old parent | Current and as-of can differ until the date arrives | None (there is no "starts later" state, `ORG-D12`) |
| The Moves (reorg) view cannot tell a unit that was moved and closed on the same day from a plain close, so that move is not listed | A rare move is missing from the list | None |
| Reads are open to every tenant member, history included | Cannot be used for sensitive data (`EMP`) | Decide the read rule (`ORG-Q01`) |
| No function creates a tenant, company or membership (done by hand with `service_role`). A member added later has no role until one is given | Setup is manual | `PLT` |
| No function or screen gives or removes roles. A user sees only their own assignments. Who may see all assignments of a tenant is undecided | Role management is manual | `PLT` |
| Headcount grid, history lists and as-of reads are not paged. Supabase returns at most 1000 rows per request, so a list or total is too low beyond that | Wrong totals on large data | Warning (`ORG-T020`), then real paging (`ORG-Q11`) |
| Server-date defaults use UTC. Between 00:00 and 07:00 in Phnom Penh a record is dated one day early (`create_org_unit`, `create_pos_unit`, `create_job_position`, `enable_level_rule` and the rename functions) | One-day offset | Phnom Penh date, UTC+7 (`ORG-T021`) |
| Khmer level names are empty | Khmer interface shows the level code or English | Seed migration when names are supplied (`ORG-T022`) |
| Closed records cannot be re-opened | To bring something back, create it again. A re-created record gets a new ID | Re-create button on closed units, jobs and Department listings (ORG Stage 9l, passed). Closed level rules and allocations are created again by hand |
| No SQL test file for the history views (`023`, `024`) and for `028` | Checked in the browser only | Add a test if wanted (`ORG-T008`) |
| Only the dev Supabase project exists | No production environment | See Next plan, later items |

---

## 12. Lessons (ORG only)

* Migration numbers and ORG stages are not the same thing (for example ORG Stage 9c is migrations `014` to `020`; ORG Stage 5 is `006`; ORG Stages 6a/6b/6c are `007`/`008`/`009`; ORG Stage 9i is `023` and `024`; ORG Stage 9k is `028`).
* An empty dev database shows "No companies visible for your account". This is expected until a tenant, a company and a `tenant_member` row exist. Check those three tables before debugging frontend code.
* Departments are not created under a Business Unit or the Parent Company. Create a Department on the Position tree tab ("Add top-level unit"), then list it for an org unit on the Department listings tab. Listings sit on org units only (not on the Parent Company) and are not inherited, so each Business Unit, Branch or Division that needs the Department needs its own listing.
* The current screens show only open records (`valid_to is null`). A closed record is not deleted: it stays in `core` and shows under **Closed (history)** on its tab.
* A level cannot be disabled while another open rule uses it as parent. The blocker is a **rule**, not a unit, so it never shows on the tree screens. Example: Office could not be disabled because Section still had an open rule "Under Office". Disable the child rules first (for example Section and Group "Under Office"), then the parent level. Closing one rule of a level is allowed while another open rule of that level remains (Section "Under Department" can stay). To find the blocker, check the open rules of the company in `core.company_level_rule` (`valid_to is null`).
* When a database function gains new views or columns, regenerate `database.types.ts` before writing the frontend queries, so the narrowing code matches the real columns.
* A rename is treated as a correction, not as a history event. ORG keeps no name history (reverted in `027`). If a real rebrand ever has to show the old name in the past, that needs a new decision.
* As-of reads treat `valid_to` as the last valid day (inclusive). Where two rows touch on one date (reorg, headcount change, re-listing), the row that started later wins, then the higher id (`ORG-D12`).
* History screens load through `useAsOfLoad` with a memoised loader (`useMemo` on company and date). Reuse it for new read-only history views instead of writing another effect.

Project-wide lessons are in `HRIS_PROJECT_OVERVIEW.md`, section 6.

---

## 13. How to resume

1. Open a new chat in the same Project and attach `HRIS_PROJECT_OVERVIEW.md`, this file and `package.json`. Name the Stage as "ORG Stage N" or "migration NNN" and paste any error text exactly.
2. For design, assumptions or open questions, also attach `HRIS_ORG_BLUEPRINT.md`.
3. For any ORG frontend change, also attach `HRIS_ORG_FRONTEND_REFERENCE.md`, the file list of `app/`, `lib/supabase/` and `modules/org/`, `database.types.ts`, and the files the change builds on (section 5.2).
4. For database changes, attach the Blueprint (section 4) and the migration files the change depends on. If a guard function is involved, use the latest version (section 5.3).
5. If a file is missing, say so and Claude will ask whether to generate it.

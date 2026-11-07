# HRIS ORG Status

Last updated: 2026-11-07
Purpose: The plan and progress of the Organization structure (ORG) module: Stages planned and passed, tasks, files created, tests, issues, next steps and known limitations. What the module is, and why, is in the Blueprint. Split out of the former `HRIS\_ORG\_STATUS.md` (dated 2026-11-06).
Read together with: `HRIS\_PROJECT\_OVERVIEW.md`, `HRIS\_ORG\_BLUEPRINT.md`, `HRIS\_ORG\_FRONTEND\_REFERENCE.md`

Module code: `ORG`. Stages are written "ORG Stage N". Migration headers that say "roadmap Stage X" mean ORG Stage X.

*Update rule: at the end of each Stage, update sections 1 to 6 and 8 in one go, and the module row in `HRIS\_MODULE\_REGISTER.md` if the state changed.*

\---

## 1\. Where we are

|Item|Value|
|-|-|
|Phase now|P4-P5 (Stage 9j closed, Stage 9k next)|
|Blueprint state|Written after the build began (not gated). Awaiting your approval. See Blueprint section 5|
|Current Stage|None in progress. ORG Stage 9j (name history) was reverted by `027`. Next is ORG Stage 9k|
|Last Stage passed|ORG Stage 9j: name history reverted (`027`, SQL test `026\_trimmed\_names\_test.sql` passed). Before it, ORG Stage 9i (`023`, `024`, checked in the browser)|
|Next|ORG Stage 9k (`028`, history reads)|
|Blocking|Stage 9k needs `008`, `009`, `010`, `015`, `023`, `024` from you, and a check of how `009` and `015` set dates (`ORG-Q09`)|

* The database (`000` to `027`) is applied to the dev project. The test result of `025` has not been reported yet.
* **Permissions are enforced on writes** through the wrappers. Reads are open to every tenant member, history included. The private write functions stay `service\_role` only.
* The frontend can read and manage everything in the ORG scope: levels (9h), units on both trees (9f), jobs and Department listings (9g), allocations and headcount (9d, 9e), and shows closed records on six tabs (9i). Buttons are hidden by `check\_permissions` where the user lacks the permission.
* Skipped for now: ORG Stage 2b (Khmer level names).

\---

## 2\. Stage plan

*Stages 0 to 9j were named by layer, before the vertical-slice rule. They are kept as built. Blueprint references use the IDs of `HRIS\_ORG\_BLUEPRINT.md`. "Depends on" follows the build order.*

|Stage|Capability|Blueprint items covered|Migrations|Frontend|Depends on|State|
|-|-|-|-|-|-|-|
|0-1|Schemas and tenancy|Overview 5.2|`000`, `001`|none|none|Passed|
|2|A company sets its level rules|4.2 (`hierarchy\_level`, `company\_level\_rule`), `ORG-D01`, `ORG-D16`|`002`|none|0-1|Passed|
|2b|Khmer level names|`ORG-D05`, `ORG-Q05`|A small seed migration|none|2|**Dropped (skipped for now)**|
|3|Org tree|`ORG-D14`, `ORG-D18`, `ORG-D19`, `ORG-D20`|`003`|none|2|Passed|
|4|Position tree, jobs, eligibility|`ORG-D02`, `ORG-D03`, `ORG-D14`|`004`, `005`|none|3|Passed|
|5|Allocation and headcount|`ORG-D21`, `ORG-D23`, `ORG-D24`|`006`|none|3, 4|Passed|
|6a|Level disable guard|`ORG-D22`|`007`|none|2, 3|Passed|
|6b|Close functions|`ORG-D21`|`008`|none|3, 4, 5|Passed|
|6c|Reorg functions|`ORG-D04`, `ORG-D25`|`009`|none|3, 4, 6b|Passed|
|7 / 7b|Read layer and catalog read views|4.5, 4.6|`010`, `011`|none|2 to 6c|Passed|
|8a-8d|Read-only frontend: foundation, config screen, trees and allocation form, headcount grid|3.1|none|Section 5.2|7 / 7b|Passed|
|9a|Roles and permissions design|`ORG-D06`, `ORG-D07`, `ORG-D26`|none (design)|none|7|Passed (agreed)|
|9b-1 / 9b-2|Role tables, permission check|4.4|`012`, `013`|none|9a|Passed|
|9c|Write wrappers: allocations, org units, position units, jobs, Department listings, level rules|`ORG-D08`, 4.4|`014` to `020`|none|9b|Passed|
|9d|Allocation save and headcount grid actions (Save calls `create\_allocation` with start date and duplicate check. Change headcount and close, each with an effective date. Clear message on `42501`. Date fields default to today's Phnom Penh date)|1.2 (workflow 5)|none|Frontend only|9c|Passed|
|9e|Own permissions and role-aware buttons (`public.check\_permissions`, permission helper, Save disabled and Change/Close hidden when not allowed)|4.4|`021`|`modules/org/permissions.ts` and screens|9c|Passed (database and frontend)|
|9f|Org tree and position tree management: rename functions and wrappers, then add, rename, move and close units on both trees|3.2, 4.3|`022`|`OrgTreeExplorer` (`manage`), `UnitActionDialog`, `unitTree.ts`|9e|Passed|
|9g|Job catalog and Department listings screens|1.2 (workflows 3, 4)|none|Jobs tab, Department listings tab|9e|Passed|
|9h|Hierarchy configuration screen (enable a level under a parent, disable one rule)|1.2 (workflow 1)|none|`HierarchyConfig`, `LevelRuleDialog`|9e|Passed (disabling and enabling confirmed in the browser, guard message seen)|
|9i|History view of closed rules, units, jobs, listings and allocations|`ORG-D09`, `ORG-D17`|`023`, `024`|Current / Closed toggle on six tabs, `ClosedRules`, `ClosedUnits`, `ClosedAllocations`, `ClosedJobs`, `ClosedListings`, `HistoryToggle`|9c|Passed|
|9j|Name history, then reverted. A corrected name must show everywhere regardless of date, so the name history table and triggers were removed (`027`). The trimmed names in the create functions (`026`, part B) stay|`ORG-D11` (reversed)|`026`, `027`|none|9i|**Passed (reverted).** `026\_trimmed\_names\_test.sql` passed|
|9k|History reads: reorg history, as-of date. Database: `028` adds a view of the past parent links of units, and adds as-of date functions for the org tree, position tree, allocations and headcount, and Department listings. Frontend after `028` passes|`ORG-D12`, `ORG-D13`, `ORG-Q09`|`028`|After `028` passes|9i. Needs `008`, `009`, `010`, `015`, `023`, `024`|**Planned**|
|Platform|Last tenant admin guard (belongs to the members, roles and setup work)|`ORG-D10`|`025`|none|`012`|Applied to dev. Test result not reported yet|

**Not counted in the stages**

* **Members, roles and setup** (create tenant, company, membership, give and remove roles): a platform stage, handled as its own module (`PLT`). Planning document first (section 6, step 4). The last tenant admin guard (`025`) is already written.
* **Optional:** Khmer level names (2b), paging the headcount grid and the history lists, a "Re-create" button on history rows (pre-fills the add form).
* Employee hooks (hiring, transfers, promotions) belong to a later module (`LCY`), not ORG.

\---

## 3\. Task list

*Tasks of the current Stage and the next one only.*

|Task|Stage|Task|Type|Blueprint ref|Who|State|Done on|Note|
|-|-|-|-|-|-|-|-|-|
|`ORG-T001`|9j / Platform|Apply `025`, `026` and `027`: `npx supabase db push --remote`|Migration|`ORG-D10`, `ORG-D11`|You|Done|2026-11-07||
|`ORG-T002`|9j / Platform|Run the SQL tests in the SQL Editor (dev project). Each must return "Success. No rows returned". `026\_trimmed\_names\_test.sql` passed. `025\_last\_tenant\_admin\_guard\_test.sql` is still to do|SQL test|`ORG-D10`, `ORG-D11`|You|Part done|2026-11-07|Only the `025` test is left. Paste any `FAIL:` message exactly|
|`ORG-T003`|9k|Send `008`, `009`, `010`, `015`, `023`, `024`|Check|`ORG-Q09`|You|To do|||
|`ORG-T004`|9k|Confirm how `009` and `015` set dates (decision "Dates in history reads")|Decision|`ORG-D12`, `ORG-Q09`|Claude|To do||Needs `ORG-T003`|
|`ORG-T005`|9k|~~Closed views show names as they were~~|Migration|`ORG-D11`, 4.6|Claude|Dropped|2026-11-07|Name history reverted (`027`). Names always show the current name|
|`ORG-T006`|9k|`028`: view of the past parent links of units (reorg history)|Migration|4.6|Claude|To do|||
|`ORG-T007`|9k|`028`: as-of date functions for the org tree, position tree, allocations and headcount, and Department listings|Migration|`ORG-D13`|Claude|To do|||
|`ORG-T008`|9k|`028\_...\_test.sql`|SQL test|4.8|Claude|To do|||
|`ORG-T009`|9k|Update `HRIS\_ORG\_FRONTEND\_REFERENCE.md` when `028` adds public objects|Document||Claude|To do|||
|`ORG-T010`|9k|Frontend (separate stage after `028` passes): reorg history, an as-of date picker|Frontend|3.1|Claude|To do||Blocked until `028` passes|

\---

## 4\. Stage log

*Dates were not recorded in the old Status. Test results are as the old document stated them.*

|Stage|Capability|Migration(s)|SQL test|Browser check|Result|Date|Notes|
|-|-|-|-|-|-|-|-|
|0-1|Schemas, tenancy|`000`, `001`|Passed|n/a|Passed|not recorded||
|2|Level catalog and company rules|`002`|Passed|n/a|Passed|not recorded||
|3|Org tree|`003`|Passed|n/a|Passed|not recorded||
|4|Position tree, jobs, eligibility|`004`, `005`|Passed|n/a|Passed|not recorded||
|5|Allocation and headcount|`006`|Passed (file name not recorded)|n/a|Passed|not recorded||
|6a / 6b / 6c|Level disable guard, close functions, reorg functions|`007`, `008`, `009`|Passed (`007`, `008` file names not recorded. `009` in `009\_010\_reorg\_read\_layer\_test.sql`)|n/a|Passed|not recorded||
|7 / 7b|Read layer, catalog read views|`010`, `011`|Passed (`011` file name not recorded)|n/a|Passed|not recorded||
|2b|Khmer level names|none|n/a|n/a|Skipped for now|not recorded|Add later as a small seed migration when names are supplied|
|8a-8d|Read-only frontend|none|n/a|Passed|Passed|not recorded||
|9a|Roles and permissions design|none|n/a|n/a|Agreed|not recorded|Decisions `ORG-D06`, `ORG-D07`, `ORG-D26`|
|9b-1 / 9b-2|Role tables, permission check|`012`, `013`|Passed|n/a|Passed|not recorded||
|9c|Write wrappers|`014` to `020`|Passed (`014` to `020` confirmed)|n/a|Passed|not recorded||
|9d|Allocation save, headcount grid actions|none|n/a|Passed|Passed|not recorded||
|9e|Own permissions, role-aware buttons|`021`|Passed|Passed|Passed|not recorded|Closes gap G8 on the database side|
|9f|Org and position tree management|`022`|Passed|Passed|Passed|not recorded||
|9g|Job catalog, Department listings|none|n/a|Passed|Passed|not recorded||
|9h|Hierarchy configuration screen|none|n/a|Passed|Passed|not recorded|Disabling confirmed (guard message seen, then Section "Under Office" and Office disabled). Enabling a level also confirmed|
|9i|History view|`023`, `024`|No SQL test file|Passed|Passed|not recorded|Checked in the browser|
|9j|Name history, reverted|`026`, `027`|`026\_trimmed\_names\_test.sql` passed|n/a|Passed|2026-11-07|Name history table and triggers removed by `027`. Trimmed names kept. Closes `ORG-I01`, `ORG-I02`|

\---

## 5\. Files

Migrations `000` to `027` are applied to the dev project. The test result of `025` has not been reported yet. Migrations are one chain shared by all modules (`000`, `001` are shared platform files).

### 5.1 Migrations and tests

|File|Stage|What it adds|Test file|
|-|-|-|-|
|`000\_create\_schemas.sql`|0-1|`core` and `private` schemas, minimal grants|n/a|
|`001\_tenancy.sql`|0-1|`tenant`, `parent\_company`, `tenant\_member`, `private.user\_tenant\_ids()`, RLS|`001\_tenancy\_test.sql`|
|`002\_hierarchy\_levels.sql`|2|`hierarchy\_level` (7 seeded), versioned `company\_level\_rule`, guard, RLS|`002\_hierarchy\_levels\_test.sql`|
|`003\_org\_tree.sql`|3|`org\_unit`, `org\_unit\_parent`, guards, `private.create\_org\_unit`|`003\_org\_tree\_test.sql`|
|`004\_position\_tree.sql`|4|`pos\_unit`, `pos\_unit\_parent`, `private.create\_pos\_unit`|`004\_position\_tree\_test.sql`|
|`005\_jobs\_and\_eligibility.sql`|4|`job\_position`, `org\_unit\_department`|`005\_jobs\_and\_eligibility\_test.sql`|
|`006\_allocation.sql`|5|`position\_allocation`, `private.create\_allocation`, allocation guard, closing cascades|passed (file name not recorded)|
|`007\_level\_disable\_guard.sql`|6a|Level cannot be disabled while open units exist|passed (file name not recorded)|
|`008\_close\_unit.sql`|6b|`private.close\_org\_unit`, `private.close\_pos\_unit`|passed (file name not recorded)|
|`009\_reorg.sql`|6c|`private.reorg\_org\_unit`, `private.reorg\_pos\_unit`, `private.pos\_department\_of`|`009\_010\_reorg\_read\_layer\_test.sql`|
|`010\_read\_layer.sql`|7|Read views and cascade functions in `public`|`009\_010\_reorg\_read\_layer\_test.sql`|
|`011\_catalog\_read\_views.sql`|7b|`public.parent\_companies`, `public.hierarchy\_levels`|passed (file name not recorded)|
|`012\_roles.sql`|9b-1|`app\_role`, `permission`, `app\_role\_permission`, `member\_role\_scope`, 3 roles, 8 permission codes, scope guard, RLS. Unique `(id, company\_id)` on `org\_unit` and `pos\_unit`|`012\_roles\_test.sql`|
|`013\_has\_permission.sql`|9b-2|`private.has\_permission`, `private.has\_tenant\_permission`, `private.role\_has\_permission`|`013\_has\_permission\_test.sql`|
|`014\_close\_allocation.sql`|9c|`private.close\_allocation`|`014\_close\_allocation\_test.sql`|
|`015\_allocation\_wrappers.sql`|9c|`private.create\_allocation` replaced, public allocation wrappers|`015\_allocation\_wrappers\_test.sql`|
|`016\_org\_unit\_wrappers.sql`|9c|Public org unit wrappers, `private.is\_company\_member`|`016\_020\_wrappers\_test.sql`|
|`017\_pos\_unit\_wrappers.sql`|9c|Public position unit wrappers, `private.can\_manage\_pos\_unit`|`016\_020\_wrappers\_test.sql`|
|`018\_job\_position\_functions.sql`|9c|Private and public job position functions|`016\_020\_wrappers\_test.sql`|
|`019\_department\_listing\_functions.sql`|9c|Private and public Department listing functions|`016\_020\_wrappers\_test.sql`|
|`020\_level\_rule\_functions.sql`|9c|Private and public level rule functions|`016\_020\_wrappers\_test.sql`|
|`021\_permission\_check.sql`|9e|`public.check\_permissions` (ORG Stage 9e, database part)|`021\_permission\_check\_test.sql`|
|`022\_rename\_unit.sql`|9f|`private.rename\_org\_unit`, `private.rename\_pos\_unit`, public wrappers `rename\_org\_unit`, `rename\_pos\_unit` (ORG Stage 9f-1)|`022\_rename\_unit\_test.sql`|
|`023` (file name not recorded)|9i|Read-only history views `company\_level\_rules\_closed`, `org\_units\_closed`, `pos\_units\_closed` (ORG Stage 9i, part 1)|browser test (ORG Stage 9i)|
|`024\_history\_views\_jobs\_listings\_allocations.sql`|9i|Read-only history views `job\_positions\_closed`, `org\_unit\_departments\_closed`, `position\_allocations\_closed` (ORG Stage 9i, part 2)|browser test (ORG Stage 9i)|
|`025\_last\_tenant\_admin\_guard.sql` (platform)|Platform (written for ORG)|Trigger on `core.member\_role\_scope` that refuses deleting or downgrading the last tenant-wide `tenant\_admin`, also through removing the member or the auth user. **Applied to dev. Test result not reported yet**|`025\_last\_tenant\_admin\_guard\_test.sql`|
|`026\_name\_history.sql` (ORG Stage 9j)|9j|Part A (`core.name\_history` and its triggers) was **removed by `027`**. Part B stays: `private.create\_org\_unit` and `private.create\_pos\_unit` replaced (names trimmed, an empty Khmer name stored as null, blank English name refused)|`026\_trimmed\_names\_test.sql` (tests part B only)|
|`027\_revert\_name\_history.sql`|9j|Drops the three name-history triggers, `private.name\_history\_sync()` and `core.name\_history`. Nothing else changes|`026\_trimmed\_names\_test.sql`|

**How tests work.** Plain SQL files. Paste one into Supabase Dashboard -> SQL Editor (dev project only). Each rolls back at the end. "Success. No rows returned" means pass. An error starting with `FAIL:` means a check failed. Tests `009\_010`, `012` and `013` create temporary users and switch role to `authenticated` and `anon`. Tests `012` and `013` need `seed\_dev\_org\_sample.sql`. `016\_020\_wrappers\_test.sql` covers the wrappers and private functions of `016` to `020`. `021\_permission\_check\_test.sql` uses temporary users and the sample data like `013`. `022\_rename\_unit\_test.sql` needs the sample data and a `tenant\_admin` user (set `v\_admin\_email` at the top). The history views (`023`, `024`) were checked in the browser, there is no SQL test file for them. `026\_trimmed\_names\_test.sql` creates its own tenant and company and needs no sample data. The old `026\_name\_history\_test.sql` was removed.

### 5.2 Frontend files (ORG Stages 8, 9d, 9e, 9f, 9g, 9h and 9i)

*Stage notes ("9f:", "9g:") sit inside each description. They show which Stage added or changed the file.*

|File|What it does|
|-|-|
|`lib/supabase/client.ts`, `lib/supabase/server.ts`|Supabase clients typed with `<Database>` from `./database.types`|
|`proxy.ts`|Refreshes the session cookie, redirects signed-out visitors to `/login` and signed-in users away from it|
|`app/login/page.tsx`|Sign-in form (`signInWithPassword`)|
|`lib/i18n.ts`|`displayName(locale, nameEn, nameKm)`: Khmer when active and not empty, else English|
|`modules/org/types.ts`|Narrowed types: `ParentCompany`, `HierarchyLevel`, `CompanyLevelRule`, `UnitRow`, `UnitOption`, `JobOption`, `PositionAllocation`. **9g:** also `JobRow` (open job: ID, company, Department, names, start date) and `ListingRow` (open Department listing: ID, company, org unit, Department, start date). **9i:** also `ClosedRuleRow`, `ClosedUnitRow`, `ClosedAllocationRow` (`PositionAllocation` plus `valid\_to`), `ClosedJobRow`, `ClosedListingRow`|
|`lib/dates.ts`|`todayInPhnomPenh()` (default for date fields, the server runs on UTC) and `isIsoDate()`|
|`modules/org/queries.ts`|**9f:** also `createUnit`, `renameUnit`, `closeUnit`, `reorgUnit` (one set for both trees, pass `"org"` or `"pos"`, with a readable message mapping for raw constraint errors). Browser wrappers for `org\_options`, `pos\_options`, `eligible\_departments`, `eligible\_jobs`, `fetchExistingAllocation`. **9d:** also `createAllocation`, `changeAllocationHeadcount`, `closeAllocation`, `MAX\_HEADCOUNT`, and a message mapping for raw constraint errors (`23505`, `23514`, `23503`). Permission (`42501`) and rule messages pass through. **9g:** also `fetchJobs` and `fetchListings` (read `job\_positions\_current` and `org\_unit\_departments\_current`, rows with an empty key column are skipped) and the writes `createJob`, `renameJob`, `closeJob`, `addListing`, `removeListing`. New `rpcWriteError` is shared by the unit, job and listing writes: it replaces raw constraint errors (`23505`, `23503`, `23514`) with "This change is not valid any more. Refresh the page and try again.", other messages pass through. Allocation writes keep `writeError`. **9h:** also `enableLevelRule` and `disableLevelRule`. **9i:** also `fetchClosedRules`, `fetchClosedUnits` (one function for both trees), `fetchClosedAllocations`, `fetchClosedJobs`, `fetchClosedListings`. Each reads its `\*\_closed` view for one company, newest closed first, skipping rows with an empty key column. Not paged (Supabase returns at most 1000 rows per request)|
|`modules/org/permissions.ts`|**9e, new.** `checkPermissions(company, code, targets)` calls `check\_permissions` in batches of up to 500 targets (any error = not allowed). `usePermissions(company, code, targets)` hook returns `can(orgUnitId, departmentId)` (false until the answer arrives) and `isLoading`. Constants `PERM\_ALLOCATION\_WRITE`, `PERM\_ORG\_UNIT\_WRITE`, `PERM\_POS\_UNIT\_WRITE`. **9g:** also `PERM\_JOB\_WRITE` (`pos.job.write`) and `PERM\_ELIGIBILITY\_WRITE` (`org.eligibility.write`). **9h:** also `PERM\_CONFIG\_WRITE` (`org.config.write`)|
|`modules/org/labels.ts`|`levelLabel()` in the active language, falls back to the level code. **9i:** also `ROOT\_LABEL` (what "no parent" means in each tree, used by the level tables and the history views)|
|`modules/org/components/AsyncSelect.tsx`|Dropdown that loads its own options, shows a reason when empty, reset with a `key`. Also exports `selectClassName`|
|`modules/org/components/CascadeSelector.tsx`|One dropdown per level, user can stop at any depth|
|`modules/org/components/OrgTreeExplorer.tsx`|Expandable tree with Expand all / Collapse all (org and position trees). **9f:** optional `manage` prop adds Add, Rename, Move and Close buttons per unit and "Add top-level unit", shown only where `check\_permissions` allows (one batched call). Refreshes the page after each save|
|`modules/org/components/UnitActionDialog.tsx`|**9f, new.** One modal for add, rename, close and move. Add offers only the levels the company's rules allow under that parent. Move offers only valid parents (never the unit itself or anything below it). Close is blocked in the form while open units are under it|
|`modules/org/unitTree.ts`|**9f, new.** Pure helpers: `descendantIds`, `departmentIdOf`, `childLevelRules`, `moveTargets`|
|`modules/org/components/AllocationForm.tsx`|Org location -> Department -> position unit -> job -> headcount and start date. Duplicate check. **9d:** Save calls `create\_allocation`, is blocked while the duplicate check runs or when an open allocation exists, clears job and headcount after saving, and refreshes the data. **9e:** Save is disabled with a reason when the user lacks `org.allocation.write` for the selected org unit and Department|
|`modules/org/components/AllocationActionDialog.tsx`|**9d, new.** Modal to change the headcount of one allocation or close it, with an effective or close date|
|`modules/org/components/HeadcountGrid.tsx`|Open allocations with search, org unit and Department filters, totals. Not paged. **9d:** Change and Close buttons on every row (new `companyId` prop). **9e:** one batched permission check for all rows. Change and Close show only where allowed, other rows show "View only"|
|`modules/org/components/Modal.tsx`|**9g, new.** Shared modal frame: title, content, error line, Cancel and submit buttons (submit disabled while saving or when `canSubmit` is false). Used by `JobDialog`, `ListingDialog` and `LevelRuleDialog`|
|`modules/org/components/JobCatalog.tsx`|**9g, new.** Jobs tab. Loads open jobs with `fetchJobs`, search by name, Department filter, "Showing x of y", sorted by Department then job name. Shows open allocations per job. Add job position button shows only if the user has `pos.job.write` for at least one Department. Rename and Close per row show only where allowed (one batched check), other rows show "View only". Shows a message when the company has no Department. Reloads its list and refreshes the page after each save|
|`modules/org/components/JobDialog.tsx`|**9g, new.** Modal to add, rename or close one job. Add: Department (only Departments the user may write to), English name (required), Khmer name (optional); the job starts on the server's date. Rename: Save is disabled until a name changed. Close: close date (defaults to today's Phnom Penh date) and a note on how many open allocations close with the job|
|`modules/org/components/DepartmentListings.tsx`|**9g, new.** Department listings tab. One row per org unit (sorted by level, then name) with its listed Departments. Loads listings with `fetchListings`. Add Department and the remove (✕) button show only where the user has `org.eligibility.write` at that org unit (one batched check), other rows show "View only". Add is disabled when every Department is already listed. Reloads and refreshes the page after each save|
|`modules/org/components/ListingDialog.tsx`|**9g, new.** Modal to list a Department for an org unit (Department not yet listed there, start date) or remove a listing (close date). Remove is blocked in the form while open allocations use the listing, and tells the user to close them on the Headcount tab first|
|`modules/org/components/HierarchyConfig.tsx`|**9h, new.** Configuration tab: the org and pos level tables (status, allowed parents). "Enable level" or "Add parent option" per level and "Disable" per rule, shown only where the user has `org.config.write` (company-level check, one empty target). Parent choices are the root (only if the level can be root) or an enabled higher level of the same tree, never one that already exists. The button is disabled with a hint when no choice is left. Refreshes the page after each save|
|`modules/org/components/LevelRuleDialog.tsx`|**9h, new.** Modal (uses `Modal`) to enable a level under a parent (the rule starts on the server's date) or disable one rule (close date, default today's Phnom Penh date, not before the rule's start). Database guard messages (`007`, `020`) are shown in the dialog|
|`modules/org/components/HistoryToggle.tsx`|**9i, new.** "Current / Closed (history)" switch shown at the top of a tab|
|`modules/org/components/ClosedRules.tsx`|**9i, new.** Closed level rules of both trees (level, what it was allowed under, started, closed)|
|`modules/org/components/ClosedUnits.tsx`|**9i, new.** Closed org or position units (one component, `tree` prop): name, level, the parent it had when it closed, started, closed. Search by name|
|`modules/org/components/ClosedAllocations.tsx`|**9i, new.** Closed allocations (headcount history): org unit, Department, position unit, job, approved headcount, started, closed. Search, org unit and Department filters. A headcount change shows as one closed row with the old headcount|
|`modules/org/components/ClosedJobs.tsx`|**9i, new.** Closed job positions: Department, job, started, closed. Search and Department filter|
|`modules/org/components/ClosedListings.tsx`|**9i, new.** Closed Department listings: org unit, Department, started, closed. Search and Department filter|
|`modules/org/components/OrgConfigView.tsx`|Header (company selector, EN / ខ្មែរ switch, sign out) and tabs: Configuration, Org tree, Position tree, Jobs, Department listings, Allocation form, Headcount. **9d:** passes `companyId` to the grid. **9g:** two new tabs, Jobs and Department listings. Departments are the position units with no parent, passed to both new tabs. Each tab is keyed by company. **9h:** the Configuration tab renders `HierarchyConfig`. **9i:** a `HistoryToggle` on six tabs (Configuration, Org tree, Position tree, Jobs, Department listings, Headcount). Closed shows the matching closed list instead of the current screen. The toggle goes back to Current when you switch tabs. The Allocation form tab has no history|
|`app/page.tsx`|Server loader inside `<Suspense>`: companies, levels, rules, org and position units, current allocations|

### 5.3 Current versions of replaced functions

Start from the **latest** version when changing these:

Start from the **latest** version when changing these:

* `private.company\_level\_rule\_guard()` -> `007`
* `private.org\_unit\_guard()`, `private.pos\_unit\_guard()`, `private.job\_position\_guard()`, `private.org\_unit\_department\_guard()` -> `006`
* `private.position\_allocation\_guard()` -> `006`
* `private.create\_allocation` -> `015`
* `private.create\_org\_unit`, `private.create\_pos\_unit` -> `026`
* `private.member\_role\_scope\_last\_admin\_guard()` -> `025` (second trigger on `core.member\_role\_scope`, next to `private.member\_role\_scope\_guard()` from `012`)

### 5.4 Dev seed data (not migrations, dev only)

* `seed\_dev\_tenant.sql`: 1 tenant ("Dev Tenant"), 1 parent company ("Dev Parent Company"), membership for `mek.rotha@gmail.com`. Refuses to run if `core.tenant` has rows.
* `seed\_dev\_org\_sample.sql`: 8 level rules, 6 org units, 6 position units, 6 Department listings, 5 jobs, 1 allocation (Software Engineer, Head Office, Backend Section, headcount 5). Inserts rules, listings and jobs straight into `core` and uses the private create functions for the rest. Refuses to run if the company already has ORG data. Khmer names are test samples.

\---

## 6\. Next plan

Do the steps in order. Each one is validated before the next starts.

1. **Test `025`** (task `ORG-T002`). `026` and `027` are applied and passed. Done when the `025` test returns "Success. No rows returned".
2. **ORG Stage 9k: migration `028`, history reads** (tasks `ORG-T003` to `ORG-T010`). Attach `008`, `009`, `010`, `015`, `023`, `024`. First confirm how `009` and `015` set dates. Then: (a) a view of the past parent links of units (reorg history), (b) as-of date functions for the org tree, position tree, allocations and headcount, and Department listings. Names always show the current name (name history was dropped). SQL test `028\_...\_test.sql`. The frontend (reorg history, an as-of date picker) is a separate stage after it passes. Done when the `028` test passes.
3. **Settle the assumptions** (`ORG-Q01` to `ORG-Q08` in the Blueprint). Go through them one by one. Each becomes a decision or changes. Start with "any tenant member sees everything", since the Employee module depends on it. Done when each item is marked Settled.
4. **Members, roles and setup: planning document.** Written before any code, in the same style as the Blueprint. Choose a module code (`PLT` is proposed, waiting for your confirmation) and create `HRIS\_<CODE>\_BLUEPRINT.md` and `HRIS\_<CODE>\_STATUS.md` from the templates. Cover: scope; setup functions (create tenant, company, membership); role management functions (give and remove a role, change a role); who may see all assignments of a tenant; what `members.manage` allows; how reads are governed (decision on `org.read`); screens; stages. The last admin guard (`025`) is already part of it. Done when the document is agreed.
5. **Build Members, roles and setup in small stages.** Database functions and tests first, then the members screen.

**Later or optional (not scheduled)**

* **Production setup:** only the dev Supabase project exists and nothing is deployed to Vercel. Create a production Supabase project and agree a migration deploy process (Supabase CLI) before many more migrations pile up.
* **1000-row limit:** show a visible warning when a list or total hits 1000 rows, before real paging is built (gap G9, `ORG-Q11`).
* **Dates without a date parameter:** decide whether to add date parameters or accept the UTC date (`ORG-Q10`).
* **Reads and the Employee module:** decide the read rule before employee data is stored (`ORG-Q01`).
* **Housekeeping:** record the file name of `023` and the test file names for `006`, `007`, `008` and `011`. Update `HRIS\_ORG\_FRONTEND\_REFERENCE.md` when `028` adds public objects.
* **Optional from before:** Khmer level names (2b), paging, a "Re-create" button on history rows.
* **Proposed UAT scenarios** (Blueprint 1.6): confirm or change before P6.

\---

## 7\. Pending from you

* Run the test for `025` and report the result (paste any `FAIL:` message exactly).
* Send `008`, `009`, `010`, `015`, `023` and `024` for ORG Stage 9k.
* Confirm the file names of migration `023` and its test, if you want them recorded.
* Settle the assumptions in the Blueprint, section 2 (Next plan, step 3).
* Choose the module code for Members, roles and setup (Next plan, step 4).
* Supply the Khmer names for the 7 levels when ready.
* Test file names for `006`, `007`, `008` and `011` if you want them recorded.
* Review the new `HRIS\_ORG\_BLUEPRINT.md`: approve it, or correct it (especially the "Not recorded" scenario answers, `ORG-Q14`, `ORG-Q15`, and the Proposed UAT scenarios).
* Send `HRIS\_ORG\_BLUEPRINT.md` so I can update decision `ORG-D11`, section 4.6 and scenario `ORG-UAT10` (`ORG-I05`).

\---

## 8\. UAT coverage and results (P6)

*P6 has not started. Scenarios are the Proposed list in Blueprint 1.6 (`ORG-Q12`). "Covered in Stage" is derived from the stage plan and is to be confirmed.*

|Scenario|Covered in Stage|Result|Date|Note|
|-|-|-|-|-|
|`ORG-UAT01` Cascading selection|8, 9d|Not run|||
|`ORG-UAT02` Create allocation, duplicate blocked|9d|Not run|||
|`ORG-UAT03` Change headcount|9d, 9i|Not run|||
|`ORG-UAT04` Close a unit|6b, 9f|Not run|||
|`ORG-UAT05` Reorg|6c, 9f|Not run|||
|`ORG-UAT06` Viewer cannot write|9c, 9e|Not run|||
|`ORG-UAT07` Department-scoped admin|9c, 9g|Not run|||
|`ORG-UAT08` Disable level blocked|6a, 9h|Not run|||
|`ORG-UAT09` Other tenant's data|0-1, 7|Not run|||
|`ORG-UAT10` Names at the time|none|Dropped|2026-11-07|Name history reverted (`027`). Names always show the current name|

\---

## 9\. Issues log

|ID|Stage|Problem|Found by|State|Fix or decision|
|-|-|-|-|-|-|
|`ORG-I01`|9j|The old stage table said "026 database (passed)". The old sections 4 and 6 and the Overview say `026` is written and not yet run|Document review during the split|Closed|`026` was run. Part A was reverted by `027` on 2026-11-07. Document corrected|
|`ORG-I02`|9j|The `026` test calls `private.enable\_level\_rule(company, level, parent level)`, written from documentation because `020` was not reviewed|Old Status|Closed|The test used `private.enable\_level\_rule` and passed (`026\_trimmed\_names\_test.sql`)|
|`ORG-I03`|Housekeeping|File name of `023` and test file names of `006`, `007`, `008`, `011` not recorded|Old Status|Open|Supply the names or accept|
|`ORG-I04`|Housekeeping|The old document contained stray escape characters before underscores and asterisks (a conversion artefact)|Document review|Fixed in this split|None|
|`ORG-I05`|9j|The Blueprint decision `ORG-D11` and section 4.6 were written for name history (names as they were). The decision was reversed: a corrected name shows everywhere regardless of date|Your decision|Open|Update the Blueprint (send `HRIS\_ORG\_BLUEPRINT.md`)|

\---

## 10\. Deployment checklist (P7)

* \[ ] Migrations applied to the test environment (dev project has `000` to `027`. No separate test or production project)
* \[ ] Environment variables set (nothing deployed to Vercel yet)
* \[ ] Workflows checked with real roles

\---

## 11\. Known limitations (P8)

|Limitation|Impact|Planned fix|
|-|-|-|
|History views show the **current** names of units and jobs (by design: name history was dropped in `027`)|A rename changes names everywhere, also in history. This is wanted: a corrected name shows everywhere|None|
|Reads are open to every tenant member, history included|Cannot be used for sensitive data (`EMP`)|Decide the read rule (`ORG-Q01`)|
|No function creates a tenant, company or membership (done by hand with `service\_role`). A member added later has no role until one is given|Setup is manual|`PLT`|
|No function or screen gives or removes roles. A user sees only their own assignments. Who may see all assignments of a tenant is undecided|Role management is manual|`PLT`|
|Headcount grid and history lists are not paged. Supabase returns at most 1000 rows per request, so a list or total is too low beyond that|Wrong totals on large data|Warning, then real paging (`ORG-Q11`)|
|Server-date defaults use UTC. Between 00:00 and 07:00 in Phnom Penh a record is dated one day early (`create\_org\_unit`, `create\_pos\_unit`, `create\_job\_position`, `enable\_level\_rule` and the rename functions)|One-day offset|Decide (`ORG-Q10`)|
|Khmer level names are empty|Khmer interface shows the level code or English|Stage 2b when names are supplied|
|Closed records cannot be re-opened|To bring something back, create it again. A re-created unit gets a new ID|Optional "Re-create" button (frontend only)|
|No SQL test file for the history views (`023`, `024`)|Checked in the browser only|Add a test if wanted|
|Only the dev Supabase project exists|No production environment|See Next plan, later items|

\---

## 12\. Lessons (ORG only)

* Migration numbers and ORG stages are not the same thing (for example ORG Stage 9c is migrations `014` to `020`; ORG Stage 5 is `006`; ORG Stages 6a/6b/6c are `007`/`008`/`009`; ORG Stage 9i is `023` and `024`).
* An empty dev database shows "No companies visible for your account". This is expected until a tenant, a company and a `tenant\_member` row exist. Check those three tables before debugging frontend code.
* Departments are not created under a Business Unit or the Parent Company. Create a Department on the Position tree tab ("Add top-level unit"), then list it for an org unit on the Department listings tab. Listings sit on org units only (not on the Parent Company) and are not inherited, so each Business Unit, Branch or Division that needs the Department needs its own listing.
* The current screens show only open records (`valid\_to is null`). A closed record is not deleted: it stays in `core` and shows under **Closed (history)** on its tab.
* A level cannot be disabled while another open rule uses it as parent. The blocker is a **rule**, not a unit, so it never shows on the tree screens. Example: Office could not be disabled because Section still had an open rule "Under Office". Disable the child rules first (for example Section and Group "Under Office"), then the parent level. Closing one rule of a level is allowed while another open rule of that level remains (Section "Under Department" can stay). To find the blocker, check the open rules of the company in `core.company\_level\_rule` (`valid\_to is null`).
* Closed records are never re-opened. Create them again instead (Blueprint `ORG-D09`).
* When a database function gains new views or columns, regenerate `database.types.ts` before writing the frontend queries, so the narrowing code matches the real columns.
* A rename is treated as a correction, not as a history event. ORG keeps no name history (reverted in `027`). If a real rebrand ever has to show the old name in the past, that needs a new decision.

Project-wide lessons are in `HRIS\_PROJECT\_OVERVIEW.md`, section 6.

\---

## 13\. How to resume

1. Open a new chat in the same Project and attach `HRIS\_PROJECT\_OVERVIEW.md`, this file and `package.json`. Name the Stage as "ORG Stage N" or "migration NNN" and paste any error text exactly.
2. For design, assumptions or open questions, also attach `HRIS\_ORG\_BLUEPRINT.md`.
3. For any ORG frontend change, also attach `HRIS\_ORG\_FRONTEND\_REFERENCE.md`, the file list of `app/`, `lib/supabase/` and `modules/org/`, `database.types.ts`, and the files the change builds on (section 5.2).
4. For database changes, attach the Blueprint (section 4) and the migration files the change depends on. If a guard function is involved, use the latest version (section 5.3).
5. If a file is missing, say so and Claude will ask whether to generate it.


# HRIS ORG Module: Status and History

Last updated: 2026-11-06
Purpose: Where the Organization structure (ORG) module is: scope, decisions, what has been created, stages and open items.
Read together with: `HRIS\_PROJECT\_OVERVIEW.md` (shared setup and conventions), `HRIS\_ORG\_FRONTEND\_REFERENCE.md` (what the frontend can use), `HRIS\_NAMING\_CONVENTION.md`

Module code: `ORG`. Stages are written "ORG Stage N". Migration headers that say "roadmap Stage X" mean ORG Stage X.

\---

## 1\. Scope

**In this module:**

* Org structure: Tenant -> Parent Company -> Business Unit -> Branch -> Division
* Position structure: Department -> Office -> Section -> Group, plus a job catalog (job positions) that belongs to Departments
* Department eligibility per org unit
* Approved headcount allocation (org unit + job + position unit)
* Closing units and reorganizing them

**Not in this module:** employees, hiring, transfers, promotions (later module, linking to ORG allocations), leave, attendance, payroll.

\---

## 2\. Requirements and rules

* Users pick from predetermined structures. Invalid combinations are never selectable (no Architect in an IT Department, none in a Banking Division).
* Levels are configurable and optional. **No placeholder records** ("N/A Division", "No Office"). The next active level links directly to its real parent.
* Cascading form: org location -> Department -> Office/Section/Group (filtered) -> eligible Position -> approved headcount.
* Every name supports English and Khmer.
* Rules that must hold: (1) a company cannot use another company's hierarchy; (2) disabling a level never silently invalidates records; (3) employee assignments stay historically consistent; (4) rule changes never rearrange existing records; (5) the design supports future hiring, transfers, promotions and allocation.

\---

## 3\. Decisions

### Your decisions

|Topic|Decision|
|-|-|
|Config scope|Hierarchy config is per **Parent Company**|
|Catalog|Departments and job positions are a Parent-Company-wide catalog|
|Position tree|Shared catalog, linked to org locations **only through allocations**|
|Reorgs|Needed (rarely)|
|Stage 2b (Khmer level names)|**Skipped for now.** Add later as a small seed migration when names are supplied|
|Roles (9a)|Three starting roles: `tenant\_admin`, `hr\_admin`, `viewer`. Permissions are stored as codes. Reads stay open to every tenant member. Existing members became `tenant\_admin`. Role changes are not logged|
|Role scope (9a)|A role is given for one scope: all companies of the tenant, one company, one org unit (subtree included) or one Department. The narrower scope replaces the broader one|
|9c permissions|The permission each wrapper checks was built as planned (section 4, "Public write wrappers")|

### Design choices

* **Two node tables, one pattern:** `org\_unit` (Business Unit, Branch, Division) and `pos\_unit` (Department, Office, Section, Group), sharing the level and rule tables.
* **Validity by composite foreign keys**, not triggers, wherever possible.
* **Versioned, never edited:** rules, parent links, eligibility rows and allocations are closed (`valid\_to`) and replaced. "Current" means `valid\_to is null`, everywhere including the read layer.
* **Stable IDs:** a unit keeps its ID through a reorg. Its parent lives in an effective-dated link table.
* **Root-level units:** generated `parent\_level\_key` (0 = directly under the root) is part of the foreign key to the rule.
* **Deferred check:** an open unit must end with an open parent link (checked at commit).
* **Closing cascades:** closing a unit closes its parent link, allocations and eligibility rows. A unit with open children cannot be closed. A Department with open jobs cannot be closed. Closing a job closes its allocations. A Department listing cannot be closed while allocations use it.
* **Rule guard:** closing the last open rule of a level is refused if the level is required, used as a parent by other rules, or has open units (`007`).
* **No company-level allocation:** every allocation sits at an org unit. A flat company enables one org level and creates one unit.
* **Position placement:** an allocation points to the job's own Department or any open descendant of it, at any depth (trigger-checked).

### Reorg behaviour (`009`)

* Moves one unit with its whole subtree. The unit ID never changes. Old link closes, new link opens.
* New parent must be an open unit of the same company, and an open rule must allow the level under it (this also blocks moving a unit under its own descendants).
* Effective date defaults to today and cannot be earlier than the current link's start or the new parent's start. A future date takes effect immediately (no "no future dates" check, because UTC would wrongly reject early-morning Phnom Penh dates).
* Eligibility rows and allocations stay attached to the unit.
* A position unit whose subtree has open allocations cannot move into another Department's tree. Departments cannot move. Org tree moves have no allocation restriction.

### Permission resolution (9a, `private.has\_permission`)

* Org side: nearest org unit assignment on the unit or above. Department side: the assignment on that Department.
* If a narrow assignment applies, it decides and company/tenant-wide roles are ignored. Every narrow assignment that applies must hold the permission (restriction wins). A side with no narrow assignment has no say.
* With no narrow assignment: company role, else tenant-wide role, else no.
* Closed, missing, other-company targets (or a non-Department for Department scope) are never valid. An assignment on a unit closed later grants nothing. A scope follows the unit's stable ID, so a reorg keeps the unit's admins.
* Hierarchy rules: company or tenant-wide assignments only.

### Assumptions (not yet confirmed by you)

* Any tenant member sees everything in their tenant for now.
* `name\_km` is optional, `name\_en` is required.
* Business Unit, Branch and Division may each sit directly under the Parent Company.
* Position tree: Department is required and the only top level. Office, Section, Group are optional.
* Khmer level names stay empty until supplied.
* `members.manage` is tenant-wide only.
* Renaming a Department itself needs a company-wide or tenant-wide role (same as creating or closing one). Renaming any other position unit needs `pos.unit.write` at its Department.
* Reference data the system needs (7 levels, roles, permission codes) is seeded inside its own migration (`002`, `012`). Sample and dev data stays outside migrations.

\---

## 4\. What has been created

All migrations are applied to the dev project. Migrations are one chain shared by all modules (`000`, `001` are shared platform files). Tests for `000` to `013`, `021` and `022` were run and **passed**. Test results for `014` to `020` are **not yet confirmed** (see section 6), although the allocation wrappers (`015`, with `014`) worked in the ORG Stage 9d browser test.

|Migration|Test|Purpose|
|-|-|-|
|`000\_create\_schemas.sql`|n/a|`core` and `private` schemas, minimal grants|
|`001\_tenancy.sql`|`001\_tenancy\_test.sql`|`tenant`, `parent\_company`, `tenant\_member`, `private.user\_tenant\_ids()`, RLS|
|`002\_hierarchy\_levels.sql`|`002\_hierarchy\_levels\_test.sql`|`hierarchy\_level` (7 seeded), versioned `company\_level\_rule`, guard, RLS|
|`003\_org\_tree.sql`|`003\_org\_tree\_test.sql`|`org\_unit`, `org\_unit\_parent`, guards, `private.create\_org\_unit`|
|`004\_position\_tree.sql`|`004\_position\_tree\_test.sql`|`pos\_unit`, `pos\_unit\_parent`, `private.create\_pos\_unit`|
|`005\_jobs\_and\_eligibility.sql`|`005\_jobs\_and\_eligibility\_test.sql`|`job\_position`, `org\_unit\_department`|
|`006\_allocation.sql`|passed (file name not recorded)|`position\_allocation`, `private.create\_allocation`, allocation guard, closing cascades|
|`007\_level\_disable\_guard.sql`|passed (file name not recorded)|Level cannot be disabled while open units exist|
|`008\_close\_unit.sql`|passed (file name not recorded)|`private.close\_org\_unit`, `private.close\_pos\_unit`|
|`009\_reorg.sql`|`009\_010\_reorg\_read\_layer\_test.sql`|`private.reorg\_org\_unit`, `private.reorg\_pos\_unit`, `private.pos\_department\_of`|
|`010\_read\_layer.sql`|`009\_010\_reorg\_read\_layer\_test.sql`|Read views and cascade functions in `public`|
|`011\_catalog\_read\_views.sql`|passed (file name not recorded)|`public.parent\_companies`, `public.hierarchy\_levels`|
|`012\_roles.sql`|`012\_roles\_test.sql`|`app\_role`, `permission`, `app\_role\_permission`, `member\_role\_scope`, 3 roles, 8 permission codes, scope guard, RLS. Unique `(id, company\_id)` on `org\_unit` and `pos\_unit`|
|`013\_has\_permission.sql`|`013\_has\_permission\_test.sql`|`private.has\_permission`, `private.has\_tenant\_permission`, `private.role\_has\_permission`|
|`014\_close\_allocation.sql`|`014\_close\_allocation\_test.sql`|`private.close\_allocation`|
|`015\_allocation\_wrappers.sql`|`015\_allocation\_wrappers\_test.sql`|`private.create\_allocation` replaced, public allocation wrappers|
|`016\_org\_unit\_wrappers.sql`|`016\_020\_wrappers\_test.sql`|Public org unit wrappers, `private.is\_company\_member`|
|`017\_pos\_unit\_wrappers.sql`|`016\_020\_wrappers\_test.sql`|Public position unit wrappers, `private.can\_manage\_pos\_unit`|
|`018\_job\_position\_functions.sql`|`016\_020\_wrappers\_test.sql`|Private and public job position functions|
|`019\_department\_listing\_functions.sql`|`016\_020\_wrappers\_test.sql`|Private and public Department listing functions|
|`020\_level\_rule\_functions.sql`|`016\_020\_wrappers\_test.sql`|Private and public level rule functions|
|`021\_permission\_check.sql`|`021\_permission\_check\_test.sql`|`public.check\_permissions` (ORG Stage 9e, database part)|
|`022\_rename\_unit.sql`|`022\_rename\_unit\_test.sql`|`private.rename\_org\_unit`, `private.rename\_pos\_unit`, public wrappers `rename\_org\_unit`, `rename\_pos\_unit` (ORG Stage 9f-1)|

### Tables

`core.hierarchy\_level`, `core.company\_level\_rule`, `core.org\_unit`, `core.org\_unit\_parent`, `core.pos\_unit`, `core.pos\_unit\_parent`, `core.job\_position`, `core.org\_unit\_department` (Departments each org unit may use, no inheritance), `core.position\_allocation`, plus roles: `core.app\_role`, `core.permission`, `core.app\_role\_permission`, `core.member\_role\_scope`.

### Permission codes (seeded in `012`)

|Code|Covers|Narrowest scope checked|Held by|
|-|-|-|-|
|`org.read`|View structure (not enforced, reads are open)|company or tenant|all three roles|
|`org.config.write`|Hierarchy rules|company or tenant|`tenant\_admin`, `hr\_admin`|
|`org.unit.write`|Create, close, move org units|org unit|`tenant\_admin`, `hr\_admin`|
|`org.eligibility.write`|List Departments for org units|org unit|`tenant\_admin`, `hr\_admin`|
|`pos.unit.write`|Create, close, move position units|Department|`tenant\_admin`, `hr\_admin`|
|`pos.job.write`|Manage job positions|Department|`tenant\_admin`, `hr\_admin`|
|`org.allocation.write`|Approved headcount allocations|org unit and Department|`tenant\_admin`, `hr\_admin`|
|`members.manage`|Members and roles|tenant|`tenant\_admin` only|

### Private write functions added in 9c (`service\_role` only)

|Function|Behaviour|
|-|-|
|`private.close\_allocation(company, allocation, close\_date)` (`014`)|Allocation must be open and belong to the company. Close date cannot be before the allocation's start. Closes only that allocation. A headcount change is close + create|
|`private.create\_allocation` (replaced in `015`)|New `p\_start\_date`. Refuses a start before the org unit, listing, job or position unit started|
|`private.create\_job\_position(company, Department, name EN, name KM)` (`018`)|Needs an open Department of the company. English name required, trimmed, unique among the Department's open jobs (clear duplicate message)|
|`private.rename\_job\_position(company, job, name EN, name KM)` (`018`)|Replaces both names. Empty Khmer name clears it|
|`private.close\_job\_position(company, job, close date)` (`018`)|Closes the job, the existing guard closes its allocations. Close date cannot be before the job's or its allocations' start|
|`private.add\_department\_listing(company, org unit, Department, start date)` (`019`)|Open org unit and open Department of the same company. Refuses an already-listed Department. Start date defaults to today and cannot be before the org unit's or Department's start, or the end of an earlier listing of the same pair|
|`private.remove\_department\_listing(company, org unit, Department, close date)` (`019`)|Closes the open listing. Refused while open allocations use it. Close date cannot be before the listing's start. A listing is found by org unit + Department, not by ID|
|`private.enable\_level\_rule(company, level, parent level or none)` (`020`)|Adds one rule. Clear messages for unknown level, parent in another tree, parent not higher, rule already enabled. Existing guard still decides "cannot sit under the root" and "parent level not enabled"|
|`private.disable\_level\_rule(company, rule, close date)` (`020`)|Closes one rule by ID. Close date cannot be before the rule's start. Existing guard still refuses closing a required level, a parent level, or a level with open units|

### Public write wrappers (9c)

All are `security definer`, call `private.has\_permission`, and are granted to `authenticated` and `service\_role` only.

|Wrapper|Permission and where it is checked|
|-|-|
|`create\_allocation`, `close\_allocation`, `change\_allocation\_headcount` (`015`)|`org.allocation.write`. Headcount change closes and recreates in one transaction|
|`create\_org\_unit(company, level, parent, name EN, name KM)` (`016`)|`org.unit.write` at the parent unit (a role on a unit covers its subtree). No parent: company or tenant-wide role only. Blank English name refused|
|`close\_org\_unit(company, unit, close date)` (`016`)|`org.unit.write` at the unit|
|`reorg\_org\_unit(company, unit, new parent, effective date)` (`016`)|`org.unit.write` on the unit and on the new parent. To the root: company or tenant-wide role|
|`create\_pos\_unit(company, level, parent, name EN, name KM)` (`017`)|`pos.unit.write` at the parent's Department. New Department: company or tenant-wide role. Blank English name refused|
|`close\_pos\_unit(company, unit, close date)` (`017`)|`pos.unit.write` at the unit's Department. Closing a Department itself: company or tenant-wide role only|
|`reorg\_pos\_unit(company, unit, new parent, effective date)` (`017`)|`pos.unit.write` on the unit's Department and the new parent's Department. To the top: company or tenant-wide role. Departments still cannot move|
|`create\_job\_position`, `rename\_job\_position`, `close\_job\_position` (`018`)|`pos.job.write` at the job's Department (a Department-scoped admin manages only their own Department's jobs)|
|`add\_department\_listing`, `remove\_department\_listing` (`019`)|`org.eligibility.write` at the org unit (a Branch role covers its Divisions). Department-scoped roles have no say (agreed in 9a)|
|`enable\_level\_rule`, `disable\_level\_rule` (`020`)|`org.config.write` at company or tenant level only|

**Helpers:** `private.is\_company\_member(company)` (`016`, replaces the repeated tenant-membership query in the allocation wrappers, which are otherwise unchanged). `private.can\_manage\_pos\_unit(company, unit)` (`017`, the "may the caller change this unit" rule shared by close and reorg).

**Error behaviour** (same pattern for org and position units, wording says "org units" or "position units"):

* Not a member, or no permission: "You do not have permission to manage org units here" (42501).
* A member naming a unit that is not open in the company: a plain "not an open unit" message.
* Level rules: a non-member asking about an unknown rule gets only "no permission"; a member gets "Rule % is not an open rule of this company".
* Everything else (rules, dates, "unit still has active units under it") comes from the private functions.

### Permission check for the frontend (9e, `021`)

`public.check\_permissions(p\_company\_id, p\_permission\_code, p\_targets)` closes gap G8 on the database side.

* `p\_targets` is a JSON array of `{org\_unit\_id, department\_id}` objects (either key can be missing or null). Default is one empty target, for company-level permissions such as `org.config.write`. At most 500 targets per call.
* Returns `org\_unit\_id`, `department\_id`, `allowed` for each distinct target.
* Calls `private.has\_permission`, the same check the write wrappers use, so the frontend and the database cannot disagree. A caller who is not logged in or not a member gets `allowed = false` for everything.
* Which key matters: `org.allocation.write` org unit and Department; `org.unit.write` and `org.eligibility.write` org unit; `pos.unit.write` and `pos.job.write` Department; `org.config.write` none.
* Granted to `authenticated` and `service\_role` only. It only hides what would fail. The wrappers still check on every write.

### Current versions of replaced functions

Start from the **latest** version when changing these:

* `private.company\_level\_rule\_guard()` -> `007`
* `private.org\_unit\_guard()`, `private.pos\_unit\_guard()`, `private.job\_position\_guard()`, `private.org\_unit\_department\_guard()` -> `006`
* `private.position\_allocation\_guard()` -> `006`
* `private.create\_allocation` -> `015`

### Dev seed data (not migrations, dev only)

* `seed\_dev\_tenant.sql`: 1 tenant ("Dev Tenant"), 1 parent company ("Dev Parent Company"), membership for `mek.rotha@gmail.com`. Refuses to run if `core.tenant` has rows.
* `seed\_dev\_org\_sample.sql`: 8 level rules, 6 org units, 6 position units, 6 Department listings, 5 jobs, 1 allocation (Software Engineer, Head Office, Backend Section, headcount 5). Inserts rules, listings and jobs straight into `core` and uses the private create functions for the rest. Refuses to run if the company already has ORG data. Khmer names are test samples.

### Frontend files (ORG Stages 8, 9d, 9e and 9f)

|File|What it does|
|-|-|
|`lib/supabase/client.ts`, `lib/supabase/server.ts`|Supabase clients typed with `<Database>` from `./database.types`|
|`proxy.ts`|Refreshes the session cookie, redirects signed-out visitors to `/login` and signed-in users away from it|
|`app/login/page.tsx`|Sign-in form (`signInWithPassword`)|
|`lib/i18n.ts`|`displayName(locale, nameEn, nameKm)`: Khmer when active and not empty, else English|
|`modules/org/types.ts`|Narrowed types: `ParentCompany`, `HierarchyLevel`, `CompanyLevelRule`, `UnitRow`, `UnitOption`, `JobOption`, `PositionAllocation`|
|`lib/dates.ts`|`todayInPhnomPenh()` (default for date fields, the server runs on UTC) and `isIsoDate()`|
|`modules/org/queries.ts`|**9f:** also `createUnit`, `renameUnit`, `closeUnit`, `reorgUnit` (one set for both trees, pass `"org"` or `"pos"`, with a readable message mapping for raw constraint errors). Browser wrappers for `org\_options`, `pos\_options`, `eligible\_departments`, `eligible\_jobs`, `fetchExistingAllocation`. **9d:** also `createAllocation`, `changeAllocationHeadcount`, `closeAllocation`, `MAX\_HEADCOUNT`, and a message mapping for raw constraint errors (`23505`, `23514`, `23503`). Permission (`42501`) and rule messages pass through|
|`modules/org/permissions.ts`|**9e, new.** `checkPermissions(company, code, targets)` calls `check\_permissions` in batches of up to 500 targets (any error = not allowed). `usePermissions(company, code, targets)` hook returns `can(orgUnitId, departmentId)` (false until the answer arrives) and `isLoading`. Constants `PERM\_ALLOCATION\_WRITE`, `PERM\_ORG\_UNIT\_WRITE`, `PERM\_POS\_UNIT\_WRITE`|
|`modules/org/labels.ts`|`levelLabel()` in the active language, falls back to the level code|
|`modules/org/components/AsyncSelect.tsx`|Dropdown that loads its own options, shows a reason when empty, reset with a `key`|
|`modules/org/components/CascadeSelector.tsx`|One dropdown per level, user can stop at any depth|
|`modules/org/components/OrgTreeExplorer.tsx`|Expandable tree with Expand all / Collapse all (org and position trees). **9f:** optional `manage` prop adds Add, Rename, Move and Close buttons per unit and "Add top-level unit", shown only where `check\_permissions` allows (one batched call). Refreshes the page after each save|
|`modules/org/components/UnitActionDialog.tsx`|**9f, new.** One modal for add, rename, close and move. Add offers only the levels the company's rules allow under that parent. Move offers only valid parents (never the unit itself or anything below it). Close is blocked in the form while open units are under it|
|`modules/org/unitTree.ts`|**9f, new.** Pure helpers: `descendantIds`, `departmentIdOf`, `childLevelRules`, `moveTargets`|
|`modules/org/components/AllocationForm.tsx`|Org location -> Department -> position unit -> job -> headcount and start date. Duplicate check. **9d:** Save calls `create\_allocation`, is blocked while the duplicate check runs or when an open allocation exists, clears job and headcount after saving, and refreshes the data. **9e:** Save is disabled with a reason when the user lacks `org.allocation.write` for the selected org unit and Department|
|`modules/org/components/AllocationActionDialog.tsx`|**9d, new.** Modal to change the headcount of one allocation or close it, with an effective or close date|
|`modules/org/components/HeadcountGrid.tsx`|Open allocations with search, org unit and Department filters, totals. Not paged. **9d:** Change and Close buttons on every row (new `companyId` prop). **9e:** one batched permission check for all rows. Change and Close show only where allowed, other rows show "View only"|
|`modules/org/components/OrgConfigView.tsx`|Header (company selector, EN / ខ្មែរ switch, sign out) and tabs: Configuration, Org tree, Position tree, Allocation form, Headcount. **9d:** passes `companyId` to the grid|
|`app/page.tsx`|Server loader inside `<Suspense>`: companies, levels, rules, org and position units, current allocations|

### How tests work

Plain SQL files. Paste one into Supabase Dashboard -> SQL Editor (dev project only). Each rolls back at the end. "Success. No rows returned" means pass. An error starting with `FAIL:` means a check failed. Tests `009\_010`, `012` and `013` create temporary users and switch role to `authenticated` and `anon`. Tests `012` and `013` need `seed\_dev\_org\_sample.sql`. `016\_020\_wrappers\_test.sql` covers the wrappers and private functions of `016` to `020`. `021\_permission\_check\_test.sql` uses temporary users and the sample data like `013`. `022\_rename\_unit\_test.sql` needs the sample data and a `tenant\_admin` user (set `v\_admin\_email` at the top).

\---

## 5\. ORG stages

|Stage|Name|Deliverable|State|
|-|-|-|-|
|0-1|Schemas, tenancy|`000`, `001`|Done, passed|
|2|Level catalog and company rules|`002`|Done, passed|
|3|Org tree|`003`|Done, passed|
|4|Position tree, jobs, eligibility|`004`, `005`|Done, passed|
|5|Allocation and headcount|`006`|Done, passed|
|6a / 6b / 6c|Level disable guard, close functions, reorg functions|`007`, `008`, `009`|Done, passed|
|7 / 7b|Read layer, catalog read views|`010`, `011`|Done, passed|
|2b|Khmer level names|Small seed migration|**Skipped for now**|
|8a-8d|Read-only frontend: foundation, config screen, trees and allocation form, headcount grid|Section 4|Done, passed|
|9a|Roles and permissions design|Section 3|Done, agreed|
|9b-1 / 9b-2|Role tables, permission check|`012`, `013`|Done, passed|
|9c|Write wrappers: allocations, org units, position units, jobs, Department listings, level rules|`014` to `020`|Done, passed|
|9d|Allocation save and headcount grid actions|Allocation form Save calls `create\_allocation` (start date, duplicate check). Headcount grid row actions: change headcount and close, each with an effective date. Clear message on `42501`, lists refresh after save. Date fields default to today's Phnom Penh date. Frontend only|Done, passed|
|9e|Own permissions and role-aware buttons|**Database:** `021` `public.check\_permissions` (closes gap G8). **Frontend:** permission helper (`modules/org/permissions.ts`), then disable Save on the allocation form and hide Change/Close on the headcount grid when not allowed|**Done, passed** (database and frontend)|
|9f|Org tree and position tree management|**Database:** `022` rename functions and wrappers. **Frontend:** add, rename, move and close units on both trees (`OrgTreeExplorer` with `manage`, `UnitActionDialog`, `unitTree.ts`), buttons hidden by `check\_permissions`|**Done, passed**|
|9g|Job catalog and Department listings|Screens for `create/rename/close\_job\_position` and `add/remove\_department\_listing`. Frontend only|Planned|
|9h|Hierarchy configuration screen|Enable and disable level rules (`enable\_level\_rule`, `disable\_level\_rule`). Frontend only|Planned|

**Remaining ORG work: 2 stages (9g, 9h).** The management screens use `modules/org/permissions.ts` from the start.

Not counted in the 2:

* **Members, roles and setup** (create tenant, company, membership, give and remove roles). Probably a platform stage rather than ORG, handled as its own module.
* **Optional:** Khmer level names (2b), history views (G6), paging the headcount grid.

Employee hooks (hiring, transfers, promotions) belong to a later Employee module, not ORG.

\---

## 6\. Where we are now

1. ORG Stages 0 to 9b are complete and tested. ORG Stage 9c is built (migrations `014` to `020`): every area has `public` write wrappers that check `private.has\_permission`.
2. **Permissions are now enforced on writes** through the wrappers. Reads are still open to every tenant member. The private write functions stay `service\_role` only.
3. The frontend can now save allocations (ORG Stage 9d, passed): the allocation form creates them and the headcount grid changes or closes them. ORG Stage 9f (unit management) is complete too. Jobs, Department listings and level rules have no screen yet. **ORG Stage 9e is complete (passed):** the allocation form and headcount grid hide or disable actions the user is not allowed to do, using `check\_permissions`.
4. Skipped for now: ORG Stage 2b (Khmer level names).
5. Next: ORG Stage 9g (jobs and Department listings), then 9h (hierarchy configuration). See section 5.

### Still missing

* Write functions not covered by `014` to `022`: create tenant, company and membership (do these by hand with `service\_role`; a member added later has no role until one is given).
* **Role management:** no function or screen gives or removes roles. A user sees only their own assignments (row level security). Decide who may see all assignments in a tenant when the members screen is built. Nothing stops the last `tenant\_admin` from being removed.
* **Headcount grid is not paged:** Supabase returns at most 1000 rows per request, so the grid and total would be too low beyond that. Fix when real data volume is known.

### Pending from you

* Confirm the tests `014\_close\_allocation\_test.sql`, `015\_allocation\_wrappers\_test.sql` and `016\_020\_wrappers\_test.sql` passed.
* Confirm the assumptions in section 3.
* Supply the Khmer names for the 7 levels when ready.
* Test file names for `006`, `007`, `008` and `011` if you want them recorded.

\---

## 7\. Lessons (ORG only)

* Migration numbers and ORG stages are not the same thing (for example ORG Stage 9c is migrations `014` to `020`; ORG Stage 5 is `006`; ORG Stages 6a/6b/6c are `007`/`008`/`009`).
* An empty dev database shows "No companies visible for your account". This is expected until a tenant, a company and a `tenant\_member` row exist. Check those three tables before debugging frontend code.

Project-wide lessons are in `HRIS\_PROJECT\_OVERVIEW.md`, section 6.

\---

## 8\. How to resume ORG work

1. Open a new chat in the same Project and attach `HRIS\_PROJECT\_OVERVIEW.md`, this file and `package.json`.
2. For ORG Stage 9g onward (frontend), also attach `HRIS\_ORG\_FRONTEND\_REFERENCE.md`, the file list of `app/`, `lib/supabase/` and `modules/org/`, `database.types.ts`, and the Stage 8 files the next step builds on (section 4).
3. For database changes, attach the migration files the change depends on. If a guard function is involved, use the latest version (section 4, "Current versions of replaced functions").
4. Say which stage you are on and paste any error text exactly.
5. If a file is missing, say so and Claude will ask whether to generate it.


# HRIS ORG Blueprint: Organization structure

Last updated: 2026-11-07
Purpose: What the Organization structure (ORG) module must do, which assumptions it rests on, how it behaves, and how its data is designed. Changed only through the decision table (section 6). Planned tasks and progress are in `HRIS_ORG_STATUS.md`.
Read together with: `HRIS_PROJECT_OVERVIEW.md`, `HRIS_MODULE_REGISTER.md`, `HRIS_CONTEXT.md`, `HRIS_ORG_STATUS.md`, `HRIS_ORG_FRONTEND_REFERENCE.md`, `HRIS_BUILD_STANDARDS.md`

> **About this Blueprint.** ORG was built before the Blueprint and Status method (`HRIS_BUILD_STANDARDS.md`, section 10). It was written afterwards from the old Status document. Where no answer was recorded (UAT scenarios, several scenario decisions), the entry says "Not recorded" and the gap is an open question in section 2. Entries marked **Proposed** are suggestions waiting for your confirmation.

---

## 0. Read this first

| Item | Value |
|---|---|
| Module code | `ORG`. Stages are written "ORG Stage N". Migration headers that say "roadmap Stage X" mean ORG Stage X |
| Table prefix | Not recorded as one prefix. Tables are named by what they hold (`org_unit`, `pos_unit`, `job_position`, `position_allocation`, `company_level_rule`, `hierarchy_level`, and others in 4.2) |
| Blueprint state | Written after the build began. Not gated: section 5 is not applied retroactively to Stages 0 to 9l. See section 5 |
| Depends on | `FND` (tenancy tables `000`, `001`), `PLT` (roles and permission check, `012`, `013`) |
| Used by | `EMP`, `LCY` (employee hooks to allocations), `SCH`, `REC` (through `LCY`) |
| Context rows used | `CTX-10` (Khmer and English), `CTX-12` (calendar), `CTX-13` (record retention, for deletion rules) |
| Ask for these files if needed | `HRIS_ORG_FRONTEND_REFERENCE.md` (frontend), the migrations named in `HRIS_ORG_STATUS.md` section 5.1 for the topic, the latest version of a guard function (`HRIS_ORG_STATUS.md` section 5.3) |

---

## 1. Requirements (P1)

### 1.1 Business objectives
- Model the company's **org structure**: Tenant, Parent Company, Business Unit, Branch, Division.
- Model the **position structure**: Department, Office, Section, Group, plus a job catalog (job positions) that belongs to Departments.
- Decide which Departments each org unit may use (Department eligibility).
- Hold **approved headcount** per org unit, job and position unit (allocation).
- Support closing units and **reorganizing** them, keeping history.
- Show history: a read-only view of closed rules, units, jobs, Department listings and allocations.

### 1.2 Workflows
1. **Configure levels:** a company enables a level under a parent level, or disables one rule. A level cannot be disabled while it is required, used as a parent by another open rule, or has open units.
2. **Build the trees:** add org units under their parent, and position units (Department first, then Office, Section, Group). Rename, move (reorg) or close them.
3. **Catalog jobs:** add, rename or close job positions under a Department.
4. **List Departments:** list a Department for an org unit (no inheritance), or remove the listing.
5. **Approve headcount:** pick org location, then Department, then Office/Section/Group (filtered), then an eligible position, then enter approved headcount and a start date. A headcount change closes the allocation and creates a new one on the effective date. Allocations can be closed.
6. **Read history:** switch a tab from Current to Closed (history).

### 1.3 Policies and rules
*These are design rules from the original requirements, not regulations. No `CTX-nn` row applies to them.*

| ID | Rule | Source | Verified | Note |
|---|---|---|---|---|
| `ORG-R01` | Users pick from predetermined structures. Invalid combinations are never selectable (no Architect in an IT Department, none in a Banking Division) | Original requirements | n/a | |
| `ORG-R02` | Levels are configurable and optional. **No placeholder records** ("N/A Division", "No Office"). The next active level links directly to its real parent | Original requirements | n/a | |
| `ORG-R03` | Cascading form: org location, Department, Office/Section/Group (filtered), eligible Position, approved headcount | Original requirements | n/a | |
| `ORG-R04` | Every name supports English and Khmer | Original requirements, `CTX-10` | `CTX-10` Unverified | Company policy to confirm |
| `ORG-R05` | A company cannot use another company's hierarchy | Original requirements | n/a | |
| `ORG-R06` | Disabling a level never silently invalidates records | Original requirements | n/a | |
| `ORG-R07` | Employee assignments stay historically consistent | Original requirements | n/a | Enforced for ORG's own records. Employee assignments arrive with `EMP` and `LCY` |
| `ORG-R08` | Rule changes never rearrange existing records | Original requirements | n/a | |
| `ORG-R09` | The design supports future hiring, transfers, promotions and allocation | Original requirements | n/a | Those processes belong to `LCY`, not ORG |

### 1.4 Roles: who can do what
*ORG roles are `tenant_admin`, `hr_admin` and `viewer`. No manager or employee role exists yet (see `ORG-Q06`). A role is given for one scope (Blueprint 4.4).*

| Action | `tenant_admin` | `hr_admin` | `viewer` | Permission code |
|---|---|---|---|---|
| View structure (not enforced: reads are open to every tenant member) | Yes | Yes | Yes | `org.read` |
| Enable or disable level rules | Yes | Yes | No | `org.config.write` (company or tenant level only) |
| Create, close, move org units | Yes | Yes | No | `org.unit.write` (org unit scope) |
| List or remove Departments for org units | Yes | Yes | No | `org.eligibility.write` (org unit scope) |
| Create, close, move position units | Yes | Yes | No | `pos.unit.write` (Department scope) |
| Manage job positions | Yes | Yes | No | `pos.job.write` (Department scope) |
| Create, change, close allocations | Yes | Yes | No | `org.allocation.write` (org unit and Department) |
| Manage members and roles | Yes | No | No | `members.manage` (tenant only) |
| Rename a position unit | Yes | Yes | No | `pos.unit.write` at its Department. Renaming a Department itself needs a company-wide or tenant-wide role |
| Rename an org unit | Not recorded | Not recorded | No | See `ORG-Q15` |

### 1.5 Out of scope
Employees, hiring, transfers, promotions (a later module, linking to ORG allocations), leave, attendance and payroll. Members, roles and setup (create tenant, company, membership, give and remove roles) is a platform concern handled as its own module (`PLT`). Employee hooks belong to `LCY`.

### 1.6 Acceptance criteria and UAT scenarios
*None were written when ORG was built. The scenarios below are **Proposed**, derived from rules already in this Blueprint. Confirm, change or add before P6. Results are tracked in `HRIS_ORG_STATUS.md`, section 8.*

| ID | Scenario | Role | Steps | Expected result |
|---|---|---|---|---|
| `ORG-UAT01` | Cascading selection | `hr_admin` | Open the Allocation form, pick org location, Department, position unit | Only valid options appear at each step. An invalid combination cannot be selected |
| `ORG-UAT02` | Create allocation, duplicate blocked | `hr_admin` | Save an allocation, then try to save the same combination again | The second save is refused with a clear message |
| `ORG-UAT03` | Change headcount | `hr_admin` | Change headcount with an effective date | One closed row with the old headcount shows under history. A new open row has the new headcount |
| `ORG-UAT04` | Close a unit | `hr_admin` | Try to close a unit that has open children, then close the children and retry | First attempt refused. Second closes the unit, its parent link, allocations and eligibility rows |
| `ORG-UAT05` | Reorg | `hr_admin` | Move a unit with its subtree to a new valid parent | The unit keeps its ID. Allocations stay attached. A position unit with open allocations cannot move into another Department's tree |
| `ORG-UAT06` | Viewer cannot write | `viewer` | Open every tab. Try a write | No write buttons. A direct write is refused with the permission message |
| `ORG-UAT07` | Department-scoped admin | Department-scoped role | Manage jobs in own Department and in another | Own Department works. The other is refused |
| `ORG-UAT08` | Disable level blocked | `hr_admin` | Disable a level that another open rule uses as parent | Refused with the guard message. Works after the child rules are disabled |
| `ORG-UAT09` | Other tenant's data | Member of tenant A | Look for tenant B's units | Nothing visible |
| `ORG-UAT10` | Names at the time (dropped) | n/a | n/a | Name history was reverted (`027`). Names always show the current name |
| `ORG-UAT11` | Re-create | `hr_admin` | Close a unit, a job and a Department listing. Open Closed (history) and click Re-create on each | The add dialog opens pre-filled. Saving gives a new open record with a new ID. The button is disabled with a reason when the old parent, org unit or Department is closed, or the listing is already open |

---

## 2. Assumptions, gaps and open questions

*Items `ORG-Q01` to `ORG-Q08` are the "Assumptions (not yet confirmed by you)" of the old Status. Settle them one by one. Each becomes a decision (section 6) or changes.*

| ID | Type | Text | If wrong, what changes | Affects | Blocks | Status | Settled by |
|---|---|---|---|---|---|---|---|
| `ORG-Q01` | Assumption | Any tenant member sees everything in their tenant for now, history included. Decide the read rule before the Employee module stores personal details or salary | Views, RLS or read functions change. `EMP` design depends on it | 4.5 | `EMP` | Open | |
| `ORG-Q02` | Assumption | `name_km` is optional, `name_en` is required | Constraints and forms change | 4.2 | None | Open | |
| `ORG-Q03` | Assumption | Business Unit, Branch and Division may each sit directly under the Parent Company | Level rules seed and guard change | 4.3 | None | Open | |
| `ORG-Q04` | Assumption | Position tree: Department is required and the only top level. Office, Section, Group are optional | Level rules change | 4.3 | None | Open | |
| `ORG-Q05` | Assumption | Khmer level names stay empty until supplied (Stage 2b is planned as `ORG-T022` and waits for the names) | A small seed migration when names arrive | 4.7 | None | Open | |
| `ORG-Q06` | Assumption | `members.manage` is tenant-wide only. A company-scoped `tenant_admin` cannot manage members. Also: no manager or employee role exists yet | Permission checks and the members screen change | 4.4 | `PLT` | Open | |
| `ORG-Q07` | Assumption | Renaming a Department itself needs a company-wide or tenant-wide role (same as creating or closing one). Renaming any other position unit needs `pos.unit.write` at its Department | `022` wrapper checks change | 4.4 | None | Open | |
| `ORG-Q08` | Assumption | Reference data the system needs (7 levels, roles, permission codes) is seeded inside its own migration (`002`, `012`). Sample and dev data stay outside migrations | Seed migrations move | 4.7 | None | Open | |
| `ORG-Q09` | Question | Dates in history reads: `valid_to` is the last valid day (inclusive) and a replacement starts on the date the old row ends. Checked against `009` and `015` and built in `028` | `028` date logic changes | 4.3 | None | Settled | `ORG-D12` (2026-11-07) |
| `ORG-Q10` | Gap | `create_org_unit`, `create_pos_unit`, `create_job_position`, `enable_level_rule` and the rename functions use the server date (UTC), so between 00:00 and 07:00 in Phnom Penh they date a record one day early. Decided: use the Phnom Penh date, no date parameters (`ORG-D27`). Not built yet (`ORG-T021`) | Function bodies change, the frontend stays | 3.4, 4.4 | None | Settled | `ORG-D27` (2026-11-07) |
| `ORG-Q11` | Gap | Paging: the headcount grid and the history lists are not paged. Supabase returns at most 1000 rows per request, so a list or total would be too low beyond that. A visible warning comes first (`ORG-T020`), real paging later | Read functions and screens change | 3.4, 4.6 | None | Open | |
| `ORG-Q12` | Gap | UAT scenarios were never written (section 1.6 is Proposed) | P6 cannot start | 1.6 | P6 | Open | |
| `ORG-Q13` | Question | Record retention for closed records, hard delete rules and anything to bring back (`SC-11`, `CTX-13`) | Deletion and archive rules | 4.8 | None | Open | |
| `ORG-Q14` | Question | Scenario answers not recorded in the old Status: back-dated limits and approval (`SC-02`), cancelling a future-dated record (`SC-07`), period lock (`SC-08`), repeat safety (`SC-13`), editing at the same time (`SC-10`), employee status effects (`SC-18`), bulk import (`SC-22`), Khmer sorting and search (`SC-23`). See 4.8 | Guards and write functions change | 4.8 | None | Open | |
| `ORG-Q15` | Gap | Which permission `rename_org_unit` (`022`) checks is not recorded in the old Status | The roles table (1.4) and wrapper table (4.4) change | 1.4, 4.4 | None | Open | |

---

## 3. Functional design (P2)

### 3.1 Screens
| Screen | Purpose | Who sees it | Main actions |
|---|---|---|---|
| Login (`/login`) | Sign in | Everyone | Sign in |
| Header | Company selector, EN / ខ្មែរ switch, sign out | Any member | Switch company, language |
| Configuration tab | Org and position level tables: status, allowed parents | Any member | Enable level, add parent option, disable rule (`org.config.write`) |
| Org tree tab | Expandable tree of org units, Expand all / Collapse all | Any member | Add, Rename, Move, Close, Add top-level unit (where allowed) |
| Position tree tab | Same, for position units | Any member | Same as above |
| Jobs tab | Open jobs with search and Department filter, open allocations per job | Any member | Add, rename, close job (`pos.job.write`) |
| Department listings tab | One row per org unit with its listed Departments | Any member | List a Department, remove a listing (`org.eligibility.write`) |
| Allocation form tab | Org location, Department, position unit, job, headcount, start date | Any member | Save an allocation (`org.allocation.write`). No history on this tab |
| Headcount tab | Open allocations with search, org unit and Department filters, totals | Any member | Change headcount, close (`org.allocation.write`), otherwise "View only" |
| Current / Closed (history) toggle | Switch a tab to its closed records. Org tree, Position tree, Department listings and Headcount also offer an As of date view. Both trees also offer Moves (reorg) | Any member | On six tabs: Configuration, Org tree, Position tree, Jobs, Department listings, Headcount. Closed units, jobs and Department listings have a Re-create button (`ORG-D28`) |

*Members screen belongs to `PLT`.*

### 3.2 User journeys
1. **Add a Department and make it usable:** Position tree tab, "Add top-level unit" (a Department), then Department listings tab, list it for each org unit that needs it.
2. **Approve headcount:** Allocation form tab, pick org location, Department, position unit, job, headcount and start date, Save. Changing it later: Headcount tab, Change, effective date.
3. **Reorganize:** Org or Position tree tab, Move on a unit, pick a valid new parent and an effective date.
4. **Bring back something closed:** Closed (history) tab of Org tree, Position tree, Jobs or Department listings, click Re-create. The add dialog opens pre-filled (names and level for a unit, names for a job, org unit and Department for a listing). Save to create a new record with a new ID. The button is disabled when the old parent, org unit or Department is closed, the level is no longer enabled there, or the Department is already listed. Closed level rules and allocations have no button: enable the level or save the allocation again (`ORG-D28`).
5. **Disable a level:** disable the child rules first, then the parent level.

### 3.3 Validations and messages
*Full error list for the frontend is in `HRIS_ORG_FRONTEND_REFERENCE.md`.*

| Field or action | Rule | Message shown |
|---|---|---|
| Any write without permission, or by a non-member | Permission check in the wrapper | "You do not have permission to manage org units here" (42501). Wording says "position units" for that tree |
| Unit named by a member that is not open in the company | Must be open | A plain "not an open unit" message |
| Level rule unknown | A non-member gets only "no permission". A member gets the rule message | "Rule % is not an open rule of this company" |
| English name | Required, trimmed. Blank refused (units, `026`) | Blank English name refused |
| Job name | Unique among the Department's open jobs | Clear duplicate message |
| Department listing | Refused if already listed. Start date not before the org unit's or Department's start, or the end of an earlier listing of the same pair | Plain message from the private function |
| Remove listing | Refused while open allocations use it | Form blocks it and says to close them on the Headcount tab first |
| Close unit | Refused while open children exist. A Department with open jobs cannot be closed | Blocked in the form while open units are under it |
| Re-create (closed unit, job or Department listing) | Opens the add dialog pre-filled. The save follows the add rules. Disabled when the old parent, org unit or Department is closed, the level is no longer enabled under the parent, or the listing is already open | The reason shows as hover text on the disabled button |
| Constraint errors (`23505`, `23503`, `23514`) | Mapped by the frontend | "This change is not valid any more. Refresh the page and try again." Other messages pass through |
| Dates | A close date cannot be before the record's start | Plain message from the private function |

### 3.4 Expected behaviour and edge cases
- **Empty states:** an empty dev database shows "No companies visible for your account" until a tenant, a company and a `tenant_member` row exist.
- **Current vs closed:** current screens show only open records (`valid_to is null`). A closed record is not deleted. It shows under Closed (history).
- **Dates:** server defaults still use UTC, so between 00:00 and 07:00 in Phnom Penh they are one day early. They will use the Phnom Penh date (`ORG-D27`, task `ORG-T021`). The frontend passes the user's date explicitly and defaults date fields to today's Phnom Penh date. A future effective date on a reorg takes effect immediately (see 4.3).
- **Names:** show `name_km` when the interface is Khmer and it is not empty, otherwise `name_en`. History views show the **current** names of units and jobs (a rename changes them everywhere, `ORG-D11`).
- **Flat company:** enable one org level and create one unit.
- **Large lists:** lists and totals are wrong beyond 1000 rows (`ORG-Q11`). A warning is planned (`ORG-T020`).
- **Departments** are not created under a Business Unit or the Parent Company. They are created on the Position tree tab and listed for each org unit that needs them. Listings are not inherited.

---

## 4. Database design (P3)

### 4.1 Entities and relationships
- Two node tables with one pattern: `org_unit` (Business Unit, Branch, Division) and `pos_unit` (Department, Office, Section, Group), sharing the level and rule tables.
- Parents live in effective-dated link tables, so a unit keeps its ID through a reorg.
- The position tree is a shared catalog (Parent-Company-wide), linked to org locations **only through allocations**.
- An allocation = org unit + job + position unit + approved headcount.
- Each org unit lists the Departments it may use (`org_unit_department`, no inheritance).
- Roles and scopes (`012`, `013`) belong to the platform and are used by every write wrapper.

### 4.2 Tables
All in schema `core`. *Key columns are summarised from the old Status. The migrations are the truth.*

| Table | Purpose | Key columns | History |
|---|---|---|---|
| `hierarchy_level` | The 7 seeded levels | level code | Reference data |
| `company_level_rule` | Which level may sit under which parent level, per Parent Company | company, level, parent level, `valid_from`, `valid_to` | Keep (close and replace) |
| `org_unit` | Business Unit, Branch, Division | ID, company, level, names | Close, never edit. Unique `(id, company_id)` |
| `org_unit_parent` | Parent link of an org unit | unit, parent, `parent_level_key`, dates | Keep (close and replace) |
| `pos_unit` | Department, Office, Section, Group | ID, company, level, names | Close, never edit. Unique `(id, company_id)` |
| `pos_unit_parent` | Parent link of a position unit | unit, parent, dates | Keep |
| `job_position` | Job catalog, belongs to a Department | ID, Department, names | Close, never edit |
| `org_unit_department` | Departments each org unit may use (no inheritance) | org unit, Department, dates | Keep |
| `position_allocation` | Approved headcount | org unit, job, position unit, headcount, dates | Keep (headcount change = close and create) |
| `app_role`, `permission`, `app_role_permission`, `member_role_scope` (`012`) | Roles and permissions (platform, see Overview 5.7) | | No role history |

### 4.3 Constraints and rules
**Rules the database enforces**
- **Validity by composite foreign keys**, not triggers, wherever possible.
- **Versioned, never edited:** rules, parent links, eligibility rows and allocations are closed (`valid_to`) and replaced. "Current" means `valid_to is null`, everywhere including the read layer.
- **No re-open:** every guard refuses changing a closed record (see `ORG-D09`).
- **Root-level units:** generated `parent_level_key` (0 = directly under the root) is part of the foreign key to the rule.
- **Deferred check:** an open unit must end with an open parent link (checked at commit).
- **Closing cascades:** closing a unit closes its parent link, allocations and eligibility rows. A unit with open children cannot be closed. A Department with open jobs cannot be closed. Closing a job closes its allocations. A Department listing cannot be closed while allocations use it.
- **Rule guard (`007`):** closing the last open rule of a level is refused if the level is required, used as a parent by other rules, or has open units. Other rules of the same level may stay open, so closing one rule of a level is allowed.
- **No company-level allocation:** every allocation sits at an org unit.
- **Position placement:** an allocation points to the job's own Department or any open descendant of it, at any depth (trigger-checked).
- **Allocation start:** refused before the org unit, listing, job or position unit started (`015`).
- **Names:** trimmed on create, blank English name refused (`026`).

**Reorg behaviour (`009`)**
- Moves one unit with its whole subtree. The unit ID never changes. The old link closes, the new link opens.
- The new parent must be an open unit of the same company, and an open rule must allow the level under it (this also blocks moving a unit under its own descendants).
- The effective date defaults to today and cannot be earlier than the current link's start or the new parent's start. A future date takes effect immediately (there is no "no future dates" check, because UTC would wrongly reject early-morning Phnom Penh dates).
- Eligibility rows and allocations stay attached to the unit.
- A position unit whose subtree has open allocations cannot move into another Department's tree. Departments cannot move. Org tree moves have no allocation restriction.

### 4.4 Functions and permission codes

**Permission codes (seeded in `012`)**

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

**Permission resolution (`private.has_permission`, ORG Stage 9a)**
- Org side: the nearest org unit assignment on the unit or above. Department side: the assignment on that Department.
- If a narrow assignment applies, it decides and company or tenant-wide roles are ignored. Every narrow assignment that applies must hold the permission (restriction wins). A side with no narrow assignment has no say.
- With no narrow assignment: company role, else tenant-wide role, else no.
- Closed, missing or other-company targets (or a non-Department for Department scope) are never valid. An assignment on a unit closed later grants nothing. A scope follows the unit's stable ID, so a reorg keeps the unit's admins.
- Hierarchy rules: company or tenant-wide assignments only.

**Private write functions (`service_role` only)**

| Function | Behaviour |
|---|---|
| `private.create_org_unit`, `private.create_pos_unit` (latest: `026`) | Create a unit. Names trimmed, blank English name refused |
| `private.close_org_unit`, `private.close_pos_unit` (`008`) | Close a unit with the cascades above |
| `private.reorg_org_unit`, `private.reorg_pos_unit` (`009`), `private.pos_department_of` | Move a unit with its subtree |
| `private.rename_org_unit`, `private.rename_pos_unit` (`022`) | Rename (a rename is a correction, `ORG-D11`) |
| `private.close_allocation(company, allocation, close_date)` (`014`) | Allocation must be open and belong to the company. Close date cannot be before the allocation's start. Closes only that allocation. A headcount change is close + create |
| `private.create_allocation` (replaced in `015`) | New `p_start_date`. Refuses a start before the org unit, listing, job or position unit started |
| `private.create_job_position(company, Department, name EN, name KM)` (`018`) | Needs an open Department of the company. English name required, trimmed, unique among the Department's open jobs |
| `private.rename_job_position(company, job, name EN, name KM)` (`018`) | Replaces both names. An empty Khmer name clears it |
| `private.close_job_position(company, job, close date)` (`018`) | Closes the job, the existing guard closes its allocations. Close date cannot be before the job's or its allocations' start |
| `private.add_department_listing(company, org unit, Department, start date)` (`019`) | Open org unit and open Department of the same company. Refuses an already-listed Department. Start date defaults to today and cannot be before the org unit's or Department's start, or the end of an earlier listing of the same pair |
| `private.remove_department_listing(company, org unit, Department, close date)` (`019`) | Closes the open listing. Refused while open allocations use it. Close date cannot be before the listing's start. A listing is found by org unit + Department, not by ID |
| `private.enable_level_rule(company, level, parent level or none)` (`020`) | Adds one rule. Clear messages for unknown level, parent in another tree, parent not higher, rule already enabled. The existing guard still decides "cannot sit under the root" and "parent level not enabled" |
| `private.disable_level_rule(company, rule, close date)` (`020`) | Closes one rule by ID. Close date cannot be before the rule's start. The existing guard still refuses closing a required level, a parent level, or a level with open units |

**Public write wrappers**
All are `security definer`, call `private.has_permission`, and are granted to `authenticated` and `service_role` only.

| Wrapper | Permission and where it is checked |
|---|---|
| `create_allocation`, `close_allocation`, `change_allocation_headcount` (`015`) | `org.allocation.write`. A headcount change closes and recreates in one transaction |
| `create_org_unit(company, level, parent, name EN, name KM)` (`016`) | `org.unit.write` at the parent unit (a role on a unit covers its subtree). No parent: company or tenant-wide role only. Blank English name refused |
| `close_org_unit(company, unit, close date)` (`016`) | `org.unit.write` at the unit |
| `reorg_org_unit(company, unit, new parent, effective date)` (`016`) | `org.unit.write` on the unit and on the new parent. To the root: company or tenant-wide role |
| `create_pos_unit(company, level, parent, name EN, name KM)` (`017`) | `pos.unit.write` at the parent's Department. New Department: company or tenant-wide role. Blank English name refused |
| `close_pos_unit(company, unit, close date)` (`017`) | `pos.unit.write` at the unit's Department. Closing a Department itself: company or tenant-wide role only |
| `reorg_pos_unit(company, unit, new parent, effective date)` (`017`) | `pos.unit.write` on the unit's Department and the new parent's Department. To the top: company or tenant-wide role. Departments still cannot move |
| `rename_org_unit`, `rename_pos_unit` (`022`) | Not recorded in detail. See `ORG-Q07`, `ORG-Q15` |
| `create_job_position`, `rename_job_position`, `close_job_position` (`018`) | `pos.job.write` at the job's Department (a Department-scoped admin manages only their own Department's jobs) |
| `add_department_listing`, `remove_department_listing` (`019`) | `org.eligibility.write` at the org unit (a Branch role covers its Divisions). Department-scoped roles have no say (agreed in 9a) |
| `enable_level_rule`, `disable_level_rule` (`020`) | `org.config.write` at company or tenant level only |

**Helpers:** `private.is_company_member(company)` (`016`, replaces the repeated tenant-membership query in the allocation wrappers). `private.can_manage_pos_unit(company, unit)` (`017`, the "may the caller change this unit" rule shared by close and reorg).

**Permission check for the frontend (`021`, `public.check_permissions(p_company_id, p_permission_code, p_targets)`)**
- `p_targets` is a JSON array of `{org_unit_id, department_id}` objects (either key can be missing or null). Default is one empty target, for company-level permissions such as `org.config.write`. At most 500 targets per call.
- Returns `org_unit_id`, `department_id`, `allowed` for each distinct target.
- Calls `private.has_permission`, the same check the write wrappers use, so the frontend and the database cannot disagree. A caller who is not logged in or not a member gets `allowed = false` for everything.
- Which key matters: `org.allocation.write` org unit and Department. `org.unit.write` and `org.eligibility.write` org unit. `pos.unit.write` and `pos.job.write` Department. `org.config.write` none.
- Granted to `authenticated` and `service_role` only. It only hides what would fail. The wrappers still check on every write.

**Error behaviour** (same pattern for org and position units):
- Not a member, or no permission: "You do not have permission to manage org units here" (42501).
- A member naming a unit that is not open in the company: a plain "not an open unit" message.
- Level rules: a non-member asking about an unknown rule gets only "no permission". A member gets "Rule % is not an open rule of this company".
- Everything else (rules, dates, "unit still has active units under it") comes from the private functions.

### 4.5 Visibility (RLS)
- Company-scoped tables use the platform tenant pattern (`company_id in (select id from core.parent_company)`, Overview 5.2).
- **Roles are enforced on writes** (wrappers). **Reads are open to every member of a tenant**, history included (`ORG-Q01`).
- `*_closed` views have the same security as the `*_current` views (`security_invoker`).
- Frontend access follows Overview 5.4: browser reads `public`, writes only through wrappers, no direct table writes.

### 4.6 Public contract
*Not declared as a list when ORG was built. **Proposed:** the objects below are the stable contract. Details are in `HRIS_ORG_FRONTEND_REFERENCE.md`.*

**Current views** (`010`, `011`): `company_level_rules_current`, `org_units_current`, `pos_units_current`, `org_unit_departments_current`, `job_positions_current`, `position_allocations_current`, `parent_companies`, `hierarchy_levels`.

**Closed (history) views** (`023`, `024`, `valid_to is not null`):
- `company_level_rules_closed`: level, parent level, start and end date.
- `org_units_closed`, `pos_units_closed`: name, level, the parent the unit had when it closed, start and end date.
- `job_positions_closed`: job and its Department's name, start and end date.
- `org_unit_departments_closed`: org unit and Department names, start and end date.
- `position_allocations_closed`: same columns as `position_allocations_current` plus `valid_to`.

**Functions:** the public write wrappers and `public.check_permissions` in 4.4.

**History reads (`028`, Stage 9k):**
- `org_unit_parent_links_closed`, `pos_unit_parent_links_closed`: closed parent links of units. An empty `unit_valid_to` means the unit is still open, so the link ended by a reorg.
- `org_units_as_of`, `pos_units_as_of`, `position_allocations_as_of`, `org_unit_departments_as_of`: each takes a company and a required date. `valid_to` is the last valid day (inclusive). Where two rows touch on one date, the one that started later wins, then the higher id (`ORG-D12`).
- Names in history are always the current names (`ORG-D11` was reversed in `027`). As-of reads for jobs and level rules are not built (`ORG-D13`).

### 4.7 Reference and seed data
- 7 hierarchy levels, roles and permission codes are seeded inside their own migrations (`002`, `012`).
- Khmer level names are empty until supplied (Stage 2b skipped, `ORG-Q05`).
- Sample and dev data stays outside migrations (files listed in `HRIS_ORG_STATUS.md`, section 5.4).

### 4.8 Scenario decisions
*Filled from the old Status. "Not recorded" means the old document gave no answer, and the item is covered by `ORG-Q14`. Nothing here was decided on your behalf.*

| Scenario | Applies to | Decision, or "Does not apply: reason" | Build consequence |
|---|---|---|---|
| SC-01 History needed | Rules, parent links, eligibility rows, allocations | Applies. Close and replace, never edit. No name history: a rename is a correction (`ORG-D11`) | `valid_from` / `valid_to`, closed views, as-of reads (`028`) |
| SC-02 Back-dated entry | Reorg, allocation, listing, rule, close | Partly decided. Dates cannot be before the related record's start (`ORG-D25`, 4.4). A close date cannot be before the record's start. Limit on how far back, approval and effect on processed data: not recorded | Date checks in private functions. Nothing downstream exists yet |
| SC-03 Future-dated entry | Reorg, allocation | A future date is stored and counts as current (`valid_to is null`). No job is needed because only data changes. A reorg with a future date takes effect immediately | As-of reads (`028`) |
| SC-04 Scheduled runs | All | Does not apply: no scheduled run is recorded in the old Status | None |
| SC-05 Overlap and gaps | Rules, listings, allocations, jobs | Duplicates refused: a rule already enabled, a Department already listed, a job name already in the Department, a duplicate allocation (frontend check). A replacement may start on the date the old row ends (`ORG-D12`). Gaps: not recorded | Composite keys, guards, plain messages |
| SC-06 Correction or change | Names, headcount, parent | A rename replaces the name everywhere and keeps no history (`ORG-D11`). A headcount change is close + create. A parent change is a reorg | `022`, `015`, `009` |
| SC-07 Cancel or reverse | All | Close only. No re-open (`ORG-D09`). Cancelling a future-dated record: not recorded | Re-create instead (Re-create button on closed units, jobs and listings, `ORG-D28`) |
| SC-08 Period lock | All | Not recorded. Nothing processed depends on ORG yet | Revisit with `EMP` and `PAY` |
| SC-09 Add | Units, jobs, listings, rules, allocations | English name required and trimmed. Unique job name per Department. Duplicate listing and rule refused. No draft state. IDs are generated | Wrappers and private functions |
| SC-10 Edit | Units, jobs | Only names change (rename). Parent changes go through reorg. Closed records cannot change. Editing at the same time: not recorded | Guards refuse changes to closed rows |
| SC-11 Delete | All | Close, not delete (`ORG-D09`). A re-created unit gets a new ID. Retention: not recorded (`CTX-13`) | No hard delete |
| SC-12 Triggers | See 4.9 | Rules that must always hold are guards and triggers. Business steps are write functions | Listed in 4.9 |
| SC-13 Repeat safety | Write functions | Partly: duplicate rules, listings and job names are refused. General answer not recorded | |
| SC-14 Status model | All | Does not apply: no status column. A record is open (`valid_to is null`) or closed | |
| SC-15 Approval | All | Does not apply in ORG as built. Shared approval workflow is planned in `PLT` | |
| SC-16 Notifications | All | Does not apply: none recorded | |
| SC-17 Who acts on whom | All | Permission codes and scopes in 4.4. Reads open to every member (`ORG-Q01`). No sensitive personal fields in ORG | |
| SC-18 Employee status effects | Allocations | Not recorded. Employee hooks belong to `LCY` | Decide with `EMP` and `LCY` |
| SC-19 Stored or calculated | Headcount | Approved headcount is stored. Nothing is calculated in ORG | |
| SC-20 Money, rounding, calendar | All | Does not apply to money. Calendar: dates are UTC by default and the frontend passes the user's date. Server defaults will move to the Phnom Penh date (`ORG-D27`) | |
| SC-21 Reporting needs | History | As-of reads (`028`). Paging missing (`ORG-Q11`) | |
| SC-22 Bulk data | All | Not recorded | |
| SC-23 Khmer and calendar | Names, level names | Bilingual names, Khmer shown when active and not empty. Khmer level names empty. Khmer sort and search: not recorded | |

### 4.9 Triggers and scheduled runs
*Names are taken from the old Status. "Not recorded" for repeat safety is part of `ORG-Q14`.*

| Name | Type | When it fires | What it does | Tables touched | Safe to repeat? |
|---|---|---|---|---|---|
| `private.company_level_rule_guard()` (`007`) | Trigger | Change to a level rule | Refuses closing the last open rule of a required, parent or in-use level | `company_level_rule` | Not recorded |
| `private.org_unit_guard()`, `private.pos_unit_guard()`, `private.job_position_guard()`, `private.org_unit_department_guard()` (`006`) | Trigger | Change to the table | Refuses changing a closed record. Applies closing cascades | The unit, link, job and listing tables, and allocations | Not recorded |
| `private.position_allocation_guard()` (`006`) | Trigger | Change to an allocation | Checks position placement and refuses changing a closed record | `position_allocation` | Not recorded |
| Open parent link check (migration not recorded) | Deferred constraint | At commit | An open unit must end with an open parent link | `org_unit_parent`, `pos_unit_parent` | n/a |
| `private.member_role_scope_guard()` (`012`) | Trigger | Change to a role assignment | Scope guard | `core.member_role_scope` | Not recorded |
| `private.member_role_scope_last_admin_guard()` (`025`, platform) | Trigger | Delete or downgrade of a role assignment, removing a member or an auth user | Refuses removing the last tenant-wide `tenant_admin` (see `ORG-D10`) | `core.member_role_scope` | Not recorded |
| Scheduled runs | | | None in ORG | | |

---

## 5. Foundation gate: ready for Stage 1

*ORG started before this method, so Stages 0 to 9l were not gated. The gate is shown for the record. A tick means the evidence exists in this document.*

- [ ] Phase P1 closed: you have not formally approved sections 1.1 to 1.5 as rewritten here
- [x] Every item in section 2 with "Blocks = Stage 9k" is Settled: `ORG-Q09` settled (2026-11-07)
- [ ] Every `CTX-nn` row used by this module is verified, or recorded as a company decision (`CTX-10`, `CTX-12`, `CTX-13` are Unverified)
- [ ] Section 1.3 has no rule marked "To verify" that a Stage 9k table depends on
- [ ] Screens, validations and edge cases written (3.1 to 3.4): written, awaiting your approval
- [ ] Tables, constraints, functions, permission codes and visibility written (4.1 to 4.7): written, awaiting your approval
- [ ] Scenario table 4.8 has no blank row: no blank rows, but several "Not recorded" answers (`ORG-Q14`)
- [ ] Triggers and scheduled runs listed (4.9), each with a repeat-safety answer: repeat safety not recorded
- [ ] Table prefix agreed and the module row in `HRIS_MODULE_REGISTER.md` is current: no prefix recorded
- [ ] You approved this Blueprint (date: )

---

## 6. Decisions

*Taken from the old Status without change. Dates were not recorded, so the Date column is "not recorded". Decisions taken or changed since the split carry a date. Details of each decision are in the section named in the last column, not repeated here.*

| ID | Date | Decision | Origin | Reason | Sections |
|---|---|---|---|---|---|
| `ORG-D01` | not recorded | Hierarchy config is per **Parent Company** | Your decision | | 4.2 |
| `ORG-D02` | not recorded | Departments and job positions are a Parent-Company-wide catalog | Your decision | | 4.1 |
| `ORG-D03` | not recorded | Position tree is a shared catalog, linked to org locations **only through allocations** | Your decision | | 4.1 |
| `ORG-D04` | not recorded | Reorgs are needed (rarely) | Your decision | | 4.3 |
| `ORG-D05` | 2026-11-07 (changed) | Stage 2b (Khmer level names) was skipped at first. It is now planned as `ORG-T022`: a small seed migration, built when you supply the 7 Khmer names | Your decision | | 4.7 |
| `ORG-D06` | not recorded | Three starting roles: `tenant_admin`, `hr_admin`, `viewer`. Permissions stored as codes. Reads stay open to every tenant member. Existing members became `tenant_admin`. Role changes are not logged | Your decision (Stage 9a) | | 4.4, 4.5 |
| `ORG-D07` | not recorded | A role is given for one scope: all companies of the tenant, one company, one org unit (subtree included) or one Department. The narrower scope replaces the broader one | Your decision (Stage 9a) | | 4.4 |
| `ORG-D08` | not recorded | The permission each wrapper checks was built as planned | Your decision (Stage 9c) | | 4.4 |
| `ORG-D09` | not recorded | History covers closed rules, units, jobs, Department listings and allocations. Closed records are **not re-opened**. To bring something back, create it again (a Re-create button pre-fills the add form, `ORG-D28`). Closing cascades, so re-opening would have to undo exactly those and could clash with newer records or a closed rule | Your decision (Stage 9i) | Re-opening is risky | 3.2, 4.3 |
| `ORG-D10` | not recorded | A tenant must always keep at least one **tenant-wide** `tenant_admin` (a company-scoped one does not count). Minimum 1. Applies to everyone, including `service_role` and manual SQL. A user may remove or downgrade their own admin role while another admin exists. A whole tenant can be deleted only after `select set_config('hris.tenant_teardown', 'on', true);` in the same transaction | Your decision (`025`, tested 2026-11-07) | | 4.9 |
| `ORG-D11` | 2026-11-07 (reversed) | **Reversed.** A rename is a correction: the new name shows everywhere, in history too, regardless of date. No name history is kept (`core.name_history` and its triggers were removed by `027`). Names are still trimmed in the database on create and an empty Khmer name is stored as null (`026`, part B) | Your decision (`026`, reversed in `027`) | A corrected name must show everywhere | 4.2 |
| `ORG-D12` | not recorded | In history reads, `valid_to` is the last valid day (inclusive). A replacement (headcount change, reorg, rename) starts on the date the old row ends, so two rows can touch on one date: the one that started later wins. Confirmed against `009` and `015` and built in `028` (2026-11-07) | Your decision (Stage 9k) | | 4.3, `ORG-Q09` |
| `ORG-D13` | not recorded | As-of date reads (`028`, built) cover the org tree, the position tree, allocations and headcount, and Department listings. Jobs and level rules can be added later | Your decision (Stage 9k) | | 4.6 |
| `ORG-D14` | not recorded | Two node tables, one pattern: `org_unit` and `pos_unit`, sharing the level and rule tables | Adopted | | 4.1 |
| `ORG-D15` | not recorded | Validity by composite foreign keys, not triggers, wherever possible | Adopted | | 4.3 |
| `ORG-D16` | not recorded | Versioned, never edited. "Current" means `valid_to is null` everywhere, including the read layer | Adopted | | 4.3 |
| `ORG-D17` | not recorded | History is read-only `*_closed` views with the same security as the `*_current` views. Names shown are the current names (`ORG-D11`) | Adopted | | 4.5, 4.6 |
| `ORG-D18` | not recorded | Stable IDs: a unit keeps its ID through a reorg. Its parent lives in an effective-dated link table | Adopted | | 4.1 |
| `ORG-D19` | not recorded | Root-level units: generated `parent_level_key` (0 = directly under the root) is part of the foreign key to the rule | Adopted | | 4.3 |
| `ORG-D20` | not recorded | Deferred check: an open unit must end with an open parent link (at commit) | Adopted | | 4.3 |
| `ORG-D21` | not recorded | Closing cascades (unit, job, listing rules) | Adopted | | 4.3 |
| `ORG-D22` | not recorded | Rule guard (`007`): closing the last open rule of a level is refused if required, used as parent, or has open units | Adopted | | 4.3 |
| `ORG-D23` | not recorded | No company-level allocation: every allocation sits at an org unit. A flat company enables one org level and creates one unit | Adopted | | 4.3 |
| `ORG-D24` | not recorded | Position placement: an allocation points to the job's own Department or any open descendant of it, at any depth (trigger-checked) | Adopted | | 4.3 |
| `ORG-D25` | not recorded | Reorg behaviour (`009`) | Adopted | | 4.3 |
| `ORG-D26` | not recorded | Permission resolution (`private.has_permission`) | Adopted | | 4.4 |
| `ORG-D27` | 2026-11-07 | Server-date defaults use the Phnom Penh date (UTC+7), not UTC. No date parameters are added. Applies to `create_org_unit`, `create_pos_unit`, `create_job_position`, `enable_level_rule` and the rename functions. Built as `ORG-T021` | Your decision | A record created between 00:00 and 07:00 in Phnom Penh was dated one day early | 3.4, 4.4, `ORG-Q10` |
| `ORG-D28` | 2026-11-07 | Closed units, jobs and Department listings get a Re-create button that opens the add dialog pre-filled. The start date is left to the default. The button is disabled when the old parent, org unit or Department is closed, the level is no longer enabled there, or the listing is already open. Closed level rules and allocations get no button | Your decision (Stage 9l) | Closed records are never re-opened (`ORG-D09`), so a re-created record is a new one | 3.2 |

# HRIS ORG Module: Status and History

Last updated: 2026-11-06
Purpose: Where the Organization structure (ORG) module is: scope, requirements, decisions, what has been created, stages and open items.
Read together with: `HRIS_PROJECT_OVERVIEW.md` (shared setup and conventions), `HRIS_ORG_FRONTEND_REFERENCE.md` (what the frontend can use), `HRIS_NAMING_CONVENTION.md`

Module code: `ORG`. Stages below are written "ORG Stage N". Migration headers that say "roadmap Stage X" mean ORG Stage X.

---

## 1. Scope

**In this module:**
- Org structure: Tenant -> Parent Company -> Business Unit -> Branch -> Division
- Position structure: Department -> Office -> Section -> Group, plus a job catalog (job positions) that belongs to Departments
- Department eligibility per org unit
- Approved headcount allocation (org unit + job + position unit)
- Closing units and reorganizing them

**Not in this module:** employees, hiring, transfers, promotions (they will link to ORG allocations in a later module), leave, attendance, payroll.

---

## 2. Requirements discussed

- Users pick from predetermined structures. Invalid combinations must never be selectable (example: no Architect in an IT Department, no Architect in a Banking Division).
- Levels are configurable and optional. **No placeholder records** (no "N/A Division", "No Office", "General Group"). The next active level links directly to its real parent.
- Cascading data-entry form: select org location -> select Department -> Office, Section and Group are filtered automatically -> select an eligible Position -> enter approved headcount.
- Every organizational and position name supports English and Khmer.
- Database-enforced validation, one reusable architecture, and a frontend that adapts to each company's configuration.

### Rules that must hold
1. A company cannot use another company's hierarchy configuration.
2. Disabling a level must not silently invalidate existing records.
3. Existing employee assignments stay historically consistent.
4. Changing hierarchy rules must not automatically rearrange existing records.
5. The design must support future hiring, transfers, promotions and position allocation.

---

## 3. Decisions made

### Your decisions
| Topic | Decision |
|---|---|
| Config scope | Hierarchy config is per **Parent Company** |
| Catalog | Departments and job positions are a Parent-Company-wide catalog |
| Position tree | A shared catalog, linked to org locations **only through allocations** |
| Reorgs | Needed (rarely) |
| Stage 5 open points | Follow Claude's recommendation (see "ORG Stage 5 decisions") |
| Stage 2b (Khmer level names) | **Skipped for now.** Add later as a small seed migration when names are supplied |

Shared decisions (tenancy, seed data, tooling, migration naming, batching) are in `HRIS_PROJECT_OVERVIEW.md`.

### Design choices adopted
- **Two node tables, one pattern:** `org_unit` (Business Unit, Branch, Division) and `pos_unit` (Department, Office, Section, Group), sharing the same level and rule tables.
- **Validity enforced by composite foreign keys**, not by triggers wherever possible.
- **Rules are versioned.** They are never edited, only closed (`valid_to`) and replaced. The same applies to parent links, eligibility rows and allocations.
- **"Current" means `valid_to is null`.** This is the convention everywhere, including the read layer.
- **Reorgs:** each unit keeps a stable ID, and its parent lives in an effective-dated link table. A reorg closes the old link and opens a new one.
- **Root-level units:** a generated `parent_level_key` (0 = directly under the root) is part of the foreign key to the rule, so a root-level unit cannot cite the wrong rule.
- **Create functions:** `private.create_org_unit`, `private.create_pos_unit` and `private.create_allocation` find the matching open rule or eligibility row themselves. Executable by `service_role` only.
- **Deferred check:** an open unit must end up with an open parent link (checked at commit).
- **Closing cascades:** closing a unit closes its open parent link, allocations and eligibility rows. A unit with open children cannot be closed. A Department with open job positions cannot be closed. Closing a job closes its allocations. A Department listing cannot be closed while allocations use it.
- **Rule guard:** closing one rule is not "disabling the level" while another open rule for the same level remains. When the last open rule of a level is closed, it is refused if the level is required, other rules use it as a parent, or open units still exist at that level (migration `007`).

### ORG Stage 5 decisions (adopted)
1. **Company-level allocation: not supported.** Every allocation sits at an org unit. A company that wants a flat structure enables one org level (for example Business Unit) and creates a single unit. Revisit only if a real company cannot work this way.
2. **Position placement:** an allocation points to a `pos_unit` that is either the job's own Department or any open descendant of it (Office, Section or Group), at any depth. A trigger checks the descendant rule. A unit from another Department's tree is rejected.

### Reorg behaviour (migration 009, adopted)
1. A reorg moves one unit with its whole subtree under a new parent (or to the root where a rule allows it). The unit ID never changes. Old link closes, new link opens.
2. The new parent must be an open unit of the same company, and an open rule must allow the unit's level under the parent's level. This also blocks moving a unit under itself or its own descendants.
3. The effective date is a parameter that defaults to today. It cannot be earlier than the start of the current link or of the new parent. The old link ends and the new one starts on that date.
4. A future effective date takes effect immediately, because the schema treats `valid_to is null` as current. No "no future dates" check was added (the server runs on UTC and would wrongly reject early-morning Phnom Penh dates).
5. Eligibility rows and allocations stay attached to the unit and are not rewritten.
6. Position tree: a unit whose subtree has open allocations cannot move into a different Department's tree. Moving inside the same Department is allowed.
7. Departments cannot be moved (no rule exists for a Department under a parent).
8. Org tree moves have no allocation restriction.
9. Functions are executable by `service_role` only.

### Assumptions I made (not yet confirmed by you)
- Membership only for now: any tenant member sees everything in their tenant. Roles and per-company access come later.
- `name_km` is optional, `name_en` is required.
- Business Unit, Branch and Division may each sit directly under the Parent Company.
- In the position tree, Department is required and is the only level allowed at the top. Office, Section and Group are optional.
- Khmer names for the 7 level names are empty until you supply them.

---

## 4. What has been created

All migrations are applied to the dev project. All tests were run and **passed**. Migrations are one chain shared by all modules. `000` and `001` are shared platform files (see `HRIS_PROJECT_OVERVIEW.md`, section 5.3).

| Migration | Owner | Test | Purpose |
|---|---|---|---|
| `000_create_schemas.sql` | Platform | n/a | `core` and `private` schemas, minimal grants |
| `001_tenancy.sql` | Platform | `001_tenancy_test.sql` | `tenant`, `parent_company`, `tenant_member`, `private.user_tenant_ids()`, RLS, read-only grants |
| `002_hierarchy_levels.sql` | ORG | `002_hierarchy_levels_test.sql` | `hierarchy_level` (7 seeded levels), versioned `company_level_rule`, guard trigger, RLS |
| `003_org_tree.sql` | ORG | `003_org_tree_test.sql` | `org_unit`, `org_unit_parent`, guards, deferred link check, `private.create_org_unit` |
| `004_position_tree.sql` | ORG | `004_position_tree_test.sql` | `pos_unit`, `pos_unit_parent`, same pattern as 003, refined rule guard, `private.create_pos_unit` |
| `005_jobs_and_eligibility.sql` | ORG | `005_jobs_and_eligibility_test.sql` | `job_position`, `org_unit_department`, replaces `org_unit_guard` and `pos_unit_guard` |
| `006_allocation.sql` | ORG | passed (test file name not recorded here) | `position_allocation`, `private.create_allocation`, allocation guard, replaces the four guards so closing cascades to allocations |
| `007_level_disable_guard.sql` | ORG | passed (test file name not recorded here) | ORG Stage 6a: a level cannot be disabled while open units exist at it |
| `008_close_unit.sql` | ORG | passed (test file name not recorded here) | ORG Stage 6b: `private.close_org_unit`, `private.close_pos_unit` |
| `009_reorg.sql` | ORG | `009_010_reorg_read_layer_test.sql` | ORG Stage 6c: `private.reorg_org_unit`, `private.reorg_pos_unit`, `private.pos_department_of` |
| `010_read_layer.sql` | ORG | `009_010_reorg_read_layer_test.sql` | ORG Stage 7: read views and cascade functions in `public` |

### Tables (ORG)
- `core.hierarchy_level`, `core.company_level_rule`
- `core.org_unit`, `core.org_unit_parent`
- `core.pos_unit`, `core.pos_unit_parent`
- `core.job_position` (company, Department, name, valid dates)
- `core.org_unit_department` (which Departments each org unit may use, no inheritance from the parent)
- `core.position_allocation` (org unit, eligibility row, job, position unit, approved headcount, valid dates)

### Current versions of replaced functions
When a later migration needs to change these, start from the **latest** version:
- `private.company_level_rule_guard()` -> latest in `007`
- `private.org_unit_guard()` -> latest in `006`
- `private.pos_unit_guard()` -> latest in `006`
- `private.job_position_guard()` -> latest in `006`
- `private.org_unit_department_guard()` -> latest in `006`
- `private.position_allocation_guard()` -> `006`

### Write functions and read layer
Not repeated here. The write functions (`create_`, `close_`, `reorg_`), the `public` views and functions, the rules and the error messages are in `HRIS_ORG_FRONTEND_REFERENCE.md`.

### How tests work
Tests are plain SQL files. Paste one into the Supabase Dashboard -> SQL Editor (dev project only). Each rolls back at the end. "Success. No rows returned" means pass. An error starting with `FAIL:` means a check failed.

The `009_010` test creates two tenants, two users in `auth.users`, and switches role to `authenticated` and `anon` to check access.

---

## 5. ORG stages

| Stage | Name | Deliverable | State |
|---|---|---|---|
| 0-1 | Schemas, tenancy | Shared platform foundation (`000`, `001`) | Done, passed |
| 2 | Level catalog and company rules | `002` | Done, passed |
| 3 | Org tree | `003` | Done, passed |
| 4 | Position tree, jobs, eligibility | `004`, `005` | Done, passed |
| 5 | Allocation and headcount | `006` | Done, passed |
| 6a | Block disabling a level with active units | `007` | Done, passed |
| 6b | Close-unit functions | `008` | Done, passed |
| 6c | Reorg functions | `009` | Done, passed |
| 7 | Read layer | `010` | Done, passed |
| 2b | Khmer level names | Small seed migration | **Skipped for now** |
| 8 | Frontend | Login, `proxy.ts` session refresh, config screen, cascading allocation form, headcount grid. Manual test per screen, EN/KH check | Next. Read gaps G1 and G2 (see `HRIS_ORG_FRONTEND_REFERENCE.md`, section 9) should be closed first |

Employee hooks (hiring, transfers, promotions linked to `position_allocation`) were earlier listed here as a last stage. They belong to a later Employee module, not to ORG.

---

## 6. Where we are now

1. ORG Stages 0 to 7 are complete, applied and tested (migrations `000` to `010`). The ORG database for configuring the organization is done.
2. Skipped for now: ORG Stage 2b (Khmer level names).
3. Proposed next step (not yet agreed): a small migration `011` adding two read views, `parent_companies` and `hierarchy_levels`, with a short test. After that, ORG Stage 8 can start read-only (login, `proxy.ts`, tree and allocation screens).
4. Pending from you:
   - Confirm or correct the assumptions in section 3.
   - Supply the Khmer names for the 7 levels when ready.
   - Agree the proposed next step.

### Design notes to resolve in later stages
- **ORG Stage 8 starts read-only.** Login, `proxy.ts` and screens that only read can use the `public` views and functions as they are.
- **Writes:** frontend writes will go through `security definer` functions in `public` that wrap the `private` write functions, each with explicit `revoke` and `grant`. These do not exist yet and must be designed together with roles and permissions before any screen can save data.
- **Missing write functions** (enable and disable a level, jobs, eligibility, closing one allocation, renaming a unit) are listed in `HRIS_ORG_FRONTEND_REFERENCE.md`, section 8.
- **Roles and permissions:** not designed yet (currently tenant membership only). A shared topic, see `HRIS_PROJECT_OVERVIEW.md`.

---

## 7. Lessons (ORG only)

- Stage numbering: ORG Stages 3 and 4 map to migrations `003` (org tree) and `004` + `005` (position tree, jobs, eligibility). ORG Stage 5 is migration `006`, ORG Stages 6a/6b/6c are `007`/`008`/`009`, ORG Stage 7 is `010`. Migration numbers and ORG stages are not the same thing.

Project-wide lessons are in `HRIS_PROJECT_OVERVIEW.md`, section 6.

---

## 8. How to resume ORG work

1. Open a new chat in the same Project and attach `HRIS_PROJECT_OVERVIEW.md`, this file and `package.json`.
2. For ORG Stage 8 (frontend), also attach `HRIS_ORG_FRONTEND_REFERENCE.md` and the file lists of `app/` and `lib/supabase/`. Migration files are not needed unless a database change is required.
3. For ORG database work, attach the migration files the change depends on (see the source map in `HRIS_ORG_FRONTEND_REFERENCE.md`). If a guard function is involved, use the latest version (see "Current versions of replaced functions").
4. Say which stage you are on and paste any error text exactly.
5. If a file is missing, say so and Claude will ask whether to generate it.

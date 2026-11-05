# HRIS Project: Status and History

Last updated: 2026-11-05

Use this file to resume work in a new chat. Give Claude this file, `package.json`, and the current list of files in `supabase/migrations/` and `supabase/tests/`. For schema work, also attach the latest migration files (see section 9).

---

## 1. Project overview

| Item | Value |
|---|---|
| Project | HRIS (repo name `hr-system`) |
| Framework | Next.js 16.4.5, React 19, TypeScript, Tailwind 4, App Router |
| Layout | `app/` folder at project root (no `src/`) |
| Hosting | Vercel |
| Backend | Supabase (Postgres, Auth) |
| Editor | VS Code on Windows (use **PowerShell**, not bash) |
| Next.js setting | `cacheComponents` is enabled |

### Working rules (apply to all code help)
- Keep explanations minimal and in plain English, focused on what changed.
- Share a downloadable file only when it is a complete code file.
- Never guess missing logic. If a dependency, config or reference file is missing, ask for it or ask whether to generate it.
- Use best practices and reduce redundant code.
- Break work into small stages. Validate each one before moving on.

---

## 2. Requirements discussed

### Structures
- **Org structure:** Tenant -> Parent Company -> Business Unit -> Branch -> Division
- **Position structure:** Department -> Office -> Section -> Group -> Position

### Core requirements
- Users pick from predetermined structures. Invalid combinations must never be selectable (example: no Architect in an IT Department, no Architect in a Banking Division).
- Levels are configurable and optional. **No placeholder records** (no "N/A Division", "No Office", "General Group"). The next active level links directly to its real parent.
- Cascading data-entry form: select org location -> select Department -> Office, Section and Group are filtered automatically -> select an eligible Position -> enter approved headcount.
- Every organizational and position name supports English and Khmer.
- Integer primary and foreign keys (exception: Supabase `auth.users` uses UUID).
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
| Tenancy | A **Tenant** sits above Parent Company (usually one tenant with one company) |
| Seed data | Kept separate from schema migrations |
| Tooling | Supabase CLI migrations, no Dashboard schema edits |
| Local DB | Docker could not be installed, so a **cloud dev project** is used |
| Migration naming | `NNN_description.sql`, sequential from `000`, no "stage" in the name |
| Stage 5 open points | Follow Claude's recommendation (see "Stage 5 decisions" below) |

### Design choices adopted
- **Schemas:** `core` (business tables), `private` (helper and trigger functions), `public` (thin views and RPCs for the frontend, added later). `core` and `private` are not exposed through the API.
- **Two node tables, one pattern:** `org_unit` (Business Unit, Branch, Division) and `pos_unit` (Department, Office, Section, Group), sharing the same level and rule tables.
- **Validity enforced by composite foreign keys**, not by triggers wherever possible.
- **Rules are versioned.** They are never edited, only closed (`valid_to`) and replaced. The same applies to parent links and eligibility rows.
- **Reorgs:** each unit keeps a stable ID, and its parent lives in an effective-dated link table. A reorg closes the old link and opens a new one.
- **Root-level units:** solved in `003`. A generated `parent_level_key` (0 = directly under the root) is part of the foreign key to the rule, so a root-level unit cannot cite the wrong rule.
- **Create functions:** `private.create_org_unit` and `private.create_pos_unit` find the matching open rule themselves. Executable by `service_role` only.
- **Deferred check:** an open unit must end up with an open parent link (checked at commit).
- **Closing cascades:** closing a unit closes its open parent link (and, for org units and Departments, its open eligibility rows). A unit with open children cannot be closed. A Department with open job positions cannot be closed.
- **Rule guard refinement (004):** closing one rule is not "disabling the level" while another open rule for the same level remains.
- **Read-only frontend access.** Logged-in users can only read. Writes go through controlled functions in later stages.

### Stage 5 decisions (Claude's recommendation, adopted for now)
1. **Company-level allocation: not supported.** Every allocation sits at an org unit. A company that wants a flat structure enables one org level (for example Business Unit) and creates a single unit. This keeps the allocation foreign keys simple and non-null. Revisit only if a real company cannot work this way.
2. **Position placement:** an allocation points to a `pos_unit` that is either the job's own Department or any open descendant of it (Office, Section or Group), at any depth. This matches the cascading form, where the user stops at the deepest level they need. A trigger checks the descendant rule because a foreign key cannot check tree membership. A unit from another Department's tree is rejected.

### Assumptions I made (not yet confirmed by you)
- Membership only for now: any tenant member sees everything in their tenant. Roles and per-company access come later.
- `name_km` is optional, `name_en` is required.
- Business Unit, Branch and Division may each sit directly under the Parent Company.
- In the position tree, Department is required and is the only level allowed at the top. Office, Section and Group are optional.
- Khmer names for the 7 level names are empty until you supply them.

---

## 4. What has been created

All migrations are applied to the dev project. All tests below were run and **passed**.

| Migration | Test | Purpose |
|---|---|---|
| `000_create_schemas.sql` | n/a | `core` and `private` schemas, minimal grants |
| `001_tenancy.sql` | `001_tenancy_test.sql` | `tenant`, `parent_company`, `tenant_member`, `private.user_tenant_ids()`, RLS, read-only grants |
| `002_hierarchy_levels.sql` | `002_hierarchy_levels_test.sql` | `hierarchy_level` (7 seeded levels), versioned `company_level_rule`, guard trigger, RLS |
| `003_org_tree.sql` | `003_org_tree_test.sql` | `org_unit`, `org_unit_parent`, guards, deferred link check, `private.create_org_unit` |
| `004_position_tree.sql` | `004_position_tree_test.sql` | `pos_unit`, `pos_unit_parent`, same pattern as 003, refined rule guard, `private.create_pos_unit` |
| `005_jobs_and_eligibility.sql` | `005_jobs_and_eligibility_test.sql` | `job_position`, `org_unit_department`, replaces `org_unit_guard` and `pos_unit_guard` |

Other files in place: `lib/supabase/env.ts`, `lib/supabase/client.ts`, `lib/supabase/server.ts`.

### Tables created so far
- `core.tenant`, `core.parent_company`, `core.tenant_member`
- `core.hierarchy_level`, `core.company_level_rule`
- `core.org_unit`, `core.org_unit_parent`
- `core.pos_unit`, `core.pos_unit_parent`
- `core.job_position` (company, Department, name, valid dates)
- `core.org_unit_department` (which Departments each org unit may use, no inheritance from the parent)

### Current versions of replaced functions
When a later migration needs to change these, start from the **latest** version:
- `private.company_level_rule_guard()` -> latest in `004`
- `private.org_unit_guard()` -> latest in `005`
- `private.pos_unit_guard()` -> latest in `005`
- `private.job_position_guard()` -> `005`

### Foreign key targets ready for Stage 5
- `core.org_unit_department (id, company_id, org_unit_id, department_id)`
- `core.job_position (id, company_id, department_id)`
- `core.org_unit (id, company_id)` and `core.pos_unit (id, company_id)`
- `core.pos_unit (id, company_id, level_id)`

### How tests work
Tests are plain SQL files. Paste one into the Supabase Dashboard -> SQL Editor (dev project only). Each rolls back at the end. "Success. No rows returned" means pass. An error starting with `FAIL:` means a check failed.

---

## 5. Environment notes

- **Dev project:** cloud Supabase project named "HRIS 2.0", already linked with `npx supabase link`.
- **This CLI version targets local Docker by default.** Always add `--remote`:
  ```powershell
  npx supabase db push --remote
  ```
- **Docker:** not installed. Local `db reset` and `supabase start` are not available until it is.
- **`.env.local`** (project root, never committed) needs:
  ```
  NEXT_PUBLIC_SUPABASE_URL=https://<project-ref>.supabase.co
  NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=<publishable key>
  ```
  Never put the `secret` or `service_role` key in any `NEXT_PUBLIC_` variable.
- **`cacheComponents` is on:** do not use `export const dynamic`. Any component that reads cookies or fetches request-time data must sit inside `<Suspense>`.
- Use only the dev project for testing. Never put real employee data in it.

---

## 6. Corrections and lessons so far

- My early plan used `supabase db push` without `--remote`. This CLI version needs the flag.
- The `alter default privileges ... revoke execute on functions` lines in `000` do not actually remove default function access. It is harmless: every function has its own explicit `revoke` and `grant`. Do this for every future function.
- The first test page used `export const dynamic`, which is not allowed with `cacheComponents`. It was rewritten with `<Suspense>`.
- A file saved to the wrong folder broke relative imports and overwrote the home page. Check destination paths carefully.
- Stage numbering: roadmap Stages 3 and 4 map to migrations `003` (org tree) and `004` + `005` (position tree, jobs, eligibility). The allocation table (roadmap Stage 5) is **not built yet**. Earlier notes that said Stage 5 was done were counting migration numbers.

---

## 7. Where we are now

1. Roadmap Stages 0 to 4 are complete, applied and tested (migrations `000` to `005`).
2. Next: roadmap Stage 5, `006_allocation.sql` plus its test, using the Stage 5 decisions above.
3. Pending from you:
   - Delete the `app/test-supabase/` folder if not already done.
   - Confirm or correct the assumptions in section 3.
   - Supply the Khmer names for the 7 levels.

---

## 8. Roadmap

| # | Stage | Planned deliverable | Validation |
|---|---|---|---|
| 0-1 | Schemas, tenancy | Done | Passed |
| 2 | Level catalog and company rules | Done (`002`) | Passed |
| 3 | Org tree | Done (`003`) | Passed |
| 4 | Position tree, jobs, eligibility | Done (`004`, `005`) | Passed |
| 2b | Khmer level names | Small seed migration | Names appear in catalog |
| 5 | Allocation and headcount | `position_allocation`: org unit, eligibility row, job position, pos unit (job's Department or a descendant), approved headcount (0 or more), effective dates. Guard that closes allocations when their org unit, Department, job or pos unit closes | "Architect in IT" and "Architect in Banking Division" rejected. Pos unit from another Department's tree rejected. Duplicate open allocation rejected |
| 6 | Lifecycle rules | 6a: block disabling a level that still has active units. 6b: close-unit function. 6c: reorg function | Rule changes leave existing rows untouched. Reorg keeps history readable |
| 7 | Read layer | Views or RPCs in `public` that return only valid options per cascade step (`security_invoker`) | Invalid options never appear |
| 8 | Frontend | Config screen, cascading allocation form, headcount grid, login, `proxy.ts` session refresh | Manual test per screen, EN/KH check |
| 9 | Employee hooks | Hiring, transfers, promotions linked to `position_allocation` | Planned later |

### Design notes to resolve in later stages
- **Stage 6:** disabling a level must also check for active units at that level (the rule guard only checks child rules).
- **Writes:** frontend writes will go through `security definer` functions, each with explicit `revoke` and `grant`.
- **Roles and permissions:** not designed yet (currently tenant membership only).
- **Types:** `supabase gen types` only covers exposed schemas, so frontend types will come from `public` views and RPCs.
- **Vercel:** add the two `NEXT_PUBLIC_` environment variables in the Vercel project when deploying, and create a separate production Supabase project.

---

## 9. How to resume

1. Open a new chat in the same Project and attach this file and `package.json`.
2. Attach the migration files the next stage depends on (for Stage 5: `003` to `005`; the replaced guards live in `004` and `005`).
3. Say which stage you are on and paste any error text exactly.
4. If a file is missing, say so and Claude will ask whether to generate it.

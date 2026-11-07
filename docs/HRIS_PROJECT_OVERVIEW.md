# HRIS Project Overview

Last updated: 2026-11-07
Purpose: Entry point for the whole HRIS project: the document set, the technical setup and conventions every module shares, and how to resume work in a new chat.
Read together with: `HRIS_MODULE_REGISTER.md` (the module list), `HRIS_CONTEXT.md` (Cambodia and company assumptions), `HRIS_BUILD_STANDARDS.md` (how modules are built), `HRIS_NAMING_CONVENTION.md`, `HRIS_MODULE_TEMPLATES.md`, and the module documents listed in the register

This document holds only what is **shared by all modules**. Anything specific to one module lives in that module's documents.

---

## 1. What HRIS is

An all-in-one HRIS platform covering human resources, employee profile, leave management, attendance and payroll (from the Project description). It is built **one module at a time**, in small stages (vertical slices), each validated before the next one starts. How is set out in `HRIS_BUILD_STANDARDS.md`.

### 1.1 Cambodia context: assumptions to verify

Moved to `HRIS_CONTEXT.md`. It holds the assumptions (public holidays, statutory leave, working hours, contracts, NSSF, tax, currency, Khmer language and calendar, retention, personal data), each with an ID (`CTX-01` to `CTX-14`), the module that owns it, and its verification status.

- **Nothing in it is verified** until its row says so. The owning module checks its rows **before its Phase P1 closes**. No rule is built from the list alone.
- Specific rates, limits and periods are not written there. They go in the module Blueprint once verified, with the source and the `CTX-nn` reference.

### 1.2 Project documents

| Document | Holds | Changes |
|---|---|---|
| `HRIS_PROJECT_OVERVIEW.md` | This file: shared technical setup, platform design, lessons, open items, how to resume | When something shared by all modules changes |
| `HRIS_MODULE_REGISTER.md` | Module list: build order, code, scope, dependencies, state, documents | When a module starts, changes scope or changes state |
| `HRIS_CONTEXT.md` | Cambodia and company assumptions, with verification results | When a module verifies an item |
| `HRIS_BUILD_STANDARDS.md` | Phases, Stages, definition of done, scenario checklist, working rules for Claude | Rarely |
| `HRIS_NAMING_CONVENTION.md` | Names of files, tables, functions, codes | Rarely |
| `HRIS_MODULE_TEMPLATES.md` | Skeletons for the module documents | Rarely |
| `HRIS_<MODULE>_BLUEPRINT.md` | The module's **foundation**: requirements, assumptions, design, database design, decisions | Written before building. Afterwards only through its decision table |
| `HRIS_<MODULE>_STATUS.md` | The module's **plan and progress**: Stage plan, tasks, stage log, files, tests, limitations | At the end of every Stage |
| `HRIS_<MODULE>_FRONTEND_REFERENCE.md` | What a frontend needs to know about the module's database | Created when the database is ready for a frontend, then kept current |

---

## 2. Module register

The module register is kept in **`HRIS_MODULE_REGISTER.md`**: build order, code, scope, dependencies, state and documents of every module. It is the only place that lists modules, so this document does not repeat it and the two cannot disagree. Where an older document says "Overview, section 2", it means the register.

- **Starting a module:** add or update its row in the register, write `HRIS_<CODE>_BLUEPRINT.md` and `HRIS_<CODE>_STATUS.md` from `HRIS_MODULE_TEMPLATES.md`, and answer the scenario checklist (`HRIS_BUILD_STANDARDS.md`, section 5) in the Blueprint before Stage 1. Create `HRIS_<CODE>_FRONTEND_REFERENCE.md` once the database is ready for a frontend. See `HRIS_NAMING_CONVENTION.md`.
- **During the build:** the Blueprint stays stable, the Status changes every Stage. After a Stage passes, update the module's Status first, then its register row if the state changed.
- **Module context:** the register row names the `CTX-nn` items a module must verify (see `HRIS_CONTEXT.md`).

---

## 3. Technical setup

| Item | Value |
|---|---|
| Project | HRIS (repo name `hr-system`) |
| Framework | Next.js 16.4.5, React 19, TypeScript, Tailwind 4, App Router |
| Layout | `app/` folder at project root (no `src/`) |
| Hosting | Vercel |
| Backend | Supabase (Postgres, Auth) |
| File storage | Cloudflare R2 (planned, not set up yet). Private bucket, signed links, only metadata in the database |
| Editor | VS Code on Windows (use **PowerShell**, not bash) |
| Next.js setting | `cacheComponents` is enabled |
| Files in place | `lib/supabase/env.ts`, `lib/supabase/client.ts`, `lib/supabase/server.ts` |

### Environment notes
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
- **Vercel:** add the two `NEXT_PUBLIC_` environment variables in the Vercel project when deploying, and create a separate production Supabase project.
- Use only the dev project for testing. Never put real employee data in it.

---

## 4. Working rules

Moved to `HRIS_BUILD_STANDARDS.md`, section 9 (working rules for Claude). The build method (phases, vertical Stages, definition of done) is in the same document.

---

## 5. Shared platform

### 5.1 Platform decisions (your decisions)
| Topic | Decision |
|---|---|
| Tenancy | A **Tenant** sits above Parent Company (usually one tenant with one company) |
| Seed data | Kept separate from schema migrations |
| Tooling | Supabase CLI migrations, no Dashboard schema edits |
| Local DB | Docker could not be installed, so a **cloud dev project** is used |
| Roles | Three starting roles: `tenant_admin`, `hr_admin`, `viewer`. Permissions stored as codes. Reads stay open to every tenant member for now. Existing members became `tenant_admin`. No role history |
| Role scope | A role is given per tenant member for one scope: all companies of the tenant, one company, one org unit (subtree included) or one Department. The narrower scope replaces the broader one |
| Migration naming | `NNN_description.sql`, sequential from `000`, no "stage" in the name. One numbering chain shared by all modules |
| Batching | Simple stages can be built together and tested once |

### 5.2 Platform design choices (adopted)
- **Schemas:** `core` (business tables), `private` (guard, helper and write functions), `public` (thin views and read functions for the frontend). `core` and `private` are not exposed through the API.
- **Integer keys:** integer primary and foreign keys everywhere (exception: Supabase `auth.users` uses UUID).
- **Bilingual names:** every name has `name_en` (required) and `name_km` (optional).
- **Tenancy tables:** `core.tenant`, `core.parent_company` (the "company"), `core.tenant_member` (which logged-in users belong to which tenant). Created in migration `001`.
- **Row visibility pattern:** a user sees only rows of companies whose tenant they belong to. Company-scoped tables use a policy of the form `company_id in (select id from core.parent_company)`, and `parent_company` itself is filtered through `private.user_tenant_ids()`. Reuse this pattern for every new company-scoped table.
- **Frontend access:** logged-in users read through `public` views and functions. They write only through `public` write wrappers (ORG has 18, migrations `014` to `020` and `022`). Each wrapper is `security definer`, granted to `authenticated` and `service_role` (not `anon`), and checks the caller's permission with `private.has_permission` (section 5.7). The `private` write functions behind them stay `service_role` only. Not built yet: functions to create a tenant, company or membership, and to give or remove roles.
- **Read layer:** views use `security_invoker`, so the caller's row level security applies.
- **Privileges:** every function has an explicit `revoke` and `grant`. For anything in `public`, revoke from `public`, `anon` and `authenticated` first, then grant to `authenticated` and `service_role`.
- **Dated rows:** the first module (ORG) keeps history with `valid_from` and `valid_to` (empty `valid_to` = current) and never edits a row, it closes it and creates a new one. Whether a later module needs the same is decided per module.

### 5.3 Platform migrations
| Migration | Test | Purpose |
|---|---|---|
| `000_create_schemas.sql` | n/a | `core` and `private` schemas, minimal grants |
| `001_tenancy.sql` | `001_tenancy_test.sql` | `tenant`, `parent_company`, `tenant_member`, `private.user_tenant_ids()`, RLS, read-only grants |
| `012_roles.sql` | `012_roles_test.sql` | Role tables, seeded roles and permission codes, scope guard, RLS (built in ORG Stage 9b-1) |
| `013_has_permission.sql` | `013_has_permission_test.sql` | `private.has_permission`, `private.has_tenant_permission` (built in ORG Stage 9b-2) |
| `025_last_tenant_admin_guard.sql` | `025_last_tenant_admin_guard_test.sql` | Trigger that refuses deleting or downgrading the last tenant-wide `tenant_admin` (written, not yet tested) |

The ORG status document lists every other migration (`002` to `011`, `014` to `024`, `026`) and also `012` and `013` (platform-wide, but built during ORG Stage 9).

### 5.4 Frontend access model (all modules)
| Question | Answer |
|---|---|
| Who calls the database | The browser or server, using the publishable key and the logged-in user's session (role `authenticated`) |
| What can they do today | Read through objects in `public`. Write only through the `public` write wrappers, which check the caller's permission |
| What can they not do | Insert, update or delete directly in tables. Read `core` or `private`. Anonymous visitors read nothing |
| Which rows are visible | Only rows of companies whose tenant the user belongs to. A user with no membership sees nothing |
| Roles | **Enforced on writes** (every wrapper checks a permission, section 5.7). **Not enforced on reads**: every member of a tenant sees everything in that tenant, history included. The frontend asks `public.check_permissions` which buttons to show. A member added later has no role until one is given |
| Empty result | Usually means "nothing here" or "not a member". The read layer does not raise an error for unknown ids or other tenants' ids |
| Secret keys | Never use the `service_role` or `secret` key in the browser or in any `NEXT_PUBLIC_` variable. The `private` write functions need `service_role`, so the frontend calls the `public` wrappers instead |

### 5.5 Dates and time zone (all modules)
- Anything that defaults to "today" uses the **server's date, which is UTC**. In Phnom Penh (UTC+7) the server date is still yesterday between 00:00 and 07:00 local time.
- When the user picks a date, **pass it explicitly** from the frontend instead of relying on the default.

### 5.6 Frontend implementation notes (all modules)
- **Generated types:** `supabase gen types` only covers exposed schemas, so types come from the `public` views and functions. Generated view columns are usually typed as nullable. Expect to narrow them.
- **`cacheComponents` is on:** components that read cookies or fetch per-user data must sit inside `<Suspense>`.
- Language rule for names: show `name_km` when the interface is Khmer and it is not empty, otherwise `name_en`.

### 5.7 Roles and permissions (all modules)

Built in migrations `012` and `013`. The ORG permission codes are listed in `HRIS_ORG_STATUS.md`, section 4.

| Item | Rule | Origin |
|---|---|---|
| Tables | `core.app_role` (roles), `core.permission` (codes), `core.app_role_permission` (which role holds which permission), `core.member_role_scope` (a role given to a tenant member for one scope) | Adopted |
| Starting roles | `tenant_admin` (every permission, including `members.manage`), `hr_admin` (every ORG permission, not `members.manage`), `viewer` (`org.read` only) | Your decisions |
| Scope | One of: all companies of the tenant, one company, one org unit (subtree included), one Department. Each assignment points at one place. One assignment per member per scope | Your decisions |
| Scope rules | An org unit or Department scope must be open when created, and a Department scope must be a Department. The role can change later, the scope cannot. A unit closed later keeps its assignment, which then grants nothing | Adopted |
| Permission codes | Lowercase `<area>.<thing>.<action>`, for example `org.unit.write`. Two flags say whether a code can be checked at org unit scope and at Department scope. Codes with neither flag are checked at company or tenant level only | Adopted |
| Check functions | `private.has_permission(company, code, org unit, Department)` and `private.has_tenant_permission(tenant, code)`. Both use the caller's login (`auth.uid()`) and only the caller's own assignments | Adopted |
| Resolution | A narrow assignment (org unit or Department) replaces the broader company and tenant-wide roles. If several narrow assignments apply, all must hold the permission (restriction wins). With none, the company role decides, then the tenant-wide role. A closed, missing or other-company target is never valid | Your decisions (narrower replaces broader), Adopted (details) |
| Adding a module's permissions | The module's first migration adds its codes and grants them to roles. Which roles get them is decided per module | Adopted |
| Reads | Not governed by roles yet. `org.read` exists but nothing checks it | Your decisions |
| Visibility of assignments | A user sees only their own. Who may see all of a tenant's assignments is decided with the members screen | Adopted |
| `members.manage` | Tenant-wide only. A company-scoped `tenant_admin` cannot manage members | Assumption |
| Last tenant administrator | A tenant must keep at least one tenant-wide `tenant_admin`. A trigger (`025`) refuses deleting or downgrading the last one, also through removing the member or the auth user. Applies to everyone, including `service_role`. A user may remove their own admin role while another admin exists. A whole tenant can be deleted only after `select set_config('hris.tenant_teardown', 'on', true);` in the same transaction | Your decisions (written, not yet tested) |
| State | Checked by every ORG write wrapper (`private.has_permission`) and by the frontend through `public.check_permissions`. No function or screen gives or removes roles yet | |

---

## 6. Lessons (project-wide)

- My early plan used `supabase db push` without `--remote`. This CLI version needs the flag.
- The `alter default privileges ... revoke execute on functions` lines in `000` do not actually remove default function access. It is harmless: every function has its own explicit `revoke` and `grant`. Do this for every future function.
- Supabase grants new objects in `public` to `anon` and `authenticated` by default, and a plain `revoke ... from public` does not remove that. Revoke from `public, anon, authenticated` first, then grant. Do the same for every future `public` view or function.
- The first test page used `export const dynamic`, which is not allowed with `cacheComponents`. It was rewritten with `<Suspense>`.
- A file saved to the wrong folder broke relative imports and overwrote the home page. Check destination paths carefully.
- Tests that end in `rollback` never fire deferred constraint triggers. Force the check with `set constraints all immediate` and then `set constraints all deferred` in tests that depend on a deferred check.

---

## 7. Open items for you (project-wide)

- Delete the `app/test-supabase/` folder if not already done.
- Run the tests for `025` and `026` (see `HRIS_ORG_STATUS.md`, section 6, Next plan).
- Confirm the proposed module codes `FND`, `PLT`, `REC`, `PRF`, `TRN` and `RPT` (`HRIS_MODULE_REGISTER.md`). `PLT` also answers the pending question "choose the module code for Members, roles and setup" in `HRIS_ORG_STATUS.md`.
- Decide the read rule ("any tenant member sees everything", `HRIS_ORG_STATUS.md`, section 3, assumptions) before the `EMP` module stores personal details or salary.
- A way to create tenants, companies, members and role assignments does not exist yet (done by hand with `service_role`). Its planning document is the next `PLT` step.
- No production Supabase project, no Vercel deployment and no Cloudflare R2 bucket yet. Set them up, with a migration deploy process, before many more migrations pile up.
- Review the Proposed items in `HRIS_BUILD_STANDARDS.md` and confirm or change them.
- Verify the Cambodia assumptions (`HRIS_CONTEXT.md`) before the owning module's Phase P1 closes.

Module-specific open items are in each module's status document.

---

## 8. How to resume

1. Open a new chat in the same Project. Name the Stage as `<MODULE> Stage N` (for example "ORG Stage 9k") or "migration NNN". Paste any error text exactly.
2. Attach files by task:

| Task | Attach |
|---|---|
| Any new chat | This file and the module's Status. `package.json` for code work |
| Planned tasks, progress, what is next | The module's Status (already in the row above) |
| Requirements, design, assumptions, open questions | + the module's Blueprint (for ORG, its Status holds scope and decisions) |
| Which module comes next, dependencies, module state | + `HRIS_MODULE_REGISTER.md` |
| Cambodia rules, company policy, anything to verify | + `HRIS_CONTEXT.md` |
| Database work | + Blueprint section 4, and only the migrations named in the module's source map for that topic. If a guard function is involved, use its latest version |
| Frontend work | + the module's frontend reference, the file lists of `app/` and `lib/supabase/`, and the **latest** version of each file to change |
| Work that touches another module | That module's frontend reference only |
| Starting a new module | `HRIS_BUILD_STANDARDS.md`, `HRIS_MODULE_TEMPLATES.md`, `HRIS_MODULE_REGISTER.md` and `HRIS_CONTEXT.md` |

3. If a file is missing, say so and Claude will ask whether to generate it.
4. Claude's session rules are in `HRIS_BUILD_STANDARDS.md`, section 9.

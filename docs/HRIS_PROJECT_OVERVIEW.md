# HRIS Project Overview

Last updated: 2026-11-06
Purpose: Entry point for the whole HRIS project: the module list, the technical setup and conventions every module shares, and how to resume work in a new chat.
Read together with: `HRIS_NAMING_CONVENTION.md`, and the module documents listed in section 2

This document holds only what is **shared by all modules**. Anything specific to one module lives in that module's documents.

---

## 1. What HRIS is

An all-in-one HRIS platform covering human resources, employee profile, leave management, attendance and payroll (from the Project description). It is built **one module at a time**, in small stages, each validated before the next one starts.

---

## 2. Module register

| Module | Code | Scope | State | Documents |
|---|---|---|---|---|
| Organization structure | `ORG` | Org tree, position tree, job catalog, Department eligibility, approved headcount allocation | Database complete (ORG Stages 0 to 7). Read-only frontend complete (Stages 8a to 8d). Roles stored and permission check built (Stages 9a to 9b). Write wrappers are next (Stage 9c) | `HRIS_ORG_STATUS.md`, `HRIS_ORG_FRONTEND_REFERENCE.md` |
| Employee profile | not assigned | Not started. Scope not discussed yet. Hiring, transfers and promotions linked to ORG allocations were noted earlier as "employee hooks" and belong here, not in ORG | Not started | none |
| Leave management | not assigned | Not started. Scope not discussed yet | Not started | none |
| Attendance | not assigned | Not started. Scope not discussed yet | Not started | none |
| Payroll | not assigned | Not started. Scope not discussed yet | Not started | none |

Starting a module: choose a short uppercase code, add it to this table, then create `HRIS_<CODE>_STATUS.md` (and `HRIS_<CODE>_FRONTEND_REFERENCE.md` once it has a frontend). See `HRIS_NAMING_CONVENTION.md`.

---

## 3. Technical setup

| Item | Value |
|---|---|
| Project | HRIS (repo name `hr-system`) |
| Framework | Next.js 16.4.5, React 19, TypeScript, Tailwind 4, App Router |
| Layout | `app/` folder at project root (no `src/`) |
| Hosting | Vercel |
| Backend | Supabase (Postgres, Auth) |
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

## 4. Working rules (apply to all code help)

- Keep explanations minimal and in plain English, focused on what changed.
- Share a downloadable file only when it is a complete code file.
- Never guess missing logic. If a dependency, config or reference file is missing, ask for it or ask whether to generate it.
- Use best practices and reduce redundant code.
- Break work into small stages. Validate each one before moving on. Simple stages may be combined into one SQL file and one test run.

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
- **Read-only frontend:** logged-in users can only read. Writes go through controlled functions (in `private`, `service_role` only today). Frontend-callable write functions are not built yet. They will check roles (section 5.7).
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

Migrations `002` to `011` are listed in the ORG status document, which also lists `012` and `013` (platform-wide, but built during ORG Stage 9).

### 5.4 Frontend access model (all modules)
| Question | Answer |
|---|---|
| Who calls the database | The browser or server, using the publishable key and the logged-in user's session (role `authenticated`) |
| What can they do today | Read only, through objects in `public` |
| What can they not do | Insert, update or delete anything. Read `core` or `private`. Anonymous visitors read nothing |
| Which rows are visible | Only rows of companies whose tenant the user belongs to. A user with no membership sees nothing |
| Roles | Stored and tested (section 5.7) but **not enforced yet**. Every member of a tenant still sees everything in that tenant, and no frontend write exists. A member added later has no role until one is given |
| Empty result | Usually means "nothing here" or "not a member". The read layer does not raise an error for unknown ids or other tenants' ids |
| Secret keys | Never use the `service_role` or `secret` key in the browser or in any `NEXT_PUBLIC_` variable. All write functions need `service_role` |

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
| State | Stored and tested. No function or screen uses the check yet | |

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
- A way to create tenants, companies, members and role assignments does not exist yet (done by hand with `service_role`). Protecting the last `tenant_admin` from removal is also open.

Module-specific open items are in each module's status document.

---

## 8. How to resume

1. Open a new chat in the same Project and attach this file, the status document of the module you are working on (for example `HRIS_ORG_STATUS.md`), and `package.json`.
2. For frontend work, also attach that module's frontend reference and the file lists of `app/` and `lib/supabase/`.
3. For database work, also attach only the migrations named in the module's source map for that topic. If a guard function is involved, use its latest version.
4. Name the stage as `<MODULE> Stage N` (for example "ORG Stage 8") or "migration NNN". Paste any error text exactly.
5. If a file is missing, say so and Claude will ask whether to generate it.

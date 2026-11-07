# HRIS PLT Status

Last updated: 2026-11-07
Purpose: The plan and progress of the Platform services (PLT) module, part A (access and setup): Stages and tasks planned, what has passed, files created, tests, issues, next steps and known limitations. What the module is, and why, is in the Blueprint.
Read together with: `HRIS_PROJECT_OVERVIEW.md`, `HRIS_PLT_BLUEPRINT.md`, `HRIS_FRONTEND_FOUNDATION.md`, `HRIS_ORG_STATUS.md` (shared migrations and the ORG permission codes)

Module code: `PLT`. Stages are written "PLT Stage N". Parts B to E (master data and audit log, file storage, scheduling, approvals) are designed later and get their own Stages when designed (Blueprint 1.7).

*Update rule: this file is updated **during** the session whenever an assumption, finding, decision or task changes (Issues log, Pending, task list, Stage state), not only at the end of a Stage. At the end of each Stage, sections 1 to 6 and 8 are brought fully up to date, and the module row in `HRIS_MODULE_REGISTER.md` if the state changed. A new assumption goes into Blueprint section 2 and is listed in section 9 here until settled.*

---

## 1. Where we are

| Item | Value |
|---|---|
| Phase now | P1 to P3 draft for part A (Stage 0) |
| Blueprint state | Draft. Decisions `PLT-D01` to `PLT-D18` recorded on 2026-11-07. One open question (`PLT-Q18`, not blocking). Not yet approved by you (`PLT-T009`) |
| Current Stage | Stage 0 (setup), in progress. The checks (`PLT-T003` to `PLT-T005`) are done |
| Last Stage passed | None. Existing platform pieces built during ORG: `001`, `012`, `013`, `021`, `025` (tested 2026-11-07), `029` (section 5.1) |
| Next | Close Stage 0 (align the other documents, approve the Blueprint), then Stage 1 (tenant setup function) |
| Blocking | Nothing blocks Stage 1. `FND-Q09` blocks Stage 2 |

* No PLT migration, test or screen exists yet. Everything PLT uses today was built inside ORG (section 5).
* The **Frontend Foundation Stage** (`HRIS_FRONTEND_FOUNDATION.md`, steps F0 to F6) runs after PLT Stage 1 and before PLT Stage 2. Its decisions `FND-D01` to `FND-D08` were answered on 2026-11-07 (work scope selector, route groups, shared folders, sidebar).

---

## 2. Stage plan

*Blueprint references use the IDs of `HRIS_PLT_BLUEPRINT.md` (`W` workflow, `D` decision, `Q` question, `SC` scenario, `UAT`). "Migrations planned" use the next free number in the shared chain when written (ORG ends at `029`, nothing else is reserved), file name `NNN_description.sql` and test `NNN_description_test.sql` (`HRIS_NAMING_CONVENTION.md` section 3), header line `-- NNN: short title (PLT Stage X)`. Stages may be reordered or split here without a decision as long as the Blueprint scope does not change.*

| Stage | Capability (a user can...) | Blueprint items covered | Migrations planned | Frontend planned | Depends on | State |
|---|---|---|---|---|---|---|
| 0 | Setup: decisions recorded, names and date defaults checked, documents aligned, Blueprint approved | `D01` to `D18`, `Q13`, `Q17`, `Q18`, section 4.10 | none | none | none | **In progress** |
| 1 | An operator creates a tenant, company and first admin without hand SQL | `W1`, `D02`, `UAT01`, `UAT02`, `SC-13`, objective 1, 4.4 (`private.create_tenant_setup`), 4.10 | `NNN_tenant_setup.sql` and its test | none. The first admin's login is created by the server-only step in its simplest form (`PLT-T012`) | Stage 0 | Planned |
| FND | Frontend Foundation (not a PLT Stage): shell, work scope selector, shared folders, import rules. Steps F0 to F6 | `HRIS_FRONTEND_FOUNDATION.md`, `FND-D01` to `FND-D08` | none | Shell, move of ORG shared pieces | Stage 1 | Planned |
| 2 | Any member sees their own access. Administrators see the members their scope covers. The scope selector switches to the user's assigned access | `W5`, `D03`, `D07`, `D16`, `UAT03` to `UAT07`, `SC-17`, `SC-21`, 3.1 (My access, Members list) | `NNN_members_read.sql`: code `members.read` (`hr_admin`, `tenant_admin`), `public.get_my_access`, `public.get_tenant_members`, `public.get_my_scope`, test | My access, Members list (read only), scope selector filter | Stage 1, FND, `FND-Q09` | Planned |
| 2b | Every change to a login, a membership or a role is logged. Tenant administrators read the log | `D08`, `UAT08`, `UAT09`, `SC-01`, `SC-12`, `SC-21`, 4.2 (`core.access_log`), 4.9 | `NNN_access_log.sql`: log table, trigger, `public.get_access_log`, test | Access log screen | Stage 2 | Planned |
| 3 | An administrator gives, changes and removes a role. A company administrator stays inside their company | `W3`, `D05`, `D06`, `UAT10` to `UAT16`, `UAT22`, `SC-05`, `SC-06`, `SC-07`, `SC-10`, `SC-11` | `NNN_member_role_wrappers.sql`: `public.assign_member_role`, `change_member_role`, `remove_member_role`, test. No new guard (`Q13` checked) | Member detail, Give role dialog | Stage 2b | Planned |
| 4 | An administrator creates a login and resets its temporary password. The new member sets their own password. An authorized administrator removes a member | `W2`, `W4` (manual part), `D09`, `D11`, `D15`, `UAT17` to `UAT21`, `UAT24`, `SC-07`, `SC-09`, `SC-11`, `SC-16` | `NNN_member_wrappers.sql`: `public.remove_tenant_member` and the database side of login creation, test | Create login dialog, Set new password screen, remove dialog. Server-only steps: create login, reset password | Stage 3 | Planned |
| 5 | The read rule is written into the platform rules: every module defines and enforces its own read code from its first Stage | `D10` | none | none (documents only: Overview 5.4 and 5.7, Blueprint template) | Stage 4 | Planned |
| Later | Automatic removal the day after the last working day | `D14`, `UAT23`, `SC-03`, `SC-04`, `SC-18` | scheduled function and test (part D) | a note on the member detail | `EMP` or `LCY`, part D | Not designed |
| B to E | Master data and full audit log, file storage, scheduling, approvals | Blueprint 1.7 | | | | Not designed |

---

## 3. Task list

*Tasks of the current Stage (0) and the next one (1) only. When a Stage passes, summarise its tasks in the stage log (section 4) and remove them here. New tasks are added as findings appear.*

| Task | Stage | Task | Type | Blueprint ref | Who | State | Done on | Note |
|---|---|---|---|---|---|---|---|---|
| `PLT-T001` | 0 | Record your answers as `PLT-D01` to `PLT-D13` and update the Blueprint | Document | Section 6 | Claude | Done | 2026-11-07 | Stage 2b added |
| `PLT-T002` | 0 | Answer `Q14`, `Q15`, `Q16` | Decision | `Q14` to `Q16` | You | Done | 2026-11-07 | Recorded as `PLT-D14` (automatic removal), `PLT-D15` (company admin removes any member with a role in their company, membership included), `PLT-D16` |
| `PLT-T003` | 0 | Check names in the Blueprint against `HRIS_NAMING_CONVENTION.md` | Check | 4.2, 4.4 | Claude | Done | 2026-11-07 | Fixed in the Blueprint: audit column is `created_at` (not `occurred_at`), origin labels follow the convention (Your decision, Adopted, Assumption, Existing), docs live in `docs/`, migration and test file names. Still to add to the convention: `get_<things>` read functions and the PLT table prefix note (`PLT-T017`). The convention's frontend section 5 is undefined (`PLT-T017`) |
| `PLT-T004` | 0 | Check `001`, `012`, `013`, `021` for date defaults (`DT-3`, `DT-5`, `DT-11`) | Check | 4.10 | Claude | Done | 2026-11-07 | No `current_date`, no date cast. Only `created_at timestamptz default now()` (instants, allowed by `DT-6`). Nothing to fix. The VS Code search of `DT-11` still runs on every new migration |
| `PLT-T005` | 0 | Answer `Q13` from `012` and `013` | Check | `Q13`, `D05` | Claude | Done | 2026-11-07 | (a) cross-tenant targets are refused by the composite foreign keys in `012`. (b) `has_permission(company, 'members.manage')` already resolves company scope. (c) the wrapper limits a company administrator, no new guard. New finding: org unit and Department scope never grant `members.manage` (`PLT-Q17`) |
| `PLT-T006` | 0 | Confirm `Q09` (manager and employee scopes) | Decision | `Q09` | You | Done | 2026-11-07 | `PLT-D17` |
| `PLT-T007` | 0 | Align the other documents with the decisions: Overview 5.7 (`members.manage` at tenant or company scope, `D05`), 5.4 (reads rule, `D10`), 5.3 and section 7 (`025` is tested, `026` is done), 5.5 (date rule now `private.org_today()`, `DT-1` to `DT-11`), `HRIS_ORG_STATUS.md` section 3 (assumption wording), and the `013` header comment (applied migrations are not edited, noted in the ORG Frontend Reference instead) | Document | 1.3 | Claude | Done | 2026-11-07 | Overview 5.1 to 5.7, 6, 7 and `HRIS_ORG_STATUS.md` (Next plan, Pending, section 11) updated. `HRIS_ORG_STATUS.md` held no `members.manage` text (see `PLT-I01`). `013` header handled by `PLT-I03` |
| `PLT-T008` | 0 | Update the PLT row in `HRIS_MODULE_REGISTER.md` when Stage 0 closes | Document | | Claude | To do | | |
| `PLT-T009` | 0 | You approve the Blueprint for part A, or correct it | Decision | Blueprint | You | To do | | Closes Stage 0 together with `PLT-T007` and `PLT-T008` |
| `PLT-T016` | 0 | Answer `Q17`: should an administrator at org unit or Department scope manage members? Recommended: no, revisit in `EMP` | Decision | `Q17` | You | Done | 2026-11-07 | Recorded as `PLT-D18` (Business Unit scope also holds `members.manage`). Follow-up `PLT-Q18` |
| `PLT-T017` | 0 | Add to `HRIS_NAMING_CONVENTION.md`: `get_<things>` pattern for permission-checked read functions (section 4), PLT has no table prefix (section 3), and the frontend naming rules of `HRIS_FRONTEND_FOUNDATION.md` 3.3 (section 5, with Foundation step F6) | Document | 4.4 | Claude | To do | | Convention section 4 part with Stage 2, section 5 with F6 |
| `PLT-T018` | 0 | Answer `Q18`: what a Business Unit administrator may see and do. Proposed default in the Blueprint | Decision | `Q18` | You | To do | | Does not block Stage 1. Needed before Stage 2 |
| `PLT-T019` | 2 or 3 | Migration for `PLT-D18`: set the org unit flag on `members.manage`, add a Business Unit level check, and make the read and wrapper functions follow `Q18`. Needs `002_hierarchy_levels.sql` (level code) | Migration | `D18`, `Q18` | Claude | Not started | | Written with the first Stage that needs it |
| `PLT-T010` | 1 | Write `NNN_tenant_setup.sql`: `private.create_tenant_setup` (tenant, company, membership, tenant-wide `tenant_admin`, one transaction, repeat safe, `service_role` only) | Migration | `W1`, `SC-13`, 4.4 | Claude | To do | | Header `-- NNN: tenant setup (PLT Stage 1)`. The tenancy tables have no business date. If the function writes one it uses `private.org_today()` |
| `PLT-T011` | 1 | Write `NNN_tenant_setup_test.sql`: creates everything, second run creates nothing new, no access for `anon` and `authenticated`, expected date by the Phnom Penh formula if a date is written (`DT-10`) | SQL test | `UAT01`, `UAT02` | Claude | To do | | |
| `PLT-T012` | 1 | Decide and build the simplest first-admin login step (an operator script or a server-only route, run with the secret key). Generates a temporary password, shown once. The real screen version is Stage 4 | Frontend | `W1`, `D09` | Claude | To do | | The exact Supabase admin calls are read from the current Supabase documentation first, not assumed. The forced password change is Stage 4 |
| `PLT-T013` | 1 | Add the server-only secret key variable to `.env.local` (never a `NEXT_PUBLIC_` name). Add it to Vercel later with the other variables | Check | 1.3 | You | To do | | Never in the browser, never committed |
| `PLT-T014` | 1 | Run the `DT-11` search on the new migration before applying it | Check | 4.10 | You | To do | | Only hit allowed: inside `private.org_today()` (not in the new file) |
| `PLT-T015` | 1 | Browser check of `UAT01`: the first admin signs in and sees the ORG module | Check | `UAT01` | You | To do | | The forced password change is built in Stage 4 and is not part of this check |

---

## 4. Stage log

*One row when a Stage ends, passed or not.*

| Stage | Capability | Migration(s) | SQL test | Browser check | Result | Date | Notes (decisions made, changes to the plan) |
|---|---|---|---|---|---|---|---|
| 0 | Setup | none | n/a | n/a | In progress | 2026-11-07 | Blueprint written and updated. Decisions `PLT-D01` to `PLT-D18` recorded. Stage 2b (access log) added before Stage 3. Automatic removal moved to "Later". Checks done: names, date defaults, `Q13` (no new guard). `get_my_scope` added to Stage 2 for the scope selector (`FND-D06`). `Q17` opened. `PLT-T007` and `Q17` done 2026-11-07 (`PLT-D18`, `Q18` opened). Left: register row (`PLT-T008`), approve the Blueprint (`PLT-T009`), naming convention (`PLT-T017`), `Q18` |

---

## 5. Files

### 5.1 Migrations and tests

No PLT migration is written yet. Existing platform migrations that PLT uses (built during ORG, details in `HRIS_ORG_STATUS.md` section 5.1):

| File | Built in | What it gives PLT | Test file |
|---|---|---|---|
| `000_create_schemas.sql` | ORG Stage 0-1 | `core`, `private` schemas | n/a |
| `001_tenancy.sql` | ORG Stage 0-1 | `tenant`, `parent_company`, `tenant_member`, `private.user_tenant_ids()`, RLS | `001_tenancy_test.sql` |
| `012_roles.sql` | ORG Stage 9b-1 | `app_role`, `permission`, `app_role_permission`, `member_role_scope` (composite foreign keys keep member, company and unit in one tenant), 3 roles, permission codes, scope guard, RLS | `012_roles_test.sql` |
| `013_has_permission.sql` | ORG Stage 9b-2 | `private.has_permission`, `private.has_tenant_permission`, `private.role_has_permission` | `013_has_permission_test.sql` |
| `021_permission_check.sql` | ORG Stage 9e | `public.check_permissions` | `021_permission_check_test.sql` |
| `025_last_tenant_admin_guard.sql` | ORG platform item | Last tenant-wide `tenant_admin` guard | `025_last_tenant_admin_guard_test.sql` (passed 2026-11-07) |
| `029_phnom_penh_dates.sql` | ORG gap fix `ORG-T021` | `private.org_today()` (the one source of "today") | `029_phnom_penh_dates_test.sql` (passed 2026-11-07) |

### 5.2 Frontend files

No PLT frontend file exists yet. Existing files PLT will use:

| Path | Purpose | Depends on | Last changed in Stage |
|---|---|---|---|
| `lib/supabase/client.ts`, `server.ts`, `env.ts`, `database.types.ts` | Supabase clients and generated types. A secret-key client does not exist and is added server-only in Stage 1 (`PLT-T012`) | | ORG |
| `lib/dates.ts` | `todayInPhnomPenh()`, `isIsoDate()` (`DT-7`) | | ORG |
| `modules/org/permissions.ts` | `checkPermissions`, `usePermissions`. Moves to `lib/permissions.ts` in the Frontend Foundation Stage | `public.check_permissions` | ORG Stage 9e |
| `proxy.ts` | Session refresh and redirects. The forced password change (Stage 4) needs a redirect rule here or in the shell | | ORG |

### 5.3 Current versions of replaced functions

Start from the **latest** version when changing these:

| Function | Current version in | Replaced |
|---|---|---|
| `private.member_role_scope_guard()` | `012` | No |
| `private.member_role_scope_last_admin_guard()` | `025` | No |
| `private.org_today()` | `029` | No |

---

## 6. Next plan

Do the steps in order. Each one is validated before the next starts.

1. **Close Stage 0.** Documents aligned (`PLT-T007`, done) and `Q17` answered (`PLT-D18`). Left: update the register row (`PLT-T008`), approve the Blueprint (`PLT-T009`), answer `Q18` (`PLT-T018`, not blocking Stage 1).
2. **Stage 1: tenant setup.** Migration and test (`PLT-T010`, `PLT-T011`), first-admin login step (`PLT-T012`), secret key variable (`PLT-T013`), date search (`PLT-T014`), browser check (`PLT-T015`). Done when the SQL test passes and a first admin signs in.
3. **Frontend Foundation Stage** (`HRIS_FRONTEND_FOUNDATION.md`, F0 to F6). Done when ORG still works on the new shell with one and with several companies selected, and `npm run lint` and `npm test` pass.
4. **Stage 2: read access.** `FND-Q09` answered first.
5. **Stage 2b: access log.**
6. **Stage 3: roles.**
7. **Stage 4: logins and members.**
8. **Stage 5: read rule recorded** in the platform documents and the Blueprint template.
9. **Later:** automatic removal after the last working day, with part D and `EMP` or `LCY`.

---

## 7. Pending from you

* Approve the Blueprint, or correct it (`PLT-T009`).
* Answer `Q18` (not blocking Stage 1) and `FND-Q09` (before Stage 2).
* For `PLT-T019` later: `002_hierarchy_levels.sql`.
* Before Stage 1: add the server-only secret key variable to `.env.local` (`PLT-T013`).
* For the Foundation Stage F1 to F4: `OrgConfigView.tsx`, `Modal.tsx`, `AsyncSelect.tsx`, `permissions.ts`, `queries.ts`, `app/login/page.tsx`, `proxy.ts`, `eslint.config.mjs`.
* Later: `HRIS_CONTEXT.md` (personal data and retention rows, for the access log retention).

---

## 8. UAT coverage and results (P6)

*Scenarios come from Blueprint section 1.6. "Covered in Stage" follows the Stage plan, "Result" is filled in Phase P6.*

| Scenario | Covered in Stage | Result | Date | Note |
|---|---|---|---|---|
| `PLT-UAT01` Set up a tenant | 1 | Not run | | |
| `PLT-UAT02` Setup is repeat safe | 1 | Not run | | |
| `PLT-UAT03` See own access | 2 | Not run | | |
| `PLT-UAT04` Tenant admin sees all | 2 | Not run | | |
| `PLT-UAT05` Non-admin cannot see all | 2 | Not run | | |
| `PLT-UAT06` Company admin sees a scoped list | 2 | Not run | | |
| `PLT-UAT07` `hr_admin` reads, cannot change | 2, 3 | Not run | | Tenant-wide and company-scoped (`D16`) |
| `PLT-UAT08` Access log is written | 2b | Not run | | |
| `PLT-UAT09` Only tenant admins read the log | 2b | Not run | | |
| `PLT-UAT10` Give a role at company scope | 3 | Not run | | |
| `PLT-UAT11` Narrower scope replaces broader | 3 | Not run | | |
| `PLT-UAT12` Scope cannot change | 3 | Not run | | |
| `PLT-UAT13` Company admin stays inside the company | 3 | Not run | | |
| `PLT-UAT14` Last admin protected | 3, 4 | Not run | | The guard `025` is tested (SQL, 2026-11-07), the UAT runs through the screens |
| `PLT-UAT15` Admin removes own role | 3 | Not run | | |
| `PLT-UAT16` Non-admin cannot manage | 3 | Not run | | |
| `PLT-UAT17` Create a login | 4 | Not run | | |
| `PLT-UAT18` Forced password change | 4 | Not run | | |
| `PLT-UAT19` Reset a temporary password | 4 | Not run | | |
| `PLT-UAT20` Company admin creates a login | 4 | Not run | | |
| `PLT-UAT21` Remove a member | 4 | Not run | | |
| `PLT-UAT22` Cross-tenant isolation | 3 | Not run | | |
| `PLT-UAT23` Automatic removal | later | Not covered | | Not built in Stages 1 to 5 (`D14`) |
| `PLT-UAT24` Company admin removes a member who works in two companies | 4 | Not run | | `D15` |

---

## 9. Issues log

| ID | Stage | Problem | Found by | State | Fix or decision |
|---|---|---|---|---|---|
| `PLT-I01` | 0 | `HRIS_PROJECT_OVERVIEW.md` 5.7 and `HRIS_ORG_STATUS.md` section 3 still say `members.manage` is tenant-wide only and role changes are not logged. `PLT-D05` and `PLT-D08` change both. The reads rule (`D10`) is also new | Review | Fixed (2026-11-07) | `PLT-T007`. The Overview is aligned. Correction: `HRIS_ORG_STATUS.md` section 3 holds no `members.manage` text, so nothing there needed the wording change. The Overview pointed at it by mistake and now points at `012` and the Blueprint |
| `PLT-I02` | 0 | `HRIS_PROJECT_OVERVIEW.md` is out of date: 5.3 and section 7 say `025` is "not yet tested" and ask for the `026` test, 5.5 says "today" defaults to the UTC date (now `private.org_today()`, `029`), and 5.2 says "ORG has 18 wrappers" without the history objects | Review | Fixed (2026-11-07) | `PLT-T007` |
| `PLT-I03` | 0 | The header of the applied migration `013` says "members.manage is tenant-wide only" and "Nothing calls them yet". Both are out of date (the check works at company scope, the wrappers call it). Applied migrations are not edited | Review of `013` | Accepted | Note in the ORG Frontend Reference (`PLT-T007`). The Blueprint states the real behaviour (1.3) |

---

## 10. Deployment checklist (P7)

* [ ] Migrations applied to the test environment (dev project only, no test or production project)
* [ ] Environment variables set (secret key variable server-only, `PLT-T013`)
* [ ] Workflows checked with real roles (`PLT-UAT01` to `PLT-UAT22`, `PLT-UAT24`)
* [ ] Multi-factor sign-in decision revisited before real staff data is stored (`PLT-D13`)

---

## 11. Known limitations (P8)

| Limitation | Impact | Planned fix |
|---|---|---|
| No function creates a tenant, company, login or membership. Done by hand with `service_role` | Setup is manual | Stage 1 (setup), Stage 4 (logins) |
| No function or screen gives or removes roles. A user sees only their own assignments | Role management is manual | Stages 2 and 3 |
| Role, login and membership changes are not logged until Stage 2b | Early changes cannot be recovered | Stage 2b |
| Automatic removal after the last working day is not built | Access of leavers ends only when an administrator removes the member | Later (`PLT-D14`, part D, `EMP` or `LCY`) |
| Every login starts with a temporary password handed over by a person. No multi-factor sign-in (`PLT-D13`) | Higher risk for administrator accounts | Revisit before production |
| One login belongs to one tenant (`PLT-D12`) | No tenant switcher | Revisit before a second tenant is real |
| ORG reads are open to every tenant member (`PLT-D10`) | ORG cannot hold sensitive data. The scope selector only narrows the screen | Each later module governs its own reads |
| A company administrator who removes a member removes their access in other companies too (`PLT-D15`) | Possible loss of access elsewhere | Warning in the remove dialog (Stage 4) |
| Administrators at Branch, Division or Department scope cannot manage members. Business Unit scope is decided but not built (`PLT-D18`) | Branch or Division administrators need a company or Business Unit administrator | Business Unit: `PLT-T019`. Others: revisit in `EMP` |

---

## 12. Lessons (this module only)

* A decision that changes an **Existing** rule (here `members.manage` tenant-wide only, no role logging) must update the Overview and the ORG Status in the same session, or three documents disagree.
* Findings during a Stage go into Blueprint section 2 and section 9 here the same day, even before they are settled.
* Read the migration, not its header comment: the check in `013` already worked at company scope although its comment said tenant-wide only (the migration wins, `HRIS_NAMING_CONVENTION.md` section 2).
* A permission with neither the org unit nor the Department flag can never be granted by an org unit or Department assignment (`012`). Check the flags before designing who may do what.

---

## 13. How to resume

1. Open a new chat in the same Project and attach `HRIS_PROJECT_OVERVIEW.md`, this file and `package.json`. Name the Stage as "PLT Stage N" or "migration NNN" and paste any error text exactly.
2. For design, assumptions or open questions, also attach `HRIS_PLT_BLUEPRINT.md`.
3. For database work, also attach the Blueprint (section 4) and the migrations named in section 5.1 that the task depends on (for the guards: `012` and `025`). Use the latest version of any replaced function (section 5.3).
4. For frontend work, also attach `HRIS_FRONTEND_FOUNDATION.md`, the file lists of `app/`, `lib/` and `modules/`, and the latest version of each file to change.
5. If a file is missing, say so and Claude will ask whether to generate it.

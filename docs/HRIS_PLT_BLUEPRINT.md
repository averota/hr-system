# HRIS PLT Blueprint: Platform services

Last updated: 2026-11-07
Purpose: What the Platform services module must do, how it looks and behaves, and how its data is designed. Part A (access and setup) is designed in full. Parts B to E are summarised and designed later. Written before building. Changed only through the decision table (section 6).
Read together with: `HRIS_PROJECT_OVERVIEW.md` (sections 5.2, 5.4, 5.7 are the platform rules this module builds on), `HRIS_MODULE_REGISTER.md`, `HRIS_BUILD_STANDARDS.md`, `HRIS_ORG_STATUS.md` (section 3 for the role decisions and section 6 for the original planning step)

Origin labels: **Existing** (a decision or rule already in the project documents, source named), **Proposed** (Claude's recommendation, waiting for your answer). Nothing in this draft is marked as your decision unless it already was.

---

## 0. Read this first

| Item | Value |
|---|---|
| Module code | `PLT` |
| Table prefix | None new in part A. Role tables already use `app_` (`app_role`, `app_role_permission`) and `member_role_scope`, `permission` |
| Phase now | P1 to P3 draft for part A. Waiting for answers to section 2 |
| Depends on | `FND` (tenancy tables `core.tenant`, `core.parent_company`, `core.tenant_member`, migration `001`) |
| Used by | `ORG` (roles, `check_permissions`), and every later module (permission codes, approvals, lookups, files, scheduling) |
| Existing migrations | `001` tenancy, `012` roles, `013` `has_permission`, `021` `check_permissions`, `025` last tenant admin guard (written, not yet tested) |
| Ask me for these files if needed | `001_tenancy.sql`, `012_roles.sql`, `013_has_permission.sql`, `021_*.sql`, `025_last_tenant_admin_guard.sql` and their tests, `seed_dev_tenant.sql`, `lib/supabase/*`, the file lists of `app/` and `modules/org/` |

---

## 1. Requirements (P1)

### 1.1 Business objectives
1. A new tenant, its first company and its first tenant administrator can be created without hand-written SQL.
2. A tenant administrator can add and remove members and give, change and remove their roles, at every scope the role model supports.
3. Every member can see their own access. Administrators can see everyone's access in their tenant.
4. Access to sensitive data is governed by roles from the first module that stores it.
5. The platform can never be left without a tenant-wide administrator.

### 1.2 Workflows
**W1. Set up a tenant** (Proposed, PLT-Q02)
1. A platform operator runs the setup function with the tenant name, the first company name and the email of the first administrator.
2. The function creates the tenant, the parent company, the membership and the tenant-wide `tenant_admin` assignment, in one transaction.
3. The administrator signs in and sees an empty ORG module.

**W2. Add a member** (Proposed, PLT-Q03)
1. The administrator enters an email on the members screen.
2. The person receives a sign-in invitation and, once signed in, is a member of the tenant with no role.
3. The administrator gives them a role (W3). A member with no role can sign in but sees no write buttons and, from the first governed module on, no governed data.

**W3. Give, change and remove a role**
1. The administrator opens a member, chooses a role, a scope kind (tenant, company, org unit, Department) and a target.
2. The rules of `HRIS_PROJECT_OVERVIEW.md` section 5.7 apply: one assignment per member per scope, a narrower scope replaces the broader one, the role can change later, the scope cannot (to move a scope, remove and add).
3. Removing or downgrading the last tenant-wide `tenant_admin` is refused (`025`).

**W4. Remove a member**
1. The administrator removes the member. Their assignments go with them.
2. The last tenant-wide `tenant_admin` cannot be removed (`025`).

**W5. See access**
1. Any member opens "My access" and sees their own assignments.
2. An administrator opens the members screen and sees all members and assignments of the tenant (PLT-Q04).

### 1.3 Policies and rules
- Role model, scope rules and permission resolution: **Existing**, `HRIS_PROJECT_OVERVIEW.md` section 5.7. Not repeated here.
- Roles are enforced on writes and not on reads (**Existing**, Overview 5.4). Part A decides how reads become governed (PLT-Q06).
- `members.manage` is tenant-wide only (**Existing** as an assumption in `HRIS_ORG_STATUS.md` section 3, PLT-Q05).
- Role changes are not logged today (**Existing** decision, `HRIS_ORG_STATUS.md` section 3). The audit log of part B would change that (PLT-Q08).
- The `service_role` and secret keys never reach the browser (**Existing**). Anything that needs them runs on the server only.
- Member emails are personal data. They are visible only to those who may manage members (Proposed). See `HRIS_PROJECT_OVERVIEW.md` section 1.1, personal data.

### 1.4 Roles: who can do what
| Action | Platform operator | `tenant_admin` (tenant-wide) | `hr_admin` | Any other member | Permission |
|---|---|---|---|---|---|
| Create tenant, company, first admin | Yes (`service_role`) | No | No | No | operator only |
| List all members and assignments | | Yes | PLT-Q04 | No | `members.manage` (and maybe `members.read`) |
| See own access | | Yes | Yes | Yes | none (own rows) |
| Add or remove a member | | Yes | No | No | `members.manage` |
| Give, change or remove a role | | Yes | No | No | `members.manage` |
| Remove own admin role | | Yes, while another tenant-wide admin exists | | | `members.manage` and `025` |

"Manager" and "employee" roles do not exist yet. They need scopes such as "own record" and "my team", which depend on the employee link. They are designed in `EMP` and `LCY` (PLT-Q09).

### 1.5 Out of scope for part A
- Login screen, password reset (Supabase Auth, already in place).
- Multi-factor sign-in (PLT-Q12).
- Linking a login to an employee record (`EMP`).
- Billing and plans.
- Bulk import of members.

### 1.6 Acceptance criteria and UAT scenarios
| ID | Scenario | Role | Steps | Expected result | Covered in Stage |
|---|---|---|---|---|---|
| `PLT-UAT01` | Set up a tenant | Operator | Run the setup function with a new tenant, company and admin email | Tenant, company, membership and tenant-wide `tenant_admin` exist. The admin can sign in | 1 |
| `PLT-UAT02` | Setup is repeat safe | Operator | Run the same setup twice | Second run changes nothing or is refused with a clear message, and creates no duplicates | 1 |
| `PLT-UAT03` | See own access | Any member | Open "My access" | Only own assignments are listed | 2 |
| `PLT-UAT04` | Admin sees all | `tenant_admin` | Open the members screen | All members and assignments of this tenant, none of another tenant | 2 |
| `PLT-UAT05` | Non-admin cannot see all | Any non-admin | Call the members read function | Refused, no data | 2 |
| `PLT-UAT06` | Give a role at company scope | `tenant_admin` | Give `hr_admin` for one company | Assignment exists. `check_permissions` for that company says allowed | 3 |
| `PLT-UAT07` | Narrower scope replaces broader | `tenant_admin` | Give the same member a role on one org unit | On that unit the narrow role decides, elsewhere the broader one | 3 |
| `PLT-UAT08` | Scope cannot change | `tenant_admin` | Try to change the scope of an assignment | Refused. Remove and add works | 3 |
| `PLT-UAT09` | Last admin protected | `tenant_admin` | Remove, downgrade or delete the only tenant-wide admin | Refused (`025`) | 3, 4 |
| `PLT-UAT10` | Admin removes own role | `tenant_admin` | With a second admin present, remove own admin role | Allowed. Without a second admin, refused | 3 |
| `PLT-UAT11` | Non-admin cannot manage | `hr_admin` | Call a role or member wrapper | Refused with a plain message | 3 |
| `PLT-UAT12` | Add a member | `tenant_admin` | Add an email | Member exists with no role (flow depends on PLT-Q03) | 4 |
| `PLT-UAT13` | Remove a member | `tenant_admin` | Remove a member who has assignments | Member and assignments gone. Other members untouched | 4 |
| `PLT-UAT14` | Cross-tenant isolation | Admin of tenant A | Try to give a role to a member or target of tenant B | Refused, no data of tenant B visible | 3 |

### 1.7 Parts of this module (Proposed, PLT-Q01)
`PLT` is wider than one design can hold, so it is designed in parts. Each part finishes P3 and the scenario checklist before its own first Stage. Later modules need parts at different times.

| Part | Scope | First needed by | Designed |
|---|---|---|---|
| A | Access and setup (this document) | `EMP`, and everything with roles | Now |
| B | Bilingual master data (lookups such as gender, nationality, ID types) and the audit log | `EMP` (lookups), all modules (audit) | Before `EMP` Stage 1 |
| C | File storage on Cloudflare R2: private bucket, signed links, metadata in the database | `EMP` (documents, photos) | Before the first Stage that stores a file |
| D | One scheduling method for jobs (what runs, when, logged, safe to repeat, catches up) | `LCY` (probation and contract end), `LVE` (accruals), `EMP` (permit expiry) | Before the first module that needs a scheduled run |
| E | Shared approval workflow and notifications | `LCY`, `LVE` | Before `LCY` Stage 1 |

---

## 2. Assumptions, gaps and open questions

Answer by ID. Each answer becomes a decision in section 6. "Recommended" is Claude's recommendation, not a decision.

| ID | Type | Question | Recommended | Affects | Status |
|---|---|---|---|---|---|
| `PLT-Q01` | Question | Keep `PLT` as one module designed in parts A to E (section 1.7), or split parts B to E into a second module with its own code? | One module, designed in parts. Revisit if the Blueprint passes about 400 lines | Register, standards | Open |
| `PLT-Q02` | Question | Who creates tenants: a platform operator only, with no public sign-up? | Yes, operator only | Stage 1 | Open |
| `PLT-Q03` | Question | How does a person get a login: (a) the administrator sends an email invitation from the members screen, or (b) the person signs up first and the administrator then adds that email? | (a). It needs one server-side function that holds the Supabase secret key in a server-only environment variable, never in the browser | Stage 4, security | Open |
| `PLT-Q04` | Question | Who may see all members and assignments of a tenant: only `tenant_admin`, or also `hr_admin` (read only, through a new `members.read` code)? | `tenant_admin` and `hr_admin` see them. Only `tenant_admin` changes them | Stage 2, roles | Open |
| `PLT-Q05` | Assumption | `members.manage` stays tenant-wide only, so a company-scoped administrator cannot add members or give roles | Confirm | Stage 3 | Open |
| `PLT-Q06` | Question | How do reads become governed? Option 1: ORG reads stay open to every tenant member (structure is not sensitive), and every later module defines its own read code (`emp.read`, `pay.read`) enforced from its first Stage. Option 2: enforce `org.read` now as well | Option 1. It removes the blocker on `EMP` without touching ORG | `EMP`, all later modules | Open |
| `PLT-Q07` | Question | When someone leaves, is "remove member" enough (assignments deleted, no history), or is a way to switch a member off but keep the record needed? | Remove is enough. Part B's audit log records who did it and when | Stage 4, `LCY` | Open |
| `PLT-Q08` | Question | Role and membership changes are security-relevant and are not logged today. Build the audit log (part B) before Stage 3, or accept no log for now? | Build a minimal audit log before Stage 3 | Order of Stages | Open |
| `PLT-Q09` | Gap | Manager and employee access needs scope kinds like "own record" and "my team". Confirm these are designed in `EMP` and `LCY`, and that the scope guard in `012` stays extensible | Confirm | `EMP`, `LCY` | Open |
| `PLT-Q10` | Question | Can one login belong to several tenants? If yes, the app needs a tenant switcher. Today "usually one tenant with one company" | One tenant per login for now, no switcher. Revisit before a second tenant is real | Frontend | Open |
| `PLT-Q11` | Question | Language of the interface: English only for now, or English and Khmer text for labels and messages? (Data names are already bilingual) | English interface now, Khmer labels designed in part B | All screens | Open |
| `PLT-Q12` | Gap | Multi-factor sign-in for administrators before real data is stored | Plan Supabase MFA for administrators before production. Not in part A | Production | Open |
| `PLT-Q13` | Gap | Does guard `012` already refuse an assignment whose target belongs to another tenant? Not reviewed for this draft | Check in Stage 3, add a guard if missing | Stage 3 | Open |

---

## 3. Functional design (P2)

### 3.1 Screens
| Screen | Purpose | Who sees it | Main actions | Stage |
|---|---|---|---|---|
| Operator setup | Create tenant, company, first admin | Operator, no screen: a function run with `service_role` | Run setup | 1 |
| My access | Own assignments | Any member | View | 2 |
| Members list | All members of the tenant with a summary of roles | `tenant_admin` (and `hr_admin` if PLT-Q04) | Search, open a member, add member | 2, 4 |
| Member detail | Assignments of one member | Same | Give, change, remove a role. Remove member | 3, 4 |
| Give role dialog | Choose role, scope kind, target | `tenant_admin` | Save. The target picker reuses the ORG org-unit and Department lists | 3 |

### 3.2 User journeys
1. **Give a role to one org unit.** Members list, open member, Give role, choose `hr_admin`, scope "org unit", pick the unit, Save. The assignment appears in the member's list.
2. **Remove an administrator.** Open member, Remove role. If it is the last tenant-wide admin, a message explains why it cannot be done.

### 3.3 Validations and messages
Each message is one plain English sentence (`HRIS_NAMING_CONVENTION.md` section 4). Exact texts are written in the Stage that builds them and recorded in the frontend reference. Rules that need one:
| Rule | Where checked |
|---|---|
| A tenant must keep at least one tenant-wide administrator | Database (`025`, text taken from the migration) |
| The caller must hold `members.manage` in this tenant | Wrapper |
| The member and the scope target must belong to the same tenant | Wrapper and guard (PLT-Q13) |
| The member already has an assignment at this scope | Database (unique key) |
| The scope of an assignment cannot be changed | Database guard (**Existing**) |
| A scope target must be open when the assignment is created | Database guard (**Existing**) |

### 3.4 Expected behaviour and edge cases
- Empty states: a member with no role sees their own access page with "no roles yet". An empty members list cannot happen, the caller is a member.
- A scope target closed later keeps its assignment, which then grants nothing (**Existing**). The member detail shows it as "inactive target" (Proposed).
- Dates: role assignments carry no effective dates (section 4.8, SC-02, SC-03).
- Names: member display uses the email until a person record exists (`EMP`).
- A user removing their own admin role is signed out of admin screens at the next page load because `check_permissions` is asked again (Proposed).

---

## 4. Database design (P3, part A)

### 4.1 Entities and relationships
- `core.tenant` 1 to many `core.parent_company`.
- `core.tenant` 1 to many `core.tenant_member` (one row per login user in the tenant, the login is an `auth.users` id).
- `core.tenant_member` 1 to many `core.member_role_scope` (one role at one scope).
- `core.app_role` many to many `core.permission` through `core.app_role_permission`.

### 4.2 Tables
| Table | Purpose | Key columns | History | Created in Stage |
|---|---|---|---|---|
| `core.tenant`, `core.parent_company`, `core.tenant_member` | Tenancy | See `001` | Existing, no change | built |
| `core.app_role`, `core.permission`, `core.app_role_permission`, `core.member_role_scope` | Roles | See `012` | No role history (**Existing**) | built |

No new table in part A (Proposed). A possible new column or table appears only if PLT-Q07 or PLT-Q10 change the answer.

### 4.3 Constraints and rules
Existing and unchanged: one assignment per member per scope, scope guard (open target, Department kind, scope fixed after creation), last tenant admin guard (`025`). New checks, if missing (PLT-Q13): target and member in the same tenant.

### 4.4 Functions and permission codes
Names are proposed and follow `HRIS_NAMING_CONVENTION.md` section 4 (write functions start with a verb).

| Function | Does | Callable by | Permission | Stage |
|---|---|---|---|---|
| `private.create_tenant_setup` | Creates tenant, company, membership and tenant-wide `tenant_admin` in one transaction | `service_role` only | operator | 1 |
| `public.get_my_access` | Returns the caller's own assignments | `authenticated` | none (own rows) | 2 |
| `public.get_tenant_members` | Returns members and assignments of the caller's tenant | `authenticated` | `members.manage` (or `members.read`, PLT-Q04) | 2 |
| `public.assign_member_role`, `public.change_member_role`, `public.remove_member_role` | Give, change role of, remove an assignment | `authenticated` | `members.manage` | 3 |
| `public.add_tenant_member`, `public.remove_tenant_member` | Add or remove a member. Adding after the invitation step (PLT-Q03) | `authenticated` | `members.manage` | 4 |
| Existing: `public.check_permissions`, `private.has_permission`, `private.has_tenant_permission` | Permission checks | as built | | built |

Each public function is `security definer`, revoked from `public, anon, authenticated` first and then granted to `authenticated` and `service_role` (**Existing** pattern). Each checks the caller's permission before it calls a `private` function. Naming for read functions that check a permission (`get_...`) is not defined yet and is added to `HRIS_NAMING_CONVENTION.md` section 4 in Stage 2.

New permission code: `members.read` only if PLT-Q04 says so.

### 4.5 Visibility (RLS)
A user sees only their own assignments through the tables (**Existing**). The administrator's view of all assignments therefore goes through `public.get_tenant_members`, which checks the permission and then reads for the caller's tenant. The role tables stay out of `public` (Proposed, same as today).

### 4.6 Public contract
Stable for other modules: `public.check_permissions` (**Existing**, `021`), `public.get_my_access` (new). How a module adds permission codes: in its first migration, granted to roles there (**Existing**, Overview 5.7).

### 4.7 Reference and seed data
Roles and permission codes are seeded in `012` (**Existing**). `seed_dev_tenant.sql` stays a dev-only file. After Stage 1 the setup function replaces it for new tenants (Proposed).

### 4.8 Scenario decisions
Part A only. All are Proposed and wait for your review. "Does not apply" has its reason.

| Scenario | Applies to | Decision, or "Does not apply: reason" | Build consequence | Stage |
|---|---|---|---|---|
| SC-01 History needed | Role assignments | No history (**Existing**). Part B's audit log records who changed what (PLT-Q08) | No dated rows. Audit entries once part B exists | 3 |
| SC-02 Back-dated entry | Role assignments | Does not apply: an assignment takes effect when saved | none | |
| SC-03 Future-dated entry | Role assignments | Does not apply: no start date on assignments. A new hire gets access when HR gives it | none | |
| SC-04 Scheduled runs | Part A | Does not apply: nothing in part A runs by schedule. Part D defines the method | none | |
| SC-05 Overlap and gaps | `member_role_scope` | One assignment per member per scope (**Existing**) | Unique key, plain message | 3 |
| SC-06 Correction or change | Assignments | The role may change, the scope never (**Existing**). A wrong scope is removed and added | Guard exists | 3 |
| SC-07 Cancel or reverse | Assignments | Removing is the reversal. No undo | none | 3 |
| SC-08 Period lock | Part A | Does not apply: no period concept | none | |
| SC-09 Add | Members | Needs a login (PLT-Q03). Duplicate email in the tenant is refused | Unique on tenant plus user | 4 |
| SC-10 Edit | Assignments | Only the role is editable | `change_member_role` | 3 |
| SC-11 Delete | Assignments, members | Hard delete, no history (**Existing**). The last tenant-wide admin cannot be deleted (**Existing**, `025`) | `remove_*` wrappers | 3, 4 |
| SC-12 Triggers | `member_role_scope`, `tenant_member` | Last admin guard and scope guard only. No new trigger | Listed in 4.9 | 3 |
| SC-13 Repeat safety | Setup, assign | Setup run twice creates nothing new. Assigning the same role twice is refused, not duplicated | Idempotent setup, unique key | 1, 3 |
| SC-14 Status model | Members | No status in part A (PLT-Q07) | none | |
| SC-15 Approval | Part A | Does not apply: an administrator acts directly | none | |
| SC-16 Notifications | Invitation | The sign-in invitation email comes from Supabase Auth (PLT-Q03). Other messages wait for part E | none | 4 |
| SC-17 Who acts on whom | All | See section 1.4. Emails visible only to those who may manage members | Permission checks in the read function | 2, 3 |
| SC-18 Employee status effects | Members | When an employee leaves, `LCY` calls `remove_tenant_member`. Part A only provides the function | Contract for `LCY` | 4 |
| SC-19 Stored or calculated | Part A | Does not apply | none | |
| SC-20 Money, rounding, calendar | Part A | Does not apply | none | |
| SC-21 Reporting needs | Members list | Small lists, search on the page is enough. Paging is not needed | none | 2 |
| SC-22 Bulk data | Members | Does not apply in part A (out of scope, 1.5) | none | |
| SC-23 Khmer and calendar | Screens | Interface language is PLT-Q11. Member names are emails | none | |

### 4.9 Triggers and scheduled runs
| Name | Type | When it fires | What it does | Tables touched | Safe to repeat? | Stage |
|---|---|---|---|---|---|---|
| Last tenant admin guard (`025`, name in the migration) | Trigger | On delete or downgrade of an assignment, or removal of a member or auth user | Refuses if it would leave the tenant without a tenant-wide `tenant_admin`. A whole tenant can be deleted only after the teardown setting (**Existing**) | `member_role_scope`, `tenant_member` | Yes | built, not yet tested |
| Scope guard (`012`, name in the migration) | Trigger | On insert or update of an assignment | Open target, Department kind, scope fixed | `member_role_scope` | Yes | built |
| `private.create_tenant_setup` | Write function | Run by the operator | See 4.4 | `tenant`, `parent_company`, `tenant_member`, `member_role_scope` | Yes | 1 |

---

## 5. Stage plan

| Stage | Capability (a user can...) | Migrations | Frontend | Depends on | Status |
|---|---|---|---|---|---|
| 0 | Setup: apply and test `025`, answer section 2, confirm Stage plan, record decisions | none | none | `025` test | Not started |
| 1 | An operator creates a tenant, company and first admin without hand SQL | setup function and test | none | Q02 | Not started |
| 2 | Any member sees their own access. An administrator sees all members and assignments | read functions and test | My access, Members list (read only) | Q04, Q11 | Not started |
| 3 | An administrator gives, changes and removes a role | role wrappers and test | Member detail, Give role dialog | Q05, Q08, Q13 | Not started |
| 4 | An administrator adds and removes a member | member wrappers and test | Add member dialog, remove action | Q03, Q07 | Not started |
| 5 | Reads are governed as decided | depends on Q06 | depends on Q06 | Q06 | Not started |
| B to E | Designed later, one part at a time (section 1.7) | | | | Not designed |

Stages 1 to 4 can be reordered only if Q08 says the audit log comes first.

---

## 6. Decisions

Decisions already made and used here are not copied. They are in `HRIS_PROJECT_OVERVIEW.md` sections 5.1 and 5.7 and `HRIS_ORG_STATUS.md` section 3: three starting roles, role scope kinds, narrower scope replaces broader, no role history, reads open to every tenant member for now, last tenant-wide admin protected.

| ID | Date | Decision | Origin | Reason |
|---|---|---|---|---|
| | | None yet. Answers to section 2 are recorded here as `PLT-D01` onward | | |

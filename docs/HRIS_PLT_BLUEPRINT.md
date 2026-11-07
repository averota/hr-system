# HRIS PLT Blueprint: Platform services

Last updated: 2026-11-07
Purpose: What the Platform services module must do, how it looks and behaves, and how its data is designed. Part A (access and setup) is designed in full. Parts B to E are summarised and designed later. Written before building. Changed only through the decision table (section 6).
Read together with: `HRIS_PROJECT_OVERVIEW.md` (sections 5.2, 5.4, 5.7 are the platform rules this module builds on), `HRIS_MODULE_REGISTER.md`, `HRIS_BUILD_STANDARDS.md`, `HRIS_NAMING_CONVENTION.md`, `HRIS_FRONTEND_FOUNDATION.md`, `HRIS_ORG_STATUS.md`

Origin labels (as in `HRIS_NAMING_CONVENTION.md`): **Your decision** (answered by you, recorded in section 6), **Adopted** (a recommendation you accepted), **Assumption** (not confirmed yet), **Existing** (a rule already in the project documents or migrations, source named).

---

## 0. Read this first

| Item | Value |
|---|---|
| Module code | `PLT` |
| Table prefix | None. Names stay plain (`access_log`, like `tenant`, `permission`). Recorded in `HRIS_NAMING_CONVENTION.md` section 3 with the first PLT migration (Stage 2b) |
| Phase now | P1 to P3 for part A approved by you on 2026-11-07 (Stage 0 closed). Stage 1 passed 2026-11-07. One question is open (`Q18`), not blocking |
| Depends on | `FND` (tenancy tables `core.tenant`, `core.parent_company`, `core.tenant_member`, migration `001`) |
| Used by | `ORG` (roles, `check_permissions`), and every later module (permission codes, approvals, lookups, files, scheduling) |
| Existing migrations | `001` tenancy, `012` roles, `013` `has_permission`, `021` `check_permissions`, `025` last tenant admin guard (applied, test passed 2026-11-07), `029` `private.org_today()` (the date helper, section 4.10) |
| Ask me for these files if needed | `HRIS_CONTEXT.md` (personal data and retention rows, for the log), `seed_dev_tenant.sql`, `lib/supabase/*`, the file lists of `app/` and `modules/org/`. `001`, `012`, `013`, `021` and the naming convention were reviewed on 2026-11-07 |

---

## 1. Requirements (P1)

### 1.1 Business objectives
1. A new tenant, its first company and its first tenant administrator can be created without hand-written SQL.
2. A tenant administrator can create logins and give, change and remove roles for every member of the tenant. A company administrator can do the same inside their own company only (`PLT-D05`).
3. Every member can see their own access. Administrators can see the access of the members their scope covers.
4. Access to sensitive data is governed by roles from the first module that stores it (`PLT-D10`).
5. The platform can never be left without a tenant-wide administrator.
6. Every change to a login, a membership or a role is recorded: who, when, what (`PLT-D08`).

### 1.2 Workflows
**W1. Set up a tenant** (`PLT-D02`: operator only)
1. A platform operator runs the setup function with the tenant name, the first company name and the email of the first administrator.
2. The function creates the tenant, the parent company, the membership and the tenant-wide `tenant_admin` assignment, in one transaction. The login of the first administrator is created by the operator (the same server-only step as W2).
3. The administrator signs in and sees an empty ORG module.

**W2. Create a login for a member** (`PLT-D09`)
1. A tenant-wide administrator, or a company administrator, enters the person's email and the company the person is added for. The company administrator can choose only their own company.
2. The system generates a temporary password and shows it **once**. The administrator hands it to the person.
3. The person signs in and must choose their own password before anything else (forced change at first sign-in).
4. The new member has no role and is listed as "no role yet". An administrator gives them a role (W3). A member with no role can sign in but sees no write buttons and, from the first governed module on, no governed data (`PLT-D10`).
5. If the password is lost before first use, an administrator resets it (Assumption, section 4.4: a new temporary password, shown once, forced change again).

**W3. Give, change and remove a role**
1. The administrator opens a member, chooses a role, a scope kind (tenant, company, org unit, Department) and a target.
2. The rules of `HRIS_PROJECT_OVERVIEW.md` section 5.7 apply: one assignment per member per scope, a narrower scope replaces the broader one, the role can change later, the scope cannot (to move a scope, remove and add).
3. A company administrator can give any role, only at their own company, an org unit or a Department of that company. Never a tenant-wide role, never another company (`PLT-D06`).
4. Removing or downgrading the last tenant-wide `tenant_admin` is refused (`025`).

**W4. Remove a member**
1. **By an administrator:** a tenant administrator removes any member. A company administrator removes any member who has a role in their company, **including the membership itself when the member also works in another company**, which then loses access there too (`PLT-D15`). The member's assignments go with the member. The remove dialog warns when the member has roles outside the caller's view (Assumption, Stage 4).
2. **Automatically after the last working day** (`PLT-D14`): the system removes the member the day after their last working day (Phnom Penh date), in a daily run shortly after midnight Phnom Penh time. The date comes from the employee record (`EMP`, `LCY`). If the removal would leave the tenant without a tenant-wide administrator, the run skips it, logs it and tells tenant administrators. The login is disabled only when the person belongs to no other tenant. Built later with `EMP`, `LCY` and part D, **not** in Stages 1 to 5.
3. The last tenant-wide `tenant_admin` cannot be removed, by anyone or by the automatic run (`025`).

**W5. See access and the log**
1. Any member opens "My access" and sees their own assignments.
2. A tenant-wide administrator and a tenant-wide `hr_admin` (read only, `PLT-D03`) open the members screen and see all members and assignments of the tenant. A company administrator and a company-scoped `hr_admin` (read only, `PLT-D16`) see the members with a role in their company plus members with no role yet (`PLT-D07`).
3. Tenant-wide administrators open the access log (`PLT-D08`). Nobody else sees it.

### 1.3 Policies and rules
- Role model, scope rules and permission resolution: **Existing**, `HRIS_PROJECT_OVERVIEW.md` section 5.7. Not repeated here.
- Roles are enforced on writes and not on reads for ORG (**Existing**). From now on every new module governs its own reads with its own read code (`emp.read`, `pay.read`), enforced from its first Stage (`PLT-D10`).
- `members.manage` can be held at tenant or company scope (`PLT-D05`). This **replaces** the earlier assumption "tenant-wide only" in `HRIS_PROJECT_OVERVIEW.md` section 5.7 (aligned on 2026-11-07). The check already works that way: `private.has_permission(company, 'members.manage')` resolves a company-scope assignment (013, checked 2026-11-07). The line "members.manage is tenant-wide only" in the header of migration `013` is only a comment. Actions that must be tenant-wide (giving a tenant-wide role, reading the access log) use `private.has_tenant_permission`.
- A role given at **Branch, Division or Department scope never grants `members.manage`**. A role given at **Business Unit scope will** (`PLT-D18`, Stage 2 or 3): today the permission applies to no org unit (`012`), so a later migration sets the flag and the check limits it to Business Units. What a Business Unit administrator may see and do is `PLT-Q18`.
- The log of who changed what is built before Stage 3 (`PLT-D08`). This replaces the earlier "role changes are not logged" decision from Stage 3 on.
- Logins are created by administrators. There is no public sign-up and no invitation email (`PLT-D09`).
- One login belongs to one tenant for now (`PLT-D12`).
- Multi-factor sign-in is not planned (`PLT-D13`). **Accepted risk:** administrators can see staff data and every login starts with a temporary password handed over by a person. Revisit before real staff data is stored in production.
- The `service_role` and secret keys never reach the browser (**Existing**). The login creation runs on the server only, with the key in a server-only environment variable.
- Member emails are personal data. They are visible only to those who may manage or read members, inside their scope (Assumption). The emails live in the login system (`auth.users`), not in `core` (Section 4.4). See `HRIS_PROJECT_OVERVIEW.md` section 1.1, personal data.
- Dates and times follow the fixed date and time rules of section 4.10 (**Existing**, `HRIS_BLUEPRINT_TEMPLATE.md`, migration `029`).

### 1.4 Roles: who can do what
"Company administrator" means the `tenant_admin` role given at company scope. "Tenant administrator" means the same role given tenant-wide.

| Action | Platform operator | Tenant administrator | Company administrator | `hr_admin` | Any other member | Permission |
|---|---|---|---|---|---|---|
| Create tenant, company, first admin | Yes (`service_role`) | No | No | No | No | operator only |
| See members and assignments | | All members of the tenant | Members with a role in the company, plus members with no role yet | Tenant-wide: all members, read only (`PLT-D03`). Company-scoped: the scoped list, read only (`PLT-D16`) | No | `members.manage`, `members.read` |
| See own access | | Yes | Yes | Yes | Yes | none (own rows) |
| Create a login | | Yes | Yes, added to their own company | No | No | `members.manage` |
| Reset a temporary password | | Yes | Yes, for members they may see | No | No | `members.manage` |
| Give, change or remove a role | | Any scope | Own company scopes only, never tenant-wide | No | No | `members.manage` |
| Remove a member | | Yes | Any member with a role in their company, membership included (`PLT-D15`) | No | No | `members.manage` |
| Read the access log | | Yes | No | No | No | `members.manage`, tenant-wide only |
| Remove own admin role | | Yes, while another tenant-wide admin exists | Yes | | | `members.manage` and `025` |

Administrators at Branch, Division or Department scope cannot manage members. Business Unit administrators can (`PLT-D18`), within the limits of `PLT-Q18`, which is still open (proposed: like a company administrator, restricted to their unit and the units below it). "Manager" and "employee" roles do not exist yet. They need scopes such as "own record" and "my team", which depend on the employee link. They are designed in `EMP` and `LCY`, and the scope guard in `012` stays extensible (`PLT-D17`).

### 1.5 Out of scope for part A
- Login screen and password reset by the person themselves (Supabase Auth, already in place). The administrator reset of a temporary password is in scope (W2).
- Multi-factor sign-in (`PLT-D13`).
- Linking a login to an employee record (`EMP`).
- **Automatic removal after the last working day** (`PLT-D14`): decided, built later with `EMP`, `LCY` and part D.
- Manager and employee scopes ("own record", "my team", `PLT-D17`).
- Invitation emails and any other email (part E).
- Billing and plans.
- Bulk import of members.

### 1.6 Acceptance criteria and UAT scenarios
| ID | Scenario | Role | Steps | Expected result | Covered in Stage |
|---|---|---|---|---|---|
| `PLT-UAT01` | Set up a tenant | Operator | Run the setup function with a new tenant, company and admin email | Tenant, company, membership and tenant-wide `tenant_admin` exist. The admin can sign in with the temporary password | 1 |
| `PLT-UAT02` | Setup is repeat safe | Operator | Run the same setup twice | Second run changes nothing or is refused with a clear message, and creates no duplicates | 1 |
| `PLT-UAT03` | See own access | Any member | Open "My access" | Only own assignments are listed | 2 |
| `PLT-UAT04` | Tenant admin sees all | Tenant administrator | Open the members screen | All members and assignments of this tenant, none of another tenant | 2 |
| `PLT-UAT05` | Non-admin cannot see all | Any member without `members.read` or `members.manage` | Call the members read function | Refused, no data | 2 |
| `PLT-UAT06` | Company admin sees a scoped list | Company administrator | Open the members screen | Members with a role in their company and members with no role yet. Not members who only work in another company | 2 |
| `PLT-UAT07` | `hr_admin` reads, cannot change | Tenant-wide and company-scoped `hr_admin` | Open the members screen, then try to give a role | List shown (all, or the scoped list). Giving a role refused | 2, 3 |
| `PLT-UAT08` | Access log is written | Tenant administrator | Create a login, give, change and remove a role | One log entry per change with actor, time, member, role and scope | 2b |
| `PLT-UAT09` | Only tenant admins read the log | Company administrator | Call the access log read function | Refused, no data | 2b |
| `PLT-UAT10` | Give a role at company scope | Tenant administrator | Give `hr_admin` for one company | Assignment exists. `check_permissions` for that company says allowed | 3 |
| `PLT-UAT11` | Narrower scope replaces broader | Tenant administrator | Give the same member a role on one org unit | On that unit the narrow role decides, elsewhere the broader one | 3 |
| `PLT-UAT12` | Scope cannot change | Tenant administrator | Try to change the scope of an assignment | Refused. Remove and add works | 3 |
| `PLT-UAT13` | Company admin stays inside the company | Company administrator | Give a role on a unit of another company, and give a tenant-wide role | Both refused with a plain message | 3 |
| `PLT-UAT14` | Last admin protected | Tenant administrator | Remove, downgrade or delete the only tenant-wide admin | Refused (`025`) | 3, 4 |
| `PLT-UAT15` | Admin removes own role | Tenant administrator | With a second tenant-wide admin present, remove own admin role | Allowed. Without a second admin, refused | 3 |
| `PLT-UAT16` | Non-admin cannot manage | `hr_admin` | Call a role or member wrapper | Refused with a plain message | 3 |
| `PLT-UAT17` | Create a login | Tenant or company administrator | Create a login with an email | Member exists with no role. The temporary password is shown once and cannot be shown again | 4 |
| `PLT-UAT18` | Forced password change | The new member | Sign in with the temporary password | The member must set their own password before any other screen opens | 4 |
| `PLT-UAT19` | Reset a temporary password | Administrator | Reset the password of a member who has not changed it | New temporary password shown once. The old one stops working. Forced change applies again | 4 |
| `PLT-UAT20` | Company admin creates a login | Company administrator | Create a login | Allowed, the member is added to the tenant with no role. A second login with the same email is refused | 4 |
| `PLT-UAT21` | Remove a member | Authorized administrator | Remove a member who has assignments | Member and assignments gone. Other members untouched. Entry in the log | 4 |
| `PLT-UAT22` | Cross-tenant isolation | Admin of tenant A | Try to give a role to a member or target of tenant B | Refused, no data of tenant B visible | 3 |
| `PLT-UAT23` | Automatic removal | System | A member's last working day passes | Member removed the next day (Phnom Penh date). The last tenant-wide admin is never removed, the skip is logged and shown to tenant administrators. **Not built in Stages 1 to 5** | later |
| `PLT-UAT24` | Company admin removes a member who works in two companies | Company administrator | Remove a member who has roles in the company and in another company | Allowed (`PLT-D15`). The member loses access in both companies. The log records it | 4 |

### 1.7 Parts of this module (`PLT-D01`)
`PLT` stays one module, designed in parts. Each part finishes P3 and the scenario checklist before its own first Stage. Later modules need parts at different times. `PLT-D01` suggested revisiting if the Blueprint becomes hard to use (about 400 lines). It is past that now but still reads as one document.

| Part | Scope | First needed by | Designed |
|---|---|---|---|
| A | Access and setup (this document) | `EMP`, and everything with roles | Now |
| B | Bilingual master data (lookups such as gender, nationality, ID types) and the full audit log (part A builds only a minimal access log) | `EMP` (lookups), all modules (audit) | Before `EMP` Stage 1 |
| C | File storage on Cloudflare R2: private bucket, signed links, metadata in the database | `EMP` (documents, photos) | Before the first Stage that stores a file |
| D | One scheduling method for jobs (what runs, when, logged, safe to repeat, catches up). The first job is the automatic removal after the last working day (`PLT-D14`) | `LCY` (probation and contract end), `LVE` (accruals), `EMP` (permit expiry), `PLT` (automatic removal) | Before the first module that needs a scheduled run |
| E | Shared approval workflow and notifications | `LCY`, `LVE` | Before `LCY` Stage 1 |

---

## 2. Assumptions, gaps and open questions

Answers are recorded in section 6.

| ID | Type | Question | Status | Settled by |
|---|---|---|---|---|
| `PLT-Q01` | Question | One module designed in parts A to E, or split? | Settled | `PLT-D01` |
| `PLT-Q02` | Question | Who creates tenants? | Settled | `PLT-D02` |
| `PLT-Q03` | Question | How does a person get a login? | Settled | `PLT-D09` |
| `PLT-Q04` | Question | Who may see all members and assignments of a tenant? | Settled | `PLT-D03` (company scope: `PLT-D07`, `PLT-D16`) |
| `PLT-Q05` | Assumption | Is `members.manage` tenant-wide only? | Settled (changed) | `PLT-D05`, `PLT-D06`, `PLT-D07` |
| `PLT-Q06` | Question | How do reads become governed? | Settled | `PLT-D10` |
| `PLT-Q07` | Question | What happens to the member record when someone leaves? | Settled | `PLT-D11`, `PLT-D14`, `PLT-D15` |
| `PLT-Q08` | Question | When is the log of role and member changes built, and who reads it? | Settled | `PLT-D08` |
| `PLT-Q09` | Gap | Manager and employee scope kinds ("own record", "my team") | Settled | `PLT-D17` |
| `PLT-Q10` | Question | Can one login belong to several tenants? | Settled | `PLT-D12` |
| `PLT-Q11` | Question | Interface language? | Settled | `PLT-D04` |
| `PLT-Q12` | Gap | Multi-factor sign-in for administrators | Settled (accepted risk) | `PLT-D13` |
| `PLT-Q13` | Gap | Checked on 2026-11-07 against `012` and `013`: (a) a company, org unit or Department of another tenant is already refused by the composite foreign keys in `012` (the member, company and units must belong to one tenant). The error is a raw foreign key error, so the wrappers check first and give a plain message. (b) `private.has_permission(company, 'members.manage')` already resolves a company-scope assignment. Only `has_tenant_permission` is tenant-wide only. (c) The wrapper limits a company administrator: it checks `has_permission` for the company, refuses scope kind `tenant` unless `has_tenant_permission` passes, and the composite foreign keys keep a target inside the company. **No new guard is needed** | Settled (checked) | Findings, no decision needed |
| `PLT-Q14` | Question | Automatic removal after the last working day | Settled | `PLT-D14` |
| `PLT-Q15` | Question | What a company administrator may remove | Settled | `PLT-D15` |
| `PLT-Q16` | Question | View of a company-scoped `hr_admin` | Settled | `PLT-D16` |
| `PLT-Q17` | Question | A role at Business Unit, Branch, Division or Department scope never grants `members.manage` (found in `012`). Should an administrator at org unit scope be able to manage the members of their unit? Recommended: no. A member is not tied to an org unit until `EMP`, so "members of a Branch" has no meaning yet. Revisit in `EMP` with `PLT-D17` | Settled | `PLT-D18` |
| `PLT-Q18` | Question | What may a Business Unit administrator see and do (`PLT-D18`)? A member is not tied to an org unit until `EMP`, so "members of a Business Unit" needs a meaning now. Proposed: the same as a company administrator, restricted to the unit and the units below it. Sees the members with a role at or below the unit, plus members with no role yet. Gives, changes and removes roles only at the unit or below it (not Departments, not company, not tenant). Cannot create logins or remove a member from the tenant (membership belongs to the company level). Needs `002_hierarchy_levels.sql` to read the Business Unit level code | Open, does not block Stage 1 | |

---

## 3. Functional design (P2)

### 3.1 Screens
| Screen | Purpose | Who sees it | Main actions | Stage |
|---|---|---|---|---|
| Operator setup | Create tenant, company, first admin | Operator, no screen: a function run with `service_role` | Run setup | 1 |
| My access | Own assignments | Any member | View | 2 |
| Members list | Members the caller's scope covers, with a summary of roles. "No role yet" is shown clearly | Tenant and company administrators, `hr_admin` (read only) | Search, open a member, create a login | 2, 4 |
| Access log | Who changed what and when | Tenant administrators | Filter by member, action, date | 2b |
| Member detail | Assignments of one member | Same as the list | Give, change, remove a role. Reset password. Remove member | 3, 4 |
| Give role dialog | Choose role, scope kind, target. A company administrator sees only own-company targets and no tenant scope | Administrators | Save. The target picker uses the org unit and Department pickers that ORG exports for other modules (`HRIS_FRONTEND_FOUNDATION.md`, `FND-D04`) | 3 |
| Create login dialog | Email and company. Shows the generated password once | Administrators | Create, copy password | 4 |
| Remove member dialog | Confirms the removal. Warns when the member also has roles outside the caller's view | Administrators | Remove | 4 |
| Set new password | First screen after the first sign-in with a temporary password | The new member | Save a new password | 4 |

### 3.2 User journeys
1. **Give a role to one org unit.** Members list, open member, Give role, choose `hr_admin`, scope "org unit", pick the unit, Save. The assignment appears in the member's list.
2. **Create a login for a new colleague.** Members list, Create login, enter email, Create. Copy the password shown once and hand it over. The colleague signs in, sets a new password, and sees no role yet. The administrator gives a role.
3. **Remove an administrator.** Open member, Remove role. If it is the last tenant-wide admin, a message explains why it cannot be done.

### 3.3 Validations and messages
Each message is one plain English sentence (`HRIS_NAMING_CONVENTION.md` section 4). Exact texts are written in the Stage that builds them and recorded in the frontend reference. Rules that need one:
| Rule | Where checked |
|---|---|
| A tenant must keep at least one tenant-wide administrator | Database (`025`, text taken from the migration) |
| The caller must hold `members.manage` (or `members.read` for the list) in the tenant or in the company concerned | Wrapper (`has_permission` for the company, `has_tenant_permission` for tenant-wide actions) |
| A company administrator may only act on their own company and its org units and Departments, and may not give a tenant-wide role | Wrapper (the composite foreign keys of `012` keep targets inside the company) |
| The member and the scope target must belong to the same tenant | Database (composite foreign keys, `012`) and wrapper (plain message) |
| The member already has an assignment at this scope | Database (unique key) |
| The scope of an assignment cannot be changed | Database guard (**Existing**) |
| A scope target must be open when the assignment is created | Database guard (**Existing**) |
| A login email already used in the tenant | Server function and database (unique key) |
| The temporary password is shown once | Server function (not stored in readable form, not logged) |
| A member with a temporary password must set a new one before using the app | Frontend and server check (Assumption, section 4.4) |

### 3.4 Expected behaviour and edge cases
- Empty states: a member with no role sees their own access page with "no roles yet". An empty members list cannot happen, the caller is a member.
- A scope target closed later keeps its assignment, which then grants nothing (**Existing**). The member detail shows it as "inactive target" (Assumption).
- A temporary password is not shown again. If it is lost, an administrator resets it (W2 step 5).
- A company administrator removing a member who also works in another company cuts that access too (`PLT-D15`). The dialog warns when `get_tenant_members` reports assignments outside the caller's scope (a yes or no, without details, Assumption).
- A person removed from the tenant loses access at their next request. The login stays unless the automatic run disables it (`PLT-D14`, no other tenant).
- Dates: role assignments carry no effective dates (section 4.8, SC-02, SC-03). The log shows its time in Phnom Penh time (section 4.10, DT-7).
- Names: member display uses the email until a person record exists (`EMP`).
- A user removing their own admin role is signed out of admin screens at the next page load because `check_permissions` is asked again (Assumption).

---

## 4. Database design (P3, part A)

### 4.1 Entities and relationships
- `core.tenant` 1 to many `core.parent_company`.
- `core.tenant` 1 to many `core.tenant_member` (one row per login user in the tenant, the login is an `auth.users` id).
- `core.tenant_member` 1 to many `core.member_role_scope` (one role at one scope).
- `core.app_role` many to many `core.permission` through `core.app_role_permission`.
- `core.tenant` 1 to many access log entries (new, section 4.2).

### 4.2 Tables
| Table | Purpose | Key columns | History | Created in Stage |
|---|---|---|---|---|
| `core.tenant`, `core.parent_company`, `core.tenant_member` | Tenancy | See `001` | Existing, no change | built |
| `core.app_role`, `core.permission`, `core.app_role_permission`, `core.member_role_scope` | Roles | See `012` | No role history (**Existing**). The log below records changes | built |
| `core.access_log` (name checked against the naming convention: singular, plain, no prefix) | Who did what to which member and when. Minimal version of the part B audit log | tenant, company (null when tenant-wide), actor login, action (create login, add member, remove member, give role, change role, remove role, reset password, automatic removal, automatic removal skipped), target member, role, scope kind and target, `created_at` (`timestamptz`, the convention's audit column) | Append only, never edited or deleted by the app. Retention follows the personal data and retention rows of `HRIS_CONTEXT.md` (to verify). Emails in the log are personal data | 2b |

No other new table in part A (Assumption). The "must change password" flag lives with the login in Supabase Auth, not in a `core` table (Assumption, checked in Stage 4). Member emails are not in `core`: `core.tenant_member` holds only the tenant and the login id. `get_tenant_members` reads the email from `auth.users` (Assumption, checked in Stage 2).

### 4.3 Constraints and rules
Existing and unchanged: one assignment per member per scope, composite foreign keys that keep member, company and unit in one tenant (`012`), scope guard (open target, Department kind, scope fixed after creation), last tenant admin guard (`025`). New: nothing in the database for a company administrator's reach (`PLT-Q13`, the wrapper does it). Access log rows are append only.

### 4.4 Functions and permission codes
Names follow `HRIS_NAMING_CONVENTION.md` section 4 (write functions start with a verb, parameters `p_`, variables `v_`, `set search_path = ''`, explicit `revoke` and `grant`).

| Function | Does | Callable by | Permission | Stage |
|---|---|---|---|---|
| `private.create_tenant_setup` | Creates tenant, company, membership and tenant-wide `tenant_admin` in one transaction. The login is created first by the server step below | `service_role` only | operator | 1 |
| `public.get_my_access` | Returns the caller's own assignments | `authenticated` | none (own rows) | 2 |
| `public.get_tenant_members` | Returns the members and assignments the caller's scope covers (tenant-wide: all, company scope: members with a role in the company plus members with no role yet). Includes the email from `auth.users` and, for each member, a yes or no for "has assignments outside the caller's scope" | `authenticated` | `members.manage` or `members.read`, at tenant or company scope | 2 |
| `public.get_my_scope` | Returns the companies and org units the caller's assignments cover (tenant: all, company: all its units, org unit: the unit and everything below). Feeds the scope selector of the shell (`HRIS_FRONTEND_FOUNDATION.md` 5.1). The selector first works on the existing views and switches to this function here. Department scope: `FND-Q09` | `authenticated` | none (own assignments) | 2 |
| `public.get_access_log` | Returns the access log of the caller's tenant | `authenticated` | `members.manage`, tenant-wide only (`has_tenant_permission`) | 2b |
| Access log trigger | Writes a log entry on every insert, update or delete of an assignment or a membership, whoever does it (also hand SQL, then the actor is empty) | database | none | 2b |
| `public.assign_member_role`, `public.change_member_role`, `public.remove_member_role` | Give, change role of, remove an assignment. A company administrator: own company scopes only, never tenant-wide | `authenticated` | `members.manage` at the company concerned (`has_permission`), tenant-wide scope needs `has_tenant_permission` | 3 |
| **Server-only step** `create member login` (route handler or server action, decided in Stage 4) | Checks the caller's permission with the caller's session, creates the login with a generated temporary password using the secret key, marks it "must change password", adds the membership, returns the password once | the server only, never the browser | `members.manage` at the company concerned | 4 |
| **Server-only step** `reset member password` | Same checks, new temporary password shown once, forced change again | the server only | `members.manage` | 4 |
| `public.remove_tenant_member` | Removes a member and their assignments. A company administrator: any member with a role in their company (`PLT-D15`) | `authenticated` | `members.manage` at the company concerned | 4 |
| Automatic removal run | Removes members the day after their last working day. Designed in part D | scheduled | | later (`PLT-D14`) |
| Existing: `public.check_permissions`, `private.has_permission`, `private.has_tenant_permission` | Permission checks | as built | | built |

Each public function is `security definer`, revoked from `public, anon, authenticated` first and then granted to `authenticated` and `service_role` (**Existing** pattern). Each checks the caller's permission before it calls a `private` function. The naming convention has no pattern yet for read functions that check a permission. `get_<things>` (`get_my_access`, `get_tenant_members`, `get_my_scope`, `get_access_log`) is added to `HRIS_NAMING_CONVENTION.md` section 4 in Stage 2 (task `PLT-T017`). The exact Supabase admin calls for creating a login and for the forced password change are read from the current Supabase documentation in Stage 4, not assumed here.

New permission code: `members.read`, given to `hr_admin` and `tenant_admin`. Like `members.manage` it applies to neither org unit nor Department scope, so it is checked at company or tenant level (**Existing** behaviour of `012`). `PLT-D18` changes this for `members.manage` only: it must be checkable at Business Unit scope. That needs the org unit flag set on the permission and a level check in the permission check, in a new migration in Stage 2 or 3. `012` and `013` are not edited. The level code is read from `002_hierarchy_levels.sql` (not yet supplied).

### 4.5 Visibility (RLS)
A user sees only their own assignments through the tables (**Existing**, `012`). The administrators' view therefore goes through `public.get_tenant_members` (scoped to the caller as in 4.4) and `public.get_access_log` (tenant-wide administrators only), which check the permission and then read for the caller's tenant. The role tables and the log stay out of `public` (Assumption, same as today).

### 4.6 Public contract
Stable for other modules: `public.check_permissions` (**Existing**, `021`), `public.get_my_access` and `public.get_my_scope` (new). How a module adds permission codes: in its first migration, granted to roles there (**Existing**, Overview 5.7). Every module also adds its read code and enforces it from its first Stage (`PLT-D10`).

### 4.7 Reference and seed data
Roles and permission codes are seeded in `012` (**Existing**). `seed_dev_tenant.sql` stays a dev-only file. After Stage 1 the setup function replaces it for new tenants (Assumption).

### 4.8 Scenario decisions
Part A only. "Does not apply" has its reason.

| Scenario | Applies to | Decision, or "Does not apply: reason" | Build consequence | Stage |
|---|---|---|---|---|
| SC-01 History needed | Role assignments, memberships | No history rows. The access log records who changed what (`PLT-D08`) | Log table and trigger | 2b |
| SC-02 Back-dated entry | Role assignments | Does not apply: an assignment takes effect when saved | none | |
| SC-03 Future-dated entry | Role assignments | Does not apply to assignments. The automatic removal after the last working day is a future-dated effect (`PLT-D14`), driven by the date in `EMP` or `LCY`, built later | none in Stages 1 to 5 | later |
| SC-04 Scheduled runs | Part A | One scheduled run is decided: automatic removal the day after the last working day (`PLT-D14`), designed in part D. Nothing else in part A runs by schedule | Not built in Stages 1 to 5. Follows `DT-8` and `DT-9` | later |
| SC-05 Overlap and gaps | `member_role_scope` | One assignment per member per scope (**Existing**) | Unique key, plain message | 3 |
| SC-06 Correction or change | Assignments | The role may change, the scope never (**Existing**). A wrong scope is removed and added | Guard exists | 3 |
| SC-07 Cancel or reverse | Assignments, logins | Removing is the reversal. No undo. A lost temporary password is reset, not recovered | none | 3, 4 |
| SC-08 Period lock | Part A | Does not apply: no period concept | none | |
| SC-09 Add | Members | An administrator creates the login (`PLT-D09`). Duplicate email in the tenant is refused | Server-only step, unique key | 4 |
| SC-10 Edit | Assignments | Only the role is editable | `change_member_role` | 3 |
| SC-11 Delete | Assignments, members | Hard delete by an authorized administrator (a company administrator: any member with a role in their company, `PLT-D15`), or automatically the day after the last working day (later). The last tenant-wide admin cannot be deleted (**Existing**, `025`). Deletions are logged | `remove_*` wrappers, log trigger | 3, 4 |
| SC-12 Triggers | `member_role_scope`, `tenant_member` | Last admin guard, scope guard and the new access log trigger | Listed in 4.9 | 2b, 3 |
| SC-13 Repeat safety | Setup, assign, automatic removal | Setup run twice creates nothing new. Assigning the same role twice is refused, not duplicated. The automatic removal run is safe to repeat (nothing to remove the second time) | Idempotent setup, unique key | 1, 3 |
| SC-14 Status model | Members | No status. A member is in the tenant or removed (`PLT-D11`) | none | |
| SC-15 Approval | Part A | Does not apply: an administrator acts directly | none | |
| SC-16 Notifications | Login creation | No email in part A. The administrator hands over the temporary password. A skipped automatic removal is shown to tenant administrators on screen (the screen is designed with part D). Other messages wait for part E | none | 4 |
| SC-17 Who acts on whom | All | See section 1.4. Emails visible only inside the caller's scope | Permission checks in the read functions | 2, 3 |
| SC-18 Employee status effects | Members | The last working day from `EMP` or `LCY` drives the automatic removal (`PLT-D14`). Part A provides the removal function. Hiring does not create a login automatically | Contract for `EMP`, `LCY`, part D | later |
| SC-19 Stored or calculated | Part A | Does not apply | none | |
| SC-20 Money, rounding, calendar | Part A | Does not apply | none | |
| SC-21 Reporting needs | Members list, access log | Small lists, search on the page is enough. The log can grow: a date filter and a row limit warning (`lib/limits.ts`) | Filter and limit warning | 2b |
| SC-22 Bulk data | Members | Does not apply in part A (out of scope, 1.5) | none | |
| SC-23 Khmer and calendar | Screens | English interface now, Khmer labels designed in part B (`PLT-D04`). Member names are emails | none | |

### 4.9 Triggers and scheduled runs
| Name | Type | When it fires | What it does | Tables touched | Safe to repeat? | Stage |
|---|---|---|---|---|---|---|
| Last tenant admin guard (`025`, name in the migration) | Trigger | On delete or downgrade of an assignment, or removal of a member or auth user | Refuses if it would leave the tenant without a tenant-wide `tenant_admin`. A whole tenant can be deleted only after the teardown setting (**Existing**) | `member_role_scope`, `tenant_member` | Yes | built, tested (2026-11-07) |
| Scope guard (`012`, `private.member_role_scope_guard`) | Trigger | On insert or update of an assignment | Open target, Department kind, scope fixed | `member_role_scope` | Yes | built |
| Access log trigger (Assumption) | Trigger | After insert, update or delete of an assignment or a membership | Appends one log entry | access log, reads the two tables | Yes (each change logs once) | 2b |
| `private.create_tenant_setup` | Write function | Run by the operator | See 4.4 | `tenant`, `parent_company`, `tenant_member`, `member_role_scope` | Yes | 1 |
| Automatic removal after the last working day | Scheduled run | Once a day shortly after midnight Phnom Penh time (`PLT-D14`) | Removes members whose last working day was before today (Phnom Penh date). Skips, logs and reports what `025` refuses. Disables the login only when the person belongs to no other tenant | `tenant_member`, `member_role_scope`, access log, reads the employee record | Yes | later (part D, `EMP`, `LCY`) |

### 4.10 Date and time rules

Fixed text for all modules (copied from `HRIS_BLUEPRINT_TEMPLATE.md`). Reason: the database server runs on UTC, Phnom Penh is UTC+7. Between 00:00 and 07:00 in Phnom Penh the UTC date is still "yesterday", so any record dated from the server date is one day early. ORG found this late and needed migration `029` and a second clean-up. New modules follow these rules from the first migration.

**Standard rules**

| No. | Rule |
|---|---|
| `DT-1` | The business time zone is `Asia/Phnom_Penh` (UTC+7, no daylight saving). The database server runs on UTC. |
| `DT-2` | A business date (start, end, effective, close, period day) is a `date` and means the Phnom Penh calendar day. |
| `DT-3` | "Today" in SQL comes only from `private.org_today()` (migration `029`, shared by all modules despite the `org_` name). These are **not allowed** anywhere in migrations, function bodies, parameter defaults, column defaults, views or triggers: `current_date`, `current_timestamp::date`, `localtimestamp::date`, `now()::date`. |
| `DT-4` | A write function takes its date as `p_date date default null` and sets `coalesce(p_date, private.org_today())` inside the body. Do not write `default private.org_today()` in the parameter list: a parameter default runs with the caller's rights, and logged-in users have no right to run a private function. |
| `DT-5` | A table has no `default current_date` on a date column. The write function sets `valid_from` and similar columns explicitly. |
| `DT-6` | An instant (created, changed, clock-in) is `timestamptz`, `default now()` is fine. To get its business day, convert: `(ts at time zone 'Asia/Phnom_Penh')::date`. Never cast a `timestamptz` to `date` directly. |
| `DT-7` | Frontend: default date fields with `todayInPhnomPenh()` from `lib/dates.ts` and always pass the date explicitly to the write function. Never use `new Date().toISOString().slice(0, 10)` (it gives the UTC date). Show instants in `Asia/Phnom_Penh`. |
| `DT-8` | Scheduled runs: `pg_cron` runs on UTC, so convert the run time (00:30 in Phnom Penh is 17:30 UTC the day before). The run's "today" is `private.org_today()`. A run must be safe to repeat (see 4.9). |
| `DT-9` | Period boundaries (month start, month end, pay period, leave year) are calculated from Phnom Penh dates, never from UTC dates. |
| `DT-10` | Tests calculate the expected "today" as `(now() at time zone 'Asia/Phnom_Penh')::date` and pass dates explicitly wherever the test is not about the default. A test must not pass only because the UTC and Phnom Penh dates happen to match. |
| `DT-11` | Check before every migration is applied and at the Stage 1 gate: in VS Code (Ctrl+Shift+F, regex on) search the migrations folder for `current_date\|current_timestamp\|localtimestamp\|now\(\)::date`. The only allowed hit is inside `private.org_today()`. |

**Module table (part A)**

| Item | Kind | Value comes from | How it is set (`DT-` rule) | Note |
|---|---|---|---|---|
| Role assignments (`member_role_scope`) | none, no business date | n/a | No dated columns by design (SC-02, SC-03). Only `created_at timestamptz default now()` | Part A adds none |
| Existing tables `001` and `012` (and `013`, `021`) | checked 2026-11-07 | | No `current_date` or date cast. The only date-like defaults are `created_at timestamptz default now()` (instants, allowed by `DT-6`) | Settled, no fix needed |
| Date columns written by `private.create_tenant_setup` | none expected | | The tenancy tables have no business date. If the function writes one, it uses `private.org_today()` explicitly (`DT-3`, `DT-5`) and the Stage 1 test checks it (`DT-10`) | Stage 1 |
| Access log `created_at` | instant | system instant | `timestamptz default now()` (`DT-6`). Shown in `Asia/Phnom_Penh` (`DT-7`). A date filter on the screen converts the chosen Phnom Penh day to an instant range | Stage 2b |
| Automatic removal after the last working day | business date compared with today | the last working day from `EMP` or `LCY` | The run removes members whose last working day is before `private.org_today()` (`DT-3`, `DT-8`, `DT-9`) | Later, with part D |
| Screens "My access" and "Members list" | instant, if one is shown | database | Shown in `Asia/Phnom_Penh` (`DT-7`) | Only if a screen shows when something happened |

---

## 5. Stage plan

| Stage | Capability (a user can...) | Migrations | Frontend | Depends on | Status |
|---|---|---|---|---|---|
| 0 | Setup: decisions recorded, names and date defaults checked (done 2026-11-07), documents aligned, Blueprint approved | none | none | none | Closed (2026-11-07) |
| 1 | An operator creates a tenant, company and first admin without hand SQL | setup function and test | none (the first admin's login is created by the server-only step, built here in its simplest form) | Stage 0 | Passed (2026-11-07) |
| 2 | Any member sees their own access. Administrators see the members their scope covers. The scope selector switches to the user's assigned access | read functions (`get_my_access`, `get_tenant_members`, `get_my_scope`), code `members.read`, test | My access, Members list (read only), scope selector filter | Stage 1, Frontend Foundation, `FND-Q09` | Not started |
| 2b | Every change to a login, a membership or a role is logged. Tenant administrators read the log | access log table, trigger, read function and test | Access log screen | Stage 2 | Not started |
| 3 | An administrator gives, changes and removes a role. A company administrator stays inside their company | role wrappers and test | Member detail, Give role dialog | Stage 2b | Not started |
| 4 | An administrator creates a login and resets its temporary password. The new member sets their own password. An authorized administrator removes a member | member wrapper, server-only steps, tests | Create login dialog, Set new password screen, remove dialog | Stage 3 | Not started |
| 5 | The read rule is written into the platform rules: every module defines and enforces its own read code from its first Stage | none | none (documents only: Overview 5.4 and 5.7, Blueprint template) | Stage 4 | Not started |
| Later | Automatic removal after the last working day | scheduled function and test (part D) | a note on the member detail | `EMP` or `LCY`, part D | Not designed |
| B to E | Designed later, one part at a time (section 1.7) | | | | Not designed |

The Frontend Foundation Stage (`HRIS_FRONTEND_FOUNDATION.md`, steps F0 to F6) runs after Stage 1 and before Stage 2, because Stage 2 is the first screen of this module.

---

## 6. Decisions

Decisions already made and used here are not copied. They are in `HRIS_PROJECT_OVERVIEW.md` sections 5.1 and 5.7: three starting roles, role scope kinds, narrower scope replaces broader, no role history (now replaced from Stage 3 on by `PLT-D08`), reads open to every tenant member for ORG, last tenant-wide admin protected.

| ID | Date | Decision | Origin | Reason | Sections changed |
|---|---|---|---|---|---|
| `PLT-D01` | 2026-11-07 | `PLT` stays one module, designed in parts A to E | Adopted | Parts depend on each other | 1.7, 2 |
| `PLT-D02` | 2026-11-07 | Tenants are created by a platform operator only. No public sign-up | Adopted | Controlled onboarding | 1.2, 2 |
| `PLT-D03` | 2026-11-07 | `tenant_admin` and `hr_admin` see all members and assignments (tenant-wide). Only `tenant_admin` changes them. New code `members.read` for `hr_admin` | Adopted | `hr_admin` needs to see who has access, not change it | 1.4, 4.4 |
| `PLT-D04` | 2026-11-07 | English interface now. Khmer labels and messages are designed in part B. Data names stay bilingual | Adopted | Keeps the first screens small | 4.8, 2 |
| `PLT-D05` | 2026-11-07 | Company-scoped administrators may also manage members and roles, inside their own company. `members.manage` can be held at tenant or company scope. **Replaces** the earlier assumption "tenant-wide only" | Your decision (differs from the recommendation) | Company administrators run their own staff access | 1.1, 1.3, 1.4, 4.4, 4.5 |
| `PLT-D06` | 2026-11-07 | A company administrator may give any role, only at their own company, an org unit or a Department of that company. Never a tenant-wide role, never another company | Adopted | Keeps the reach inside the company | 1.2, 1.4, 3.3 |
| `PLT-D07` | 2026-11-07 | A company administrator sees the members with a role in their company plus members with no role yet | Adopted | They can find new people to give a role to without seeing other companies' staff | 1.2, 1.4, 4.4 |
| `PLT-D08` | 2026-11-07 | A minimal access log is built before Stage 3 (new Stage 2b). Only tenant-wide administrators read it | Adopted | Role changes are security relevant. Early changes cannot be recovered | 1.1, 1.3, 4.2, 4.4, 5 |
| `PLT-D09` | 2026-11-07 | An administrator (tenant-wide or company) creates the login. The system generates a temporary password, shown once. The person must set their own password at first sign-in. No invitation email, no public sign-up. Needs a server-only step with the Supabase secret key | Your decision (the "admin creates the account" option, with the recommended password handling) | | 1.2, 1.3, 3.1, 4.4 |
| `PLT-D10` | 2026-11-07 | Reads stay open to every tenant member for ORG. Every later module defines its own read code and enforces it from its first Stage | Adopted | Removes the blocker on `EMP` without changing ORG | 1.3, 4.6, 5 |
| `PLT-D11` | 2026-11-07 | A member is removed by an authorized administrator, or automatically after their last working day | Your decision (your own wording) | Access should end without relying on someone remembering | 1.2, 1.5, 4.8, 4.9, 5 |
| `PLT-D12` | 2026-11-07 | One tenant per login for now. No tenant switcher | Adopted | Keeps the shell simple | 1.3 |
| `PLT-D13` | 2026-11-07 | Multi-factor sign-in is not planned. Accepted risk, revisit before real staff data is stored in production | Your decision (differs from the recommendation) | | 1.3, 1.5 |
| `PLT-D14` | 2026-11-07 | Automatic removal: the day after the last working day (Phnom Penh date), a daily run shortly after midnight Phnom Penh time, the date from the employee record. If it would remove the last tenant-wide administrator it skips, logs and tells tenant administrators. The login is disabled only when the person belongs to no other tenant. Built later with `EMP`, `LCY`, part D | Adopted | | 1.2, 4.8, 4.9 |
| `PLT-D15` | 2026-11-07 | A company administrator may remove any member who has a role in their company, **including the membership**, even if the member also works in another company (the member then loses access there too). The dialog warns when the member has assignments outside the caller's view | Your decision (differs from the recommendation) | Company administrators own the leaving process of their staff | 1.2, 1.4, 3.1, 3.4, 4.8 |
| `PLT-D16` | 2026-11-07 | A company-scoped `hr_admin` (given `members.read` at company scope) sees the same scoped list as a company administrator, read only | Adopted | | 1.2, 1.4 |
| `PLT-D17` | 2026-11-07 | Manager and employee scopes ("own record", "my team") are designed in `EMP` and `LCY`. The scope guard in `012` stays extensible. Nothing is added to part A | Adopted | "My team" depends on the employee link | 1.4, 1.5, 2 |
| `PLT-D18` | 2026-11-07 | `members.manage` can also be held at **Business Unit** scope, in addition to tenant and company scope. Branch, Division and Department scope never grant it. Recorded from your answer to `Q17`: "Yes for only tenant and business unit" (read as: tenant, company and Business Unit). What a Business Unit administrator may do is `PLT-Q18` | Your decision (differs from the recommendation) | | 1.3, 1.4, 4.4 |

Also decided on 2026-11-07 and used by this module: the Frontend Foundation decisions `FND-D01` to `FND-D08` in `HRIS_FRONTEND_FOUNDATION.md` (work scope selector, route groups, shared folders).

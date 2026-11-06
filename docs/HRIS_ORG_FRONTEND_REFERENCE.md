# HRIS ORG Frontend Reference

Last updated: 2026-11-06
Purpose: Everything the frontend needs to know about the ORG (Organization structure) database: what it can read, what it can write, the rules and errors. Use it instead of reading the migration files.
Read together with: `HRIS_PROJECT_OVERVIEW.md` (shared access model, dates and implementation notes), `HRIS_ORG_STATUS.md`, `HRIS_NAMING_CONVENTION.md`

Covers migrations `002` to `011` (ORG), `014` to `020` and `022` (ORG write wrappers), `023` and `024` (history views), plus `001` where tenancy matters. Migrations `012` and `013` (roles) are covered only where they affect the frontend (sections 8, 9 and 11). All applied on the dev project. Tests for `002` to `013`, `021` and `022` passed. `023` and `024` were checked in the browser (ORG Stage 9i, passed), there is no SQL test file for them. Test results for `014` to `020` are not yet confirmed (see `HRIS_ORG_STATUS.md`). Not reviewed for this document: `000_create_schemas.sql`, the files in `lib/supabase/`, and the definitions of the `023` views (their columns were taken from the generated `database.types.ts`).

---

## 1. Scope and access

- This document covers the ORG module only. Other modules will have their own reference.
- The frontend reads ORG data through **14 views and 4 functions in `public`** (section 3) and writes through **18 `public` write wrappers** (section 8). Every ORG screen is wired: allocation form and headcount grid (ORG Stage 9d), org and position tree screens (9f), jobs and Department listings (9g), hierarchy configuration (9h). The history view (9i) reads the closed views. Role-aware buttons use `public.check_permissions` (section 8.5).
- Every wrapper checks the caller's permission with `private.has_permission` (migrations `012`, `013`). Reads are still open to every tenant member (history included) and are not permission-checked.
- The roles and permission tables are not exposed in `public`. The frontend asks `public.check_permissions` instead (section 8.5, gap G8 closed).
- The shared access model (who can call what, which rows are visible, empty results, secret keys) is in `HRIS_PROJECT_OVERVIEW.md`, section 5.4. Nothing in ORG changes it.

---

## 2. Data model in brief

### Structures
- **Org structure:** Tenant -> Parent Company (called "company" in the API) -> Business Unit -> Branch -> Division. The company is the root and has no unit row.
- **Position structure:** Department -> Office -> Section -> Group, plus a job catalog (job positions) that belongs to Departments.
- The two structures meet only in **allocations**: "this org unit has this job, placed at this position unit, with this approved headcount".

### Levels (global catalog, same for every company)
| Code | Tree | Rank | Name (EN) | Can sit directly under the root | Required |
|---|---|---|---|---|---|
| `business_unit` | org | 1 | Business Unit | yes | no |
| `branch` | org | 2 | Branch | yes | no |
| `division` | org | 3 | Division | yes | no |
| `department` | pos | 1 | Department | yes | **yes** |
| `office` | pos | 2 | Office | no | no |
| `section` | pos | 3 | Section | no | no |
| `group` | pos | 4 | Group | no | no |

Khmer level names (`name_km` in `hierarchy_levels`) are empty for now.

### Company rules (configuration)
- A rule says: "this company allows level X directly under level Y" (or directly under the root when there is no parent level).
- A level can have several rules with different parents. Example: Section under Office **and** Section under Department.
- A parent level must rank higher than its child. A level is "enabled" for a company while at least one open rule exists for it.
- Levels are optional. A company may use only Business Unit, or skip Office, and so on. **No placeholder records exist.** The next enabled level links directly to its real parent.
- **The frontend must build its forms from the rules, never from a fixed list of levels.**
- A rule can block disabling a level without showing anywhere in the tree screens: a level cannot be disabled while another open rule uses it as parent (example: Office, while Section still has an open rule "Under Office"). Disable the child rule first.

### Units and parent links
- Every unit keeps a stable ID for life. Its parent is stored as a dated link, so a reorg closes the old link and opens a new one.
- Org unit with no parent = sits directly under the company.
- Position unit with no parent = a Department (the only level that may be at the top).
- A unit's link points at the rule that allowed it. Later rule changes never touch existing links.

### Eligibility, jobs, allocations
- **Eligibility (Department listing):** which Departments each org unit may use. Listed per org unit. **Not inherited** from the parent org unit.
- **Job position:** a title (for example Architect) that belongs to exactly one Department. Catalog is company-wide.
- **Allocation:** org unit + job + position unit + approved headcount. The job's Department must be listed for the org unit. The position unit is the job's own Department or an open Office, Section or Group anywhere below it.

### Open and closed
- Everything has `valid_from` and `valid_to`. **Open (current) means `valid_to` is empty.** The `*_current` views and all functions in `public` return open rows only (except `parent_companies` and `hierarchy_levels`, which are not dated).
- Closed rows are history. They are read through the `*_closed` views (section 3).
- **Closed records are never re-opened.** Every guard refuses changing a closed record. To bring something back, create it again: enable the level rule again, add the unit or job again (a re-created unit gets a new ID), list the Department again, or create the allocation again.

---

## 3. Read API (`public`)

Call views with `supabase.from('<view>')` and functions with `supabase.rpc('<function>', { ... })`. All ids are integers.

### Views
| View | Columns |
|---|---|
| `parent_companies` | `company_id`, `tenant_id`, `name_en`, `name_km`, `is_active`. Companies in the caller's tenant(s) |
| `hierarchy_levels` | `level_id`, `tree` (`org` or `pos`), `code`, `rank`, `name_en`, `name_km`, `can_be_root`, `is_required`. The global 7-level catalog. Note: column names here are `name_en` / `name_km`, not `level_name_en` / `level_name_km` as in the other views |
| `company_level_rules_current` | `rule_id`, `company_id`, `tree` (`org` or `pos`), `level_id`, `level_code`, `level_rank`, `level_name_en`, `level_name_km`, `parent_level_id` (null = directly under the root), `parent_level_code`, `parent_level_name_en`, `parent_level_name_km`, `valid_from` |
| `org_units_current` | `unit_id`, `company_id`, `level_id`, `level_code`, `level_rank`, `level_name_en`, `level_name_km`, `name_en`, `name_km`, `parent_unit_id` (null = directly under the company), `valid_from` |
| `pos_units_current` | Same columns as `org_units_current`. `parent_unit_id` null = a Department |
| `org_unit_departments_current` | `eligibility_id`, `company_id`, `org_unit_id`, `department_id`, `valid_from` |
| `job_positions_current` | `job_position_id`, `company_id`, `department_id`, `name_en`, `name_km`, `valid_from` |
| `position_allocations_current` | `allocation_id`, `company_id`, `org_unit_id`, `org_unit_name_en`, `org_unit_name_km`, `department_id`, `department_name_en`, `department_name_km`, `job_position_id`, `job_name_en`, `job_name_km`, `pos_unit_id`, `pos_unit_name_en`, `pos_unit_name_km`, `pos_level_code`, `approved_headcount`, `valid_from` |

### Closed (history) views (`023`, `024`)

Closed rows only (`valid_to` is set). Same visibility rules as the `*_current` views (logged-in tenant members, `security_invoker`). The views have no order: sort in the query (`valid_to` descending, then the id). Names are the **current** names of the units and jobs, so a rename also changes them in history. Supabase returns at most 1000 rows per request (not paged yet).

| View | Columns |
|---|---|
| `company_level_rules_closed` | Same columns as `company_level_rules_current` plus `valid_to` |
| `org_units_closed`, `pos_units_closed` | `unit_id`, `company_id`, `level_id`, `level_code`, `level_rank`, `level_name_en`, `level_name_km`, `name_en`, `name_km`, `parent_unit_id`, `parent_name_en`, `parent_name_km` (the parent the unit had when it closed. Null = directly under the company, or a Department), `valid_from`, `valid_to` |
| `job_positions_closed` | `job_position_id`, `company_id`, `department_id`, `department_name_en`, `department_name_km`, `name_en`, `name_km`, `valid_from`, `valid_to` |
| `org_unit_departments_closed` | `eligibility_id`, `company_id`, `org_unit_id`, `org_unit_name_en`, `org_unit_name_km`, `department_id`, `department_name_en`, `department_name_km`, `valid_from`, `valid_to` |
| `position_allocations_closed` | Same columns as `position_allocations_current` plus `valid_to`. A headcount change shows as one closed row holding the old headcount |

Frontend: `fetchClosedRules`, `fetchClosedUnits` (pass `"org"` or `"pos"`), `fetchClosedAllocations`, `fetchClosedJobs`, `fetchClosedListings` in `modules/org/queries.ts`. They skip rows with an empty key column and return newest closed first.

### Functions
| Function | Parameters | Returns (ordered) |
|---|---|---|
| `org_options` | `p_company_id`, `p_parent_unit_id` (optional, null = directly under the company) | `unit_id`, `level_id`, `level_code`, `name_en`, `name_km`. Direct children of that org unit, by level rank then English name |
| `eligible_departments` | `p_company_id`, `p_org_unit_id` | Same columns. Departments listed for that org unit, by English name |
| `pos_options` | `p_company_id`, `p_parent_unit_id` (required) | Same columns. Offices, Sections or Groups directly under that position unit, by level rank then English name. **Top-level Departments do not come from here**, they come from `eligible_departments` |
| `eligible_jobs` | `p_company_id`, `p_org_unit_id`, `p_department_id` | `job_position_id`, `name_en`, `name_km`. Open jobs of that Department, only if the Department is listed for that org unit. Otherwise empty |

Example:
```ts
const { data, error } = await supabase.rpc('org_options', {
  p_company_id: companyId,
  p_parent_unit_id: null, // omit or null for the top level
})
```

Notes:
- One option list can mix levels (for example Business Unit and Branch both directly under the company when the rules allow). Show `level_name_en` or `level_name_km` next to each option.
- Option functions share one return shape so one dropdown component can serve all of them.

---

## 4. Cascading allocation form (how to wire it)

| Step | User picks | Call | Notes |
|---|---|---|---|
| 1 | Company | `parent_companies` view | Needed for every call below |
| 2 | Org location | `org_options(company, null)`, then `org_options(company, picked)` for each deeper level | The user can **stop at any depth**: an allocation may sit at any org unit. Offer "go deeper" only when the next call returns rows |
| 3 | Department | `eligible_departments(company, orgUnit)` | Empty = no Department is listed for this org unit. Show a "not configured" message. Not inherited from the parent |
| 4 | Position unit | Start with the Department itself. Optional: `pos_options(company, current)` repeatedly | The user can stop at any depth. The chosen unit is the Department or anything below it |
| 5 | Job | `eligible_jobs(company, orgUnit, department)` | Only jobs valid for this org unit and Department |
| 6 | Approved headcount | none | Whole number, 0 or more |

Rules for the form:
- When an earlier step changes, **clear every later step**.
- Invalid combinations (a job from a Department the org unit does not list) can never be offered, because each list comes from a function that filters them out.
- Save with `public.create_allocation` (section 8). Before saving, check `position_allocations_current` for an existing allocation with the same org unit, position unit and job. The database rejects a duplicate open allocation (unique index `position_allocation_open_uq`, Postgres error code `23505`).

Implemented in `modules/org/components/AllocationForm.tsx`, using `CascadeSelector`, `AsyncSelect` and the wrappers in `modules/org/queries.ts`. The duplicate check is `fetchExistingAllocation`. Save calls `public.create_allocation` (ORG Stage 9d) and is disabled when the user lacks `org.allocation.write` for the org unit and Department (ORG Stage 9e).

Headcount grid: read `position_allocations_current` filtered by `company_id`. Implemented in `modules/org/components/HeadcountGrid.tsx`. Allocations are never edited. To change a headcount call `public.change_allocation_headcount` (closes the allocation and creates the replacement in one transaction). To remove an allocation call `public.close_allocation`. Closed allocations (including replaced headcounts) are read from `position_allocations_closed` and shown on the Headcount tab under Closed (history) (`ClosedAllocations.tsx`, ORG Stage 9i).

---

## 5. Rules the database enforces

These hold no matter what the frontend sends. Messages are quoted exactly so the frontend can map them. `%` stands for a value inserted by the database. Messages added by the write functions of `014` to `020` are in section 8.

### Company rules (`company_level_rule`)
| Rule | Message |
|---|---|
| A new rule must be open | `A new rule must be open (valid_to must be empty)` |
| A level that cannot be at the root needs a parent level | `Level "%" cannot sit directly under the root` |
| The parent level must be enabled for the company | `The parent level is not enabled for this company` |
| A parent level must rank higher than its child | check constraint (no custom message). `public.enable_level_rule` checks it first, see section 8 |
| One open rule per company + level + parent level | unique index `company_level_rule_open_uq` (code `23505`). `public.enable_level_rule` checks it first, see section 8 |
| Rules are never edited, only closed | `Rules cannot be edited. Close the rule and create a new one` |
| A closed rule cannot change | `A closed rule cannot be changed` |
| Disabling = closing the **last** open rule of a level. Required level | `Level "%" is required and cannot be disabled` |
| Disabling while another open rule uses it as parent | `Other active rules still use level "%" as their parent` |
| Disabling while open units exist at that level | `Level "%" still has active units. Close them before disabling the level` |

Closing one rule while another open rule for the same level remains is allowed. Existing units keep their links.

### Units (`org_unit`, `pos_unit`)
| Rule | Message |
|---|---|
| New unit must be open | `A new org unit must be open (valid_to must be empty)` / `A new position unit must be open (valid_to must be empty)` |
| Level must be enabled for the company | `This level is not enabled for the company` |
| Only names and the end date can change | `Company, level and start date of an org unit cannot be changed` / `... of a position unit cannot be changed` |
| A closed unit cannot change | `A closed org unit cannot be changed` / `A closed position unit cannot be changed` |
| Cannot close a unit that still has open child units | `This unit still has active units under it` |
| Cannot close a Department that still has open jobs | `This Department still has active job positions` |
| Every open unit must end the transaction with an open parent link | `Org unit % must have an open parent link` / `Position unit % must have an open parent link` |

Closing a unit **automatically closes**: its open parent link, its open allocations, and its open eligibility rows (org units and Departments).

### Parent links (`org_unit_parent`, `pos_unit_parent`)
| Rule | Message |
|---|---|
| New link must be open | `A new link must be open (valid_to must be empty)` |
| The unit and the parent must be open | `The unit is closed` / `The parent unit is closed` |
| The rule must be open | `The rule is closed. Use a currently active rule` |
| Links are never edited, only closed | `Links cannot be edited. Close the link and create a new one` |
| A closed link cannot change | `A closed link cannot be changed` |
| Unit, parent and rule must belong to the same company, and the parent's level must match the rule | foreign key errors (code `23503`) |
| One open link per unit | unique index (code `23505`) |

### Job positions (`job_position`)
| Rule | Message |
|---|---|
| New job must be open | `A new job position must be open (valid_to must be empty)` |
| Must belong to an open Department | `A job position must belong to an open Department` |
| Title unique inside its Department while open (exact English name match) | unique index `job_position_open_name_uq` (code `23505`). The job write functions check it first with a clear message, see section 8 |
| Names can change. Company, Department, start date cannot | `Company, department and start date of a job position cannot be changed` |
| A closed job cannot change | `A closed job position cannot be changed` |

Closing a job automatically closes its open allocations.

### Department eligibility (`org_unit_department`)
| Rule | Message |
|---|---|
| New row must be open | `A new eligibility row must be open (valid_to must be empty)` |
| The org unit must be open | `The org unit is closed` |
| Only an open Department can be listed | `Only an open Department can be listed for an org unit` |
| One open row per org unit + Department | unique index `org_unit_department_open_uq` (code `23505`). `public.add_department_listing` checks it first, see section 8 |
| Rows are never edited, only closed | `Eligibility rows cannot be edited. Close the row and create a new one` |
| A closed row cannot change | `A closed eligibility row cannot be changed` |
| Cannot close a listing that allocations still use | `Open allocations still use this Department at this org unit. Close them first` |

### Allocations (`position_allocation`)
| Rule | Message |
|---|---|
| New allocation must be open | `A new allocation must be open (valid_to must be empty)` |
| The org unit must list the job's Department (open eligibility row) | `The org unit no longer lists this Department (eligibility row is closed)`. Different Department or org unit: foreign key error (code `23503`) |
| The job must belong to that Department | foreign key error (code `23503`) |
| The job must be open | `The job position is closed` |
| The position unit must be open | `The position unit is closed` |
| The position unit must be the job's Department or below it | `The position unit is not inside the Department of this job` |
| Headcount is 0 or more | check constraint on `approved_headcount` (code `23514`) |
| One open allocation per org unit + position unit + job | unique index `position_allocation_open_uq` (code `23505`) |
| Allocations are never edited, only closed | `Allocations cannot be edited. Close the allocation and create a new one` |
| A closed allocation cannot change | `A closed allocation cannot be changed` |

---

## 6. What the database does not check (frontend's job)

| Item | Detail |
|---|---|
| Blank names | The write wrappers refuse a missing or blank English name (`The English name is required`). `create_org_unit` and `create_pos_unit` store the name **as sent**, so trim it in the form (`createUnit` does). The rename and job functions trim it themselves |
| Name length | No limit |
| Duplicate unit names | Allowed (two units named the same under one parent). Only job titles are unique, inside a Department |
| Khmer names | `name_km` is optional and not validated. Job functions trim it and store an empty value as null. Language fallback rule is in `HRIS_PROJECT_OVERVIEW.md`, section 5.6. Level names have no Khmer text yet |
| Headcount maximum | None. Only 0 or more, whole number |

---

## 7. Dates in ORG functions

The shared rule (server date is UTC, pass dates explicitly) is in `HRIS_PROJECT_OVERVIEW.md`, section 5.5. ORG specifics:
- Every date parameter of a write wrapper defaults to the server's date (UTC). **Pass the date explicitly from the frontend** when the user picks one.
- Dates the user can choose: allocation start (`create_allocation`), Department listing start (`add_department_listing`), and the close or effective date of every close, reorg and headcount change.
- `create_org_unit`, `create_pos_unit`, `create_job_position` and `enable_level_rule` have no date parameter: the record starts **today by the server's date**. No backdating or future dating is possible through them.
- A start date cannot be earlier than the start of the things the new row depends on. A close or reorg date cannot be earlier than the start of the rows it ends (messages in section 8).
- A future date takes effect immediately, because "current" is defined as an empty `valid_to`. There is no "starts later" state.

---

## 8. Write API

### 8.1 Public wrappers (callable from the frontend)

All are in `public`, `security definer`, granted to `authenticated` and `service_role` only (not `anon`). Each checks the caller's permission, then calls the matching `private` function. Call them with `supabase.rpc('<name>', { ... })`. Parameters with a default can be omitted. All ids are integers. "Today" means the server date (UTC), so pass dates explicitly.

| Wrapper | Parameters (default) | Returns |
|---|---|---|
| `create_allocation` | `p_company_id`, `p_org_unit_id`, `p_job_position_id`, `p_pos_unit_id`, `p_headcount`, `p_start_date` (today) | new allocation id |
| `close_allocation` | `p_company_id`, `p_allocation_id`, `p_close_date` (today) | nothing |
| `change_allocation_headcount` | `p_company_id`, `p_allocation_id`, `p_new_headcount`, `p_effective_date` (today) | new allocation id. Closes the old allocation and opens the replacement on the same date, in one transaction |
| `create_org_unit` | `p_company_id`, `p_level_id`, `p_parent_unit_id` (null = under the company), `p_name_en`, `p_name_km` (null) | new unit id |
| `close_org_unit` | `p_company_id`, `p_unit_id`, `p_close_date` (today) | nothing |
| `reorg_org_unit` | `p_company_id`, `p_unit_id`, `p_new_parent_id` (null = to the company), `p_effective_date` (today) | nothing |
| `create_pos_unit` | `p_company_id`, `p_level_id`, `p_parent_unit_id` (null = a new Department), `p_name_en`, `p_name_km` (null) | new unit id |
| `close_pos_unit` | `p_company_id`, `p_unit_id`, `p_close_date` (today) | nothing |
| `reorg_pos_unit` | `p_company_id`, `p_unit_id`, `p_new_parent_id` (null = to the top), `p_effective_date` (today) | nothing |
| `rename_org_unit` | `p_company_id`, `p_unit_id`, `p_name_en`, `p_name_km` (null) | nothing. Replaces both names (trimmed), an empty Khmer name clears it |
| `rename_pos_unit` | `p_company_id`, `p_unit_id`, `p_name_en`, `p_name_km` (null) | nothing. Same as `rename_org_unit` |
| `create_job_position` | `p_company_id`, `p_department_id`, `p_name_en`, `p_name_km` (null) | new job id |
| `rename_job_position` | `p_company_id`, `p_job_id`, `p_name_en`, `p_name_km` (null) | nothing. Replaces both names, an empty Khmer name clears it |
| `close_job_position` | `p_company_id`, `p_job_id`, `p_close_date` (today) | nothing. Also closes the job's open allocations |
| `add_department_listing` | `p_company_id`, `p_org_unit_id`, `p_department_id`, `p_start_date` (today) | new listing (eligibility) id |
| `remove_department_listing` | `p_company_id`, `p_org_unit_id`, `p_department_id`, `p_close_date` (today) | nothing. A listing is found by org unit + Department, not by its id |
| `enable_level_rule` | `p_company_id`, `p_level_id`, `p_parent_level_id` (null = directly under the root) | new rule id |
| `disable_level_rule` | `p_company_id`, `p_rule_id`, `p_close_date` (today) | nothing. Needs the rule id from `company_level_rules_current` |

Example:
```ts
const { data: newId, error } = await supabase.rpc('create_allocation', {
  p_company_id: companyId,
  p_org_unit_id: orgUnitId,
  p_job_position_id: jobId,
  p_pos_unit_id: posUnitId,
  p_headcount: 5,
  p_start_date: '2026-11-06', // pass the date the user picked
})
```

### 8.2 Permission each wrapper checks

Each wrapper calls `private.has_permission(company, code, org unit, Department)`. Resolution rules (narrow scope replaces broad, restrictions win) are in `HRIS_ORG_STATUS.md`, section 3. When no org unit or Department is passed, only a company-wide or tenant-wide assignment can pass. All three starting roles: `tenant_admin` and `hr_admin` hold every ORG write code, `viewer` holds none.

| Wrapper | Permission code | Checked at |
|---|---|---|
| `create_allocation`, `close_allocation`, `change_allocation_headcount` | `org.allocation.write` | the allocation's org unit and the job's Department |
| `create_org_unit` | `org.unit.write` | the parent unit (a role on a unit covers its subtree). No parent: company or tenant-wide role only |
| `close_org_unit` | `org.unit.write` | the unit |
| `reorg_org_unit` | `org.unit.write` | the unit **and** the new parent. To the company (no parent): company or tenant-wide role only |
| `create_pos_unit` | `pos.unit.write` | the Department of the parent unit. A new Department (no parent): company or tenant-wide role only |
| `close_pos_unit` | `pos.unit.write` | the unit's Department. Closing a Department itself: company or tenant-wide role only |
| `reorg_pos_unit` | `pos.unit.write` | the unit (same rule as `close_pos_unit`) **and** the Department of the new parent. To the top: company or tenant-wide role only. Departments cannot move |
| `rename_org_unit` | `org.unit.write` | the unit |
| `rename_pos_unit` | `pos.unit.write` | the unit's Department (same rule as `close_pos_unit`). Renaming a Department itself: company or tenant-wide role only |
| `create_job_position`, `rename_job_position`, `close_job_position` | `pos.job.write` | the job's Department |
| `add_department_listing`, `remove_department_listing` | `org.eligibility.write` | the org unit (a Branch role covers its Divisions). Department-scoped roles have no say |
| `enable_level_rule`, `disable_level_rule` | `org.config.write` | company or tenant level only. Org unit and Department roles never pass |

### 8.3 Errors from the wrappers

- **No permission:** Postgres error code `42501` with one fixed message per area. Map the **code**, not the text. A caller who is not a member of the company's tenant gets the same error, so a non-member learns nothing about what exists.
- **Everything else** is a plain error (code `P0001`) with the message below. A tenant member naming something that is not open in the company gets a plain message. Permission is checked after that existence check, so a member can see "not an open ..." for something they may not manage.

| Area | No-permission message (code `42501`) |
|---|---|
| Allocations | `You do not have permission to manage allocations here` |
| Org units | `You do not have permission to manage org units here` |
| Position units | `You do not have permission to manage position units here` |
| Job positions | `You do not have permission to manage job positions here` |
| Department listings | `You do not have permission to manage Department listings here` |
| Hierarchy rules | `You do not have permission to change hierarchy rules here` |

Messages the wrappers and `private` functions can raise (besides the rules in section 5):

| Area | Messages |
|---|---|
| Allocations | `Allocation % is not an open allocation of this company`, `This job position is not offered at this org unit`, `Start date % is earlier than %, when the org unit, listing, job or position unit started`, `Close date % is earlier than %, when this allocation started`, `The new headcount is the same as the current headcount` |
| Org units | `Parent unit % is not an open unit of this company`, `Org unit % is not an open unit of this company`, `New parent % is not an open unit of this company`, `The English name is required`, plus create, close and reorg messages below |
| Position units | Same as org units with `Position unit % is not an open unit of this company`, plus create, close and reorg messages below |
| Job positions | `Department % is not an open Department of this company`, `Job position % is not an open job position of this company`, `The English name is required`, `A job position named "%" already exists in this Department`, `Close date % is earlier than %, when this job or an allocation of it started` |
| Department listings | `Org unit % is not an open unit of this company`, `Department % is not an open Department of this company`, `Department % is already listed for org unit %`, `Department % is not listed for org unit %`, `Start date % is earlier than %, when the org unit or Department started or a previous listing ended`, `Close date % is earlier than %, when this listing started`, and `Open allocations still use this Department at this org unit. Close them first` |
| Hierarchy rules, enable | `Company % not found`, `Level % does not exist`, `The parent level must be in the same tree as the level`, `A parent level must be higher up than its child level`, `This rule is already enabled for the company`. The guard still decides `Level "%" cannot sit directly under the root` and `The parent level is not enabled for this company` |
| Hierarchy rules, disable | `Rule % is not an open rule of this company` (members only, non-members get `42501`), `Close date % is earlier than %, when this rule started`. The guard still decides the three disable messages in section 5 |

Create, close and reorg messages from the private functions (unchanged):
- `create_org_unit`, `create_pos_unit`: `Parent unit % is not an open unit of this company`, `No active rule allows this level under this parent`.
- `rename_org_unit`, `rename_pos_unit`: `Org unit % is not an open unit of this company` / `Position unit % is not an open unit of this company`, `The English name is required`.
- `close_org_unit`: `Org unit % is not an open unit of this company`, `Close date % is earlier than %, when this unit or something under it started`, plus the unit messages in section 5. `close_pos_unit` is the same with `Position unit % ...`.
- Reorg:
  - `Org unit % is not an open unit of this company` / `Position unit % is not an open unit of this company`
  - `The unit is already under this parent`
  - `Effective date % is earlier than %, when the current parent link started`
  - `New parent % is not an open unit of this company`
  - `Effective date % is earlier than %, when the new parent started`
  - `No active rule allows this level under this parent` (also what you get when trying to move a Department, or to move a unit under itself or one of its own descendants)
  - `Open allocations sit at this unit or under it. Close them before moving it to another Department` (position tree only. Moving inside the same Department is allowed)

Reorg keeps eligibility rows and allocations attached to the unit. It does not rewrite them.

### 8.4 Private functions (not callable from the frontend)

`service_role` only. They are what the wrappers call. Argument order matches the wrapper without the permission check.

| Function | Added in | Note |
|---|---|---|
| `create_org_unit`, `create_pos_unit` | `003`, `004` | Find the matching open rule themselves |
| `create_allocation` | `006`, **replaced in `015`** | New `p_start_date` argument (default today). The old 5-argument form was dropped, 5-argument calls still work because of the default |
| `close_org_unit`, `close_pos_unit` | `008` | Closing cascades (section 5) |
| `reorg_org_unit`, `reorg_pos_unit`, `pos_department_of` | `009` | |
| `close_allocation` | `014` | |
| `create_job_position`, `rename_job_position`, `close_job_position` | `018` | |
| `add_department_listing`, `remove_department_listing` | `019` | |
| `enable_level_rule`, `disable_level_rule` | `020` | |
| `is_company_member` | `016` | True when the caller belongs to the company's tenant. Used by the wrappers to choose between a plain message and no hint |
| `rename_org_unit`, `rename_pos_unit` | `022` | Trim both names. English name required |
| `can_manage_pos_unit` | `017` | The "may the caller change this unit itself" rule shared by `close_pos_unit` and `reorg_pos_unit` |

### 8.5 Permission check for the frontend (`check_permissions`, migration `021`)

`public.check_permissions(p_company_id, p_permission_code, p_targets)` returns `org_unit_id`, `department_id`, `allowed` for each distinct target. `p_targets` is a JSON array of `{org_unit_id, department_id}` (either key can be missing or null, default is one empty target, at most 500 per call). It calls the same `private.has_permission` as the wrappers. A caller who is not logged in or not a member gets `allowed = false` for everything. It only hides what would fail, the wrappers still check on every write.

Which key matters per code: `org.allocation.write` org unit and Department; `org.unit.write` and `org.eligibility.write` org unit; `pos.unit.write` and `pos.job.write` Department; `org.config.write` none.

Frontend helper: `modules/org/permissions.ts`.
```ts
const perm = usePermissions(companyId, PERM_ALLOCATION_WRITE, [{ orgUnitId, departmentId }]);
perm.can(orgUnitId, departmentId); // false until the answer arrives
perm.isLoading;
```
Pass all targets of a screen in one call (the headcount grid does this for every row). Add a constant per permission code when a screen needs it.

### 8.6 Write functions that do not exist yet
| Needed by | Missing function |
|---|---|
| Setup | Create tenant, company and tenant membership (dev data was seeded by hand, see `HRIS_ORG_STATUS.md`, section 4) |
| Members screen | Give and remove roles (no function or screen yet) |

---

## 9. Known gaps

| # | Gap | Effect | Planned fix |
|---|---|---|---|
| G1 | ~~No read object for parent companies or tenants~~ | **Closed** by migration `011`: `public.parent_companies` | none |
| G2 | ~~No read object for the level catalog~~ | **Closed** by migration `011`: `public.hierarchy_levels` | none |
| G3 | ~~No `public` write functions~~ | **Closed** by migrations `015` to `020` (and `014`) and `022`: section 8. All screens are wired (ORG Stages 9d, 9f, 9g, 9h) | none |
| G4 | ~~Missing write functions~~ | **Mostly closed** by `014`, `018`, `019`, `020`, `022`. Still missing: tenant/company/membership setup, role management (section 8.6) | New migrations when a screen needs them |
| G5 | ~~No roles or permissions~~ | **Closed for writes** by `012`, `013` and the wrappers: every wrapper calls `private.has_permission`. Reads stay open to every tenant member. Shared topic, see `HRIS_PROJECT_OVERVIEW.md`, section 5.7 | none |
| G6 | ~~No history views~~ | **Closed** by migrations `023` and `024` (ORG Stage 9i): closed rules, units, jobs, Department listings and allocations (section 3). Not provided: the past parent links of units that are still open (reorg history) and "as of date" reads | Add if a screen needs them |
| G7 | Khmer level names empty | Level labels show English only | Seed migration (ORG Stage 2b, skipped for now) |
| G8 | ~~No read object for the caller's own permissions~~ | **Closed** by migration `021` (`public.check_permissions`, section 8.5) and `modules/org/permissions.ts`. Allocation form and headcount grid use it | none |
| G9 | History lists and the headcount grid are not paged | Supabase returns at most 1000 rows per request, so a list or total would be too low beyond that | Add paging when real data volume is known |

---

## 10. Implementation notes (ORG)

Shared notes (generated types, `cacheComponents`, language fallback) are in `HRIS_PROJECT_OVERVIEW.md`, section 5.6. ORG specifics:
- **Do not hard-code levels:** read `company_level_rules_current` to know which levels exist for a company and what sits under what.
- **Label mixed lists:** an option list may contain several levels. Show the level name beside each option.
- **Cache keys:** include the company id (and the parent unit id for cascades).
- **Empty lists:** show a reason ("no Departments listed for this org unit") instead of an empty dropdown.
- **Reusable pieces:** `AsyncSelect` and `CascadeSelector` load their own options. Pass them a memoised (`useCallback`) loader, and give them a `key` that includes whatever they depend on (company, parent choice) so they reset.
- **Units for trees:** `app/page.tsx` loads `org_units_current` and `pos_units_current` for all visible companies and the browser filters by company. Revisit if a tenant ever has many thousands of units.
- **Allocations for the headcount grid:** `app/page.tsx` loads `position_allocations_current` for all visible companies without paging. Supabase returns at most 1000 rows per request by default, so the grid and its total would be too low beyond that. Revisit when real data volume is known.
- **Calling a wrapper:** `error.code === '42501'` means no permission. Show a fixed "you do not have permission" message. Show the database message for other errors (they are written for users), and refresh the lists after a successful write because views return only open rows.
- **Passing null:** `p_parent_unit_id`, `p_new_parent_id` have no default. Send `null` explicitly for "under the company" or "top of the tree". The generated types say `number`, so `queries.ts` casts (`value as number`).
- **Unit management (ORG Stage 9f):** `OrgTreeExplorer` takes an optional `manage` prop (tree, company, levels, the company's rules). Without it the tree is read-only. The levels offered for a new unit and the places a unit can move to come from the open rules (`modules/org/unitTree.ts`), never from a fixed list. Where each permission is checked: org tree at the unit. Position tree at the unit's Department. A Department itself and a new top-level unit use an empty target (company-wide or tenant-wide role). Add, rename, move and close all go through `createUnit`, `renameUnit`, `reorgUnit`, `closeUnit` in `queries.ts` (pass `"org"` or `"pos"`).
- **Jobs, listings and level rules (ORG Stages 9g, 9h):** the Jobs tab, Department listings tab and Configuration tab load their open rows with `fetchJobs`, `fetchListings` and the rules passed from `app/page.tsx`, reload after each save and call `router.refresh()`. Jobs check `pos.job.write` at the Department, listings check `org.eligibility.write` at the org unit, level rules check `org.config.write` with one empty target. The enable and disable forms offer only valid choices, and show the database guard message when a disable is refused.
- **History (ORG Stage 9i):** six tabs (Configuration, Org tree, Position tree, Jobs, Department listings, Headcount) have a Current / Closed (history) toggle (`HistoryToggle.tsx` in `OrgConfigView.tsx`). Closed shows `ClosedRules`, `ClosedUnits`, `ClosedJobs`, `ClosedListings` or `ClosedAllocations`, each loading its own rows with the matching `fetchClosed*` function, keyed by company. History is read-only, there is no re-open (section 2). Closed names are the current names. The toggle returns to Current when the tab changes.
- **A level that will not disable:** the blocker is usually an open rule that uses the level as parent, not a unit. Check `company_level_rules_current` for rules whose `parent_level_id` is that level.

---

## 11. Source map (only open these for specific details)

| Topic | File |
|---|---|
| Tenancy, tenant helper, row level security pattern | `001_tenancy.sql` |
| Level catalog, seeded levels, company rule table | `002_hierarchy_levels.sql` (the `parent_level_key` column is added in `003`) |
| Latest rule guard (what blocks disabling a level) | `007_level_disable_guard.sql` |
| Org tree, parent links, deferred link check, `create_org_unit` | `003_org_tree.sql` |
| Position tree, `create_pos_unit` | `004_position_tree.sql` |
| Job positions, Department eligibility | `005_jobs_and_eligibility.sql` |
| Allocation table and guard, **latest** unit, job and eligibility guards | `006_allocation.sql` |
| Close functions | `008_close_unit.sql` |
| Reorg functions | `009_reorg.sql` |
| Public views (current), read functions, privileges | `010_read_layer.sql` |
| `parent_companies` and `hierarchy_levels` views | `011_catalog_read_views.sql` |
| Roles, permission codes, role scope, scope guard | `012_roles.sql` |
| Permission check (`has_permission`, `has_tenant_permission`) | `013_has_permission.sql` |
| `private.close_allocation` | `014_close_allocation.sql` |
| **Latest** `private.create_allocation`, allocation wrappers | `015_allocation_wrappers.sql` |
| Org unit wrappers, `private.is_company_member` | `016_org_unit_wrappers.sql` |
| Position unit wrappers, `private.can_manage_pos_unit` | `017_pos_unit_wrappers.sql` |
| Job position functions and wrappers | `018_job_position_functions.sql` |
| Department listing functions and wrappers | `019_department_listing_functions.sql` |
| Level rule functions and wrappers | `020_level_rule_functions.sql` |
| `public.check_permissions` | `021_permission_check.sql` |
| Rename unit functions and wrappers | `022_rename_unit.sql` |
| Closed views for rules and units | `023` (file name not recorded) |
| Closed views for jobs, Department listings and allocations | `024_history_views_jobs_listings_allocations.sql` |
| Behaviour proven by tests | `supabase/tests/` (`009_010_reorg_read_layer_test.sql` for reorg and the read layer, `012_roles_test.sql` and `013_has_permission_test.sql` for roles, `014_close_allocation_test.sql`, `015_allocation_wrappers_test.sql` and `016_020_wrappers_test.sql` for the write functions and wrappers, `021_permission_check_test.sql`, `022_rename_unit_test.sql`) |

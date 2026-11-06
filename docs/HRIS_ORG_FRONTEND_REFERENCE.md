# HRIS ORG Frontend Reference

Last updated: 2026-11-06
Purpose: Everything the frontend needs to know about the ORG (Organization structure) database: what it can read, what it cannot do yet, the rules and errors. Use it instead of reading the migration files.
Read together with: `HRIS_PROJECT_OVERVIEW.md` (shared access model, dates and implementation notes), `HRIS_ORG_STATUS.md`, `HRIS_NAMING_CONVENTION.md`

Covers migrations `002` to `011` (ORG), plus `001` where tenancy matters. All applied and tested on the dev project. Not reviewed for this document: `000_create_schemas.sql` and the files in `lib/supabase/`.

---

## 1. Scope and access

- This document covers the ORG module only. Other modules will have their own reference.
- The frontend reads ORG data through **8 views and 4 functions in `public`** (section 3). It cannot write anything yet (section 8).
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

### Units and parent links
- Every unit keeps a stable ID for life. Its parent is stored as a dated link, so a reorg closes the old link and opens a new one.
- Org unit with no parent = sits directly under the company.
- Position unit with no parent = a Department (the only level that may be at the top).
- A unit's link points at the rule that allowed it. Later rule changes never touch existing links.

### Eligibility, jobs, allocations
- **Eligibility:** which Departments each org unit may use. Listed per org unit. **Not inherited** from the parent org unit.
- **Job position:** a title (for example Architect) that belongs to exactly one Department. Catalog is company-wide.
- **Allocation:** org unit + job + position unit + approved headcount. The job's Department must be listed for the org unit. The position unit is the job's own Department or an open Office, Section or Group anywhere below it.

### Open and closed
- Everything has `valid_from` and `valid_to`. **Open (current) means `valid_to` is empty.** All views and functions in `public` return open rows only (except `parent_companies` and `hierarchy_levels`, which are not dated).
- Closed rows are history. They cannot be read through `public` yet (see section 9).

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
- Before saving (when the write function exists), check `position_allocations_current` for an existing allocation with the same org unit, position unit and job. The database rejects a duplicate open allocation (unique index `position_allocation_open_uq`, Postgres error code `23505`).

Implemented (read-only, save disabled) in `modules/org/components/AllocationForm.tsx`, using `CascadeSelector`, `AsyncSelect` and the wrappers in `modules/org/queries.ts`. The duplicate check is `fetchExistingAllocation`.

Headcount grid: read `position_allocations_current` filtered by `company_id`. Changing a headcount means closing the allocation and creating a new one (allocations are never edited).

---

## 5. Rules the database enforces

These hold no matter what the frontend sends. Messages are quoted exactly so the frontend can map them. `%` stands for a value inserted by the database.

### Company rules (`company_level_rule`)
| Rule | Message |
|---|---|
| A new rule must be open | `A new rule must be open (valid_to must be empty)` |
| A level that cannot be at the root needs a parent level | `Level "%" cannot sit directly under the root` |
| The parent level must be enabled for the company | `The parent level is not enabled for this company` |
| A parent level must rank higher than its child | check constraint (no custom message) |
| One open rule per company + level + parent level | unique index `company_level_rule_open_uq` (code `23505`) |
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
| Title unique inside its Department while open (exact English name match) | unique index `job_position_open_name_uq` (code `23505`) |
| Names can change. Company, Department, start date cannot | `Company, department and start date of a job position cannot be changed` |
| A closed job cannot change | `A closed job position cannot be changed` |

Closing a job automatically closes its open allocations.

### Department eligibility (`org_unit_department`)
| Rule | Message |
|---|---|
| New row must be open | `A new eligibility row must be open (valid_to must be empty)` |
| The org unit must be open | `The org unit is closed` |
| Only an open Department can be listed | `Only an open Department can be listed for an org unit` |
| One open row per org unit + Department | unique index `org_unit_department_open_uq` (code `23505`) |
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
| Blank names | `name_en` must be present, but an empty or whitespace-only string is accepted. Validate and trim in the form |
| Name length | No limit |
| Duplicate unit names | Allowed (two units named the same under one parent). Only job titles are unique, inside a Department |
| Khmer names | `name_km` is optional and not validated. Language fallback rule is in `HRIS_PROJECT_OVERVIEW.md`, section 5.6. Level names have no Khmer text yet |
| Headcount maximum | None. Only 0 or more, whole number |

---

## 7. Dates in ORG functions

The shared rule (server date is UTC, pass dates explicitly) is in `HRIS_PROJECT_OVERVIEW.md`, section 5.5. ORG specifics:
- Create functions always start a record **today by the server's date**. No backdating or future dating is possible through them.
- Close and reorg functions take a date parameter (default today). **Pass the date explicitly from the frontend** when the user picks one.
- A future date takes effect immediately, because "current" is defined as an empty `valid_to`. There is no "starts later" state.
- A close or reorg date cannot be earlier than the start of the rows it ends (see messages in section 8).

---

## 8. Write functions

All are in `private`, executable by `service_role` only. **None is callable from the frontend yet.** They show what the future frontend write functions will wrap.

| Function | Arguments | What it does | Messages it can raise |
|---|---|---|---|
| `create_org_unit` | `company, level, parent (null = under the company), name_en, name_km` | Creates the unit and its link, finding the matching open rule itself. Returns the new id | `Parent unit % is not an open unit of this company`, `No active rule allows this level under this parent` |
| `create_pos_unit` | Same | Same, for the position tree | Same two messages |
| `create_allocation` | `company, org_unit, job_position, pos_unit, headcount` | Finds the matching open eligibility row, creates the allocation. Returns the new id | `This job position is not offered at this org unit`, plus allocation messages in section 5 |
| `close_org_unit` | `company, unit, close_date` | Closes an open unit (cascades in section 5) | `Org unit % is not an open unit of this company`, `Close date % is earlier than %, when this unit or something under it started`, plus unit messages in section 5 |
| `close_pos_unit` | Same | Same, for the position tree | `Position unit % is not an open unit of this company`, same date message |
| `reorg_org_unit` | `company, unit, new_parent (null = to the company), effective_date` | Moves a unit and everything under it. Unit id stays. Old link closes, new link opens | See below |
| `reorg_pos_unit` | Same | Same, for Office, Section, Group | See below |

Reorg messages:
- `Org unit % is not an open unit of this company` / `Position unit % is not an open unit of this company`
- `The unit is already under this parent`
- `Effective date % is earlier than %, when the current parent link started`
- `New parent % is not an open unit of this company`
- `Effective date % is earlier than %, when the new parent started`
- `No active rule allows this level under this parent` (also what you get when trying to move a Department, or to move a unit under itself or one of its own descendants)
- `Open allocations sit at this unit or under it. Close them before moving it to another Department` (position tree only. Moving inside the same Department is allowed)

Reorg keeps eligibility rows and allocations attached to the unit. It does not rewrite them.

### Write functions that do not exist yet
| Needed by | Missing function |
|---|---|
| Config screen | Create and close company level rules (enable and disable a level) |
| Job catalog screen | Create a job position, rename it, close it |
| Eligibility screen | List a Department for an org unit, remove a listing |
| Headcount grid | Close a single allocation (needed to change a headcount) |
| Names | Rename a unit |
| Setup | Create tenant, company and tenant membership (dev data was seeded by hand, see `HRIS_ORG_STATUS.md`, section 4) |

---

## 9. Known gaps before ORG frontend screens can be built

| # | Gap | Effect | Planned fix |
|---|---|---|---|
| G1 | ~~No read object for parent companies or tenants~~ | **Closed** by migration `011`: `public.parent_companies` | none |
| G2 | ~~No read object for the level catalog~~ | **Closed** by migration `011`: `public.hierarchy_levels` | none |
| G3 | No `public` write functions | Nothing can be saved from the frontend | Wrappers over the `private` write functions, each with explicit `revoke` and `grant`, designed with roles |
| G4 | Missing write functions (section 8) | Config, jobs, eligibility and headcount screens cannot save | New migrations, one area at a time |
| G5 | No roles or permissions | Every tenant member sees everything and (later) could write everything | Design before G3. Shared topic, see `HRIS_PROJECT_OVERVIEW.md` |
| G6 | No history views | Closed rows, reorg history and "as of date" cannot be read | Add when a screen needs them |
| G7 | Khmer level names empty | Level labels show English only | Seed migration (ORG Stage 2b, skipped for now) |

---

## 10. Implementation notes (ORG)

Shared notes (generated types, `cacheComponents`, language fallback) are in `HRIS_PROJECT_OVERVIEW.md`, section 5.6. ORG specifics:
- **Do not hard-code levels:** read `company_level_rules_current` to know which levels exist for a company and what sits under what.
- **Label mixed lists:** an option list may contain several levels. Show the level name beside each option.
- **Cache keys:** include the company id (and the parent unit id for cascades).
- **Empty lists:** show a reason ("no Departments listed for this org unit") instead of an empty dropdown.
- **Reusable pieces:** `AsyncSelect` and `CascadeSelector` load their own options. Pass them a memoised (`useCallback`) loader, and give them a `key` that includes whatever they depend on (company, parent choice) so they reset.
- **Units for trees:** `app/page.tsx` loads `org_units_current` and `pos_units_current` for all visible companies and the browser filters by company. Revisit if a tenant ever has many thousands of units.

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
| Allocation table and guard, `create_allocation`, **latest** unit, job and eligibility guards | `006_allocation.sql` |
| Close functions | `008_close_unit.sql` |
| Reorg functions | `009_reorg.sql` |
| Public views, read functions, privileges | `010_read_layer.sql` |
| `parent_companies` and `hierarchy_levels` views | `011_catalog_read_views.sql` |
| Behaviour proven by tests | `supabase/tests/` (`009_010_reorg_read_layer_test.sql` for reorg and the read layer) |

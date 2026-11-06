# HRIS Naming Convention

Last updated: 2026-11-06
Purpose: One place that says how project documents, modules, stages, migrations, tests and database objects are named, so a name alone tells you what a file or object is and which module it belongs to.
Read together with: `HRIS_PROJECT_OVERVIEW.md`

Status of this convention:
- Sections 1 to 4 are in use today (documents and modules are new, the rest was observed in migrations `001` to `010`).
- Section 5 (frontend code naming) is **not defined yet**. It is to be agreed at the start of ORG Stage 8.

---

## 1. Modules and stages

| Item | Rule |
|---|---|
| Module | One area of the HRIS built in its own set of stages (for example Organization structure) |
| Module code | Short uppercase code, listed in the module register of `HRIS_PROJECT_OVERVIEW.md`. Today: `ORG` |
| Stage | A small step inside one module, numbered from 0 (`ORG Stage 6c`). Stages restart at 0 for every module |
| Talking about work | Always `<MODULE> Stage N` or "migration NNN" (for example "ORG Stage 6c" or "migration 009"). Never a bare "stage 5" |

Migration headers written before modules existed say "roadmap Stage X". That always means the ORG module. Applied migrations are not edited.

---

## 2. Project documents

Two kinds of document.

| Kind | File name | Example |
|---|---|---|
| Project document (shared by all modules) | `HRIS_<TOPIC>.md` | `HRIS_PROJECT_OVERVIEW.md` |
| Module document | `HRIS_<MODULE>_<TOPIC>.md` | `HRIS_ORG_STATUS.md` |

| Item | Rule |
|---|---|
| Location | `docs/` folder at the project root |
| File name | Uppercase, underscores, no spaces. Topic is a short noun phrase |
| Not in the file name | Dates, versions, stage numbers. The `Last updated` line and git history carry that |
| Dates | ISO format `YYYY-MM-DD` |

### Standard documents
| File | Answers | Update when |
|---|---|---|
| `HRIS_PROJECT_OVERVIEW.md` | Modules and their state, shared technical setup and conventions, how to resume | A module is added or changes state, or a shared rule changes |
| `HRIS_NAMING_CONVENTION.md` | How things are named | A new naming pattern is introduced |
| `HRIS_<MODULE>_STATUS.md` | Where that module is: scope, requirements, decisions, what has been created, stages, open items | Every time a stage of that module passes |
| `HRIS_<MODULE>_FRONTEND_REFERENCE.md` | What the frontend can read and write for that module, rules enforced, error messages, known gaps, where to look in code. Created when the module's database is ready for a frontend | Any change to a `public` object, guard, trigger or write function of that module |

Add another document only when a topic needs more than a section in an existing one.

### Where a fact belongs
- Used by every module (setup, tenancy, access model, shared conventions): `HRIS_PROJECT_OVERVIEW.md`.
- Used by one module: that module's documents. Do not repeat it in the overview.
- A fact lives in one place. Other documents point to it.

### Header block (first lines of every document)
```
# <Title>

Last updated: YYYY-MM-DD
Purpose: <one sentence: the question this document answers>
Read together with: <other documents, if any>
```

### Style
- State facts, decisions and rules in tables or short lists. Do not paste code. Point to the migration file for details.
- Exact error messages may be quoted, because the frontend will map them.
- Label the origin of a statement: **Your decisions** (made by you), **Adopted** (Claude's recommendation you accepted), **Assumption** (not confirmed yet).
- Documents cover what the files contain. Anything not reviewed is named as not reviewed.

### Keeping documents true
- If a document and a migration disagree, **the migration wins**. Fix the document in the same session.
- A function that is replaced in a later migration is listed under "Current versions of replaced functions" in the owning module's status document.

---

## 3. Migrations, tests, seeds

Migrations form **one chain shared by all modules**. A module's status document lists which migrations belong to it.

| Item | Rule | Example |
|---|---|---|
| Migration | `supabase/migrations/NNN_description.sql`. Three digits, sequential from `000`, no gaps. Description is lowercase snake_case and says what the file contains. No word "stage" | `009_reorg.sql` |
| Test | `supabase/tests/NNN_description_test.sql`, same `NNN` and description as its migration | `001_tenancy_test.sql` |
| Combined test | `NNN_MMM_description_test.sql`, first and last migration number covered | `009_010_reorg_read_layer_test.sql` |
| Seed | Kept separate from schema migrations. Location and name are **not defined yet**. Define when the first seed file is created (the Khmer level names, ORG Stage 2b) | |

### Migration header (first comment lines)
- Line 1: `-- NNN: short title (<MODULE> Stage X)`. Migrations `000` and `001` are shared platform files and have no module.
- Then what the file adds, and any special behaviour.
- If it replaces a function from an earlier migration, say which function and which migration held the previous version.

### Tests
- Plain SQL, pasted into the Supabase Dashboard SQL Editor on the dev project only.
- Each test rolls back at the end. "Success. No rows returned" is a pass. An error starting with `FAIL:` names the failed check.

---

## 4. Database objects

### Schemas
| Schema | Holds | Exposed to the frontend |
|---|---|---|
| `core` | Business tables | No |
| `private` | Guard, helper and write functions | No |
| `public` | Read views and read functions | Yes, read-only, logged-in users only |

### Tables and columns (`core`)
| Item | Rule | Example |
|---|---|---|
| Table | Singular, lowercase snake_case | `org_unit`, `job_position` |
| Table prefix | Not fixed across modules. ORG uses `org_` and `pos_` for its two trees. When a new module starts, agree its prefix in its first migration and record it here | `org_unit`, `pos_unit` |
| Parent link table | `<node table>_parent` | `org_unit_parent` |
| Primary key | `id integer generated always as identity` | |
| Foreign key column | `<thing>_id` | `company_id`, `department_id` |
| Bilingual names | `name_en` (required), `name_km` (optional) | |
| Validity | `valid_from date`, `valid_to date`. `valid_to is null` means open (current) | |
| Audit | `created_at timestamptz` | |
| Composite key targets | `unique (id, company_id, ...)` so foreign keys can check company and level | |

### Constraints, indexes, policies
| Item | Rule | Example |
|---|---|---|
| Unique constraint | `<table>_<columns>_key` | `company_level_rule_link_key` |
| One open row | Partial unique index `<table>_open_uq` (add the column hint if needed) | `position_allocation_open_uq`, `job_position_open_name_uq` |
| Plain index | `<table>_<column>_idx` | `position_allocation_org_unit_idx` |
| Row level security policy | `<table>_select` | `org_unit_select` |

### Functions and triggers (`private`)
| Item | Rule | Example |
|---|---|---|
| Guard function | `<table>_guard()`. The trigger has the same name | `org_unit_guard` |
| Deferred link check | `<node>_link_check()`, with constraint triggers `<node>_needs_link` and `<node>_parent_keeps_link` | `pos_unit_link_check` |
| Write function | Starts with a verb: `create_`, `close_`, `reorg_` | `create_allocation`, `close_org_unit`, `reorg_pos_unit` |
| Helper function | Describes the result | `pos_department_of`, `user_tenant_ids` |
| Parameters | Prefix `p_` | `p_company_id` |
| Local variables | Prefix `v_` | `v_unit_id` |
| Settings | `set search_path = ''`, tables written as `core.<table>` | |
| Privileges | Every function has an explicit `revoke` and `grant`. Write functions: `service_role` only | |
| Error messages | One plain English sentence, no codes | `The unit is already under this parent` |

### Views and functions (`public`)
| Item | Rule | Example |
|---|---|---|
| View over a dated table | `<thing>_current`, open rows only (`valid_to is null`) | `org_units_current` |
| View over an undated catalog table | Plural noun, no suffix. Planned for ORG: `parent_companies`, `hierarchy_levels` | |
| View options | `with (security_invoker = true)` | |
| View key column | Renamed `<thing>_id` | `unit_id`, `allocation_id`, `rule_id` |
| Joined names | Prefix with the thing they describe | `org_unit_name_en`, `job_name_km` |
| Dropdown function | `<thing>_options` | `org_options`, `pos_options` |
| Eligibility-filtered function | `eligible_<things>` | `eligible_departments`, `eligible_jobs` |
| Privileges | Revoke from `public`, `anon`, `authenticated`, then grant to `authenticated` and `service_role` (Supabase grants new `public` objects to `anon` by default) | |

### Level codes (ORG data, `core.hierarchy_level.code`)
Lowercase snake_case: `business_unit`, `branch`, `division`, `department`, `office`, `section`, `group`.

---

## 5. Frontend code naming

Not defined yet. A proposal for folders, components, hooks and types will be made at the start of ORG Stage 8 and recorded here once you agree.

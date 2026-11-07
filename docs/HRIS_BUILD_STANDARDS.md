# HRIS Build Standards

Last updated: 2026-11-07
Purpose: How every module is built: the lifecycle, the vertical-slice rule, the definition of done, the patterns every module follows, and the session rules for Claude. Read it before starting a new module or a new Stage.
Read together with: `HRIS_PROJECT_OVERVIEW.md` (module register, shared platform), `HRIS_NAMING_CONVENTION.md` (names), `HRIS_MODULE_TEMPLATES.md` (skeletons of the module documents)

Origin labels: **Agreed** (you confirmed it), **Existing** (already a rule in the project documents, the source is named), **Proposed** (Claude's recommendation, waiting for your confirmation). When you confirm a Proposed item, change its label to Agreed.

---

## 1. Module lifecycle (phases P1 to P8)

| Phase | Name | What is produced | Leave the phase when | Recorded in | Origin |
|---|---|---|---|---|---|
| P1 | Requirements | Business objectives, workflows, policies, user roles, acceptance criteria, list of UAT scenarios | You approved it. Open questions that change the scope are settled | Blueprint section 1 | Agreed |
| P2 | Functional design | Screens, user journeys, validations, expected behaviour, who can do what (HR, manager, employee) | You approved it | Blueprint section 3 | Agreed |
| P3 | Database design | The **whole module**: tables, relationships, constraints, functions, permission codes, RLS needs, draft public contract, answers to the scenario checklist (section 5) | You approved it. No open question can still change the schema. Every checklist scenario is answered | Blueprint section 4 | Agreed |
| P4 | Backend development and testing | Per Stage: migration, SQL test, read views, write functions and public wrappers, validation rules and messages | The Stage's SQL test passes | Status (stage log), frontend reference | Agreed |
| P5 | Frontend development and testing | Per Stage: pages, forms, tables, dialogs, interactions | The Stage's browser check passes | Status (stage log) | Agreed |
| P6 | UAT | Every P1 scenario run end to end: permissions, data integrity, edge cases | Every scenario passes, or the gap is a listed known limitation | Status section 6 | Agreed |
| P7 | Deployment | Module deployed to the test environment, real workflows checked | Checklist done | Status section 7 | Agreed |
| P8 | Completion and documentation | Decisions, schema changes, test results and known limitations recorded. Documents compacted (section 8) | Documents match the code | All module documents | Agreed |

- **Phase, not Stage.** `P1` to `P8` are lifecycle phases. A **Stage** is a vertical slice (section 2). The two words are never mixed. (Agreed: this replaces the earlier idea of calling the phases "S1 to S8", which would clash with `ORG Stage 6c`.)
- P1 to P3 are finished for the **whole module** before Stage 1 starts. P4 and P5 are not separate periods: they run together inside every Stage.
- A very small module may do P1 and P2 in one pass. No phase is skipped.

---

## 2. Stages are vertical slices (Agreed)

**Design the whole database in P3 for coherence, then build one slice at a time: database, then server action or write function, then UI, then test.** Example for Leave: Stage 1 leave types, Stage 2 apply for leave, Stage 3 approve or reject.

| Rule | Origin |
|---|---|
| One Stage = one thing a user can do, end to end. Name it by that capability ("apply for leave"), not by a layer ("leave tables") | Agreed |
| **Stage 0** has no feature. It records: blueprint approved, module code and table prefix agreed, first migration with the module's permission codes and their role grants | Agreed (permission codes in first migration: Existing, Overview 5.7) |
| A table is created in the Stage that first needs it, following the P3 design. No tables "for later" | Proposed |
| Inside a Stage the order is fixed: (1) migration and SQL test, (2) read views and functions, (3) write functions and public wrappers with permission check and plain-English errors, (4) frontend types and data access, (5) UI with all states, (6) browser check against this Stage's UAT scenarios, (7) update the documents | Agreed |
| Size: one Stage = one migration, one test and a handful of frontend files. Simple Stages may be batched and tested once. A complex Stage is split into `6a`, `6b` | Existing (Overview section 4) |
| Every Stage leaves the app working and deployable | Proposed |
| A Stage ends with your confirmation. The next Stage does not start before | Proposed |
| Name work `<MODULE> Stage N` or "migration NNN". Never a bare "stage 5" | Existing (Naming 1) |

---

## 3. Definition of done for a Stage (Proposed)

A Stage is done only when every line is true.

- [ ] Migration applied to the dev project with `--remote`. SQL test passes ("Success. No rows returned")
- [ ] The test covers: happy path, permission denied, another tenant's data, every invalid-input error message, closed or ended records, boundary dates
- [ ] Every new function has an explicit `revoke` and `grant`. Objects in `public` are revoked from `public, anon, authenticated` first (Overview section 6)
- [ ] Every write wrapper checks a permission. New permission codes are granted to roles in a migration
- [ ] Frontend shows loading, empty, error and "not allowed" states. Buttons follow the permission check. Database error messages are mapped. Names follow the Khmer/English rule. Dates are passed explicitly (Overview 5.5, 5.6)
- [ ] The scenario decisions (section 5) for the objects in this Stage are built and tested: history, back-dated and future-dated entry, add, edit, delete or close, triggers, scheduled runs
- [ ] Browser check done with a user who is allowed and a user who is not
- [ ] No leftover test pages or debug code
- [ ] Documents updated (section 8)
- [ ] Known limitations written down, not hidden

---

## 4. Patterns every module follows

Details live in the documents named in the last column. Do not repeat them in module documents.

| Area | Rule | Where defined | Origin |
|---|---|---|---|
| Schemas and access | `core` tables, `private` functions, `public` read views. Frontend reads `public` only. Writes go through public wrappers that check permission | Overview 5.2, 5.4 | Existing |
| Tenancy | Every company-scoped table uses the same row-visibility pattern | Overview 5.2 | Existing |
| Roles | A module adds its permission codes in its first migration | Overview 5.7 | Existing |
| Names | `name_en` required, `name_km` optional. Show Khmer when the interface is Khmer and the name is not empty | Overview 5.2, 5.6 | Existing |
| Dates | Anything defaulting to "today" uses the server (UTC) date. The frontend passes the user's date explicitly | Overview 5.5 | Existing |
| Error messages | One plain English sentence, no codes. Listed in the module's frontend reference so the frontend can map them | Naming 4 | Existing |
| History | Each module decides in P3: keep history (close a row and create a new one, as ORG does) or edit in place. Record the decision. Employee records and anything that feeds payroll should keep history | Section 5 (SC-01 to SC-03), ORG Status design choices | Proposed |
| Validation | Three places, the database is the truth: constraints and guards, then wrapper checks, then UI checks for convenience only. UI validation never replaces the database | | Proposed |
| Approvals | Use the shared approval workflow once it exists (module `PLT`). Do not build a private approval table per module | Roadmap | Proposed |
| Files | Employee documents go to a private R2 bucket with signed links. Only metadata (path, type, owner, dates) goes in the database | | Proposed |
| Money | `numeric`, never floating point. A currency code is stored next to every amount (USD or KHR) | | Proposed |
| Seeds | Reference data the module cannot run without is seeded in its own migration. Sample and dev data stay in separate files | Naming 3 | Existing |
| Applied migrations | Never edited. A fix is a new migration | Naming 3 | Existing |
| Frontend code names and folders | **Not defined yet** | Naming 5 | Open |

---

## 5. Design scenario checklist (P2 and P3)

Basic scenarios that are easy to forget and expensive to add after the tables exist. Every module goes through this list **before Stage 1**. The place for the answers is Blueprint section 4.8. Triggers and scheduled runs are listed in Blueprint section 4.9. (Agreed: the checklist exists. The scenarios themselves are Proposed.)

**How to use it**
- For each scenario and each group of tables or functions it touches, answer **Applies** (with the decision) or **Does not apply** (with a one-line reason). A blank is an open question.
- Claude asks one group at a time and does not assume an answer.
- Each Stage builds and tests the decisions for the objects it touches (sections 3 and 6).
- New scenarios found later are added to this list, so the next module gets them.

### A. Time and history
| ID | Scenario | Decide | Usual build consequence |
|---|---|---|---|
| SC-01 | History needed | Which tables and fields must show what was true on a past date (position, salary, status, balances)? Keep history, edit in place, or only an audit log? | History rows with `valid_from` and `valid_to` (close and replace, never edit), "as of date" reads, so reports and payroll can look at any past date. ORG already works this way |
| SC-02 | Back-dated entry | May the effective date be in the past? How far back? Who may do it? Does it need approval? What happens to what is already processed (payroll run, leave balance, attendance)? | Lower limit check, period lock (SC-08), a list of affected records, a recalculation or adjustment rule. If none is defined, refuse |
| SC-03 | Future-dated entry | May the effective date be in the future? Must anything happen on that date? | **Only the data changes:** store the row with the future date and read "as of date". No job needed. **Something must happen** (status flips, login switched off, balance added, message sent): a scheduled run (SC-04). Define what "current" means: in ORG it is `valid_to is null`, so a future-dated row already counts as current. A module that needs true future effect must read current as of a date |
| SC-04 | Scheduled runs | For each run: what it does, when (Phnom Penh time or UTC), what if a day is missed, what if it runs twice | Safe to repeat, writes a log, catches up after a missed day, can be started by hand, listed in Blueprint 4.9. One scheduling method for the whole project, chosen once in `PLT` |
| SC-05 | Overlap and gaps | May two records of the same kind overlap for the same person or unit? Are gaps allowed? | Exclusion constraint or guard with a plain-English message |
| SC-06 | Correction or change | Is fixing a typo different from a real change on a date? Which fields are which? | A correction updates the row and creates no history. A change closes the row and creates a new one |
| SC-07 | Cancel or reverse | Can a future-dated or approved record be cancelled or reversed? Until when? What is undone with it? | A cancel status or closing rule, and the undo of side effects |
| SC-08 | Period lock | Is there a cut-off after which nothing may change (payroll month closed, leave year closed)? Who unlocks it? | A lock record, checked in every write function that can reach the locked period |

### B. Add, edit, delete
| ID | Scenario | Decide | Usual build consequence |
|---|---|---|---|
| SC-09 | Add | What is required for a draft and what for the final record? How are duplicates found? Are codes typed or generated? | Draft status, required-at-submit checks, unique constraints, code generation |
| SC-10 | Edit | Which fields may change once the record is in use? Which never (codes, keys)? What if two people edit at once? | Guard that refuses changing fixed fields, version or `updated_at` check, a clear message |
| SC-11 | Delete | Hard delete, close (set an end date), or blocked while used? What cascades? May it be brought back? How long must it be kept? | Usually close, not delete. ORG: closing cascades and nothing is re-opened. Foreign keys restrict. Hard delete only for drafts |
| SC-12 | Triggers | What must happen automatically on add, edit or delete: derived values, cascade closes, status copied to other tables, audit entries? | Rules that must always hold go into a guard or trigger in the database. Business steps go into a write function. Each trigger is listed in Blueprint 4.9 with what it touches. No trigger writes into another module's tables without being named in both modules' documents |
| SC-13 | Repeat safety | What if the same action is sent twice (double click, retry, a job re-run)? | Write functions and jobs safe to repeat, unique keys, migrations that can re-run |

### C. Status and approval
| ID | Scenario | Decide | Usual build consequence |
|---|---|---|---|
| SC-14 | Status model | Which states exist, which transitions are allowed, who may do each, which states are final? | Status column, a transition guard, a transition table in the Blueprint |
| SC-15 | Approval | Who approves, per which scope? Who covers an absent approver? Is there a time limit or escalation? What happens to a change after approval, and can the request be withdrawn? | The shared approval workflow (`PLT`). A time limit needs a scheduled run |
| SC-16 | Notifications | Who is told about which event, and where (in the app, or a message)? | Event rows and the shared notification service (`PLT`) |

### D. People and access
| ID | Scenario | Decide | Usual build consequence |
|---|---|---|---|
| SC-17 | Who acts on whom | What can the employee, the manager and HR each do, and for which scope (company, org unit)? Which fields are sensitive (salary, ID numbers, family details)? | Permission codes, scope checks, views that leave out sensitive columns, reads under roles for sensitive data |
| SC-18 | Employee status effects | What happens to this module's data when the employee exits, transfers, is rehired, is suspended or holds several assignments at once? | Effects listed in Blueprint 4.9, with who applies them (trigger, write function or scheduled run) |

### E. Calculation, reporting and data
| ID | Scenario | Decide | Usual build consequence |
|---|---|---|---|
| SC-19 | Stored or calculated | Is a result stored as a snapshot or calculated when asked? Does a back-dated change force a recalculation? | Snapshot with a run ID for payroll-type results, calculation on request for display |
| SC-20 | Money, rounding, calendar | Currency (USD or KHR), exchange-rate date, rounding, part-period proration, year rollover (carry-over, accrual) | `numeric`, a currency column, a dated rate table, the rules written in the Blueprint |
| SC-21 | Reporting needs | Which lists and reports need as-of dates, history or large volumes? | As-of views, server-side search and paging, indexes |
| SC-22 | Bulk data | Is there an Excel import or export, or a load of legacy data? | A staging table, a validation report, no direct writes into `core` tables |
| SC-23 | Khmer and calendar | Khmer names, Khmer search and sorting, Khmer or Gregorian dates, public holidays as data | Bilingual columns, a tested sort and search, holidays in a table, Khmer fonts in generated PDFs |

---

## 6. Testing standard

| Item | Rule | Origin |
|---|---|---|
| SQL test | Plain SQL in the Supabase SQL Editor on the dev project. Rolls back at the end. `FAIL: <check>` names a failed check. Tests that rely on deferred constraints force them (`set constraints all immediate`, then `deferred`) | Existing (Naming 3, Overview 6) |
| UAT scenarios | Written in P1, numbered `<MODULE>-UAT01`. Columns: scenario, role, steps, expected result. Each Stage's browser check uses the scenarios it covers. P6 runs all of them | Proposed |
| Scenario tests | The SQL test includes the scenarios decided for the Stage's objects: a back-dated entry, a future-dated entry, an overlap, a delete or close that is blocked, and each trigger. A scheduled run is tested by running it twice and after a missed day | Proposed |
| Test data | Dev project only. No real employee data | Existing (Overview 3) |
| Results | Recorded in the Status stage log: passed, failed, or "not run" | Proposed |

---

## 7. Changing the design while building

| Situation | What to do |
|---|---|
| Bug in an applied migration | New migration. Say which function or object it replaces in its header. Update "Current versions of replaced functions" in the module Status |
| Unbuilt part of the design changes | First write the change in the Blueprint decision table (date, reason). Then build |
| The change touches another module's tables, functions or errors | Stop. Name the other module and the object. You decide. Then update that module's frontend reference |
| New requirement during a Stage | Add it to the Blueprint as an open question or a new Stage. Do not squeeze it into the current Stage |
| A document and a migration disagree | The migration wins. Fix the document in the same session |
| Claude lacks a file or a fact | Claude asks, or asks whether to generate it. Claude never guesses |

---

## 8. Documents: what to update, what to attach

### Per module (Proposed)
| Document | Holds | Changes |
|---|---|---|
| `HRIS_<MODULE>_BLUEPRINT.md` | P1 to P3: requirements, assumptions and open questions, functional design, database design, Stage plan, decisions | Rarely. Only through the decision table |
| `HRIS_<MODULE>_STATUS.md` | P4 to P8: where we are, stage log, files and migrations, next plan, pending items, UAT, deployment, known limitations | Every Stage |
| `HRIS_<MODULE>_FRONTEND_REFERENCE.md` | What the frontend can read and write, rules enforced, errors, known gaps, source map. Created when the module's database is ready for a frontend | When a public object, guard, trigger or write function changes |

Skeletons are in `HRIS_MODULE_TEMPLATES.md`. Older modules (ORG) keep scope and decisions inside their Status document until they are compacted.

### Identifiers
Decisions `<MODULE>-D01`, open questions and assumptions `<MODULE>-Q01`, UAT scenarios `<MODULE>-UAT01`. Numbers are never reused. A settled question becomes a decision and keeps its ID reference.

### What to update when
| Event | Update |
|---|---|
| Decision made or assumption confirmed | Blueprint decision table, with its origin label |
| A Stage passes | Status: stage log, files and migrations, test result, next plan |
| A public object, guard, trigger, write function or error message changes | Frontend reference, in the same session |
| A shared rule or platform fact changes | `HRIS_PROJECT_OVERVIEW.md`, not the module documents |
| A module changes state | Module register in `HRIS_PROJECT_OVERVIEW.md` |
| A new naming pattern appears | `HRIS_NAMING_CONVENTION.md` |

### What to attach for a task
| Task | Attach |
|---|---|
| Any new chat | `HRIS_PROJECT_OVERVIEW.md`, this module's Status |
| Requirements, design, open questions | + Blueprint |
| Database work | + Blueprint section 4, and only the migrations named in the source map |
| Frontend work | + frontend reference, the file lists of `app/` and `lib/supabase/`, and the **latest** version of each file to change |
| Work that touches another module | That module's frontend reference only |

### Size and compaction (Proposed)
Aim for Blueprint about 400 lines, Status about 250, frontend reference about 450. Over that, compact: collapse finished Stages to one or two lines, move reasoning into the decision table, and drop what the code already shows. At P8 every module is compacted once.

### Style
Documents follow `HRIS_NAMING_CONVENTION.md` section 2: header block, tables and short lists, no pasted code, a fact lives in one place, statements labelled **Your decisions**, **Adopted** or **Assumption**.

---

## 9. Working rules for Claude

**Start of a session**
1. Read the Overview and the module's Status (and Blueprint if the task is design). Say in one line: module, current Stage, what comes next.
2. Ask only for the files needed for this small step, and always for the latest version of a file before changing it.

**During a session**
- One Stage at a time. Do not build ahead of the Blueprint.
- Never guess missing logic or hidden context. Record it as an open question (`<MODULE>-Q..`) and ask.
- In P2 and P3, walk through the scenario checklist (section 5) one group at a time and ask for each decision. Never fill in "does not apply" without a reason.
- Output only complete new or changed files, ready to add or replace, individually (a zip only for many files). Explanations stay minimal, plain English, about what changed.
- Flag every statement that is an assumption.
- Never use the `service_role` or `secret` key in the browser. Never edit an applied migration. Never paste code into documents.

**End of a Stage**
- Give the exact text to add to the Status (and to the Blueprint or frontend reference if they changed), together with the code.
- State the next Stage and wait for your confirmation.

---

## 10. Existing ORG module

ORG was built before this method: database Stages first, then the frontend. It stays as it is. The method applies from the next module. ORG's documents are compacted and split into Blueprint and Status as a separate step, so nothing is lost on the way.

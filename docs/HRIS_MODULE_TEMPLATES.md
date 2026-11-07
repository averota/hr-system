# HRIS Module Document Templates

Last updated: 2026-11-07
Purpose: Skeletons for the two documents every new module starts with (Blueprint and Status). Copy a part into its own file, replace `<MODULE>`, delete the hints in italics.
Read together with: `HRIS_BUILD_STANDARDS.md` (what each phase and section means), `HRIS_NAMING_CONVENTION.md`

The third module document, `HRIS_<MODULE>_FRONTEND_REFERENCE.md`, is created when the module's database is ready for a frontend. Use `HRIS_ORG_FRONTEND_REFERENCE.md` as the model: scope and access, data model in brief, read API, rules the database enforces, what it does not check, write API, errors, known gaps, source map.

---

## Part A: `HRIS_<MODULE>_BLUEPRINT.md`

````markdown
# HRIS <MODULE> Blueprint: <Module name>

Last updated: YYYY-MM-DD
Purpose: What the <module name> module must do, how it looks and behaves, and how its data is designed. Written before building. Changed only through the decision table (section 6).
Read together with: `HRIS_PROJECT_OVERVIEW.md`, `HRIS_<MODULE>_STATUS.md`, `HRIS_BUILD_STANDARDS.md`

## 0. Read this first
| Item | Value |
|---|---|
| Module code | `<MODULE>` |
| Table prefix | *agreed in Stage 0* |
| Phase now | P1 / P2 / P3 / P4-P5 (Stage N) / P6 / P7 / P8 |
| Depends on | *other modules and the tables or functions used (their frontend reference, public contract only)* |
| Used by | *modules that will depend on this one* |
| Ask for these files if needed | *file names Claude should request for specific details* |

## 1. Requirements (P1)
### 1.1 Business objectives
*3 to 6 bullets.*
### 1.2 Workflows
*Numbered steps per workflow. Who does what, in which order.*
### 1.3 Policies and rules
*Company policy, Cambodian labour or tax rules that apply. Mark each "to verify" until checked against the current regulation.*
### 1.4 Roles: who can do what
| Action | HR | Manager | Employee | Permission code |
|---|---|---|---|---|
### 1.5 Out of scope
### 1.6 Acceptance criteria and UAT scenarios
| ID | Scenario | Role | Steps | Expected result | Covered in Stage |
|---|---|---|---|---|---|
| `<MODULE>-UAT01` | | | | | |

## 2. Assumptions, gaps and open questions
| ID | Type | Text | Affects | Status | Settled on |
|---|---|---|---|---|---|
| `<MODULE>-Q01` | Assumption / Gap / Question | | Phase or Stage | Open / Settled (becomes `<MODULE>-D..`) | |

## 3. Functional design (P2)
### 3.1 Screens
| Screen | Purpose | Who sees it | Main actions | Stage |
|---|---|---|---|---|
### 3.2 User journeys
*One short numbered list per journey.*
### 3.3 Validations and messages
| Field or action | Rule | Message shown |
|---|---|---|
### 3.4 Expected behaviour and edge cases
*Empty states, dates (UTC, user-picked dates), closed or ended records, Khmer and English names.*

## 4. Database design (P3)
### 4.1 Entities and relationships
*Short list or a diagram. Link to ORG or platform tables where used.*
### 4.2 Tables
| Table | Purpose | Key columns | History (keep or edit in place) | Created in Stage |
|---|---|---|---|---|
### 4.3 Constraints and rules
*What the database enforces. One line each.*
### 4.4 Functions and permission codes
| Function or wrapper | Does | Permission code | Stage |
|---|---|---|---|
### 4.5 Visibility (RLS)
*Which rows who sees. Reuse the tenant pattern; list any exception.*
### 4.6 Public contract
*Views and functions other modules may use. Only these are stable.*
### 4.7 Reference and seed data

### 4.8 Scenario decisions
*Answer every scenario of `HRIS_BUILD_STANDARDS.md` section 5 before Stage 1. "Does not apply" needs a one-line reason. A blank is an open question.*
| Scenario | Applies to (tables or functions) | Decision, or "Does not apply: reason" | Build consequence | Stage |
|---|---|---|---|---|
| SC-01 History needed | | | | |
| SC-02 Back-dated entry | | | | |
| SC-03 Future-dated entry | | | | |
| SC-04 Scheduled runs | | | | |
| SC-05 Overlap and gaps | | | | |
| SC-06 Correction or change | | | | |
| SC-07 Cancel or reverse | | | | |
| SC-08 Period lock | | | | |
| SC-09 Add | | | | |
| SC-10 Edit | | | | |
| SC-11 Delete | | | | |
| SC-12 Triggers | | | | |
| SC-13 Repeat safety | | | | |
| SC-14 Status model | | | | |
| SC-15 Approval | | | | |
| SC-16 Notifications | | | | |
| SC-17 Who acts on whom | | | | |
| SC-18 Employee status effects | | | | |
| SC-19 Stored or calculated | | | | |
| SC-20 Money, rounding, calendar | | | | |
| SC-21 Reporting needs | | | | |
| SC-22 Bulk data | | | | |
| SC-23 Khmer and calendar | | | | |

### 4.9 Triggers and scheduled runs
| Name | Type (trigger, write function, scheduled run) | When it fires | What it does | Tables touched (any other module?) | Safe to repeat? | Stage |
|---|---|---|---|---|---|---|

## 5. Stage plan
| Stage | Capability (a user can...) | Migrations | Frontend | Depends on | Status |
|---|---|---|---|---|---|
| 0 | Setup: blueprint approved, prefix agreed, permission codes | | none | | |
| 1 | | | | | |

## 6. Decisions
| ID | Date | Decision | Origin | Reason |
|---|---|---|---|---|
| `<MODULE>-D01` | | | Your decision / Adopted | |
````

---

## Part B: `HRIS_<MODULE>_STATUS.md`

````markdown
# HRIS <MODULE> Status

Last updated: YYYY-MM-DD
Purpose: Where the <module name> module is in the build: stages passed, files created, tests, next steps and known limitations.
Read together with: `HRIS_PROJECT_OVERVIEW.md`, `HRIS_<MODULE>_BLUEPRINT.md`, `HRIS_<MODULE>_FRONTEND_REFERENCE.md`

## 1. Where we are
*At most 10 lines: current Stage, last Stage passed, what is next, anything blocking.*

## 2. Stage log
| Stage | Capability | Migration(s) | SQL test | Browser check | Date | Notes |
|---|---|---|---|---|---|---|

## 3. Files
### 3.1 Migrations and tests
| File | Stage | What it adds | Test file |
|---|---|---|---|
### 3.2 Frontend files
| Path | Purpose | Depends on | Last changed in Stage |
|---|---|---|---|
### 3.3 Current versions of replaced functions
| Function | Current version in | Replaced |
|---|---|---|

## 4. Next plan
*Numbered, small steps. The first one is the next Stage.*

## 5. Pending from you
*Questions, files, decisions, tests to run.*

## 6. UAT results (P6)
| Scenario | Result | Note |
|---|---|---|

## 7. Deployment checklist (P7)
- [ ] Migrations applied to the test environment
- [ ] Environment variables set
- [ ] Workflows checked with real roles

## 8. Known limitations (P8)
| Limitation | Impact | Planned fix |
|---|---|---|

## 9. Lessons (this module only)

## 10. How to resume
*Three to five lines: which files to attach (see `HRIS_BUILD_STANDARDS.md` section 8), how to name the Stage.*
````

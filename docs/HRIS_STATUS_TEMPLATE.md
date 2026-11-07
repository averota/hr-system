# HRIS <MODULE> Status

Last updated: YYYY-MM-DD
Purpose: The plan and progress of the <module name> module: Stages and tasks planned, what has passed, files created, tests, issues, next steps and known limitations. What the module is, and why, is in the Blueprint.
Read together with: `HRIS_PROJECT_OVERVIEW.md`, `HRIS_<MODULE>_BLUEPRINT.md`, `HRIS_<MODULE>_FRONTEND_REFERENCE.md`

> **Template use (delete this note after copying).** Save as `HRIS_<MODULE>_STATUS.md`, replace `<MODULE>`, delete the hints in italics. Create it together with the Blueprint, fill section 2 (Stage plan) once the Blueprint is "Ready for Stage 1", then update it at the end of every Stage: sections 1 to 6 and 8 in one go, and the module row in `HRIS_MODULE_REGISTER.md` if the state changed.

---

## 1. Where we are
*At most 10 lines.*

| Item | Value |
|---|---|
| Phase now | P1 / P2 / P3 / P4-P5 (Stage N) / P6 / P7 / P8 |
| Blueprint state | Draft / Ready for Stage 1 (date), copied from Blueprint section 0 |
| Current Stage | |
| Last Stage passed | |
| Next | |
| Blocking | *none, or what and who* |

---

## 2. Stage plan
*One row per Stage, in build order. A Stage is a vertical slice: a user can do something new. Stages may be reordered or split here without a decision, as long as the Blueprint scope does not change.*

| Stage | Capability (a user can...) | Blueprint items covered (`R`, `Q`, `D`, `SC`, `UAT`, section) | Migrations planned | Frontend planned | Depends on | State (Planned / In progress / Passed / Blocked / Dropped) |
|---|---|---|---|---|---|---|
| 0 | Setup: Blueprint approved, prefix agreed, first migration with permission codes and role grants | | | none | | |
| 1 | | | | | | |

---

## 3. Task list
*Tasks of the current Stage and the next one only. When a Stage passes, summarise its tasks in the stage log (section 4) and remove them here.*

| Task | Stage | Task | Type (Migration / SQL test / Frontend / Document / Decision / Check) | Blueprint ref | Who (You / Claude) | State (To do / Doing / Done / Blocked) | Done on | Note |
|---|---|---|---|---|---|---|---|---|
| `<MODULE>-T001` | | | | | | | | |

---

## 4. Stage log
*One row when a Stage ends, passed or not.*

| Stage | Capability | Migration(s) | SQL test | Browser check | Result (Passed / Failed / Partly) | Date | Notes (decisions made, changes to the plan) |
|---|---|---|---|---|---|---|---|

---

## 5. Files

### 5.1 Migrations and tests
| File | Stage | What it adds | Test file |
|---|---|---|---|

### 5.2 Frontend files
| Path | Purpose | Depends on | Last changed in Stage |
|---|---|---|---|

### 5.3 Current versions of replaced functions
| Function | Current version in | Replaced |
|---|---|---|

---

## 6. Next plan
*Numbered, small steps. The first one is the next Stage or task.*

---

## 7. Pending from you
*Questions, files, decisions, tests to run.*

---

## 8. UAT coverage and results (P6)
*Scenarios come from Blueprint section 1.6. "Covered in Stage" is filled while building, "Result" in Phase P6.*

| Scenario | Covered in Stage | Result | Date | Note |
|---|---|---|---|---|

---

## 9. Issues log
| ID | Stage | Problem | Found by (SQL test / Browser / UAT / Other) | State (Open / Fixed / Accepted) | Fix or decision |
|---|---|---|---|---|---|

---

## 10. Deployment checklist (P7)
- [ ] Migrations applied to the test environment
- [ ] Environment variables set
- [ ] Workflows checked with real roles

---

## 11. Known limitations (P8)
| Limitation | Impact | Planned fix |
|---|---|---|

---

## 12. Lessons (this module only)

---

## 13. How to resume
*Three to five lines: which files to attach (see `HRIS_BUILD_STANDARDS.md` section 8), how to name the Stage.*

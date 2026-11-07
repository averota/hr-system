# HRIS Module Register

Last updated: 2026-11-07
Purpose: The list of all HRIS modules in build order, with their permanent codes, scope, dependencies, state and documents. Use it to plan the build order and to find which module owns something.
Read together with: `HRIS_PROJECT_OVERVIEW.md` (shared setup), `HRIS_BUILD_STANDARDS.md` (phases and stages), `HRIS_NAMING_CONVENTION.md`

Modules are listed in **build order**. The order follows dependencies, so a module is built after the modules it needs. The **code is permanent**, the order can change. Each module goes through phases P1 to P8 and is built in Stages.

All module codes are confirmed.

| Order | Module | Code | Scope | Depends on | State | Documents |
|---|---|---|---|---|---|---|
| 1 | Project foundation | `FND` | Stack, repository, environments, tenancy tables (`000`, `001`), shared conventions and documents | none | In place. Not yet set up: production Supabase project, Vercel deployment, Cloudflare R2 (see `HRIS_PROJECT_OVERVIEW.md`, section 7) | `HRIS_PROJECT_OVERVIEW.md`, `HRIS_BUILD_STANDARDS.md`, `HRIS_NAMING_CONVENTION.md`, `HRIS_MODULE_TEMPLATES.md`, `HRIS_BLUEPRINT_TEMPLATE.md`, this file |
| 2 | Platform services | `PLT` | Part A: access and setup (create tenant, company and membership; give, change and remove roles; members screen; how reads are governed). Planned parts, designed later (Proposed): B bilingual master data and audit log, C file storage on R2, D scheduling method for jobs, E shared approval workflow and notifications | `FND` | Roles built (`012`, `013`). Last tenant admin guard (`025`) applied and tested (2026-11-07). Blueprint draft for part A written (P1 to P3, date rules added 2026-11-07), waiting for your answers to its open questions (Stage 0) | `HRIS_PLT_BLUEPRINT.md` |
| 3 | Organization structure | `ORG` | Org tree, position tree, job catalog, Department eligibility, approved headcount allocation | `FND`, `PLT` (roles) | **Paused on 2026-11-07.** Stages 0 to 9l complete (database `000` to `029`, frontend with write screens, permissions, history of closed records, as-of and Moves views, Re-create). Gap fixes passed: 1000-row warning, Phnom Penh date (`029`). Left: Khmer level names (needs the names), settle the Blueprint assumptions, approve the Blueprint | `HRIS_ORG_BLUEPRINT.md`, `HRIS_ORG_STATUS.md`, `HRIS_ORG_FRONTEND_REFERENCE.md` |
| 4 | Employee management | `EMP` | Employee profiles and employment records (the data and its history). Scope not discussed yet. The read rule ("any tenant member sees everything") must be decided before employee data is stored (`PLT` question PLT-Q06) | `ORG`, `PLT` (parts A, B and C) | Not started | none |
| 5 | Employee lifecycle | `LCY` | Hiring, probation, transfer, promotion, termination (the process and its approvals). The earlier "employee hooks" to ORG allocations belong here. Scope not discussed yet | `EMP`, `ORG`, `PLT` (part E) | Not started | none |
| 6 | Work schedule | `SCH` | Shifts, working days, holidays. Scope not discussed yet | `ORG`, `PLT` | Not started | none |
| 7 | Attendance | `ATT` | Timekeeping and attendance records, overtime (Proposed). Scope not discussed yet | `EMP`, `SCH` | Not started | none |
| 8 | Leave management | `LVE` | Leave policies, applications, balances. Scope not discussed yet | `EMP`, `SCH`, `PLT` (parts D and E) | Not started | none |
| 9 | Payroll | `PAY` | Salary structures, calculations, payroll processing. Scope not discussed yet | `EMP`, `SCH`, `ATT`, `LVE` | Not started | none |
| 10 | Recruitment | `REC` | Vacancies and candidate management. Hands a hired candidate to `LCY` | `ORG`, `LCY` | Not started | none |
| 11 | Performance | `PRF` | Evaluations and performance management | `EMP` | Not started | none |
| 12 | Training | `TRN` | Training programs and employee development | `EMP` | Not started | none |
| 13 | Reporting | `RPT` | Cross-module HR reports and analytics. Each module ships its own basic reports | all | Not started | none |

- Orders 10 to 13 can be reordered freely.
- Self-service is not a module: each module document says what HR, managers and employees can each do.
- Starting a module: add or update its row here, write `HRIS_<CODE>_BLUEPRINT.md` and `HRIS_<CODE>_STATUS.md` from `HRIS_MODULE_TEMPLATES.md`, and answer the scenario checklist (`HRIS_BUILD_STANDARDS.md`, section 5) before Stage 1. Every Blueprint also carries the date and time rules (section 4.10 of `HRIS_BLUEPRINT_TEMPLATE.md`, fixed text): "today" in SQL comes only from `private.org_today()` (Phnom Penh date), never from `current_date`. Create `HRIS_<CODE>_FRONTEND_REFERENCE.md` once the database is ready for a frontend.
- Update this file when a module is added, its scope or dependencies change, or its state changes (a phase closes, or a Stage group finishes). Stage-by-Stage progress belongs in the module's Status document, not here.

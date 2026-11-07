# HRIS <MODULE> Blueprint: <Module name>

Last updated: YYYY-MM-DD
Purpose: What the <module name> module must do, which assumptions it rests on, how it looks and behaves, and how its data is designed. Written before building. Changed only through the decision table (section 6). Planned tasks and progress are in the Status.
Read together with: `HRIS_PROJECT_OVERVIEW.md`, `HRIS_MODULE_REGISTER.md`, `HRIS_CONTEXT.md`, `HRIS_<MODULE>_STATUS.md`, `HRIS_BUILD_STANDARDS.md`

> **Template use (delete this note after copying).** Save as `HRIS_<MODULE>_BLUEPRINT.md`, replace `<MODULE>`, delete the hints in italics. This file is the foundation: it holds no Stage names, dates or task state, those live in the Status. An approved section changes only after a row is added to section 6. **Section 4.10 (date and time rules) is fixed text for all modules: copy it unchanged and fill only its module table.**

---

## 0. Read this first

| Item | Value |
|---|---|
| Module code | `<MODULE>` |
| Table prefix | *agreed before Stage 1* |
| Blueprint state | Draft / Ready for Stage 1 (date) *(set only when section 5 is fully ticked)* |
| Depends on | *other modules and the tables or functions used (their frontend reference, public contract only)* |
| Used by | *modules that will depend on this one* |
| Context rows used | *`CTX-nn` rows from `HRIS_CONTEXT.md` that this module must verify or reuse* |
| Ask for these files if needed | *file names Claude should request for specific details* |

---

## 1. Requirements (P1)

### 1.1 Business objectives
*3 to 6 bullets.*

### 1.2 Workflows
*Numbered steps per workflow. Who does what, in which order.*

### 1.3 Policies and rules
*Company policy, Cambodian labour or tax rules that apply. Nothing is "Verified" until checked against the current regulation or company policy. Record verified results in `HRIS_CONTEXT.md` too.*

| ID | Rule | Source (`CTX-nn`, regulation, company policy) | Verified (Yes / To verify / Company decision) | Note |
|---|---|---|---|---|
| `<MODULE>-R01` | | | | |

### 1.4 Roles: who can do what
| Action | HR | Manager | Employee | Permission code |
|---|---|---|---|---|

### 1.5 Out of scope

### 1.6 Acceptance criteria and UAT scenarios
*What "done" means for users. When each scenario is built and tested is tracked in the Status.*

| ID | Scenario | Role | Steps | Expected result |
|---|---|---|---|---|
| `<MODULE>-UAT01` | | | | |

---

## 2. Assumptions, gaps and open questions

*Every assumption the design depends on is listed here, with what happens if it is wrong. An item is closed only by a decision (section 6) or by verification (`HRIS_CONTEXT.md`).*

| ID | Type | Text | If wrong, what changes | Affects (section) | Blocks | Status | Settled by |
|---|---|---|---|---|---|---|---|
| `<MODULE>-Q01` | Assumption / Gap / Question | | | | Stage 1 / Later / None | Open / Settled | `<MODULE>-D..` or `CTX-nn` |

---

## 3. Functional design (P2)

### 3.1 Screens
| Screen | Purpose | Who sees it | Main actions |
|---|---|---|---|

### 3.2 User journeys
*One short numbered list per journey.*

### 3.3 Validations and messages
| Field or action | Rule | Message shown |
|---|---|---|

### 3.4 Expected behaviour and edge cases
*Empty states, dates (Phnom Penh business date and user-picked dates, rules in 4.10), closed or ended records, Khmer and English names.*

---

## 4. Database design (P3)

### 4.1 Entities and relationships
*Short list or a diagram. Link to ORG or platform tables where used.*

### 4.2 Tables
| Table | Purpose | Key columns | History (keep or edit in place) |
|---|---|---|---|

### 4.3 Constraints and rules
*What the database enforces. One line each.*

### 4.4 Functions and permission codes
| Function or wrapper | Does | Permission code |
|---|---|---|

### 4.5 Visibility (RLS)
*Which rows who sees. Reuse the tenant pattern; list any exception.*

### 4.6 Public contract
*Views and functions other modules may use. Only these are stable.*

### 4.7 Reference and seed data

### 4.8 Scenario decisions
*Answer every scenario of `HRIS_BUILD_STANDARDS.md` section 5 before Stage 1. "Does not apply" needs a one-line reason. A blank is an open question: add it to section 2. Answers for SC-02, SC-03, SC-04 and SC-20 must follow the date and time rules in 4.10.*

| Scenario | Applies to (tables or functions) | Decision, or "Does not apply: reason" | Build consequence |
|---|---|---|---|
| SC-01 History needed | | | |
| SC-02 Back-dated entry | | | |
| SC-03 Future-dated entry | | | |
| SC-04 Scheduled runs | | | |
| SC-05 Overlap and gaps | | | |
| SC-06 Correction or change | | | |
| SC-07 Cancel or reverse | | | |
| SC-08 Period lock | | | |
| SC-09 Add | | | |
| SC-10 Edit | | | |
| SC-11 Delete | | | |
| SC-12 Triggers | | | |
| SC-13 Repeat safety | | | |
| SC-14 Status model | | | |
| SC-15 Approval | | | |
| SC-16 Notifications | | | |
| SC-17 Who acts on whom | | | |
| SC-18 Employee status effects | | | |
| SC-19 Stored or calculated | | | |
| SC-20 Money, rounding, calendar | | | |
| SC-21 Reporting needs | | | |
| SC-22 Bulk data | | | |
| SC-23 Khmer and calendar | | | |

### 4.9 Triggers and scheduled runs
| Name | Type (trigger, write function, scheduled run) | When it fires | What it does | Tables touched (any other module?) | Safe to repeat? |
|---|---|---|---|---|---|

### 4.10 Date and time rules

*Fixed text for all modules. Copy unchanged. Only the module table at the end is filled in. Reason: the database server runs on UTC, Phnom Penh is UTC+7. Between 00:00 and 07:00 in Phnom Penh the UTC date is still "yesterday", so any record dated from the server date is one day early. ORG found this late and needed migration `029` and a second clean-up. New modules follow these rules from the first migration.*

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

**Module table.** *List every date or time column, function parameter, screen field and scheduled run of this module. One row each. A blank row means the item was not thought about.*

| Item (table.column, function parameter, screen field or run) | Kind (business date / instant / period boundary) | Value comes from (user picks / system today / system instant) | How it is set (explicit in function, frontend date field, `DT-` rule used) | Note |
|---|---|---|---|---|

---

## 5. Foundation gate: ready for Stage 1

*Tick every line, then set "Blueprint state" in section 0 to Ready for Stage 1 and record the date. The Stage plan and tasks are then written in the Status.*

- [ ] Phase P1 closed: objectives, workflows, roles and out of scope agreed by you
- [ ] Every item in section 2 with "Blocks = Stage 1" is Settled
- [ ] Every `CTX-nn` row used by this module is verified, or recorded as a company decision, in `HRIS_CONTEXT.md`
- [ ] Section 1.3 has no rule marked "To verify" that a Stage 1 table depends on
- [ ] Screens, validations and edge cases written (sections 3.1 to 3.4)
- [ ] Tables, constraints, functions, permission codes and visibility written (sections 4.1 to 4.7)
- [ ] Scenario table 4.8 has no blank row
- [ ] Triggers and scheduled runs listed (4.9), each with a repeat-safety answer
- [ ] Date and time rules (4.10) copied unchanged and the module table has no blank row. No date column has `default current_date`
- [ ] Table prefix agreed and the module row in `HRIS_MODULE_REGISTER.md` is current
- [ ] You approved this Blueprint (date: )

---

## 6. Decisions

*The only way to change an approved section. Add the row first, then update the section it names.*

| ID | Date | Decision | Origin (Your decision / Adopted) | Reason | Sections changed |
|---|---|---|---|---|---|
| `<MODULE>-D01` | | | | | |

# HRIS Context

Last updated: 2026-11-07
Purpose: Cambodia and company context that shapes the HRIS modules: what is assumed, who must verify it, and what has been verified. One place, so a rule is checked once and every module reuses the result.
Read together with: `HRIS_PROJECT_OVERVIEW.md`, `HRIS_MODULE_REGISTER.md`, `HRIS_BUILD_STANDARDS.md`

This document holds only context **shared by several modules**. A rule that belongs to one module is written in that module's Blueprint (section 1.3).

---

## 1. How to use this document

1. **Nothing below is verified** until its row says so (section 2, column Status). Each row is an assumption.
2. The owning module checks its rows against the current regulation or company policy **before its Phase P1 closes**. No rule is built from this list alone.
3. Specific rates, limits and periods are deliberately **not written here**. They are written in the module Blueprint once verified, with the source.
4. When a row is verified, update it here (Status, date, source, one-line outcome). The Blueprint then refers to the row by its ID (`CTX-nn`), so the next module does not check the same thing twice.
5. If a module finds a new topic, add a row with the next free ID. Do not reuse or renumber IDs.

Status values: `Unverified`, `Verified`, `Company decision` (policy chosen by you, no regulation involved), `Not applicable` (with reason).

---

## 2. Cambodia and company assumptions

| ID | Topic | Why it matters | Module | Check against | Status | Verified on, source and outcome |
|---|---|---|---|---|---|---|
| `CTX-01` | Public holidays | Announced by the Ministry each year, so they must be data and not code | `SCH` | Current Ministry announcement | Unverified | |
| `CTX-02` | Statutory leave | Annual, sick, maternity and special leave: types, minimums, how they build up | `LVE` | Labour Law and current notices | Unverified | |
| `CTX-03` | Working hours and overtime | Normal hours, overtime and night or holiday premiums feed attendance and payroll | `SCH`, `ATT`, `PAY` | Labour Law and current notices | Unverified | |
| `CTX-04` | Contract types | Fixed-duration and unlimited-duration contracts, renewal limits, probation limits | `EMP`, `LCY` | Labour Law | Unverified | |
| `CTX-05` | Termination and seniority pay | Notice, indemnity and seniority payments on exit | `LCY`, `PAY` | Labour Law and current notices | Unverified | |
| `CTX-06` | National Social Security Fund (NSSF) | Employee registration, contribution branches and ceilings | `EMP`, `PAY` | NSSF current rules | Unverified | |
| `CTX-07` | Tax on salary and benefits | Calculation basis, brackets, resident or non-resident status, benefits in kind | `PAY` | General Department of Taxation | Unverified | |
| `CTX-08` | Foreign employees | Work permit and ID document tracking with expiry reminders | `EMP` | Ministry and immigration rules | Unverified | |
| `CTX-09` | Currency | Pay in USD, KHR or both. Which exchange rate, and which date | `PAY` | Company policy, current rule | Unverified | |
| `CTX-10` | Khmer and English | Both languages on every name and printed document, Khmer font in PDFs | all | Company policy | Unverified | |
| `CTX-11` | Khmer name order | Family name first, in Khmer. Display, sort and search rules | `EMP` | Company policy | Unverified | |
| `CTX-12` | Khmer and Gregorian dates | Which calendar users see, and in which reports | all | Company policy | Unverified | |
| `CTX-13` | Record retention | How long employee and payroll records must be kept before deletion is allowed (scenario SC-11) | all | Current legal requirement | Unverified | |
| `CTX-14` | Personal data | Employee records are sensitive. Check the legal requirements that apply | all | Current legal requirement | Unverified | |

---

## 3. How a module uses a row

| Step | Where | What |
|---|---|---|
| 1 | Blueprint section 0 | List the `CTX-nn` rows the module uses |
| 2 | Blueprint section 2 | For each row still `Unverified`, one assumption entry, blocking Stage 1 if a rule depends on it |
| 3 | Phase P1 | Check the source, then update the row here (Status, date, source, outcome) |
| 4 | Blueprint section 1.3 | Write the verified rule with its `CTX-nn` reference |
| 5 | Blueprint section 6 | A choice made by you becomes a decision (`<MODULE>-D..`). Set the row to `Company decision` |

---

## 4. Open items

- Verification of every row above is pending. The owning module starts it in its Phase P1.
- Rows owned by `all` are verified by the first module that needs them. Record which module did it in the last column.

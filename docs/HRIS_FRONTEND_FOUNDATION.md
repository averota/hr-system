# HRIS Frontend Foundation

Last updated: 2026-11-07
Purpose: How the HRIS frontend is organised once all modules exist: the folder tree, what goes where, the rules between folders, the shared shell (navigation, work scope, language), and the small stage that moves ORG onto it. Written so the structure is decided once, before the second module adds screens.
Read together with: `HRIS_PROJECT_OVERVIEW.md` (section 3 technical setup, 5.4 access model, 5.6 frontend notes), `HRIS_MODULE_REGISTER.md` (module codes), `HRIS_NAMING_CONVENTION.md`, `HRIS_ORG_FRONTEND_REFERENCE.md`, `HRIS_PLT_BLUEPRINT.md`

Status: **Decided on 2026-11-07** (`FND-D01` to `FND-D08`, section 7). One question is open (`FND-Q09`). This document is also the proposal for `HRIS_NAMING_CONVENTION.md` section 5 (frontend code naming, still undefined there). It is recorded in the convention in Foundation step F6.

Origin labels: **Existing** (how it is today), **Your decision** and **Adopted** (a recommendation you accepted), **Assumption** (not confirmed yet).

**Not yet checked, before any code is written:**
- `AGENTS.md` says this Next.js (16.4.5) differs from what Claude knows and the guides in `node_modules/next/dist/docs/` must be read first. Route groups, nested layouts, cookies and `proxy.ts` behaviour are checked there in step F0, not assumed here.
- `Modal.tsx`, `AsyncSelect.tsx` and `OrgConfigView.tsx` were not reviewed. Which pieces are really free of ORG imports is confirmed when they are moved.
- `HRIS_NAMING_CONVENTION.md` was reviewed on 2026-11-07: documents live in `docs/` (confirmed, not optional), migrations in `supabase/migrations/`, tests in `supabase/tests/`, decision IDs are `<MODULE>-D01` (this document uses `FND` for the foundation). Its section 5 (frontend naming) is not defined, see above.

---

## 1. Where we are now (Existing)

| Item | Today |
|---|---|
| Stack | Next.js 16.4.5, React 19, Tailwind 4 (`@tailwindcss/turbopack`), `lucide-react` for icons, no UI library |
| Routes | `app/page.tsx` is the ORG page. `app/login/page.tsx` is the sign-in. `proxy.ts` refreshes the session and redirects |
| Shell | None. The header (company selector, EN / ខ្មែរ switch, sign out) and the tabs sit inside `modules/org/components/OrgConfigView.tsx` |
| Shared code | None folder-wise. Generic pieces (`Modal`, `AsyncSelect`, `RowLimitWarning`, `AsOfDatePicker`, `limits.ts`, `permissions.ts`, `useAsOfLoad.ts`, the error mapping in `queries.ts`) are filed under `modules/org` |
| Loading data | `app/page.tsx` loads every company's units, rules and allocations in one request and maps the nullable columns. Row limits therefore count all companies together |
| Loose ends | Root layout still says "Create Next App". `globals.css` sets `font-family: Arial`, which overrides the Geist font. Pages use fixed grey colours, not shared colour names |

---

## 2. Principles

1. **A piece is shared when a second module needs it.** Not before. The folders are decided now, the files move one at a time.
2. **One direction only.** `app` uses `modules`, `modules` use `components` and `lib`, `components` use `lib`. Never the other way round (section 4).
3. **Business words stay in modules.** If a file names a unit, employee, leave or job, it belongs to its module. If it is styled UI with no business word, it belongs in `components/`. Everything else (dates, errors, clients) is `lib/`.
4. **Route files are thin.** A `page.tsx` calls its module's loader and renders its module view. The sign-in check is done once, in the shell.
5. **Same shape for every module.** A developer opening `modules/emp` finds the same files as in `modules/org`.
6. **Dates follow the Blueprint template section 4.10** (Phnom Penh date, always passed explicitly). Existing: `lib/dates.ts`.
7. **The scope selector is a view filter, not security.** The database decides what a user may read, module by module (`PLT-D10`). A page never trusts the selection cookie for access (section 5).

---

## 3. Final folder tree (all modules built)

```
hr-system/
├── app/                              ROUTES ONLY. Thin files
│   ├── layout.tsx                    root: <html>, fonts (Latin and Khmer), page title
│   ├── globals.css                   Tailwind and the colour names (tokens)
│   ├── favicon.ico
│   ├── (auth)/                       signed-out pages, no shell
│   │   └── login/page.tsx
│   ├── (app)/                        signed-in pages, wrapped by the shell
│   │   ├── layout.tsx                loads user, scope, permissions, renders <AppShell>
│   │   ├── page.tsx                  home (landing, links to the modules the user may use)
│   │   ├── org/                      ORG   Organization structure (tabs in one page for now)
│   │   ├── platform/                 PLT   Members, access, setup (one route per section)
│   │   ├── employees/                EMP   Employee management
│   │   ├── lifecycle/                LCY   Hiring, probation, transfer, promotion, termination
│   │   ├── schedule/                 SCH   Work schedule
│   │   ├── attendance/               ATT   Attendance
│   │   ├── leave/                    LVE   Leave management
│   │   ├── payroll/                  PAY   Payroll
│   │   ├── recruitment/              REC   Recruitment
│   │   ├── performance/              PRF   Performance
│   │   ├── training/                 TRN   Training
│   │   └── reports/                  RPT   Reporting
│   └── api/                          only when a secret key is needed on the server (PLT login creation, `PLT-D09`)
│
├── components/                       SHARED UI. No business words, no module imports
│   ├── layout/                       AppShell, Sidebar, Topbar, ScopeSelector, LanguageSwitch,
│   │                                 UserMenu, PageHeader, SectionTabs, Breadcrumbs
│   ├── ui/                           Button, Modal, Badge, Card, Alert, LimitWarning (RowLimitWarning),
│   │                                 EmptyState, Spinner
│   ├── form/                         Field, TextInput, TextArea, DateField, Select, AsyncSelect,
│   │                                 CascadeSelector, FormError, FormActions
│   └── data/                         DataTable, SearchBox, FilterBar, Pagination, TotalsBar,
│                                     HistoryToggle, AsOfDatePicker
│
├── lib/                              SHARED LOGIC. No React screens, no module imports
│   ├── supabase/                     client.ts, server.ts, env.ts, database.types.ts
│   ├── context/                      ScopeContext, LocaleContext (scope and language chosen once in the shell)
│   ├── scope.ts                      selection rules: subtree, several companies, cookie read and check
│   ├── hooks/                        useLoad (today useAsOfLoad)
│   ├── permissions.ts                checkPermissions, usePermissions (the PERM_ codes stay in each module)
│   ├── errors.ts                     message mapping for database errors (today writeError, rpcWriteError)
│   ├── limits.ts                     MAX_ROWS, LimitedRows, isRowLimitReached
│   ├── dates.ts                      todayInPhnomPenh, isIsoDate
│   ├── i18n.ts                       displayName, later the English and Khmer labels
│   └── format.ts                     number, date and (PAY) money display
│
├── config/
│   └── navigation.ts                 the module menu: collects each module's nav.ts, hides what the user may not use
│
├── modules/                          BUSINESS CODE. One folder per module, the same shape each
│   ├── org/
│   │   ├── components/               screens and dialogs used only by ORG
│   │   ├── loaders.ts                server data loading and column narrowing (moved out of app/page.tsx)
│   │   ├── queries.ts                browser reads and writes (split by topic when large)
│   │   ├── queriesHistory.ts
│   │   ├── types.ts
│   │   ├── permissions.ts            PERM_ codes of this module
│   │   ├── labels.ts, unitTree.ts    ORG helpers
│   │   ├── nav.ts                    this module's menu entry (label, route, icon, permission to show)
│   │   └── public.ts                 the only file other modules may import (section 4)
│   ├── plt/   emp/   lcy/   sch/   att/   lve/   pay/   rec/   prf/   trn/   rpt/      same shape as org
│
├── supabase/                         migrations/, tests/, dev seeds (Existing, `HRIS_NAMING_CONVENTION.md` section 3)
├── docs/                             the HRIS_*.md documents (Existing, `HRIS_NAMING_CONVENTION.md` section 2)
├── proxy.ts                          session refresh and redirects (Existing)
├── eslint.config.mjs                 also holds the import rules of section 4
└── next.config.ts, tsconfig.json, package.json, AGENTS.md, README.md
```

### 3.1 Module codes, folders, routes

| Code | Folder | Route | Menu label |
|---|---|---|---|
| `ORG` | `modules/org` | `/org` | Organization |
| `PLT` | `modules/plt` | `/platform` | Platform |
| `EMP` | `modules/emp` | `/employees` | Employees |
| `LCY` | `modules/lcy` | `/lifecycle` | Lifecycle |
| `SCH` | `modules/sch` | `/schedule` | Schedule |
| `ATT` | `modules/att` | `/attendance` | Attendance |
| `LVE` | `modules/lve` | `/leave` | Leave |
| `PAY` | `modules/pay` | `/payroll` | Payroll |
| `REC` | `modules/rec` | `/recruitment` | Recruitment |
| `PRF` | `modules/prf` | `/performance` | Performance |
| `TRN` | `modules/trn` | `/training` | Training |
| `RPT` | `modules/rpt` | `/reports` | Reports |

Module folders use the code (as `modules/org` does today). Routes use plain words (`FND-D01`).

### 3.2 Where does a new file go?

| Question | Answer |
|---|---|
| Does it name something from one module (unit, employee, leave)? | `modules/<code>/` |
| Is it a styled piece of screen with no business word? | `components/` (`layout`, `ui`, `form` or `data`) |
| Is it logic, a client, a hook or a helper with no screen? | `lib/` |
| Is it a route (a URL)? | `app/` and it stays thin |
| Is it only used by one module today, but looks generic? | Leave it in the module. Move it when a second module needs it |

### 3.3 File names (proposal for `HRIS_NAMING_CONVENTION.md` section 5)

Observed in `modules/org` today, recorded here as the rule (Assumption until F6):

| Item | Rule | Example |
|---|---|---|
| React component file | PascalCase, one main component per file | `OrgTreeExplorer.tsx`, `JobDialog.tsx` |
| Helper, query, type, hook files | camelCase | `queries.ts`, `unitTree.ts`, `useAsOfLoad.ts` |
| Hook | starts with `use` | `usePermissions` |
| Route files | Next.js names: `page.tsx`, `layout.tsx` | `app/(app)/org/page.tsx` |
| Module folder | the module code in lowercase | `modules/org` |
| Module files every module has | `components/`, `loaders.ts`, `queries.ts`, `types.ts`, `permissions.ts`, `nav.ts`, `public.ts` | |
| Permission constants | `PERM_<AREA>_<THING>` in the module's `permissions.ts` | `PERM_JOB_WRITE` |
| Imports | the `@/` alias, never long relative paths across folders | `@/lib/dates` |

---

## 4. Rules between folders

| Folder | May import | May not import |
|---|---|---|
| `app/` | `components`, `lib`, `config`, any module's `loaders.ts` and views | |
| `config/` | each module's `nav.ts` | |
| `modules/<x>/` | `components`, `lib`, its own files, another module's `public.ts` only | another module's other files |
| `components/` | `lib` | `modules`, `app` |
| `lib/` | nothing of this project except generated types | `components`, `modules`, `app` |

- **Enforced, not just agreed:** an ESLint `no-restricted-imports` rule blocks the forbidden paths, so `npm run lint` fails on a violation (set up in step F5, `FND-D04`).
- **Why `public.ts`:** the Platform "Give role" dialog needs an org unit picker and Employees will need one too. ORG exports `OrgUnitPicker` and `DepartmentPicker` from `modules/org/public.ts`. Other modules import only that file. It is the frontend side of the Blueprint's "Public contract".
- **Direction at screen level:** `PLT` screens may import ORG's `public.ts`. ORG never imports `PLT` (it uses `lib/permissions.ts` and the database).

---

## 5. The shell

**What it holds (built once):**
- **Sidebar** (desktop, collapsible, drawer on small screens, `FND-D08`) with one entry per module from `config/navigation.ts`.
- **Topbar:** the **scope selector**, the EN / ខ្មែរ switch, and the user menu with sign out. These move out of `OrgConfigView.tsx`.
- **Page header** and **section tabs** that each module uses for its own sections (today's ORG tabs use the same component).
- **Sign-in check, user, scope and permissions** are loaded once in `app/(app)/layout.tsx` and given to every page.

**A module's menu entry** (`modules/<code>/nav.ts`) says four things: label, route, icon (from `lucide-react`) and the permission code that shows it. Adding a module to the menu is adding one entry. Entries the user may not use are hidden, never shown disabled.

### 5.1 Work scope (replaces the single company selector, `FND-D06`)

The user chooses **where they work** once, in the topbar. The answers of 2026-11-07:

| Rule | Decision |
|---|---|
| What it is | A multi-select tree of the org structure: Parent company, Business Unit, Branch, Division. The position tree (Departments) is not part of it |
| What a selection covers | The unit **and everything below it**. A Branch covers its Divisions. A Business Unit covers its Branches and Divisions. A Parent company covers all its units (`FND-D06`) |
| What the user can choose from | Only where they hold an assignment, and everything below it. Tenant-wide: everything. Company scope: that company. Org unit scope: that unit and below. **The parents above their access are hidden** (a Branch user sees the tree starting at their Branch) |
| Several companies at once | Allowed for lists and reports. Screens that change company-level setup (ORG Configuration, Position tree, Jobs) need exactly one company and ask the user to pick one |
| Default | The last selection, remembered in a cookie. First visit: everything the user may access |
| Writes | A write action uses the exact unit or target of that action, never the multi-selection |

**How it is built (Assumption, checked in F0 and F2):**
- The selection is stored in a cookie so the server knows it. Pages load only the selected scope, which also removes the "all companies share one 1000-row limit" note on ORG.
- **The cookie is never trusted.** The server checks every unit in it against what the user may access and ignores the rest. A tampered cookie can show nothing more than the user could already see.
- Access to data is enforced in the database per module (`PLT-D10`). Until a module has its own read code (ORG reads are open to every tenant member), the selector only narrows the screen.
- **Two steps:** step F2 builds the selector on the existing views (`parent_companies`, `org_units_current`), so it first lists all units. PLT Stage 2 adds `public.get_my_scope` (the companies and org units the user's assignments cover), and the selector then switches to it. This keeps the Foundation Stage free of database work.
- ORG tabs and the scope: Org tree, Headcount and Department listings follow the selected scope. Configuration, Position tree and Jobs need one company. The Allocation form always works on one org unit.
- **Open (`FND-Q09`):** what a user with only a **Department** scope sees in the selector. A Department is in the position tree, not the org tree.

**Module sections:** new modules use one route per section (for example `/employees/contracts`), so each section has its own address and loads only its data. ORG stays as one page with tabs during the Foundation Stage and is split only if needed (`FND-D05`).

**Styling:** Tailwind 4 and `lucide-react` only, no UI library (`FND-D07`). Colours are named once in `globals.css` (primary, danger, warning, surface, border, text) instead of fixed grey values in every component. Khmer text gets its own font in the root layout.

---

## 6. What moves out of ORG, and when

| Today | Goes to | When |
|---|---|---|
| Header of `OrgConfigView.tsx` (company selector, language switch, sign out) | `components/layout/` (`ScopeSelector`, `LanguageSwitch`, `UserMenu`) and `lib/context/` | Foundation Stage |
| `Modal.tsx` | `components/ui/Modal.tsx` | Foundation Stage |
| `RowLimitWarning.tsx` | `components/ui/LimitWarning.tsx` | Foundation Stage |
| `AsyncSelect.tsx` | `components/form/AsyncSelect.tsx` | Foundation Stage |
| `AsOfDatePicker.tsx` | `components/data/AsOfDatePicker.tsx` | When a second module has history views |
| `HistoryToggle.tsx` | `components/data/HistoryToggle.tsx` (the Moves mode stays an ORG extra) | Same |
| `CascadeSelector.tsx` | `components/form/CascadeSelector.tsx` | When a second module needs a cascade |
| `limits.ts` and `LimitedRows` | `lib/limits.ts` | Foundation Stage |
| `useAsOfLoad.ts` | `lib/hooks/useLoad.ts` | Foundation Stage |
| `checkPermissions`, `usePermissions` from `permissions.ts` | `lib/permissions.ts`. The `PERM_` codes stay in `modules/org/permissions.ts` | Foundation Stage |
| `writeError`, `rpcWriteError` from `queries.ts` | `lib/errors.ts` | Foundation Stage |
| Data loading and narrowing in `app/page.tsx` | `modules/org/loaders.ts`. `app/(app)/org/page.tsx` becomes a few lines and reads the selected scope | Foundation Stage |
| Everything else in `modules/org` (all `Closed*`, `AsOf*`, dialogs, `OrgTreeExplorer`, `unitTree.ts`, `labels.ts`, `types.ts`, queries) | stays | |

---

## 7. Decisions

Answered on 2026-11-07. IDs follow `HRIS_NAMING_CONVENTION.md` (`<MODULE>-D..`, module `FND`). The earlier draft IDs `FE-Q01` to `FE-Q08` map to `FND-D01` to `FND-D08`.

| ID | Decision | Origin |
|---|---|---|
| `FND-D01` | Routes in plain words (`/org`, `/platform`, `/employees`). Module folders keep the code | Adopted |
| `FND-D02` | Two route groups: `(auth)` for sign-in pages without the shell, `(app)` for everything with the shell | Adopted |
| `FND-D03` | Four shared component folders: `layout`, `ui`, `form`, `data` | Adopted |
| `FND-D04` | A module uses another module only through `modules/<code>/public.ts`, enforced by an ESLint rule | Adopted |
| `FND-D05` | New modules: one route per section. ORG keeps its tabs in one page for now | Adopted |
| `FND-D06` | Work scope selector in the topbar, section 5.1: multi-select tree (Parent company, Business Unit, Branch, Division), a selection covers the unit and everything below, only the user's assigned access is offered and parents above it are hidden, several companies allowed for lists and reports while company-level setup screens need one company, last selection remembered in a cookie (first visit: everything accessible). Replaces the single company selector | Your decision (extends the recommendation) |
| `FND-D07` | Tailwind and `lucide-react` only, colour names in `globals.css`, a separate Khmer font in the root layout | Adopted |
| `FND-D08` | Left sidebar, collapsible, drawer on small screens | Adopted |

**Open**

| ID | Question | Recommended | Blocks |
|---|---|---|---|
| `FND-Q09` | What does a user with only a **Department** scope see in the scope selector? | They see the org structure of their company as selectable (the Department decides which allocations they may change, `private.has_permission` still checks every write). The alternative is to show only the org units where their Department is listed | PLT Stage 2 (`get_my_scope`) |

---

## 8. Foundation Stage (small steps, each validated before the next)

Do after PLT Stage 1 (database only). Before PLT Stage 2 (first screens).

| Step | Does | Check |
|---|---|---|
| F0 | Read the Next.js guides in `node_modules/next/dist/docs/` for route groups, nested layouts, cookies and `proxy.ts`. Confirm the file naming of section 3.3 | Notes recorded |
| F1 | Root layout cleanup (title, fonts including Khmer, colour names). Add `(auth)` and `(app)`, move `login` | `npm test` and sign in works |
| F2 | Build the shell (sidebar, topbar, language switch, scope selector on the existing views with all units, cookie) with ORG as the only menu entry | Browser: menu, scope selection, sign out |
| F3 | Move the ORG page to `app/(app)/org`, move the loading code to `modules/org/loaders.ts` (reads the selected scope), remove the header from `OrgConfigView.tsx` | Browser: every ORG tab still works with one company and with several |
| F4 | Move the shared files of section 6 and fix imports | `npm test`, `npm run lint`, browser |
| F5 | Add the import rules to `eslint.config.mjs` | `npm run lint` passes and a test violation fails |
| F6 | Record the result: folder tree, rules and file names into `HRIS_NAMING_CONVENTION.md` (section 5), `HRIS_PROJECT_OVERVIEW.md` (section 3), the ORG Status file list, the ORG Frontend Reference, and a Frontend Foundation row in the module register | Documents updated |

Files needed from you for F1 to F4: `OrgConfigView.tsx`, `Modal.tsx`, `AsyncSelect.tsx`, `permissions.ts`, `queries.ts` (error mapping part), `app/login/page.tsx`, `proxy.ts`, `eslint.config.mjs`.

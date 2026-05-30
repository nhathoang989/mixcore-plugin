---
name: mix-mcp-build-site
description: Build a complete website with Mixcore CMS using a phased, documented plan — clarifies requirements and proposes a site outline first (unless "auto" is requested), then executes requirements analysis, MixDB schema, master layout, modules, pages, secondary pages, and forms across 7 sequential phases with progress tracking. Wiki documentation is produced automatically by the CRUD→wiki RAG pipeline — no manual wiki phase.
argument-hint: "[analyze|plan|phase-1|phase-2|phase-3|phase-4|phase-5|phase-6|phase-7] [site-name or requirement description]"
---

You are building a complete website with **Mixcore CMS** using a **phased, documented, requirements-driven approach**.

> **Implementation tools**: Invoke `mixcore:mix-mcp-cms` before any template/content/MCP work. Invoke `mixcore:mix-mcp-db` before any schema/column/relationship work.

---

## Invocation Mode — Clarify First or Auto-Complete

**Check whether the user asked for auto-complete before doing anything else.**

Auto-complete is requested when the user's message includes any of:
`auto`, `auto-complete`, `just do it`, `go ahead`, `skip questions`, `no questions`, `proceed automatically`

### If NOT in auto-complete mode → Clarify & Suggest (REQUIRED)

Do NOT create any files or call any MCP tools yet. Instead, present a structured clarification + suggestion reply:

**1. Summarise what you understood** (2–3 sentences max). State the site type, brand/name if given, and the primary goal.

**2. Ask focused clarifying questions** — use `AskUserQuestion` with 2–4 targeted questions. Pick only what is still unknown or ambiguous. Common gaps:

| Topic | Example question |
|---|---|
| Target audience | "Who is the primary visitor — consumers, businesses, or internal staff?" |
| Content types | "What dynamic content will the site have? (e.g. blog posts, products, team members, testimonials)" |
| Forms | "Which forms are needed — contact, newsletter, registration, or none?" |
| Pages | "What are the main pages besides Home? (e.g. About, Services, Pricing, Blog, Portfolio)" |
| Features | "Any special requirements — multi-language, member portal, e-commerce, or none?" |
| Design style | "Any brand colours, fonts, or design references to follow?" |

**3. Propose a site plan outline** before waiting for answers — show the user what you _plan_ to build based on what you know, so they can correct or confirm:

```
**Proposed plan for [Site Name]:**
- Pages: Home, About, [inferred pages]
- Content types: [inferred MixDB tables]
- Modules: [Hero, Services grid, Testimonials …]
- Forms: [Contact form, Newsletter …]
- Features: [anything special detected]

If this looks right, reply "go ahead" and I'll start planning.
To adjust any part, answer the questions above or just tell me what to change.
```

**4. Wait for user confirmation** before writing any planning documents or calling any MCP tools. Do NOT proceed to Step 1 until the user approves the outline or says to go ahead.

### If IN auto-complete mode → Skip straight to Step 1

Proceed immediately to Step 1 — Requirements Analysis & Planning Documents — using all context already provided by the user.

---

## Agent Protocol

**Before starting ANY phase:**
1. Read `wwwroot/mixcontent/planning/progress-tracker.md` — verify the previous phase is ✅ Complete
2. Read `wwwroot/mixcontent/planning/requirements-analysis.md` and the phase-specific instruction file
3. Invoke the relevant sub-skill (`mixcore:mix-mcp-cms` or `mixcore:mix-mcp-db`) for that phase's work

**After completing EACH phase:**
1. Update `wwwroot/mixcontent/planning/progress-tracker.md` with status ✅ Complete, completion date, all generated IDs/names, and notes
2. Record MCP-generated IDs (templateId, layoutId, module IDs, table names) — future phases depend on them

**MCP-first execution (non-negotiable):**
- **ALL content creation, schema changes, and data operations MUST go through MCP tools** — `CreateTemplate`, `CreatePageContent`, `CreateModuleContent`, `CreateRow`, `CreateMixDbTableFromPrompt`, etc.
- **NEVER use Edit, Write, or any file-system tool** to create or modify templates, content, or database records during plan execution. Direct file edits bypass the CMS engine and break routing, caching, and ID tracking.
- Planning documents (`wwwroot/mixcontent/planning/*.md`) are the only files you may write directly with file tools — everything else is MCP.

**CSS @ escaping rule (all phases):** In MCP `content` parameters, escape ALL CSS at-rules: `@@media`, `@@keyframes`, `@@font-face`. Never use bare `@media` inside MCP strings.

**Razor template rules (all phases):**
- **`fileName` MUST include the `.cshtml` extension** — the CMS stores `FileName` exactly as passed and builds `TemplateFilePath = /{FileFolder}/{FileName}`. A missing extension causes a "template not found" error at runtime.
  - ✅ `fileName: "HomePage.cshtml",  extension: ".cshtml"`
  - ❌ `fileName: "HomePage"` — runtime error: partial view not found
- **Extension is always `.cshtml`** — never `.html`, `.razor`, or any other extension. Pass both `fileName: "Name.cshtml"` AND `extension: ".cshtml"` to every `CreateTemplate` / `UpdateTemplate` call.
- **C# variable declarations inside `@{ }` blocks must NOT wrap the value in `@(...)`**. The `@(...)` syntax is for inline output in HTML; inside a code block it is a syntax error.
  - WRONG: `var iId = @(item.Get<int>("id", 0));`
  - RIGHT:  `var iId = item.Get<int>("id", 0);`

---

## Phase Overview

| Phase | Name | Skill | Key Output |
|---|---|---|---|
| 1 | Database & Theme Setup | `mixcore:mix-mcp-db` | MixDB tables seeded, IDs recorded |
| 2 | Master Layout | `mixcore:mix-mcp-cms` | Master template created, layoutId recorded |
| 3 | Module Templates & Content | `mixcore:mix-mcp-cms` | Module templates + content instances, systemNames recorded |
| 4 | Main Pages | `mixcore:mix-mcp-cms` | Home, About, Services, Contact pages created/updated |
| 5 | Secondary Pages | `mixcore:mix-mcp-cms` | Blog listing, category, detail pages |
| 6 | Forms & Widgets | `mixcore:mix-mcp-cms` + `mixcore:mix-mcp-db` | Contact form, newsletter, sidebar widgets |
| 7 | Verify & Fix | `mixcore:mix-mcp-cms` + browser | All pages render correctly, bugs fixed |

> Wiki documentation is produced automatically: content created through the MCP tools is mirrored into the site wiki and indexed by the CRUD→wiki RAG pipeline. There is no manual wiki phase.

---

## Step 1 — Requirements Analysis & Planning Documents

Create all planning documents **before executing any phase**. These documents are the source of truth for all subsequent phases.

### 1a. `wwwroot/mixcontent/planning/requirements-analysis.md`

```markdown
# Requirements Analysis

## Core Business Context
- **Website Type:** [Corporate / E-commerce / Blog / Portfolio / SaaS]
- **Company/Brand:** [Name]
- **Industry:** [Sector]
- **Target Audience:** [Primary visitors]

## Scope Definition

### Required Pages
- Home — hero, features, CTA
- About — company story, team
- [Add more as needed]

### Required Features
- [Feature 1: description]
- [Feature 2: description]

### Content Types (→ MixDB tables)
- [Products / Blog Posts / Services / Team Members / Testimonials]

### Forms Needed
- [Contact / Newsletter / Registration]

### Special Requirements
- [Multi-language / Member portal / E-commerce]
```

### 1b. `wwwroot/mixcontent/planning/mixdb-schema.md`

Document every table that needs to be created. Always use `BrandName` prefix in display names.

```markdown
# MixDB Schema

## Table: [BrandName] Products
**Display Name:** BrandName Products
**System Name:** (auto-generated as <site_name>_products)
**Detail Page:** Yes — `/products/{id}` (needs folderType=Data template)

| Column | Type | Required | Notes |
|--------|------|----------|-------|
| name | String | Yes | Product name |
| price | Double | Yes | |
| description | MultilineText | No | |
| image_url | String | No | Full public URL |
| is_active | Boolean | No | Default: true |

## Relationships
- Products → Categories (OneToMany)
```

> For each table, set **Detail Page:** to `Yes — <url-pattern>` (Phase 1 will create a `folderType="Data"` template + attach via `templateId` / `layoutId`) or `No` (skip).

> See `mixcore:mix-mcp-db` skill for `CreateMixDbTableFromPrompt` parameter format and relationship rules.

### 1c. `wwwroot/mixcontent/planning/site-architecture.md`

```markdown
# Site Architecture

## Page Hierarchy
- / (Home) — templateId: TBD, layoutId: TBD
- /about — templateId: TBD
- /services — templateId: TBD
- /blog — templateId: TBD
- /contact — templateId: TBD

## Navigation Structure
Primary: Home | About | Services | Blog | Contact
Footer: Privacy | Terms

## Module Dependencies
- hero-banner → Home page
- services-grid → Home + Services page
- testimonials → Home + About page
- newsletter-signup → Footer (widget)

## Template FolderType Map
- Masters: MasterLayout
- Pages: HomePage, StandardPage, BlogListPage, BlogPostPage, ContactPage
- Modules: HeroBanner, ServicesGrid, Testimonials, TeamGrid
- Forms: ContactForm, NewsletterForm
- Widgets: NewsletterWidget, RecentPostsWidget
- Data: ProductDetail, BlogPostDetail   ← only for tables with a "Detail Page: Yes" flag in mixdb-schema.md
```

### 1d. `wwwroot/mixcontent/planning/progress-tracker.md`

```markdown
# Progress Tracker

| Phase | Name | Status | Completed | Notes |
|-------|------|--------|-----------|-------|
| 1 | Database & Theme Setup | ⏳ Pending | | |
| 2 | Master Layout | ⏳ Pending | | |
| 3 | Modules | ⏳ Pending | | |
| 4 | Main Pages | ⏳ Pending | | |
| 5 | Secondary Pages | ⏳ Pending | | |
| 6 | Forms & Widgets | ⏳ Pending | | |
| 7 | Verify & Fix | ⏳ Pending | | |

## Generated IDs
<!-- Record all MCP-generated IDs here as each phase completes -->
- layoutId (Master): TBD
- templateId (Home): TBD
- moduleId (HeroBanner): TBD
```

---

## Steps 2–8 — Generate Phase Instruction Files

Create `wwwroot/mixcontent/planning/phase-N-*.md` files before executing. Each file is read by the agent at phase start.

### `wwwroot/mixcontent/planning/phase-1-setup.md` — Database & Theme Setup

**Invoke `mixcore:mix-mcp-db` skill first.**

Tasks:
1. Create all MixDB tables from `mixdb-schema.md` using `CreateMixDbTableFromPrompt`
2. For each table: call `GetMixDbBySystemName(includeColumns: true)` to confirm exact system names and column names — record in progress-tracker
3. Create relationships using `CreateMixDbRelationshipFromPrompt` (display names, not system names)
4. Seed initial data with `CreateRow` for each table (3–5 realistic records, full public image URLs)
5. Verify data with `QueryTable`
6. **(Optional) Record-detail templates** — for each table flagged in `mixdb-schema.md` as needing a per-record detail page (e.g. `/products/{id}`, `/blog-posts/{slug}`):
   - `CreateTemplate(folderType: "Data", fileName: "<TableName>Detail.cshtml", extension: ".cshtml")` — use `@model dynamic` + `@inject Mix.DataSource.Interfaces.IMixDbDataService db`; reference columns via `@(Model.Get<T>("column_name"))`.
   - Attach with `UpdateMixDbTable(systemName: "<table>", templateId: <returnedId>, layoutId: <masterLayoutId-from-phase-2>)`. If you create the template before Phase 1 runs, pass `templateId` / `layoutId` directly to `CreateMixDbTableFromPrompt` or `CreateMixDbTable` instead.
   - Tables that only feed lists/cards inside other pages or modules **don't need a Data template** — skip them.
   - Record the `templateId` per table in progress-tracker.

### `wwwroot/mixcontent/planning/phase-2-layout.md` — Master Layout

**Invoke `mixcore:mix-mcp-cms` skill first.**

Tasks:
1. `ListTemplates(folderType: "Masters")` — check if master already exists
2. `CreateTemplate(folderType: "Masters", fileName: "MasterLayout.cshtml", extension: ".cshtml")`:
   - Must include exactly ONE `@RenderBody()`, ONE `@RenderSection("Styles", false)`, ONE `@RenderSection("Scripts", false)`
   - Include `<!--[STYLES]-->` comment before Styles section
   - Include Bootstrap 5 CDN, Font Awesome
   - Navigation links from `site-architecture.md`
   - Footer with newsletter form hook
3. Record returned `layoutId` in progress-tracker

### `wwwroot/mixcontent/planning/phase-3-modules.md` — Module Templates & Content

**Invoke `mixcore:mix-mcp-cms` skill first.**

Tasks (for each module in `site-architecture.md`):
0. **Check before create** — call `ListTemplates(folderType: "Modules")` and `ListModules` to detect existing templates and module content instances before creating anything.
1. `CreateTemplate(...)` or `UpdateTemplate(id, ...)` for the module template.
   - Model: `@model Mix.Rendering.ViewModels.ModuleContentViewModel` (or `@model dynamic` for MixDB-driven)
   - For MixDB-driven modules: verify schema columns from phase-1 before writing template code
2. `CreateModuleContent(...)` or `UpdateModuleContent(id, ...)` — verify templateId has `folderType="Modules"` first
3. Record each module's `id` and `systemName` in progress-tracker

### `wwwroot/mixcontent/planning/phase-4-main-pages.md` — Main Pages

**Invoke `mixcore:mix-mcp-cms` skill first.**

**Pre-planning audit (do this BEFORE generating the phase-4 file):**
Call `ListPageContents` (or `mcp__mixcore__list_page_contents`) to retrieve ALL existing pages. Record in the phase-4 file which pages exist with their current IDs. A fresh Mixcore install always has a Home page — never assume the site is empty.

Tasks (for each main page):
0. **Check before create** — use the pre-planning audit results (above) to determine whether the page already exists.
   - If the page **exists**: call `UpdatePageContent(id: <existing-id>, ...)` — never create a duplicate.
   - If the page **does not exist**: proceed with `CreatePageContent`.
   - The Home page (`seoName: "home"` or `seoName: ""`) **almost always exists** — default to Update unless the audit proves otherwise.
1. `CreateTemplate(folderType: "Pages", fileName: "[PageName].cshtml", extension: ".cshtml")` — **fileName must include `.cshtml`** — or `UpdateTemplate(id)` if the template already exists (check with `ListTemplates`).
   - Model: `@model Mix.Rendering.ViewModels.PageContentViewModel`
   - Never include `@{ Layout = "..." }` — layout set via `layoutId` at content creation
   - Render associated modules with `Model.Modules.OrderBy(m => m.Priority)` loop + try-catch
2. `CreatePageContent(...)` or `UpdatePageContent(id, ...)` based on step 0 result; always pass `layoutId: <master layoutId from phase-2>`.
3. `CreatePageModuleAssociation(pageId, moduleId)` for each module dependency
4. Record page IDs (including pre-existing ones) in progress-tracker

### `wwwroot/mixcontent/planning/phase-5-secondary-pages.md` — Secondary Pages

**Invoke `mixcore:mix-mcp-cms` skill first.**

Tasks:
- Blog listing page: queries MixDB posts with `IMixDbDataService` in template
- Blog post page: uses `@model Mix.Rendering.ViewModels.PostContentViewModel`
- Category pages: filter by `category_id` via `SearchMixDbRequestModel`
- Each page: same template → content → association flow as phase 4

### `wwwroot/mixcontent/planning/phase-6-forms.md` — Forms & Widgets

**Invoke `mixcore:mix-mcp-cms` skill first.**

Tasks:
1. **Forms** — `CreateTemplate(folderType: "Forms")`:
   - Model: `@model dynamic` (mandatory)
   - `<form class="frm-mixdb-ajax" data-mixdb-table="<site_name>_contacts">` (both attributes mandatory)
   - Verify the target MixDB table exists (created in phase 1)
   - **Numeric columns** (`Double`, `Integer`): the `frm-mixdb-ajax` handler must coerce `FormData` strings to JS numbers before `JSON.stringify`, or PostgreSQL raises error 42804 (`column "x" is of type double precision but expression is of type text`). Use `/^-?\d+(\.\d+)?$/.test(v) ? parseFloat(v) : v` in the `forEach` loop. See `mixcore:mix-mcp-cms/references/form-templates.md` § Numeric fields.
2. **Widgets** — `CreateTemplate(folderType: "Widgets")`:
   - Model: `@model dynamic` (default) or `ModuleContentViewModel` when passed from parent
   - Keep focused and single-purpose (newsletter, recent posts, search bar)
3. Associate forms/widgets with pages via `CreatePageModuleAssociation`

### `wwwroot/mixcontent/planning/phase-7-verify.md` — Verify & Fix

**Invoke `mixcore:mix-mcp-cms` skill first. Use Playwright browser tools if available.**

Goal: confirm every page renders without errors in the browser and that all module associations, data queries, and form submissions work as expected.

Tasks:
1. **Enumerate all pages** — call `ListPageContents` and collect the URL slug for every page created in phases 4–6.
2. **Find the correct verification URL** — read `.mcp.json` in the repo root and use the `url` value from the `mixcore` server entry (e.g. `http://localhost:58245`). The Mixcore site and MCP server share the same host/port. Do NOT assume `localhost:5000` or `localhost:5001`. Then navigate `<base-url>/<slug>` and take a screenshot with `browser_take_screenshot`. Check:
   - Page loads with HTTP 200 (no redirect loop, no 404, no 500)
   - Master layout renders (nav, footer visible)
   - All module regions are populated — no blank or `[object Object]` output
   - Images display (not broken)
   - Razor template errors: look for yellow ASP.NET error pages or stack traces
3. **Verify forms** — for each form (phase 6), submit a test entry and confirm:
   - No 500 from type mismatch (especially numeric columns — see phase-6 numeric coercion rule)
   - Row appears in MixDB via `QueryTable`
4. **Fix any issues found** — apply fixes using MCP tools only:
   - Template errors → `UpdateTemplate(id, content: <fixed content>)`
   - Missing module → `CreatePageModuleAssociation`
   - Wrong layout → `UpdatePageContent(id, layoutId: <correct id>)`
   - Broken data query → correct the Razor template filter expression
5. **Re-verify after each fix** — navigate the page again and confirm the issue is resolved.
6. **Update progress-tracker** — record Phase 7 as ✅ Complete with a summary of issues found and fixed (or "no issues found").

> **No manual wiki phase.** Content created through the MCP tools during phases 1–7
> (pages, modules, posts, MixDB rows) is mirrored into the tenant site wiki and indexed
> automatically by the CRUD→wiki RAG pipeline (`RagImportNotificationHandler` →
> `RAGImportSubscriber` → `SiteWikiWriter`). If you want a hand-authored overview doc,
> use `generate_document` (load **`mixcore:mix-mcp-rag`**) — it writes and indexes atomically.

---

## Step 9 — Generate Execution Prompt Files

Create one file per phase in `wwwroot/mixcontent/planning/prompts/`. Each file is the exact prompt to paste for that phase.

### Template for each execution prompt file:

```
Execute Phase N: [Phase Name]

**CRITICAL PRE-CHECKS (read all before touching any MCP tool):**
- Read wwwroot/mixcontent/planning/progress-tracker.md — verify Phase N-1 is ✅ Complete
- Read wwwroot/mixcontent/planning/requirements-analysis.md
- Read wwwroot/mixcontent/planning/mixdb-schema.md (phase 1 only)
- Read wwwroot/mixcontent/planning/phase-N-[name].md

**SKILLS TO INVOKE FIRST:**
- mixcore:mix-mcp-db (phases 1, 6 if new tables needed)
- mixcore:mix-mcp-cms (phases 2–7)

**EXECUTION:**
Follow ALL instructions in phase-N-[name].md exactly.
Record all generated IDs and system names in wwwroot/mixcontent/planning/progress-tracker.md.
Update Phase N status to ✅ Complete with today's date upon completion.
```

**Phase 7's prompt is special — paste it verbatim:**

```
Execute Phase 7: Verify & Fix

**PRE-CHECKS:**
- Read wwwroot/mixcontent/planning/progress-tracker.md — verify Phases 1–6 are all ✅ Complete
- Read wwwroot/mixcontent/planning/phase-7-verify.md
- Read wwwroot/mixcontent/planning/site-architecture.md (for the full page list)

**SKILLS TO INVOKE FIRST:**
- mixcore:mix-mcp-cms

**EXECUTION:**
1. Call ListPageContents to enumerate every page.
2. For each page: navigate to it, screenshot it, and check for errors.
3. Verify all forms submit without errors.
4. Fix any issues found using MCP tools only (UpdateTemplate, UpdatePageContent, etc.).
5. Re-verify each fix.
6. Update wwwroot/mixcontent/planning/progress-tracker.md — Phase 7 ✅ Complete with issues-found/fixed summary.
```

---

## Content & Design Guidelines (All Phases)

| Concern | Standard |
|---|---|
| **Writing style** | Professional, technical yet accessible, active voice |
| **SEO** | Meta descriptions 150–160 chars, semantic HTML5, schema.org markup |
| **Primary color** | `#007bff` |
| **Secondary color** | `#6c757d` |
| **Success color** | `#28a745` |
| **Accent** | `#667eea` |
| **Typography** | System font stack |
| **Responsive** | Mobile `<768px`, Tablet `768–991px`, Desktop `≥992px` |
| **Images** | Full public URLs only (`https://images.unsplash.com/...`) — no relative paths |
| **CSS escaping** | All `@media`, `@keyframes`, `@font-face` must be `@@media`, `@@keyframes`, `@@font-face` in MCP content strings |

---

## Critical Rules (All Phases)

- **Execute via MCP tools only — never Edit/Write files for CMS content, templates, or database rows**
- **`fileName` MUST include `.cshtml`** — pass `fileName: "MyTemplate.cshtml"` (not `"MyTemplate"`) to every `CreateTemplate` call. The CMS builds `TemplateFilePath = /{FileFolder}/{FileName}` — a missing extension causes a "partial view not found" error at runtime. Also always pass `extension: ".cshtml"` as a separate parameter.
- **No `@(...)` inside `@{ }` code blocks** — `@(expr)` is HTML output syntax; inside a code block write the expression directly: `var x = item.Get<int>("id", 0);` not `var x = @(item.Get<int>("id", 0));`
- **Check before create** — for every page, template, module, and MixDB table: call the corresponding `Get`/`List` MCP tool first. If the item already exists, call `Update*` instead of `Create*`. Never create duplicates; the Home page (`seoName: "home"`) in particular almost always exists in a fresh Mixcore install.
- **Never start a phase without reading `wwwroot/mixcontent/planning/progress-tracker.md` first**
- **Always record MCP-generated IDs immediately** — templateId, layoutId, moduleId, table systemNames are needed by later phases
- **Template folderType must match content type**: Pages → `"Pages"` template, Modules → `"Modules"` template, Posts → `"Posts"` template, Masters → `"Masters"` template
- **Verify template IDs before creating content**: call `GetTemplate(id)` and confirm folderType matches
- **Never use `filterJson: {"key":"value"}`** — use array format `[{"fieldName":"...","value":"...","operator":"="}]`
- **`QueryRows` requires `dataSourceName`** — use `QueryTable` for internal MixDB tables
- **`CreateRow`/`UpdateRow` auto-index to RAG** — no separate indexing step needed
- For all other implementation rules, see `mixcore:mix-mcp-cms` skill (Razor syntax, MixDB queries, module rendering)

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

**🚨 Framework requests (React, Vue, Angular, Next.js, Svelte, etc.):** If the user mentions any external frontend framework, do NOT install or configure that framework. Explain that Mixcore will build the same site natively using Razor templates, MixDB tables, and CMS modules — achieving the same result without the framework's complexity. Only if the user insists after this explanation, route to `mixcore:mix-mcp-spa` to deploy their pre-built SPA.

**2. Ask focused clarifying questions** — use `AskUserQuestion` with 2–4 targeted questions. Pick only what is still unknown or ambiguous. Common gaps:

| Topic | Example question |
|---|---|
| Target audience | "Who is the primary visitor — consumers, businesses, or internal staff?" |
| Content types | "What dynamic content will the site have? (e.g. blog posts, products, team members, testimonials)" |
| Forms | "Which forms are needed — contact, newsletter, registration, or none?" |
| Pages | "What are the main pages besides Home? (e.g. About, Services, Pricing, Blog, Portfolio)" |
| Features | "Any special requirements — multi-language, member portal, e-commerce, or none?" |
| Design style | "Any brand colours, fonts, or design references to follow?" |

**Planning Principles — apply these 3 rules before proposing any site outline:**

1. **Break pages into manageable sections — when applicable.** For each page, ask: "Does this page have multiple distinct visual/functional sections?" If yes, split into reusable modules instead of one monolithic template. Modules are independently editable, reorderable, and reusable across pages. Simple pages (e.g. Privacy Policy, single-column text) don't need decomposition.

2. **Repetitive content belongs in MixDB tables.** If the same kind of content appears in multiple places (team members, testimonials, services, pricing tiers, portfolio items), create a MixDB table for it. Tables give you: centralized editing (change once, update everywhere), list/detail pages for free, and the `IMixDbDataService` API for filtering/sorting in templates. Ask: "Does this content repeat? Will it need to be updated over time?" If yes → table.

3. **Every form needs a database table + a form template.** A contact form without a database is a black hole — submissions are lost. For every form on the site: (a) create a MixDB table to store submissions (columns match form fields), (b) create a `folderType="Forms"` template with `class="frm-mixdb-ajax"` that POSTs to that table, (c) verify the form submits and the row lands in MixDB during Phase 7. This applies to contact forms, newsletter signups, registrations, surveys — any `<form>` the user fills out.

**3. Propose a site plan outline** before waiting for answers — show the user what you _plan_ to build based on what you know, so they can correct or confirm:

```
**Proposed plan for [Site Name]:**
- Pages: Home, About, [inferred pages]
- Content types: [inferred MixDB tables]
- Modules: [Hero, Services grid, Testimonials …]
- Forms: [Contact form, Newsletter …]
- Features: [anything special detected]

If this looks right, reply "go ahead" and I'll plan **and build** the whole site in one run.
To adjust any part, answer the questions above or just tell me what to change.
```

**4. Wait for user confirmation** before writing any planning documents or calling any MCP tools. Do NOT proceed to Step 1 until the user approves the outline or says to go ahead.

### If NOT in auto-complete mode → after the outline is approved, run everything to completion

**The clarification gate above is the ONLY stop.** Once the user approves the outline (or replies "go ahead"), proceed through Step 1 — Requirements Analysis & Planning Documents, then Steps 2–9, then continue **straight into Step 10 — Execute All Phases** — Steps 1–10 run continuously in the same session. **Do NOT stop a second time** to re-report the plan or wait for another "go ahead" before executing; writing the planning and prompt files is not the finish line, the built site is. Ask once, up front — then build the whole thing.

### If IN auto-complete mode → skip the gate, plan and execute all phases

Proceed immediately to Step 1 — Requirements Analysis & Planning Documents — using all context already provided by the user. **Do NOT stop after writing the planning and prompt files.** Once Steps 1–9 have produced the planning docs, phase instruction files, and prompt files, continue straight into **Step 10 — Execute All Phases** and run Phase 1 → Phase 7 in this same session. Auto-complete means "build the site," not "produce a plan."

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

**Template API reference (read before writing ANY template that queries MixDB):**
- `IMixDbDataService` methods: `GetRowsAsync(tableName, filter?)` → `IReadOnlyList<MixDbRow>`, `GetRowAsync(tableName, id)` → `MixDbRow`
- `MixDbRow` is a `readonly record struct` — use `.Get<T>("key")` or `.Get<T>("key", fallback)`, check `.IsEmpty` (not `== null`)
- `MixDbFilter.Where("field", value).And("field", value, ">")` — pass `null` for no filter
- **Don't call `SearchAsync` on `IMixDbDataService`** — no such method exists. (`SearchMixDbRequestModel` *does* exist in `mix.shared`, but it isn't used in Razor templates — use `GetRowsAsync`/`GetRowAsync` with `MixDbFilter` instead.)
- Full reference: `mixcore:mix-mcp-cms/references/mixdb-in-razor.md` — read BEFORE writing template code
- Every page template that queries data MUST include its own `@using Mix.DataSource.Models` + `@inject Mix.DataSource.Interfaces.IMixDbDataService db` — these do NOT inherit from the master layout

**CSS @ escaping rule (all phases):** In MCP `content` parameters, escape ALL CSS at-rules: `@@media`, `@@keyframes`, `@@font-face`. Never use bare `@media` inside MCP strings. **Double `@@` is ONLY for CSS at-rules (and literal `@` in CDN / scoped-npm URLs) — never double Razor directives** (`@model`, `@inject`, `@using`, `@if`, `@foreach`, `@Html.Raw`, `@Model.X`, `@(...)`): a doubled directive is emitted as literal text (`@model …` shows in the page) instead of executing.

**Razor template rules (all phases):**
- **`fileName` MUST include the `.cshtml` extension** — the CMS stores `FileName` exactly as passed and builds `TemplateFilePath = /{FileFolder}/{FileName}`. A missing extension causes a "template not found" error at runtime.
  - ✅ `fileName: "HomePage.cshtml",  extension: ".cshtml"`
  - ❌ `fileName: "HomePage"` — runtime error: partial view not found
- **Extension is always `.cshtml`** — never `.html`, `.razor`, or any other extension. Pass both `fileName: "Name.cshtml"` AND `extension: ".cshtml"` to every `CreateTemplate` / `UpdateTemplate` call.
- **C# variable declarations inside `@{ }` blocks must NOT wrap the value in `@(...)`**. The `@(...)` syntax is for inline output in HTML; inside a code block it is a syntax error.
  - WRONG: `var iId = @(item.Get<int>("id", 0));`
  - RIGHT:  `var iId = item.Get<int>("id", 0);`
- **Generic method calls inside HTML attributes MUST use `@(...)` wrapping** — the Razor parser sees `<int>` as an HTML tag. This causes CS1503 ("cannot convert from method group") at runtime.
  - WRONG: `value="@fbApp.Get<int>("id")"` → parser sees `<int>` as HTML tag → CS1503
  - RIGHT: `value="@(fbApp.Get<int>("id"))"` → explicit expression boundary
  - Also applies to any `@row.Get<T>()` directly followed by non-C# characters: `@job.Get<int>("x")s` → `@(job.Get<int>("x"))s`
  - Non-generic calls like `@fbApp.Get("key", "")` DON'T need wrapping (no angle brackets to confuse parser)

**Validate every `.cshtml` template server-side right after creating/updating it — BEFORE building page content or opening a browser.** Call `ValidateTemplate` (pass the `templateId` returned by `CreateTemplate`/`UpdateTemplate`, or raw `content` + `folderType` for pre-flight). It compiles the Razor server-side and returns `{ success, skipped, errors:[{ line, message, code }] }`, catching `CS1061`/`CS0234`/`CS1503`/`RZ*` errors in ~1s without the create-page → navigate → read-500 → fix loop. Workflow per template:
- `CreateTemplate(...)` → `ValidateTemplate(templateId: <new id>)` → if `success:false`, fix with `SearchReplaceTemplate`/`UpdateTemplate` and re-validate until green, THEN move on.
- In **Phase 1**, validate any optional `folderType="Data"` record-detail template right after creating it; in **Phase 2**, validate the master template before any page/module references it; in **Phases 3–6**, validate each template before creating the content instance that renders it. This front-loads compile errors so Phase 7 (browser) only finds runtime/data issues.
- `.liquid` templates return `skipped:true` (Razor compilation does not apply).

> 🚨 **Bind the real ViewModel — there is NO `ViewBag.Page`/`ViewBag.Post`/`ViewBag.Posts`.** The engine renders a template via `<partial model="@Model">`, so data arrives on `Model`, not `ViewBag`. Reading a `ViewBag.Post*` returns `null` and the list renders silently empty. Header each template with `@model Mix.Rendering.ViewModels.PageContentViewModel` (Pages — `Model.Content`, `Model.Posts?.Items`, `Model.Modules`), `PostContentViewModel` (Posts — `Model.Title/Content/Excerpt/Image/SeoName`), or `ModuleContentViewModel` (Modules). `@using Mixcore.Lib.*` is **not a real namespace** → `CS0234`; the correct one is `Mix.Rendering.ViewModels`. `ValidateTemplate` catches both the bad `@using` (`CS0234`) and the unknown type (`CS0246`) — which is why validating after every create/update is non-negotiable.

**Design quality rule (all template phases — 2, 3, 4, 5, 6):** Before generating or updating a template, check whether a frontend-design or UI design skill is available in this session (`frontend-design`, `ui-ux-pro-max`, `ui-styling`, or any skill whose description mentions UI / UX / frontend / design / styling). If one is available, invoke it first via the `Skill` tool and apply its layout, color, typography, and accessibility guidance to the markup. If none is available, proceed with this skill's conventions. See `mixcore:mix-mcp-cms` → "🎨 Design Quality" for the full rule. Output still goes only through MCP `CreateTemplate` / `UpdateTemplate`.

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

> **Validate-as-you-go:** every `.cshtml` template is compile-checked with `ValidateTemplate` immediately after each `CreateTemplate`/`UpdateTemplate` (phases 2–6) — fix `CS*`/`RZ*` errors and re-validate until `success:true` before building any content that renders it.

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

### Page Section Breakdown *(if pages have multiple distinct sections)*
<!-- Optional — only if a page benefits from being split into reusable modules.
     A simple text page (e.g. Privacy Policy) does not need this. -->
- [Page name]: [module-1, module-2, …] — or omit for simple pages

### Repetitive Content → MixDB Tables *(if content repeats across pages)*
<!-- Optional — only if the site has content that appears in multiple places or needs
     centralized editing. Skip for sites with purely static/one-off content. -->
- [Content type] — on [pages]; columns: [col1, col2, …] — or omit if none

### Content Types (→ MixDB tables)
- [Products / Blog Posts / Services / Team Members / Testimonials]

### Forms Needed:         [Contact / Newsletter / Registration — or none]
<!-- For each form: map to a MixDB table + folderType="Forms" template. Skip if no forms. -->

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
3. Create relationships using `create_relationship` (numeric table IDs `parentId`/`childId` — look up via `GetMixDbBySystemName`)
4. Seed initial data with `CreateRow` for each table (3–5 realistic records, full public image URLs)
5. Verify data with `QueryTable`
6. **(Optional) Record-detail templates** — for each table flagged in `mixdb-schema.md` as needing a per-record detail page (e.g. `/products/{id}`, `/blog-posts/{slug}`):
   - `CreateTemplate(folderType: "Data", fileName: "<TableName>Detail.cshtml", extension: ".cshtml")` — use `@model dynamic` + `@inject Mix.DataSource.Interfaces.IMixDbDataService db`; reference columns via `@(Model.Get<T>("column_name"))`. **Validate it immediately** — `ValidateTemplate(templateId: <returnedId>)` per the Agent Protocol rule; fix `CS*`/`RZ*` errors and re-validate until `success:true` before attaching it.
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
   - **Favicon** — generate a *suitable, brand-matched* SVG favicon (do NOT link a generic stock globe). Author a 32×32 `viewBox` SVG using the site's primary/accent colors — a monogram (brand initial) or a simple glyph that echoes the brand — then write it with `write_text_file(path: "generated-data/<site-slug>-favicon.svg", content: "<svg …>")`. TextFileTool paths are relative to `wwwroot/mixcontent/documents/`, so it is served at `/mixcontent/documents/generated-data/<site-slug>-favicon.svg`. Reference it in `<head>`: `<link rel="icon" type="image/svg+xml" href="/mixcontent/documents/generated-data/<site-slug>-favicon.svg" />`. This is self-contained with no third-party dependency. Example monogram SVG: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32"><rect width="32" height="32" rx="6" fill="#007bff"/><text x="16" y="22" font-family="system-ui,sans-serif" font-size="18" font-weight="700" text-anchor="middle" fill="#fff">M</text></svg>`. (A full `https://…` public PNG/ICO URL in `href` is an acceptable alternative, but the generated local SVG is the default — never a bare relative path that is not under `/mixcontent/…`.)
   - Navigation links from `site-architecture.md`
   - Footer with newsletter form hook
3. Validate the master template (`ValidateTemplate(templateId: <layoutId>)`) per the Agent Protocol rule before any page references it
4. Record returned `layoutId` in progress-tracker

**🚨 CRITICAL — Verify master compiles BEFORE building pages (Step 3.5):**
After creating the master template and at least one page that uses it, **immediately verify the master compiles without errors** before creating the rest of the pages:

1. Update the Home page to use the new master + a simple page template (or the default template id=2)
2. Navigate to the home page with Playwright OR fetch it with `curl -s <base-url>/`
3. **Check for compilation errors** — look for `CompilationFailedException`, `CS1061`, `CS0234`, `CS0023` in the response body
4. If the page returns HTTP 500 with Razor compilation errors: **fix the master template first**, re-verify, then proceed
5. Only after the master compiles clean → proceed to Phase 3 (creating page templates)

**Why this matters:** A single compilation error in the master layout breaks EVERY page. Fixing the master after creating 5+ pages means re-verifying all of them. One early browser check saves 4+ fix-and-retry cycles. See [[mixdb-razor-api-reference]] for the most common API mistakes (wrong method names, missing `@inject`/`@using` directives).

> 🚨 **A master RENDERS sections — it NEVER DEFINES them.** The master must contain **zero `@section` blocks**; use `@RenderSection("Seo"/"Styles"/"Scripts", false)` only. A `@section Seo { … }` definition in a master crashes every page at *render* with `InvalidOperationException: … sections … defined but … not rendered … 'Seo'` — and `ValidateTemplate` (compile-only) does **NOT** catch it, so the Phase 2 browser/curl check is what surfaces it. Put the master's own meta inline in `<head>`; section definitions belong only in the child host view. See `mixcore:mix-mcp-cms` → `references/razor-rules.md` §5.

### `wwwroot/mixcontent/planning/phase-3-modules.md` — Module Templates & Content

**Invoke `mixcore:mix-mcp-cms` skill first.**

Tasks (for each module in `site-architecture.md`):
0. **Check before create** — call `ListTemplates(folderType: "Modules")` and `ListModules` to detect existing templates and module content instances before creating anything.
1. `CreateTemplate(...)` or `UpdateTemplate(id, ...)` for the module template.
   - Model: `@model Mix.Rendering.ViewModels.ModuleContentViewModel` (or `@model dynamic` for MixDB-driven)
   - For MixDB-driven modules: verify schema columns from phase-1 before writing template code
   - Validate the template (`ValidateTemplate`) per the Agent Protocol rule before creating the module content instance
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
   - Validate the template (`ValidateTemplate`) per the Agent Protocol rule before creating the page content instance
2. `CreatePageContent(...)` or `UpdatePageContent(id, ...)` based on step 0 result; always pass `layoutId: <master layoutId from phase-2>`.
3. `CreatePageModuleAssociation(pageId, moduleId)` for each module dependency
4. Record page IDs (including pre-existing ones) in progress-tracker

### `wwwroot/mixcontent/planning/phase-5-secondary-pages.md` — Secondary Pages

**Invoke `mixcore:mix-mcp-cms` skill first.**

Tasks:
- Blog listing page: queries MixDB posts with `IMixDbDataService` in template
- Blog post page: uses `@model Mix.Rendering.ViewModels.PostContentViewModel`
- Category pages: filter by `category_id` via `MixDbFilter.Where("category_id", id)`
- Each page: same template → validate (`ValidateTemplate`) per the Agent Protocol rule → content → association flow as phase 4

### `wwwroot/mixcontent/planning/phase-6-forms.md` — Forms & Widgets

**Invoke `mixcore:mix-mcp-cms` skill first.**

Tasks:
1. **Forms** — `CreateTemplate(folderType: "Forms")`:
   - Model: `@model dynamic` (mandatory)
   - `<form class="frm-mixdb-ajax" data-mixdb-table="<site_name>_contacts">` (both attributes mandatory)
   - Verify the target MixDB table exists (created in phase 1)
   - **Numeric columns** (`Double`, `Integer`): the `frm-mixdb-ajax` handler must coerce `FormData` strings to JS numbers before `JSON.stringify`, or PostgreSQL raises error 42804 (`column "x" is of type double precision but expression is of type text`). Use `/^-?\d+(\.\d+)?$/.test(v) ? parseFloat(v) : v` in the `forEach` loop. See `mixcore:mix-mcp-cms/references/form-templates.md` § Numeric fields.
   - **🚦 Validate the form template** (do ALL of these before associating it — a form that "looks right" but fails any of these silently never saves):
     1. **Compile** — `ValidateTemplate(templateId)` → fix `CS*`/`RZ*` until `success:true` (per the Agent Protocol rule).
     2. **`frm-mixdb-ajax` contract** — the markup MUST have BOTH `class="frm-mixdb-ajax"` AND `data-mixdb-table="<table>"`; missing either means the handler never picks the form up and submit is a no-op.
     3. **Field ↔ column match** — call `GetMixDbBySystemName(<table>, includeColumns:true)` and confirm every `<input|select|textarea name="X">` matches a column `systemName`. Extra fields are silently dropped; a required column with no matching field fails at insert (NOT NULL → 500). NEVER include the server-auto columns `id` / `created_date_time` / `created_by`.
     4. **Form lives in a TEMPLATE, not `Content`** — the `<form>` belongs in this Form template (or a page template, embedded via `@await Html.PartialAsync("../Forms/<name>.cshtml")`), NEVER baked into a page's `Content` data field (that field is prose, output via `@Html.Raw` — not Razor-compiled, can't carry partials). See `mixcore:mix-mcp-cms/references/form-templates.md`.
     5. **Submit handler present** — the master layout carries the single `frm-mixdb-ajax` JS handler that POSTs to `/api/v1/rest/mixdb/data/{table}` (added in Phase 2). Without it, every form on the site is inert.
2. **Widgets** — `CreateTemplate(folderType: "Widgets")`:
   - Model: `@model dynamic` (default) or `ModuleContentViewModel` when passed from parent
   - Keep focused and single-purpose (newsletter, recent posts, search bar)
   - Validate the template (`ValidateTemplate`) per the Agent Protocol rule
3. Associate forms/widgets with pages via `CreatePageModuleAssociation`

### `wwwroot/mixcontent/planning/phase-7-verify.md` — Verify & Fix

**Invoke `mixcore:mix-mcp-cms` skill first. Use Playwright browser tools if available.**

Goal: confirm every page renders without errors in the browser and that all module associations, data queries, and form submissions work as expected.

Tasks:
0. **Section-contract gate (run FIRST, before any browser check)** — call `validate_site_sections(mixThemeId)`. It cross-checks every page/post/data template's `@section` definitions against each master's `@RenderSection`/`IgnoreSection` slots and catches the #1 build crash (`"sections have been defined but have not been rendered"`) that `validate_template` (compile-only) cannot. If `ok:false`, fix the reported master(s) — add `@RenderSection("<section>", required:false)` for each `unrenderedChildSections` entry (Seo/Styles in `<head>`, Scripts before `</body>`) — and re-run until `ok:true`. Only then proceed to the browser pass. (`create_template`/`update_template` already **reject** a master missing the Seo/Styles/Scripts render slots, so this gate mainly catches custom sections and pre-existing masters.) Then run **`validate_site_queries(mixThemeId)`** — the same idea for MixDB queries: it flags any `GetDataAsync(table, filterJson)` whose filter literal is not a JSON array of `{fieldName,value,operator}` (e.g. a `{"order":[…]}` object), the runtime `JsonSerializationException` that `validate_template` can't see. Fix to `ok:true` before proceeding.
1. **Enumerate all pages** — call `ListPageContents` and collect the URL slug for every page created in phases 4–6.
2. **Find the correct verification URL** — read `.mcp.json` in the repo root and use the `url` value from the `mixcore` server entry (e.g. `http://localhost:58245`). The Mixcore site and MCP server share the same host/port. Do NOT assume `localhost:5000` or `localhost:5001`. Then navigate `<base-url>/<slug>` and take a screenshot with `browser_take_screenshot`. Check:
   - Page loads with HTTP 200 (no redirect loop, no 404, no 500)
   - Master layout renders (nav, footer visible)
   - All module regions are populated — no blank or `[object Object]` output
   - Images display (not broken)
   - Razor template errors: look for yellow ASP.NET error pages or stack traces
   - **If HTTP 500**: use `curl -s <base-url>/<slug>` to see the full compilation error in the response body — `CompilationFailedException`, `CS1061`, `CS0234`, `CS0023` are the most common. The browser screenshot only shows "Internal Server Error"; `curl` reveals the exact line and error code.
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

## Step 10 — Execute All Phases

**This is where the site actually gets built. Steps 1–9 only produced plans; this step runs them.**

Execute Phase 1 → Phase 7 **sequentially in this same session**. Do not hand the prompt files back to the user and stop — those files are resume/recovery artifacts, not a substitute for running the phases now. Both modes reach here without a second approval: auto-mode skips the clarification gate; non-auto clarifies the outline once, then runs Steps 1–10 continuously after that one approval.

For **each** phase N from 1 to 7:

1. **Pre-check** — Read `wwwroot/mixcontent/planning/progress-tracker.md`; confirm Phase N-1 is ✅ Complete (Phase 1 has no predecessor). Read `requirements-analysis.md` and `phase-N-*.md`.
2. **Invoke the phase's sub-skill** — `mixcore:mix-mcp-db` (phases 1, and 6 if new tables) or `mixcore:mix-mcp-cms` (phases 2–7), per the Phase Overview table.
3. **Execute** every task in `phase-N-*.md` via MCP tools only (never Edit/Write for content). Validate each `.cshtml` with `ValidateTemplate` before building content on it.
4. **Record** all generated IDs/system names and mark Phase N ✅ Complete (with date) in `progress-tracker.md`.
5. **Stop-on-failure** — if a phase hits an error you cannot fix with MCP tools after a reasonable attempt, halt, mark the phase ⚠️ Blocked in the tracker with the exact error, and report to the user instead of skipping ahead. Later phases depend on earlier IDs — never continue past a blocked phase.

After Phase 7 (Verify & Fix) completes clean, report a summary: pages built, their URLs (use the MCP-server origin from `.mcp.json`, not `localhost:5000`), tables seeded, and any issues found/fixed.

> The phase files written in Steps 2–8 and the prompt files from Step 9 stay on disk so a fresh session can re-enter any single phase later — but in this run, execute them now rather than waiting to be re-prompted.

---

## Content & Design Guidelines (All Phases)

| Concern | Standard |
|---|---|
| **Writing style** | Professional, technical yet accessible, active voice |
| **SEO** | Meta descriptions 150–160 chars, semantic HTML5, schema.org markup |
| **Colors & palette** | Resolve from the site's `design.md` / `design-system.md` design tokens — do NOT hardcode hex values here. Fall back to the default token palette in `design.md` if the site has no design system yet. See `mixcore:mix-mcp-cms/references/design.md` and `design-system.md`. |
| **Typography** | Resolve from the site's `design.md` / `design-system.md` typography tokens (font family + scale). See `mixcore:mix-mcp-cms/references/design.md`. |
| **Responsive** | Resolve breakpoints from the site's `design.md` / `design-system.md` tokens (fall back to the `design.md` defaults) — do NOT hardcode a fixed breakpoint set here. See `mixcore:mix-mcp-cms/references/design.md`. |
| **Favicon** | Generate a *suitable, brand-matched* SVG (32×32 `viewBox`; a monogram or simple glyph in the site's primary/accent colors), write it with `write_text_file(path: "generated-data/<slug>-favicon.svg", …)`, and link it in `<head>`: `<link rel="icon" type="image/svg+xml" href="/mixcontent/documents/generated-data/<slug>-favicon.svg" />`. Local generated SVG is the default (served from the documents folder); a full `https://…` public URL is an acceptable alternative — never a generic stock globe and never a bare relative path outside `/mixcontent/…`. |
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

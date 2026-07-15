---
name: mix-mcp-cms
description: Build websites with Mixcore CMS using MCP-first development — AI-powered dynamic schemas (MixDb), templates, content management, smart queries, and LLM tools for autonomous website creation.
argument-hint: "[create-template|create-content|create-mixdb|smart-query|build-site] [entity]"
---

You are building **websites with Mixcore CMS** using **MCP-First Development**.

**All operations go through the Mixcore MCP server.** Connect via whatever URL the user has configured — never assume or hardcode a host/port.

## Step 0 — Resolve MCP Server

Before any MCP call, resolve `{MCP_PREFIX}` and `{SITE_URL}` **from the connected MCP session** — never from a hardcoded or persisted config. Follow `plugins/mixcore/skills/mixcore/mcp-prefix.md` (canonical): detect the connected `mcp__{server-name}__*` Mixcore server, set `MCP_PREFIX = mcp__{server-name}__`, and derive `SITE_URL` from that server's `url` in `.mcp.json` (strip `/mcp`). Use `SITE_URL` for all browser verification and reported links — never assume `localhost`.

Then replace every `mcp__mixcore__` reference in this skill with `{MCP_PREFIX}`.

> This step is skipped automatically when `mixcore:mix-mcp-cms` is invoked via the `mixcore:mixcore` router (which already resolved `{MCP_PREFIX}` and `{SITE_URL}` in its own Step 0).

## 🚨 CRITICAL RULE: Load razor-rules.md Before ANY Template Write — ValidateTemplate After

**Before every `CreateTemplate` or `UpdateTemplate` call**, you MUST load **[references/razor-rules.md](references/razor-rules.md)** and apply every rule in it. This is not optional — it is the template syntax contract. Skipping it causes `@@`-escaping bugs, wrong `@model` declarations, broken partial paths, missing `.cshtml` extensions, and section-count crashes.

**After every `CreateTemplate` or `UpdateTemplate` call**, you MUST call `ValidateTemplate` and fix every `CS*`/`RZ*` error before creating page/module content or opening a browser. The compile-check takes ~1s; a create-page → navigate → read-500 → fix loop on errors a ValidateTemplate would have surfaced is wasted work.

```text
Gate order for EVERY template task:
  Wiki-First → Design-System-First → Frontend-Design-First → Load razor-rules.md → CreateTemplate/UpdateTemplate → ValidateTemplate → fix errors → ValidateTemplate → success:true → proceed
```

If `ValidateTemplate` returns `skipped:true` (`.liquid` template), that's fine — Razor compilation doesn't apply.

---

## Reference files (load when relevant)

| Topic | File |
|---|---|
| **Razor template syntax** — `@model`, CSS escaping, partials, sections, row rendering, module loops | [references/razor-rules.md](references/razor-rules.md) |
| **MixDB queries in Razor** — `IMixDbDataService`, `MixDbRow`, `MixDbFilter`, naming conventions | [references/mixdb-in-razor.md](references/mixdb-in-razor.md) |
| **Data loading paths** — `QueryTable` vs `QueryRows` vs Razor injection, JSON filter format | [references/data-loading.md](references/data-loading.md) |
| **Content creation** — folderType verification, template assignment, phase plan | [references/content-creation.md](references/content-creation.md) |
| **Template ViewModels** — Page/Post/Module/Widget `Model` properties, `@model` matrix | [references/viewmodels.md](references/viewmodels.md) |
| **Design system format & gate** — resolve/author/bootstrap `design.md`, token→CSS-var materialization | [references/design-system.md](references/design-system.md) |
| **Global default `design.md`** — baseline tokens used when a site has no override | [references/design.md](references/design.md) |
| **Form templates** — `frm-mixdb-ajax`, JS handler, hidden fields, API endpoint | [references/form-templates.md](references/form-templates.md) |
| **Multilingual site** — cultures, per-culture content (`specificulture` on create + read), culture switcher, `@L` i18n localizer, Languages portal | [references/multilingual.md](references/multilingual.md) |
| **Live MCP tool signatures and enums** | Use `ToolSearch` with `select:{MCP_PREFIX}<tool_name>` — schemas loaded directly from server |
| **AI chat widgets** — SiteWikiHub integration, SignalR frontend, drawer pattern | Use `mixcore:mix-mcp-ai` skill |

For AI chat widget tasks (floating chat, SiteWikiHub, SignalR-connected widgets), invoke the **`mixcore:mix-mcp-ai`** skill instead of or alongside this one.

---

## 🎨 Design Quality: Use a Frontend/UI Skill Before Generating or Updating a Template

**Before you generate or update ANY template** (master layout, page, module, post, widget, form, or MixDB detail template), check whether a frontend-design or UI design skill is available in this session and invoke it first to inform the markup and styling.

1. **Check availability** — look in the available-skills list for a design/UI skill. Common ones, in order of preference:
   - `frontend-design` — distinctive, production-grade UI; avoids generic AI aesthetics
   - `ui-ux-pro-max` — styles, color palettes, font pairings, layout/UX guidance
   - `ui-styling` — Tailwind / shadcn-style components, themes, accessibility
   - any other skill whose description mentions UI, UX, frontend, design system, or styling
2. **If one is available → invoke it first** via the `Skill` tool, then apply its guidance (layout, color, typography, spacing, interaction states, accessibility) to the Razor markup you pass to `CreateTemplate` / `UpdateTemplate`.
3. **If none is available → proceed** with the design conventions already in this skill and the reference files. Do not block the task.

> This raises visual quality and consistency. The frontend/UI skill informs **how the HTML/CSS looks**; this skill still governs **how it is created** — all output goes through MCP `CreateTemplate` / `UpdateTemplate`, never direct file edits.

---

## 🎨 Design-System-First: Resolve `design.md` Before Generating or Updating a Template

**Before any `CreateTemplate` / `UpdateTemplate`**, resolve the site's design system. Full rules:
[references/design-system.md](references/design-system.md).

1. **Per-site override** — `read_document("<site-slug>/design.md")`.
2. **Fallback** — if missing, use the global default [references/design.md](references/design.md).
3. **Auto-bootstrap** — if there is no per-site `design.md` and this is a real site build,
   synthesize one (brand input → requirements wiki → `frontend-design` output → global default),
   save it via `generate_document("design", <content>, "<site-slug>")`, then proceed.
4. **Apply** — use the resolved tokens; materialize them once into the master layout `:root {}`
   as CSS variables and consume `var(--token)` in every other template. No off-palette literals.

Gate order within a template task: **Wiki-First → Design-System-First → Frontend-Design-First →
CreateTemplate → ValidateTemplate**.

---

## 🚨 CRITICAL RULE: NEVER Update Files Directly

**❌ DO NOT** directly edit/write template or content files using `Write`/`Edit` tools.

**✅ DO** use MCP tools instead:
- **Templates**: Use `CreateTemplate`, `UpdateTemplate`, `DeleteTemplate`
- **Page Content**: Use `CreatePageContent`, `UpdatePageContent`
- **Module Content**: Use `CreateModuleContent`, `UpdateModuleContent`
- **Text Files**: Use `WriteTextFile`, `AppendToTextFile` for **planning docs only** — **never for wiki** (see exceptions below)
- **MixDb Tables**: Use `CreateMixDbTable`, `UpdateMixDbTable`, `CreateColumn`, etc.

**Why?** MCP tools register changes in the CMS, handle migrations, broadcast updates via SignalR, invalidate cache, and maintain data consistency. Direct file edits bypass all this.

**Exception — wiki docs**: Files under `wwwroot/mixcontent/documents/wiki/` must be managed with **`mixcore:mix-mcp-rag`** tools (`generate_document`, `read_document`, `list_documents`, `delete_document`) — never `WriteTextFile`/`ReadTextFile`. Those bypass the RAG index and leave the in-app AI with stale content.

**Exception — planning docs**: Files under `wwwroot/mixcontent/planning/` may use `WriteTextFile`/`ReadTextFile` directly (no CMS registration or RAG indexing needed).

---

## 🚨 CRITICAL RULE: Search the Site Wiki Before Every Task

Before executing any CMS task, **search the wiki knowledge base** to load site context. Load the **`mixcore:mix-mcp-rag`** skill, then:

```
{MCP_PREFIX}search(query: "<task subject>", topK: 5)
```

The search index covers all wiki files at once — template IDs, page slugs, MixDB schema, gotchas from prior sessions — in one call.

| Task | Targeted follow-up (after search) |
|------|-----------------------------------|
| Create / update a **page** | `{MCP_PREFIX}read_document("<tenant-name>/pages/<seo-name>.md")` |
| Create / update a **module** | search `"modules widget system name"` |
| Create / update a **template** | `{MCP_PREFIX}read_document("<tenant-name>/templates/<name>.md")` |
| Create / update a **form** | search `"forms contact newsletter MixDB table"` |
| Create / update a **MixDB table** | `{MCP_PREFIX}read_document("<tenant-name>/database/<table>.md")` |
| Any task on an existing site | search `"site index"` then read the index doc |
| Planning / phased build tasks | `{MCP_PREFIX}list_text_files("planning/")` and `read_text_file` the plan |

**Why?** Search finds relevant knowledge across all wiki files in one call — no need to guess file paths or follow cross-links manually. Skipping this step causes duplicate work, wrong template IDs, and broken page associations.

---

## Document Folder Convention

**All generated documents live under `wwwroot/mixcontent/`.**

| Purpose | Path pattern |
|---------|-------------|
| Wiki / reference docs | `wwwroot/mixcontent/documents/wiki/<topic>.md` |
| Site / feature build plans | `wwwroot/mixcontent/planning/<plan-name>.md` |
| Any other AI-generated text | `wwwroot/mixcontent/<category>/<file>.md` |

Never write docs to the project root, `wwwroot/` directly, or any path outside `wwwroot/mixcontent/`.

---

## MCP Tools Quick Reference

| Category | Tool Methods | Key Actions |
|----------|-------------|-------------|
| **Templates** | `CreateTemplate`, `GetTemplate`, `UpdateTemplate`, `SearchReplaceTemplate`, `ValidateTemplate`, `DeleteTemplate`, `ListTemplates` | Create/manage + server-side compile-check Razor templates |
| **Pages** | `CreatePageContent`, `GetPageContent`, `GetPageContentBySeoName`, `UpdatePageContent`, `DeletePageContent`, `ListPageContents`, `UpdatePageContentFromPrompt` | Create/manage page content |
| **Modules** | `CreateModuleContent`, `GetModuleContent`, `GetModuleContentBySystemName`, `UpdateModuleContent`, `DeleteModuleContent`, `ListModuleContents`, `GetModulesByType`, `UpdateModuleContentFromPrompt` | Create/manage module content |
| **Posts** | `CreatePostContent`, `GetPostContent`, `GetPostContentBySeoName`, `UpdatePostContent`, `DeletePostContent`, `ListPostContents` | Create/manage post content |
| **MixDb Tables** | `GetMixDbBySystemName`, `SearchMixDb`, `CreateMixDbTableFromPrompt`, `CreateMixDbTable`, `UpdateMixDbTable`, `DeleteMixDbTable` | AI-powered + explicit table management |
| **MixDb Columns** | `GetColumnById`, `ListColumns`, `CreateColumn`, `UpdateColumn`, `DeleteColumn`, `GetColumnsByTable`, `AddColumnToTable`, `UpdateTableColumn`, `DeleteTableColumn` | AI-powered column management |
| **MixDb Relationships** | `GetRelationshipById`, `ListRelationships`, `CreateRelationship`, `UpdateRelationship`, `DeleteRelationship`, `GetRelationshipsByParentTable`, `GetRelationshipsByChildTable` | Manage table relationships |
| **MixDb Data (internal)** | `QueryTable`, `CreateRow`, `UpdateRow`, `DeleteRow`, `GetRowById` | CRUD on internal MixDb tables (`dataSourceName` optional/null) |
| **MixDb Data (DataSource)** | `QueryRows`, `GetRowById`, `CreateRow`, `UpdateRow`, `DeleteRow` | CRUD on external DataSource tables — requires `dataSourceName` for `QueryRows` |
| **SmartQuery** | `ParseSmartQuery`, `SmartQuery` | Natural language query parsing + execution |
| **Navigation** | `CreatePagePostAssociation`, `CreateModulePostAssociation`, `CreatePageModuleAssociation`, `GetPageNavigationTree` + list/delete variants | Link pages/modules/posts |
| **PageModule Ext** | `ListModulesForPage`, `ReorderModulesOnPage`, `CopyModuleAssociations`, `RemoveModuleFromPage`, `GetPagesWithModule` | Extended page-module ops |
| **Wiki / RAG** | `Search`, `GenerateDocument`, `ReadDocument`, `ListDocuments`, `DeleteDocument`, `ReloadWiki` | Wiki knowledge base — load **`mixcore:mix-mcp-rag`** skill |
| **Text Files** | `ReadTextFile`, `WriteTextFile`, `AppendToTextFile`, `DeleteTextFile`, `ListTextFiles` | Planning docs only — never use for wiki |
| **DB Query** | `ExecuteQuery`, `GetTables`, `GetTableSchema`, `GetTableData` | Read-only CMS DB queries |
| **Utility** | `Fetch`, `Echo` | URL fetch, connectivity test |

---

## AI-Powered MixDb Tools

Create database schemas from natural language:

| Method | Description | Example |
|--------|-------------|---------|
| `CreateMixDbTableFromPrompt` | Create table + columns from description | `"Create a Product table with name, price, and description"` |
| `AddColumnToTable` | Add columns via AI prompt | `"Add a price column that stores decimal values"` |
| `UpdateTableColumn` | Update columns via AI prompt | `"Change product_price to be non-required"` |
| `DeleteTableColumn` | Delete columns via AI prompt | `"Remove the product_code column"` (requires `confirmDropColumn="YES"`) |

**LLM Parameters**: `llmServiceType` (`"OpenAI"`, `"DeepSeek"`, `"LMStudio"`), `llmModel`, `timeoutSeconds`

---

## SmartQuery — Natural Language Data Queries

Query MixDb tables using natural language:

| Method | Description | Example |
|--------|-------------|---------|
| `ParseSmartQuery` | Parse query into filters for review | `ParseSmartQuery("mix_products", "products priced over $50")` → returns filters without executing |
| `SmartQuery` | Parse + execute, return actual data | `SmartQuery("mix_products", "active products created last week")` → returns paginated results |

**SmartQuery workflow:**
1. Call `ParseSmartQuery` to review the parsed filters
2. If filters match intent, call `SmartQuery` (or adjust the natural language query)
3. Returns: parsed filters, explanation, confidence score, and actual data

---

## Enum Values

**All enum values (folderType, MixPageType, MixModuleType, MixContentStatus, MixConjunction, MixDataType, MixDbTableRelationshipType) are embedded in the live tool schemas.** Use `ToolSearch` to load the relevant tool and read its `enum` property. Always pass string names, never integers.

---

## Architecture Overview

**Mixcore v3** is an **ASP.NET Core 10** headless CMS rebuilt from scratch:
- **Dynamic Schema System (MixDb)**: Create tables via explicit schema
- **AI-First Development**: MCP tools for autonomous website building
- **Template-Content Separation**: Razor templates (`.cshtml`) render content instances
- **Multi-Tenant SaaS**: Built-in tenant isolation, SignalR real-time, REST APIs
- **DataSource Support**: Connect external databases alongside the built-in MixDb engine

---

## ViewModel Properties

Each template type exposes a strongly-typed `Model` (Page/Post/Module) or `@model dynamic`
(Widget/Form/Master/Data). The full per-type property tables, the `@model` matrix, and the
Widget/Form notes live in **[references/viewmodels.md](references/viewmodels.md)** — load it before
writing any Page, Post, Module, or Widget template. `Content`/`Excerpt` hold semantic HTML — always render with `@Html.Raw(Model.Content)` / `@Html.Raw(Model.Excerpt)`.

---

## Common Task Patterns

| Request | Action |
|---|---|
| "create master layout" | `CreateTemplate(folderType="Masters", fileName="MyMaster.cshtml")` — **fileName MUST include `.cshtml`**; always before pages. **Then `ValidateTemplate(id)` → fix errors → re-validate until `success:true`.** |
| "create page template" | `CreateTemplate(folderType="Pages", fileName="HomePage.cshtml")` — **fileName MUST include `.cshtml`**; see [razor-rules.md](references/razor-rules.md) §1. **Then `ValidateTemplate(id)` → fix errors → re-validate until `success:true`.** |
| "create module template" | `CreateTemplate(folderType="Modules", fileName="HeroBanner.cshtml")` — **fileName MUST include `.cshtml`**. **Then `ValidateTemplate(id)` → fix errors → re-validate until `success:true`.** |
| "create post template" | `CreateTemplate(folderType="Posts", fileName="BlogPost.cshtml")` — **fileName MUST include `.cshtml`**. **Then `ValidateTemplate(id)` → fix errors → re-validate until `success:true`.** |
| "create widget template" | `CreateTemplate(folderType="Widgets", fileName="Newsletter.cshtml")` — **fileName MUST include `.cshtml`**; use `@model dynamic`. **Then `ValidateTemplate(id)` → fix errors → re-validate until `success:true`.** |
| "create form template" | `CreateTemplate(folderType="Forms", fileName="ContactForm.cshtml")` — **fileName MUST include `.cshtml`**; see [form-templates.md](references/form-templates.md). **Then `ValidateTemplate(id)` → fix errors → re-validate until `success:true`.** |
| "create data/detail template for MixDB table" | 1. `GetMixDbBySystemName(includeColumns: true)` → confirm schema. 2. `CreateTemplate(folderType="Data", fileName="Detail.cshtml")` — `@model Mix.DataSource.Models.MixDbRow`. 3. **`ValidateTemplate(id)` → fix errors → re-validate until `success:true`.** 4. `UpdateMixDbTable(systemName, templateId: <id>)` to assign. Inject `@inject IMixDbDataService db` ONLY for related rows. See [mixdb-in-razor.md → Data-detail template contract](references/mixdb-in-razor.md). |
| "update page template" | `UpdateTemplate(id, content: ...)` → **`ValidateTemplate(id)` → fix errors → re-validate until `success:true`.** Then **check linked modules**: `ListPageModuleAssociations(pageId)` → read each module's template via `GetTemplate` → verify the page template's wrapper HTML/CSS is still compatible with each module template's output. If the page layout changed (grid columns, spacing, breakpoints), update affected module templates too (and validate each). See [content-creation.md → Update Workflow](references/content-creation.md). |
| "update module template" | `UpdateTemplate(id, content: ...)` → **`ValidateTemplate(id)` → fix errors → re-validate until `success:true`.** Then **check parent pages**: `GetPagesWithModule(moduleId)` → read each page's template → verify the module's new output still fits each page's container structure. |
| "validate / compile-check a template" | `ValidateTemplate(templateId)` — returns `{ success, skipped, errors:[{ line, message, code }] }`. Fix `CS*`/`RZ*` errors before creating page content. `.liquid` → `skipped:true`. Pre-flight raw markup with `ValidateTemplate(content, folderType)`. **Loop `Validate → fix (SearchReplaceTemplate/UpdateTemplate) → Validate` until `success:true`.** |
| "create a page" | Verify templateId + layoutId folderTypes → `CreatePageContent` — see [content-creation.md](references/content-creation.md) |
| "create a module" | Verify `templateId` has `folderType="Modules"` → `CreateModuleContent` |
| "create a post" | Verify templateId + layoutId → `CreatePostContent` |
| "create MixDb table" | `CreateMixDbTableFromPrompt` (AI) — use brand prefix in displayName |
| "add column to table" | `CreateColumn` (explicit) or `AddColumnToTable` (AI prompt) |
| "create table relationship" | `create_relationship` with numeric table IDs (`parentId`/`childId`) — look up ids via `GetMixDbBySystemName` |
| "verify table schema" | `GetMixDbBySystemName(includeColumns=true)` |
| "query internal MixDb via MCP" | `QueryTable(tableName, filterJson)` — see [data-loading.md](references/data-loading.md) Path A |
| "query external DataSource via MCP" | `QueryRows(...)` — see [data-loading.md](references/data-loading.md) Path B |
| "query MixDb in Razor template" | `@inject IMixDbDataService db` — see [mixdb-in-razor.md](references/mixdb-in-razor.md) |
| "write a row" | `CreateRow(dataSourceName: null, ...)` — see [data-loading.md](references/data-loading.md) Path C |
| "inspect CMS database" | `ExecuteQuery` (SELECT only) or `GetTableData` |
| "get module system names" | `ListModuleContents` → filter `Model.Modules` by exact `SystemName` (e.g. `Model.Modules?.FirstOrDefault(m => m.SystemName == "x")`) |
| "link page to module" | `CreatePageModuleAssociation` |
| "link post to page" | `CreatePagePostAssociation` |
| "reorder modules on page" | `ReorderModulesOnPage(pageId, moduleOrderJson)` |
| "copy page layout to another page" | `CopyModuleAssociations(sourcePageId, targetPageId)` |
| "find existing templates" | `ListTemplates(keyword, folderType)` |
| "smart query MixDb (natural language)" | `SmartQuery(tableName, query)` — no filter JSON needed |
| "read/write wiki docs" | `ReadDocument` / `GenerateDocument` (`mixcore:mix-mcp-rag`) — never text-file tools (they bypass the RAG index) |
| "test MCP connection" | `Echo(message)` |

> **`CreateTemplate` required args:** `fileName` (incl. `.cshtml`) **+** `content` (full Razor/HTML). The `CreateTemplate(...)` cells above are abbreviated — they omit `content=` for readability; always pass it. `folderType`/`mixThemeId` default to `Pages`/`1`; `tenantId` auto-injects. Calling with `tenantId` only → `ArgumentException: missing … 'fileName'`.

---

## Critical Don'ts

- ❌ **Never edit template or content files directly** — use `CreateTemplate`, `UpdateTemplate`, `CreatePageContent`, `UpdatePageContent`. Direct edits bypass CMS cache invalidation and SignalR broadcasts.
- ❌ **Never browser-verify a `.cshtml` template before `ValidateTemplate` returns `success:true`** — server-side compilation catches `CS1061`/`CS0234`/`CS1503`/`RZ*` errors in ~1s; don't spend a create-page → navigate → read-500 → fix loop on errors a compile-check would have surfaced.
- ❌ **Never pass `fileName` without the `.cshtml` extension to `CreateTemplate`** — the CMS stores `FileName` exactly as passed and builds `TemplateFilePath` from it. Missing extension → template not found at runtime. Always: `fileName: "HomePage.cshtml"` ✅ Never: `fileName: "HomePage"` ❌
- ❌ **Never call `CreateTemplate` with only `tenantId`** — `fileName` **and** `content` are the two **required** parameters (`content` = the full Razor/HTML body). `tenantId` is **auto-injected** by the agent and optional — supplying it alone yields `ArgumentException: missing a value for the required parameter 'fileName'`. The table examples below abbreviate the call and omit `content=` for brevity, but you **must** pass a non-empty `content`. Same rule for `CreateModuleContent`/`CreatePageContent`/`CreatePostContent`: never call with tenant scope alone.
- ❌ **Never call `UpdateTemplate` with only `tenantId`** — `id` is **required** (`ArgumentException: missing a value for the required parameter 'id'` otherwise). `content` is **optional**: omit it to leave the stored body unchanged (a `scripts`/`styles`/`fileFolder`-only update) — but supply at least one updatable field, or the call errors with "Nothing to update". If you don't know the id, **discover it first**: `ListTemplates(keyword: "<file name>")` or the `templateId` field on `GetPageContent`/`GetModuleContent`, then `GetTemplate(id)` to read the current content — when `content` IS supplied, `UpdateTemplate` **replaces the whole content**, it does not patch. For small targeted edits use `SearchReplaceTemplate(id, oldString, newString)` instead. If no read/list tool surfaces the id, ask the user — never guess.
- ❌ **Never run `SearchReplaceTemplate` against a stale copy** — it exact-string-matches the LIVE stored content and fails when `oldString` has drifted by whitespace, encoding, or a prior edit. Always `GetTemplate(id)` immediately before composing `oldString`. For large rewrites — or after 2 consecutive `oldString`-mismatch failures — switch to `UpdateTemplate(id, content: <full body>)` instead of retrying escape variations.
- ❌ Never put `style`/`class` attributes or `<style>`/`<script>` blocks in `content`/`excerpt` — these fields are **semantic HTML only** (structure tags). Render with `@Html.Raw(Model.Content)`. Presentation belongs in the template.
- ❌ Never use `@row.Get<T>("field")` without wrapping — always `@(row.Get<T>("field"))`
- ❌ Never use CSS `@media`, `@keyframes`, `@font-face` unescaped — always `@@media`, `@@keyframes`, `@@font-face`
- ❌ Never put `@model` in a master layout template
- ❌ Never put `@{ Layout = "..." }` in a page or module template
- ❌ Never call `@Html.Partial()` (sync) — always `@await Html.PartialAsync()`
- ❌ Never use relative image paths — full public URLs only
- ❌ Never set `templateId` or `layoutId` to a non-existent or wrong-folderType template
- ❌ Never put `style`/`class` attributes, `<style>`/`<script>` blocks, JS, or CSS in `content`/`excerpt` fields — these are **semantic HTML only** (structure tags like `<p>`, `<a>`, `<strong>`). Presentation belongs in the template (`.cshtml`). Render with `@Html.Raw(Model.Content)`.
- ❌ Never use display names in MixDb queries — always system names (`<site_name>_table`)
- ❌ Never pass display or system names as the parent/child key to `create_relationship` — it takes numeric table IDs (`parentId`/`childId`); there is no `CreateMixDbRelationshipFromPrompt` tool
- ❌ Never guess module system names — call `ListModuleContents` first
- ❌ Never call `MigrateTable` — this tool does not exist; migration is automatic
- ❌ Never use integer folderType values — string enum values only (`"Pages"` not `1`)
- ❌ Never duplicate `@RenderSection("Styles", false)` in a master layout — each section exactly once
- ❌ Never call `Model.GetModule(...)` — it doesn't exist; filter `Model.Modules` by exact `SystemName` from `ListModuleContents` (`Model.Modules?.FirstOrDefault(m => m.SystemName == "x")`)
- ❌ Never skip try-catch when rendering `module.TemplateFilePath` in a loop — a broken module will crash the whole page without it (and there is no `module.Template` nav property — use `module.TemplateFilePath`)
- ❌ Never write MixDB template code without first calling `GetMixDbBySystemName(includeColumns: true)` — field names are case-sensitive
- ❌ Never use `@model dynamic` in a Page or Post template — both require their typed ViewModel
- ❌ Never use a typed ViewModel in a Form template — form templates require `@model dynamic`
- ❌ Never violate the form contract — `class="frm-mixdb-ajax"` + `data-mixdb-table` mandatory; JS handler in the Master layout only; never include server auto-set fields (`id`, `created_date_time`, `created_by`). Full contract (incl. public POST endpoint): [form-templates.md](references/form-templates.md)
- ❌ Never use `QueryRows` without a `dataSourceName` — it is required; use `QueryTable` for internal tables
- ❌ Never use `filterJson: {"status":"Published"}` (key/value) — both `filterJson` and `filtersJson` require array format `[{"fieldName":"...","value":"...","operator":"="}]`
- ❌ Never use `IMixDbDataServiceFactory` in Razor templates — it does not exist; use `@inject IMixDbDataService db`
- ❌ Never use `SearchMixDbRequestModel`, `GetPagingAsync`, or `MixQueryField` in Razor templates — internal service types; use `MixDbFilter` and `GetRowsAsync`
- ❌ **Never hardcode dynamic data in a template** — if a MixDB table exists for products, menu items, team members, etc., the template MUST load rows via `@inject IMixDbDataService db` and render them in a `@foreach` loop. Static HTML copies of database rows are always wrong: the CMS and the page diverge the moment any row is added/removed. See [mixdb-in-razor.md §NEVER HARDCODE](references/mixdb-in-razor.md) for the canonical loop + category-mapping pattern.
- ❌ Never update a page template that renders linked modules without also checking the linked module templates for consistency — the page's wrapper HTML, CSS classes, and grid structure must match what module templates actually produce. See [content-creation.md → Update Workflow](references/content-creation.md).
- ❌ Never start a CMS task (page, module, post, template, form, MixDB table) without first reading the relevant docs from `wwwroot/mixcontent/documents/wiki/` — skipping this causes duplicate IDs, wrong templates, and broken pages
- ❌ **Never `CreateTemplate`/`UpdateTemplate` before resolving `design.md`** — read the per-site `<site-slug>/design.md` (or fall back to the global default; auto-bootstrap if missing), then generate from its tokens. Skipping it makes each template drift to a different palette/typography/spacing. See [references/design-system.md](references/design-system.md).
- ❌ Never write generated documents outside `wwwroot/mixcontent/` — all wiki, planning, and AI-generated files belong there

---

> **Wiki documentation is automatic.** Content created/updated/deleted through the MCP
> tools (pages, modules, posts, MixDB rows) is mirrored into the site wiki and indexed by
> the CRUD→wiki RAG pipeline (`RagImportNotificationHandler` → `RAGImportSubscriber` →
> `SiteWikiWriter`). No manual `generate_document` / `reload_wiki` step is needed after a
> build task. Use `mixcore:mix-mcp-rag` only when you want to hand-author a standalone wiki doc.

---

## MCP Tools

<!-- mcp-tools:auto (generated by docs-sync; canonical names from live tools/list) -->
Canonical `/mcp` tools this skill reaches for (names are the exact `tools/list` names; confirm signatures live via ToolSearch before calling). MixDB schema/row tools live in `mixcore:mix-mcp-db`; workflow/cron/wiki tools in their own `mix-mcp-*` skills.

- **Templates** — `create_template`, `get_template`, `update_template`, `search_replace_template`, `delete_template`, `list_templates`, `validate_template`
- **Pages** — `create_page_content`, `get_page_content`, `get_page_content_by_seo_name`, `update_page_content`, `update_page_content_from_prompt`, `delete_page_content`, `list_page_contents`
- **Modules** — `create_module_content`, `get_module_content`, `get_module_content_by_system_name`, `update_module_content`, `update_module_content_from_prompt`, `delete_module_content`, `list_module_contents`, `get_modules_by_type`
- **Posts** — `create_post_content`, `get_post_content`, `get_post_content_by_seo_name`, `update_post_content`, `delete_post_content`, `list_post_contents`
- **Page ↔ module/post wiring** — `create_page_module_association`, `list_modules_for_page`, `list_page_module_associations`, `update_page_module_association`, `delete_page_module_association`, `remove_module_from_page`, `get_pages_with_module`, `reorder_modules_on_page`, `copy_module_associations`, `create_page_post_association`, `list_page_post_associations`, `delete_page_post_association`, `create_module_post_association`, `list_module_post_associations`, `delete_module_post_association`, `get_page_navigation_tree`
- **Themes** — `list_themes`, `get_theme`, `get_theme_by_system_name`, `create_theme`, `update_theme`, `delete_theme`
- **Multilingual (culture/language)** — `list_cultures`, `get_culture`, `get_culture_by_specificulture`, `create_culture`, `update_culture`, `delete_culture`, `list_languages`, `get_language_contents`, `create_language`, `set_language_content`, `delete_language`
- **MixDB read (template data)** — `get_mix_db_by_system_name`, `query_table`, `smart_query`
- **AI generation** — `generate` (structured content), `generate_text`, `generate_image`, `analyze_image`
- **Validation** — `validate_template`, `validate_site_sections`, `validate_site_queries`
<!-- /mcp-tools:auto -->

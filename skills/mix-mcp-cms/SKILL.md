---
name: mix-mcp-cms
description: Build websites with Mixcore CMS using MCP-first development — AI-powered dynamic schemas (MixDb), templates, content management, smart queries, and LLM tools for autonomous website creation.
argument-hint: "[create-template|create-content|create-mixdb|smart-query|build-site] [entity]"
---

You are building **websites with Mixcore CMS** using **MCP-First Development**.

**All operations go through the Mixcore MCP server.** Connect via whatever URL the user has configured — never assume or hardcode a host/port.

## Step 0 — Resolve MCP Server

Before any MCP call, resolve `{MCP_PREFIX}`:

1. Read `plugins/mixcore/skills/mixcore/server-config.md`.
   - If it exists and contains a server name → set `MCP_PREFIX = mcp__{server-name}__` (e.g. `mcp__mixcore-cloud__`).
   - If the file does not exist → run **Step 0** from the `mixcore:mixcore` skill to detect and persist the server, then return here.
2. Replace every `mcp__mixcore__` reference in this skill with `{MCP_PREFIX}`.

> This step is skipped automatically when `mixcore:mix-mcp-cms` is invoked via the `mixcore:mixcore` router (which already resolved `{MCP_PREFIX}` in its own Step 0).

## Reference files (load when relevant)

| Topic | File |
|---|---|
| **Razor template syntax** — `@model`, CSS escaping, partials, sections, row rendering, module loops | [references/razor-rules.md](references/razor-rules.md) |
| **MixDB queries in Razor** — `IMixDbDataService`, `MixDbRow`, `MixDbFilter`, naming conventions | [references/mixdb-in-razor.md](references/mixdb-in-razor.md) |
| **Data loading paths** — `QueryTable` vs `QueryRows` vs Razor injection, JSON filter format | [references/data-loading.md](references/data-loading.md) |
| **Content creation** — folderType verification, template assignment, phase plan | [references/content-creation.md](references/content-creation.md) |
| **Form templates** — `frm-mixdb-ajax`, JS handler, hidden fields, API endpoint | [references/form-templates.md](references/form-templates.md) |
| **Live MCP tool signatures and enums** | Use `ToolSearch` with `select:{MCP_PREFIX}<tool_name>` — schemas loaded directly from server |
| **AI chat widgets** — SiteKnowledgeHub integration, SignalR frontend, drawer pattern | Use `mixcore:mix-mcp-ai` skill |

For AI chat widget tasks (floating chat, SiteKnowledgeHub, SignalR-connected widgets), invoke the **`mixcore:mix-mcp-ai`** skill instead of or alongside this one.

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

## 🚨 CRITICAL RULE: NEVER Update Files Directly

**❌ DO NOT** directly edit/write template or content files using `Write`/`Edit` tools.

**✅ DO** use MCP tools instead:
- **Templates**: Use `CreateTemplate`, `UpdateTemplate`, `DeleteTemplate`
- **Page Content**: Use `CreatePageContent`, `UpdatePageContent`
- **Module Content**: Use `CreateModuleContent`, `UpdateModuleContent`
- **Text Files**: Use `WriteTextFile`, `AppendToTextFile` (for wiki/docs only)
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
| Wiki / reference docs | `wwwroot/mixcontent/wiki/<topic>.md` |
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

These are the strongly-typed properties available in each template type. Always use `@Html.Raw()` for HTML fields.

### PageContentViewModel (`folderType="Pages"`)

| Property | Type | Notes |
|---|---|---|
| `Model.Id` | `int` | Page content ID |
| `Model.Title` | `string` | Page title |
| `Model.Content` | `string` | **HTML** — always `@Html.Raw(Model.Content)` |
| `Model.Excerpt` | `string?` | Short description — `@Html.Raw(Model.Excerpt)` |
| `Model.SeoName` | `string` | URL slug |
| `Model.Modules` | `List<ModuleContentViewModel>` | Associated modules (see [razor-rules.md](references/razor-rules.md) §7) |
| `Model.LastModified` | `DateTime?` | Use null-conditional: `Model.LastModified?.ToString(...)` |
| `Model.ModifiedBy` | `string?` | Username of last editor |

### PostContentViewModel (`folderType="Posts"`)

| Property | Type | Notes |
|---|---|---|
| `Model.Id` | `int` | Post ID |
| `Model.Title` | `string` | Post title |
| `Model.Content` | `string` | **HTML** — always `@Html.Raw(Model.Content)` |
| `Model.Excerpt` | `string?` | Teaser — `@Html.Raw(Model.Excerpt)` |
| `Model.SeoName` | `string` | URL slug |
| `Model.CreatedDateTime` | `DateTime` | Creation date — always present |
| `Model.PublishedDateTime` | `DateTime?` | Publication date |
| `Model.ModifiedBy` | `string?` | Author/editor name |
| `Model.Image` | `string?` | Featured image URL |
| `Model.Tags` | `string?` | Comma-separated tags |
| `Model.Source` | `string?` | Content source |

### ModuleContentViewModel (`folderType="Modules"`)

| Property | Type | Notes |
|---|---|---|
| `Model.Id` | `int` | Module ID |
| `Model.Title` | `string` | Module title |
| `Model.SystemName` | `string` | Unique slug — use in `Model.GetModule()` |
| `Model.Content` | `string` | **HTML** — `@Html.Raw(Model.Content)` |
| `Model.Excerpt` | `string?` | Short HTML — `@Html.Raw(Model.Excerpt)` |
| `Model.SeoName` | `string` | URL slug |
| `Model.Priority` | `int` | Display order |
| `Model.ClassName` | `string` | Optional CSS wrapper class |
| `Model.PageSize` | `int?` | Optional paging hint |
| `Model.Type` | `MixModuleType` | `"Content"`, `"Data"`, `"ListPost"` |
| `Model.Template` | `TemplateViewModel` | Use `"../" + Model.Template.FilePath` or `Model.Template.GetFilePath(themeName)` in PartialAsync |
| `Model.Posts` | `List<PostContentViewModel>` | Associated posts |
| `Model.DetailUrl` | `string` | Computed `/Module/{Id}/{SeoName}` |

---

## Common Task Patterns

| Request | Action |
|---|---|
| "create master layout" | `CreateTemplate(folderType="Masters", fileName="MyMaster.cshtml")` — **fileName MUST include `.cshtml`**; always before pages |
| "create page template" | `CreateTemplate(folderType="Pages", fileName="HomePage.cshtml")` — **fileName MUST include `.cshtml`**; see [razor-rules.md](references/razor-rules.md) §1 |
| "create module template" | `CreateTemplate(folderType="Modules", fileName="HeroBanner.cshtml")` — **fileName MUST include `.cshtml`** |
| "create post template" | `CreateTemplate(folderType="Posts", fileName="BlogPost.cshtml")` — **fileName MUST include `.cshtml`** |
| "create widget template" | `CreateTemplate(folderType="Widgets", fileName="Newsletter.cshtml")` — **fileName MUST include `.cshtml`**; use `@model dynamic` |
| "create form template" | `CreateTemplate(folderType="Forms", fileName="ContactForm.cshtml")` — **fileName MUST include `.cshtml`**; see [form-templates.md](references/form-templates.md) |
| "create data/detail template for MixDB table" | 1. `GetMixDbBySystemName(includeColumns: true)` → confirm schema. 2. `CreateTemplate(folderType="Data", fileName="Detail.cshtml")` — `@model dynamic` + `@inject IMixDbDataService db`. 3. `UpdateMixDbTable(systemName, templateId: <id>)` to assign. See [content-creation.md](references/content-creation.md) |
| "validate / compile-check a template" | `ValidateTemplate(templateId)` after every `CreateTemplate`/`UpdateTemplate` — returns `{ success, skipped, errors:[{ line, message, code }] }`. Fix `CS*`/`RZ*` errors before creating page content. `.liquid` → `skipped:true`. Pre-flight raw markup with `ValidateTemplate(content, folderType)`. |
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
| "get module system names" | `ListModuleContents` → use exact systemName in `Model.GetModule()` |
| "link page to module" | `CreatePageModuleAssociation` |
| "link post to page" | `CreatePagePostAssociation` |
| "reorder modules on page" | `ReorderModulesOnPage(pageId, moduleOrderJson)` |
| "copy page layout to another page" | `CopyModuleAssociations(sourcePageId, targetPageId)` |
| "find existing templates" | `ListTemplates(keyword, folderType)` |
| "smart query MixDb (natural language)" | `SmartQuery(tableName, query)` — no filter JSON needed |
| "read/write wiki docs" | `ReadTextFile`, `WriteTextFile`, `AppendToTextFile` |
| "test MCP connection" | `Echo(message)` |

---

## Critical Don'ts

- ❌ **Never edit template or content files directly** — use `CreateTemplate`, `UpdateTemplate`, `CreatePageContent`, `UpdatePageContent`. Direct edits bypass CMS cache invalidation and SignalR broadcasts.
- ❌ **Never browser-verify a `.cshtml` template before `ValidateTemplate` returns `success:true`** — server-side compilation catches `CS1061`/`CS0234`/`CS1503`/`RZ*` errors in ~1s; don't spend a create-page → navigate → read-500 → fix loop on errors a compile-check would have surfaced.
- ❌ **Never pass `fileName` without the `.cshtml` extension to `CreateTemplate`** — the CMS stores `FileName` exactly as passed and builds `TemplateFilePath` from it. Missing extension → template not found at runtime. Always: `fileName: "HomePage.cshtml"` ✅ Never: `fileName: "HomePage"` ❌
- ❌ Never use `@Model.Content` — always `@Html.Raw(Model.Content)`
- ❌ Never use `@row.Get<T>("field")` without wrapping — always `@(row.Get<T>("field"))`
- ❌ Never use CSS `@media`, `@keyframes`, `@font-face` unescaped — always `@@media`, `@@keyframes`, `@@font-face`
- ❌ Never put `@model` in a master layout template
- ❌ Never put `@{ Layout = "..." }` in a page or module template
- ❌ Never call `@Html.Partial()` (sync) — always `@await Html.PartialAsync()`
- ❌ Never use relative image paths — full public URLs only
- ❌ Never set `templateId` or `layoutId` to a non-existent or wrong-folderType template
- ❌ Never put content body (`content`, `excerpt`) in CSHTML — HTML only
- ❌ Never use display names in MixDb queries — always system names (`<site_name>_table`)
- ❌ Never pass display or system names as the parent/child key to `create_relationship` — it takes numeric table IDs (`parentId`/`childId`); there is no `CreateMixDbRelationshipFromPrompt` tool
- ❌ Never guess module system names — call `ListModuleContents` first
- ❌ Never call `MigrateTable` — this tool does not exist; migration is automatic
- ❌ Never use integer folderType values — string enum values only (`"Pages"` not `1`)
- ❌ Never duplicate `@RenderSection("Styles", false)` in a master layout — each section exactly once
- ❌ Never use `Model.GetModule("display name")` — always use exact `systemName` from `ListModuleContents`
- ❌ Never skip try-catch when rendering `module.Template.FilePath` in a loop — a broken module will crash the whole page without it
- ❌ Never write MixDB template code without first calling `GetMixDbBySystemName(includeColumns: true)` — field names are case-sensitive
- ❌ Never use `@model dynamic` in a Page or Post template — both require their typed ViewModel
- ❌ Never use a typed ViewModel in a Form template — form templates require `@model dynamic`
- ❌ Never omit `class="frm-mixdb-ajax"` or `data-mixdb-table` from a form tag — both are mandatory; see [form-templates.md](references/form-templates.md)
- ❌ Never put the `frm-mixdb-ajax` JavaScript handler inside a Form or Page template — it belongs in the Master layout only
- ❌ Never post a public `frm-mixdb-ajax` form to `api/v1/rest/data-source/{dataSourceName}/table/{tableName}` (permission-checked, 401/403 for anonymous) — public forms post to `api/v1/rest/mixdb/data/{tableName}` (the `[AllowAnonymous]` `PublicMixDbDataController`), which resolves the DataSource from the table itself (no `data-mixdb-datasource` needed)
- ❌ Never include `id`, `created_date_time`, or `created_by` fields in a form — auto-set by the server
- ❌ Never use `QueryRows` without a `dataSourceName` — it is required; use `QueryTable` for internal tables
- ❌ Never use `filterJson: {"status":"Published"}` (key/value) — both `filterJson` and `filtersJson` require array format `[{"fieldName":"...","value":"...","operator":"="}]`
- ❌ Never use `IMixDbDataServiceFactory` in Razor templates — it does not exist; use `@inject IMixDbDataService db`
- ❌ Never use `SearchMixDbRequestModel`, `GetPagingAsync`, or `MixQueryField` in Razor templates — internal service types; use `MixDbFilter` and `GetRowsAsync`
- ❌ **Never hardcode dynamic data in a template** — if a MixDB table exists for products, menu items, team members, etc., the template MUST load rows via `@inject IMixDbDataService db` and render them in a `@foreach` loop. Static HTML copies of database rows are always wrong: the CMS and the page diverge the moment any row is added/removed. See [mixdb-in-razor.md §NEVER HARDCODE](references/mixdb-in-razor.md) for the canonical loop + category-mapping pattern.
- ❌ Never start a CMS task (page, module, post, template, form, MixDB table) without first reading the relevant docs from `wwwroot/mixcontent/wiki/` — skipping this causes duplicate IDs, wrong templates, and broken pages
- ❌ Never write generated documents outside `wwwroot/mixcontent/` — all wiki, planning, and AI-generated files belong there

---

> **Wiki documentation is automatic.** Content created/updated/deleted through the MCP
> tools (pages, modules, posts, MixDB rows) is mirrored into the site wiki and indexed by
> the CRUD→wiki RAG pipeline (`RagImportNotificationHandler` → `RAGImportSubscriber` →
> `SiteWikiWriter`). No manual `generate_document` / `reload_wiki` step is needed after a
> build task. Use `mixcore:mix-mcp-rag` only when you want to hand-author a standalone wiki doc.

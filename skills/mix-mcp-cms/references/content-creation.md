## 🚨 CRITICAL: ValidateTemplate After Every CreateTemplate / UpdateTemplate

After every `CreateTemplate` or `UpdateTemplate` call, you MUST call `ValidateTemplate` and fix every `CS*`/`RZ*` error before creating page/module content or opening a browser. See [razor-rules.md §0](razor-rules.md) for the full rule.

```text
CreateTemplate → ValidateTemplate → fix errors (SearchReplaceTemplate/UpdateTemplate) → ValidateTemplate → success:true → proceed
```

---

# Content Creation — Template Assignment (REQUIRED)

**Every content type must use a template whose `folderType` matches the content type exactly.** Mismatched folderTypes cause silent render failures or exceptions.

For Razor template authoring rules, see [razor-rules.md](razor-rules.md).

---

## 🚨 CRITICAL RULE: Page Type (Home MUST be "Home")

Every `CreatePageContent` call has a `type` parameter. **The type MUST match the page's purpose.**

```
MixPageType enum (Mix.Constant.Enums.MixPageType):
  "System"   — internal system pages (login, error, installation)
  "Home"     — the site's home/front page
  "Article"  — content articles, about pages, info pages
  "ListPost" — blog listing / post archive pages
```

| Page purpose | `type` value |
|---|---|
| **Home / front page** | **`"Home"`** ← MANDATORY for home pages |
| About, Contact, Info, Services | `"Article"` |
| Blog listing, News archive | `"ListPost"` |
| Login, 404, System | `"System"` |

**🚨 A home page created with `type: "Article"` is WRONG.** The site can only have ONE `type: "Home"` page. The CMS uses this type to identify which page is the site root. Creating the home page as `"Article"` breaks the site's root URL resolution.

## Required folderType per content type

| Content type | `templateId` folderType | `layoutId` folderType |
|---|---|---|
| `CreatePageContent` | **`"Pages"`** | `"Masters"` (or `null`) |
| `CreateModuleContent` | **`"Modules"`** | not used |
| `CreatePostContent` | **`"Posts"`** | `"Masters"` (or `null`) |
| `UpdateMixDbTable` (detail view) | **`"Data"`** | `"Masters"` (or `null`) |

---

## Verification workflow

Before calling `CreatePageContent`, `CreateModuleContent`, or `CreatePostContent`, **always verify** the template IDs:

```
Step 0: Set the correct type for CreatePageContent
  → type must be "Home" for the site's home/front page
  → type must be "Article" for content pages (About, Contact, etc.)
  → type must be "ListPost" for blog listing pages
  → type must be "System" for internal pages (login, error, etc.)
  → NEVER use "Article" for a home page — this breaks site root resolution

Step 1: GetTemplate(id: {templateId})
  → folderType must be "Pages"   for CreatePageContent
  → folderType must be "Modules" for CreateModuleContent
  → folderType must be "Posts"   for CreatePostContent
  → If wrong or missing → create the correct template first

Step 2: GetTemplate(id: {layoutId})   [pages and posts only]
  → folderType must be "Masters"
  → If wrong or missing → set layoutId: null OR create master first
```

**Never** use a `"Pages"` template as the `templateId` for a module, or a `"Modules"` template for a post, etc. String enum names are required — **never pass integer folderType values**.

---

## Discovery before creation

```
ListTemplates(folderType: "Pages")    → find existing page templates
ListTemplates(folderType: "Modules")  → find existing module templates
ListTemplates(folderType: "Posts")    → find existing post templates
ListTemplates(folderType: "Masters")  → find existing master layouts
```

Rules:
- `content` and `excerpt` fields are **semantic HTML only** — structure tags (`<p>`, `<a>`, `<strong>`, `<em>`, `<ul>`, `<h2>`, etc.) are fine. Never put `style`/`class` attributes, `<style>`/`<script>` blocks, JS, or CSHTML in these fields. All presentation belongs in the template (`.cshtml`). Render with `@Html.Raw(Model.Content)` so tags aren't encoded.
- `templateId: null` is valid (content renders without a template wrapper)
- `layoutId: null` is valid (page/post renders without a master layout)
  - With `layoutId: null` the **page template is the entire response** — `@RenderBody()` is bypassed and no site nav/footer/widgets wrap it. For a standalone page (embedded SPA, admin/portal), make the Page template a full `<!DOCTYPE html>…</html>` document (still starting with `@model Mix.Rendering.ViewModels.PageContentViewModel`). For a role-guarded admin portal, see `system-prompts/instructions/workflows/admin-portal.md`.

---

## Get module system names before using them in templates

```
ListModuleContents(pageIndex: 0, pageSize: 50)
→ returns actual systemName values

Then in template: Model.Modules?.FirstOrDefault(m => m.SystemName == "exact-system-name")  ✅
Never filter on the display name ("Hero Banner")                                          ❌ use SystemName, not the title
(there is NO Model.GetModule(...) method — PageContentViewModel exposes only List<ModuleContentViewModel>? Modules)
```

---

## Template creation conventions

- **fileName**: `"TemplateName.cshtml"` — **must include the `.cshtml` extension** in the filename
- **extension**: `".cshtml"` — also pass separately (the dot is required)
- **folderType**: String enum only — `"Masters"`, `"Pages"`, `"Modules"`, `"Posts"`, `"Forms"`, `"Widgets"`, `"Data"` — never integers
- **Images**: Full public URLs only (`https://images.unsplash.com/...`) — no relative paths

```
✅  fileName: "MixSpaceMaster.cshtml",  extension: ".cshtml"
✅  fileName: "HomePage.cshtml",        extension: ".cshtml"
❌  fileName: "HomePage"               — missing extension; template may not resolve at runtime
```

### Deletion confirmation
- Template delete: `confirm="YES"`
- Text file delete: `confirm="YES"`

---

## 🚨 Update Workflow: Page-Module Template Consistency

When you **update a page template** (via `UpdateTemplate`) that renders linked modules, **also check the linked module templates** for consistency. The page template's wrapper markup, CSS classes, grid structure, and expected module output must match what the module templates actually produce.

### Why this matters

A page template and its linked modules form a **coupled rendering system**:
- The page template defines the container layout (grid columns, section wrappers, spacing, responsive breakpoints)
- Each module template produces HTML that slots into those containers
- If the page template changes its expected DOM structure but module templates don't adjust, the rendering breaks (misaligned grids, broken wrappers, CSS class mismatches)

### When to apply

| Trigger | Action |
|---|---|
| Update page template that renders `Model.Modules` (all-modules loop or specific `SystemName` lookup) | Review **every linked module's template** — verify the module's output HTML still fits the page's new container structure |
| Update a module template's output HTML/CSS | Review **every page template that renders this module** — verify the page's wrapper/container is compatible |
| Change CSS classes or grid structure in a page template's module wrapper | Check module templates for class name dependencies |
| Change responsive breakpoints in a page template | Check module templates for hardcoded responsive assumptions |

### Workflow

```
Step 1: Identify linked modules
  ListPageModuleAssociations(pageId) or GetPageNavigationTree(pageId)
  → note each module's templateId

Step 2: Read each linked module's template
  GetTemplate(id: {moduleTemplateId})
  → understand the current HTML output, CSS classes, and structure

Step 3: After updating the page template, validate then verify compatibility
  UpdateTemplate(id: {pageTemplateId}, content: "...")
  → ValidateTemplate(id: {pageTemplateId}) → fix errors → re-validate until success:true
  - Do the page's wrapper CSS classes match what modules expect?
  - Does the page's grid structure (column count, gap) work with module output?
  - Are responsive breakpoints consistent between page and module templates?
  - If the page changed from all-modules-loop to specific SystemName lookups, do the names still match?

Step 4: Update module templates if needed (validate each)
  UpdateTemplate(id: {moduleTemplateId}, content: "...")
  → ValidateTemplate(id: {moduleTemplateId}) → fix errors → re-validate until success:true
```

### Example

```text
Scenario: Updating a Home page template's feature grid from 3-column to 4-column

Before:
  <div class="grid grid-cols-3 gap-4">  ← page template
    @foreach (var m in Model.Modules) { <partial name="@m.TemplateFilePath" model="m" /> }
  </div>

After:
  <div class="grid grid-cols-4 gap-6">  ← page template changed
    @foreach (var m in Model.Modules) { <partial name="@m.TemplateFilePath" model="m" /> }
  </div>

Check: The feature-card module template may have hardcoded "aspect-ratio: 4/3" or "max-width: 300px"
that worked for 3-column but breaks in 4-column — update the module template too.
```

> **This rule applies to `UpdateTemplate` on Page templates only.** `CreateTemplate` on a new page template already implies you're building fresh module templates; the consistency check is inherent in the build phase order (modules before pages, per the Phase-Based Development table below).

---
## Phase-Based Website Development

| Phase | Description | MCP Tools |
|-------|-------------|-----------|
| 0 | Requirements & planning | `Search`, `GetMixDbBySystemName`, `ListPageContents` |
| 1 | MixDb schema setup | `CreateMixDbTableFromPrompt` (AI) or `CreateMixDbTable` + `CreateColumn` + `CreateRelationship` |
| 2 | Master layout | `CreateTemplate(folderType="Masters")` → **`ValidateTemplate` → fix → re-validate** — ALWAYS FIRST |
| 3 | Module templates | `CreateTemplate(folderType="Modules")` → **`ValidateTemplate` → fix → re-validate** |
| 4 | Page templates | `CreateTemplate(folderType="Pages")` → **`ValidateTemplate` → fix → re-validate** |
| 5 | Seed MixDb data | `CreateRow` (single) or `CreateMixDbTableFromPrompt` with seed data description |
| 6 | Content creation | `CreatePageContent` (verify templateId + layoutId first), `CreateModuleContent`, `CreatePostContent` |
| 7 | Wire up | `CreatePageModuleAssociation`, `CreatePagePostAssociation` |
| 8 | Verify & publish | `UpdatePageContent(status="Published")` |

---

## Assigning a Data template to a MixDB table

MixDB tables can have a `templateId` (and optionally `layoutId`) that the CMS uses to render a detail view for individual rows.

### Workflow

```
Step 1: Verify table schema
  GetMixDbBySystemName(databaseSystemName: "<site>_products", includeColumns: true)
  → note column names and types — schema-first is mandatory

Step 2: Create the Data template
  CreateTemplate(
    fileName: "ProductDetail.cshtml",
    folderType: "Data",             ← must be "Data"
    content: "..."                  ← @model Mix.DataSource.Models.MixDbRow (controller hands in the row)
  )
  → returns templateId (e.g. 16)

Step 3: Assign template to table
  UpdateMixDbTable(
    systemName: "<site>_products",
    templateId: 16                  ← from step 2
  )
```

### Data template rules

The Data-detail render path has a strict contract — the controller loads the row and hands it in as the `@model`, assigns the master layout, and renders the template as a main view. Follow the canonical **"Data-detail template contract"** in [mixdb-in-razor.md](mixdb-in-razor.md#data-detail-template-contract); the essentials:

- `@model Mix.DataSource.Models.MixDbRow` — never `@model dynamic`, never a cast, never a page/post ViewModel
- Read columns straight from the model via `Model.Get<...>` — **do NOT re-query the primary row**; `@inject IMixDbDataService` only to load *related* rows

> 🔹 **Reading MixDB rows?** `MixDbRow` has **no indexer and no `ContainsKey`** — read every field with `.Get<T>("field")` (always wrapped in `@(...)`), test existence with `.Contains("field")`, never `row["field"]` (CS0021) / `row.ContainsKey(...)` (CS1061) / `row.field`. Full rules: **mixcore:mix-mcp-cms → references/mixdb-in-razor.md "MixDbRow accessor reference".**
- **Never** assume a column exists — verify via `GetMixDbBySystemName(includeColumns: true)` first

### Linking to a data detail page

Use the `/db/{tableName}/{id}` route to link to any MixDB row detail view:

```cshtml
@* In any template — link to a product detail page *@
<a href="/db/rosewhisk_products/@(row.Get<int>("id", 0))">
    View @(row.Get<string>("name"))
</a>
```

Pattern: `/db/{systemTableName}/{rowId}`

- `{systemTableName}` — the MixDB table system name (e.g. `rosewhisk_products`)
- `{rowId}` — the integer row ID from `row.Get<int>("id", 0)`
- The route resolves the table's assigned `TemplateId`, loads the row, and renders `Views/Frontend/DataDetail.cshtml` with optional master layout from `LayoutId`

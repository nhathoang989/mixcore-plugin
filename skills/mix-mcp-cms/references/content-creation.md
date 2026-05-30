# Content Creation — Template Assignment (REQUIRED)

**Every content type must use a template whose `folderType` matches the content type exactly.** Mismatched folderTypes cause silent render failures or exceptions.

For Razor template authoring rules, see [razor-rules.md](razor-rules.md).

---

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
- `content` and `excerpt` fields are **HTML only** — never CSHTML (`@Model.Title` etc.)
- `templateId: null` is valid (content renders without a template wrapper)
- `layoutId: null` is valid (page/post renders without a master layout)
  - With `layoutId: null` the **page template is the entire response** — `@RenderBody()` is bypassed and no site nav/footer/widgets wrap it. For a standalone page (embedded SPA, admin/portal), make the Page template a full `<!DOCTYPE html>…</html>` document (still starting with `@model Mix.Rendering.ViewModels.PageContentViewModel`). For a role-guarded admin portal, see `system-prompts/instructions/workflows/admin-portal.md`.

---

## Get module system names before using them in templates

```
ListModuleContents(pageIndex: 0, pageSize: 50)
→ returns actual systemName values

Then in template: Model.GetModule("exact-system-name")  ✅
Never: Model.GetModule("Hero Banner")                   ❌ display name, won't work
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

## Phase-Based Website Development

| Phase | Description | MCP Tools |
|-------|-------------|-----------|
| 0 | Requirements & planning | `Search`, `GetMixDbBySystemName`, `ListPageContents` |
| 1 | MixDb schema setup | `CreateMixDbTableFromPrompt` (AI) or `CreateMixDbTable` + `CreateColumn` + `CreateRelationship` |
| 2 | Master layout | `CreateTemplate` with `folderType="Masters"` — ALWAYS FIRST |
| 3 | Module templates | `CreateTemplate` with `folderType="Modules"` |
| 4 | Page templates | `CreateTemplate` with `folderType="Pages"` |
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
    content: "..."                  ← @model dynamic + @inject IMixDbDataService db
  )
  → returns templateId (e.g. 16)

Step 3: Assign template to table
  UpdateMixDbTable(
    systemName: "<site>_products",
    templateId: 16                  ← from step 2
  )
```

### Data template rules (see also [razor-rules.md §8](razor-rules.md))

- `@model dynamic` — always, no typed ViewModel
- The controller loads the row and passes it as `Model` — **do NOT inject `IMixDbDataService` or query the DB in the template**
- Cast the model at the top: `var product = (MixDbRow)Model;`
- Guard optional columns: `row.Contains("image_url")` before rendering
- `MixDbRow.Empty` is returned (not null) when row not found — check `row.IsEmpty`
- **Never** assume a column exists — verify via `GetMixDbBySystemName` first

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

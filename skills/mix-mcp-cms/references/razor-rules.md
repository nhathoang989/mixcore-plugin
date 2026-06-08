# Razor Template Rules (P0 — Always Apply)

Detailed Razor syntax rules for Mixcore templates. Loaded by `mixcore:mix-mcp-cms` when writing or reviewing `.cshtml` templates. Pair with [content-creation.md](content-creation.md) for folderType verification, [form-templates.md](form-templates.md) for form-specific rules, and [mixdb-in-razor.md](mixdb-in-razor.md) for MixDB data access patterns used in Data templates.

---

## 1. Mandatory `@model` declarations

| Template type | folderType | `@model` |
|---|---|---|
| Master layout | `"Masters"` | **NONE** — masters use `@RenderBody()`, never `@model` |
| Page template | `"Pages"` | `@model Mix.Rendering.ViewModels.PageContentViewModel` |
| Module template | `"Modules"` | `@model Mix.Rendering.ViewModels.ModuleContentViewModel` (or `@model dynamic` for MixDb-driven) |
| Post template | `"Posts"` | `@model Mix.Rendering.ViewModels.PostContentViewModel` |
| Form template | `"Forms"` | `@model dynamic` — forms write TO MixDb, no typed ViewModel. Must include `class="frm-mixdb-ajax"` and `data-mixdb-table="<site_name>_tablename"` on the `<form>` tag |
| Widget template | `"Widgets"` | `@model dynamic` (default) or `@model Mix.Rendering.ViewModels.ModuleContentViewModel` only when the parent explicitly passes a module model |
| Data template | `"Data"` | `@model dynamic` — reads FROM MixDb via `IMixDbDataService`. Only renders columns that exist in the actual table schema. See [mixdb-in-razor.md](mixdb-in-razor.md) for query patterns. |

**Never** use `@model PageContentViewModel` in a Form template. **Never** include `@{ Layout = "..." }` inside page/module templates — layout is assigned via `layoutId` in `CreatePageContent`.

---

## 2. CSS `@` escaping — all at-rules must be doubled

```cshtml
✅  @@media (max-width: 768px) { }
✅  @@keyframes fadeIn { }
✅  @@font-face { }
✅  @@import url(...);
✅  @@supports (display: grid) { }

❌  @media   @keyframes   @font-face   (all cause Razor syntax errors)
```

---

## 3. HTML content rendering

```cshtml
✅  @Html.Raw(Model.Content)    — for trusted CMS HTML
✅  @Model.Title                — plain text, auto-encoded (safe)
✅  @Json.Serialize(Model.Data) — for JS contexts
✅  @Url.Encode(searchTerm)     — for URL parameters

❌  @Model.Content              — won't render tags (encodes < and >)
❌  @Html.Raw(userInput)        — XSS risk with user-submitted content
```

---

## 4. 🚨 Partial view syntax — ALWAYS `../[FolderType]/[FileName].cshtml`

🚨 **CRITICAL RULE:** Two non-negotiable requirements for every partial path:
1. **Always** prefix with `../[FolderType]/` — never a bare filename or root-relative path.
2. **FileName MUST include the `.cshtml` extension** — `Header.cshtml`, never `Header`.

```cshtml
✅  @await Html.PartialAsync("../Modules/Header.cshtml")
✅  @await Html.PartialAsync("../Modules/ProductCard.cshtml", product)
✅  @await Html.PartialAsync("../Widgets/Newsletter.cshtml")
✅  @await Html.PartialAsync("../" + module.Template.FilePath, module)
✅  @await Html.PartialAsync(module.Template.GetFilePath(themeName), module)

❌  @Html.Partial("Header")                       — sync, deprecated
❌  @await Html.PartialAsync("Header")            — missing ../ prefix and .cshtml extension
❌  @await Html.PartialAsync("Modules/Header")    — missing ../ prefix and .cshtml extension
❌  @await Html.PartialAsync("/Modules/Header")   — wrong prefix; use "../" not "/"
❌  @await Html.PartialAsync("/" + module.Template.FilePath, module) — wrong prefix; use "../"
❌  @await Html.PartialAsync("../Modules/Header") — missing .cshtml extension
❌  <partial name="Modules/Header" />             — tag helper (not preferred)
```

Path pattern: `../[FolderType]/[FileName].cshtml`

---

## 5. Master layout structure — section counts matter

```cshtml
<!DOCTYPE html>
<html>
<head>
    @RenderSection("Schema", false)       @* 0 or 1 times *@
    @RenderSection("Seo", false)          @* required — declare in every master; pages fill optionally *@
    <!--[STYLES]-->                       @* Mix CMS styles injection point — keep this comment *@
    @RenderSection("Styles", false)       @* exactly 1 time *@
</head>
<body>
    @RenderBody()                         @* exactly 1 time *@
    <script src="~/js/scripts.js"></script>
    @RenderSection("Scripts", false)      @* exactly 1 time *@
</body>
</html>
```

Each `@RenderSection` name must appear **exactly once**. Duplicating any section name causes `InvalidOperationException: The section 'X' has already been rendered.`

**Required vs optional sections:**
| Section | Master must declare | Page must provide |
|---|---|---|
| `Seo` | ✅ Required in every master | ❌ Optional (pages fill when needed) |
| `Styles` | ✅ Required in every master | ❌ Optional |
| `Scripts` | ✅ Required in every master | ❌ Optional |
| `Schema` | Optional | Optional |

Pages inject meta tags, OG tags, and structured data via `@section Seo { <meta ...> }`. The master must declare the slot or those tags are silently dropped.

---

## 6. MixDB value rendering — use `row.Get<T>()` inside `@(...)`

```cshtml
✅  @(row.Get<string>("name"))
✅  @(row.Get<double>("price", 0.0).ToString("N2"))
✅  @(row.Get<DateTime>("created_at").ToString("MMM dd, yyyy"))
✅  <img src="@(row.Get<string>("image_url"))" alt="@(row.Get<string>("name"))">

❌  @row.Get<string>("name")          — Razor parser confusion; value will NOT render
❌  @row.Get<double>("price")         — silently outputs nothing
```

The `<` in generic method calls confuses Razor's parser. Always wrap `Get<T>()` in `@(...)`.

---

## 7. Module rendering in page templates

### Pattern 1: Render all modules dynamically (recommended for any page type)

```cshtml
@model Mix.Rendering.ViewModels.PageContentViewModel

@if (Model.Modules != null && Model.Modules.Any())
{
    @foreach (var module in Model.Modules.OrderBy(m => m.Priority))
    {
        <div class="module-section" data-module-id="@module.Id">
            @try
            {
                @await Html.PartialAsync("../" + module.Template.FilePath, module)
            }
            catch (Exception ex)
            {
                <div class="module-error p-4 border border-danger rounded my-2">
                    <strong>Module error:</strong> @module.Title (@module.SystemName)<br>
                    @ex.Message — Template: @module.Template?.FilePath
                </div>
            }
        </div>
    }
}
```

The try-catch ensures a broken module doesn't crash the whole page. Always wrap `module.Template.FilePath` renders in try-catch.

### Pattern 2: Render a specific module by system name

```cshtml
@{
    var heroModule = Model.GetModule("hero-banner");      // exact systemName only
    var gridModule = Model.GetModule("services-grid");
}

@if (heroModule != null)
{
    @await Html.PartialAsync("../" + heroModule.Template.FilePath, heroModule)
}
```

**Always call `ListModuleContents` to get exact `systemName` values before using `Model.GetModule()`.** Never guess — display names will return null.

---

## 8. Data template pattern — MixDB-driven, schema-first

Data templates (folderType `"Data"`) render rows from a MixDB table. They **must** be written schema-first: call `GetMixDbBySystemName` to confirm exact column names and types before writing any `Get<T>()` call. Only render columns that exist in the actual schema — never assume a column is present.

```cshtml
@model dynamic
@using Mix.DataSource.Models

@{
    // Controller loads the row and passes it as Model.
    // Always verify table schema first via GetMixDbBySystemName before writing this template.
    // Only reference columns confirmed to exist.
    var product = (MixDbRow)Model;
}

@* Detail view — render a single row passed by the controller *@
@if (!product.IsEmpty)
{
    <div class="data-row">
        @* Only render columns that exist in the schema *@
        <h3>@(row.Get<string>("name"))</h3>

        @* Guard optional columns with Contains() before rendering *@
        @if (row.Contains("image_url") && row.Get<string>("image_url") != null)
        {
            <img src="@(row.Get<string>("image_url"))" alt="@(row.Get<string>("name"))">
        }

        @if (row.Contains("price"))
        {
            <span>$@(row.Get<double>("price", 0.0).ToString("N2"))</span>
        }
    </div>
}
```

### Rules
- **Schema-first**: call `GetMixDbBySystemName(includeColumns: true)` before writing the template. See [mixdb-in-razor.md](mixdb-in-razor.md).
- **Guard optional columns** with `row.Contains("col")` — missing columns return default values silently, not exceptions, but conditional rendering prevents meaningless empty elements.
- **Never assume** a column exists just because the MixDB table was designed with it — columns can be added/removed independently.
- `MixDbRow` is a struct: no `?.` null-conditional; use `row.IsEmpty` for single-row checks.
- All `Get<T>()` calls must be inside `@(...)` — see rule 6.

---

## 9. Critical: Widget Partial Rendering — Styles/Scripts Params Are Dropped

When a template is included via `@await Html.PartialAsync(...)`, only the `Content` field is rendered. The `Styles` and `Scripts` template parameters are silently ignored.

**Rule:** For any widget template rendered as a partial, put all `<style>`, CDN `<script src>`, and `<script>` blocks inside the `Content` field.

---

## 10. CDN URL escaping in HTML attributes

When a CDN URL contains `@package-name` (scoped npm packages), escape `@` as `@@` in Razor:

```cshtml
<!-- WRONG — Razor treats @microsoft as an expression -->
<script src="https://unpkg.com/@microsoft/signalr@8.0.7/dist/browser/signalr.min.js"></script>

<!-- CORRECT -->
<script src="https://unpkg.com/@@microsoft/signalr@8.0.7/dist/browser/signalr.min.js"></script>
```

Note: `@8.0.7` does NOT need escaping because digits cannot start a Razor expression.

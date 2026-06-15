# Razor Template Rules (P0 — Always Apply)

Detailed Razor syntax rules for Mixcore templates. Loaded by `mixcore:mix-mcp-cms` when writing or reviewing `.cshtml` templates. Pair with [content-creation.md](content-creation.md) for folderType verification, [form-templates.md](form-templates.md) for form-specific rules, and [mixdb-in-razor.md](mixdb-in-razor.md) for MixDB data access patterns used in Data templates.

---

## 0. Compile-check server-side after every write (do this first)

🚨 **CRITICAL RULE: after each `CreateTemplate`/`UpdateTemplate`, call `ValidateTemplate` and fix any errors before rendering a page or opening a browser.** It compiles the Razor server-side via the runtime view engine and returns `{ success, skipped, errors:[{ line, message, code }] }` in ~1s, so the syntax mistakes the rest of this file warns about (`@@`-escaping, generic-call `@(...)` wrapping, wrong `@model`, missing `.cshtml`) surface as a structured `CS*`/`RZ*` diagnostic instead of a 500 page found only by a browser round-trip.

```text
ValidateTemplate(templateId: 42)
  → { "success": false, "errors": [ { "line": 12, "message": "'string' does not contain a definition for 'Naem'", "code": "CS1061" } ] }
ValidateTemplate(content: "<h1>@Model.Title</h1>", folderType: "Pages")   # pre-flight raw markup, no DB write
```

- Loop `Validate → fix (SearchReplaceTemplate/UpdateTemplate) → Validate` until `success:true`, then create the page/module content.
- `.liquid` templates return `skipped:true` — Razor compilation does not apply to them.

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
| Data template (record-detail, `/db/{table}/{id}`) | `"Data"` | `@model Mix.DataSource.Models.MixDbRow` — the controller hands in the **already-loaded row** as the model and renders the template as a **main view** (so its `@section Seo` reaches the master). **No `Layout` directive** (the controller assigns it), **no re-query** — read columns from `Model.Get<…>`. Only `@inject IMixDbDataService db` to load *related* rows. Only render columns that exist in the schema. See [the Data-detail contract](mixdb-in-razor.md#data-detail-template-contract). |

**Never** use `@model PageContentViewModel` in a Form template. **Never** set the layout inside a page/module template — no `@{ Layout = "..." }` and no `@{ Layout = null; }`. The layout is a property of the *page content*, assigned via the `layoutId` parameter of `CreatePageContent` (a master template id, or `null` for a standalone full-document page); a `Layout` directive in the template body is ignored.

---

## 2. CSS `@` escaping — at-rules doubled, Razor directives NOT

Double `@@` applies **only** to CSS at-rules (and literal `@` in CDN / scoped-npm URLs, §10). **Never double a Razor directive** — `@model`, `@inject`, `@using`, `@if`, `@foreach`, `@await`, `@RenderBody`, `@RenderSection`, `@Html.Raw`, `@Model.X`, `@(...)` stay single-`@`; doubling them makes Razor emit the directive as literal text in the page instead of executing it.

```cshtml
✅  @@media (max-width: 768px) { }
✅  @@keyframes fadeIn { }
✅  @@font-face { }
✅  @@import url(...);
✅  @@supports (display: grid) { }
✅  @model dynamic   @if (x) { }   @foreach (var i in list) { }   @Html.Raw(html)   ← directives single-@

❌  @media   @keyframes   @font-face   (bare CSS at-rules cause Razor syntax errors)
❌  @@model   @@if   @@foreach   @@Html.Raw   (doubled directives render as literal text)
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

⚠️ **`@Json.Serialize` camelCases keys.** ASP.NET Core's `IJsonHelper` lowercases PascalCase property names by default (`Title` → `title`, `Facebook` → `facebook`), so inline JS that reads PascalCase keys will break. Use a case-insensitive read, lowercase/snake_case keys, or serialize a `Dictionary`/anonymous object with the exact keys you want.

---

## 4. 🚨 Partial view syntax — ALWAYS `../[FolderType]/[FileName].cshtml`

🚨 **CRITICAL RULE:** Two non-negotiable requirements for every partial path:
1. **Always** prefix with `../[FolderType]/` — never a bare filename or root-relative path.
2. **FileName MUST include the `.cshtml` extension** — `Header.cshtml`, never `Header`.

> The same `.cshtml` rule applies when **creating** a template: pass `CreateTemplate(fileName: "Master.cshtml", …)`, never `"Master"`. The renderer resolves a layout/partial path as `{FileFolder}/{FileName}` verbatim, so a `fileName` without the extension yields an unresolvable path (`The partial view 'X' was not found`).

```cshtml
✅  @await Html.PartialAsync("../Modules/Header.cshtml")
✅  @await Html.PartialAsync("../Modules/ProductCard.cshtml", product)
✅  @await Html.PartialAsync("../Widgets/Newsletter.cshtml")
✅  <partial name="@module.TemplateFilePath" model="module" />   @* module.TemplateFilePath is already a leading-slash absolute path, e.g. /Templates/MyTheme/Header.cshtml *@

❌  @Html.Partial("Header")                       — sync, deprecated
❌  @await Html.PartialAsync("Header")            — missing ../ prefix and .cshtml extension
❌  @await Html.PartialAsync("Modules/Header")    — missing ../ prefix and .cshtml extension
❌  @await Html.PartialAsync("/Modules/Header")   — wrong prefix; use "../" not "/"
❌  @await Html.PartialAsync("../" + module.Template.FilePath, module) — `ModuleContentViewModel` has NO `Template` nav property; use `module.TemplateFilePath`
❌  @await Html.PartialAsync("../Modules/Header") — missing .cshtml extension
```

Two ways to name a partial:
- **Literal hand-authored partials** (`Header.cshtml`, `ProductCard.cshtml`): `../[FolderType]/[FileName].cshtml` with `Html.PartialAsync`.
- **A module's own template** (rendered from a `ModuleContentViewModel`): use `module.TemplateFilePath` directly — it is already a leading-slash **absolute** path (e.g. `/Templates/MyTheme/Header.cshtml`) set by the content handlers. Do NOT prefix `"../"` and do NOT use `module.Template.FilePath` — the rendering `Mix.Rendering.ViewModels.ModuleContentViewModel` has no `Template` nav property, only `string? TemplateFilePath`.

---

## 5. Master layout structure — section counts matter

```cshtml
<!DOCTYPE html>
<html>
<head>
    <link rel="icon" type="image/svg+xml" href="/mixcontent/documents/generated-data/<slug>-favicon.svg" />  @* brand favicon — generate an SVG (see below) *@
    @RenderSection("Seo", false)          @* MANDATORY — declare once; false only lets a child page skip it, not the master *@
    <!--[STYLES]-->                       @* Mix CMS styles injection point — keep this comment *@
    @RenderSection("Styles", false)       @* MANDATORY — declare once; false only lets a child page skip it, not the master *@
</head>
<body>
    @RenderBody()                         @* exactly 1 time *@
    <script src="~/js/scripts.js"></script>
    @RenderSection("Scripts", false)      @* MANDATORY — declare once; false only lets a child page skip it, not the master *@
</body>
</html>
```

Each `@RenderSection` name must appear **exactly once**. Duplicating any section name causes `InvalidOperationException: The section 'X' has already been rendered.`

🚨 **`false` ≠ optional.** The `false` arg only tells Razor not to throw when a *child page* omits the section — the master MUST still declare `Seo`, `Styles`, and `Scripts` (each exactly once). Never describe these three as "optional sections"; `Schema` is the only optional one.

**Required vs optional sections (these apply to the MASTER ↔ host-view layer only):**
| Section | Master must declare | Provided by |
|---|---|---|
| `Seo` | ✅ Required in every master | The host view (`PublicPage.cshtml`), built from the page's SEO fields |
| `Styles` | ✅ Required in every master | The host view, from the template's `Styles` field |
| `Scripts` | ✅ Required in every master | The host view, from the template's `Scripts` field |

🚨 **CRITICAL RULE: never read `Model.*` in a master — not even dynamically.** A master has no `@model`, but `Model` is still available as `dynamic` at the layout layer, so `Model.SeoTitle` **compiles and only blows up at runtime**. The model the layout receives is whatever the host view rendered — `PageContentViewModel` for a page, `PostContentViewModel` for a post, or **`DataDetailViewModel` for a MixDB record-detail page (`/db/{tableName}/{id}`), which has NO `SeoTitle`/`Title`/`SeoDescription`**. Reaching into the model couples the master to one shape and throws `RuntimeBinderException: 'DataDetailViewModel' does not contain a definition for 'SeoTitle'` for the others. Get the title/SEO through model-agnostic channels every host view supplies:

```razor
@* ❌ WRONG — throws at runtime on a Data-detail page (and any non-page model) *@
@{ var pageTitle = !string.IsNullOrEmpty(Model.SeoTitle) ? Model.SeoTitle : Model.Title; }

@* ✅ CORRECT — ViewData["Title"] is set by every host view; SEO <meta> arrive via @RenderSection("Seo") *@
@{ var pageTitle = ViewData["Title"] as string ?? "Site Name"; }
<head>
    <title>@pageTitle</title>
    @RenderSection("Seo", false)   @* per-page meta/OG/canonical injected by the host view *@
</head>
```

**Favicon (generate a suitable one — do not hard-code a generic globe):** author a 32×32 `viewBox` SVG in the site's brand colors (a monogram or simple glyph), write it with `write_text_file(path: "generated-data/<slug>-favicon.svg", content: "<svg …>")` — TextFileTool paths are relative to `wwwroot/mixcontent/documents/`, so it serves at `/mixcontent/documents/generated-data/<slug>-favicon.svg` — then reference it in `<head>` as shown above. Example: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32"><rect width="32" height="32" rx="6" fill="#007bff"/><text x="16" y="22" font-family="system-ui,sans-serif" font-size="18" font-weight="700" text-anchor="middle" fill="#fff">M</text></svg>`. A full `https://…` public URL in `href` is an acceptable alternative.

🚨 **Pages/Modules templates are rendered as nested `<partial>` by the host view** (`PublicPage.cshtml` does `<partial name="@Model.TemplateFilePath" model="@Model" />`). `@section` blocks declared **inside a partial are silently dropped** — Razor only honors `@section` in a view that participates in the layout (the host view / master). The host view itself supplies `@section Seo`, `@section Styles`, and `@section Scripts`, pulling Styles/Scripts from the template's `Styles`/`Scripts` fields.

**Therefore, deliver page/module CSS+JS one of two ways — NOT in `@section Styles { … }` / `@section Scripts { … }` (which only work in the host/master layer):**

- **Preferred — the template's `Styles`/`Scripts` fields**: pass CSS to `CreateTemplate(styles: …)` and JS to `CreateTemplate(scripts: …)`. The host view pipes them into the master's `@RenderSection("Styles")` (in `<head>`) and `@RenderSection("Scripts")` (before `</body>`). 🚨 `UpdateTemplate` is **content-only** (no `styles`/`scripts` params) — so use this on the initial `CreateTemplate`. CSS at-rules in these raw fields are **plain** (`@media`), no `@@` escaping.
- **Inline `<style>`/`<script>` in the body**: renders via `@RenderBody()`. Required when editing an existing template through `UpdateTemplate`. Escape at-rules as `@@media`/`@@keyframes` (it's `.cshtml`).

### 5a. Every nav link MUST resolve — no dead links

A master's header/footer nav renders on **every** page, so one broken `href` breaks the whole site. Before writing each nav `<a href>`, decide page-vs-section and make it resolve:

- **Separate page** → the `href` must match a page's URL. `href="/about"` only works if a page exists with `seoName: "about"`. For every multi-page nav target, **create the page** with `CreatePageContent` (this master as `layoutId`) before or right after saving the master.
- **Section of the current page (one-pager)** → use an in-page anchor: `href="#about"` → `<section id="about">` in the body that renders inside `@RenderBody()`.

Never ship `href="#"`, `href="javascript:void(0)"`, or a path to a page you haven't created. The brand/logo `href="/"` (home) is always valid. Example layouts use placeholder paths (`/about`, `/services`, …) — replace them with links to pages you actually create or real `#section` anchors.

### 5b. Active navigation state (shared master, no per-page slug)

The master layout renders for every page and has **no `@model`**, so it cannot know the current page server-side. Set the active nav link **client-side**: match `window.location.pathname` against each link's `href`, then add an `.active` class (+ `aria-current="page"`). Match the exact path OR a section prefix (so `/docs` stays active on `/docs/api`), and guard `'/'` so the home link doesn't match everything.

```html
<script>
(function () {
    var path = (location.pathname || '/').replace(/\/+$/, '') || '/';
    document.querySelectorAll('.nav-links a, #mobile-menu a').forEach(function (a) {
        var href = a.getAttribute('href');
        if (!href || href.charAt(0) !== '/' || href === '/p/login') return;
        var clean = href.replace(/\/+$/, '') || '/';
        if (clean === path || (clean !== '/' && path.indexOf(clean + '/') === 0)) {
            a.classList.add('active');
            a.setAttribute('aria-current', 'page');
        }
    });
})();
</script>
```

Style `.active` like the link's hover state. Do this in JS — the master has no page context, so a server-side `Model.SeoName` check isn't available at the master layer.

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
                <partial name="@module.TemplateFilePath" model="module" />
            }
            catch (Exception ex)
            {
                <div class="module-error p-4 border border-danger rounded my-2">
                    <strong>Module error:</strong> @module.Title (@module.SystemName)<br>
                    @ex.Message — Template: @module.TemplateFilePath
                </div>
            }
        </div>
    }
}
```

The try-catch ensures a broken module doesn't crash the whole page. Always wrap module renders in try-catch. `module.TemplateFilePath` is already a leading-slash absolute path (`/Templates/.../X.cshtml`) — there is no `module.Template` nav property.

### Pattern 2: Render a specific module by system name

`PageContentViewModel` exposes only `List<ModuleContentViewModel>? Modules` — there is **no** `GetModule(...)` method. Select by `SystemName` with LINQ:

```cshtml
@{
    var heroModule = Model.Modules?.FirstOrDefault(m => m.SystemName == "hero-banner");   // exact systemName only
    var gridModule = Model.Modules?.FirstOrDefault(m => m.SystemName == "services-grid");
}

@if (heroModule != null)
{
    <partial name="@heroModule.TemplateFilePath" model="heroModule" />
}
```

**Always call `ListModuleContents` to get exact `systemName` values before filtering `Model.Modules`.** Never guess — a wrong `SystemName` returns null.

---

## 8. Data template pattern — MixDB-driven, schema-first

Data templates (folderType `"Data"`) render rows from a MixDB table. They **must** be written schema-first: call `GetMixDbBySystemName` to confirm exact column names and types before writing any `Get<T>()` call. Only render columns that exist in the actual schema — never assume a column is present.

```cshtml
@model Mix.DataSource.Models.MixDbRow
@using Mix.DataSource.Models

@{
    // The controller loads the row and hands it in as Model — do NOT re-query the primary row.
    // Always verify table schema first via GetMixDbBySystemName before writing this template.
    // Only reference columns confirmed to exist.
}

@* Detail view — render the single row passed by the controller *@
@if (!Model.IsEmpty)
{
    <div class="data-row">
        @* Only render columns that exist in the schema *@
        <h3>@(Model.Get<string>("name"))</h3>

        @* Guard optional columns with Contains() before rendering *@
        @if (Model.Contains("image_url") && Model.Get<string>("image_url") != null)
        {
            <img src="@(Model.Get<string>("image_url"))" alt="@(Model.Get<string>("name"))">
        }

        @if (Model.Contains("price"))
        {
            <span>$@(Model.Get<double>("price", 0.0).ToString("N2"))</span>
        }
    </div>
}
```

### Rules
- **Read the primary row from `Model`, never re-query it.** The controller hands in the already-loaded `MixDbRow`. Inject `@inject IMixDbDataService db` **only for RELATED rows**, never to re-fetch the primary row. See [mixdb-in-razor.md → Data-detail template contract](mixdb-in-razor.md#data-detail-template-contract).
- **Schema-first**: call `GetMixDbBySystemName(includeColumns: true)` before writing the template. See [mixdb-in-razor.md](mixdb-in-razor.md).
- **Guard optional columns** with `Model.Contains("col")` — missing columns return default values silently, not exceptions, but conditional rendering prevents meaningless empty elements.
- **Never assume** a column exists just because the MixDB table was designed with it — columns can be added/removed independently.
- `MixDbRow` is a struct: no `?.` null-conditional; use `Model.IsEmpty` for the primary-row check (and `row.IsEmpty` for any related row you load via `db`).
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

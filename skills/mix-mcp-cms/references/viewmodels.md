# Template ViewModel Properties

The strongly-typed model available in each template type, by `folderType`. `Content` and
`Excerpt` hold **semantic HTML** (structure tags only — no `style`/`class`/`<script>`/`<style>`).
Always render with `@Html.Raw(Model.Content)` / `@Html.Raw(Model.Excerpt)`. Page and Post
templates **require** their typed ViewModel (`@model …`); Module templates may use the typed
model or `@model dynamic`; Widget and Form templates use `@model dynamic`.

| folderType | `@model` | Typed ViewModel |
|---|---|---|
| `Pages` | required | `PageContentViewModel` |
| `Posts` | required | `PostContentViewModel` |
| `Modules` | typed **or** `dynamic` | `ModuleContentViewModel` |
| `Widgets` | `@model dynamic` | — (no typed model) |
| `Forms` | `@model dynamic` | — (binds to MixDB columns) |
| `Masters` | none | — (never put `@model` in a master) |
| `Data` | `@model Mix.DataSource.Models.MixDbRow` | — (MixDB record detail at `/db/{table}/{id}`; controller passes the loaded row in as the model — **no `Layout`**, no re-query; `@section Seo` works because it renders as a main view) |

> 🚨 **The renderer passes the page/post as the typed `Model` (`FrontendController` does `return View(page)`), NOT via `ViewBag`.** `ViewBag.Content` / `ViewBag.Title` / `ViewBag.Description` / `ViewBag.Page` are **never populated** — reading them renders an **empty body/hero even though the page's `Content` field is full** (the #1 cause of "page renders no content"). Always read page data from `@Model.*`: `@Html.Raw(Model.Content)`, `@Model.Title`, `@Html.Raw(Model.Excerpt)`. The master layout *does* read `ViewBag.Title`/`ViewBag.Description` for the document `<title>`/meta — but only what **your template** assigns: set `ViewBag.Title = Model.Title;` yourself in an `@{ }` block to prime it (as `HomePage.cshtml` does).

---

## PageContentViewModel (`folderType="Pages"`)

| Property | Type | Notes |
|---|---|---|
| `Model.Id` | `int` | Page content ID |
| `Model.Title` | `string` | Page title |
| `Model.Content` | `string` | **Semantic HTML** — always `@Html.Raw(Model.Content)`. No `style`/`class`/`<script>`/`<style>`. |
| `Model.Excerpt` | `string?` | Short description, semantic HTML — `@Html.Raw(Model.Excerpt)`. |
| `Model.SeoName` | `string` | URL slug |
| `Model.Modules` | `List<ModuleContentViewModel>` | Associated modules (see [razor-rules.md](razor-rules.md) §7) |
| `Model.LastModified` | `DateTime?` | Use null-conditional: `Model.LastModified?.ToString(...)` |
| `Model.ModifiedBy` | `string?` | Username of last editor |

> **`pageType`** is a `create_page_content` argument (not a `Model` property): pass the string
> `"System"`, `"Home"`, `"Article"`, etc. When a page sets `layoutId: null`, the page template is
> the entire response — it must be a full HTML document and `@RenderBody()` is bypassed.

---

## PostContentViewModel (`folderType="Posts"`)

| Property | Type | Notes |
|---|---|---|
| `Model.Id` | `int` | Post ID |
| `Model.Title` | `string` | Post title |
| `Model.Content` | `string` | **Semantic HTML** — always `@Html.Raw(Model.Content)`. No `style`/`class`/`<script>`/`<style>`. |
| `Model.Excerpt` | `string?` | Teaser, semantic HTML — `@Html.Raw(Model.Excerpt)`. |
| `Model.SeoName` | `string` | URL slug |
| `Model.CreatedDateTime` | `DateTime` | Creation date — always present |
| `Model.PublishedDateTime` | `DateTime?` | Publication date |
| `Model.ModifiedBy` | `string?` | Author/editor name |
| `Model.Image` | `string?` | Featured image URL |
| `Model.Tags` | `string?` | Comma-separated tags — split with `Model.Tags?.Split(',')` |
| `Model.Source` | `string?` | Content source |

---

## ModuleContentViewModel (`folderType="Modules"`)

| Property | Type | Notes |
|---|---|---|
| `Model.Id` | `int` | Module ID |
| `Model.Title` | `string` | Module title |
| `Model.SystemName` | `string` | Unique slug — filter `page.Modules` by this value (e.g. `Modules?.FirstOrDefault(m => m.SystemName == "x")`); there is no `Model.GetModule()` |
| `Model.Content` | `string` | **Semantic HTML** — render with `@Html.Raw(Model.Content)`. No `style`/`class`/`<script>`/`<style>`. |
| `Model.Excerpt` | `string?` | Short semantic HTML — `@Html.Raw(Model.Excerpt)`. |
| `Model.SeoName` | `string` | URL slug |
| `Model.Priority` | `int` | Display order |
| `Model.ClassName` | `string` | Optional CSS wrapper class |
| `Model.PageSize` | `int?` | Optional paging hint |
| `Model.Type` | `MixModuleType` | `"Content"`, `"Data"`, `"ListPost"` |
| `Model.TemplateFilePath` | `string?` | Leading-slash absolute path (e.g. `/Templates/.../X.cshtml`) — render with `<partial name="@Model.TemplateFilePath" model="Model" />`. There is no `Model.Template` nav property on the rendering `ModuleContentViewModel` |
| `Model.Posts` | `List<PostContentViewModel>` | Associated posts |
| `Model.DetailUrl` | `string` | Computed `/Module/{Id}/{SeoName}` — use for "read more" links instead of building URLs by hand |

---

## Widget templates (`folderType="Widgets"`)

Widgets are rendered with `Html.PartialAsync` and have **no typed ViewModel** — declare `@model dynamic`.
All CSS/JS must live in the widget's `Content`; the `styles` and `scripts` partial parameters are
**silently dropped** in this render context, so do not rely on them. Escape CDN `@` in scoped npm
package names (`@@microsoft/signalr`); a version like `@8.0.7` (digit after `@`) needs no escape.

---

## Form templates (`folderType="Forms"`)

`@model dynamic` only — form fields bind directly to MixDB table columns, not to a ViewModel.
See [form-templates.md](form-templates.md) for the `frm-mixdb-ajax` contract and submit endpoint.

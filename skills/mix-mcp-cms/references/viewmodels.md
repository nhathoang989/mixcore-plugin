# Template ViewModel Properties

The strongly-typed model available in each template type, by `folderType`. Always use
`@Html.Raw()` for HTML fields (`Content`, `Excerpt`). Page and Post templates **require**
their typed ViewModel (`@model …`); Module templates may use the typed model or `@model dynamic`;
Widget and Form templates use `@model dynamic`.

| folderType | `@model` | Typed ViewModel |
|---|---|---|
| `Pages` | required | `PageContentViewModel` |
| `Posts` | required | `PostContentViewModel` |
| `Modules` | typed **or** `dynamic` | `ModuleContentViewModel` |
| `Widgets` | `@model dynamic` | — (no typed model) |
| `Forms` | `@model dynamic` | — (binds to MixDB columns) |
| `Masters` | none | — (never put `@model` in a master) |
| `Data` | `@model dynamic` + `@inject IMixDbDataService db` | — (MixDB record detail) |

---

## PageContentViewModel (`folderType="Pages"`)

| Property | Type | Notes |
|---|---|---|
| `Model.Id` | `int` | Page content ID |
| `Model.Title` | `string` | Page title |
| `Model.Content` | `string` | **HTML** — always `@Html.Raw(Model.Content)` |
| `Model.Excerpt` | `string?` | Short description — `@Html.Raw(Model.Excerpt)` |
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
| `Model.Content` | `string` | **HTML** — always `@Html.Raw(Model.Content)` |
| `Model.Excerpt` | `string?` | Teaser — `@Html.Raw(Model.Excerpt)` |
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
| `Model.SystemName` | `string` | Unique slug — use the exact value in `Model.GetModule()` |
| `Model.Content` | `string` | **HTML** — `@Html.Raw(Model.Content)` |
| `Model.Excerpt` | `string?` | Short HTML — `@Html.Raw(Model.Excerpt)` |
| `Model.SeoName` | `string` | URL slug |
| `Model.Priority` | `int` | Display order |
| `Model.ClassName` | `string` | Optional CSS wrapper class |
| `Model.PageSize` | `int?` | Optional paging hint |
| `Model.Type` | `MixModuleType` | `"Content"`, `"Data"`, `"ListPost"` |
| `Model.Template` | `TemplateViewModel` | Use `"../" + Model.Template.FilePath` or `Model.Template.GetFilePath(themeName)` in `PartialAsync` |
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

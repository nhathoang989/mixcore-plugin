# MixDB in Razor Templates

How to query and render MixDB data from `.cshtml` templates. Pair with [data-loading.md](data-loading.md) when choosing between Razor and MCP paths.

---

## 🚨 NEVER HARDCODE DYNAMIC DATA

If a site has a MixDB table for products, menu items, team members, etc., the template **MUST** load that data via `IMixDbDataService` — never copy-paste records as static HTML.

**Why this matters:** Hardcoded data creates a split truth: the CMS database diverges from what renders on screen. Adding or removing a row in the admin has no effect. This was the exact bug in the `RoseWhiskMenu.cshtml` template (May 2026), where 4 extra products existed only in HTML, not in the `rosewhisk_products` table.

```
❌ WRONG — data is frozen in the template HTML
<div class="menu-item"><h3>Strawberry Rose Cake</h3><span>$48.00</span></div>
<div class="menu-item"><h3>Earl Grey Chiffon</h3><span>$38.00</span></div>

✅ RIGHT — data comes from the database
@foreach (var p in await db.GetRowsAsync("rosewhisk_products")) {
    <div class="menu-item"><h3>@(p.Get<string>("name"))</h3><span>$@(p.Get<double>("price").ToString("N2"))</span></div>
}
```

**Test:** Ask yourself — "if I add a row in MixDB admin, will it appear here without editing the template?" If no, the template is wrong.

---

## Schema-First Approach (REQUIRED before writing template code)

**Before writing any MixDB query in a template, always verify the table schema:**

```
GetMixDbBySystemName(databaseSystemName: "<site_name>_products", includeColumns: true)
```

This returns exact column `systemName` values (case-sensitive), data types, and required flags. Wrong casing causes silent runtime errors. Never assume column names — confirm them first.

---

## Canonical pattern — inject `IMixDbDataService`

```cshtml
@using Mix.DataSource.Models
@inject Mix.DataSource.Interfaces.IMixDbDataService db
```

That is the **only** inject needed. No factory, no `DatabaseService`, no `SearchMixDbRequestModel`.

---

## List query — `GetRowsAsync`

```cshtml
@using Mix.DataSource.Models
@inject Mix.DataSource.Interfaces.IMixDbDataService db

@{
    // No filter — all rows
    var all = await db.GetRowsAsync("<site_name>_products");

    // With filter
    var active = await db.GetRowsAsync("<site_name>_products",
        MixDbFilter.Where("is_active", true)
                   .And("price", 0, ">"));
}

@foreach (var p in active) {
    <div>@(p.Get<string>("name"))</div>
    <div>$@(p.Get<double>("price", 0.0).ToString("N2"))</div>
    @if (p.Get<bool>("is_featured")) { <span>Featured</span> }
}
```

## Single-row query — `GetRowAsync`

```cshtml
@{
    var row = await db.GetRowAsync("<site_name>_products", id: 1);
}
@if (!row.IsEmpty) {
    <h2>@(row.Get<string>("name"))</h2>
}
```

Returns `MixDbRow.Empty` (not null) when not found — check `row.IsEmpty`.

---

## Data-detail template contract

A `folderType="Data"` template attached to a table (via `templateId`) renders the **record-detail page** at `/db/{tableName}/{id:int}` (integer `id`, served by `FrontendController.DataDetail`). This render path is different from the list/embed queries above — **do not** `@inject IMixDbDataService` and re-query for the primary row, and **do not** declare a `Layout`:

🚨 **The controller already loaded the row and hands it in as the template's `@model`, and assigns the master layout for you.** The template is rendered as a **main view** (not a partial), so its `@section Seo` reaches the master.

```cshtml
@model Mix.DataSource.Models.MixDbRow
@{
    // ✅ Read the row straight from the model — the controller already loaded it.
    //    NO Layout directive (the controller assigns the master via ViewData["MixLayout"]).
    //    NO @inject + re-query for THIS row. (Inject only to load *related* rows.)
    var name    = Model.Get<string>("name") ?? "Untitled";
    var tagline = Model.Get<string>("tagline") ?? "";
    ViewData["Title"] = name;          // page <title> via the master
}
@section Seo {                         // ✅ works — this is a MAIN view, not a partial
    <title>@name</title>
    <meta name="description" content="@tagline" />
    <meta property="og:title" content="@name" />
}
<article>
    <h1>@name</h1>
    <p>@tagline</p>
</article>
```

**Auto-detect the SEO fields at generation time:** inspect the table schema (`GetMixDbBySystemName(includeColumns: true)`) and map the row's columns into `@section Seo` — title from `seoTitle` → `title` → `name`/`heading`; description from `seoDescription` → `description` → `excerpt`/`tagline`; image from `seoImage` → `image` → `thumbnail`/`cover`. Only reference columns that actually exist.

**Contract checklist for a Data-detail template:**
- `@model Mix.DataSource.Models.MixDbRow` — never `@model dynamic`, never a page/post ViewModel.
- **No `Layout`** directive — the controller assigns it; declaring one re-resolves relative to the `Data/` folder and 404s.
- **No re-query** of the primary row — read `Model.Get<…>`. `@inject IMixDbDataService db` only for *related* rows.
- `@section Seo { … }` with the auto-detected fields, plus `ViewData["Title"]` for the master `<title>`.
- File name in **Title Case** (e.g. `FeatureDetail.cshtml`, not `feature-detail.cshtml`).
- The master it renders under must be model-agnostic (reads `ViewData["Title"]`, never `Model.*`) — see [razor-rules.md §master rules](razor-rules.md).

### `MixDbRow` is a struct — no `?.`, and no `!= null` on the value itself

`MixDbRow` is a value type, so `?.` on it is **CS0023** and `row != null` on a non-nullable `MixDbRow` is **CS0019**. Both `GetRowAsync(...)` and `FirstOrDefault()` on a `List<MixDbRow>` return a **non-null** `MixDbRow` (the empty `MixDbRow.Empty` / `default` when nothing matched), never `null`. Test with **`.IsEmpty`**, not `!= null`.

```cshtml
❌  var name = category?.Get<string>("name");   // CS0023: '?.' cannot be applied to MixDbRow
❌  if (category != null) { … }                 // CS0019 when category is MixDbRow (not MixDbRow?)

✅  var row = (await db.GetRowsAsync("...")).FirstOrDefault();   // MixDbRow (non-null)
✅  if (!row.IsEmpty) { var name = row.Get<string>("name"); }
```

`!= null` is valid ONLY when the variable is explicitly declared `MixDbRow?`. For every ordinary `MixDbRow`, use `.IsEmpty` instead of `?.`.

---

## `MixDbRow` accessor reference

| Method | Returns | Notes |
|---|---|---|
| `row.Get<string>("key")` | `string?` | null if missing |
| `row.Get<double>("key", 0.0)` | `double` | fallback for value types |
| `row.Get<bool>("key")` | `bool` | **Non-nullable** — do NOT use `?? false`; `??` on `bool` is CS0019 |
| `row.Get<int>("key", -1)` | `int` | fallback returned on missing/error |
| `row.TryGet<T>("key", out var v)` | `bool` | false when key absent — correct for value types |
| `row.Contains("key")` | `bool` | existence check |
| `row.IsEmpty` | `bool` | true when `GetRowAsync` found nothing |

Handles: `Nullable<T>`, enums from string or int, JToken/nested JSON, all `IConvertible` types.

### 🚨 These access patterns do NOT exist on `MixDbRow` — they will NOT compile

`MixDbRow` is a `readonly record struct` whose ONLY members are the methods above (plus `.Data`). It has **no indexer, no `ContainsKey`, and no dynamic/per-field properties.** The model keeps guessing these — every one fails:

| ❌ Wrong (guessed) | Error | ✅ Correct |
|---|---|---|
| `row["name"]` | **CS0021** — `MixDbRow` has no indexer | `@(row.Get<string>("name"))` |
| `row.ContainsKey("name")` | **CS1061** — it's `Contains`, not `ContainsKey` | `@if (row.Contains("name"))` |
| `row.name` / `row.Name` | **CS1061** — not `dynamic`; no per-field property | `@(row.Get<string>("name"))` |
| `row.Data["name"]` | compiles, but skips type conversion + null-safety | `@(row.Get<string>("name"))` |

Read **every** field with `.Get<T>("field")` (or `.Get<T>("field", fallback)`), test existence with `.Contains("field")`, and **always wrap a value `.Get<T>()` in `@(...)`** when emitting it — a bare `@row.Get<string>("x")` mis-parses `<string>` as an HTML tag. `.Data` is the raw `IReadOnlyDictionary<string, object?>` escape hatch — prefer `.Get`/`.Contains`/`.TryGet`.

---

## `MixDbFilter` operator reference

| Operator | Meaning |
|---|---|
| `=` (default) | Exact match |
| `!=` | Not equal |
| `>` `>=` `<` `<=` | Numeric comparison |
| `like` | SQL LIKE (use `%` wildcards in value) |
| `notlike` | SQL NOT LIKE |

```csharp
MixDbFilter.Where("status", "active")
           .And("price", 100, ">=")
           .And("name", "%pro%", "like")
```

---

## MixDB Naming Conventions

### Display names — ALWAYS use a brand prefix

```
✅  "BrandName Products"
✅  "CoffeeShop Loyalty Points"
✅  "[RestaurantName] Menu Items"

❌  "Products"          — missing brand prefix
❌  "Menu Items"        — missing brand prefix
```

Format: `BrandName [TableDescription]`

### System names — auto-generated with `<site_name>_` prefix

| Display name | System name |
|---|---|
| `Brand_Name Products` | `<site_name>_products` |
| `CoffeeShop Orders` | `<site_name>_orders` |

- Use **system names** in all queries, templates, and code
- After creating a table, call `GetMixDbBySystemName(includeColumns: true)` to get the actual system name and numeric `id`

### Relationship creation — takes numeric table IDs

`create_relationship` takes the **numeric table IDs** (`parentId`/`childId`), not display or system names — there is no `CreateMixDbRelationshipFromPrompt` tool. Look up each id with `GetMixDbBySystemName` first. `propertyName`, `sourceColumnName`, and `destinationColumnName` are NOT NULL in the DB — always set them.

```
create_relationship(
    parentId: 12,                          // parent/source table id
    childId: 8,                            // child/destination table id
    displayName: "Product Category",
    propertyName: "categories",            // required (NOT NULL)
    sourceColumnName: "id",                // required (NOT NULL)
    destinationColumnName: "category_id",  // required (NOT NULL)
    type: "OneToMany"                      // OneToMany | ManyToMany (the only two values in MixDbTableRelationshipType)
)
```

---

## MixDb Table Creation Workflow

`CreateMixDbTable` and `CreateMixDbTableFromPrompt` both apply the migration automatically. There is **no separate MigrateTable tool**.

```
AI-driven:
  CreateMixDbTableFromPrompt(displayName: "BrandName Products",
      schemaDescription: "name (string, required), price (double), image_url (string)")
  → Creates table + columns + migration in one call

Explicit:
  1. CreateMixDbTable(displayName, systemName, columnsJson)
  2. CreateColumn(tableId, ...) [for additional columns]
  3. CreateRelationship(parentId, childId, displayName, type) [optional]

After creation:
  GetMixDbBySystemName(databaseSystemName: "<site_name>_products", includeColumns: true)
  → Confirm actual column system names before writing templates
```

---

## Category / enum mapping pattern — integer `category_id` → display string

When a table stores categories as integers (`category_id INT`) rather than strings, define a server-side dictionary at the top of the Razor code block and reference it throughout the template. This avoids repeating switch/if chains and keeps the mapping in one place.

```cshtml
@using Mix.DataSource.Models
@inject Mix.DataSource.Interfaces.IMixDbDataService db
@{
    var products = await db.GetRowsAsync("site_products",
        MixDbFilter.Where("is_active", true));

    // Map integer category_id → (CSS slug, display label)
    var categoryMap = new Dictionary<int, (string Slug, string Label)>
    {
        { 1, ("cake",  "Artisanal Cakes") },
        { 2, ("tea",   "Premium Tea Blends") },
        { 3, ("drink", "Specialty Drinks") }
    };

    // Compute which categories are actually used (for dynamic tab rendering)
    var usedCategoryIds = products
        .Select(p => p.Get<int>("category_id", 0))
        .Where(id => categoryMap.ContainsKey(id))
        .Distinct()
        .OrderBy(id => id)
        .ToList();
}

<!-- Tabs rendered from actual data — no hardcoded tab names -->
<div class="menu-tabs">
    <button class="tab active" onclick="filterCat('all',this)">All</button>
    @foreach (var catId in usedCategoryIds)
    {
        var cat = categoryMap[catId];
        <button class="tab" onclick="filterCat('@cat.Slug',this)">@cat.Label</button>
    }
</div>

<!-- Cards rendered from actual data -->
@foreach (var p in products)
{
    var catId   = p.Get<int>("category_id", 0);
    var catSlug = categoryMap.ContainsKey(catId) ? categoryMap[catId].Slug : "other";
    var catLabel = categoryMap.ContainsKey(catId) ? categoryMap[catId].Label : "";

    <div class="menu-item" data-cat="@catSlug">
        <span class="cat-label">@catLabel</span>
        <h3>@(p.Get<string>("name"))</h3>
    </div>
}
```

**Key points:**
- Query the table first, then derive which tabs to show from actual rows — tab list stays in sync with the data automatically.
- Use `categoryMap.ContainsKey(id)` guard for robustness against unexpected `category_id` values.
- Keep the dictionary near the top of `@{ }` so it's easy to update when categories change.

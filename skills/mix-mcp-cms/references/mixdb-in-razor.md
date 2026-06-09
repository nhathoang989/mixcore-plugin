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

### `MixDbRow` is a struct — no `?.` null-conditional access

```cshtml
❌  var name = category?.Get<string>("name");   // CS0023: '?' cannot be applied to MixDbRow
❌  var id   = category?.Get<int>("id", 0) ?? 0;

✅  var hasCategory = category != null && !category.IsEmpty;
✅  var name = hasCategory ? category.Get<string>("name") : "";
```

Use `IsEmpty` (and `!= null` when the local came from `FirstOrDefault()` on a `List<MixDbRow>`) instead of `?.`.

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
    type: "OneToMany"                      // OneToMany | ManyToMany | ManyToOne | OneToOne
)
```

---

## MixDb Table Creation Workflow

`CreateMixDbTable` and `CreateMixDbTableFromPrompt` both apply the migration automatically. There is **no separate MigrateTable tool**.

```
AI-driven:
  CreateMixDbTableFromPrompt(displayName: "BrandName Products",
      schemaDescription: "name (string, required), price (decimal), image_url (string)")
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

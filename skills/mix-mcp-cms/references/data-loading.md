# Loading Dynamic Data — Which Service to Use

There are **two separate data paths** depending on context. Choosing the wrong one fails silently.

For Razor-specific patterns see [mixdb-in-razor.md](mixdb-in-razor.md). For live MCP tool signatures use `ToolSearch` with `select:mcp__mixcore__<tool_name>` to load schemas directly from the server.

---

## Decision tree

```
Are you writing a Razor template?
  YES → @inject IMixDbDataService db → db.GetRowsAsync(table, MixDbFilter.Where(...))
        Access values via row.Get<T>("field")

Are you calling an MCP tool?
  Is the table in an external DataSource (separate database connection)?
    YES → QueryRows(dataSourceName, tableName, ...)
    NO  → QueryTable(tableName, filterJson)
```

> 🔹 **Reading MixDB rows?** `MixDbRow` has **no indexer and no `ContainsKey`** — read every field with `.Get<T>("field")` (always wrapped in `@(...)`), test existence with `.Contains("field")`, never `row["field"]` (CS0021) / `row.ContainsKey(...)` (CS1061) / `row.field`. Full rules: **mixcore:mix-mcp-cms → references/mixdb-in-razor.md "MixDbRow accessor reference".**

---

## Path A — MCP: `QueryTable` (internal MixDb tables)

```
QueryTable(
    tableName:   "<site_name>_products",           // system name, no dataSourceName needed
    filterJson:  "[{\"fieldName\":\"is_active\",\"value\":true,\"operator\":\"=\"}]"
)
```
Returns: `IReadOnlyList<Dictionary<string, object?>>` — flat list, no pagination metadata.

---

## Path B — MCP: `QueryRows` (external DataSource tables)

```
QueryRows(
    dataSourceName: "my-external-db",              // REQUIRED — name of the DataSource connection
    tableName:      "products",
    pageIndex:      0,
    pageSize:       20,
    sortBy:         "created_at",
    direction:      "desc",                        // "asc" | "desc"
    filtersJson:    "[{\"fieldName\":\"status\",\"value\":\"active\",\"operator\":\"=\"}]"
)
```
Returns: paginated `JObject` with items + total. **`dataSourceName` is mandatory** — `QueryRows` does not fall back to internal tables.

---

## Path C — MCP: `CreateRow` / `UpdateRow` / `DeleteRow` (both internal and external)

`dataSourceName` is **optional** for write operations:
- Pass `null` → resolves via the table's own database context (internal MixDb)
- Pass a name → uses that external DataSource connection

```
CreateRow(dataSourceName: null,  tableName: "<site_name>_contacts", dataJson: "{...}")  // internal
CreateRow(dataSourceName: "crm", tableName: "leads",                dataJson: "{...}")  // external
```

**RAG auto-indexing**: Every `CreateRow` and `UpdateRow` automatically pushes the row to the AI knowledge base via the message queue. No separate step needed.

---

## Path D — Razor template: `IMixDbDataService`

Used only in `.cshtml` templates. Always internal MixDb; does not connect to external DataSources.

Razor path — see [mixdb-in-razor.md](mixdb-in-razor.md) for the full `GetRowsAsync`/`GetRowAsync` recipe + `MixDbRow` accessor reference.

---

## Path F — Client-side JavaScript: Anonymous form submit (`PublicMixDbDataController`)

Use this endpoint for **public HTML form submissions** (contact forms, newsletter signups, survey responses). No authentication required — anyone can POST.

**Source:** `src/modules/cms/mix.datasource/Controllers/PublicMixDbDataController.cs`  
**Route:** `POST /api/v1/rest/mixdb/data/{tableName}`  
**Auth:** `[AllowAnonymous]` — no JWT or API key needed  
**Body:** flat JSON object — one key per column (`column_system_name: value`)  
**Returns:** `int` — the new row's `id`

Auto-sets `created_by` from the authenticated user's JWT (`MixClaims.UserName`), or `"public"` for anonymous requests.  
Works with both internal MixDb tables and tables linked to an external DataSource — resolves the connection string automatically.

```javascript
// Submit a contact form anonymously
fetch('/api/v1/rest/mixdb/data/my_site_contacts', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
        full_name: 'Jane Smith',
        email: 'jane@example.com',
        message: 'Hello!'
    })
}).then(r => r.json()).then(id => console.log('new row id:', id));
```

> **When to use Path F vs. Path E:**  
> - Path F → anonymous form submissions; no API key; write-only  
> - Path E → authenticated reads, updates, deletes, paginated queries

---

## Path E — Client-side JavaScript: `DataSourceTableDataController` REST API

The **only supported REST endpoint** for reading MixDB row data from browser JavaScript.

**Source:** `src/modules/cms/mix.datasource/Controllers/DataSourceTableDataController.cs`  
**Auth:** Table-permission-based via `[DataSourceTableAuthorize]`:
- Table has **empty** `ReadPermissions` → **anonymous access allowed** (no header needed)
- Table has **populated** `ReadPermissions` → `X-Api-Key` or Bearer JWT with a matching role required

For public pages, prefer server-side Razor (Path D) — it avoids CORS and exposes no API key.

**Client-side role guard (admin/portal pages).** To gate a page on a role (e.g. SuperAdmin), decode the JWT in `localStorage['mix_access_token']` and read the role claim — no server call needed:
- Role claim key: `http://schemas.microsoft.com/ws/2008/06/identity/claims/role` (Microsoft 2008 URI, **not** the xmlsoap 2005 one); value is an **array** of role names.
- SuperAdmin role string is exactly `"SuperAdmin"`; other seeded roles include `Owner`, `Guest`. Check `exp` for expiry.
- Login: `POST /api/v1/rest/auth/login` → `Result.AccessToken`; renew: `POST /api/v1/rest/auth/renew-token`.
- This guards the **UI only** — for server enforcement, populate the table's permission lists with the role. Full pattern: `system-prompts/instructions/workflows/admin-portal.md`.

---

### Loading a filtered list — step by step

**Endpoint:**
```
POST /api/v1/rest/data-source/{dataSourceName}/table/{tableName}/filter
Content-Type: application/json
X-Api-Key: {key}          ← omit only when ReadPermissions is empty
```

**Request body (`SearchDataSourceTableRequestDto`):**

| Field | Type | Default | Notes |
|---|---|---|---|
| `pageIndex` | int | `0` | Zero-based page number |
| `pageSize` | int | `20` | Rows per page; use `1000` to fetch all |
| `sortBy` | string? | `"id"` | Column system name to sort by |
| `direction` | string | `"asc"` | `"asc"` or `"desc"` |
| `queries` | array? | `[]` | Filter conditions (see below); all conditions are ANDed together |

**Filter condition (`TableDataQueryField`):**

| Field | Type | Default | Notes |
|---|---|---|---|
| `fieldName` | string | `""` | Exact column system name (case-sensitive) |
| `value` | any | `null` | Value to compare against |
| `operator` | string | `"="` | See supported operators below |

**Supported `operator` values:**

| Operator | Meaning |
|---|---|
| `"="` | Equals (default) |
| `"!="` | Not equals |
| `">"` | Greater than |
| `">="` | Greater than or equal |
| `"<"` | Less than |
| `"<="` | Less than or equal |
| `"LIKE"` | SQL LIKE — use `%` wildcards in `value` (e.g. `"%pro%"`) |

Any unknown operator falls back to `"="`.

**Example request body:**
```json
{
  "pageIndex": 0,
  "pageSize": 20,
  "sortBy": "created_at",
  "direction": "desc",
  "queries": [
    { "fieldName": "is_active", "value": true,    "operator": "=" },
    { "fieldName": "price",     "value": 100,     "operator": ">=" },
    { "fieldName": "name",      "value": "%pro%", "operator": "LIKE" }
  ]
}
```

**Response:**
```json
{
  "items": [ { "id": 1, "name": "Product A", "price": 149.99, ... }, ... ],
  "total": 42,
  "pageIndex": 0,
  "pageSize": 20
}
```

---

### JavaScript fetch pattern

```javascript
// Generic helper — returns a Promise resolving to { items, total, pageIndex, pageSize }
function filterMixDb(dataSourceName, tableName, options) {
    var opts = options || {};
    var body = {
        pageIndex:  opts.pageIndex  || 0,
        pageSize:   opts.pageSize   || 20,
        sortBy:     opts.sortBy     || null,
        direction:  opts.direction  || 'asc',
        queries:    opts.queries    || []
    };
    var headers = { 'Content-Type': 'application/json' };
    if (opts.apiKey) { headers['X-Api-Key'] = opts.apiKey; }

    return fetch(
        '/api/v1/rest/data-source/' + dataSourceName + '/table/' + tableName + '/filter',
        { method: 'POST', headers: headers, body: JSON.stringify(body) }
    ).then(function(r) { return r.json(); });
}

// ── Examples ──────────────────────────────────────────────────────────────

// 1. Fetch all rows (no filter, public table)
filterMixDb('my_db', 'products', { pageSize: 1000 }).then(function(data) {
    var items = data.items || [];
    console.log('total:', data.total);
});

// 2. Filtered list with sort (private table needs apiKey)
filterMixDb('my_db', 'products', {
    apiKey:    'YOUR_API_KEY',
    pageIndex: 0,
    pageSize:  20,
    sortBy:    'price',
    direction: 'asc',
    queries: [
        { fieldName: 'is_active', value: true,    operator: '='    },
        { fieldName: 'price',     value: 50,      operator: '>='   },
        { fieldName: 'name',      value: '%shirt%', operator: 'LIKE' }
    ]
}).then(function(data) {
    data.items.forEach(function(item) {
        console.log(item.name, item.price);
    });
});

// 3. Paginated walk (page 2 of results)
filterMixDb('my_db', 'orders', {
    apiKey:    'YOUR_API_KEY',
    pageIndex: 1,
    pageSize:  10,
    sortBy:    'created_at',
    direction: 'desc',
    queries: [{ fieldName: 'status', value: 'pending', operator: '=' }]
}).then(function(data) {
    console.log('page 2 of', Math.ceil(data.total / 10));
});
```

---

### Single row

```
GET /api/v1/rest/data-source/{dataSourceName}/table/{tableName}/{id}
X-Api-Key: {key}
→ 200 JObject of the row | 404 if not found
```

### Create / Update / Delete (authenticated)

```
POST   /api/v1/rest/data-source/{dataSourceName}/table/{tableName}         body: JObject
PUT    /api/v1/rest/data-source/{dataSourceName}/table/{tableName}/{id}    body: JObject
DELETE /api/v1/rest/data-source/{dataSourceName}/table/{tableName}/{id}
```

---

### How to get `dataSourceName`

For **internal MixDB tables** (the built-in tenant DB — the usual case), `dataSourceName` is simply **`master`**. No lookup needed:

```
POST /api/v1/rest/data-source/master/table/profile_project/filter
```

For **external DataSource** tables, `dataSourceName` is the `systemName` of the `MixDbDatabase` record that owns the table. Look it up via the DataSource API (requires Owner role):

```
GET /api/v1/rest/data-source
Authorization: Bearer {jwt}

→ Response: {
    "items": [
      {
        "id": 1,
        "systemName": "my_external_db",   ← this is the dataSourceName
        "tables": [
          { "systemName": "products", ... },
          { "systemName": "orders",   ... }
        ]
      },
      ...
    ]
  }
```

Or search by keyword to narrow results:

```
GET /api/v1/rest/data-source?keyword=my_db
Authorization: Bearer {jwt}
```

The `systemName` of the matching item is the value to use as `{dataSourceName}` in every filter/CRUD call.
---

## JSON parameter formats (shared across MCP paths)

- **`filterJson`** / **`filtersJson`**: Both use the **same array format** — `[{"fieldName":"status","value":"Active","operator":"="}]`
  - `fieldName`: exact column system name (case-sensitive)
  - `value`: the value to compare against
  - `operator`: `"="`, `"!="`, `">"`, `">="`, `"<"`, `"<="`, `"like"`, `"notlike"`
- **`dataJson`**: `{"name":"Widget","price":9.99}`
- **`moduleOrderJson`**: `[1, 3, 2]` (array of module IDs in order)

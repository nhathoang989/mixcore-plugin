# Form Templates — `frm-mixdb-ajax`

Required attributes, JavaScript handler, and hidden-field patterns for forms that write to MixDB. The system has two parts:

1. **The form** in a Page/Form template
2. **The JavaScript handler** in the Master layout (runs once, handles all forms on the page)

For Razor authoring rules (escaping, partials, sections), see [razor-rules.md](razor-rules.md).

> 🚨 **Never build a server-side `<form method="post">` that handles the POST in Razor**
> (e.g. `@if (Context.Request.Method == "POST") { db.CreateRowAsync(...) }`). Mixcore SSR page
> routes are **GET-only** — a `POST` to any page (`/contact`, `/faq`, …) returns **HTTP 405** and
> the Razor block never runs, so no row is saved and the user sees no error. Editing such a
> template can never fix it; the only working path is the `frm-mixdb-ajax` + public-endpoint
> pattern below.

> 🚨 **Put the form in a Page/Form *template* — never bake `<form>` markup into a page's `Content` (or `Excerpt`) data field.** The `Content` field is semantic **prose**, output via `@Html.Raw(Model.Content)`; it is **not compiled as Razor**, so a form placed there can't use partials, mixes interactive structure into editor-owned copy (a content edit can silently break it), and can't be cleanly isolated per page. Author the form in a **Form template** (`folderType: Forms`, `@model dynamic`) and embed it with `@await Html.PartialAsync("../Forms/<name>.cshtml")` from the page template (or put the markup directly in the page template). Keep `Content` to headings/intro copy only. *(This is also why a page that needs a form — e.g. Contact — should get its **own** page template rather than reusing a shared inner-page template whose other pages have no form.)*

---

## Form markup (Page or Form template)

```html
<form class="frm-mixdb-ajax"
      data-mixdb-table="<site_name>_contacts"
      data-redirect="/contact?sent=1">
  <input name="name" required />
  <input name="email" type="email" required />
  <textarea name="message" required></textarea>
  <button type="submit">Send</button>
</form>
```

| Attribute | Required | Description |
|---|---|---|
| `class="frm-mixdb-ajax"` | ✅ | Marks the form for AJAX submission |
| `data-mixdb-table` | ✅ | MixDB table system name (e.g. `mysite_contacts`) |
| `data-redirect` | Optional | URL to redirect to on success |
| `data-quiet="1"` | Optional | Suppress the success alert (useful for newsletter inline forms) |

> The public submit endpoint resolves the owning DataSource from the table itself, so the form needs **only** `data-mixdb-table` — no `data-mixdb-datasource` is required.

**Input names must exactly match the column `systemName` values in the MixDB table.** Call `GetMixDbBySystemName(includeColumns: true)` to confirm them before writing the form.

---

## API endpoint called by the handler

```
POST /api/v1/rest/mixdb/data/{tableName}
Content-Type: application/json

Body: flat JSON — one key per column system_name
  { "name": "Jane", "email": "jane@example.com", "message": "Hello" }
Response: 200 OK with new row id (integer)
```

**Source**: `PublicMixDbDataController.Submit` — `[AllowAnonymous]`, the public form-submission endpoint. It looks up the owning DataSource from the table itself, so the form needs only `data-mixdb-table`. **Do NOT post public forms to `api/v1/rest/data-source/{dataSourceName}/table/{tableName}`** — that controller (`DataSourceTableDataController`) is permission-checked and returns 401/403 for anonymous submitters (and is for authenticated admin CRUD only).

### Server-side handling

- **Only columns defined in the table schema are written.** Extra form fields are silently dropped.
- **Missing required fields** fail at the DB level (NOT NULL violation → 500). Validate client-side before submitting.
- **Auto-set by the server — never include these in the form**:
  - `id` — DB auto-increment (returned in the response)
  - `created_date_time` — set to `DateTime.UtcNow`
  - `created_by` — authenticated user's username, or `"public"` if anonymous

### Authenticated DataSource CRUD endpoints (admin/owner — NOT for public forms)

These require a Bearer JWT / matching role and are for admin tooling, not `frm-mixdb-ajax` submissions:

```
POST /api/v1/rest/data-source/{dataSourceName}/table/{tableName}/filter
  Body: SearchDataSourceTableRequestDto → paginated list

GET  /api/v1/rest/data-source/{dataSourceName}/table/{tableName}/{id}
  → single row

POST   /api/v1/rest/data-source/{dataSourceName}/table/{tableName}           body: JObject → create
PUT    /api/v1/rest/data-source/{dataSourceName}/table/{tableName}/{id}      body: JObject → update
DELETE /api/v1/rest/data-source/{dataSourceName}/table/{tableName}/{id}                   → delete
```

See `data-loading.md` Path E for how to look up `dataSourceName` and for the JavaScript read pattern.

---

## JavaScript handler (belongs in the Master layout `<script>` block)

The handler must live in the Master layout so it runs once on page load and covers all forms rendered by `@RenderBody()`. **Do not put this script inside a Form or Page template** — it will duplicate on multi-form pages.

```javascript
// frm-mixdb-ajax handler — place inside the Master layout <script> block
document.addEventListener('DOMContentLoaded', function () {
    document.querySelectorAll('form.frm-mixdb-ajax').forEach(function (form) {
        form.addEventListener('submit', function (e) {
            e.preventDefault();
            var table      = form.getAttribute('data-mixdb-table');
            var quiet      = form.getAttribute('data-quiet') === '1';
            var redirect   = form.getAttribute('data-redirect');

            // Collect all form fields as a flat JSON object
            var data = {};
            new FormData(form).forEach(function (v, k) { data[k] = v; });

            fetch('/api/v1/rest/mixdb/data/' + table, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(data)
            })
            .then(function (r) {
                if (r.ok) {
                    if (redirect) { window.location.href = redirect; return; }
                    if (!quiet) alert('Submitted successfully!');
                    form.reset();
                } else {
                    return r.json().then(function (j) {
                        alert('Error: ' + (j.message || r.status));
                    });
                }
            })
            .catch(function (err) { alert('Network error: ' + err.message); });
        });
    });
});
```

---

## Injecting hidden computed fields (e.g. cart totals)

For forms that need dynamic values not from user input (order totals, JSON arrays, etc.), populate hidden fields via JavaScript before the handler fires:

```javascript
// Example: populate hidden fields before form submits
var form = document.querySelector('form.frm-mixdb-ajax[data-mixdb-table="mysite_orders"]');
if (form) {
    form.items_json.value = JSON.stringify(cartItems);
    form.total.value      = calculateTotal().toFixed(2);
}
```

These hidden inputs must exist in the form HTML:
```html
<input type="hidden" name="items_json" value="" />
<input type="hidden" name="total" value="0" />
```

---

## Numeric fields — server-side coercion (automatic) + JS coercion (recommended)

### Server-side (automatic since `DataSourceTableDataService.CoerceValue`)

`DataSourceTableDataService.CreateAsync` and `UpdateAsync` now coerce every column value to its declared `MixDataType` before passing it to Npgsql. The rules:

| MixDataType | Incoming JToken | Result |
|---|---|---|
| `Integer` | JSON number or parseable string | `int` |
| `Integer` | empty string / unparseable | `DBNull.Value` (null) |
| `Long` | JSON number or parseable string | `long` |
| `Double` | JSON number or parseable string | `double` |
| `Boolean` | `true`/`false` / `"true"`/`"false"` / `"1"`/`"0"` | `bool` |
| `Boolean` | other | `DBNull.Value` |
| Any | empty string | `DBNull.Value` |

This means error 42804 (`column "x" is of type integer but expression is of type text`) cannot occur from the service layer **as long as the column's `DataType` is set correctly in MixDB**.

### JavaScript coercion (belt-and-suspenders — still recommended)

`FormData` always yields strings. Coercing in JS keeps the JSON payload clean and avoids empty-string-to-null surprises on required columns:

```javascript
new FormData(form).forEach(function (v, k) {
    // Coerce "9.00", "2.99", "0" → JS number; "true"/"false" → JS boolean; keep everything else as-is
    data[k] = /^-?\d+(\.\d+)?$/.test(v) ? parseFloat(v)
            : v === 'true' ? true
            : v === 'false' ? false
            : v;
});
```

**Important:** For `Integer`/`Double` number inputs — if the user leaves the field blank, JS sends an empty string and the server maps it to `NULL`. Make inputs `required` or provide a default value if null is not acceptable for the column.

---

## Critical Don'ts (forms-specific)

- ❌ Never use a typed ViewModel in a Form template — form templates require `@model dynamic`

The other forms-specific rules are stated once in their sections above: both `class="frm-mixdb-ajax"` and `data-mixdb-table` are mandatory (attribute table); keep the JavaScript handler in the Master layout only ("JavaScript handler" section); public forms post to `api/v1/rest/mixdb/data/{tableName}`, never the permission-checked data-source endpoint ("API endpoint called by the handler"); never include the server-auto-set `id` / `created_date_time` / `created_by` ("Server-side handling"); and `required`/default + JS coercion for `Integer`/`Double` number inputs ("Numeric fields").

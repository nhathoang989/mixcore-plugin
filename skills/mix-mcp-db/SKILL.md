---
name: mix-mcp-db
description: Use when working with MixDB dynamic tables — creating and managing table schemas, columns, relationships, and reading or writing row data via MCP tools.
argument-hint: "[create-table|add-columns|query|seed-data|relationships] [description]"
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
  - Edit
  - Write
  - mcp__mixcore__get_tables
  - mcp__mixcore__get_mix_db_by_system_name
  - mcp__mixcore__search_mix_db
  - mcp__mixcore__create_mix_db_table
  - mcp__mixcore__create_mix_db_table_from_prompt
  - mcp__mixcore__update_mix_db_table
  - mcp__mixcore__delete_mix_db_table
  - mcp__mixcore__list_columns
  - mcp__mixcore__get_column_by_id
  - mcp__mixcore__get_columns_by_table
  - mcp__mixcore__create_column
  - mcp__mixcore__update_column
  - mcp__mixcore__delete_column
  - mcp__mixcore__add_column_to_table
  - mcp__mixcore__update_table_column
  - mcp__mixcore__delete_table_column
  - mcp__mixcore__query_table
  - mcp__mixcore__get_table_schema
  - mcp__mixcore__get_table_data
  - mcp__mixcore__smart_query
  - mcp__mixcore__parse_smart_query
  - mcp__mixcore__execute_query
  - mcp__mixcore__query_rows
  - mcp__mixcore__get_row_by_id
  - mcp__mixcore__create_row
  - mcp__mixcore__update_row
  - mcp__mixcore__delete_row
  - mcp__mixcore__create_many
  - mcp__mixcore__update_many
  - mcp__mixcore__list_relationships
  - mcp__mixcore__get_relationship_by_id
  - mcp__mixcore__get_relationships_by_parent_table
  - mcp__mixcore__get_relationships_by_child_table
  - mcp__mixcore__create_relationship
  - mcp__mixcore__update_relationship
  - mcp__mixcore__delete_relationship
  - mcp__mixcore__migrate_mix_db_table
  - mcp__mixcore__reload_wiki
---

You are working with **MixDB** — the dynamic database layer of mixcore-cloud. All schema and row operations use MCP tools directly. No REST API calls needed.

---

## Architecture

```
MixDB Table (MixDbTable)         — schema stored in the main CMS DB
  ├── Columns (MixDbColumn)      — typed fields; id auto-generated, never define it
  ├── Relationships              — OneToMany or ManyToMany between tables
  └── Row data
       ├── Internal tables       — data lives in the CMS DB; query via query_table / smart_query
       └── DataSource tables     — data lives in an external DB; query via query_rows (needs dataSourceName)
```

**Key rule:** Never define an `id` column — it is the auto-generated primary key. Audit fields (`created_date_time`, `created_by`, `last_modified`, `modified_by`) are injected automatically.

---

## Data Types

| Type | Use for |
|---|---|
| `String` | Short text, slugs, names |
| `Text` / `MultilineText` / `Html` / `TuiEditor` | Long text, rich content |
| `Integer` / `Long` / `Double` | Numbers |
| `Boolean` | True/false |
| `DateTime` / `DateTimeLocal` / `Date` / `Time` / `Duration` | Date & time |
| `EmailAddress` / `PhoneNumber` / `Url` / `ImageUrl` | Validated string formats |
| `Upload` / `ArrayMedia` | File / media references |
| `Reference` | FK to another MixDB table |
| `Json` / `Array` / `ArrayRadio` | Structured / multi-value |
| `Tag` / `Color` / `Icon` / `QRCode` / `BarCode` | UI-specific |

> 🚨 **CRITICAL — pick the right type for long content (the `varchar(250)` trap).**
> `String` (and every short-string type: `EmailAddress`, `Url`, `ImageUrl`, slugs, names) migrates to **`varchar(250)`**. Inserting a longer value fails at row-create time with Postgres `22001: value too long for type character varying(250)`. For article bodies, rich HTML, descriptions, long excerpts — anything that can exceed 250 chars — use a **long-text** type: `Text`, `MultilineText`, or `Html` (these map to an unbounded `TEXT` column).
>
> **Verify, don't trust the request.** `create_mix_db_table` / `create_mix_db_table_from_prompt` can **coerce an unrecognized `dataType` to `String`** — a column you asked to be `Html` may land as `String(250)`. After creating a table, call `get_table_schema` (or `get_mix_db_by_system_name`) and confirm the long-text columns are actually `Text`/`Html`/`MultilineText`, not `String`.
>
> **Fixing a too-narrow existing column:** change the type with `update_column(id, dataType: "Text")` (or `"Html"`), then **`migrate_mix_db_table`** — widening an existing physical column requires the DROP+CREATE that `migrate` does. `repair_mix_db_table` only **adds** missing columns; it will **not** widen `varchar(250)`→`TEXT`. Because `migrate` re-creates the table it **drops all rows** — so **finalize long-text column types BEFORE seeding data.**

---

## Workflow: Create a table with known schema

### Step 1 — Check if the table already exists

```
mcp__mixcore__get_mix_db_by_system_name(
  databaseSystemName: "blog_posts"
)
```

If it returns data, skip to Step 3. If not found, proceed to Step 2.

### Step 2 — Create the table

**Option A — Explicit columns (preferred when schema is known):**

```
mcp__mixcore__create_mix_db_table(
  displayName: "Blog Posts",
  systemName: "blog_posts",
  description: "Stores blog post content",
  columnsJson: '[
    {"systemName":"title",        "displayName":"Title",        "dataType":"String",   "isRequired":true},
    {"systemName":"content",      "displayName":"Content",      "dataType":"Html",     "isRequired":false},
    {"systemName":"slug",         "displayName":"Slug",         "dataType":"String",   "isRequired":true},
    {"systemName":"published_at", "displayName":"Published At", "dataType":"DateTime", "isRequired":false}
  ]'
)
```

**Option B — Natural language (when schema is described loosely):**

```
mcp__mixcore__create_mix_db_table_from_prompt(
  schemaDescription: "Create a Blog Posts table with title (required string), html content, url slug (required), and published date",
  displayName: "Blog Posts",
  systemName: "blog_posts"
)
```

### Step 3 — Migration (automatic)

Migration runs **automatically** on table create/save — there is normally no manual step here.
Only call `migrate_mix_db_table` explicitly after schema drift, manual column edits, or recovery:

```
mcp__mixcore__migrate_mix_db_table(systemName: "blog_posts")
```

### Step 4 — Verify the schema

```
mcp__mixcore__get_mix_db_by_system_name(
  databaseSystemName: "blog_posts",
  includeColumns: true,
  includeRelationships: true
)
```

### Step 5 — (Optional) Attach a record-detail template

If the table needs a per-record detail page (e.g. `/blog-posts/{id}`), create a Razor template with `folderType="Data"` and assign it on the table. This is purely optional — tables that are only consumed inside other pages/modules don't need it.

```
# 1. Create the detail template (mixcore:mix-mcp-cms territory; use @model dynamic + @inject IMixDbDataService)
mcp__mixcore__create_template(
  fileName: "BlogPostDetail.cshtml",
  folderType: "Data",
  extension: ".cshtml",
  content: "<article>...@(Model.Get<string>(\"title\"))...</article>"
)

# returns templateId, e.g. 91

# 2. Assign the template (and optional master layout) to the table
mcp__mixcore__update_mix_db_table(
  systemName: "blog_posts",
  templateId: 91,
  layoutId: <masterLayoutId>   # optional
)
```

> 🔹 **Reading MixDB rows?** `MixDbRow` has **no indexer and no `ContainsKey`** — read every field with `.Get<T>("field")` (always wrapped in `@(...)`), test existence with `.Contains("field")`, never `row["field"]` (CS0021) / `row.ContainsKey(...)` (CS1061) / `row.field`. Full rules: **mixcore:mix-mcp-cms → references/mixdb-in-razor.md "MixDbRow accessor reference".**

Both `create_mix_db_table` / `create_mix_db_table_from_prompt` also accept `templateId` and `layoutId`, so you can assign them at create-time if the template already exists. Leave them unset to skip the detail-view wiring entirely.

---

## Column Management

### Add columns to an existing table

**Option A — Single column (exact control):**

```
mcp__mixcore__create_column(
  tableId: 42,
  displayName: "Featured Image",
  systemName: "featured_image",
  dataType: "ImageUrl"
)
```

**Option B — Multiple columns via natural language:**

```
mcp__mixcore__add_column_to_table(
  databaseSystemName: "blog_posts",
  schemaText: "Add a featured_image column for image URLs and a view_count integer column with default 0"
)
```

### Update columns

```
mcp__mixcore__update_table_column(
  databaseSystemName: "blog_posts",
  schemaText: "Change the slug column to be required and rename content to body"
)
```

Or update by ID for precision:

```
mcp__mixcore__update_column(
  id: 17,
  displayName: "Body",
  systemName: "body",
  dataType: "Html"
)
```

### Remove columns

```
mcp__mixcore__delete_table_column(
  databaseSystemName: "blog_posts",
  schemaText: "Remove the legacy_id and draft_notes columns",
  confirmDropColumn: "YES"
)
```

Or by ID:

```
mcp__mixcore__delete_column(id: 17)
```

### Update or remove table-level fields

```
mcp__mixcore__update_mix_db_table(
  systemName: "blog_posts",
  displayName: "Blog Articles",
  columnsToAddJson: '[{"systemName":"author","displayName":"Author","dataType":"String"}]',
  columnsToRemoveJson: '["legacy_field"]'
)
```

---

## Querying Data

### Internal MixDB tables (data in CMS DB)

**Simple query with JSON filter:**

```
mcp__mixcore__query_table(
  tableName: "blog_posts",
  filterJson: '[{"fieldName":"status","value":"Published","operator":"="}]'
)
```

**Natural language query:**

```
mcp__mixcore__smart_query(
  tableName: "blog_posts",
  query: "published posts from last month sorted by date descending",
  pageSize: 10
)
```

**Preview parsed filters before executing:**

```
mcp__mixcore__parse_smart_query(
  tableName: "blog_posts",
  query: "posts with more than 100 views"
)
```

**Raw SQL (read-only SELECT):**

```
mcp__mixcore__execute_query(
  query: "SELECT id, title, slug FROM blog_posts WHERE published_at > '2026-01-01' ORDER BY published_at DESC LIMIT 20"
)
```

> ⚠️ **Column-metadata gotcha:** `mix_db_column` has no `is_required`/`description` physical columns —
> those flags live inside the JSON `configurations` column (`{"isRequired": true, ...}`). A query like
> `SELECT c.is_required FROM mix_db_column c` fails with `no such column`. Select `configurations` and
> parse it, or just use `get_table_schema` / `get_columns_by_table`, which return parsed flags directly.

**Sample rows:**

```
mcp__mixcore__get_table_data(tableName: "blog_posts", limit: 20)
```

**Get single row:**

```
mcp__mixcore__get_row_by_id(
  dataSourceName: "blog-db",
  tableName: "blog_posts",
  id: 1
)
```

### External DataSource tables (data in external DB)

**Filtered + paginated query:**

```
mcp__mixcore__query_rows(
  dataSourceName: "blog-db",
  tableName: "blog_posts",
  filtersJson: '[{"fieldName":"slug","value":"hello-world","operator":"="}]',
  sortBy: "published_at",
  direction: "desc",
  pageIndex: 0,
  pageSize: 10
)
```

Operators: `=` `!=` `>` `<` `>=` `<=` `LIKE`

---

## Row CRUD

`dataSourceName` is **optional**:
- **Omit** for internal MixDB tables (stored in the CMS database)
- **Required** for external DataSource tables (separate connection string)

### Insert a row

**Internal table (no dataSourceName):**
```
mcp__mixcore__create_row(
  tableName: "user_registrations",
  dataJson: '{"username":"alice","email":"alice@example.com","status":"Active","role":"member"}'
)
```

**External DataSource table:**
```
mcp__mixcore__create_row(
  tableName: "blog_posts",
  dataSourceName: "blog-db",
  dataJson: '{"title":"Hello World","slug":"hello-world"}'
)
```

Returns the new row `id`. For many rows in one call, use `create_many` (below) instead of repeating.

### Update a row (partial)

```
mcp__mixcore__update_row(
  tableName: "user_registrations",
  id: 1,
  dataJson: '{"status":"Active"}'
)
```

Only supplied fields are updated.

### Delete a row

```
mcp__mixcore__delete_row(
  tableName: "user_registrations",
  id: 1
)
```

### Bulk insert / update

`create_many` and `update_many` write a whole JSON **array** in one call. Rows process
**independently** — a failure on one row does NOT roll back the others; the response reports
`createdCount`/`updatedCount`, `failedCount`, and per-row results/errors keyed by array `index`.
`dataSourceName` is optional, same rule as the single-row tools.

**Bulk insert** — `rowsJson` is an array of row objects:
```
mcp__mixcore__create_many(
  tableName: "products",
  rowsJson: '[{"name":"Widget","price":9.99},{"name":"Gadget","price":4.50}]'
)
```

**Bulk update** — `updatesJson` is an array of objects, each REQUIRING a positive integer `id`
plus the columns to change (the `id` identifies the row, it is not written as a column):
```
mcp__mixcore__update_many(
  tableName: "products",
  updatesJson: '[{"id":1,"price":9.99},{"id":2,"status":"Active"}]'
)
```

There is no bulk delete — call `delete_row` per row.

---

## Relationships

### Define a relationship between tables

> **⚠️ `propertyName` is required** — the DB column is NOT NULL. Omitting it causes a constraint violation. `sourceColumnName` and `destinationColumnName` should also always be set.

```
mcp__mixcore__create_relationship(
  parentId: 10,
  childId: 15,
  displayName: "Blog Post Tags",
  type: "ManyToMany",
  sourceTableName: "blog_posts",
  destinationTableName: "tags",
  propertyName: "tags",            ← REQUIRED (camelCase nav property name)
  sourceColumnName: "id",          ← parent FK column (usually "id")
  destinationColumnName: "post_id" ← child FK column
)
```

`type`: `OneToMany` | `ManyToMany`

| Field | Required | Notes |
|---|---|---|
| `parentId` | ✅ | Table ID of the parent (one side) |
| `childId` | ✅ | Table ID of the child (many side) |
| `displayName` | ✅ | Human-readable label |
| `propertyName` | ✅ | Navigation property name — NOT NULL in DB. Use camelCase (e.g. `"tags"`, `"configurations"`) |
| `type` | ✅ | `"OneToMany"` or `"ManyToMany"` |
| `sourceTableName` | recommended | Parent table system name |
| `destinationTableName` | recommended | Child table system name |
| `sourceColumnName` | recommended | Usually `"id"` |
| `destinationColumnName` | recommended | FK column on child table |

### Inspect relationships

```
mcp__mixcore__get_relationships_by_parent_table(parentTableId: 10)
mcp__mixcore__get_relationships_by_child_table(childTableId: 15)
mcp__mixcore__list_relationships(parentTableId: 10)
```

### Update / delete a relationship

```
mcp__mixcore__update_relationship(id: 3, displayName: "Post Categories", type: "ManyToMany")
mcp__mixcore__delete_relationship(id: 3)
```

---

## Discovery

```
mcp__mixcore__get_tables()                              # list all tables
mcp__mixcore__search_mix_db(keyword: "blog")           # search by name
mcp__mixcore__get_table_schema(tableName: "blog_posts") # columns for a table
mcp__mixcore__get_columns_by_table(tableId: 42)         # columns by table ID
mcp__mixcore__list_columns(tableId: 42)                 # paginated column list
```

---

## Delete a Table

```
mcp__mixcore__delete_mix_db_table(systemName: "blog_posts")
```

**Irreversible.** Cascades all columns and relationship definitions.

---

## Migrate a Table

Re-runs DDL migration for a table against the underlying database. Migration fires automatically on create/save, so only call this explicitly after schema drift, manual column edits, or recovery.

```
# By system name
mcp__mixcore__migrate_mix_db_table(systemName: "blog_posts")

# By table ID
mcp__mixcore__migrate_mix_db_table(tableId: 42)
```

---

## Wiki — Per-table fact sheets

After every MCP call that creates, updates, migrates a table, **or inserts/updates/deletes rows**, write (or overwrite) a fact sheet at:

```
src/apps/MixCore.Cloud.Web/wwwroot/mixcontent/documents/wiki/<tenantId>/<site-name>/database/<system_name>.md
```

`<tenantId>` is **MANDATORY** — the RAG index is tenant-scoped (`SiteWikiService`/`RAGSearchTool` resolve the base as `documents/wiki/{CurrentTenantId}/`). Use the resolved tenant id — **`1` for a default single-tenant install**. Files written without the tenant segment are NOT found by tenant-scoped `search`/`read_document`. `<site-name>` is the project/site folder name (e.g. `rose-whisk`). If no folder exists yet, create it.

Use `generate_document` (load **`mixcore:mix-mcp-rag`**) with `folder: "<site-name>/database"` and `title: "<system_name>"` — it writes the file **and** indexes it atomically (no `reload_wiki` needed). Body template:

```markdown
# <DisplayName> (`<system_name>`)

**Table ID:** <id>  
**MixDb Database ID:** <mixDbDatabaseId>  
**Type:** <type>  
**Last operation:** <create|update|migrate> — <YYYY-MM-DD>

## Columns

| systemName | displayName | dataType | required |
|---|---|---|---|
| field_name | Field Name | String | true |

## Relationships

| type | source | destination | propertyName |
|---|---|---|---|
| OneToMany | blog_posts | comments | comments |

## Notes

<!-- Any non-obvious constraints, migration history, or usage context -->
```

**Rules:**
- One file per table, overwritten on each operation (not appended).
- Only include columns and relationships returned by the last successful MCP response.
- Omit sections with no data (e.g. skip the Relationships table if none exist).
- After `delete_mix_db_table`, remove the corresponding wiki doc with `delete_document` (mixcore:mix-mcp-rag) — it de-indexes automatically.
- `generate_document` / `delete_document` update the in-memory `SiteWikiService` index on write — **no manual `reload_wiki` step is needed**. Row CRUD via the MCP tools also mirrors into the wiki automatically via the CRUD→wiki RAG pipeline.

---

## Naming Conventions

- Table `systemName`: `snake_case` (e.g., `blog_posts`, `product_categories`)
- Column `systemName`: `snake_case` (e.g., `published_at`, `view_count`)
- DataSource `systemName`: `kebab-case` (e.g., `blog-db`, `shop-db`)
- Never define `id`, `created_date_time`, `created_by`, `last_modified`, `modified_by` — all auto-managed

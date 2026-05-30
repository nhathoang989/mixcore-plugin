---
name: mix-dev-migration
description: Add EF Core migrations for mixcore-cloud after entity model changes — covers all 4 provider contexts (SQLite, PostgreSQL, MySQL, SqlServer), the correct startup project, and how to run migration tests.
argument-hint: "[migration-name] [context]"
allowed-tools:
  - Bash
  - Edit
  - Read
  - Glob
  - Grep
---

You are adding EF Core migrations in **mixcore-cloud**.
All commands run from the repo root: `C:\Tinku\Git\mixcore\sources\mixcore-cloud`.

---

## Critical: Use mix.database as both startup AND project

The solution-level build fails due to pre-existing errors in `mix.ai.ui` and `mix.ai.tests`. The Web host also fails to build for the same reason. **Do not use the full solution or the Web project as the startup project.**

`src/platform/mix.database` has both:
- `IDesignTimeDbContextFactory<T>` implementations for all 4 providers
- `Microsoft.EntityFrameworkCore.Design` package (required by EF tooling)

**Always use:**
```bash
dotnet ef \
  --startup-project src/platform/mix.database \
  --project src/platform/mix.database \
  migrations add <MigrationName> \
  --context <ContextName> \
  --output-dir Migrations/<Path>
```

---

## The 4 Migrations — Run All After Any Entity Change in MixCmsContext

```bash
# SQLite (dev default)
dotnet ef --startup-project src/platform/mix.database \
          --project src/platform/mix.database \
          migrations add <MigrationName> \
          --context SqliteMixCmsContext \
          --output-dir Migrations/Cms/Sqlite

# PostgreSQL (production default)
dotnet ef --startup-project src/platform/mix.database \
          --project src/platform/mix.database \
          migrations add <MigrationName> \
          --context PostgresqlMixCmsContext \
          --output-dir Migrations/Cms/Postgres

# MySQL
dotnet ef --startup-project src/platform/mix.database \
          --project src/platform/mix.database \
          migrations add <MigrationName> \
          --context MySqlMixCmsContext \
          --output-dir Migrations/Cms/MySql

# SQL Server
dotnet ef --startup-project src/platform/mix.database \
          --project src/platform/mix.database \
          migrations add <MigrationName> \
          --context SqlServerMixCmsContext \
          --output-dir Migrations/Cms/SqlServer
```

Run all 4 after every entity change. EF Core 10 treats `PendingModelChangesWarning` as an error — missing provider migrations will break startup on that provider.

---

## Context → Output Directory Map

| Context class | Output dir |
|---|---|
| `SqliteMixCmsContext` | `Migrations/Cms/Sqlite` |
| `PostgresqlMixCmsContext` | `Migrations/Cms/Postgres` |
| `MySqlMixCmsContext` | `Migrations/Cms/MySql` |
| `SqlServerMixCmsContext` | `Migrations/Cms/SqlServer` |

Other context families (Account, AuditLog, QueueLog, Quartz) have their own output dirs under `Migrations/Account/`, `Migrations/AuditLog/`, etc. — same pattern, different context names. See `DesignTimeFactories/MixCmsContextDesignTimeFactories.cs` for all available factories.

---

## Cloud modules that own their own DbContext

🚨 **CRITICAL RULE:** A cloud module (`src/cloud/`) with its **own** `DbContext` that persists to the platform DB must follow the per-provider pattern too — fresh installs default the platform DB to **SQLite**, production runs **PostgreSQL**. A context hardwired to one provider crashes the others (`Couldn't set data source` on SQLite, then `PendingModelChangesWarning`).

Mirror `MixCmsContext` + `DatabaseService.GetDbContext`:

1. Derive the base context from `Mix.Database.Base.BaseDbContext` (its `OnConfiguring` switches on `MixDatabaseProvider`). Override `OnModelCreating` **without** calling `base`. Keep a `DbContextOptions` ctor for InMemory unit tests.
2. Add one thin subclass per provider — `Sqlite<Name>`, `Postgresql<Name>`, `MySql<Name>`, `SqlServer<Name>` — each `: <Name>(connectionString, provider)`.
3. Add a runtime abstract factory (`switch` on provider → `new <Provider><Name>(connStr, provider)`); register as `AddScoped<TBase>(sp => Factory.Create(connStr, provider))`.
4. Add an `IDesignTimeDbContextFactory<T>` per subclass (placeholder connection strings — `migrations add` never connects).
5. Generate one migration set per subclass into `Data/Migrations/<Provider>`, using the **module project** as both `--project` and `--startup-project`:

```bash
dotnet ef migrations add InitX \
  --project src/cloud/<Module>/<Module>.csproj \
  --startup-project src/cloud/<Module>/<Module>.csproj \
  --context Sqlite<Name> \
  --output-dir Data/Migrations/Sqlite
# repeat for Postgresql / MySql / SqlServer contexts → Postgres / MySql / SqlServer dirs
```

6. Verify every context reports clean: `dotnet ef migrations has-pending-model-changes --context <T>` (run with a fresh build, not `--no-build`).
7. Pair inverse navigations explicitly — `HasMany(x => x.Steps).WithOne(s => s.Parent)`; a bare `.WithOne()` invents a shadow FK column.

Reference implementation: `MixCore.Cloud.Flows` (`Data/FlowsDbContext.cs`, `FlowsDbContextProviders.cs`, `FlowsDbContextFactory.cs`, `Data/Migrations/{Sqlite,Postgres,MySql,SqlServer}/`).

---

## Verify before migrating

Always build `mix.database` alone first to confirm the entity change compiles:

```bash
dotnet build src/platform/mix.database/mix.database.csproj
```

Zero errors required before running `dotnet ef`.

---

## Always add EntityConfiguration for new columns (snake_case)

Every new property added to a CMS entity **must** have an explicit `HasColumnName("snake_case")` mapping in its `EntityConfiguration` class under `src/platform/mix.database/Entities/Cms/EntityConfigurations/`. Without it EF generates PascalCase column names that diverge from the DB convention.

```csharp
// e.g. MixDbTableConfiguration.cs
builder.Property(e => e.TemplateId)
   .IsRequired(false)
   .HasColumnName("template_id");

builder.Property(e => e.LayoutId)
   .IsRequired(false)
   .HasColumnName("layout_id");
```

**Workflow:** edit entity → add `HasColumnName` in config → then run `dotnet ef migrations add`. If you run migrations before adding the config, EF generates PascalCase names and you must remove both migrations and re-add after fixing the config.

**`EntityConfiguration` changes also need migrations.** It's not just new properties — any change to the EntityConfiguration class (`HasIndex(...).IsUnique()`, `HasKey`, `HasOne`/`HasMany`, foreign key behavior, `HasDatabaseName`) is a model change. Skipping the migration causes `PendingModelChangesWarning` at startup and breaks all tests for that context.

**Verify the snapshot.** After `dotnet ef migrations add`, grep the generated `*ModelSnapshot.cs` for your change (e.g., the index name). If the snapshot is unchanged, EF generated against stale state — remove and re-add.

---

## Migration naming convention

Use `PascalCase` describing what changed:
- `AddTemplateIdLayoutIdToMixDbTable`
- `AddPriorityToMixContent`
- `RefactorCmsSchema`

Avoid generic names like `Update1` — the name is permanent and appears in the database's `__EFMigrationsHistory` table.

---

## Running migration tests

```bash
dotnet test src/tests/mix.database.migrations.tests
```

**All 117 tests require real database connections to PostgreSQL, MySQL, SqlServer, and SQLite.** There are no in-memory SQLite tests. `appsettings.example.json` is a leftover — ignore it; **connection strings come from environment variables**, not JSON.

### Test credentials: `.env.tests` (repo root)

`Mix.Tests.Shared.TestDatabaseCredentials` walks up from the test binary directory looking for a `.env.tests` file and injects each `KEY=VALUE` into the process environment (existing env vars win). Without this file, each variable falls back to a hard-coded default (`P@ssw0rd` for all providers — rarely correct).

### Filter by provider

```bash
dotnet test src/tests/mix.database.migrations.tests --filter "Database=PostgreSQL"
dotnet test src/tests/mix.database.migrations.tests --filter "Database=SqlServer"
dotnet test src/tests/mix.database.migrations.tests --filter "Database=MySQL"
dotnet test src/tests/mix.database.migrations.tests --filter "FullyQualifiedName~Sqlite"
```

Tests use `IClassFixture<T>` — the fixture's constructor runs `EnsureDeleted+Migrate`. **If the fixture ctor throws, every test in that class fails as a group**, often with cryptic "Class fixture type … threw in its constructor" wrappers. Look past the wrapper to the inner exception.

### Watch for native services shadowing Docker port mappings

On Windows, native installs of PostgreSQL or MySQL can win port 5432 / 3306 even though Docker reports the port forwarded. The container is healthy but unreachable; the native server gets all the connections. Diagnose with:

```powershell
Get-NetTCPConnection -LocalPort 5432 -State Listen | %{ Get-Process -Id $_.OwningProcess }
```

If `postgres.exe` or `mysqld.exe` is the listener (not `com.docker.backend`), your test credentials must match that native install — not the Docker container's env vars. See the troubleshooting section below.

---

## Troubleshooting common test failures

### `PendingModelChangesWarning: The model for context '…' has pending changes`

The model derived from entities + configurations differs from the latest `*ModelSnapshot.cs`. Fix: run `dotnet ef migrations add <Name>` for the failing context (and the other 3 providers — the warning surfaces per-provider but the cause is shared model code).

Most common triggers in this repo:
- A `HasIndex(...).IsUnique()` added to an `EntityConfiguration` without a migration
- A new entity property without `HasColumnName` + migration
- An entity property removed without a migration that drops the column

### SQL Server: `The certificate chain was issued by an authority that is not trusted`

`Microsoft.Data.SqlClient` 4+ defaults `Encrypt=true; TrustServerCertificate=false`; the Docker SQL Server image uses a self-signed cert. The test connection string in `TestDatabaseCredentials.SqlServerConnectionString` already appends `TrustServerCertificate=true` — if you fork this for other tools (admin app, smoke scripts), add the same suffix.

### PostgreSQL: `password authentication failed for user "postgres"`

If a Docker postgres container is running but the password is rejected, a native Windows install is probably winning port 5432. Confirm with `Get-NetTCPConnection -LocalPort 5432 -State Listen`. The native install has a different password than the container env var. Either point `.env.tests` at the native install's password, or stop the native service so Docker can take the port.

### Orphan `*.cs` migration without `.Designer.cs`

Found a migration file that compiles but never applies? Without `.Designer.cs` the `[Migration("...")]` attribute is missing, so EF never discovers it. It's dead code in the migration assembly. Either re-generate properly with `dotnet ef migrations add` or delete the `.cs` file.

This pattern often shows up when a migration was hand-authored or imported from a partial PR. Detect orphans with:

```bash
ls src/platform/mix.database/Migrations/Cms/*/[0-9]*_*.cs | while read f; do
  [ -f "${f%.cs}.Designer.cs" ] || echo "ORPHAN: $f"
done
```

---

## Rollback a migration

```bash
dotnet ef --startup-project src/platform/mix.database \
          --project src/platform/mix.database \
          migrations remove --context <ContextName>
```

Run once per context to remove the last migration from that provider.

---

## Apply migrations to a running database

Migrations are **applied automatically on app startup** via `MixAutoMigrateHostedService` (`src/platform/mix.lib/Services/MixAutoMigrateHostedService.cs`):

- Registered in `AddMixCoreServices` as a hosted service
- Runs only when `InitStatus == InitStep.Done` (site fully initialized)
- Calls `DatabaseService.UpdateMixCmsContextAsync()` → `MigrateDbContextAsync()` → `DbContext.Database.MigrateAsync()` for each context

**To apply a new migration: restart the app.** No `dotnet ef database update` needed in normal operation.

For emergency manual apply (e.g. the app won't start due to a schema mismatch):
```bash
dotnet ef --startup-project src/platform/mix.database \
          --project src/platform/mix.database \
          database update --context <ContextName>
```
This uses the DesignTimeFactory connection string, not the app's — use only as a fallback.

---

## Key files

| File | Purpose |
|---|---|
| `src/platform/mix.database/DesignTimeFactories/MixCmsContextDesignTimeFactories.cs` | All EF design-time factories — one class per provider per context |
| `src/platform/mix.database/Entities/Cms/` | CMS entity classes — edit these before adding migrations |
| `src/platform/mix.database/Migrations/Cms/` | Generated migrations — one subfolder per provider |
| `src/tests/mix.database.migrations.tests/` | Migration integration tests |

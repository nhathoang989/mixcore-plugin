---
name: mix-dev-dotnet-cli
description: Run dotnet CLI operations for the mixcore-cloud solution — build, test, run, migrations, and package management.
argument-hint: "[build|test|run|migrate|add|watch] [args]"
allowed-tools:
  - Bash
---

You are helping with .NET CLI operations in the **mixcore-cloud** solution (`src/MixCore.Cloud.sln`).
All commands run from the mixcore-cloud repo root.

## Build

```bash
dotnet build src/MixCore.Cloud.sln                    # full solution
dotnet build src/MixCore.Cloud.sln -c Release         # release config
dotnet build src/<path/to/project.csproj>             # single project
dotnet build src/MixCore.Cloud.sln --no-restore       # skip restore (faster after first build)
```

## Run

```bash
dotnet run --project src/apps/MixCore.Cloud.Web       # main web app
dotnet run --project src/host/mixcore.host            # all services via .NET Aspire (AppHost.cs)
docker compose up --build                            # Docker Compose (SQLite by default)
docker compose --profile postgres up --build         # Docker Compose (PostgreSQL)
```

## Test

```bash
dotnet test src/MixCore.Cloud.sln                     # all tests (sequential — required)
dotnet test src/tests/mix.database.migrations.tests   # migration tests only
dotnet test src/tests/mix.installation.tests          # installation tests only

# Filter to a single class
dotnet test src/tests/mix.database.migrations.tests --filter "FullyQualifiedName~AccountContextMigrationTests"

# Filter to a single method
dotnet test src/tests/mix.database.migrations.tests --filter "FullyQualifiedName~AccountContextMigrationTests.EnsureCreated_SQLite_CreatesSchemaWithoutErrors"

# Filter by database provider trait
dotnet test src/tests/mix.installation.tests --filter "Trait=Database|MySQL"
dotnet test src/tests/mix.installation.tests --filter "Trait=Database|SqlServer"
```

> Tests must run sequentially (`[assembly: CollectionBehavior(DisableTestParallelization = true)]` is set globally). Do not add parallelism — `DatabaseService` writes to `wwwroot/mixcontent/appsettings.json`.

## EF Core Migrations

Always run from the **repo root** (not from inside `src/`):

```bash
# Add a migration
dotnet ef --startup-project src/apps/MixCore.Cloud.Web \
          --project src/platform/mix.database \
          migrations add <MigrationName> \
          --context <ContextName> \
          --output-dir Migrations/<Path>

# Apply migrations
dotnet ef --startup-project src/apps/MixCore.Cloud.Web \
          --project src/platform/mix.database \
          database update --context <ContextName>

# List pending migrations
dotnet ef --startup-project src/apps/MixCore.Cloud.Web \
          --project src/platform/mix.database \
          migrations list --context <ContextName>
```

Available contexts (non-exhaustive): `MixCmsContext`, `MixCmsAccountContext`, `AuditLogDbContext`, `QueueLogDbContext`.
Other migrated contexts exist (e.g. Gateway, MixDb, MixQueueDb, Quartz, Settings) — see the subfolders under `src/platform/mix.database/Migrations/` for the full list.
Each has provider variants: `SqliteMixCmsContext`, `PostgresqlMixCmsContext`, `MySqlMixCmsContext`, `SqlServerMixCmsContext` (and the equivalents for the other contexts).

> EF Core 10 treats `PendingModelChangesWarning` as an error. Always add a migration when changing entity models.

## Packages

```bash
dotnet add src/<project.csproj> package <PackageName>
dotnet add src/<project.csproj> package <PackageName> --version <version>
dotnet remove src/<project.csproj> package <PackageName>
dotnet restore src/MixCore.Cloud.sln
dotnet list src/<project.csproj> package --outdated
```

## Watch (hot reload)

```bash
dotnet watch --project src/apps/MixCore.Cloud.Web run
dotnet watch --project src/tests/mix.database.migrations.tests test
```

## Useful flags

| Flag | Effect |
|------|--------|
| `--no-restore` | Skip NuGet restore (saves time when packages are already restored) |
| `--no-build` | Skip build step (e.g. for `dotnet test --no-build`) |
| `-v d` / `-v diag` | Verbose / diagnostic output |
| `--configuration Release` | Use Release configuration |
| `--framework net10.0` | Target a specific TFM |

## Common task patterns

When the user asks to:
- **"build"** → `dotnet build src/MixCore.Cloud.sln`
- **"run"** → `dotnet run --project src/apps/MixCore.Cloud.Web`
- **"run tests" / "test"** → `dotnet test src/MixCore.Cloud.sln`
- **"run a single test"** → ask for the class/method name, then use `--filter "FullyQualifiedName~..."`
- **"add a migration"** → ask for migration name and context, use the `dotnet ef` command above
- **"add a NuGet package"** → ask which `.csproj` and the package name
- **"restore packages"** → `dotnet restore src/MixCore.Cloud.sln`

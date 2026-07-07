---
name: mix-dev-tests
description: Write unit and integration tests for the mixcore-cloud solution — controller unit tests, migration tests, fake services, and installation tests.
argument-hint: "[controller|migration|installation] [ContextOrControllerName]"
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
  - Edit
  - Write
---

You are writing tests for the **mixcore-cloud** solution.
All paths are relative to the mixcore-cloud repo root.

---

## Test projects

| Project | What it tests |
|---------|---------------|
| `src/tests/mix.database.migrations.tests` | EF Core migrations across all 4 DB providers |
| `src/tests/mix.installation.tests` | `InitCmsController` — all installation endpoints |

**Tests always run sequentially.** `[assembly: CollectionBehavior(DisableTestParallelization = true)]` must not be removed.
`DatabaseService` reads/writes `wwwroot/mixcontent/setting-files/databases.json` at construction; parallel runs corrupt that file.

---

## Running tests

```bash
dotnet test src/mixcore.sln                                             # all tests
dotnet test src/tests/mix.database.migrations.tests                    # migration tests
dotnet test src/tests/mix.installation.tests                           # installation tests

# Filter by class
dotnet test src/tests/mix.database.migrations.tests --filter "FullyQualifiedName~AccountContextMigrationTests"

# Filter by database provider trait
dotnet test src/tests/mix.database.migrations.tests --filter "Trait=Database|PostgreSQL"
dotnet test src/tests/mix.database.migrations.tests --filter "Trait=Database|MySQL"
dotnet test src/tests/mix.database.migrations.tests --filter "Trait=Database|SqlServer"
```

**Judge by your own `--filter` run, not the suite total.** Clean `main` has pre-existing failures (and `mix.installation.tests` may not even compile — check the open issues). To prove a failure is pre-existing and not yours: `git stash -u` → run the same filter → `git stash pop`. Run tests in a verify-worktree when the app is live on `:5000` (see `mixcore:mix-dev-dotnet-cli`).

---

## Controller unit tests (no WebApplicationFactory)

```csharp
var controller = new InitCmsController(
    Mock.Of<IInitCmsService>(),
    fakeDatabaseService,
    fakeAppSettings,
    configuration,
    Mock.Of<IThemeImportOrchestrator>());

controller.ControllerContext = new ControllerContext
{
    HttpContext = new DefaultHttpContext()
};
```

The constructor order is `(IInitCmsService, DatabaseService, AppSettingsService, IConfiguration, IThemeImportOrchestrator)` — `dbService` comes before `appSettings`.

Use `new ConfigurationBuilder().AddInMemoryCollection().Build()` — **not** `.Build()` alone (throws `InvalidOperationException` when a service calls `configuration[key] = value`).

---

## Faking settings services

`AppSettingServiceBase<T>.LoadAppSettings()` is `protected virtual` — subclass to bypass file I/O.

### `FakeAppSettingsService`

`AppSettingsService`'s constructor takes only `(IConfiguration)`; pass an in-memory configuration so no file is read. `SaveSettings()` returns **`bool`** (from `AppSettingServiceBase<T>`), not `Task`. Use a primary constructor to capture the desired `InitStep` (the enum is `InitStep`, **not** `MixInitStatus`), then set it in `LoadAppSettings()` (which the base constructor calls). Set `AI` to a non-null value so the base constructor body doesn't attempt a `File.Copy`.

```csharp
internal sealed class FakeAppSettingsService(InitStep initStatus = InitStep.Blank)
    : AppSettingsService(new ConfigurationBuilder().AddInMemoryCollection().Build())
{
    // Captured before the base constructor runs (primary-constructor field initializer).
    private readonly InitStep _initStatus = initStatus;

    protected override void LoadAppSettings()
    {
        AppSettings = new AppSettingsModel
        {
            InitStatus = _initStatus,
            AI         = new AIConfigurations()
        };
        RawSettings = JObject.FromObject(AppSettings);
    }

    public override bool SaveSettings() => true;
}
```

### `FakeDatabaseService`

`DatabaseService`'s primary constructor is **3-arg** — `(IHttpContextAccessor, IConfiguration, TenantDbResolver)` — but it also exposes a 2-arg fallback `(IHttpContextAccessor, IConfiguration)` (the design-time / Quartz path that supplies an empty `TenantDbResolver`). The fake calls the 2-arg overload. Configure **PostgreSQL** so tests reflect a realistic production database scenario. `SaveSettings()` returns **`bool`**.

```csharp
internal sealed class FakeDatabaseService()
    : DatabaseService(Mock.Of<IHttpContextAccessor>(), new ConfigurationBuilder().AddInMemoryCollection().Build())
{
    internal static string DefaultConnectionString => TestCredentials.PostgreSqlConnectionString;

    protected override void LoadAppSettings()
    {
        RawSettings = new JObject
        {
            ["DatabaseProvider"] = "PostgreSQL",
            ["ConnectionStrings"] = new JObject
            {
                [MixConstants.CONST_CMS_CONNECTION]     = DefaultConnectionString,
                [MixConstants.CONST_ACCOUNT_CONNECTION] = DefaultConnectionString,
                [MixConstants.CONST_MIXDB_CONNECTION]   = DefaultConnectionString,
                [MixConstants.CONST_QUARTZ_CONNECTION]  = DefaultConnectionString
            }
        };
        AppSettings = new DatabaseConfigurations
        {
            DatabaseProvider = MixDatabaseProvider.PostgreSQL
        };
    }

    public override bool SaveSettings() => true;
}
```

### `FakeSystemPromptService` — services that load prompt files

Runtime LLM prompts live under the **web host's** `system-prompts/system/` — that path does not exist in the test working directory, so any service calling `ISystemPromptService.LoadPrompt(...)` needs the in-memory fake at `mix.ai.tests/Agents/FakeSystemPromptService.cs`. Seed it with only the filename→template pairs the test exercises; its `BuildFromTemplate` mirrors production semantics ({{Key}} replacement + unmatched-`{{...}}` stripping), so assertions on the rendered prompt stay realistic:

```csharp
var prompts = new FakeSystemPromptService(new Dictionary<string, string>
{
    ["rerank-documents.md"] = "Query: \"{{Query}}\"\nDocuments:\n{{Documents}}"
});
var sut = new VectorLessService(dir, cfg, llm, cache, logger, promptService: prompts);
```

An unseeded filename throws `FileNotFoundException` — useful for asserting a call-site's degraded path (fallback, skip, `Skipped`).

### Unreadable-file scenarios — `File.SetUnixFileMode`

To prove a "never throws on unreadable file" contract, make a real file unreadable rather than mocking IO:

```csharp
if (OperatingSystem.IsWindows()) return;          // UnixFileMode is not supported on Windows
File.SetUnixFileMode(path, UnixFileMode.None);    // exists, but File.ReadAllText throws
try { /* assert no-throw + skipped */ }
finally { File.SetUnixFileMode(path, UnixFileMode.UserRead | UnixFileMode.UserWrite); } // else Dispose cleanup fails
```

---

## Migration tests (integration — requires a real database)

Migration tests use a **fixture + `IClassFixture<T>`** pattern. The fixture runs `EnsureDeleted()` + `Migrate()` once before all tests in the class.

### Fixture + test class pattern

```csharp
// ── Fixture ───────────────────────────────────────────────────────────────────
public sealed class PostgresqlMyContextMigrationFixture : IDisposable
{
    public static string ConnectionString => TestDatabaseCredentials.PostgreSqlConnectionString;
    private readonly DatabaseService _databaseService;

    public PostgresqlMyContextMigrationFixture()
    {
        _databaseService = TestDatabaseServiceFactory.CreateForProvider(ConnectionString, "PostgreSQL");
        using var ctx = CreateContext();
        ctx.Database.EnsureDeleted();
        ctx.Database.Migrate();
    }

    public void Dispose() { }

    public PostgresqlMyContext CreateContext() => new(_databaseService);
}

// ── Tests ─────────────────────────────────────────────────────────────────────
[Trait("Category", "Integration")]
[Trait("Database",  "PostgreSQL")]
public sealed class PostgresqlMyContextMigrationTests(PostgresqlMyContextMigrationFixture fixture)
    : IClassFixture<PostgresqlMyContextMigrationFixture>
{
    private readonly PostgresqlMyContextMigrationFixture _fixture = fixture;

    [Fact]
    public void Migrate_PostgreSQL_Succeeds()
    {
        using var ctx = _fixture.CreateContext();
        Assert.Empty(ctx.Database.GetPendingMigrations());
    }

    [Fact]
    public void Table_SomeEntity_ExistsAfterMigrate_PostgreSQL()
    {
        using var ctx = _fixture.CreateContext();
        Assert.True(ctx.SomeDbSet.Count() >= 0);
    }

    [Fact]
    public void Table_SomeEntity_HasSnakeCaseColumns_PostgreSQL()
    {
        using var ctx = _fixture.CreateContext();
        var entityType = ctx.Model.FindEntityType(typeof(SomeEntity))!;
        var storeId    = StoreObjectIdentifier.Table(entityType.GetTableName()!, entityType.GetSchema());
        var columns    = entityType.GetProperties()
                                   .Select(p => p.GetColumnName(storeId))
                                   .ToList();
        Assert.Contains("id",          columns);
        Assert.Contains("system_name", columns);
    }
}
```

### MySQL workaround — use raw ADO.NET for table existence

`MySql.EntityFrameworkCore 9.x` has a `MissingMethodException` with EF Core 10's updated `IRelationalCommandBuilder`. DbSet LINQ queries throw, so use raw ADO.NET for table existence checks:

```csharp
private void AssertTableExists(string tableName)
{
    using var ctx = _fixture.CreateContext();
    var conn    = ctx.Database.GetDbConnection();
    var wasOpen = conn.State == ConnectionState.Open;
    if (!wasOpen) conn.Open();
    try
    {
        using var cmd = conn.CreateCommand();
        cmd.CommandText = """
            SELECT COUNT(*)
            FROM information_schema.TABLES
            WHERE TABLE_SCHEMA = DATABASE()
              AND TABLE_NAME   = @tableName
            """;
        var param = cmd.CreateParameter();
        param.ParameterName = "@tableName";
        param.Value         = tableName;
        cmd.Parameters.Add(param);
        var count = Convert.ToInt64(cmd.ExecuteScalar());
        Assert.True(count == 1, $"Table '{tableName}' was not found.");
    }
    finally
    {
        if (!wasOpen) conn.Close();
    }
}
```

### Connection strings from environment variables

`TestDatabaseCredentials` (migration tests) and `TestCredentials` (installation tests) read these
environment variables, falling back to `P@ssw0rd` / `localhost` defaults. Both auto-load a `.env`
file found by walking up from the test binary to the repo root (existing shell/CI vars win):

```
MIXCORE_TEST_MYSQL_HOST        (default: localhost)
MIXCORE_TEST_MYSQL_PORT        (default: 3306)
MIXCORE_TEST_MYSQL_DATABASE    (default: mixcore_structure)
MIXCORE_TEST_MYSQL_USER        (default: root)
MIXCORE_TEST_MYSQL_PASSWORD    (default: P@ssw0rd)

MIXCORE_TEST_POSTGRES_HOST     (default: localhost)
MIXCORE_TEST_POSTGRES_DATABASE (default: mixcore_structure)
MIXCORE_TEST_POSTGRES_USER     (default: postgres)
MIXCORE_TEST_POSTGRES_PASSWORD (default: P@ssw0rd)

MIXCORE_TEST_SQLSERVER_HOST     (default: localhost)
MIXCORE_TEST_SQLSERVER_DATABASE (default: mixcore_structure)
MIXCORE_TEST_SQLSERVER_USER     (default: sa)
MIXCORE_TEST_SQLSERVER_PASSWORD (default: P@ssw0rd)
```

To set local credentials, either export these `MIXCORE_TEST_*` variables in your shell, place them
in a `.env` file at the repo root, or copy
`src/tests/mix.database.migrations.tests/appsettings.example.json` → `appsettings.json` and set the
connection string there (required for the integration/migration tests per the repo README).

### Trait values for provider filtering

| Provider   | Trait value   |
|------------|---------------|
| PostgreSQL | `"PostgreSQL"` |
| MySQL      | `"MySQL"` |
| SQL Server | `"SqlServer"` |

---

## EF Core 10 warning — `PendingModelChangesWarning`

EF Core 10 elevates `PendingModelChangesWarning` to an error. `Database.Migrate()` throws `InvalidOperationException` when the model is ahead of the last migration snapshot. Use `Database.EnsureCreated()` in tests that only need schema verification; generate a new migration to fix `Migrate()`.

---

## Common task patterns

When the user asks to:
- **"write tests for a controller"** → create a controller unit test using the fake-services pattern above; no `WebApplicationFactory` needed
- **"write migration tests for a new context"** → create fixtures for all three providers (PostgreSQL, MySQL, SqlServer) with `[Trait("Database", ...)]`
- **"add a fake service"** → subclass `AppSettingServiceBase<T>` or `DatabaseService`, override `LoadAppSettings()` and `SaveSettings()`
- **"run only PostgreSQL tests"** → `dotnet test ... --filter "Trait=Database|PostgreSQL"`

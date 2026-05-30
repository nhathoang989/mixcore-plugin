---
name: tests
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
All paths are relative to the repo root: `C:\Tinku\Git\mixcore\sources\mixcore-cloud`.

---

## Test projects

| Project | What it tests |
|---------|---------------|
| `src/tests/mix.database.migrations.tests` | EF Core migrations across all 4 DB providers |
| `src/tests/mix.installation.tests` | `InitCmsController` — all installation endpoints |

**Tests always run sequentially.** `[assembly: CollectionBehavior(DisableTestParallelization = true)]` must not be removed.
`DatabaseService` reads/writes `wwwroot/mixcontent/databases.json` at construction; parallel runs corrupt that file.

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

---

## Controller unit tests (no WebApplicationFactory)

```csharp
var controller = new InitCmsController(
    Mock.Of<IInitCmsService>(),
    fakeAppSettings,
    fakeDatabaseService,
    configuration);

controller.ControllerContext = new ControllerContext
{
    HttpContext = new DefaultHttpContext()
};
```

Use `new ConfigurationBuilder().AddInMemoryCollection().Build()` — **not** `.Build()` alone (throws `InvalidOperationException` when a service calls `configuration[key] = value`).

---

## Faking settings services

`AppSettingServiceBase<T>.LoadAppSettings()` is `protected virtual` — subclass to bypass file I/O.

### `FakeAppSettingsService`

```csharp
public class FakeAppSettingsService : AppSettingsService
{
    public FakeAppSettingsService(IHttpContextAccessor accessor, IConfiguration config)
        : base(accessor, config) { }

    protected override void LoadAppSettings()
    {
        AppSettings = new AppSettingsModel
        {
            IsInit      = false,
            InitStatus  = MixInitStatus.Blank
        };
    }

    public override Task SaveSettings() => Task.CompletedTask;
}
```

### `FakeDatabaseService`

```csharp
public class FakeDatabaseService : DatabaseService
{
    public FakeDatabaseService(IHttpContextAccessor accessor, IConfiguration config)
        : base(accessor, config) { }

    protected override void LoadAppSettings()
    {
        AppSettings = new DatabaseConfigurations
        {
            DatabaseProvider = MixDatabaseProvider.SQLITE,
            ConnectionStrings = new ConnectionStrings
            {
                MixCmsConnection      = "Data Source=:memory:",
                MixAccountConnection  = "Data Source=:memory:",
                MixAuditLogConnection = "Data Source=:memory:",
                MixQueueLogConnection = "Data Source=:memory:",
                MixDbConnection       = "Data Source=:memory:",
                MixQuartzConnection   = "Data Source=:memory:"
            }
        };
        RawSettings = JObject.FromObject(AppSettings);
    }

    public override Task SaveSettings() => Task.CompletedTask;
}
```

---

## Migration tests (integration — requires a real database)

Migration tests use a **fixture + `IClassFixture<T>`** pattern. The fixture runs `EnsureDeleted()` + `Migrate()` once before all tests in the class.

### Fixture + test class pattern

```csharp
// ── Fixture ───────────────────────────────────────────────────────────────────
public sealed class PostgresqlMyContextMigrationFixture : IDisposable
{
    public static string ConnectionString => TestConnections.PostgreSqlConnectionString;
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

`TestConnections` reads from `.env.tests` at the repo root (falls back to `P@ssw0rd` defaults):

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

Copy `.env.tests.example` → `.env.tests` at the repo root to set local credentials.

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

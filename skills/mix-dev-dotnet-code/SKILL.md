---
name: mix-dev-dotnet-code
description: Implement and review C# 12/.NET 10 code in mixcore-cloud — project conventions, architecture rules, ViewModels (mix.heart), CQRS handlers, EF Core, and safe defaults.
argument-hint: "[api|service|viewmodel|entity|refactor|fix] [Context]"
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
  - Edit
  - Write
---

You are implementing **C# 12 / .NET 10** code for **mixcore-cloud**.
All paths are relative to: `C:\Tinku\Git\mixcore\sources\mixcore-cloud`.

---

## Baseline standards

- Target framework: `net10.0`
- Nullable: enabled
- Implicit usings: enabled
- Use C# 12 primary constructors for new controllers/services
- Prefer `async`/`await`; avoid sync-over-async
- Keep methods `virtual` in controllers/services to support module overrides

---

## Architecture guardrails

- Respect modular monolith boundaries:
  - `src/platform/*` for shared infrastructure
  - `src/modules/*` for business features
  - `src/apps/*` for entry points
- Module discovery is automatic via `IStartupService`; do not add manual module wiring when not required.
- For app startup order, keep:
  1. `builder.AddDbContexts()`
  2. `builder.AddMixAuthorize()`

---

## API and service patterns

- Controllers must use `[ApiController]` and `[Route("api/v1/...")]`.
- For domain errors, use `MixException(MixErrorStatus, message)` (not raw `Exception`).
- Use `SearchRequestDto` + `SearchQuery<TEntity, TPrimaryKey>` for paged/filter endpoints.
- Use `IPortalHubClientService` for SignalR notifications and `IMemoryQueueService<MessageQueueModel>` for queue events.
- Prefer existing base classes (`TenantControllerBase`, `ReadOnlyControllerBase`, `CrudControllerBase`, `CrudService`) over bespoke implementations.

---

## CQRS command handlers — pipeline behaviors only fire for `ICommand<T>`

`AddMixCqrs(assembly)` (mix.heart) wires MediatR plus three pipeline behaviors — `ValidationBehavior` → `CacheInvalidationBehavior` → `UnitOfWorkBehavior`. **All three early-return unless the request implements `ICommand<TResponse>`**, and `UnitOfWorkBehavior` / `ValidationBehavior` additionally require a `Uow` / `Data` property (resolved by reflection).

🚨 **CRITICAL RULE:** If your command is a plain `IRequest<T>` (like `RegisterTenantCommand` and the tenant-invitation commands), it gets **none** of those behaviors. You must:

- **Persist manually** — call `Context.SaveChangesAsync(ct)` yourself; there is no ambient UnitOfWork commit. Use the existing context (e.g. `TenantUserManager.Context.SaveChangesAsync(...)`, as in `TenantIdentityServices.cs` / `AccountUserService`).
- **Validate manually** — `ValidationBehavior` only runs DataAnnotations on a `Data` property, never FluentValidation, and validators are **not** DI-registered (no `AddValidatorsFromAssembly` anywhere). Instantiate the validator in the handler:

```csharp
var validation = await new XCommandValidator().ValidateAsync(request, ct);
if (!validation.IsValid)
    throw new MixException(MixErrorStatus.Badrequest,
        validation.Errors.Select(e => e.ErrorMessage).ToArray());
```

`MixException.Status` enum values equal HTTP codes (400/401/403/404/500) — map them in controllers with `StatusCode((int)ex.Status, new { error = ex.Message })`.

---

## Outbound email (EDM) is a no-op stub

🚨 **CRITICAL RULE:** Do not assume `IMixEdmService.SendMailWithEdmTemplate(...)` actually delivers mail — it does not in the current build. The real `mix.notification/Services/MixEdmService.cs` is **excluded from compilation** (`<Compile Remove>` in `mix.notification.csproj`) and unregistered. Two `IMixEdmService` interfaces exist (`mix.notification.Interfaces` and `Mix.Account.Interfaces`); the only registration is `mix.account/Startup.cs` → `AddScoped<IMixEdmService, DefaultEdmService>()`, a no-op that logs and returns. EDM templates load by name via `GetEdmTemplate(filename)`; none ship in the repo. The Cloud.Mail `IEmailService` SMTP/Resend providers are likewise stubs.

When a feature "sends email" (register, confirm-email, password-reset, tenant-invite): store/queue the artifact and surface the limitation — never report delivery. Wiring a real provider is separate work.

---

## Data and JSON conventions

- Keep EF Core mappings and entities compatible with existing snake_case DB naming conventions.
- Use `Newtonsoft.Json` (`JObject` / `JToken`) consistently where the project already uses it.
- Reuse existing configuration models in `mix.shared` before introducing new settings types.

---

## ViewModels (mix.heart)

ViewModels are the CQRS data layer. They live in `src/modules/<module>/ViewModels/` and extend one of three base classes.

### Hierarchy

```
QueryViewModelBase<TDbContext, TEntity, TPrimaryKey, TView>
  └── SimpleViewModelBase  — adds Id, CRUD command handlers
        └── ViewModelBase  — adds audit fields (CreatedDateTime, LastModified, CreatedBy, ModifiedBy, Priority, Status, IsDeleted)
```

### When to use each

| Base class | Use when |
|---|---|
| `QueryViewModelBase` | Read-only — no CRUD needed |
| `SimpleViewModelBase` | Full CRUD, no audit fields |
| `ViewModelBase` | Full CRUD with audit fields |

### Generic constraints (required on all ViewModels)

```csharp
where TPrimaryKey : IComparable
where TEntity     : class, IEntity<TPrimaryKey>
where TDbContext  : DbContext
where TView       : <BaseClass><TDbContext, TEntity, TPrimaryKey, TView>  // self-referencing
```

### Key members (SimpleViewModelBase)

```csharp
// Constructors
public SimpleViewModelBase()
public SimpleViewModelBase(TDbContext context)
public SimpleViewModelBase(TEntity entity, UnitOfWorkInfo? uowInfo)
public SimpleViewModelBase(UnitOfWorkInfo unitOfWorkInfo)

// Protected state
UnitOfWorkInfo? UowInfo
MixCacheService? CacheService
TDbContext? Context           // from UowInfo
List<ValidationResult> Errors
bool IsValid

// Key overridables
public virtual void InitDefaultValues(string? language = null, int? cultureId = null)
public virtual Task<TEntity> ParseEntity(CancellationToken ct = default)
protected virtual Task SaveEntityRelationshipAsync(TView view, TEntity entity, CancellationToken ct)
protected virtual Task DeleteEntityRelationshipAsync(TView view, CancellationToken ct)
public virtual async Task Validate(CancellationToken ct)

// Command methods — IMediator is always the first parameter
public virtual async Task<TPrimaryKey> CreateAsync(IMediator mediator, CancellationToken ct = default)
public virtual async Task UpdateAsync(IMediator mediator, TPrimaryKey id, TView data, CancellationToken ct = default)
public virtual async Task DeleteAsync(IMediator mediator, TView data, CancellationToken ct = default)
public virtual async Task PatchAsync(IMediator mediator, TPrimaryKey id, TView data, IEnumerable<EntityPropertyModel> props, CancellationToken ct = default)
public virtual async Task SaveManyAsync(IMediator mediator, List<TView> data, CancellationToken ct = default)
```

### Creating a ViewModel

```csharp
namespace Mix.<Module>.ViewModels;

public class ProductViewModel
    : SimpleViewModelBase<MixCmsContext, Product, int, ProductViewModel>
{
    public string Name { get; set; } = string.Empty;
    public decimal Price { get; set; }

    public override void InitDefaultValues(string? language = null, int? cultureId = null)
    {
        Name = "New Product";
        Price = 0;
    }

    protected override async Task SaveEntityRelationshipAsync(
        ProductViewModel view, Product entity, CancellationToken ct)
    {
        // persist child entities here using same UowInfo
        await Task.CompletedTask;
    }
}
```

With audit fields — extend `ViewModelBase` and call `base.InitDefaultValues()`:

```csharp
public class ArticleViewModel
    : ViewModelBase<MixCmsContext, Article, Guid, ArticleViewModel>
{
    public string Title { get; set; } = string.Empty;

    public override void InitDefaultValues(string? language = null, int? cultureId = null)
    {
        base.InitDefaultValues(language, cultureId); // sets CreatedDateTime, Status, etc.
        Title = "Untitled";
    }
}
```

### Validation pattern

```csharp
public override async Task Validate(CancellationToken ct)
{
    ct.ThrowIfCancellationRequested();
    if (string.IsNullOrWhiteSpace(Name))
        Errors.Add(new ValidationResult("Name is required", ["Name"]));
    if (Price < 0)
        Errors.Add(new ValidationResult("Price must be positive", ["Price"]));
    if (!IsValid)
        await HandleExceptionAsync(new MixException(MixErrorStatus.Badrequest,
            [.. Errors.Select(e => e.ErrorMessage ?? string.Empty)]));
}
```

### Entity relationship handling

Always guard `UowInfo` before touching related repos — share the same instance to stay in one transaction:

```csharp
protected override async Task SaveEntityRelationshipAsync(
    OrderViewModel view, Order entity, CancellationToken ct)
{
    if (UowInfo == null)
        throw new InvalidOperationException("UowInfo is not set.");

    var itemRepo = new EntityRepository<MixCmsContext, OrderItem, int>(UowInfo);
    itemRepo.SetCacheService(CacheService);
    foreach (var item in view.Items)
    {
        var itemEntity = await item.ParseEntity(ct);
        itemEntity.OrderId = entity.Id;
        await itemRepo.SaveAsync(itemEntity, ct);
    }
}
```

### Services overview

| Service | Package | Use for |
|---|---|---|
| `HeartCrudService` | mix.heart | Basic CRUD via mediator (no tenant/identity) |
| `CrudService` | mix.lib | Full CRUD with tenant stamping, cache, SignalR |
| `EntityRepository` | mix.heart | Direct DB ops inside a UnitOfWork |

```csharp
// Preferred: CrudService wraps tenant concerns
public class ProductService(
    IHttpContextAccessor httpContextAccessor,
    IMixIdentityService identityService,
    IMediator mediator,
    UnitOfWorkInfo<MixCmsContext> uow,
    MixCacheService cacheService)
{
    private readonly CrudService<ProductViewModel, MixCmsContext, Product, int> _crud
        = new(httpContextAccessor, identityService, mediator, uow, cacheService);

    public Task<int> CreateAsync(ProductViewModel vm, CancellationToken ct)
        => _crud.CreateAsync(vm, ct);
}
```

### Default ID check

```csharp
public bool IsDefaultId(TPrimaryKey id)
{
    if (id == null) return true;
    if (id is Guid g) return g == Guid.Empty;
    if (id is int i) return i == default;
    return EqualityComparer<TPrimaryKey>.Default.Equals(id, default);
}
```

### QueryHandlers / ExpandView (rendering layer — mandatory)

Every ViewModel that lives in `src/apps/mix.rendering/ViewModels/` **must** have a matching handler in `src/apps/mix.rendering/Handlers/` that extends `QueryHandlers<TView, TDbContext, TEntity, TPrimaryKey>`. The handler overrides `ExpandView` to populate derived/related fields (template file paths, layout paths, child collections) after the base CQRS query loads the entity.

Checklist: **ViewModel → Handler is always a pair. Creating one without the other is a bug.**

```csharp
// src/apps/mix.rendering/Handlers/WidgetContentHandlers.cs
public class WidgetContentHandlers(
    UnitOfWorkInfo<MixCmsContext> uow,
    MixCacheService cacheService,
    IMediator mediator)
    : QueryHandlers<WidgetContentViewModel, MixCmsContext, MixWidgetContent, int>(uow, cacheService)
{
    public IMediator Mediator { get; } = mediator;

    public override async Task ExpandView(
        WidgetContentViewModel result,
        CancellationToken cancellationToken = default)
    {
        if (result.Template == null)
        {
            result.Template = await Mediator.Send(
                new GetSingleQuery<MixTemplateViewModel, MixCmsContext, MixTemplate, int>(
                    m => m.Id == result.TemplateId));
            result.TemplateFilePath = $"{result.Template?.FileFolder}/{result.Template?.FileName}";

            result.Layout = await Mediator.Send(
                new GetSingleQuery<MixTemplateViewModel, MixCmsContext, MixTemplate, int>(
                    m => m.Id == result.LayoutId));
            result.LayoutFilePath = result.Layout != null
                ? $"{result.Layout.FileFolder}/{result.Layout.FileName}"
                : null;
        }
    }
}
```

`ExpandView` is the read-side complement to `SaveEntityRelationshipAsync`. Use it to:
- Resolve `TemplateFilePath` / `LayoutFilePath` from template IDs
- Load associated collections via `GetListQuery` (e.g., modules on a page)
- Load paginated child collections via `GetPagingQuery` + `PagingResponseModel<T>` (e.g., posts on a page, using the parent's `PageSize` as the page size)

---

## EF Core migration reminders

Run from repo root:

```bash
dotnet ef --startup-project src/apps/MixCore.Cloud.Web --project src/platform/mix.database \
  migrations add <MigrationName> --context <ContextName> --output-dir Migrations/<Path>
```

EF Core 10 treats pending model changes as errors — always add/align migrations when entity models change.

---

## Build and test commands

```bash
dotnet build src/MixCore.Cloud.sln
dotnet test  src/MixCore.Cloud.sln
dotnet test  src/tests/mix.database.migrations.tests
dotnet test  src/tests/mix.installation.tests

# Targeted filters
dotnet test src/tests/mix.database.migrations.tests --filter "FullyQualifiedName~<ClassOrMethod>"
dotnet test src/tests/mix.installation.tests --filter "Trait=Database|MySQL"
dotnet test src/tests/mix.installation.tests --filter "Trait=Database|SqlServer"
```

---

## Common requests mapping

| Request | Action |
|---|---|
| "add endpoint" | Extend existing controller base in the right module; keep `api/v1` versioning |
| "add service logic" | Prefer extending `CrudService` or `TenantServiceBase` |
| "add ViewModel" | Extend `SimpleViewModelBase` (no audit) or `ViewModelBase` (with audit); override `InitDefaultValues`, `Validate`, `ParseEntity` as needed. **If the ViewModel is in `mix.rendering`, also create a matching `QueryHandlers` subclass in `Handlers/` with `ExpandView` overridden.** |
| "add validation" | Override `Validate()`, add to `Errors`, throw via `HandleExceptionAsync` |
| "handle child entities" | Override `SaveEntityRelationshipAsync` / `DeleteEntityRelationshipAsync`; use same `UowInfo` |
| "fix DI startup error" | Verify `AddDbContexts()` is called before `AddMixAuthorize()` |
| "add migration" | Run `dotnet ef` from repo root with explicit context and output folder |
| "improve C# code quality" | Enforce nullable safety, explicit error flow, project conventions — no workaround casts |
| "add/fix MCP tool" | Read `references/mcp-tool-authoring.md` first — covers `McpToolBase` inheritance, tenant scoping, `IHttpContextAccessor` registration |

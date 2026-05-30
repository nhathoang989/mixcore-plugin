---
name: module
description: Scaffold a mixcore-cloud module — either a brand-new standalone module project (new csproj + IStartupService + solution registration) OR a controller/service added to an existing module. Covers controllers (CRUD/read-only), services, ViewModels, DI wiring, and the module auto-discovery contract. For ViewModels/CQRS handlers use mixcore:dotnet-code; for EF entities + migrations use mixcore:migration.
argument-hint: "[new-project|add-controller|add-service] [Entity] [crud|read-only] [in <folder-path>]"
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
  - Edit
  - Write
---

You are scaffolding a **mixcore-cloud module** — a feature module under `src/modules/<domain>/` or a cloud pillar under `src/cloud/`. All paths are relative to the repo root.

## Two modes — decide first

| Mode | When | What you create |
|---|---|---|
| **A. New standalone module project** | "create a new module", "new project from scratch", target folder does not exist yet | New `.csproj`, `Startup.cs` (`IStartupService`), solution entry, then controller/service |
| **B. Add to an existing module** | target module folder already exists; "add a controller/service to mix.X" | Just the `Controllers/`/`Services/` files + DI registration in the existing `Startup.cs` |

> Adding **any other class** (ViewModel, CQRS handler) to an existing module that just needs more logic → that's `mixcore:dotnet-code`, not this skill. This skill is for the module skeleton and its controller/service surface.

## Collect inputs before touching files

```
1. Target folder path (required)   e.g. src/modules/cms/mix.content  OR  src/cloud/MixCore.Cloud.Auth
2. Entity name (required)          e.g. "Product", "ApiToken", "Campaign"
3. Controller type (default crud)  crud → CrudControllerBase (GET+POST+PUT+DELETE+PATCH) · read-only → ReadOnlyControllerBase (GET only)
4. Authorization (default admin+editor)  admin+editor → MixRoles.Administrators + "," + MixRoles.Editors · owner → MixRoles.Owner · any-auth → [MixAuthorize] no roles
```

---

## Module anatomy

```
src/modules/<domain>/mix.<module>/        (or src/cloud/MixCore.Cloud.<Pillar>/)
├── Controllers/<Entity>Controller.cs
├── Services/<Entity>Service.cs           (optional — omit for pure pass-through CRUD)
├── ViewModels/<Entity>ViewModel.cs       (scaffold via mixcore:dotnet-code)
├── Startup.cs                            # IStartupService — module self-registration
└── mix.<module>.csproj
```

The module is discovered automatically via `MixAssemblyFinder.GetAssembliesByPrefix("mix")` — **no `Program.cs` edit** needed, just reference the csproj from the web host.

---

## Mode A — new project skeleton

### `Startup.cs` (`IStartupService` from `Mix.Shared.Interfaces`)

```csharp
namespace Mix.<Module>;

public class Startup : IStartupService
{
    public Task ConfigureServices(IHostApplicationBuilder builder)
    {
        // module DI here, e.g. builder.Services.AddScoped<<Entity>Service>();
        return Task.CompletedTask;
    }
    public Task Configure(IApplicationBuilder app, IConfiguration config, bool isDev) => Task.CompletedTask;
    public Task ConfigureEndpoints(IEndpointRouteBuilder endpoints, IConfiguration config, bool isDev) => Task.CompletedTask;
}
```

### `.csproj`

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
  </PropertyGroup>
  <ItemGroup>
    <ProjectReference Include="..\..\..\platform\mix.lib\mix.lib.csproj" />
    <ProjectReference Include="..\..\..\platform\mix.database\mix.database.csproj" />
  </ItemGroup>
</Project>
```

Add to the solution and reference it from the web host:

```bash
dotnet sln src/MixCore.Cloud.sln add src/modules/<domain>/mix.<module>/mix.<module>.csproj
```

---

## Controller

Route convention: **kebab-case, plural** — `Product` → `api/v1/rest/products`, `ApiToken` → `api/v1/rest/api-tokens`.

### CRUD — `CrudControllerBase<TView, TDbContext, TEntity, TPrimaryKey>`

```csharp
using MediatR;
using Microsoft.AspNetCore.Mvc;
using Mix.Auth.Interfaces;
using Mix.Database.Entities.Cms;
using Mix.Heart.UnitOfWork;
using Mix.Lib.Controllers;
using Mix.Lib.Interfaces;
using Mix.Queue.Interfaces;
using Mix.Queue.Models;
using Mix.<Module>.Services;
using Mix.<Module>.ViewModels;

namespace Mix.<Module>.Controllers;

[MixAuthorize(roles: MixRoles.Administrators + "," + MixRoles.Editors)]
[Route("api/v1/rest/<entity-kebab-plural>")]
[ApiController]
public class <Entity>Controller(
    IMixIdentityService mixIdentityService,
    IHttpContextAccessor httpContextAccessor,
    IMediator mediator,
    ITenantService tenantService,
    UnitOfWorkInfo<MixCmsContext> uow,
    IMemoryQueueService<MessageQueueModel> queueService,
    <Entity>Service entityService)
    : CrudControllerBase<<Entity>ViewModel, MixCmsContext, <Entity>, int>(
        mixIdentityService, httpContextAccessor, mediator, tenantService, uow, queueService)
{
    protected readonly <Entity>Service EntityService = entityService;
}
```

### Read-only — `ReadOnlyControllerBase<...>`

```csharp
[MixAuthorize(roles: MixRoles.Administrators + "," + MixRoles.Editors)]
[Route("api/v1/rest/<entity-kebab-plural>")]
[ApiController]
public class <Entity>Controller(
    IHttpContextAccessor httpContextAccessor,
    IMediator mediator,
    ITenantService tenantService,
    UnitOfWorkInfo<MixCmsContext> uow,
    <Entity>Service entityService)
    : ReadOnlyControllerBase<<Entity>ViewModel, MixCmsContext, <Entity>, int>(
        httpContextAccessor, mediator, tenantService, uow)
{
    protected readonly <Entity>Service EntityService = entityService;
}
```

> The base constructor signatures above are verified against `src/platform/mix.lib/Controllers/{CrudControllerBase,ReadOnlyControllerBase}.cs`. `CrudControllerBase` takes 6 args `(IMixIdentityService, IHttpContextAccessor, IMediator, ITenantService, UnitOfWorkInfo, IMemoryQueueService)`; `ReadOnlyControllerBase` takes 4 `(IHttpContextAccessor, IMediator, ITenantService, UnitOfWorkInfo)`. Do **not** use the older cache/hub-service signature.

**Rules:** action methods are `public virtual` (override to customise); `[ApiController]` + `[Route("api/v1/...")]` on every controller; return `ActionResult<T>`/`IActionResult`; throw `MixException(MixErrorStatus, message)` for domain errors. Controllers are auto-discovered by `AddControllers()` — never register them in DI.

---

## Service — `CrudService<...>` (only when you need custom logic)

```csharp
using MediatR;
using Mix.Database.Entities.Cms;
using Mix.Heart.UnitOfWork;
using Mix.Lib.Services;
using Mix.<Module>.ViewModels;

namespace Mix.<Module>.Services;

public class <Entity>Service(
    IHttpContextAccessor httpContextAccessor,
    IMediator mediator,
    UnitOfWorkInfo<MixCmsContext> uow)
    : CrudService<<Entity>ViewModel, MixCmsContext, <Entity>, int>(httpContextAccessor, mediator, uow)
{
    // Add custom query methods only when the controller needs them; leave empty for pass-through CRUD.
}
```

## ViewModel (brief — full guidance in `mixcore:dotnet-code`)

```csharp
namespace Mix.<Module>.ViewModels;

public class <Entity>ViewModel
    : TenantDataViewModelBase<MixCmsContext, <Entity>, int, <Entity>ViewModel>
{
    public string Name { get; set; } = string.Empty;
    public override <Entity> ParseEntity(MixCmsContext context)
    {
        var entity = base.ParseEntity(context);
        entity.Name = Name;
        return entity;
    }
}
```

Use `TenantDataViewModelBase` for entities with `TenantId`, `DisplayName`, `Description`, `Image`.

---

## `Startup.cs` DI registration

Inside `ConfigureServices()` of the module's `Startup.cs`:

```csharp
services.AddMediatR(cfg => cfg.RegisterServicesFromAssembly(typeof(Startup).Assembly)); // one call per module
services.AddScoped<<Entity>Service>();
```

### Host DI order (critical, applies to the web host)

```csharp
builder.AddDbContexts();     // 1st — registers all DbContext + UoW
builder.AddMixAuthorize();   // 2nd — depends on UnitOfWorkInfo<MixCmsAccountContext>
```

Missing `AddDbContexts()` before `AddMixAuthorize()` → DI validation error at startup.

---

## Conventions

- Namespaces: `Mix.<Module>`, `Mix.<Module>.Controllers`, `Mix.<Module>.Services`. Private fields `_camelCase`; interfaces `IFoo`.
- `[EnableCors(MixCorsPolicies.PublicApis)]` on endpoints that allow any origin without credentials.

## Out of scope — defer to

| Need | Skill |
|---|---|
| ViewModel data contracts, CQRS handlers (cache/side-effects), general C# | `mixcore:dotnet-code` |
| EF Core entity + migration (all 4 providers) | `mixcore:migration` |
| Build / run / package | `mixcore:dotnet-cli` |

## Verify

```bash
dotnet build src/MixCore.Cloud.sln
```

| Compile error | Fix |
|---|---|
| `CrudControllerBase` not found | `using Mix.Lib.Controllers;` |
| `CrudService` not found | `using Mix.Lib.Services;` |
| `MixAuthorize` not found | `using Mix.Auth.Interfaces;` |
| `IMemoryQueueService` not found | `using Mix.Queue.Interfaces;` |
| ViewModel type unresolved | scaffold it first via `mixcore:dotnet-code` |

## Common task patterns

- **"create a new module"** → Mode A: folder, `Startup.cs`, `.csproj`, add to sln, then controller/service.
- **"add a CRUD controller"** → `CrudControllerBase` (6-arg ctor) + route `api/v1/rest/<entity-kebab-plural>`.
- **"add a read-only controller"** → `ReadOnlyControllerBase` (4-arg ctor).
- **"add a service"** → extend `CrudService`, override virtuals for custom logic.
- **"wire module loading"** → implement `IStartupService` in `Startup.cs`; auto-discovered by assembly prefix `"mix"`.

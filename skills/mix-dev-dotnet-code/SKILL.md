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
All paths are relative to: the **mixcore-cloud** solution root.

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
- Use `IHubClientService` for SignalR notifications (forwarded to the `PortalHubClientService` singleton in `mix.lib`) and `IMemoryQueueService<MessageQueueModel>` for queue events.
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

## Outbound email — `Mix.Shared.Email.IEmailService` (MixCore.Cloud.Mail)

Email is sent through the single platform contract `Mix.Shared.Email.IEmailService` (`src/platform/common/mix.shared/Email/IEmailService.cs`), implemented by `MixCore.Cloud.Mail.Services.EmailService` and registered in `MixCore.Cloud.Mail/Startup.cs` (`AddScoped<IEmailService, EmailService>()`, alongside `IEdmTemplateRenderer → EdmTemplateRenderer` and the unkeyed `IEmailProvider → SmtpEmailProvider`). `mix.account/Startup.cs` documents this: account itself no longer registers any email service.

To send mail, inject `IEmailService` and call:
- `SendAsync(int tenantId, SendEmailDto dto, ct)` — inline `dto.BodyHtml`.
- `SendWithTemplateAsync(int tenantId, string templateName, JObject data, SendEmailDto dto, ct)` — named template with `[[Token]]` replacement from `data`; falls back to `dto.BodyHtml` when the template resolves empty.

Note the template store is not yet populated: `GetTemplateAsync` returns empty until one is implemented, so `SendWithTemplateAsync` falls back to the inline body. The SMTP provider does the actual delivery — there is no `IMixEdmService` / `mix.notification` / `DefaultEdmService`; those types were removed.

---

## In-app notifications — `INotificationService` + `IHubContext<NotificationHub>`

The notification system stores rows in `mix_notification` (AuditLogDbContext) and pushes to users in real-time via SignalR. For full architecture see [developer-notifications.md](system-prompts/instructions/developer/developer-notifications.md).

### Service pattern

Inject `INotificationService` (scoped, `mix.lib`) — it persists AND broadcasts via `IHubContext<NotificationHub>` in one call:

```csharp
// Create + broadcast in one call
await _notificationService.CreateAsync(new Notification
{
    TenantId = tenantId,
    UserId = userId,        // null = broadcast to all
    Title = "Deploy complete",
    Body = "Production deploy finished successfully.",
    Type = "success",
    Category = "deploy",
    ActionUrl = $"/cloud/deploy/{deployId}",
    Source = $"deploy.run.{runId}",
    CorrelationId = runId
});
```

### Direct IHubContext injection (services that need custom broadcast logic)

```csharp
public class MyService(IHubContext<NotificationHub> hub)
{
    await hub.Clients.Group(NotificationHub.UserGroup(userId))
        .SendAsync(HubMethods.NewNotification, notification);
    // Or broadcast to all: hub.Clients.All.SendAsync(...)
}
```

Group naming: `NotificationHub.UserGroup(int userId)` → `"notif_{userId}"`. On connect, `NotificationHub.OnConnectedAsync` auto-joins the user's group.

### REST API fallback

`NotificationsController` (`api/v1/notifications`) — paginated GET, unread-count, mark-read, delete. Auth via `[Authorize]`, user resolved from JWT `MixClaims.Id`. Use `INotificationsApiClient` (loopback) in Blazor.

### MCP tools

`NotificationTool` (`[McpServerToolType]`) — `create_notification`, `list_notifications`, `get_unread_count`, `mark_read`, `mark_all_read`. Follows standard `McpToolBase` pattern.

---

## mix.ai agents & hubs — never leak raw exceptions to the chat user

🚨 **CRITICAL RULE:** any error that can reach the chat UI (a `BaseAgent`/specialist-agent catch, or a SignalR hub's `ReceiveError`/`ReceiveComplete`) must be sanitized through `AgentErrorMessages.From(ex)` (`Mix.AI.Application.Agents`) — never `ex.Message`. Raw text like `Status(StatusCode="Unavailable", Detail="Connection refused")` must stay in `LogError` only. The mapping: connectivity failures (gRPC `RpcException`, `SocketException`, `HttpRequestException`, `TimeoutException` — including inside an `AggregateException`) → "knowledge base unavailable" message; everything else → a generic retry message.

When adding or editing an agent (`TaskAgent`, `PlanningService`, `ChatAgent`, …) or a hub (`LLMHub`, `SiteWikiHub`, `AIContentEditorHub`):
- The catch that builds the user-facing `AgentProcessResult` **Content AND Error** (and any streamed `OnChunk`/`EmitAsync` text) must use `AgentErrorMessages.From(ex)`, not the raw message.
- **Rethrow `OperationCanceledException`** (`catch (OperationCanceledException) { throw; }`) before the general catch — a caller-cancelled request is benign; the hubs already filter it via `when (ex is not OperationCanceledException)`.
- **RAG/vector lookups are best-effort.** `RAGProcessor.BuildContextAsync` degrades to empty context on any backend failure — keep it that way; a missing vector store must never fail the chat. The Qdrant client bounds its connect phase via `VectorDbConfiguration.ConnectTimeoutSeconds` (default 2s) so an unreachable Qdrant costs ~2s/call, not the ~5s platform default.

---

## mix.ai plan lifecycle — resume/retry/continue (PR #249)

`AgentLoopService` is a native LLM tool-calling loop — the model creates/ticks `AIPlan`/`AIPlanStep` rows via the local plan tools backed by `PlanToolService`. Nothing "executes step N" deterministically. When touching plan re-execution, respect these invariants:

- **Re-attach, don't duplicate.** `POST /api/v1/ai/plans/{id}/resume|retry|continue` enqueue a `mix-ai-plan-resume` message (202); `AIPlanQueueSubscriber` re-runs the loop with `AgentRequest.ExistingPlanId` set so `PlanToolService.BindToExisting` loads the existing plan. `ReRun` (synchronous) is the old duplicate-as-new-plan path — leave it alone.
- **Verb = reset scope only:** `retry` → `ResetScope.FailedPlusNonCompleted`; `resume`/`continue` → `ResetScope.NonCompleted` (Failed steps stay Failed). Completed steps + `ResultJson` are NEVER reset. The API is deliberately lenient (any verb on any non-Completed, non-running plan); the UI gates stricter.
- 🚨 **One DI scope, one loop per plan.** `PlanToolService` and `AgentLoopService` are both scoped, and the loop is constructed with the scope's `PlanToolService` — resolve both from the SAME scope and call `BindToExisting` + `ResetForResumeAsync` BEFORE `ProcessAsync` (the loop's re-bind is idempotent). The write gate is per-instance, so two loops on one plan from different scopes race the same rows — that's why the controller 409s on `InProgress`/`WaitingForApproval`.
- **Hub streaming is free.** The loop reroutes `OnEvent` to the `ai-plan-{id}` SignalR group itself — a background caller passes `OnEvent: null` and the plan-detail page still streams live. Don't inject `IHubContext` into queue subscribers for this.
- **No orphaned plans.** `FinalizeAsync` (loop `finally`) drives every exit terminal; the subscriber additionally marks a still-`InProgress` plan `Failed` when the loop fails before its try (`MarkFailedIfStuckAsync`). Queue runs are non-interactive (`AwaitDecision` null) — approval-gated tools won't run and `clarify` dead-ends, so such plans finalize `Incomplete`, never hang.
- **`WaitingForApproval` is active, not orphaned** — a live loop is suspended on it. Never offer Resume on it directly; the escape hatch is Cancel → Resume. In cloud-ui, `IsActive` includes `WaitingForApproval` so Cancel stays visible.
- Session continuity has no `AIPlan.SessionId` column — the subscriber recovers it best-effort from the newest `AITranscript` by `PlanId`; `BuildResumeContextAsync` injects the authoritative plan state regardless.

---

## Data and JSON conventions

- Keep EF Core mappings and entities compatible with existing snake_case DB naming conventions.
- Use `Newtonsoft.Json` (`JObject` / `JToken`) consistently where the project already uses it.
- Reuse existing configuration models in `mix.shared` before introducing new settings types.

---

## Runtime LLM prompts live in files — never hardcode them in C#

🚨 **CRITICAL RULE:** every LLM prompt (system instruction, rerank/classify/parse prompt, agent persona) lives as a `.md` file under `src/apps/MixCore.Cloud.Web/system-prompts/system/`, loaded via `ISystemPromptService`:

```csharp
var prompt = systemPromptService.BuildFromTemplate(
    systemPromptService.LoadPrompt("my-prompt.md"),           // caches per filename, process-wide
    new Dictionary<string, string> { ["Key"] = value });      // fills {{Key}} placeholders
```

Rules that follow:
- **`BuildFromTemplate` STRIPS unmatched `{{...}}`** — never put literal double-brace text in a prompt file (single-brace JSON examples like `{"index":0}` are safe).
- **A missing prompt file must land in the call-site's existing fallback**, never a new exception surface: put `LoadPrompt` *inside* the existing try/catch (rerank → BM25 order, parse → "Could not parse query", summarize → trimmed history).
- **Filenames are path-locked** once referenced from C# — renaming the file without the call site breaks silently at runtime (`FileNotFoundException` → fallback). Update docs-sync's locked-files list when adding one.
- Dynamic parts (`DateTime.UtcNow`, joined lists, personas) are template variables filled at call time — the file content itself is static and cached forever (`ClearCache` to refresh).
- In tests the web-host `wwwroot` doesn't exist — seed `FakeSystemPromptService` (`mix.ai.tests/Agents/`) with filename→template pairs; it mirrors production `BuildFromTemplate` semantics.

## DI lifetime gotchas (learned the hard way)

- **Stateless file-loader services with instance caches must be singletons.** `SystemPromptService` and `SkillService` were scoped — their "process-lifetime" caches were per-request, so every request re-read/re-parsed the whole corpus. If a service is stateless w.r.t. the request and caches disk content, register `AddSingleton`.
- **Captive dependency check:** a singleton factory lambda (`services.AddSingleton(sp => ...)`) must not resolve scoped services. If a scoped service is needed by both scoped and singleton consumers, either make it a singleton (when stateless) or resolve it from a created scope at call time (`scopeFactory.CreateScope()` — see `GameAiOpponent.ThinkAsync`).
- **Never `= null` default for DI-injected services** in DI-resolved ctors (can silently inject null). Optional-with-default is fine ONLY for manually-constructed classes (factory lambdas, tests) where you control every call site — e.g. `VectorLessService(..., ISystemPromptService? promptService = null)`.

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

// Command methods — IMediator is always the first parameter. These act on `this` (the current
// ViewModel instance) — they do NOT take a `TView data` argument. (Older skill drafts showed a
// `data` param; that is wrong — verified against SimpleViewModelBase.)
public virtual async Task<TPrimaryKey> CreateAsync(IMediator mediator, CancellationToken ct = default)
public virtual async Task UpdateAsync(IMediator mediator, TPrimaryKey id, CancellationToken ct = default)  // id must equal this.Id
public virtual async Task DeleteAsync(IMediator mediator, CancellationToken ct = default)
public virtual async Task PatchAsync(IMediator mediator, TPrimaryKey id, IEnumerable<EntityPropertyModel> props, CancellationToken ct = default)
public virtual async Task SaveAsync(IMediator mediator, CancellationToken ct = default)  // ⚠️ INSERT-ONLY — see rule below
```

### 🚨 CRITICAL RULE: `SaveAsync` is INSERT-ONLY — branch Create vs Update for upsert

`SaveAsync` dispatches `SaveCommand`, and the `GenericViewModelHandlers` `SaveCommand` handler
**unconditionally** `Context.Set<TEntity>().Add(entity)` — it never checks the PK. So `SaveAsync`
**always inserts**; calling it on a ViewModel with an existing `Id` PK-collides (SQLite `UNIQUE`
constraint → `MixException(ServerError)`) or silently duplicates the row. It never updates.

For a create-or-update endpoint, branch on `IsDefaultId` instead of calling `SaveAsync`:

```csharp
await vm.Validate(ct);
if (vm.IsDefaultId(vm.Id))
    await vm.CreateAsync(mediator, ct);          // Id == 0 / Guid.Empty → insert
else
    await vm.UpdateAsync(mediator, vm.Id, ct);   // existing Id → repo.UpdateAsync (real update)
```

`UpdateCommand` uses `repo.UpdateAsync` **and still runs `SaveEntityRelationshipAsync`**, so child
upsert + cache invalidation keep working on the update path. **Apply the same branch inside
`SaveEntityRelationshipAsync`** when persisting nested children that may already have an `Id` — a
nested `child.SaveAsync(...)` has the identical insert-only trap. (The `MixTenant`/culture
precedent only ever *creates* children on signup, so it never surfaced this.)

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

🚨 **`IsValid` defaults `false` and is NEVER auto-set.** It is a plain `protected bool { get; set; }`
on `QueryViewModelBase`. `base.Validate()` throws `MixException(Badrequest)` on `!IsValid` — so a
`Validate` override that calls `await base.Validate(ct)` (or does its own `if (!IsValid) throw`)
**always 400s, even on valid input, with an empty error message** (empty because `Errors` is empty).
You MUST stamp `IsValid = Errors.Count == 0;` before the base call / the throw:

```csharp
public override async Task Validate(CancellationToken ct)
{
    ct.ThrowIfCancellationRequested();
    if (string.IsNullOrWhiteSpace(Name))
        Errors.Add(new ValidationResult("Name is required", ["Name"]));
    if (Price < 0)
        Errors.Add(new ValidationResult("Price must be positive", ["Price"]));

    IsValid = Errors.Count == 0;              // ← REQUIRED — defaults false, never auto-set
    await base.Validate(ct);                  // throws MixException(Badrequest, Errors) when !IsValid
}
```

Notes:
- The command methods (`CreateAsync`/`UpdateAsync`/`SaveAsync`) do **not** call `Validate` — only the
  `ValidationBehavior` pipeline (DataAnnotations on a `Data` property) runs automatically. If you want
  custom `Validate()` enforced, **call `await vm.Validate(ct)` explicitly in the controller** before the
  Create/Update — and then the `IsValid` stamp above is mandatory or every write 400s.
- Precedent for the stamp: `MixThemeImportService` (`siteData.IsValid = siteData.Errors.Count == 0`).

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

### 🚨 CRITICAL RULE: register a concrete CQRS handler per ViewModel

`GenericViewModelHandlers<TView, TDbContext, TEntity, TPrimaryKey>` (the base that implements every
`SaveCommand`/`GetFirstQuery`/`GetSingleQuery`/… handler) is **generic** — MediatR's
`RegisterServicesFromAssembly` only registers **concrete closed** handlers. So **every new ViewModel used
through `CrudService`/`CrudControllerBase` MUST have a one-line concrete handler subclass**, or the first
CRUD call throws at runtime (the build stays clean): `No service for type 'IRequestHandler<GetFirstQuery<…>>'`.

```csharp
// src/.../Handlers/ProductViewModelHandler.cs  (one class per ViewModel)
public sealed class ProductViewModelHandler
    : GenericViewModelHandlers<ProductViewModel, MixCmsContext, Product, int>
{
    public ProductViewModelHandler(UnitOfWorkInfo<MixCmsContext> uow, MixCacheService cacheService)
        : base(uow, cacheService) { }
}
```

Place it in an assembly scanned by `AddMixCqrs(...)` (e.g. `mix.lib`, alongside `MixCultureViewModelHandler`).
One handler class covers both commands and queries for that ViewModel.

### Services overview

| Service | Package | Use for |
|---|---|---|
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

## Repository paging patterns (mix.heart)

`ViewQueryRepository` and `EntityRepository` (mix.heart) provide two paging strategies. Pick the right one for your use case.

### OFFSET paging (`GetPagingAsync` / `GetPagingEntitiesAsync`)

Use when the UI needs **page-number navigation** and/or **exact total counts** (admin grids, paginated lists with "page 3 of 47").

```csharp
var repo = new ViewQueryRepository<MyContext, MyEntity, int, MyViewModel>(uow);
var result = await repo.GetPagingAsync(
    m => m.Status == "active",
    new PagingModel { PageIndex = 2, PageSize = 20 },
    ct);
// result.Items (20 items), result.PagingData.Total, result.PagingData.TotalPage
```

**Perf note:** Internally batched into 3 queries (COUNT + key-fetch + full-row batch), not one query per row. Still, `OFFSET` scans-and-discards skipped rows, so deep pages are linear in cost. Use keyset paging for deep/infinite-scroll feeds.

**`SkipTotalCount`** — set `paging.SkipTotalCount = true` to skip the `COUNT(*)` round trip entirely. `Skip`/`Take` still apply; `Total`/`TotalPage` stay as the caller set them (e.g. a cached count, or 0 for "unknown"). Use for hot paths where exact totals aren't needed.

```csharp
var paging = new PagingModel { PageIndex = 0, PageSize = 50, SkipTotalCount = true };
var result = await repo.GetPagingAsync(_ => true, paging, ct);
// result.PagingData.Total == 0 — caller opted out of counting
```

### Keyset (cursor) paging (`GetKeysetPagingAsync`)

Use when the UI is **infinite-scroll**, **feed-based**, or iterating **large tables** where `OFFSET` depth becomes a problem. O(log n) at any page depth, stable under concurrent inserts/deletes. Cursor = last row's `Id`. No COUNT, no OFFSET.

Available on `ViewQueryRepository` (returns ViewModels). Not on `EntityRepository` (raw-entity paging).

```csharp
// First page
var page1 = await repo.GetKeysetPagingAsync(
    m => m.Status == "active",
    new KeysetPagingModel<int> { PageSize = 20 },
    ct);
// page1.Items (20 items), page1.HasMore, page1.NextCursor (10 — last row Id)

// Next page — pass cursor back
var page2 = await repo.GetKeysetPagingAsync(
    m => m.Status == "active",
    new KeysetPagingModel<int> { After = page1.NextCursor, PageSize = 20 },
    ct);

// Descending (newest-first)
var recent = await repo.GetKeysetPagingAsync(
    _ => true,
    new KeysetPagingModel<int> { PageSize = 20, Direction = SortDirection.Desc },
    ct);
```

**Trade-offs:**
| | OFFSET (`GetPagingAsync`) | Keyset (`GetKeysetPagingAsync`) |
|---|---|---|
| Page-number jumps | Yes | No (cursor = last seen Id) |
| Exact total count | Yes | No (HasMore only) |
| Deep-page cost | O(n) (scans all prior rows) | O(log n) (index seek) |
| Stable under concurrent writes | No (rows shift) | Yes (Id-anchored) |
| Available on | ViewQueryRepository, EntityRepository, QueryRepository | ViewQueryRepository only |

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

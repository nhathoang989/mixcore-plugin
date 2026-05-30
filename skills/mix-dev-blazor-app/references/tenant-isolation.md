# mixcore:mix-dev-blazor-app · Tenant Isolation in Blazor Server Circuits

Loaded by `mixcore:mix-dev-blazor-app` whenever a Blazor Server section loads tenant-scoped data. Explains why `IHttpContextAccessor` fails after the initial render and the two-layer `BlazorTenantContext` / `MixSectionContext` pinning pattern, with the dedup guards. Pair with [embedded-dashboard.md](embedded-dashboard.md).

---

## Tenant Isolation in Blazor Server Circuits

🚨 **CRITICAL RULE:** Never use `?? 1` as a tenant ID fallback in Blazor section components. `1` is the platform tenant — using it silently routes all data operations to the wrong tenant.

### Why `IHttpContextAccessor` fails in Blazor Server

Blazor Server components run over a persistent SignalR connection. After the initial HTTP render, `IHttpContextAccessor.HttpContext` is `null` or stale. Any service that internally calls `HttpContext.Items["ResolvedTenantId"]` returns `0` or falls back to `1` for every subsequent interaction in the circuit lifetime.

### Two-layer tenant pinning architecture

```
MVC View (.cshtml)
  └─ param-TenantId='@(Context.Items["ResolvedTenantId"] as int? ?? 1)'
       └─ Shell component (CloudDashboard / AdminDashboard)
            ├─ TenantCtx.Initialize(TenantId)  ← pins to BlazorTenantContext for circuit
            └─ <CascadingValue Value="_sectionContext" IsFixed="true">
                 └─ Section components: Section?.TenantId ?? _tenantCtx.TenantId
```

Layer 1: `MixSectionContext` cascades the tenant ID from the shell to descendants  
Layer 2: `BlazorTenantContext` (scoped, one per circuit) is the fallback when the cascade is null

### `BlazorTenantContext` service

Already registered in `Program.cs`. Do not re-register. Lives in `mix.ui.shared/Services/BlazorTenantContext.cs`.

```csharp
public class BlazorTenantContext
{
    private int _tenantId;

    public BlazorTenantContext(TenantDbResolver resolver, IHttpContextAccessor http)
    {
        var ctx = http.HttpContext;
        if (ctx?.Items.TryGetValue("ResolvedTenantId", out var raw) == true && raw is int id && id > 0)
            _tenantId = id;
    }

    public int TenantId => _tenantId > 0 ? _tenantId : 1;   // never returns 0

    // Idempotent — first call wins; subsequent calls are ignored
    public void Initialize(int tenantId)
    {
        if (tenantId > 0 && _tenantId == 0)
            _tenantId = tenantId;
    }

    public int ResolveFromDomain(string host) =>
        _resolver.GetIdByDomain(host) ?? TenantId;  // ?? TenantId (not ?? _tenantId)
}
```

### Shell component — call `Initialize` in `OnInitializedAsync`

```csharp
[Parameter] public int TenantId { get; set; } = 1;
[Inject] private BlazorTenantContext TenantCtx { get; set; } = default!;

protected override async Task OnInitializedAsync()
{
    TenantCtx.Initialize(TenantId);   // first line — before any service calls
    // ...
}
```

MVC view must supply the TenantId parameter:
```cshtml
param-TenantId='@(Context.Items["ResolvedTenantId"] as int? ?? 1)'
```

### Section component — correct tenant resolution pattern

```csharp
[CascadingParameter] private MixSectionContext? Section { get; set; }
[Inject] private BlazorTenantContext _tenantCtx { get; set; } = default!;

// Always resolve this way — never ?? 1
var tid = Section?.TenantId ?? _tenantCtx.TenantId;
SomeService.SetTenantId(tid);
```

### `MixSectionContext` — the cascading record

```csharp
public sealed record MixSectionContext(int TenantId);

// Shell declares the cascade:
<CascadingValue Value="new MixSectionContext(_activeTenantId)" IsFixed="true">
    @ChildContent
</CascadingValue>
```

### Lifecycle method rule

| Section type | Lifecycle method | Why |
|---|---|---|
| **List sections** (PageList, PostList, etc.) | `OnParametersSetAsync` | Must reload when the shell switches tenants or cascade changes |
| **Editor sections** with changing ItemId | `OnParametersSetAsync` + `_lastLoadedItemId` guard | Must reload when ItemId changes; guard prevents redundant loads |
| **Static / single-load sections** | `OnInitializedAsync` | Fires once per circuit; fine for display-only sections |

### Dedup guard — list sections (`_lastTenantId`)

`OnParametersSetAsync` fires on every parent `StateHasChanged`, not just when the tenant changes. Without a guard, a list section re-queries the DB on every sidebar highlight or toast notification.

```csharp
private int _lastTenantId;

protected override async Task OnParametersSetAsync()
{
    var tid = Section?.TenantId ?? _tenantCtx.TenantId;
    if (tid == _lastTenantId) return;      // skip if tenant unchanged
    _lastTenantId = tid;
    SomeService.SetTenantId(tid);
    await LoadAsync();
}
```

### Dedup guard — editor sections (`_lastLoadedItemId`)

```csharp
private string _lastLoadedItemId = "";

protected override async Task OnParametersSetAsync()
{
    if (ItemId == _lastLoadedItemId) return;
    _lastLoadedItemId = ItemId;
    SomeService.SetTenantId(Section?.TenantId ?? _tenantCtx.TenantId);
    await LoadAsync();
}
```


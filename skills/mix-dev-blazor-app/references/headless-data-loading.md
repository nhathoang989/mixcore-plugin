# Headless data loading + refresh-token retry (cloud portal & admin sections)

Mixcore is a **headless CMS**: a Blazor section's data must be reachable through the **REST API
contract**, not only through an in-process service call. But the portal is **co-hosted with the
API** by default, and a Blazor Server circuit that calls its own Kestrel over loopback HTTP
**deadlocks the circuit** (the request never completes; the SignalR connection then times out).
Those two facts are reconciled by the **transport-abstraction** pattern below — never by making a
co-hosted circuit call `/api` over HTTP.

> Reference implementation already in the repo:
> `IMixLogTransport` (interface, `mix.cloud.ui/Services`) →
> `InProcessMixLogTransport` (`MixCore.Cloud.Web/Services`, MediatR — co-hosted default) /
> `HttpMixLogTransport` (`mix.cloud.ui/Services`, `"LocalApi"` HttpClient — separate-process).
> Copy this shape for any new data-loading section.

## The rule

1. **A REST controller MUST exist for every section's data.** If a section loads data with no
   backing REST endpoint, **create the controller** (`[ApiController] [Authorize]`, inherit
   `TenantControllerBase`/`CrudControllerBase`/`ReadOnlyControllerBase` from `mix.lib`, resolve
   tenant from `HttpContext.Items["ResolvedTenantId"]`). This is the headless contract external
   clients / CLI / a future standalone portal depend on.
2. **The UI depends on an `IXxxApiClient` interface**, not on `IMediator` / a service / `DbContext`
   directly. Provide two implementations:
   - `HttpXxxApiClient` in `mix.cloud.ui/Services` — calls the REST endpoint over `"LocalApi"`.
   - `InProcessXxxApiClient` in `MixCore.Cloud.Web/Services` — calls the same read pipeline
     (MediatR / service) directly, **without** an ambient `HttpContext` (build queries from a
     synthetic `DefaultHttpContext().Request`; `IHttpContextAccessor.HttpContext` is null on a
     circuit).
3. **Bind the in-process impl by default** in the co-hosted host (`Program.cs`). A standalone
   portal (separate process) binds the HTTP impl. Document the swap in the module README.
4. **Read endpoints MUST emit camelCase JSON** (clients parse lowercase JObject keys like
   `r["name"]`, `r["triggerType"]`). Return hand-written anonymous DTOs, **not** raw ViewModels —
   raw ViewModels serialize PascalCase and the UI silently renders blank.

## Refresh-token retry (every HTTP data call)

The HTTP path must **retry once on `401` by renewing the access token** with the refresh token —
the programmatic-fetch analogue of `AdminTokenHelper.TryRefreshAndRetryAsync` (that helper only
covers **browser navigation** 401s via the status-code-pages handler; XHR/`HttpClient` calls are
not covered by it).

Wire it on the named client, not per-call:

```csharp
// Program.cs — the "LocalApi" client is NOT registered by default; register it so the
// refresh handler has a pipeline to attach to.
builder.Services.AddTransient<RefreshTokenHandler>();
builder.Services.AddHttpClient("LocalApi")
       .AddHttpMessageHandler<RefreshTokenHandler>();
```

`RefreshTokenHandler : DelegatingHandler` responsibilities:
- Attach `Authorization: Bearer {token}` from a **scoped token holder** — do **not** mutate
  `HttpClient.DefaultRequestHeaders` on the factory-shared client (it leaks across circuits).
- On `401`: read the `RefreshToken` GUID from the expired JWT claim (same extraction as
  `AdminTokenHelper.ExtractRefreshTokenId`), renew, write the new token back to the holder, then
  **clone and resend the request once**.
- **Single-flight** the renewal (a `SemaphoreSlim`) so concurrent 401s renew exactly once.
- Renewal path mirrors the transport split: **co-hosted** calls
  `IMixIdentityService.RenewTokenAsync(RenewTokenDto{ RefreshToken, AccessToken })` in-process;
  **standalone** calls a `POST /api/v1/auth/renew-token` endpoint (there is **no** REST
  renew-token endpoint today — add one for standalone). On renew failure, let the `401` surface so
  the section shows its existing auth-error UI.

## Checklist when adding/refactoring a data-loading section

- [ ] REST controller exists (create if missing); returns **camelCase** anonymous DTOs.
- [ ] `IXxxApiClient` interface in `mix.cloud.ui/Services`.
- [ ] `HttpXxxApiClient` (over `"LocalApi"`) + `InProcessXxxApiClient` (MediatR/service, no ambient `HttpContext`).
- [ ] In-process impl bound by default in `Program.cs`; HTTP impl documented for standalone.
- [ ] Section `.razor.cs` injects `IXxxApiClient` — **not** `IMediator`/service/`DbContext`.
- [ ] `"LocalApi"` registered with `RefreshTokenHandler` (single-flight 401 retry).
- [ ] Co-hosted smoke test: section renders rows with **no SignalR "Server timeout"** (deadlock regression).

## Anti-patterns (rejected in review)

- ❌ Section injects `IMediator` / `CrudService` / `DbContext` and loads data with no REST endpoint behind it.
- ❌ Co-hosted circuit calls its own `/api` over `"LocalApi"` (deadlock — that's why the in-process impl exists).
- ❌ HTTP client mutates `DefaultRequestHeaders.Authorization` per call instead of using a handler.
- ❌ Read controller returns raw ViewModels (PascalCase → UI renders blank).
- ❌ No 401/refresh retry on HTTP data calls.

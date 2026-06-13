# Headless data loading (cloud portal & admin sections)

Mixcore is a **headless CMS**: a Blazor section's data must be reachable through the **REST API
contract**, not only through an in-process service call — so the same endpoints a future
React/Vue/Angular SPA calls are the ones the Blazor UI uses. As of PR #265 the portal/admin UI
**calls the REST API over loopback HTTP** through shared typed clients. The whole client layer lives
in **`src/platform/common/mix.ui.shared/Services`** and is consumed by both `mix.cloud.ui` and
`mix.admin.ui`.

> Canonical reference impl: `FlowsApiClient` (`mix.ui.shared/Services/FlowsApiClient.cs`). Copy its
> shape for any new data-loading client.

## The layer (all in `mix.ui.shared/Services`)

- **`I*ApiClient`** interfaces — the UI depends on these, never on `IMediator`/a service/`DbContext`.
  Methods return **`ApiResult<T>`** (`{ bool Success; T? Data; string? Error }`) or `ApiResult` for
  void — uniform, and they **never throw**.
- **`LoopbackApiClient`** base — owns the plumbing every client used to repeat:
  `protected HttpClient Http`, `Json(body)`, and `GetJsonAsync<T>(url, map, ct)` /
  `SendAsync(verb, call)` / `SendJsonAsync<T>(verb, call, map, ct)` (each wraps try/catch →
  `ApiResult.Fail`). A derived client adds only its routes + response mapping.
- **`Http*ApiClient`** impls — extend `LoopbackApiClient`, call the REST endpoint via the per-circuit
  **`ILocalApiClient`** (bearer token + silent refresh wired in). `Program.cs` binds these co-hosted.
- **`ILocalApiClient` + token plumbing** in `Services/Http/` (`LocalApiClient`, `RefreshTokenHandler`,
  `ICloudTokenAccessor`, `ITokenRenewer`, `HttpTokenRenewer`).

## The rule

1. **A REST controller must exist for every section's data.** If missing, create it (`[ApiController]
   [Authorize]`, inherit `TenantControllerBase`/`CrudControllerBase`/`ReadOnlyControllerBase`). This
   is the headless contract the loopback client AND an external SPA both consume.
2. **The section injects an `I*ApiClient`** and reads `res.Success ? res.Data : res.Error`.
3. **Author the client as `Http*ApiClient : LoopbackApiClient(localApi), I*ApiClient`** in
   `mix.ui.shared/Services` (FlowsApiClient pattern). For `/api/v1/rest/*` CRUD controllers the list
   endpoint returns `PagingResponseModel<TView>` — unwrap `"items"`. `GetByIdAsync` returns `Ok(null)`
   on 404 so a new-item editor shows a fresh draft. Bind it in `Program.cs`.
4. **Tenant is resolved SERVER-SIDE from the signed JWT claim** (`TenantControllerBase` reads the
   `TenantId` claim when no cookie; standalone controllers use `Mix.Lib.Helpers.TenantResolver.Resolve(HttpContext, User)`).
   Loopback Bearer calls carry no tenant cookie — **never** `?? 1`. The client does **not** send tenant
   (the JWT carries it, signed); any `int tenantId` param is kept for source-compat but not sent.
5. **JSON is camelCase + enums-by-name globally** (`Program.cs` `AddNewtonsoftJson` sets a
   `CamelCaseNamingStrategy` ContractResolver, `ProcessDictionaryKeys=false`/`OverrideSpecifiedNames=false`,
   plus a `StringEnumConverter`). So a controller may return ViewModels/entities raw — no hand-rolled
   DTO needed for casing. (Read by `JObject`/`JToken` or `JsonConvert.DeserializeObject`, which is
   case-insensitive.)

## Why loopback is safe co-hosted (the deadlock is RESOLVED)

The old "a co-hosted Blazor Server circuit calling its own Kestrel over loopback deadlocks" rule no
longer holds. It was the old blocking/self-renew design, fixed by: (a) a fully-async
`RefreshTokenHandler` (no `.Result`/`.Wait()`, single-flight `SemaphoreSlim`); (b) the co-hosted host
binds **`InProcessTokenRenewer`** so 401-retry renews in-process and never recurses over the loopback
socket (`HttpTokenRenewer` is standalone-only); (c) a **scoped per-circuit `LocalApiClient`** (fresh
handler, no pooled-handler token leak). Verified live at `/p`.

`InProcess*ApiClient` transports were removed except where no REST endpoint exists yet
(`MixDbSchema`, `MixDbData`, `TenantAdmin`) plus `InProcessTokenRenewer`/`InProcessMixLogTransport`.
The read-only CMS InProcess classes were stripped to **static read-engines**
(`InProcessXxxApiClient.QueryXxxAsync`) still called in-process by their REST controllers.

## 🚨 Circuit-init token-timing gotcha

`OnInitializedAsync` runs **before** `OnParametersSet`. If a component seeds the per-circuit token
(`ICloudTokenAccessor`) in `OnParametersSet` but calls a loopback client in `OnInitializedAsync`, the
call goes out unauthenticated → 401 → (a throwing client) terminates the circuit. **Seed the token at
the top of `OnInitializedAsync`** before any init-time loopback call, and **guard init loads** (clients
return `ApiResult` and don't throw, but still fail safe to empty). This bit `CloudDashboard` +
`GlobalAiChatPanel` during the CMS loopback flip.

## Checklist when adding/refactoring a data-loading section

- [ ] REST controller exists (create if missing); resolves tenant from the JWT claim (no `?? 1`).
- [ ] `I*ApiClient` interface in `mix.ui.shared/Services`, returning `ApiResult<T>`.
- [ ] `Http*ApiClient : LoopbackApiClient(localApi), I*ApiClient` (FlowsApiClient pattern); bound in `Program.cs`.
- [ ] Section injects `I*ApiClient` — **not** `IMediator`/service/`DbContext` — and reads `res.Success/.Data/.Error`.
- [ ] Token seeded before any `OnInitializedAsync` loopback call; init loads fail safe.
- [ ] Co-hosted smoke test at `/p`: section renders rows, **no SignalR "Server timeout"**, no server "Unhandled exception in circuit".

## Anti-patterns (rejected in review)

- ❌ Section injects `IMediator`/`CrudService`/`DbContext` and loads data with no REST endpoint behind it.
- ❌ Controller resolves tenant with `?? 1` (loopback Bearer has no cookie → wrong-tenant leak; use the JWT claim).
- ❌ Loopback client throws on error (crashes the circuit) instead of returning `ApiResult.Fail`.
- ❌ A loopback call in `OnInitializedAsync` before the per-circuit token is seeded.
- ❌ Sending tenant from the client (redundant + spoofable — the signed JWT carries it).

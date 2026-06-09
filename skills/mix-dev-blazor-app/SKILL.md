---
name: mix-dev-blazor-app
description: Scaffold, modify, and reason about Blazor Web Apps in the mixcore-cloud solution — components, pages, services, HttpClient, render modes, routing, standalone-app and MVC-embedded dashboard setup, and Blazor Server tenant isolation. Thin index; loads references/ on demand.
argument-hint: "[new-component|new-page|new-app|add-service|add-step] [name]"
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
  - Edit
  - Write
---

You are helping build **Blazor Web Apps** in the **mixcore-cloud** solution. All paths are relative to the repo root.

---

## Two Blazor patterns in this repo

| Pattern | Where used | Key difference | Reference |
|---------|-----------|----------------|-----------|
| **Standalone Blazor Web App** | `src/apps/` (installation wizard) | Full Blazor Router, `Program.cs` hosts Razor components | [references/standalone-app.md](references/standalone-app.md) |
| **MVC-embedded Blazor module** | `src/modules/*/mix.*.ui/` (admin, cloud dashboards) | `<component>` tag in `.cshtml`, no Blazor Router, `history.pushState` for URL sync | [references/embedded-dashboard.md](references/embedded-dashboard.md) |

**Read the matching reference before starting.** Load it with the `Read` tool.

## References (load on demand)

| File | Read when the task involves… |
|---|---|
| [references/standalone-app.md](references/standalone-app.md) | a standalone Blazor app in `src/apps/` — solution layout, render modes, boilerplate, typed HttpClient, wizard steps |
| [references/embedded-dashboard.md](references/embedded-dashboard.md) | an MVC-embedded dashboard module — catch-all route, `history.pushState`, shell/section structure, cascading nav, code-behind partials |
| [references/tenant-isolation.md](references/tenant-isolation.md) | loading tenant-scoped data in a Blazor **Server** section (`BlazorTenantContext` / `MixSectionContext`) |
| [references/headless-data-loading.md](references/headless-data-loading.md) | loading a section's data through the REST contract (headless), the co-hosted loopback-deadlock caveat + transport abstraction, and 401 refresh-token retry |

The sections below (gotchas, Aspire, CLI, task patterns, data-loading rule, UI rule) apply to **both** patterns — keep them in mind regardless of which reference you load.

---

## Gotchas

### ❌ Never name a Blazor namespace segment `System`

`@using Mix.Cloud.Ui.Components.Sections.System` makes the Razor compiler resolve `System.Collections` as `Mix.Cloud.Ui.Components.Sections.System.Collections` — hundreds of errors. Use `Administration`, `SysAdmin`, etc. instead.

### ❌ `ErrorAlertDialog` is admin-UI-only

`ErrorAlertDialog` lives in `mix.admin.ui/Components/Shared/`. Don't reference it from `mix.cloud.ui`. Replace with:
- `ErrorAlertDialog` → `@if (_showError) { <BbAlert Variant="AlertVariant.Danger" Dismissible OnDismiss="@(() => _showError = false)">@_loadError</BbAlert> }`

`CodeEditorField` is **not** admin-only — it is a **shared** component in `src/platform/common/mix.ui.shared/Components/Shared/CodeEditorField.razor`, so it is usable from `mix.cloud.ui`. If you do want a plain textarea instead, use `<BbTextarea @bind-Value="@_field" Class="font-mono text-sm w-full" />`.

### ❌ Don't use `NavigationManager.NavigateTo()` for in-dashboard navigation

In MVC-embedded Blazor, `NavigationManager.NavigateTo()` triggers a full page reload. Use `history.pushState` (via `JS.InvokeVoidAsync`) to update the URL without re-mounting the component tree.

### ❌ `IHttpContextAccessor` is unreliable after initial render

In Blazor Server, `IHttpContextAccessor.HttpContext` is `null` after the initial render phase. Services that rely on it for tenant resolution (like `DatabaseService.CurrentTenantId`) silently return tenant `1` for all subsequent calls in the circuit. Always use `BlazorTenantContext` in section components — see [references/tenant-isolation.md](references/tenant-isolation.md).

### ⚠️ Full solution build is authoritative for Blazor

When verifying Blazor changes, always build via the solution file:
```bash
dotnet build src/MixCore.Cloud.sln --configuration Release
```
Building a single Blazor `.csproj` directly (`dotnet build src/apps/X/X.csproj`) may report spurious CS0246 errors for types defined in `_Imports.razor` because the Blazor source generator hasn't yet run for dependent projects. The SLN build processes projects in dependency order and eliminates this race.

### ✅ `IAsyncDisposable` when using `DotNetObjectReference`

Any component that creates a `DotNetObjectReference` for JS interop must implement `IAsyncDisposable`, not `IDisposable`:

```csharp
// In .razor: @implements IAsyncDisposable
public async ValueTask DisposeAsync()
{
    Theme.OnThemeChanged -= OnThemeChanged;   // also unsubscribe events
    try { await JS.InvokeVoidAsync("myCleanupFn"); } catch { }
    _dotNetRef?.Dispose();
}
```

---

## Aspire service discovery

```csharp
// appsettings.json
{ "SomeApi": { "BaseUrl": "https+http://some-service-name" } }

// appsettings.Development.json
{ "SomeApi": { "BaseUrl": "http://localhost:5059" } }
```

Register in `src/host/mixcore.host/AppHost.cs`:

```csharp
var api = builder.AddProject<Projects.Mix_Api>("some-service-name");
var ui  = builder.AddProject<Projects.YourApp>("your-app-name").WithReference(api);
```

---

## CLI commands

```bash
# Scaffold standalone Blazor Web App
dotnet new blazor -n YourApp --interactivity Server --framework net10.0 -o src/apps/YourApp

# Add to solution
dotnet sln src/MixCore.Cloud.sln add src/apps/YourApp/YourApp.csproj

# Add project reference
dotnet add src/apps/YourApp/YourApp.csproj reference src/modules/mix.lib/mix.lib.csproj

# Run standalone
dotnet run --project src/apps/YourApp

# Run under Aspire
dotnet run --project src/host/mixcore.host
```

---

## Common task patterns

| User asks to… | Pattern |
|---|---|
| "create a Blazor app" | Scaffold with `dotnet new blazor`, add to sln, wire Program.cs with Aspire defaults + typed HttpClient (references/standalone-app.md) |
| "add a Blazor component" | Create `.razor` in `Components/` with `[Parameter]` contract, `type="button"` buttons |
| "add a wizard step" | Follow the 7-step checklist in references/standalone-app.md (Pattern A) |
| "add a service / API client" | Typed `HttpClient` class in `Services/` using `ApiResult` pattern (references/standalone-app.md); for a portal/admin **section's data**, follow the headless data-loading rule below (references/headless-data-loading.md) |
| "load data in a portal/admin section" | REST controller (create if missing) + `IXxxApiClient` with in-process & HTTP impls; **never** inject `IMediator`/service/`DbContext` straight into the section (references/headless-data-loading.md) |
| "add a section to the dashboard" | Create `.razor` + `.razor.cs` partial pair in `Sections/{Group}/`, add `CloudNavContext? NavContext` cascading param, add route to `_validRoutes`, add `else if` case in shell, add sidebar item (references/embedded-dashboard.md) |
| "wire URL routing to dashboard" | `history.pushState` in Navigate/NavigateToDetail, `[JSInvokable] HandlePopState`, global functions in `site.js`, `{**id}` catch-all route in MVC controller (references/embedded-dashboard.md) |
| "embed Blazor inside MVC" | Register `AddRazorComponents().AddInteractiveServerComponents()` in `Program.cs`, `app.MapRazorComponents<App>()`, render with `<component type="..." render-mode="Server" />` in `.cshtml` (references/embedded-dashboard.md) |

---

## Headless Data-Loading Rule

**Mixcore is a headless CMS: every portal/admin section's data MUST be reachable through the REST
API contract — not loaded only by injecting `IMediator` / a service / `DbContext` straight into the
section.** If a section has no backing endpoint, **create the controller** (`[ApiController]
[Authorize]`, `mix.lib` base controller, **camelCase** anonymous DTOs — raw ViewModels serialize
PascalCase and render blank).

But **never let a co-hosted Blazor Server circuit call its own Kestrel over loopback HTTP — it
deadlocks the circuit** (→ SignalR "Server timeout"). Reconcile both with the **transport
abstraction**: the UI depends on an `IXxxApiClient` interface with **two** impls — `InProcessXxx`
(MediatR/service, co-hosted **default**) and `HttpXxx` (`"LocalApi"`, separate-process). This
mirrors the shipped `IMixLogTransport` → `InProcessMixLogTransport` / `HttpMixLogTransport`.

**Every HTTP data call retries once on `401` by refreshing the access token** — the
`HttpClient`/XHR analogue of `AdminTokenHelper` (which only covers browser-navigation 401s).
Register the (currently unregistered) `"LocalApi"` client with a single-flight `RefreshTokenHandler`
`DelegatingHandler`; do not mutate the shared client's `DefaultRequestHeaders`.

**Read [references/headless-data-loading.md](references/headless-data-loading.md) before adding or
refactoring any section that loads data** — it has the full pattern, the `Program.cs` wiring, the
refresh-handler design, and the add-a-section checklist.

---

## UI Design Rule

**Whenever you generate OR update any Blazor UI, you MUST invoke the `frontend-design` skill _before_ writing or changing markup/CSS.** This is non-negotiable and applies equally to brand-new components and to edits/redesigns/cleanups of existing ones.

```
Skill("frontend-design:frontend-design")  ← always before writing OR editing UI code
```

Trigger on: "create a component", "add a page", "redesign", "clean up UI", "improve the look", "review the UI", "polish", any task that results in new or changed `.razor` markup or `.css` rules.

### Pick the surface first — it decides how `frontend-design` applies

`frontend-design` optimizes for distinctive, memorable aesthetics. That is right for **public surfaces** and wrong for **admin surfaces**, where consistency is the quality bar. Decide which you're touching:

| Surface | Where | How to apply `frontend-design` |
|---|---|---|
| **Admin / portal / dashboard** | `mix.cloud.ui`, `mix.admin.ui`, embedded dashboards, settings/section components | Apply its quality lens **through the existing BlazorBlueprint / shadcn design system.** Consistency with sibling sections IS the design — reuse the native components and tokens, do not hand-roll. |
| **Public / marketing / auth landing** | landing page, signup/login layouts, standalone marketing pages | Full creative latitude — commit to a distinctive identity (fonts, accent, motion). |

> ⚠️ Do **not** hand-roll UI that the component library already provides. In admin/portal work, "deliberate design" means choosing the right **BlazorBlueprint** primitive and matching the surrounding sections — not inventing custom chrome. Custom `fixed inset-0` modals, raw `<input>/<select>/<table>`, and "Yes/No" text instead of badges read as off-house-style and get rejected in review. Before building, grep a sibling section for the idiom and reuse it:
> - Modal/editor → `BbDialog` (`BbDialogContent/Header/Title/Footer/Close`); destructive confirm → `BbAlertDialog`
> - Form controls → `BbInput` / `BbSelect` / `BbSwitch` / `BbCheckbox` / `BbLabel` (not raw HTML inputs)
> - Status & tags → `BbBadge` (`BadgeVariant.*`); framing → `BbCard`; tables → existing table idiom
> - Only the **prebuilt** Tailwind utilities exist (no JIT build): `grid-cols-1/2`, `sm:grid-cols-2`, plus `grid-cols-3/4` patched in `cloud.css`. **Arbitrary values like `sm:grid-cols-[120px_1fr_1fr]` silently never apply** — use a shipped utility or add the rule to `cloud.css`.

After the skill loads:
1. Confirm the surface (table above). For admin/portal: survey 1–2 sibling sections and reuse their BlazorBlueprint components and layout. For public: commit to a clear aesthetic direction (dark/light, accent color, font pairing).
2. Write any CSS classes needed **before** the Razor markup that uses them; verify each utility class actually exists in the shipped CSS.
3. Scope custom styles to the component — use a wrapper class (e.g. `.su-card`, `.signup-page`) to avoid leaking into the rest of the app.
4. For login/signup layouts: styles go in `wwwroot/css/cloud.css` (append a named section); layout-level changes (fonts, body background) go in the relevant `_Layout.cshtml` inline `<style>` block.
5. Build and verify before committing.

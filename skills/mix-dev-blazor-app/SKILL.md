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

The sections below (gotchas, Aspire, CLI, task patterns, UI rule) apply to **both** patterns — keep them in mind regardless of which reference you load.

---

## Gotchas

### ❌ Never name a Blazor namespace segment `System`

`@using Mix.Cloud.Ui.Components.Sections.System` makes the Razor compiler resolve `System.Collections` as `Mix.Cloud.Ui.Components.Sections.System.Collections` — hundreds of errors. Use `Administration`, `SysAdmin`, etc. instead.

### ❌ `ErrorAlertDialog` and `CodeEditorField` are admin-UI-only

These components live in `mix.admin.ui/Components/Shared/`. Don't reference them from `mix.cloud.ui`. Replace with:
- `ErrorAlertDialog` → `@if (_showError) { <BbAlert Variant="AlertVariant.Danger" Dismissible OnDismiss="@(() => _showError = false)">@_loadError</BbAlert> }`
- `CodeEditorField` → `<BbTextarea @bind-Value="@_field" Class="font-mono text-sm w-full" />`

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

Register in `src/mixcore.host/Program.cs`:

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
dotnet sln src/mixcore.sln add src/apps/YourApp/YourApp.csproj

# Add project reference
dotnet add src/apps/YourApp/YourApp.csproj reference src/modules/mix.lib/mix.lib.csproj

# Run standalone
dotnet run --project src/apps/YourApp

# Run under Aspire
dotnet run --project src/mixcore.host
```

---

## Common task patterns

| User asks to… | Pattern |
|---|---|
| "create a Blazor app" | Scaffold with `dotnet new blazor`, add to sln, wire Program.cs with Aspire defaults + typed HttpClient (references/standalone-app.md) |
| "add a Blazor component" | Create `.razor` in `Components/` with `[Parameter]` contract, `type="button"` buttons |
| "add a wizard step" | Follow the 7-step checklist in references/standalone-app.md (Pattern A) |
| "add a service / API client" | Typed `HttpClient` class in `Services/` using `ApiResult` pattern (references/standalone-app.md) |
| "add a section to the dashboard" | Create `.razor` + `.razor.cs` partial pair in `Sections/{Group}/`, add `CloudNavContext? NavContext` cascading param, add route to `_validRoutes`, add `else if` case in shell, add sidebar item (references/embedded-dashboard.md) |
| "wire URL routing to dashboard" | `history.pushState` in Navigate/NavigateToDetail, `[JSInvokable] HandlePopState`, global functions in `site.js`, `{**id}` catch-all route in MVC controller (references/embedded-dashboard.md) |
| "embed Blazor inside MVC" | Register `AddRazorComponents().AddInteractiveServerComponents()` in `Program.cs`, `app.MapRazorComponents<App>()`, render with `<component type="..." render-mode="Server" />` in `.cshtml` (references/embedded-dashboard.md) |

---

## UI Design Rule

**Whenever creating or significantly modifying Blazor UI**, invoke the `frontend-design` skill **before writing any markup or CSS**. The skill determines the aesthetic direction, component structure, and CSS approach. Do not default to generic BlazorBlueprint defaults — every user-facing UI should have a deliberate visual identity.

Trigger on: "create a component", "add a page", "redesign", "clean up UI", "improve the look", "review the UI", any task that results in new or changed `.razor` markup or `.css` rules.

```
Skill("frontend-design:frontend-design")  ← always before writing UI code
```

After the skill loads:
1. Commit to a clear aesthetic direction (dark/light, accent color, font pairing).
2. Write the CSS classes needed **before** the Razor markup that uses them.
3. Scope styles to the component — use a wrapper class (e.g. `.su-card`, `.signup-page`) to avoid leaking into the rest of the app.
4. For login/signup layouts: styles go in `wwwroot/css/cloud.css` (append a named section); layout-level changes (fonts, body background) go in the relevant `_Layout.cshtml` inline `<style>` block.
5. Build and verify before committing.

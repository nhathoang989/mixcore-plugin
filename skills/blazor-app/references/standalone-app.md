# mixcore:blazor-app · Pattern A — Standalone Blazor Web App

Loaded by `mixcore:blazor-app` for **standalone** Blazor Web Apps (`src/apps/`, e.g. the installation wizard): solution layout, target framework, render modes, file layout, boilerplate, RCL static assets, the typed HttpClient pattern, and the wizard step-component pattern. Pair with [embedded-dashboard.md](embedded-dashboard.md) (MVC-embedded modules) and [tenant-isolation.md](tenant-isolation.md) (Blazor Server tenant pinning).

---

## Pattern A — Standalone Blazor Web App

### Solution layout

```
src/
├── apps/
│   └── MixCore.Cloud.Web/               # Main ASP.NET Core 10 MVC + Blazor host
├── modules/
│   └── installation/
│       ├── mix.installation.lib/        # Business logic (IInitCmsService, InitCmsService)
│       └── mix.installation.api/        # Standalone REST API (InitCmsController)
├── platform/
│   └── common/
│       ├── mix.shared/                  # DTOs, AppSettingServiceBase<T>
│       └── mixcore.aspire.service/      # AddServiceDefaults / MapDefaultEndpoints
└── host/
    └── MixCore.Cloud.Host/              # .NET Aspire orchestrator (local dev only)
```

The canonical Blazor reference is the **installation wizard** — study its patterns before adding any new Blazor code.

### Target framework & compiler settings

```xml
<Project Sdk="Microsoft.NET.Sdk.Web">
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
  </PropertyGroup>
</Project>
```

### Render modes

| Scenario | Attribute |
|----------|-----------|
| Full interactivity (default for wizard pages) | `@rendermode InteractiveServer` |
| Static page (no interactivity) | *(no attribute)* |
| Interactive with pre-render disabled | `@rendermode new InteractiveServerRenderMode(prerender: false)` |

Apply at **page level** (not in `App.razor`) to keep control granular.

### Standard file layout

```
src/apps/YourApp/
├── Components/
│   ├── Steps/           # Step wizard components (if applicable)
│   └── Shared/          # Reusable UI fragments
├── Layouts/
│   └── MainLayout.razor
├── Models/
│   └── AppModels.cs     # All local enums, models, and view models
├── Pages/
│   └── Index.razor      # Main orchestrator page — @page "/"
├── Services/
│   └── SomeApiClient.cs # Typed HttpClient (one class per external API)
├── wwwroot/
│   └── css/app.css
├── App.razor            # HTML document root + HeadOutlet
├── Routes.razor         # <Router> wrapper
├── _Imports.razor       # Global @using directives
├── Program.cs
└── YourApp.csproj
```

### Boilerplate files

**`App.razor`**

```razor
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8" />
    <title>Your App</title>
    <HeadOutlet />
    <link rel="stylesheet" href="css/app.css" />
</head>
<body>
    <Routes />
    <script src="_framework/blazor.web.js"></script>
</body>
</html>
```

**`_Imports.razor`**

```razor
@using System.Net.Http
@using Microsoft.AspNetCore.Components
@using Microsoft.AspNetCore.Components.Forms
@using Microsoft.AspNetCore.Components.Routing
@using Microsoft.AspNetCore.Components.Web
@using Microsoft.AspNetCore.Components.Web.Virtualization
@using YourApp.Components
@using YourApp.Models
@using YourApp.Services
```

**`Program.cs`**

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.AddServiceDefaults();   // Aspire service defaults

builder.Services.AddRazorComponents()
    .AddInteractiveServerComponents();

builder.Services.AddHttpClient<SomeApiClient>(client =>
{
    client.BaseAddress = new Uri(
        builder.Configuration["SomeApi:BaseUrl"] ?? "https+http://some-service");
    client.Timeout = TimeSpan.FromSeconds(60);
});

var app = builder.Build();

app.MapDefaultEndpoints();
app.UseStaticFiles();
app.UseAntiforgery();
app.MapRazorComponents<App>()
   .AddInteractiveServerRenderMode();

app.Run();
```

### Static assets rule (RCL `_content/*`)

Razor Class Library assets (CSS/JS shipped by `mix.ui.shared`, `BlazorBlueprint.Components`, `mix.installation.ui`, etc.) are served at `_content/<PackageId>/…` and referenced from the host layout (`_CloudLayout.cshtml`, `_AiChatLayout.cshtml`, `App.razor`) via `<link>` / `<script>`. Blazor's own boot + asset wiring lives in `_framework/blazor.web.js` (standalone app) or `blazor.server.js` (MVC-hosted component) — it is generated; never hand-edit it.

**The physical asset files must exist under the host's `wwwroot/_content/…`.** In Development, `MapStaticAssets` runs `StaticAssetDevelopmentRuntimeHandler`, which stats every asset **and its precompressed `.gz` / `.br` siblings** at the wwwroot-relative path recorded in the build manifest (`MixCore.Cloud.Web.staticwebassets.endpoints.json`). If a file is missing, that asset returns **HTTP 500 `System.IO.FileNotFoundException`** — not 404 — and any page linking it loads unstyled.

This bites hardest in a **fresh `git worktree`**: a clean checkout has no materialized `_content`, and a partial/incremental build (or hand-wiped `obj/`) leaves the manifest pointing at files that were never copied — so *every* `_content/*` request 500s while MVC/Razor pages still return 200. Fix by materializing the assets into the host `wwwroot/_content/`:

```bash
dotnet publish src/apps/MixCore.Cloud.Web/MixCore.Cloud.Web.csproj -c Debug -o /tmp/pub
cp -R /tmp/pub/wwwroot/_content/. src/apps/MixCore.Cloud.Web/wwwroot/_content/
```

(or just run the app from the main checkout, which already has them). **Do not** hand-delete `obj/**/staticwebassets*` caches and then build a single project — that desynchronizes the per-RCL manifests and reproduces exactly this 500.

### Typed HttpClient pattern

```csharp
// Services/SomeApiClient.cs
public class SomeApiClient(HttpClient http)
{
    public async Task<ApiResult> PostStepAsync(StepDto dto, CancellationToken ct = default)
    {
        try
        {
            var response = await http.PostAsJsonAsync("api/v1/step", dto, ct);
            response.EnsureSuccessStatusCode();
            return ApiResult.Ok();
        }
        catch (Exception ex) { return ApiResult.Fail(ex.Message); }
    }
}

public record ApiResult(bool Success, string? Error = null)
{
    public static ApiResult Ok(object? _ = null) => new(true);
    public static ApiResult Fail(string error)   => new(false, error);
}
```

### Step component pattern

```razor
@* Components/Steps/StepOneComponent.razor *@
<div class="step">
    @if (_errors.Count > 0)
    {
        <ul class="errors">@foreach (var (f, m) in _errors) { <li><strong>@f</strong>: @m</li> }</ul>
    }
    <input type="text" @bind="Model.Name" @bind:event="oninput" />
    <button type="button" @onclick="Submit" disabled="@(Busy || _submitting)">Continue</button>
</div>

@code {
    [Parameter, EditorRequired] public StepOneModel Model { get; set; } = default!;
    [Parameter, EditorRequired] public EventCallback<StepOneModel> OnNext { get; set; }
    [Parameter] public bool Busy { get; set; }

    Dictionary<string, string> _errors = new();
    bool _submitting;

    async Task Submit()
    {
        _errors.Clear();
        if (string.IsNullOrWhiteSpace(Model.Name)) _errors["Name"] = "Required";
        if (_errors.Count > 0) return;
        _submitting = true;
        await OnNext.InvokeAsync(Model);
        _submitting = false;
    }
}
```

**Component contract rules (always follow):**
- All buttons are `type="button"` with `@onclick` — never `<EditForm>` or `type="submit"`.
- `Model` and `OnNext` are always `[EditorRequired]`.
- Validate locally in `Dictionary<string, string> _errors` before calling `OnNext.InvokeAsync`.
- Disable buttons while `Busy` (parent awaiting API) **and** while `_submitting` (component validating).

### Adding a new wizard step — checklist

1. Add enum value to `WizardStep` in `AppModels.cs`
2. Add a model class to `AppModels.cs`
3. Create `Components/Steps/NewStepComponent.razor`
4. Add `case WizardStep.NewStep:` in `Pages/Index.razor`'s `@switch`
5. Add step label to `_stepLabels`
6. Add handler `HandleNewStep(NewStepModel model)` in `Index.razor`
7. Add method to the API client for the new endpoint


# mixcore:mix-dev-blazor-app · Pattern B — MVC-embedded Blazor dashboard module

Loaded by `mixcore:mix-dev-blazor-app` for **MVC-embedded** Blazor modules (`src/modules/*/mix.*.ui/`, e.g. admin & cloud dashboards): the `<component>` tag, catch-all MVC route, `history.pushState` URL sync, shell/section structure, cascading nav context, code-behind partials, folder layout, and shared components. Pair with [standalone-app.md](standalone-app.md) and [tenant-isolation.md](tenant-isolation.md).

---

## Pattern B — MVC-embedded Blazor dashboard module

Used by `mix.admin.ui` (admin panel) and `mix.cloud.ui` (cloud dashboard). No Blazor Router — navigation is managed in-process via a cascading context + `history.pushState`.

### How it works end-to-end

```
Browser URL ──► MVC Controller ──► .cshtml View ──► <component> tag ──► Blazor shell component
     ▲                                                                         │
     └───────────────── history.pushState() ◄────────── Navigate() / NavigateToDetail()
                              │
                   popstate event ──► [JSInvokable] HandlePopState() ──► state rebuild
```

### MVC controller — catch-all route + id parameter

```csharp
[Authorize]
public class CloudController : Controller
{
    [Route("cloud")]
    [Route("cloud/{section}")]
    [Route("cloud/{section}/{subsection}")]
    [Route("cloud/{section}/{subsection}/{**id}")]   // {**id} = catch-all for deep-links
    public IActionResult Index(string? section = null, string? subsection = null, string? id = null)
    {
        ViewData["Section"]    = section    ?? "overview";
        ViewData["SubSection"] = subsection ?? "";
        ViewData["Id"]         = id         ?? "";
        return View();
    }
}
```

### MVC view — pass route parameters to component

```cshtml
@* Views/Cloud/Index.cshtml *@
<component type="typeof(Mix.Cloud.Ui.Components.CloudDashboard)" render-mode="Server"
           param-InitialSection='@(ViewData["Section"] as string ?? "overview")'
           param-InitialSubSection='@(ViewData["SubSection"] as string ?? "")'
           param-InitialId='@(ViewData["Id"] as string ?? "")'
           param-AccessToken="@Context.Request.Cookies["mixcore_access_token"]" />
```

### Shell component structure (CloudDashboard / AdminDashboard)

```csharp
public partial class CloudDashboard : IAsyncDisposable
{
    [Parameter] public string InitialSection    { get; set; } = "overview";
    [Parameter] public string InitialSubSection { get; set; } = "";
    [Parameter] public string InitialId         { get; set; } = "";
    [Parameter] public string? AccessToken      { get; set; }

    [Inject] private IJSRuntime JS { get; set; } = default!;

    private string _activeSection    = "overview";
    private string _activeSubSection = "";
    private string _activeItemId     = "";

    private DotNetObjectReference<CloudDashboard>? _dotNetRef;

    // All valid section/subsection combinations — reject unknown routes
    private static readonly Dictionary<string, HashSet<string>> _validRoutes = new()
    {
        ["overview"] = [""],
        ["data"]     = ["databases", "tables", "table-editor", "table-data", "record-editor"],
        ["content"]  = ["posts", "post-editor", "pages", "page-editor", "modules", "module-editor"],
        // ... add all sections
    };

    protected override async Task OnInitializedAsync()
    {
        var section    = InitialSection.ToLowerInvariant().Trim('/');
        var subSection = InitialSubSection.ToLowerInvariant().Trim('/');
        var id         = InitialId.Trim();

        if (_validRoutes.TryGetValue(section, out var subs) && subs.Contains(subSection))
        {
            _activeSection = section; _activeSubSection = subSection; _activeItemId = id;
        }
        else
        {
            _activeSection = "overview"; _activeSubSection = ""; _activeItemId = "";
        }
        _openGroups.Add(_activeSection);
        RebuildNavContext();
        await Task.CompletedTask;
    }

    protected override async Task OnAfterRenderAsync(bool firstRender)
    {
        if (firstRender)
        {
            _dotNetRef = DotNetObjectReference.Create(this);
            await JS.InvokeVoidAsync("cloudSetupPopState", _dotNetRef);
        }
    }

    public async ValueTask DisposeAsync()
    {
        try { await JS.InvokeVoidAsync("cloudCleanupPopState"); } catch { }
        _dotNetRef?.Dispose();
    }

    // Uses history.pushState — NOT NavigationManager.NavigateTo (that causes full reload)
    private async Task Navigate(string section, string subSection = "")
    {
        _activeSection = section; _activeSubSection = subSection; _activeItemId = "";
        _openGroups.Add(section);
        var url = subSection == "" ? $"/cloud/{section}" : $"/cloud/{section}/{subSection}";
        await JS.InvokeVoidAsync("history.pushState", null, "", url);
        RebuildNavContext();
        StateHasChanged();
    }

    private async Task NavigateToDetail(string section, string subSection, string itemId)
    {
        _activeSection = section; _activeSubSection = subSection; _activeItemId = itemId;
        _openGroups.Add(section);
        var url = $"/cloud/{section}/{subSection}/{itemId}";
        await JS.InvokeVoidAsync("history.pushState", null, "", url);
        RebuildNavContext();
        StateHasChanged();
    }

    [JSInvokable]
    public Task HandlePopState(string path)
    {
        var rel = path.TrimStart('/');
        if (rel.StartsWith("cloud/", StringComparison.OrdinalIgnoreCase))
            rel = rel["cloud".Length..].TrimStart('/');

        var parts      = rel.Split('/', StringSplitOptions.RemoveEmptyEntries);
        var section    = parts.Length > 0 ? parts[0] : "overview";
        var subSection = parts.Length > 1 ? parts[1] : "";
        var itemId     = parts.Length > 2 ? string.Join("/", parts.Skip(2)) : "";

        if (_validRoutes.TryGetValue(section, out var subs) && subs.Contains(subSection))
        {
            _activeSection = section; _activeSubSection = subSection; _activeItemId = itemId;
        }
        else { _activeSection = "overview"; _activeSubSection = ""; _activeItemId = ""; }

        _openGroups.Add(_activeSection);
        RebuildNavContext();
        StateHasChanged();
        return Task.CompletedTask;
    }
}
```

### JS popstate bridge — in `wwwroot/js/site.js` (NOT a colocated .razor.js)

```js
// Global functions — NOT ES module exports
window.cloudSetupPopState = function (dotNetRef) {
    window._cloudNavDotNet = dotNetRef;
    window._cloudPopStateHandler = function () {
        window._cloudNavDotNet.invokeMethodAsync('HandlePopState', window.location.pathname);
    };
    window.addEventListener('popstate', window._cloudPopStateHandler);
};

window.cloudCleanupPopState = function () {
    if (window._cloudPopStateHandler)
        window.removeEventListener('popstate', window._cloudPopStateHandler);
    window._cloudNavDotNet = null;
};
```

> **Why `site.js` not `.razor.js`?** Colocated `.razor.js` files are ES modules — `JS.InvokeVoidAsync("fnName", ...)` expects global window functions, not module exports. Put global helpers in `site.js`.

### Cascading navigation context pattern

```csharp
// The context is an immutable record — rebuilt on every navigation
public sealed class CloudNavContext
{
    public string ActiveSection    { get; init; } = "";
    public string ActiveSubSection { get; init; } = "";
    public string ActiveItemId     { get; init; } = "";
    public string WorkspaceName    { get; init; } = "";

    public Func<string, string, Task>         Navigate         { get; init; } = (_, _) => Task.CompletedTask;
    public Func<string, string, string, Task> NavigateToDetail { get; init; } = (_, _, _) => Task.CompletedTask;
    public Action<string, string?, ToastVariant> ShowToast     { get; init; } = (_, _, _) => { };
}

// Shell rebuilds context after every state change
private void RebuildNavContext()
{
    _navContext = new CloudNavContext
    {
        ActiveSection    = _activeSection,
        ActiveSubSection = _activeSubSection,
        ActiveItemId     = _activeItemId,
        WorkspaceName    = _workspaceName,
        Navigate         = Navigate,
        NavigateToDetail = NavigateToDetail,
        ShowToast        = (title, desc, v) => Toast.Show(desc ?? "", title, v),
    };
}
```

**In child section components:**

```csharp
[CascadingParameter] private CloudNavContext? NavContext { get; set; }

// Navigate back to list
private void GoBack() => _ = NavContext?.Navigate("content", "posts");

// Navigate to an editor
private void OpenEditor(int id) => _ = NavContext?.NavigateToDetail("content", "post-editor", id.ToString());
```

### Code-behind (partial class) pattern for section components

Split complex section components into `.razor` + `.razor.cs`:

```csharp
// CmsPostsSection.razor.cs
public partial class CmsPostsSection
{
    [CascadingParameter] private CloudNavContext?     NavContext  { get; set; }
    [CascadingParameter] private MixSectionContext?   Section     { get; set; }
    [Inject] private PostContentService PostService   { get; set; } = default!;
    [Inject] private BlazorTenantContext _tenantCtx   { get; set; } = default!;

    private List<PostRow> _filtered = [];
    private int _lastTenantId;  // dedup guard: skip re-load when tenant unchanged

    protected override async Task OnParametersSetAsync()
    {
        var tid = Section?.TenantId ?? _tenantCtx.TenantId;  // NEVER ?? 1
        if (tid == _lastTenantId) return;
        _lastTenantId = tid;
        PostService.SetTenantId(tid);
        await LoadAsync();
    }

    private async Task LoadAsync() { /* ... */ }
}
```

```razor
@* CmsPostsSection.razor — pure markup, no @code block *@
<div class="flex flex-1 flex-col gap-4">
    <BbDataTable TData="PostRow" Data="@_filtered" ShowToolbar ShowPagination>
        <Columns>
            <BbDataTableColumn TData="PostRow" TValue="string" Property="@(x => x.Title)" Header="Title">
                <CellTemplate Context="row">
                    <button @onclick="@(() => NavContext?.NavigateToDetail("content","post-editor",row.Id.ToString()))">
                        @row.Title
                    </button>
                </CellTemplate>
            </BbDataTableColumn>
        </Columns>
    </BbDataTable>
</div>
```

### Folder structure for Blazor modules

Organize sections into semantic subdirectories — one namespace per group:

```
Components/
├── CloudDashboard.razor          # Shell — sidebar + section router
├── CloudDashboard.razor.cs
├── CloudNavContext.cs            # Cascading context
├── MetricCard.razor              # Reusable sub-components (no subdirectory)
└── Sections/
    ├── Content/                  # mix.cloud.ui.Components.Sections.Content
    │   ├── CmsPostsSection.razor
    │   ├── CmsPostsSection.razor.cs
    │   └── CmsPostEditorSection.razor
    ├── Data/
    ├── AI/
    └── Administration/           # ⚠️ NOT "System" — see gotchas below
```

**`_Imports.razor`** must include a `@using` per subdirectory:

```razor
@using Mix.Cloud.Ui.Components.Sections.Content
@using Mix.Cloud.Ui.Components.Sections.Data
@using Mix.Cloud.Ui.Components.Sections.Administration
```

### Global usings in `.csproj` for code-behind files

`.razor.cs` partial-class files don't get the Razor source generator's auto-usings. Add them explicitly in `.csproj`:

```xml
<ItemGroup>
  <Using Include="Microsoft.AspNetCore.Components" />
  <Using Include="Microsoft.AspNetCore.Components.Web" />
  <Using Include="Microsoft.AspNetCore.Components.Forms" />
  <Using Include="BlazorBlueprint.Components" />
  <!-- plus any domain namespace used across many files -->
</ItemGroup>
```

Without this, `[Parameter]`, `EventCallback<>`, and `ChangeEventArgs` won't resolve in `.razor.cs` files.

### Shared components across modules → mix.ui.shared

Components used by both `mix.admin.ui` AND `mix.cloud.ui` belong in `mix.ui.shared/Components/{Category}/`:

```
platform/common/mix.ui.shared/
└── Components/
    ├── AI/
    │   └── LlmCredentialsEditor.razor     # existing
    ├── Shared/                            # JS-interop field editors (one .razor + colocated .razor.js)
    │   ├── CodeEditorField.razor          # Monaco code editor
    │   ├── HtmlWysiwygField.razor         # Quill WYSIWYG (Html columns)
    │   └── MarkdownEditorField.razor      # Toast-UI markdown (TuiEditor columns)
    ├── Services/
    │   └── MediaUploadClient.cs           # IMediaUploadClient → POST /api/v1/vault/objects/upload
    └── MixDb/
        ├── DynamicColumnEditor.razor      # per-MixDataType field renderer (rich editors + file upload)
        └── ColumnEditorRow.razor          # column schema row
```

Add the reference to any consuming module's `.csproj`:
```xml
<ProjectReference Include="..\..\..\platform\common\mix.ui.shared\mix.ui.shared.csproj" />
```

### JS-interop editors — load order, globals, disposal

The editor fields wrap third-party JS via a colocated ES-module `.razor.js`, imported as
`./_content/mix.ui.shared/Components/Shared/<Name>.razor.js` with `init`/`setValue`/`dispose`
and an `[JSInvokable] OnValueChanged` callback (mirror `CodeEditorField`). Each implements
`IAsyncDisposable` and calls the JS `dispose`.

🚨 **CRITICAL — UMD editor bundles must load BEFORE Monaco's AMD loader.** Quill and Toast-UI
are UMD bundles; Monaco's `loader.min.js` installs an AMD `define.amd`. If a UMD bundle loads
*after* the Monaco loader it registers as an anonymous AMD module, Monaco rejects it
(`Can only have one anonymous define call per script file`), and `window.Quill` / `window.toastui`
never bind → the component's `init()` throws → **the Blazor circuit terminates**. In
`_BlazorAdminLayout.cshtml` put the Quill/Toast-UI `<script>` tags *above* the Monaco loader.

- **Both host layouts.** Shared MixDb editors render in `mix.admin.ui` (`/a`, `_BlazorAdminLayout.cshtml`)
  AND `mix.cloud.ui` (`/p`, `_CloudLayout.cshtml`) — add the editor `<link>`/`<script>` to **both**, or the
  feature silently breaks on one host. `_CloudLayout` has no Monaco loader, so order is moot there.
- **Guard the global.** Start `init()` with `if (typeof Quill === 'undefined') { /* textarea fallback */ return; }`
  so a blocked/air-gapped CDN degrades instead of crashing the circuit.
- **Verify in a browser** — a clean `dotnet build` never catches an AMD/UMD load-order break.

### File upload from a shared component (Vault)

`mix.ui.shared` (platform/common) must **not** reference a cloud pillar, so it cannot DI `VaultService`.
Upload over HTTP instead:

- `MixSectionContext(int TenantId, string? AccessToken = null)` is cascaded `IsFixed` by both dashboards
  (token read from the `mixcore_access_token` cookie via the host `.cshtml` → dashboard `AccessToken` param).
- `MediaUploadClient` (the `FlowsApiClient` idiom: `IHttpClientFactory.CreateClient("LocalApi")` +
  `NavigationManager.BaseUri`) sets the **`Bearer` header explicitly** — a server→server loopback POST does
  **not** carry the auth cookie, so a null token → 401.
- Parse the response with `JObject` (tolerate `url`/`Url`); never reference the Vault `FileUploadResultDto`.
- `IBrowserFile.OpenReadStream` is forward-only — buffer to a `MemoryStream` so `HttpClient` can set `Content-Length`.

### Edit↔view toggle for stateful JS editors

A Toast-UI editor and its viewer are **distinct instances** that cannot swap mode in place; `ReadOnly`
is only read in `init()`. When a field is rendered in a single branch with `ReadOnly="@IsReadOnly"`,
`@key` it on the mode (e.g. `@key="@($"md-{IsReadOnly}")"`) so flipping edit↔view recreates the instance.
(Quill columns instead use separate `@if (IsReadOnly)` branches, so they recreate naturally.)


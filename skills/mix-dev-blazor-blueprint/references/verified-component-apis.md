# Verified BlazorBlueprint Component APIs (this repo)

These are the exact component usages **confirmed by grepping `src/modules/**/*.razor`** in this
repo. The live docs at blazorblueprintui.com are the upstream source of truth, but the patterns
below are what actually compiles and matches existing conventions here. When they disagree with a
guess, trust these — they were derived from working code.

## Overlays → both `BbSheet` (side drawers) and `BbDialog` (centered modals) are used

Both are in active use: `BbSheet` for **side drawers / slide-out create-edit forms**, and `BbDialog`
(`BbDialogContent` / `BbDialogHeader` / `BbDialogTitle` / `BbDialogDescription` / `BbDialogFooter` /
`BbDialogClose`) for **centered modal dialogs**. `BbDialog` is used in
`mix.cloud.ui/Components/Sections/Network/RouteEditorDialog.razor`, with a `<BbDialogProvider />`
rendered once in `mix.cloud.ui/Components/CloudDashboard.razor` (alongside `<BbPortalHost />`). Pick
`BbSheet` for a side drawer, `BbDialog` for a centered modal.

`BbSheet`, controlled (programmatic open, e.g. opened from a row action):

```razor
<BbSheet Open="@_open" OpenChanged="@(v => { if (!v) Close(); })">   @* or @bind-Open *@
    <BbSheetContent Side="SheetSide.Right" Class="w-[30rem] sm:w-[40rem] flex flex-col">
        <BbSheetHeader>
            <BbSheetTitle>Title</BbSheetTitle>
            <BbSheetDescription>Subtitle</BbSheetDescription>
        </BbSheetHeader>
        <div class="flex flex-col gap-4 p-4 overflow-y-auto flex-1">
            @* body *@
        </div>
        <BbSheetFooter Class="p-4 border-t">
            <BbButton @onclick="SaveAsync">Save</BbButton>          @* validate before closing *@
            <BbSheetClose AsChild><BbButton Variant="ButtonVariant.Ghost">Cancel</BbButton></BbSheetClose>
        </BbSheetFooter>
    </BbSheetContent>
</BbSheet>
```

`OpenChanged` fires with `false` when the user dismisses via overlay/escape — route that to your
close handler so parent state stays in sync. Requires `<BbPortalHost />` in the layout (already
present in dashboard layouts).

Reference files: `mix.admin.ui/Components/Projects/{IssuesSection,GoalsSection,KanbanSection}.razor`,
`mix.cloud.ui/Components/Sections/Data/CmsDomainsSection.razor`,
`mix.cloud.ui/Components/Sections/Automation/{FlowsSection,FlowEditSection,FlowRunHistorySection}.razor`.
For `BbDialog`: `mix.cloud.ui/Components/Sections/Network/RouteEditorDialog.razor`.

## `BbSelect` is compositional

Not a simple bound list — it needs the trigger/value/content/item parts:

```razor
<BbSelect TValue="string" @bind-Value="_x">      @* or Value="@_x" ValueChanged="OnChanged" to intercept *@
    <BbSelectTrigger TValue="string">
        <BbSelectValue Placeholder="Select…" />
    </BbSelectTrigger>
    <BbSelectContent>
        <BbSelectItem Value="@("Foo")">Foo label</BbSelectItem>
    </BbSelectContent>
</BbSelect>
```

## `BbSwitch` uses `Checked` / `CheckedChanged` (and `@bind-Checked`)

NOT `Value`/`ValueChanged`. Use either the explicit pair or the `@bind-Checked` shorthand —
**both are valid and in use** (`@bind-Checked` is used in `PostEditorSection.razor`,
`PageEditorSection.razor`, and `ThemeImportCombinedStep.razor`):

```razor
<BbSwitch Checked="@x" CheckedChanged="@(v => x = v)" />   @* explicit *@
<BbSwitch @bind-Checked="@x" />                            @* shorthand — equivalent *@
```

## Other confirmed forms

- `BbTextarea` → `@bind-Value` + `Rows` (optionally `@bind-Value:event="oninput"`).
- `BbBadge` → `Variant=BadgeVariant.{Default,Destructive,Outline,Secondary}` only.
- `BbDataTable` / `BbDataTableColumn` (`TData`/`TValue`/`Property`/`Header`/`Sortable`/`Filterable`,
  `<CellTemplate>` exposes the row as `context`): see `Components/Sections/Data/DatabasesSection.razor`.
  (Note: this is `BbDataTable`, distinct from the enterprise `BbDataGrid` shown in SKILL.md's layout sample.)

## Inline `@code` blocks need their own `@using`

`_Imports.razor` includes `BlazorBlueprint.Components` but **not Newtonsoft.Json**. A `.razor` with an
inline `@code` block that uses `JObject`/`JArray`/`JsonConvert` must add at the top:

```razor
@using Newtonsoft.Json
@using Newtonsoft.Json.Linq
```

Otherwise you get `CS0103: JObject does not exist` — which cascades into misleading `StringContent`
overload errors because the affected variables become error-typed. (Code-behind `.razor.cs` files
declare their usings normally and don't hit this.)

## Calling the local REST API from a section

MVC-embedded Blazor has no pre-configured `BaseAddress`. Use the `"LocalApi"` named client and add
the Bearer token from `CloudNavContext.AccessToken`:

```csharp
var http = HttpFactory.CreateClient("LocalApi");
http.BaseAddress ??= new Uri(Navigation.BaseUri);
if (!string.IsNullOrEmpty(NavContext?.AccessToken))
    http.DefaultRequestHeaders.Authorization =
        new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", NavContext.AccessToken);
```

Controller responses serialize enums as **integers** (the host's `AddNewtonsoftJson` has no
`StringEnumConverter`) — have the controller project enum fields to strings, or parse ints on the
client. See the `mvc-enum-serialization` memory.

## Lucide icon names must be **v2 canonical** (no aliases)

`BlazorBlueprint.Icons.Lucide` is pinned at **2.0.0**, whose runtime registers only Lucide's ~1665
**canonical** names. The package also ships a `content/lucide.json` with ~212 **aliases**, but the DLL
does **not** register aliases — so a Lucide-v1 / alias name renders a ⚠️ "Icon not found" fallback,
often with the wrong meaning (a warning triangle where a check belongs). Use canonical names. Renames
that bit this repo (fixed in PR #130):

| ❌ alias / v1 | ✅ canonical | ❌ alias / v1 | ✅ canonical |
|---|---|---|---|
| `layout` | `layout-dashboard` | `check-square` | `square-check` |
| `code-2` | `code-xml` | `columns` | `columns-2` |
| `form-input` | `text-cursor-input` | `edit` | `square-pen` |
| `globe-2` | `globe` | `home` | `house` |
| `bar-chart-2` | `chart-no-axes-column` | `plus-circle` | `circle-plus` |
| `circle-help` | `circle-question-mark` | `x-circle` | `circle-x` |
| `check-circle-2` | `circle-check-big` | `alert-circle` | `circle-alert` |
| `check-circle` | `circle-check` | `alert-triangle` | `triangle-alert` |

If unsure a name exists, dump `LucideIconData.GetAvailableIcons()` from the installed DLL. To audit a
running page, count `[role=alert]` nodes whose text matches `/icon not found/i` — must be 0.

## No app-level Tailwind build — only `blazorblueprint.css` utilities exist

The portal has **no Tailwind compile step**. Every utility class is served by the precompiled
`blazorblueprint.css` from the `BlazorBlueprint.Components` NuGet — only the utilities BlazorBlueprint's
own components used are present. A class that isn't in the bundle silently does nothing (e.g. a `grid`
with `md:grid-cols-3` gets `display:grid` but no `grid-template-columns`, collapsing to one column).

Confirmed **absent** (collapsed stat-card rows): `sm:grid-cols-3`, `sm:grid-cols-4`, `md:grid-cols-3`.
Present: `grid-cols-3`, `lg:grid-cols-3`, `lg:grid-cols-4`, `md:grid-cols-2`, `sm:grid-cols-2`.

- Before relying on any new Tailwind utility, grep
  `~/.nuget/packages/blazorblueprint.components/<ver>/staticwebassets/blazorblueprint.css` for it.
- If missing, add it to `src/apps/MixCore.Cloud.Web/wwwroot/css/cloud.css` (loaded after the bundle in
  `_CloudLayout.cshtml`), e.g. `@media (min-width:640px){ .sm\:grid-cols-3{grid-template-columns:repeat(3,minmax(0,1fr))} }`.
- Verify in-browser: `getComputedStyle(grid).gridTemplateColumns`.

### Arbitrary Tailwind values never emit — use `cloud.css` instead

**Any `[arbitrary-value]` Tailwind class silently does nothing.** This includes:
- Width/height: `w-[98vw]`, `max-w-[60rem]`, `h-[90vh]`, `max-h-[90vh]`
- Overflow: `overflow-hidden` (as an arbitrary `[overflow:hidden]`)
- Text wrapping: `[overflow-wrap:anywhere]`, `[word-break:break-all]`, `[word-break:break-word]`
- Grid: `grid-cols-[120px_1fr]`, `min-w-[200px]`

**Workaround:** define the rule as a **CSS class** in `cloud.css` with `!important` to override
BlazorBlueprint's default `max-w-lg`/`max-h` on dialogs:

```css
/* cloud.css */
.audit-detail-dialog { width: 98vw !important; max-width: 60rem !important; max-height: 90vh !important; overflow: hidden !important; }
.audit-detail-dialog pre { white-space: pre-wrap; overflow-wrap: anywhere; word-break: break-word; max-height: 24rem; overflow: auto; }
```

Then reference the class: `<BbDialogContent Class="audit-detail-dialog flex flex-col gap-0 p-0" ...>`.
See `AuditLogSection.razor` for the canonical pattern.

### `BbDialog`: use `ShowClose="false"` when the header has its own X

`BbDialogContent` renders a **built-in close button** (an X in the top-right) by default. If you
build a custom header with your own `<BbDialogClose>` X button, set `ShowClose="false"` on
`BbDialogContent` — otherwise the dialog has **two close icons**:

```razor
<BbDialogContent Class="..." ShowClose="false">
    <BbDialogHeader>
        <div class="flex items-start justify-between gap-4">
            <BbDialogTitle>Title</BbDialogTitle>
            <BbDialogClose AsChild>
                <BbButton Variant="ButtonVariant.Ghost" Size="ButtonSize.Icon">
                    <LucideIcon Name="x" class="h-4 w-4" />
                </BbButton>
            </BbDialogClose>
        </div>
    </BbDialogHeader>
    @* …body (no BbDialogFooter needed — the X is the sole close)… *@
</BbDialogContent>
```

### Flexbox text-wrapping: add `min-w-0` to the container chain

In a flex column layout, flex children default to `min-width: auto` (content-based), so they
expand to fit their longest child rather than constraining it. `max-w-full` on a `<pre>` is
ineffective because the parent keeps growing. Add `min-w-0` to every flex container in the chain
from the constrained ancestor down to the code block:

```razor
@* ❌ Wrong — <pre> overflows because its ancestors have min-width:auto *@
<div class="flex flex-col gap-3 overflow-y-auto flex-1 min-h-0">       @* missing min-w-0 *@
    <div class="flex flex-col gap-1">
        <pre class="max-w-full">...long unbroken JSON line...</pre>
    </div>
</div>

@* ✅ Right — min-w-0 on the constrained ancestor lets flex children shrink *@
<div class="flex flex-col gap-3 overflow-y-auto flex-1 min-h-0 min-w-0">  @* <— min-w-0 here *@
    <div class="flex flex-col gap-1 min-w-0">                              @* <— and here *@
        <pre class="rounded-md border bg-muted/40 p-3 text-xs overflow-auto whitespace-pre-wrap max-h-96">@Pretty(p.Value)</pre>
    </div>
</div>
```

For simpler scalar text (not in a `<pre>`), use Tailwind's native `break-all` instead of
arbitrary-wrap utilities: `<span class="text-sm break-all">@Scalar(p.Value)</span>`.

## Component parameter names are validated at **render**, not build

Blazor binds component parameters by reflection at render time, so passing a parameter the component
doesn't declare **compiles fine** but throws `InvalidOperationException: … does not have a property
matching the name 'X'` at runtime — terminating the circuit (blank page). Always smoke-test a page in
the browser after adding component params; `dotnet build` will not catch this.

Concrete trap: `ShowSearch` exists on **`BbDataGrid`/`BbTreeView`**, not **`BbDataTable`**.
`BbDataTable`'s built-in toolbar search is on whenever `ShowToolbar="true"` and filters on change/Enter
(see `DatabasesSection.razor`). **Do not add a second custom `<input>` search** inside
`<ToolbarActions>` — that yields a duplicate search box (the MixDB Tables bug, #128). Keep only facet
filters (Type, etc.) + Reset in `ToolbarActions` and let the built-in search handle text.

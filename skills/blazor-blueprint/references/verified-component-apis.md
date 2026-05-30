# Verified BlazorBlueprint Component APIs (this repo)

These are the exact component usages **confirmed by grepping `src/modules/**/*.razor`** in this
repo. The live docs at blazorblueprintui.com are the upstream source of truth, but the patterns
below are what actually compiles and matches existing conventions here. When they disagree with a
guess, trust these — they were derived from working code.

## Modals / slide-outs → use `BbSheet`, not `BbDialog`

There is **no `BbDialog`/`BbModal` usage anywhere in this codebase.** Every modal, drawer, and
create/edit form is a `BbSheet`. Use it for new overlays.

Controlled (programmatic open, e.g. opened from a row action):

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
`mix.cloud.ui/Components/Sections/Automation/{CreateEditFlowDialog,RunHistoryPanel}.razor`.

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

## `BbSwitch` uses `Checked` / `CheckedChanged`

NOT `Value`/`ValueChanged`, and there is no `@bind-Checked` in use:

```razor
<BbSwitch Checked="@x" CheckedChanged="@(v => x = v)" />
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

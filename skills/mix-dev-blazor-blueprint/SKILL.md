---
name: mix-dev-blazor-blueprint
description: Scaffold and design shadcn-style dashboards and UI components for mixcore-cloud using BlazorBlueprint.Components — layouts, data grids, charts, sidebars, forms, and page blueprints.
argument-hint: "[dashboard|sidebar|form|datagrid|chart|page] [component-name]"
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
  - Edit
  - Write
  - WebFetch
---

You are building **shadcn-style UI** for **mixcore-cloud** using **BlazorBlueprint.Components**.

## First step — check verified repo APIs, then fetch current docs

**Read `references/verified-component-apis.md` first.** It documents the exact component usages
confirmed by grepping this repo — including repo conventions that differ from a naive reading of the
library docs (e.g. modals use `BbSheet`, **not** `BbDialog`; `BbSelect` is compositional; `BbSwitch`
uses `Checked`/`CheckedChanged`; inline `@code` blocks must add `@using Newtonsoft.*`) **and three
portal-wide traps: Lucide names must be v2 canonical (aliases render ⚠️), Tailwind utilities are
limited to the precompiled `blazorblueprint.css` (add missing ones to `cloud.css`), and component
parameter names are checked at render not build (a bad param compiles but kills the circuit).**

Then fetch the live component index for anything not covered there:

```
WebFetch https://blazorblueprintui.com/llms/index.txt
```

For a specific component (e.g. DataGrid), fetch its dedicated doc:

```
WebFetch https://blazorblueprintui.com/llms/data-grid.txt
WebFetch https://blazorblueprintui.com/llms/chart.txt
WebFetch https://blazorblueprintui.com/llms/sidebar.txt
```

---

## Setup (already done in this repo)

| Step | Code |
|------|------|
| NuGet | `BlazorBlueprint.Components` (v3.9.3+) in `src/apps/mixcore/mixcore.csproj` |
| Services | `builder.Services.AddBlazorBlueprintComponents();` in `Program.cs` |
| CSS | `<link rel="stylesheet" href="_content/BlazorBlueprint.Components/blazorblueprint.css" />` in layouts |
| Portal | `<BbPortalHost />` in `_InitLayout.cshtml` (required for modals, sheets, tooltips) |
| Imports | `@using BlazorBlueprint.Components` is in all three `_Imports.razor` files |

---

## Component categories

| Category | Key components |
|----------|---------------|
| Enterprise | `BbDataGrid`, `BbChart`, `BbFormWizard`, `BbDashboardGrid` |
| Navigation | `BbSidebar`, `BbTabs`, `BbBreadcrumb`, `BbPagination` |
| Overlay | `BbSheet` (preferred for modals/drawers in this repo — no `BbDialog` usage exists), `BbToast`, `BbPopover`, `BbTooltip` |
| Form | `BbInput`, `BbSelect`, `BbCheckbox`, `BbRadioGroup`, `BbSwitch`, `BbDatePicker`, `BbFileUpload` |
| Display | `BbAlert`, `BbAvatar`, `BbBadge`, `BbSkeleton`, `BbSpinner`, `BbCard` |
| Data | `BbTable`, `BbTreeView`, `BbMarkdownEditor` |
| Icons | `<LucideIcon Name="..." />` (BlazorBlueprint.Icons.Lucide) |

---

## Repo conventions

- **Location**: new components go in the module's `Components/` folder
  - AI UI: `src/modules/ai/mix.ai.ui/Components/`
  - Installation UI: `src/modules/installation/mix.installation.ui/Components/`
  - Shared UI: `src/platform/common/mix.ui.shared/Components/`
- **Render mode**: use `@rendermode InteractiveServer` on components that need interactivity
- **Namespace**: follow `Mix.<ModuleName>.Ui.Components`
- **No Bootstrap**: layouts use `mixcore:*` CSS classes from `site.css` (BlazorBlueprint design tokens)

---

## Dashboard layout pattern

```razor
@rendermode InteractiveServer

<div style="display:flex; height:100vh;">
    <BbSidebar>
        <BbSidebarHeader>
            <span style="font-weight:700">mixcore</span>
        </BbSidebarHeader>
        <BbSidebarContent>
            <BbSidebarMenu>
                <BbSidebarMenuItem>
                    <BbSidebarMenuButton Href="/dashboard">
                        <LucideIcon Name="layout-dashboard" />
                        Dashboard
                    </BbSidebarMenuButton>
                </BbSidebarMenuItem>
            </BbSidebarMenu>
        </BbSidebarContent>
    </BbSidebar>

    <main style="flex:1; overflow:auto; padding:1.5rem;">
        <!-- KPI cards row -->
        <BbDashboardGrid Columns="4">
            <BbCard>...</BbCard>
        </BbDashboardGrid>

        <!-- Data table -->
        <BbDataGrid Items="@items" TItem="MyItem">
            <BbDataGridColumn Field="@(x => x.Name)" Title="Name" />
        </BbDataGrid>
    </main>
</div>
```

---

## Theming

BlazorBlueprint uses shadcn/ui-compatible CSS variables (OKLCH). To customise, add a `theme.css` before `blazorblueprint.css`:

```css
@layer base {
  :root {
    --background: oklch(1 0 0);
    --foreground: oklch(0.145 0 0);
    --primary: oklch(0.205 0 0);
    --primary-foreground: oklch(0.985 0 0);
    --radius: 0.5rem;
  }
  .dark {
    --background: oklch(0.145 0 0);
    --foreground: oklch(0.985 0 0);
  }
}
```

Pre-built themes: https://ui.shadcn.com/themes and https://tweakcn.com

---

## BbPortalHost placement

`<BbPortalHost />` must appear **once** in the root layout of any page that uses overlays (Dialog, Sheet, Toast, Popover, Tooltip). It is already in `_InitLayout.cshtml`. Add it to `_Layout.cshtml` if you add overlay components to MVC-hosted Blazor islands.

---
title: "Design System Format & Gate (design.md authoring rules)"
category: "instructions"
sub_category: "templates"
tags: [design-system, design-md, format-spec, gate, bootstrap, css-variables]
last_modified: 2026-06-11
summary: "How to resolve, author, bootstrap, and apply a design.md before creating or updating any template. Mixcore-adapted Google DESIGN.md format. Defines the resolution gate, token→CSS-variable materialization into the master layout, and the contrast/completeness checklist."
---

# design.md — Format & Resolution Gate

`design.md` is the single source of visual-identity truth for a site. It MUST be resolved
**before every `CreateTemplate` / `UpdateTemplate`**, alongside the Wiki-First and
Frontend-Design-First gates. Inspired by Google's DESIGN.md, adapted to mixcore: tokens are
CSS-variable oriented and materialized into the master layout.

## Resolution Gate (run before any template create/update)
1. **Per-site override** — `read_document("<site-slug>/design.md")`.
2. **Fallback** — if missing, use the global default `references/design.md`
   (engine: `instructions/templates/design.md`).
3. **Auto-bootstrap** — if there is no per-site `design.md` AND this is a real site build,
   synthesize one from, in priority order: brand input the user gave → the site's
   requirements/brand wiki doc → `frontend-design` (or other available UI skill) output →
   the global default. Save it with
   `generate_document("design", <content>, "<site-slug>")`, then proceed.
4. **Apply** — generate Razor/CSS from the resolved tokens; obey Do's & Don'ts. No off-palette
   / off-scale literals.

Order within a template task: **Wiki-First → Design-System-First → Frontend-Design-First →
CreateTemplate → ValidateTemplate**.

## File format (mixcore-adapted Google DESIGN.md)
Two layers: YAML front matter (machine-readable tokens) + markdown prose (the *why*).

YAML token groups: `colors`, `typography`, `spacing`, `radius`, `elevation`, `breakpoints`,
`components`. Each maps to a CSS custom property (see the global default for the canonical
`--color-*` / `--font-*` / `--space-*` / `--radius-*` / `--shadow-*` names).

Markdown sections, in this canonical order (Google order + mixcore notes):
`## Overview` → `## Colors` → `## Typography` → `## Layout` → `## Elevation & Depth` →
`## Shapes` → `## Components` → `## Do's and Don'ts`.

## Token → CSS-variable materialization (the mixcore mechanism)
The master layout is "create first" and owns site-wide CSS. Materialize the resolved tokens
**once** into its `:root {}` block, e.g.:

```razor
<style>
  :root {
    --color-primary: #2563eb;
    --color-text: #0f172a;
    --font-sans: Inter, system-ui, sans-serif;
    --space-4: 1rem;
    --radius-md: 0.5rem;
    --shadow-md: 0 4px 6px -1px rgba(0,0,0,0.10);
    /* …one line per token from design.md… */
  }
</style>
```

Every other template (page/module/post/widget/form/MixDB detail) consumes `var(--color-primary)`
etc. — never re-declares raw values. Updating `design.md` + re-materializing the master
restyles the whole site.

## Authoring / bootstrap checklist
- [ ] All required token groups present (colors, typography, spacing, radius, elevation).
- [ ] Body text vs background ≥ WCAG AA (4.5:1); large text ≥ 3:1. (Prose check — no CLI lint.)
- [ ] Every prose section present and in canonical order.
- [ ] Component entries reference token names, not raw values.
- [ ] Saved as a per-site wiki doc via `generate_document` (kebab-case `design.md`).

## When updating an existing design.md
Read the current per-site file first, change only the intended tokens/prose, re-save via
`generate_document`, then re-materialize the master `:root` so consumers pick up the change.

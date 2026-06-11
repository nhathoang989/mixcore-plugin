---
title: "Global Default Design System (design.md)"
category: "instructions"
sub_category: "templates"
tags: [design-system, design-md, tokens, visual-identity, css-variables, default]
last_modified: 2026-06-11
summary: "The global default design.md used when a site has no per-site override. Mixcore-adapted Google DESIGN.md format: YAML token front matter + prose rationale. Tokens are materialized into the master layout :root and consumed as CSS variables by all other templates."
---

# Default Design System

> This is the **global default**. A site overrides it with a per-site wiki doc at
> `<site-slug>/design.md`. Resolve the per-site file first; fall back to this only when none exists.

```yaml
colors:
  primary:    "#2563eb"   # --color-primary   (primary actions, links)
  secondary:  "#475569"   # --color-secondary (secondary buttons, headers)
  accent:     "#f59e0b"   # --color-accent    (highlights, badges)
  background: "#ffffff"   # --color-bg        (page background)
  surface:    "#f8fafc"   # --color-surface   (cards, raised panels)
  text:       "#0f172a"   # --color-text      (body text)
  textMuted:  "#64748b"   # --color-text-muted(captions, meta)
  border:     "#e2e8f0"   # --color-border    (dividers, input borders)
  success:    "#16a34a"
  warning:    "#d97706"
  danger:     "#dc2626"
typography:
  fontSans:  "Inter, system-ui, -apple-system, 'Segoe UI', Roboto, sans-serif"  # --font-sans
  fontSerif: "Georgia, 'Times New Roman', serif"                                # --font-serif
  fontMono:  "'JetBrains Mono', 'Fira Code', ui-monospace, monospace"           # --font-mono
  baseSize:  "16px"        # --text-base
  ratio:     1.25          # major-third scale
  weights:   { normal: 400, medium: 500, semibold: 600, bold: 700 }
  lineHeights: { tight: 1.25, normal: 1.5, relaxed: 1.75 }
spacing:   # 4px base → --space-*
  "1": "0.25rem"
  "2": "0.5rem"
  "3": "0.75rem"
  "4": "1rem"
  "6": "1.5rem"
  "8": "2rem"
  "12": "3rem"
  "16": "4rem"
radius:
  sm:   "0.25rem"   # --radius-sm
  md:   "0.5rem"    # --radius-md
  lg:   "1rem"      # --radius-lg
  full: "9999px"    # --radius-full
elevation:
  sm: "0 1px 2px rgba(0,0,0,0.05)"          # --shadow-sm
  md: "0 4px 6px -1px rgba(0,0,0,0.10)"     # --shadow-md
  lg: "0 10px 15px -3px rgba(0,0,0,0.10)"   # --shadow-lg
breakpoints: { sm: "640px", md: "768px", lg: "1024px", xl: "1280px" }
components:
  button: { bg: primary, text: background, radius: md, paddingY: "3", paddingX: "6" }
  card:   { bg: surface, border: border, radius: lg, shadow: md, padding: "6" }
  input:  { bg: background, border: border, radius: md, text: text }
```

## Overview
A clean, neutral, professional identity: blue primary, slate neutrals, generous whitespace,
subtle elevation. Reads as trustworthy SaaS. Override per site when the brand differs.

## Colors
Use `--color-primary` for primary actions and links; `--color-secondary` for secondary
controls; `--color-accent` sparingly for emphasis. Body text is `--color-text` on
`--color-bg`; cards sit on `--color-surface`. Keep body text vs background at WCAG AA (≥4.5:1).

## Typography
Sans (`--font-sans`) for UI and body, serif optional for long-form, mono for code. Scale is a
1.25 major-third from a 16px base. Headings use weight 600–700; body 400.

## Layout
Spacing uses the `--space-*` 4px scale — never ad-hoc pixel values. Content max-width ~1200px,
centered. Mobile-first; use the breakpoints above (remember `@@media` escaping in `.cshtml`).

## Elevation & Depth
Three shadow tiers (`--shadow-sm/md/lg`). Elevate cards and popovers; keep page backgrounds flat.

## Shapes
Radii from `--radius-*`. Inputs/buttons use `md`; cards use `lg`; pills/avatars use `full`.

## Components
- **Button** — `--color-primary` bg, `--color-bg` text, `--radius-md`, padding `--space-3 / --space-6`.
- **Card** — `--color-surface` bg, `--color-border` 1px, `--radius-lg`, `--shadow-md`, `--space-6` padding.
- **Input** — `--color-bg` bg, `--color-border` border, `--radius-md`.

## Do's and Don'ts
- ✅ Reference CSS variables (`var(--color-primary)`), never raw hex copied per template.
- ✅ Materialize these tokens into the master layout `:root {}` once; consume them everywhere else.
- ✅ Escape CSS at-rules in `.cshtml`: `@@media`, `@@keyframes`, `@@font-face`.
- ❌ Don't invent off-palette colors, off-scale spacing, or new fonts per template.
- ❌ Don't hardcode dynamic data — load MixDB rows; styling tokens are the only constants.

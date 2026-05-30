---
name: spa
description: Embed a built SPA (Vite, CRA, Next static export, Astro, SvelteKit static, plain HTML/JS) into Mixcore as a page — clarifies requirements and writes a plan document first (Step 0), then configures the build base path to `/mixcontent/<name>/`, deploys static assets, escapes Razor `@` chars, and creates the Page template and Page via MCP with `layoutId=null`. Use when the user asks to "embed a React/Vue/Svelte app into Mixcore", "serve a built SPA as a Mixcore page", "wrap index.html in a Mixcore template", "deploy a Vite app at /<route>", or any time a complete, self-contained `<!doctype html>…</html>` document is being installed as a Mixcore page rather than rebuilt as a Razor page.
argument-hint: "<seo-name> [page-title] — SPA project lives at wwwroot/mixcontent/<seo-name>/"
---

You are embedding a **built SPA** (Single-Page Application) into Mixcore as a single page with `layoutId=null`. The SPA's built `index.html` becomes the page template content verbatim, and the SPA's static assets are served from `/mixcontent/<seo-name>/`.

**When to use this skill** — anything that produces a static `index.html` + an `assets/` folder and needs to live at a Mixcore route:
- Vite (React / Vue / Svelte / Solid / Preact / vanilla)
- Create React App
- Next.js static export (`output: 'export'`)
- Astro / SvelteKit static
- Plain hand-written HTML/CSS/JS

**When NOT to use it** — if the page should be **rendered by Razor** with Mixcore data (Model.Content, MixDB queries, modules, posts), use [mixcore:cms](../mixcore:cms/SKILL.md) instead. This skill is for fully client-rendered apps that ship their own runtime.

---

## Invocation Mode — Plan First or Auto-Complete

**Check whether the user asked for auto-complete before doing anything else.**

Auto-complete is requested when the user's message includes any of:
`auto`, `auto-complete`, `just do it`, `go ahead`, `skip questions`, `no questions`, `proceed automatically`

### If NOT in auto-complete mode → Clarify & Plan (REQUIRED)

Do NOT build, deploy, or call any MCP tools yet. Instead:

**1. Summarise what you understood** (2–3 sentences). State the SPA type, the target route/seo-name if given, and the primary purpose.

**2. Ask focused clarifying questions** via `AskUserQuestion` — pick only unknowns:

| Topic | Example question |
|---|---|
| SPA framework | "Is this a Vite/React, Vue, Next.js, or plain HTML SPA?" |
| Route | "What URL should it live at? (e.g. `/dashboard`, `/app`, `/landing`)" |
| Dynamic data | "Does the SPA need to read data from the CMS — product lists, blog posts, team members?" |
| Forms | "Does it include any forms that should submit to MixDB?" |
| Build state | "Is the SPA already built (dist/ exists), or does it need to be scaffolded and built first?" |

**3. Propose a deploy plan outline** — show the user what you plan to do so they can correct or confirm:

```
**Proposed deploy plan for [SPA Name]:**
- Route: /<seo-name>
- Framework: [Vite/React/…]
- Assets path: src/apps/MixCore.Cloud.Web/wwwroot/mixcontent/<seo-name>/
- Dynamic data: [MixDB tables to create, or none]
- Forms: [submission table name, or none]
- Mixcore page: title, layoutId=null, type="Article"

If this looks right, reply "go ahead" and I'll create the plan document then deploy.
To adjust any part, answer the questions above or just tell me what to change.
```

**4. Wait for user confirmation** before writing any plan document or calling any MCP/build tools.

### If IN auto-complete mode → Skip straight to Step 0

Proceed immediately to Step 0 — Plan Document — using all context already provided.

---

## Step 0 — Plan Document (REQUIRED before any deployment step)

**Before touching the build, the file system, or any MCP tool, write a plan document.**

Create `wwwroot/mixcontent/planning/<seo-name>-spa-plan.md` using the Write tool:

```markdown
# SPA Deploy Plan: <SPA Name>

## Identity
- **SPA Name:** <name>
- **Framework:** Vite / CRA / Next.js / Astro / plain HTML
- **Route (seo-name):** <seo-name>
- **Page Title:** <title>
- **Page Type:** Article  (or "Home" if this replaces the root page)

## Paths
- **Source root:** src/apps/MixCore.Cloud.Web/wwwroot/mixcontent/<seo-name>/
- **Build output:** …/<seo-name>/dist/  (assets served at /mixcontent/<seo-name>/dist/assets/ for upload_from_url)
- **Vault provider:** [local / S3 / MinIO / R2 — determines upload approach]
- **Vite base:** /mixcontent/<seo-name>/ (build only; template will use vault URLs)

## CMS Dependencies
- **MixDB tables needed:** [list table names, or "none"]
- **MixDB form submission tables:** [list table names, or "none"]
- **Pre-existing CMS data to fetch:** [list endpoints, or "none"]

## Vault Upload Map
<!-- Filled in during Step 3 -->
| Original dist path | Vault storedUrl | mediaId |
|---|---|---|
| /mixcontent/<seo-name>/assets/<hash>.js | TBD | TBD |
| /mixcontent/<seo-name>/assets/<hash>.css | TBD | TBD |
| /mixcontent/<seo-name>/favicon.svg | TBD | TBD |

## Razor Escaping
- **Known @ characters to double:** [e.g. Google Fonts wght@, ital@ — or "TBD: scan dist/index.html after build"]

## Checklist
- [ ] Step 0 — Plan document written
- [ ] Pre-step — MixDB tables created (if any)
- [ ] Step 1 — Vite base path configured
- [ ] Step 2 — SPA built
- [ ] Step 3 — Assets uploaded to Mix Vault via upload_from_url; vault map filled in above
- [ ] Step 4 — dist/index.html read + vault URLs substituted
- [ ] Step 5 — @ characters escaped
- [ ] Step 6 — Page template created via MCP
- [ ] Step 7 — Page record created via MCP
- [ ] Post-step — Wiki doc updated with vault upload map
```

### Pre-step: CMS dependencies

If the plan lists MixDB tables or form tables:
1. Invoke the `mixcore:cms` skill and load `mixcore:db`
2. Create all required MixDB tables **before** building the SPA
3. Record the exact `systemName` for each table — the SPA fetch code references these names at runtime

Only after the plan document is written and CMS dependencies are resolved, proceed to Step 1.

---

## Dynamic data & forms — consult `mixcore:cms` BEFORE writing code

**Before generating any SPA code that loads data or renders a form, invoke the `mixcore:cms` skill** and inspect the live Mixcore site state (MixDB tables, posts, pages, modules). Data that lives in the CMS must be fetched at runtime — never hardcoded.

### Decision table

| SPA feature | Hardcode? | Action |
|---|---|---|
| Static marketing copy, hero text | ✅ Fine | Write directly in JSX/HTML |
| List of products, blog posts, team members | ❌ No | Load `mixcore:cms` → find/create MixDB table → fetch via API |
| Contact / signup / survey form | ❌ No | Load `mixcore:cms` → identify form module or MixDB table for submissions |
| Navigation items | ❌ No | Load `mixcore:cms` → `get_page_navigation_tree` |
| Images whose URLs are known build-time constants | ✅ Fine | Inline the URL |
| Images managed by editors (changeable) | ❌ No | Load `mixcore:cms` → store in MixDB row with image column |

### Data-loading pattern

After loading `mixcore:cms` and confirming the MixDB table name (e.g. `products`), fetch at runtime using the Mixcore REST API:

```ts
// GET list from a MixDB table
const res = await fetch('/api/v1/rest/data-source/products/items?pageSize=20')
const { data } = await res.json()   // data.items: row[]

// GET single row by id
const res = await fetch('/api/v1/rest/data-source/products/items/42')
const { data } = await res.json()
```

Use `useEffect` + `useState` (React) or `onMounted` (Vue) to fetch on mount. Handle loading/error states.

### Form-submission pattern

Before building a form, load `mixcore:cms` and call `get_modules_by_type` or `list_module_contents` to check for an existing form module. If one exists, submit to its endpoint. If not, create a MixDB table for submissions first (via `mixcore:cms` → `mixcore:db`), then POST rows:

```ts
// POST a new row to a MixDB submissions table
await fetch('/api/v1/rest/data-source/contact_submissions/items', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ name, email, message }),
})
```

### Required workflow

```
User asks for data-loading or form in SPA
  → invoke mixcore:cms skill
  → inspect site state (get_tables, list_module_contents)
  → confirm table/module name and column schema
  → generate SPA fetch/POST code against real API
  → only THEN write the React/Vue component
```

Never write a component that fetches `/api/...` without first verifying the endpoint exists and the schema matches.

---

## Folder layout — source AND deployed artifacts co-located

The **source tree** and the **deployed artifacts** for an SPA both live in `src/apps/MixCore.Cloud.Web/wwwroot/mixcontent/<seo-name>/`:

```
src/apps/MixCore.Cloud.Web/wwwroot/mixcontent/<seo-name>/
├── src/                    ← Vite/React/Vue source
├── public/                 ← static assets copied to build output
├── index.html              ← Vite source entry (NOT a deployed page — Mixcore serves the template at /<seo-name>)
├── package.json
├── vite.config.ts          ← `base: '/mixcontent/<seo-name>/'` (build only)
├── tsconfig.json
├── dist/                   ← Vite build output — gitignored; assets are HTTP-accessible here for upload_from_url
└── node_modules/           ← gitignored
```

**No `assets/` sibling folder** — built assets are uploaded to Mix Vault via `upload_from_url` and served from their vault URLs. The `assets/` directory is not needed and should not be created.

**Caveat — source is statically servable:** ASP.NET's static file middleware serves everything under `wwwroot/`, so `dist/assets/index-HASH.js` is reachable at `/mixcontent/<seo-name>/dist/assets/index-HASH.js`. This is intentional — it is what makes `upload_from_url` work. But never put `.env` files, secrets, or credentials inside the SPA folder; they will be publicly accessible.

---

## Deployment — Steps 1–7

> **Pre-condition:** Step 0 plan document must exist at `wwwroot/mixcontent/planning/<seo-name>-spa-plan.md`. Tick each checklist item in the plan as you complete it.

### 1. Configure the build base path

Every URL inside the built `index.html` (script src, link href, favicon) must resolve under `/mixcontent/<seo-name>/`. Set this once in the build config so subsequent rebuilds are stable.

**Vite** — edit `vite.config.ts`:

```ts
import { defineConfig } from 'vite'

export default defineConfig(({ command }) => ({
  base: command === 'build' ? '/mixcontent/<seo-name>/' : '/',
  // ...plugins
}))
```

The conditional keeps `npm run dev` working at `http://localhost:5173/` while production builds rewrite to the deploy base.

**Create React App** — set `"homepage": "/mixcontent/<seo-name>/"` in `package.json` before `npm run build`.

**Next.js static export** — set `basePath: '/mixcontent/<seo-name>'` and `assetPrefix: '/mixcontent/<seo-name>/'` in `next.config.js`.

**Plain HTML** — hand-edit the `<script src>` / `<link href>` to start with `/mixcontent/<seo-name>/`.

### 2. Build the SPA

Run the build from the SPA folder under `wwwroot/mixcontent/<seo-name>/`:

```bash
npm run build --prefix src/apps/MixCore.Cloud.Web/wwwroot/mixcontent/<seo-name>
```

Vite outputs to `…/<seo-name>/dist/`. Verify the produced `index.html` references your base path:

```bash
grep -E 'src=|href=' src/apps/MixCore.Cloud.Web/wwwroot/mixcontent/<seo-name>/dist/index.html
```

Every `src=` / `href=` for local assets should start with `/mixcontent/<seo-name>/`. External URLs (Google Fonts, CDNs) are untouched.

### 3. Upload assets to Mix Vault via MCP

`dist/assets/` is under `wwwroot/`, so ASP.NET Core's static-file middleware serves each built file at `http://localhost:<PORT>/mixcontent/<seo-name>/dist/assets/<filename>`. Use `upload_from_url` to ingest those files into Mix Vault and get back permanent served URLs.

**A. Extract asset filenames from the built `index.html`**

Scan `dist/index.html` for every local asset reference:

```bash
grep -oE '/mixcontent/<seo-name>/[^"'\'']+' \
  src/apps/MixCore.Cloud.Web/wwwroot/mixcontent/<seo-name>/dist/index.html
```

Typical output:
```
/mixcontent/<seo-name>/assets/index-Bqhsncm1.js
/mixcontent/<seo-name>/assets/index-BR28wvA1.css
/mixcontent/<seo-name>/favicon.svg
```

**B. Upload each asset via MCP — `upload_from_url`**

Read the server port from `.mcp.json` (the `mixcore` server entry's `url` field). For each file from step A:

```
upload_from_url(
  url: "http://localhost:<PORT>/mixcontent/<seo-name>/dist/assets/<filename>",
  filename: "<filename>"
)
```

The tool returns `{ storedUrl, key, mediaId }`. Build a substitution map:

| Original path in `dist/index.html` | Vault `storedUrl` |
|---|---|
| `/mixcontent/<seo-name>/assets/index-Bqhsncm1.js` | `/mix-content/…` |
| `/mixcontent/<seo-name>/assets/index-BR28wvA1.css` | `/mix-content/…` |
| `/mixcontent/<seo-name>/favicon.svg` | `/mix-content/…` |

**C. Production: S3 / MinIO / R2 vault backends**

For cloud providers, use `get_presigned_upload_url` to get a signed PUT URL, then upload the file bytes directly:

```
presigned = get_presigned_upload_url(key: "spa/<seo-name>/assets/<filename>")
# PUT file bytes to presigned.url with the correct Content-Type header
# (use curl, PowerShell Invoke-WebRequest, or any HTTP client)
```

> **Server must be running.** `upload_from_url` fetches over HTTP — the Mixcore server must be up so `dist/` files are reachable. If the server is stopped, fall back to the bash `cp -r` approach and re-run the MCP upload once the server restarts.

**Why vault upload instead of bash copy?**

- Assets live in Mix Vault — persistent, CDN-routable, provider-agnostic (local → S3/R2 requires no code change)
- No `assets/` sibling folder to maintain; no stale hash-named files accumulate
- On rebuild, new uploads produce new vault URLs → template update naturally replaces old references

### 4. Read `dist/index.html` and substitute vault URLs

Read the built `index.html`:

```
Read src/apps/MixCore.Cloud.Web/wwwroot/mixcontent/<seo-name>/dist/index.html
```

**Do not** read the source `index.html` at the project root — it still has `<script src="/src/main.tsx">` and won't work in production.

Using the substitution map from step 3, replace every original local path with its vault `storedUrl`:

```
Replace: /mixcontent/<seo-name>/assets/index-Bqhsncm1.js
With:    <storedUrl returned for that file>

Replace: /mixcontent/<seo-name>/assets/index-BR28wvA1.css
With:    <storedUrl returned for that file>

Replace: /mixcontent/<seo-name>/favicon.svg
With:    <storedUrl returned for favicon>
```

Apply all substitutions before moving to step 5. The resulting HTML references vault URLs throughout.

### 5. Escape `@` characters for Razor

The template is a `.cshtml` file rendered by Razor. Razor parses `@` as the start of a code expression. Every literal `@` in the HTML must be doubled to `@@`.

Common sources of literal `@` in built SPAs:

| Source | Before | After |
|---|---|---|
| Google Fonts weight | `wght@300;400` | `wght@@300;400` |
| Google Fonts italic | `ital@1` | `ital@@1` |
| Inline email | `mailto:hi@example.com` | `mailto:hi@@example.com` |
| Inline CSS at-rules | `@media`, `@keyframes`, `@font-face` | `@@media`, `@@keyframes`, `@@font-face` |
| npm-style version comments | `@version 1.2.3` | `@@version 1.2.3` |

At render time `@@` outputs a literal `@`, so the browser sees the correct URL/CSS.

**Quick scan** (run before pasting):

```bash
grep -nE '[^@]@[^@]' <spa-folder>/dist/index.html
```

Every match needs the `@` doubled.

### 6. Create the Page template via MCP

```
CreateTemplate(
  folderType: "Pages",
  fileName: "<PascalCaseName>Landing.cshtml",   # MUST include .cshtml
  content: "<escaped index.html from step 5>"
)
```

**Rules:**

- `folderType` is `Pages`, not `Masters` — a master layout would wrap the template, but our SPA template is already a complete `<!doctype html>…</html>` document. With `layoutId=null` on the page (step 7) Mixcore renders the template directly.
- Do **not** include an `@model` directive. Mixcore's `_ViewImports.cshtml` provides the page model type globally, and the template doesn't reference `Model` anyway.
- Do **not** include `@{ Layout = "..." }`. The page-level `layoutId=null` is what disables the master.
- Save the returned template `Id` — you need it for step 7.

### 7. Create the Page via MCP

```
CreatePageContent(
  title: "<page title>",
  seoName: "<seo-name>",            # the URL slug — page will live at /<seo-name>
  templateId: <id from step 6>,
  layoutId: null,                    # critical: disables the master layout
  type: "Article",                   # REQUIRED — see gotcha below
  content: "",                       # empty: SPA renders into <div id="root"></div>
  status: "Published",
  seoTitle: "...",
  seoDescription: "..."
)
```

The page is now live at `https://<host>/<seo-name>`.

---

## Critical gotchas (learned the hard way)

### `type` is NOT NULL in `mix_page_content`

The MCP tool definition shows `type` as optional with no default, but the underlying Postgres column is `NOT NULL`. Calling `CreatePageContent` without `type` returns:

```
23502: null value in column "type" of relation "mix_page_content" violates not-null constraint
```

**Fix:** always pass `type: "Article"` (or `"Home"`, `"ListPost"`, `"System"`). For embedded SPAs, `"Article"` is the default choice unless the user wants `/<seo-name>` as the site home.

### Git Bash mangles `--base=/path/` flags

On Windows, MSYS path translation rewrites `--base=/mixcontent/prisma/` into `--base=C:/Program Files/Git/mixcontent/prisma/` before Vite sees it. Vite logs `"base" option should start with a slash` and the URLs in the build are wrong.

**Fix:** never pass `--base=` on the CLI from Git Bash. Set `base` in `vite.config.ts` (step 1) and run plain `npm run build`. If you must use the CLI, prefix the command with `MSYS_NO_PATHCONV=1`.

### Hashed asset filenames change every rebuild

Vite stamps a hash into asset filenames (`index-Bqhsncm1.js`, `index-BR28wvA1.css`). Every rebuild produces new filenames, so the template's `<script src>` and `<link href>` go stale.

**Fix:** after each rebuild, re-upload all assets via `upload_from_url` (step 3) to get new vault `storedUrl` values, substitute them into the fresh `dist/index.html`, escape `@`, and then:

```
UpdateTemplate(id: <template id>, content: "<new escaped index.html with new vault URLs>")
```

The page record itself does not need to change — the `templateId` link is stable.

### `layoutId=null` is the whole point

A Mixcore page template normally renders inside a master layout (which provides `<html>`, `<head>`, `<body>`). An embedded SPA's template **already contains** all of those, so a master layout would produce nested `<html>` elements — invalid HTML.

Always pass `layoutId: null` for SPA pages. The MCP `CreatePageContent` tool accepts it explicitly.

### Don't import the SPA's CSS module into Razor's `Styles` field

`CreateTemplate` has a `styles` parameter. Leave it empty for SPA templates — the SPA's bundled CSS is already linked from inside the `index.html`. Putting it in the `styles` field would double-load and would not match the hashed filename anyway.

### Static asset paths are case-sensitive on Linux

Locally on Windows, `/MixContent/Prisma/assets/foo.js` works. In a Linux container it 404s. Always lowercase the `<seo-name>` and the folder path under `wwwroot/mixcontent/`.

### Navigation links must use smooth-scroll, never bare `href="#"`

A bare `href="#"` either scrolls to the top of the page or does nothing — it never targets the intended section. Every nav link that should scroll to a section on the same page must be wired with `scrollIntoView`.

**Required pattern (React):**

```tsx
// 1. Map each label to its section id
const NAV_TARGETS: Record<string, string> = {
  Projects:  'projects',
  Studio:    'studio',
  Journal:   'hero',      // falls back to top
  Connect:   'connect',
}

// 2. Smooth-scroll handler — always call preventDefault
function handleNav(e: React.MouseEvent, label: string, onDone?: () => void) {
  e.preventDefault()
  const el = document.getElementById(NAV_TARGETS[label] ?? label.toLowerCase())
  if (el) {
    el.scrollIntoView({ behavior: 'smooth', block: 'start' })
  } else {
    window.scrollTo({ top: 0, behavior: 'smooth' })
  }
  onDone?.()   // close mobile menu, if any
}

// 3. Render — href is a real anchor so middle-click / right-click still works
{['Projects', 'Studio', 'Journal', 'Connect'].map(link => (
  <a
    key={link}
    href={`#${NAV_TARGETS[link]}`}
    onClick={e => handleNav(e, link)}
  >
    {link}
  </a>
))}

// 4. Every target section has a matching id
<section id="hero"     className="...">...</section>
<section id="studio"   className="...">...</section>
<section id="projects" className="...">...</section>
<div     id="connect" />   {/* anchor-only div at page bottom */}
```

**Mobile menu:** pass `() => setMenuOpen(false)` as `onDone` so the sheet closes on tap.

**Checklist before shipping any SPA with a navbar:**
- [ ] Every link label has an entry in `NAV_TARGETS`
- [ ] Every target `id` exists in the DOM (section or anchor div)
- [ ] Both desktop nav **and** mobile menu use `handleNav`
- [ ] Clicking each link in dev mode visibly scrolls to the right section

---

## Worked example — Prisma landing page

This is the actual deployment that produced this skill. SPA + deployed assets both at `src/apps/MixCore.Cloud.Web/wwwroot/mixcontent/prisma/` (Vite + React + TS + Tailwind), Mixcore page at `/prisma`.

| Step | Command / call | Result |
|---|---|---|
| 0 | Write `wwwroot/mixcontent/planning/prisma-spa-plan.md` with route, framework, asset paths, no MixDB deps | Plan document created, checklist ready |
| 1 | Edit `…/wwwroot/mixcontent/prisma/vite.config.ts` → `base: command === 'build' ? '/mixcontent/prisma/' : '/'` | Config persists across builds |
| 2 | `npm run build --prefix src/apps/MixCore.Cloud.Web/wwwroot/mixcontent/prisma` | `dist/index.html` with `src="/mixcontent/prisma/assets/index-Bqhsncm1.js"` |
| 3 | `upload_from_url(url="http://localhost:PORT/mixcontent/prisma/dist/assets/index-Bqhsncm1.js")` × 2 files + favicon | storedUrls for JS, CSS, favicon recorded in substitution map |
| 4 | Read `…/dist/index.html`; replace `/mixcontent/prisma/assets/…` with vault storedUrls throughout | `index.html` now references vault URLs |
| 5 | `wght@300` → `wght@@300`, `ital@1` → `ital@@1` (Google Fonts URL only) | Razor-safe HTML |
| 6 | `CreateTemplate(folderType="Pages", fileName="PrismaLanding.cshtml", content=…)` | Template ID `3` |
| 7 | `CreatePageContent(title="Prisma", seoName="prisma", templateId=3, layoutId=null, type="Article", status="Published")` | Page ID `3`, live at `/prisma` |

Total time once the SPA exists: ~2 minutes.

History note: the skill originally used bash `cp -r` to promote assets from `dist/assets/` to an `assets/` sibling folder. The MCP `upload_from_url` approach replaced this — assets now live in Mix Vault, the `assets/` sibling folder is gone, and the template's `<script src>` / `<link href>` reference vault URLs instead of local paths.

---

## Update flow (after SPA code changes)

```bash
# 1. Rebuild
npm run build --prefix src/apps/MixCore.Cloud.Web/wwwroot/mixcontent/<seo-name>
```

Then (with the server running):

```
# 2. Re-upload all assets via MCP — new content hashes produce new vault keys
upload_from_url(url: "http://localhost:<PORT>/mixcontent/<seo-name>/dist/assets/<new-hash>.js")
upload_from_url(url: "http://localhost:<PORT>/mixcontent/<seo-name>/dist/assets/<new-hash>.css")
upload_from_url(url: "http://localhost:<PORT>/mixcontent/<seo-name>/dist/favicon.svg")

# 3. Read dist/index.html, substitute new vault storedUrls, escape @, then:
UpdateTemplate(id=<template id>, content=<new escaped index.html with new vault URLs>)
```

The page record never needs to change — the `templateId` link is stable. The old vault objects for the previous build's hash-named files are superseded by the new uploads; they can be left in vault (small, text files) or deleted if cleanup is required.

---

## Documentation workflow

After deploying an SPA page, update the wiki:

1. Create/update `wiki/page/<seo-name>.md` — record:
   - Page ID, Template ID
   - SPA source folder
   - Vault upload map (original filename → storedUrl / mediaId)
   - Build base path
   - Razor escape list (what `@` chars needed doubling)
   - Update procedure
2. Add a row to `wiki/pages.md`
3. Add a row to `wiki/templates.md`
4. Add a link in `wiki/index.md`

Use `WriteTextFile` / `AppendToTextFile` — these are wiki files, not CMS entities.

---

## Critical do-not-do list

- ❌ Never run `vite build --base=/foo/` from Git Bash — set `base` in `vite.config.ts` instead (MSYS path translation breaks the flag)
- ❌ Never set Vite `build.outDir: '.'` — it overwrites the source `index.html` with the built one, breaking the next rebuild. Keep output in `dist/`
- ❌ Never call `upload_from_url` before the Mixcore server is running — the tool fetches over HTTP; the server must be up for `dist/` files to be reachable
- ❌ Never create an `assets/` sibling folder and copy files there — use `upload_from_url` instead; the assets folder approach is the old pattern
- ❌ Never skip the URL substitution in step 4 — the template must reference vault `storedUrl` values, not the original `/mixcontent/<seo-name>/assets/…` paths (those only exist in `dist/`, not as deployed static files)
- ❌ Never call `CreatePageContent` without `type` — Postgres rejects it (23502 NOT NULL)
- ❌ Never assign a `layoutId` to an SPA page — produces nested `<html>` elements
- ❌ Never add `@model` or `@{ Layout = "…" }` to an SPA template
- ❌ Never forget to escape `@` characters — Razor parses them as code expressions and the build fails at render time
- ❌ Never use mixed-case `<seo-name>` — Linux containers are case-sensitive on file paths
- ❌ Never put the bundled SPA CSS in `CreateTemplate(styles=…)` — it's already linked from inside the built `index.html` and would double-load with a stale hash
- ❌ Never read the **source** `index.html` at `wwwroot/mixcontent/<seo-name>/index.html` when building the template — it has `<script src="/src/main.tsx">` which only works in dev. Always read `wwwroot/mixcontent/<seo-name>/dist/index.html` (the built one).
- ❌ Never put `.env` files, secrets, or anything not meant for public consumption inside `wwwroot/mixcontent/<seo-name>/` — ASP.NET will serve them as static files, including `dist/` contents
- ❌ Never use `href="#"` for in-page nav links — always map each label to a section `id` and use `scrollIntoView` with `preventDefault` (see "Navigation links" gotcha above)
- ❌ Never ship a navbar without verifying every link scrolls to its target section in dev mode
- ❌ Never hardcode data that belongs in the CMS (product lists, blog posts, form submissions, nav items) — load `mixcore:cms` first, confirm the MixDB table/module, then fetch via the Mixcore REST API at runtime
- ❌ Never write a form `POST` or data `GET` against `/api/...` without first using `mixcore:cms` to verify the endpoint and column schema exist

---
name: mix-verify-full-scan
description: Autonomous exploratory QA scan of a running Mixcore site — crawls all discovered pages (not just a known build list), checks render/console/forms/nav/section-contracts/a11y/mobile/auth, and produces a severity-tagged findings report. ScoutQA-style ad hoc scan; use anytime, not just post-build.
argument-hint: "[site-url] [category-filter or 'full']"
allowed-tools:
  - Bash
  - Read
---

You are running an **autonomous, crawl-based exploratory QA scan** of a running Mixcore site — not a check against a known list of pages a build just created (that's `mixcore:mix-verify-site` Mode A), but a full-site sweep that discovers its own scope and reports severity-tagged findings across eight categories.

## When to use

- Ad hoc, any time — "scan the whole site for bugs," "run a full QA pass," "check for accessibility issues," "find broken links." No prior build phase required.
- When you don't already know the full page list (unlike `mix-verify-site`, which checks pages a specific build phase was supposed to create).
- Before a release, after a batch of unrelated CMS changes, or when a user reports "something's broken somewhere" without a specific page.

Pair with: `mixcore:mix-verify-site` (known-page-list post-build check — use that instead when you already have `site-architecture.md`), `mixcore:mix-mcp-cms` / `mixcore:mix-mcp-db` (fix what this scan finds). Use Playwright MCP for the browser drive (load its `browser_*` tools first via `ToolSearch`, query: `playwright browser navigate snapshot click resize`).

### In-app equivalent — AIWebBuilder "Full Test"

The cloud portal ships a built-in subset of this scan: **AI → Web Builder → Full Test** (`AIWebBuilder.razor`). It crawls from the CMS page list, discovers + dedupes internal links (cap 50 pages), and per page checks: render status (500/CS/RZ codes), console errors, broken images/links, dead links (`href="#"`), MixDB form field↔column contract, and a site-level favicon check. Console capture includes **parse-time/boot errors**: the iframe loads pages with `?sim=1`, which makes `SimConsolePreviewMiddleware` inject an early error-capture snippet as the first thing in `<head>` (buffered in `window.__simErrors`). Findings render grouped per page with a severity summary, and a **Fix issues** button hands the full findings list to the Ask AI panel as one message. Findings wait for load-complete + verify the iframe pathname before attributing, so nothing leaks across pages.

Prefer the in-app Full Test when the user is in the portal and wants a quick QA pass + AI-driven fixes; prefer THIS skill when you need the categories it doesn't cover (a11y, responsive, auth/XSS, form submission round-trips) or a persisted wiki report.

---

## 0. Resolve the site URL

Same resolution as `mix-verify-site` §0 — derive `SITE_URL` from the connected `mcp__{server}__*` server's `url` in `.mcp.json` (strip `/mcp`), never hardcode `localhost:5000`. See `skills/mixcore/mcp-prefix.md` for the canonical procedure.

---

## 1. Discover pages — live crawl, not a known list

Unlike `mix-verify-site`, don't rely on `site-architecture.md`. Build the crawl frontier from live state:

1. `list_page_contents` — seed the frontier with every published page.
2. For each seeded page, `browser_navigate` + `browser_snapshot`, and collect every internal `<a href>` found in the accessibility tree.
3. **Normalize + dedupe** before enqueuing: reduce each href to its pathname (drop query/hash), trim the trailing `/`, and dedupe case-insensitively — `/shop`, `/shop/`, `/shop?page=2`, and `/shop#top` are ONE frontier entry. Skip non-page links: static assets (a dot-extension final segment other than `.html`) and infrastructure prefixes (`/api/`, `/p/`, `/a/`, `/mcp`, `/hubs/`, `/mixcontent/`).
4. Repeat until no new internal links appear (typically converges in 1-2 passes); `/db/{table}/{id}` detail routes are pages — include them.

Cap the frontier (default 50 pages) and report "coverage partial — frontier capped at N" rather than crawling unbounded. Record the final frontier size — it's the denominator for coverage reporting at the end.

---

## 2. Contract gate (run first — cheap, catches whole-site crashes)

Before spending browser time on individual pages:

```
validate_site_sections(mixThemeId)   # catches "sections defined but not rendered" crashes
validate_site_queries(mixThemeId)    # catches bad filterJson runtime crashes
```

If either returns `ok:false`, record every reported issue as a `critical` finding (category `section-contract`) — these crash every page that uses the offending master/template, so they dominate the report. Fixing them first (`SearchReplaceTemplate`/`UpdateTemplate`) before continuing to §3 avoids re-discovering the same root cause on every affected page.

---

## 3. Per-page pass

For every URL in the crawl frontier:

```
browser_navigate  <url>
browser_snapshot                            # a11y tree — assert real content, not an empty shell
browser_console_messages level=error        # must be clean
```

**Render/console findings (`render`, `console`):** flag HTTP 500 / yellow ASP.NET error pages / `CompilationFailedException` / any `console_messages` at `error` level. For a 500, `curl -s <url>` to capture the exact `CS*`/`RZ*` code in the response body (the browser screenshot only shows "Internal Server Error").

**Attribution guard:** wait for the page to actually finish loading before snapshotting/reading console — a slow page (CDN scripts, fonts) probed too early yields the PREVIOUS page's state attributed to the current URL. If a page doesn't reach load-complete within ~15s, record a `render`/`medium` finding ("did not finish loading — in-page checks skipped") and move on rather than mis-attributing.

**Broken-link findings (`broken-link`):** every internal link collected during crawl gets HEAD-checked ONCE (dedupe across the whole scan — a link on 5 pages is checked once); a non-200 (404/500) is a finding. External links: skip by default (out of scope — this scans the site, not the internet) unless the user asks for external-link checking too.

**Dead-link findings (`dead-link`):** links that go nowhere by construction — raw `href="#"`, empty `href`, `javascript:` handlers with no navigation, and `#anchor` fragments whose target id doesn't exist in the document. Common in LLM-generated nav bars ("Home/About/Contact" all `#`). Severity `medium`.

**Favicon finding (`favicon`):** check ONCE per scan (site-level, first page wins). If the page declares `<link rel="icon">` (or `shortcut icon` / `apple-touch-icon`), HEAD-check the same-origin href — a 404 is `medium` ("declared but missing"). If nothing is declared, HEAD-check the browser fallback `/favicon.ico` — a 404 is `low` ("no favicon at all"). `data:` and external-CDN favicons: skip.

**Accessibility findings (`a11y`):** from the same snapshot — flag images with no alt text, headings that skip a level (`h1`→`h3` with no `h2`), and interactive elements with no accessible name/role.

**Responsive findings (`responsive`):** `browser_resize` to a mobile width (375×812) and a tablet width (768×1024), re-snapshot each page. Flag horizontal overflow (content wider than viewport) and any element that becomes unreachable/hidden.

---

## 4. Forms pass

For every `frm-mixdb-ajax` form encountered during the crawl (check each page's snapshot/HTML for `class="frm-mixdb-ajax"` + `data-mixdb-table`):

1. `get_mix_db_by_system_name(<table>, includeColumns: true)` — the field contract.
2. Submit a realistic test payload through the actual form (Playwright `browser_fill_form` + submit) — don't call the REST endpoint directly, since that skips whatever client-side coercion (e.g. numeric-string-to-number) the page's own JS does.
3. `query_table(<table>)` — confirm the row landed with the submitted values.

**Form findings (`form-data`):** missing `frm-mixdb-ajax`/`data-mixdb-table` attributes (inert form), a submitted field with no matching column (silently dropped), a required column with no matching field (500 on submit), or no row appearing after a submit that returned success (silent black hole).

---

## 5. Auth pass

- Anonymous `curl -s -o /dev/null -w "%{http_code}" <SITE_URL>/p` and `/a` — expect a 302 redirect to a login page, not a 200 (leaked authenticated content) or a bare 401 (Mixcore's documented pattern is redirect-not-401 for these two prefixes).
- For any REST endpoint a discovered form POSTs to, an unauthenticated request should 401/404, never 200 with real data.
- One XSS probe per text input on each discovered form: submit `<script>alert(1)</script>` as the field value, then re-fetch the record (`query_table`) and confirm the stored/rendered value is HTML-escaped, not executed verbatim.

**Auth findings (`auth`):** any endpoint returning 200 where a redirect/401 was expected, or an XSS probe value that renders unescaped on any page displaying that data.

---

## 6. Report

Emit findings as a table, grouped by severity (`critical` > `high` > `medium` > `low`):

| Severity | Category | Page | Description | Evidence |
|---|---|---|---|---|

Severity guide:
- **critical** — section/query contract failures (crash every page using the template), any 500, any auth leak (200 where redirect/401 expected)
- **high** — console errors, broken internal links, form data silently dropped or not persisted
- **medium** — a11y violations, responsive overflow, unescaped XSS round-trip on non-sensitive fields, dead links (`href="#"` nav), a declared-but-404 favicon, a page that never finished loading
- **low** — cosmetic a11y (minor alt-text gaps), external-link 404s (if checked), missing favicon (nothing declared and `/favicon.ico` 404s)

End with a coverage line: `Scanned N pages, M forms, in <categories run>.` No external report link or service dependency (no `scoutqa` account) — this is entirely native MCP + Playwright. If the user wants the findings persisted, load `mixcore:mix-mcp-rag` and `generate_document` the report into the site wiki.

---

## Gotchas

- **Don't stop at HTTP 200.** A page can render 200 while console-erroring or showing an empty MixDB list — always pair the snapshot with the console-messages check.
- **Contract gate first, always.** Running the per-page pass before `validate_site_sections`/`validate_site_queries` means re-discovering the same crash on every page that shares the broken master — expensive and noisy.
- **`/p` and `/a` redirect, they don't 401.** An anonymous 302 to `/p/login` is correct Mixcore behavior, not a finding — only flag a bare 200.
- **Crawl convergence.** A site with many cross-linked pages can take more than 2 passes to converge; cap at 3 passes and report "coverage may be partial" rather than looping indefinitely.
- **Screenshots under `.playwright*/` only** (gitignored) — never `wwwroot/` or a committed directory.
- **Never build the main tree while `:5000` is live** — see `mix-verify-site`'s Gotchas for the same shared-`bin/` lock issue if this scan needs to run alongside other dev work.

---

## MCP Tools

<!-- mcp-tools:auto (generated by docs-sync; canonical names from live tools/list) -->
Crawls and drives pages with Playwright, then cross-checks contracts/data via these MCP read tools (exact `tools/list` names).

- **Contract gate** — `validate_site_sections`, `validate_site_queries`
- **Page/content discovery** — `list_page_contents`, `get_page_content_by_seo_name`, `list_templates`
- **Forms / data cross-check** — `get_mix_db_by_system_name`, `query_table`, `execute_query`
- **Wiki report (optional)** — `generate_document` (via `mixcore:mix-mcp-rag`)
<!-- /mcp-tools:auto -->

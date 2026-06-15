---
name: mix-verify-site
description: Smoke-test a built Mixcore site end-to-end against a running host — drive pages with Playwright, cross-check the DB (pages/templates/MixDB rows/AI plans), and (optionally) run a full fresh-install + AI-build in an isolated worktree. Use after building a site (mix-mcp-build-site, an AI site build, or CMS work) to confirm it actually renders and behaves — the browser/content counterpart to mix-verify-mcp.
argument-hint: "[site-url-or-'fresh'] [what-to-verify]"
allowed-tools:
  - Bash
  - Read
---

You are verifying that a **built Mixcore site** actually works against a *running* host — pages render, navigation resolves, MixDB-driven content shows, no console errors — and that the underlying data (pages, templates, MixDB rows, AI plans) matches. This is the **content/browser axis**; it is the counterpart to `mixcore:mix-verify-mcp` (which round-trips a `/mcp` tool but renders no pages).

## When to use

- After `mixcore:mix-mcp-build-site`, an **AI site build** (install-wizard "Describe Your Site"), or any CMS change, to confirm the site renders and behaves end-to-end.
- To smoke-test that a page, module, template, or MixDB-backed list shows real data in a browser — not just that a build is green or an MCP call returned 200.
- To run a **full fresh-install + AI-build** locally and watch it produce a browsable site.

Pair with: `mixcore:mix-mcp-build-site` / `mixcore:mix-mcp-cms` (build the thing), `mixcore:mix-mcp-db` (inspect MixDB), `mixcore:mix-verify-mcp` (tool-level round-trip). Use Playwright MCP for the browser drive (load its `browser_*` tools first via `ToolSearch`, query: `playwright browser navigate snapshot click`).

---

## 0. Resolve the site URL — never assume `localhost:5000`

Derive `SITE_URL` the same way the content router does (`skills/mixcore/mcp-prefix.md`): take the connected `mcp__{server}__*` server's `url` from `.mcp.json` and strip `/mcp`. Verify rendered content against **that** origin (e.g. `https://mixcore.cloud`), not a hardcoded localhost. Only when the user asks for a **fresh local install** (arg `fresh`) do you stand up your own host per §3.

Route prefixes on any Mixcore host: `/` landing · published pages at their SeoName (Home page = `/`) · `/db/{table}/{id}` MixDB detail · `/p` cloud portal (auth-gated) · `/a` admin · `/api` REST · `/mcp`.

---

## Mode A — verify an already-running site

### 1. Drive the pages (Playwright)

For each page the build was supposed to create:

```
browser_navigate  SITE_URL/<seoName>        (Home page is SITE_URL/)
browser_snapshot                            # read the a11y tree — assert real content, not an empty shell
browser_console_messages level=error        # must be clean
```

Assert the *specific contract*, not just HTTP 200: the Home page shows its hero/sections; a MixDB-driven list (menu, products, posts) renders **rows with real values**, not an empty table or `@Model`-leftovers; nav links point at the other pages and resolve. Screenshot evidence under `.playwright*/` **only** (gitignored) — never `wwwroot/` or a committed dir.

### 2. Cross-check the data behind the pages

A page can return 200 and still be empty. Confirm the rows exist. Prefer the MCP read tools (`mcp__{server}__get_pages_with_module`, `query_table`, `get_table_data`) when connected; for a local SQLite tenant, read the file directly (columns are **snake_case**):

```bash
DB=$(ls -t src/apps/MixCore.Cloud.Web/wwwroot/mixcontent/cms_*.sqlite | grep -vE "audit|queue|quartz" | head -1)
sqlite3 -header "$DB" "SELECT id,seo_name,type,status FROM mix_page_content;"      # Home (type=Home) + others, Published
sqlite3 -header "$DB" "SELECT id,file_name,folder_type FROM mix_template;"          # master + page templates
sqlite3 "$DB" ".tables" | tr ' ' '\n' | grep -v "^mix_\|^ai_"                       # MixDB tables the build created
```

A page whose `type=Home` and `status=Published` exists ⇒ the site root is browsable. No `type=Home` row ⇒ the build never produced an entry point (an AI build that stalled — see §4).

---

## Mode B — full fresh install + AI build (arg `fresh`)

Stand up a clean instance and drive the install wizard (or your build flow) from zero. Do this in an **isolated worktree on its own `mixcontent`** so you never disturb the user's `:5000` app.

🚨 **Run AI builds over HTTPS.** The installer stores `McpEndpoint = https://{host}`, and the AI build agent calls that loopback `/mcp` to run its CRUD steps. On an **HTTP-only** dev run those calls fail the TLS handshake (`AuthenticationException: Cannot determine the frame size or a corrupted frame was received` → "SSL connection could not be established") and every create-step errors while planning/discovery still "succeed". Serve HTTPS so the loopback resolves:

```bash
dotnet dev-certs https --check --trust          # must report a trusted cert
# fresh-install reset (mixcontent is gitignored; settings carry InitStatus):
rm -f  src/apps/MixCore.Cloud.Web/wwwroot/mixcontent/cms_*.sqlite*
rm -rf src/apps/MixCore.Cloud.Web/wwwroot/mixcontent/{templates,uploads,documents}
cp     src/apps/MixCore.Cloud.Web/wwwroot/default-mixcontent/setting-files/*.json \
       src/apps/MixCore.Cloud.Web/wwwroot/mixcontent/setting-files/      # resets InitStatus → Blank
ASPNETCORE_ENVIRONMENT=Development ASPNETCORE_URLS=http://localhost:5000 \
  nohup dotnet run --project src/apps/MixCore.Cloud.Web --no-build > /tmp/mixrun.log 2>&1 &
# readiness:
for i in $(seq 1 45); do curl -sk -o /dev/null -w "%{http_code}" http://localhost:5000/init | grep -q 200 && { echo READY; break; }; sleep 2; done
```

The platform DB can be **SQLite** for a local install (pick SQLite at the Database step) — no Postgres needed. Drive the wizard with Playwright: Database (SQLite) → Account → AI Setup (add a real provider key, e.g. DeepSeek `base_url https://api.deepseek.com`, set a model) → Theme Setup (choose **Describe Your Site (AI)**, fill the description, optionally upload a `.txt/.md/.json` doc) → Complete → **Complete Installation & Start AI Build**. The build is dispatched only at Complete (after `InitStatus=Done`).

### Watch the build, and continue it if it stalls

The agent runs in the background; poll the plan (a real build is multi-minute):

```bash
DB=$(ls -t src/apps/MixCore.Cloud.Web/wwwroot/mixcontent/cms_*.sqlite | grep -vE "audit|queue|quartz" | head -1)
sqlite3 "$DB" "SELECT status,completed_steps||'/'||total_steps FROM ai_plans;"
sqlite3 "$DB" "SELECT step_number,status,substr(description,1,50) FROM ai_plan_steps ORDER BY step_number;"
grep -iE "mcp|SSL|frame size|IsError|completed\." /tmp/mixrun.log | tail
```

A plan turn ends in **`Incomplete`** (not `Failed`) when the budget runs out with steps still pending — this is normal for a big build. Drive it to completion by **continuing** it (each continue runs one more turn; repeat until `Completed` or `total_steps` are all done):

```bash
JWT=$(curl -sk -X POST http://localhost:5000/api/v1/rest/auth/login -H 'Content-Type: application/json' \
  -d '{"userName":"admin","password":"<pwd>"}' | python3 -c "import sys,json;print(json.load(sys.stdin)['result']['accessToken'])")
curl -sk -X POST http://localhost:5000/api/v1/ai/plans/<id>/continue -H "Authorization: Bearer $JWT"   # 202 → re-runs
```

Then verify the produced site with **Mode A** (load `/`, the menu/list pages, check rows + console). The plan-detail page is `/p/ai/plan-detail/{id}` — but `/p` is `[Authorize]`, so an unauthenticated hit 302s to `/p/login?returnUrl=…`; sign in (admin) and the returnUrl lands you on the plan.

### Teardown

```bash
lsof -ti :5000 -ti :1883 | xargs kill -9 2>/dev/null   # frees HTTP + the MQTT broker (binds TCP 1883)
# remove any stray screenshots the run left at the repo root
find . -maxdepth 2 -name "*.png" -path "*playwright*" -delete 2>/dev/null
```

---

## Gotchas

- **Don't trust a clean build or a 200.** A page renders 200 while empty; an MCP create returns success while the row is wrong. Always assert the *content* (Mode A snapshot) AND the *data* (DB/MCP read).
- **AI build CRUD needs HTTPS loopback** — see §B. The single most common reason a "successful install" produces an empty site is the agent's `http://localhost:5000/mcp` calls failing on an HTTP run.
- **No `type=Home` page ⇒ no browsable root.** The completion redirect keys off this: with no Home page the wizard sends you to `/p`, not `/`. If the AI build is mid-flight, the Home page may not exist yet — continue the plan, then re-check.
- **`/p` and `/a` are auth-gated** — an anonymous request 302s to `/p/login` (HTML), not 401. Gate-first / sign in before asserting portal content. (Same pattern as the chat-widget auth redirect.)
- **Never build the main tree while `:5000` is live** — shared `bin/` locks/replaces DLLs and takes the app + its MCP server down. Use an isolated worktree (own `bin/obj`) and an alternate port, or stop `:5000` first.
- **MQTT** binds TCP `1883` (MQTTnet default) — a second instance can't co-bind it; stop the first or accept the swallowed bind error (HTTP/`/mcp` still serve).
- **Screenshots under `.playwright*/` only** (gitignored) — never `wwwroot/` or a committed directory.

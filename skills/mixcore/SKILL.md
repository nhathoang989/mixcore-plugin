---
name: mixcore
description: Entry point for CONTENT tasks in Mixcore CMS — routes to the mixcore:* skill that uses MCP tools to CRUD content (templates, pages, modules, posts, MixDB tables/rows, site wiki, AI chat widget). Content only — MCP tools ONLY; never edits repo source code and never switches to mixcore:mixdev from here. Server-side bugs or code-requiring needs are escalated as GitHub issues and handed back to the user. Trigger on "mixcore", "mixcore:*", or any templates / MixDB / pages / modules / posts / wiki / website-content task. To keep skill↔system-prompt docs in sync use mixcore:docs-sync.
argument-hint: "<describe your task — auto-routes to the right mixcore:* skill>"
---

# Mixcore Skill Router

> **Scope:** this router covers **content CRUD via MCP tools only** — templates, pages, modules, posts, MixDB schema/rows, the site wiki, and the AI chat widget. It never edits repo source code. Sibling routers: **`mixcore:mixdev`** (AI edits C#/Blazor source to implement features) · **`mixcore:docs-sync`** (CRUD developer docs, keep skills ↔ system-prompts consistent).

> ## 🚨 HARD RULE — `/mixcore:mixcore` is MCP-only; never touch source code
>
> In a `/mixcore:mixcore` session you interact with the running server **exclusively through MCP tools**. You must **NEVER**, from here:
> - invoke `mixcore:mixdev` (or any `mix-dev-*` skill),
> - edit, create, or delete repo source code (`.cs`, `.razor`, `.csproj`, config),
> - run `dotnet build` / `dotnet run` / `dotnet test`, restart the app, or open a git worktree/branch to change code.
>
> If a task turns out to need a source-code change — or you hit a **server-side bug, a missing/broken endpoint, or any capability only a code change can provide** — do **not** switch skills and do **not** fix it yourself. Instead: **STOP → create a GitHub issue → tell the user the issue number + link → wait for the user to decide what happens next.** See [GitHub Issue Escalation](#github-issue-escalation). The user owns all decisions about code/server work; your job here is MCP content work plus surfacing blockers as issues.

When invoked with a task (e.g. `/mixcore:mixcore create a contact form` or `/mixcore:mixcore add a price column to products`), you **must**:

1. **Resolve the MCP server** (see Step 0 below — one-time setup, then cached)
2. **Search the wiki** — `{MCP_PREFIX}search(query: "<task subject>")` (see Step 1 below)
3. **Load live site state via MCP tools** (see Step 2 below)
4. Match the task to ONE row in the Skill Map below (closest match wins; never ask)
5. **Invoke that skill via the `Skill` tool** — do not paraphrase or "act as" the skill
6. After it loads, execute the task using the loaded context

If the task needs multiple skills, run the combination pattern in order. The first skill in the chain is the one to invoke immediately.

> **Tool naming:** Throughout this skill every tool reference is written as `mcp__mixcore__<tool>`.
> Replace `mcp__mixcore__` with `{MCP_PREFIX}` resolved in Step 0.
> Example: if `MCP_PREFIX = mcp__mixcore-bk__`, then `mcp__mixcore__search` → `mcp__mixcore-bk__search`.

---

## Step 0 — Resolve MCP Server (one-time, then cached)

**Do this before any MCP call.**

### 0a. Check for saved preference

Use the `Read` tool to read `plugins/mixcore/skills/mixcore/server-config.md`.

- **If the file exists and contains a server name** → set `MCP_PREFIX = mcp__{server-name}__` and skip to Step 1.
- **If the file does not exist** → proceed to 0b.

### 0b. Detect available servers

Read `.mcp.json` in the repo root. Find all server keys whose name contains "mixcore" (e.g. `mixcore`, `mixcore-bk`). Build a list of `(name, url)` pairs from the `mcpServers` object.

### 0c. Ask the user which server to use

Call `AskUserQuestion` with one question. Present one option per discovered Mixcore server plus an "Other" option for a custom name:

```
Question: "Which Mixcore MCP server should this skill use?"
Header: "MCP server"
Options:
  - label: "<name>"  description: "<url from .mcp.json>"   ← one per discovered server
```

Pick the first discovered server as the default (recommended). If only one server exists, skip the question and use it automatically.

### 0d. Save the selection

Write the chosen server name (just the key, e.g. `mixcore-bk`) to `plugins/mixcore/skills/mixcore/server-config.md`:

```markdown
# Mixcore MCP Server Config
server: mixcore-bk
```

Use the `Write` tool to create the file. Then set `MCP_PREFIX = mcp__{chosen-name}__`.

> **Reset:** The user can delete `plugins/mixcore/skills/mixcore/server-config.md` at any time to be asked again on the next invocation.

---

## Step 1 — Search the Site Wiki First (via mixcore:mix-mcp-rag)

**Before routing or executing**, search the wiki knowledge base to understand what has already been built. This prevents duplicate work and wrong IDs.

> For all wiki document operations (search, read, create, list, delete) load the **`mixcore:mix-mcp-rag`** skill.

```
{MCP_PREFIX}search(query: "<describe what you need>", topK: 5)
# e.g. mcp__mixcore__search(...)  or  mcp__mixcore-bk__search(...)
```

Returns a JSON array of `{ Id, Title, Content, Score, Source }` ranked by relevance. Increase `topK` (e.g. `10`) when the task touches multiple content types at once.

| Task involves… | Search query |
|---|---|
| Pages | `"site pages slugs template IDs layout"` |
| Templates | `"templates master layout IDs folder"` |
| Modules | `"modules widget template IDs system name"` |
| Posts | `"posts articles slugs"` |
| Forms | `"forms newsletter contact MixDB table"` |
| MixDB table | `"<table-name> schema columns relationships"` |
| Phased / planned work | `"site planning phases progress"` |
| Any general task | Use the task subject as the query |

**When you need to read, create, or delete a specific wiki doc** — invoke **`mixcore:mix-mcp-rag`** and use `{MCP_PREFIX}read_document`, `{MCP_PREFIX}generate_document`, or `{MCP_PREFIX}delete_document`. Never use raw `read_text_file`/`write_text_file` for wiki files.

If search returns no relevant results (new site with no wiki yet), skip to Step 2.

---

## Step 2 — Load Live Site State via MCP Tools

After reading the wiki, use MCP tools to confirm the current live state. This catches anything not yet documented.

Use `ToolSearch` with the resolved tool names (substitute `mcp__mixcore__` → `{MCP_PREFIX}`) to load schemas, then call:

| When the task involves… | Load these first |
|---|---|
| Pages, templates, layout | `{MCP_PREFIX}list_page_contents` + `{MCP_PREFIX}list_templates` |
| MixDB tables, schema, rows | `{MCP_PREFIX}get_tables` + `{MCP_PREFIX}get_table_schema` |
| Modules, widgets | `{MCP_PREFIX}list_module_contents` |
| Posts, articles | `{MCP_PREFIX}list_post_contents` |
| Relationships | `{MCP_PREFIX}list_relationships` |
| Full site audit | all of the above |

**Quick context fetch** — run in parallel for general tasks:
```
{MCP_PREFIX}list_page_contents  (pageSize: 20)
{MCP_PREFIX}list_templates      (pageSize: 20)
{MCP_PREFIX}get_tables
```

Use `{MCP_PREFIX}get_page_content_by_seo_name` or `{MCP_PREFIX}get_mix_db_by_system_name` to look up a specific item when you already have a name.

---

## Skill Map

| Task signal | Skill |
|---|---|
| `.cshtml` template, CMS page/module/post, MixDB-driven content rendering | `mixcore:mix-mcp-cms` |
| MixDB table/column/relationship schema, seed rows (no rendering) | `mixcore:mix-mcp-db` |
| Embed a **built SPA** (Vite/React/Vue/Svelte/Next-static) as a Mixcore page with `layoutId=null` — **only when the user explicitly requests `mixcore:mix-mcp-spa` or says they have a `dist/` folder to deploy** | `mixcore:mix-mcp-spa` |
| Complete website from a brief — phased plan, schema + templates + pages; **also the default for any React/Vue/Svelte/frontend page/landing page request unless `mixcore:mix-mcp-spa` is explicitly requested** | `mixcore:mix-mcp-build-site` |
| **AI chat widget** on a CMS page — floating/drawer chat, SiteKnowledgeHub SignalR wiring, streaming, login/token, auth-failure handling | `mixcore:mix-mcp-ai` |
| **Wiki / knowledge base / RAG** — search the site wiki, create/read/list/delete wiki docs, manage the RAG index | `mixcore:mix-mcp-rag` |
| **Scheduled (cron) jobs** — recurring time-based jobs that fire a single Webhook or QueuePublish action; create/list/update/toggle/run-now, read run history (mix.ai `/mcp` SchedulerTool) | `mixcore:mix-schedule` |
| **Flows workflows** — webhook/manual/queue-triggered, multi-step automations (HttpRequest, SendEmail, SignalRBroadcast, QueuePublish); create/trigger/monitor/cancel runs (mix.ai `/mcp` Flows tools) | `mixcore:mix-mcp-flows` |
| Coding / backend / Blazor / .NET source change, **or** a server-side bug / missing capability that blocks an MCP task | 🚨 **STOP — do not switch to `mixcore:mixdev` and do not edit source.** File a GitHub issue, report it to the user, and await their decision. See [GitHub Issue Escalation](#github-issue-escalation). |

---

## Combination Patterns (first skill = invoke now)

- **New table + page that reads it** → `mixcore:mix-mcp-db` → `mixcore:mix-mcp-cms`
- **Build a landing page, marketing site, or any frontend page** → `mixcore:mix-mcp-build-site` (Razor/CMS templates, all phases)
- **Only when user explicitly says "use mixcore:mix-mcp-spa" or "I have a built dist folder"** → `frontend-design` (build the SPA) → `mixcore:mix-mcp-spa` (install into Mixcore)
- **AI chat widget on a page** → `mixcore:mix-mcp-ai` (hub/streaming/auth wiring) + `mixcore:mix-mcp-cms` (widget HTML/CSS in the template content field)
- **"Run X on a schedule / every N minutes" (single action)** → `mixcore:mix-schedule` (cron job → Webhook or QueuePublish)
- **"When X happens, do A then B then C" (event/webhook trigger, multi-step)** → `mixcore:mix-mcp-flows`

> **Scheduler vs Flows:** time-based + one action → `mixcore:mix-schedule`. Webhook/manual/queue trigger or multi-step pipeline → `mixcore:mix-mcp-flows`. A Flows `Schedule` trigger overlaps for simple recurring single actions — prefer `mixcore:mix-schedule` when there are no extra steps.

- **A task that mixes CMS content with a code/server need** → do the content part here via MCP (`mixcore:mix-mcp-cms` / `mixcore:mix-mcp-db`); for the code/server part, **file a GitHub issue and report to the user — never switch to `mixcore:mixdev` from a `/mixcore:mixcore` session.**

---

## Boundary Rules

- **`mixcore:mix-mcp-cms` vs `mixcore:mix-mcp-db`**: `mixcore:mix-mcp-db` is schema-only. The moment a `.cshtml` template, page, or `Model.GetModule(...)` is involved, switch to `mixcore:mix-mcp-cms`.
- **`mixcore:mix-mcp-build-site` is the default for all website/landing page requests** — including React, Svelte, Vue, or "build a page" requests. It uses Razor/CMS templates and covers all phases automatically.
- **`mixcore:mix-mcp-spa` is opt-in only**: use it exclusively when the user explicitly says "use mixcore:mix-mcp-spa", "I have a dist folder", "embed a built SPA", or names `mixcore:mix-mcp-spa` directly. Never infer it from the tech stack alone.
- **CMS vs coding**: If the task needs `.razor` components, C# services, `dotnet build`, EF migrations, or module scaffolding — **do not route to `mixcore:mixdev` and do not edit source from here.** STOP, file a GitHub issue, report it, and await the user's decision (see [GitHub Issue Escalation](#github-issue-escalation)). The user drives whether and when code work happens.
- **`mixcore:mix-mcp-ai` vs `mixcore:mix-mcp-cms`**: `mixcore:mix-mcp-ai` owns the chat *behavior* (SignalR hub, `AskAI`, streaming handlers, auth/token). The widget's *HTML/CSS* (drawer, overlay, login form, bubbles) lives in the template content field and is `mixcore:mix-mcp-cms`'s job. A typical widget task uses both.

---

## GitHub Issue Escalation

A `/mixcore:mixcore` session **never edits source and never hands off to `mixcore:mixdev`**. When you hit something MCP tools cannot do — a server-side bug, a missing or broken endpoint, or a needed schema/feature that only a code change provides — **escalate, don't fix**:

1. **Confirm it's real** — reproduce it through MCP/HTTP 2–3 times and rule out a bad parameter or stale cache. Do not retry the same failing call more than 2–3 times.
2. **File a GitHub issue** (the only write to the codebase you may make from here):
   ```bash
   gh issue create --repo mixcore-cloud/platform \
     --title "bug: <short description>" \
     --body "**Context:** hit during a /mixcore:mixcore (MCP-only) session.
   **Steps to reproduce:** ...
   **Expected:** ...
   **Actual:** ...
   **File (if known):** path/to/file.cs:line"
   ```
3. **Report to the user** — give the issue number + URL, a one-line summary, and exactly what it blocks.
4. **Stop and wait.** Do **not** open a worktree, edit code, run `dotnet`, restart the server, or invoke `mixcore:mixdev`. The user decides the next step and will tell you what to do.

Everything else continues through MCP tools as normal — only the blocked, code-requiring part becomes an issue.

---

## MCP Tool Reference

All Mixcore MCP tools follow snake_case naming. Load schemas via `ToolSearch` before first use. Replace `mcp__mixcore__` in every tool name below with `{MCP_PREFIX}` resolved in Step 0.

**Key tool groups:**

| Group | Representative tools |
|---|---|
| Templates | `create_template`, `get_template`, `update_template`, `list_templates` |
| Pages | `create_page_content`, `get_page_content_by_seo_name`, `list_page_contents`, `update_page_content` |
| Modules | `create_module_content`, `list_module_contents`, `get_module_content_by_system_name` |
| Posts | `create_post_content`, `list_post_contents`, `get_post_content_by_seo_name` |
| MixDB schema | `get_tables`, `get_table_schema`, `create_mix_db_table`, `create_mix_db_table_from_prompt` |
| MixDB columns | `add_column_to_table`, `update_table_column`, `delete_table_column`, `list_columns` |
| MixDB rows | `create_row`, `update_row`, `delete_row`, `query_rows`, `query_table` |
| Relationships | `create_relationship`, `list_relationships`, `get_relationships_by_parent_table` |
| Smart queries | `smart_query`, `parse_smart_query` |
| Associations | `create_page_module_association`, `create_page_post_association`, `create_module_post_association` |
| Wiki / RAG | `search` (discover), `read_document`, `generate_document`, `list_documents`, `delete_document`, `reload_wiki` — load **`mixcore:mix-mcp-rag`** for all wiki doc ops |
| Files (non-wiki) | `read_text_file`, `write_text_file`, `list_text_files` — planning docs only; never use for wiki |
| DB inspect | `execute_query`, `get_tables`, `get_table_data` |
| Utility | `fetch` (URL fetch), `echo` (connectivity test) |

Full signatures: use `ToolSearch` with `select:{MCP_PREFIX}<tool_name>` (e.g. `select:mcp__mixcore-cloud__search`) to load live schemas from the server.

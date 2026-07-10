# mixcore plugin

The Mixcore CMS skill suite for Claude Code, bundled as one installable plugin. All skills are namespaced under
`mixcore:` (the plugin name), and each skill's own name announces its router family: content/MCP leaves are
prefixed **`mix-mcp-*`**, code leaves **`mix-dev-*`**, and the routers are **`mixcore`** (content) and
**`mixdev`** (code), alongside **`docs-sync`**.

## Install

This repo **is** the plugin's marketplace (`.claude-plugin/marketplace.json` + `.claude-plugin/plugin.json` at the
repo root). To use the skills from any project:

```
/plugin marketplace add nhathoang989/mixcore-plugin
/plugin install mixcore@mixcore
```

### Used as a submodule of `mixcore-cloud/platform`

The [`platform`](https://github.com/mixcore-cloud/platform) repo vendors this repo as a git submodule at
`plugins/mixcore/` and dogfoods it — its `.claude/settings.json` declares `extraKnownMarketplaces.mixcore` →
this repo and enables `mixcore@mixcore`. After cloning platform, pull the submodule:

```
git submodule update --init plugins/mixcore
```

For local development on a checkout of **this** repo, register it as a marketplace from its own root:

```
/plugin marketplace add .
```

## Skills

Two routers sit on top and delegate to the leaf skills:

| Skill | Invoke | Role |
|---|---|---|
| `mixcore:mixcore` | `/mixcore:mixcore` | **Content router** — templates, pages, modules, posts, MixDB, wiki (MCP tools) |
| `mixcore:mixdev` | `/mixcore:mixdev` | **Code router** — C#, Blazor, modules, migrations, tests |
| `mixcore:docs-sync` | `/mixcore:docs-sync` | Keep `plugins/mixcore/skills/` ↔ `wwwroot/system-prompts/` docs consistent |
| `mixcore:mix-mcp-cms` | `/mixcore:mix-mcp-cms` | MCP-first website building — templates, schemas, content, smart queries |
| `mixcore:mix-mcp-db` | `/mixcore:mix-mcp-db` | MixDB dynamic tables, columns, relationships, row CRUD |
| `mixcore:mix-mcp-ai` | `/mixcore:mix-mcp-ai` | AI chat widget — SiteWikiHub SignalR, streaming, auth/token |
| `mixcore:mix-mcp-rag` | `/mixcore:mix-mcp-rag` | Site wiki / knowledge base — search, create, read, list, delete |
| `mixcore:mix-mcp-spa` | `/mixcore:mix-mcp-spa` | Embed a built SPA (Vite/React/Vue/Svelte) with `layoutId=null` |
| `mixcore:mix-mcp-build-site` | `/mixcore:mix-mcp-build-site` | Complete website from a brief — phased plan + schema + templates + pages || `mixcore:mix-mcp-flows` | `/mixcore:mix-mcp-flows` | Flows workflows — webhook/manual/queue triggers, multi-step actions, run history |
| `mixcore:mix-mcp-schedule` | `/mixcore:mix-mcp-schedule` | Scheduled cron jobs — recurring single Webhook/QueuePublish action, run-now, history |
| `mixcore:mix-verify-site` | `/mixcore:mix-verify-site` | Verify a built site — Playwright page drive + DB/MCP data cross-check; optional fresh-install + AI-build run |
| `mixcore:mix-verify-full-scan` | `/mixcore:mix-verify-full-scan` | Ad hoc crawl-based exploratory QA scan — render/console/forms/links/a11y/mobile/auth, severity-tagged report |
| `mixcore:mix-verify-mcp` | `/mixcore:mix-verify-mcp` | Round-trip-verify an MCP tool against a running host (isolated worktree + alt port) |
| `mixcore:mix-dev-module` | `/mixcore:mix-dev-module` | Scaffold a module (new project or add to existing) |
| `mixcore:mix-dev-dotnet-code` | `/mixcore:mix-dev-dotnet-code` | C# 12 / .NET 10 — ViewModels, CQRS handlers, EF Core |
| `mixcore:mix-dev-dotnet-cli` | `/mixcore:mix-dev-dotnet-cli` | `dotnet` build / test / run / migrations / packages |
| `mixcore:mix-dev-migration` | `/mixcore:mix-dev-migration` | EF Core migrations across all 4 provider contexts |
| `mixcore:mix-dev-tests` | `/mixcore:mix-dev-tests` | xUnit controller / migration / installation tests || `mixcore:mix-dev-blazor-app` | `/mixcore:mix-dev-blazor-app` | Blazor Web App components, pages, services, render modes |
| `mixcore:mix-dev-blazor-blueprint` | `/mixcore:mix-dev-blazor-blueprint` | shadcn-style dashboards via BlazorBlueprint.Components |

See each skill's `SKILL.md` under `skills/` for details.

## How it works

You usually don't invoke leaf skills directly — you describe a task (or type a router
command) and a **router** delegates:

- **`mixcore`** (content) — resolves the Mixcore MCP server (see
  [`skills/mixcore/mcp-prefix.md`](skills/mixcore/mcp-prefix.md)), searches the site wiki,
  loads live site state, then invokes the matching `mix-mcp-*` leaf (templates, MixDB,
  pages/modules/posts, wiki, AI widget).
- **`mixdev`** (code) — routes source-code work to the matching `mix-dev-*` leaf (C#/.NET,
  Blazor, modules, EF migrations, tests) and composes companion plugins where useful.
- **`docs-sync`** — keeps `skills/*` and the platform repo's `wwwroot/system-prompts/`
  mirrored.

## Requirements

- **A Mixcore MCP server** for the content (`mixcore` / `mix-mcp-*`) skills — see
  [`skills/mixcore/mcp-prefix.md`](skills/mixcore/mcp-prefix.md).
- **Optional companion plugins** used by some `mixdev` workflows: `superpowers:*`
  (plan implementation / code review) and the `dotnet-*` skill plugins (test, build,
  diagnostics). Install them separately; if absent, those steps are simply skipped.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the skill-authoring checklist, naming
convention, and the `scripts/validate.sh` invariants (run in CI on every PR).

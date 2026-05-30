# mixcore plugin

The Mixcore CMS skill suite for Claude Code, bundled as one installable plugin. All skills are namespaced under
`mixcore:` — the plugin name carries identity, so the skills drop the old `mix-`/`mixcore-` prefixes.

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
| `mixcore:guide` | `/mixcore:guide` | **Content router** — templates, pages, modules, posts, MixDB, wiki (MCP tools) |
| `mixcore:dev` | `/mixcore:dev` | **Code router** — C#, Blazor, modules, migrations, tests |
| `mixcore:docs-sync` | `/mixcore:docs-sync` | Keep `plugins/mixcore/skills/` ↔ `wwwroot/system-prompts/` docs consistent |
| `mixcore:cms` | `/mixcore:cms` | MCP-first website building — templates, schemas, content, smart queries |
| `mixcore:db` | `/mixcore:db` | MixDB dynamic tables, columns, relationships, row CRUD |
| `mixcore:ai` | `/mixcore:ai` | AI chat widget — SiteKnowledgeHub SignalR, streaming, auth/token |
| `mixcore:rag` | `/mixcore:rag` | Site wiki / knowledge base — search, create, read, list, delete |
| `mixcore:spa` | `/mixcore:spa` | Embed a built SPA (Vite/React/Vue/Svelte) with `layoutId=null` |
| `mixcore:build-site` | `/mixcore:build-site` | Complete website from a brief — phased plan + schema + templates + pages |
| `mixcore:module` | `/mixcore:module` | Scaffold a module (new project or add to existing) |
| `mixcore:dotnet-code` | `/mixcore:dotnet-code` | C# 12 / .NET 10 — ViewModels, CQRS handlers, EF Core |
| `mixcore:dotnet-cli` | `/mixcore:dotnet-cli` | `dotnet` build / test / run / migrations / packages |
| `mixcore:migration` | `/mixcore:migration` | EF Core migrations across all 4 provider contexts |
| `mixcore:tests` | `/mixcore:tests` | xUnit controller / migration / installation tests |
| `mixcore:blazor-app` | `/mixcore:blazor-app` | Blazor Web App components, pages, services, render modes |
| `mixcore:blazor-blueprint` | `/mixcore:blazor-blueprint` | shadcn-style dashboards via BlazorBlueprint.Components |

See each skill's `SKILL.md` under `skills/` for details.

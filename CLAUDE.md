# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

This is **not application code** — it is the `mixcore` **Claude Code plugin**: a suite of
Skills (Markdown + YAML frontmatter) that drive Claude Code when working *in* the
**Mixcore CMS / `mixcore-cloud` platform** repo. The deliverables here are skill prompts and
their reference docs, plus the plugin/marketplace manifests. There is no compiler, test runner,
or lint step — "correctness" is about prompt content and the cross-reference invariants below.

The repo **is its own marketplace**: `.claude-plugin/marketplace.json` (lists the `mixcore`
plugin) and `.claude-plugin/plugin.json` (plugin manifest, `version`) live at the root.

## Install / develop

```sh
# Local dev on this checkout — register the repo itself as a marketplace, then install:
/plugin marketplace add .
/plugin install mixcore@mixcore

# Or from GitHub:
/plugin marketplace add nhathoang989/mixcore-plugin
/plugin install mixcore@mixcore

# This repo is normally vendored as a submodule of mixcore-cloud/platform at plugins/mixcore/:
git submodule update --init plugins/mixcore
```

After editing a skill, reload it in the consuming session (re-run `/plugin install` or restart
Claude Code) — skills are read at load time.

> **Git gotcha:** in a standalone checkout the `.git` is a *gitlink file* pointing at a
> superproject that isn't present, so plain `git` commands fail
> (`fatal: not a git repository: …/.git/modules/plugins/mixcore`). Use `gh` for PRs/issues, and
> expect a detached HEAD. Real git work happens from the `platform` superproject.

## Validation (run before committing skill edits)

These greps encode the invariants the `docs-sync` skill enforces. The PR that role-prefixed the
skill names relied on exactly these checks:

```sh
# 1. Every skill dir name MUST equal its `name:` frontmatter.
for d in skills/*/; do n=$(basename "$d"); \
  fm=$(grep -m1 '^name:' "$d/SKILL.md" | sed 's/name:[[:space:]]*//'); \
  [ "$n" = "$fm" ] || echo "MISMATCH: dir=$n name=$fm"; done

# 2. No leftover old short tokens after a rename (guide/dev/cms/db/ai/rag/spa/… without prefix).
grep -rnE 'mixcore:(guide|dev|cms|db|ai|rag|spa|build-site|module|dotnet-code|dotnet-cli|migration|tests|blazor-app|blazor-blueprint)([^a-z-]|$)' skills README.md .claude-plugin

# 3. No stale skills/<old-name>/ path references.
grep -rn 'skills/\(cms\|db\|ai\|rag\|spa\|guide\|dev\|build-site\|module\|tests\|migration\|dotnet-code\|dotnet-cli\|blazor-app\|blazor-blueprint\)/' skills
```

## Architecture

### Skill layout & naming

Each skill is `skills/<name>/SKILL.md` with YAML frontmatter (`name`, `description`, often
`argument-hint` and `allowed-tools`). Larger skills use **progressive disclosure**: the SKILL.md
is a thin index that loads files from a sibling `references/` dir on demand (e.g.
`skills/mix-mcp-cms/references/razor-rules.md`). Invoked as `mixcore:<name>` /
`/mixcore:<name>`.

Naming announces the skill's family (see README table):
- **Routers:** `mixcore` (content), `mixdev` (code) — sit on top and delegate to leaves.
- **`mix-mcp-*`** — content/MCP leaves: `cms`, `db`, `ai`, `rag`, `spa`, `build-site`.
- **`mix-dev-*`** — source-code leaves: `module`, `dotnet-code`, `dotnet-cli`, `migration`,
  `tests`, `blazor-app`, `blazor-blueprint`.
- **`docs-sync`** — the documentation sibling (unprefixed).

### Two axes of work

The suite splits along *how* Claude acts on the target platform:

- **Content axis — MCP-first (`mixcore` router → `mix-mcp-*`).** These operate a *running*
  Mixcore CMS through MCP tools (`mcp__{server}__*`), never by editing CMS files directly, so
  changes register migrations, broadcast via SignalR, and invalidate cache. The router resolves
  `{MCP_PREFIX}` and `{SITE_URL}` in a "Step 0" **dynamically from the connected MCP session**
  (canonical procedure: `skills/mixcore/mcp-prefix.md`): detect the connected
  `mcp__{server-name}__*` server (never hardcoded/persisted — no config file), and derive
  `SITE_URL` from that server's `url` in `.mcp.json` (strip `/mcp`) for all browser
  verification and reported links. Leaves assume both are already resolved when reached via
  the router. Wiki docs are managed through the
  `mix-mcp-rag` tools, **not** file writes (file writes bypass the RAG index).

- **Code axis — source edits (`mixdev` router → `mix-dev-*`).** These edit C# 12 / .NET 10 /
  Blazor source in the `mixcore-cloud` solution: ViewModels (mix.heart), CQRS handlers, EF Core
  across **4 provider contexts** (SQLite, PostgreSQL, MySQL, SqlServer), module scaffolding
  (`IStartupService` self-registration), xUnit tests, and Blazor apps.

### docs-sync invariant (the cross-repo contract)

Mixcore keeps **two documentation locations that must mirror each other**:
`plugins/mixcore/skills/*` (these Claude Code skills) and `wwwroot/system-prompts/` (the in-app
Mix AI engine). The `docs-sync` SKILL.md holds the authoritative File-Mapping table (which skill
file pairs with which system-prompt file). When you change a skill that has a counterpart, update
the mirror — and keep that mapping table current when adding/renaming skills.

### Target-repo paths referenced by skills (not in this repo)

Skills frequently reference paths in the *consuming* platform repo — `src/modules/`, `src/apps/`,
`src/cloud/`, `wwwroot/mixcontent/` (`planning/`, `documents/wiki/`), `wwwroot/system-prompts/`.
Don't expect these here; this repo contains only the skills and manifests.

## Conventions when editing skills

- Keep SKILL.md as a router/index; push depth into `references/`. Match the existing thin-index
  style of neighboring skills.
- A skill's `name:` and its directory name must stay identical (validation #1). Renaming a skill =
  rename the dir, the frontmatter, every cross-reference, reference-file headers, and the
  `docs-sync` mapping table — then run all three validation greps.
- Cross-skill pointers use the `mixcore:<name>` form (e.g. "delegate to `mixcore:mix-mcp-cms`").
- Bump `version` in `.claude-plugin/plugin.json` for releases.

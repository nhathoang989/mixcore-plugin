# Contributing to the mixcore plugin

This repo is the **mixcore Claude Code plugin** — a suite of Skills (`skills/<name>/SKILL.md`)
plus the marketplace/plugin manifests under `.claude-plugin/`. There is no build or test
toolchain; correctness is about skill content and a few structural invariants enforced by
`scripts/validate.sh` (run in CI on every PR).

## Validate before you push

```sh
bash scripts/validate.sh
```

It checks: each skill dir name equals its `name:` frontmatter; no leftover old
`mixcore:<short>` tokens; no stale `skills/<old>/` path references; no machine-absolute
paths (e.g. `C:\…`, `/Users/…`). It also warns about skills that don't declare
`allowed-tools` (see policy below).

## Adding a skill

1. Create `skills/<name>/SKILL.md` with frontmatter (`name`, `description`, usually
   `argument-hint`; add `allowed-tools` if the skill should be restricted).
2. `name:` **must** equal the directory name.
3. Put depth in a sibling `references/` dir and keep `SKILL.md` a thin index
   (progressive disclosure), matching neighboring skills.
4. Add a row to the README skill table.
5. If the skill has a counterpart in the platform repo's `wwwroot/system-prompts/`,
   add it to the **File Mapping** table in `skills/docs-sync/SKILL.md`.
6. Run `scripts/validate.sh`.

## Renaming a skill

Rename the directory **and** update, in lock-step: the `name:` frontmatter, every
cross-reference (`mixcore:<name>`), reference-file headers, the README table, and the
`docs-sync` File Mapping table. Then run `scripts/validate.sh` — it will catch leftover
old tokens and stale paths.

## Naming convention

Names are intentionally prefixed so users can discover the whole suite by typing `mix…`
and so skill names don't collide with other installed plugins:

| Family | Prefix | Examples |
|---|---|---|
| Content / MCP-first leaves | `mix-mcp-*` | `mix-mcp-cms`, `mix-mcp-db`, `mix-mcp-rag` |
| Source-code leaves | `mix-dev-*` | `mix-dev-dotnet-code`, `mix-dev-module` |
| Routers | (none) | `mixcore` (content), `mixdev` (code) |
| Documentation sibling | (none) | `docs-sync` |

`docs-sync` is a deliberate **third category** (documentation), distinct from the two
routers; it is intentionally unprefixed.

## `allowed-tools` policy

Omitting `allowed-tools` means the skill inherits the session's default toolset; declare
it only to **restrict** a skill. Routers (`mixcore`, `mixdev`) and the broad content
skills (`mix-mcp-cms`, `mix-mcp-spa`, `mix-mcp-ai`, `mix-mcp-build-site`) intentionally
omit it because they orchestrate many tools; narrowly-scoped skills declare it.

## MCP prefix

Every content skill talks to a Mixcore MCP server via `{MCP_PREFIX}`. The single source
of truth for resolving it is [`skills/mixcore/mcp-prefix.md`](skills/mixcore/mcp-prefix.md).
Leaf skills assume the prefix is already resolved when reached through the `mixcore` router.

## Choosing `mix-mcp-build-site` vs `mix-mcp-spa`

- **`mix-mcp-build-site`** is the default for *any* website / landing-page / page request —
  including React/Vue/Svelte — because it builds with Razor/CMS templates end-to-end.
- **`mix-mcp-spa`** is **opt-in only**: use it solely to embed an *already-built* SPA
  (a `dist/` folder) into a Mixcore page with `layoutId=null`. Never infer it from the
  tech stack alone.

---
name: docs-sync
description: Use for DOCUMENTATION CRUD in the mixcore-cloud repo — create/update/refine developer docs while keeping the two locations consistent: plugins/mixcore/skills/* (Claude Code agents) and src/apps/MixCore.Cloud.Web/system-prompts/skills/* (in-app Mix AI engine via SkillService/VectorLessService) MUST mirror each other. Trigger on "update docs", "update skill", "sync docs", "keep docs in sync", editing any system-prompts/skills/* or plugins/mixcore/skills/* file, adding a new skill, or whenever you detect drift between the two locations. Sibling routers: mixcore:mixcore (content CRUD via MCP) · mixcore:mixdev (source-code feature work).
---

# Mixcore Documentation Sync

> **Scope:** this is the **documentation** sibling of the router triad — CRUD developer docs and keep the two locations consistent. Siblings: **`mixcore:mixcore`** (content CRUD via MCP tools) · **`mixcore:mixdev`** (AI edits source code to implement features).

Mixcore CMS has **two documentation locations** that must stay in sync. They serve different audiences but share the same ground truth:

| Location | Path | Audience |
|---|---|---|
| **Plugin Skills** | `plugins/mixcore/skills/*/` | Claude Code agents (you, in developer sessions) |
| **System Skills** | `src/apps/MixCore.Cloud.Web/system-prompts/skills/*/` | The Mix AI engine — reachable through **two separate retrieval paths** (below) |

A fact that is true in one must be true in the other. When one drifts, the in-app AI gives different answers than the developer AI — which causes user-facing inconsistencies.

**The two retrieval paths for system-prompts/skills/ content** — both must stay correct, since a change here is live through both:
1. **Automatic, per-turn** — `SkillService.BuildSkillContextAsync` ranks skills by `triggers:` keyword match against the current turn's query and injects the top-scoring skill(s)' `SKILL.md` + ranked `references/*.md` directly into `AgentLoopService`'s context, every turn, unprompted.
2. **Explicit, on-demand** — the agent can also call the `search_backend_knowledge` MCP tool (`RagBackendSearchTool.SearchBackendKnowledgeAsync`, `src/modules/ai/mix.ai/Application/Mcp/McpTools/Rag/RagBackendSearchTool.cs`) mid-turn to BM25-search the whole `system-prompts/skills` tree directly — e.g. after an `AskAI` turn fails or gives an unhelpful answer and it needs grounded backend knowledge. Backed by `VectorLessService(WikiFolders.Skills)` — zero-dependency BM25 over Markdown, optional LLM rerank, NOT tenant-scoped. (Distinct from `RAGSearchTool`, which searches the per-tenant SiteWiki, not this skills corpus.)

---

## Directory Structure

### `plugins/mixcore/skills/` (authoritative source)

All skills live here. Each skill is a folder with `SKILL.md` (YAML frontmatter: `name`, `description`, `triggers`, `argument-hint`) + optional `references/*.md` files.

```
plugins/mixcore/skills/
├── mixcore/              # Router: content tasks → delegates to mix-mcp-*
├── mixdev/               # Router: code tasks → delegates to mix-dev-*
├── docs-sync/            # This skill — documentation sync
├── mix-mcp-cms/          # Templates, pages, modules, posts, forms, razor
├── mix-mcp-db/           # MixDB tables, columns, relationships, rows
├── mix-mcp-ai/           # SignalR hubs, AI chat widgets, streaming
├── mix-mcp-rag/          # Wiki knowledge base, RAG search, documents
├── mix-mcp-flows/        # Workflow automation, webhooks, schedules
├── mix-mcp-schedule/     # Cron jobs, scheduled tasks
├── mix-mcp-spa/          # Deploy pre-built SPA dist/ folders
├── mix-mcp-build-site/   # Phased website build workflow (7 phases)
├── mix-verify-mcp/       # MCP tool round-trip verification
├── mix-verify-site/      # Site-wide verification checks
├── mix-dev-module/       # Scaffold new module projects
├── mix-dev-dotnet-code/  # C# 12 / .NET 10 code patterns
├── mix-dev-dotnet-cli/   # dotnet build/test/run commands
├── mix-dev-migration/    # EF Core migrations (4 providers)
├── mix-dev-tests/        # xUnit test authoring
├── mix-dev-blazor-app/   # Blazor component/page development
└── mix-dev-blazor-blueprint/  # shadcn-style dashboard UI
```

### `src/apps/MixCore.Cloud.Web/system-prompts/` (runtime mirror)

```
system-prompts/
├── system/                           # Core system prompts (locked, no skill counterpart)
│   ├── mixcore-focused-system-prompt.md   [LOCKED — C# ref: SystemPromptService]
│   ├── planning-system-prompt.md          [LOCKED — C# ref: PlanningService]
│   └── site-knowledge-system-prompt.md    [LOCKED — C# ref: SiteWikiAgent]
└── skills/                           # Runtime mirror of plugin skills (non-mix-dev only)
    ├── mixcore/SKILL.md + references/
    ├── mix-mcp-cms/SKILL.md + references/
    ├── mix-mcp-db/SKILL.md + references/
    ├── mix-mcp-ai/SKILL.md + references/
    ├── mix-mcp-rag/SKILL.md + references/
    ├── mix-mcp-flows/SKILL.md + references/
    ├── mix-mcp-schedule/SKILL.md + references/
    ├── mix-mcp-spa/SKILL.md + references/
    ├── mix-mcp-build-site/SKILL.md + references/
    ├── mix-verify-mcp/SKILL.md + references/
    ├── mix-verify-site/SKILL.md + references/
    ├── mix-mcp-tools/SKILL.md + references/     # MCP prompt templates (parse-query, chart-data, etc.)
    ├── mix-mcp-reference/SKILL.md + references/ # CMS reference docs (no single skill owner)
    ├── mix-agent/SKILL.md + references/         # Agent-level prompts (intent, tool, step)
    └── docs-sync/SKILL.md                       # This skill — documentation sync
```

**What is NOT mirrored to `system-prompts/skills/`:**
- **`mix-dev-*` skills** — developer tooling, not runtime AI. The in-app AI never scaffolds modules, runs `dotnet build`, or authors C# code. These stay in `plugins/mixcore/skills/` only.
- **`mixdev` router** — same reason, code-only.
- **`system-prompts/system/*.md`** — runtime prompts, loaded by `SystemPromptService.LoadPrompt()`, no skill counterpart.

**Locked files:** Every file in `system/` is path-locked in C# via `SystemPromptService.LoadPrompt()`. Never rename or move them; they are loaded RAW (no frontmatter). Two groups:
- **Core prompts (3):** `mixcore-focused-system-prompt.md`, `site-knowledge-system-prompt.md`, `planning-system-prompt.md` — use `{{TenantName}}`, `{{Date}}`, `{{RAGContext}}` template variables.
- **Operational prompts (10, extracted from C#):** `rerank-documents.md` (VectorLessService LLM rerank), `conversation-summary.md` + `clarity-check.md` (TokenOptimizer), `game-ai-opponent.md` (GameAiOpponent), `llm-usage-query-parse.md` (LlmUsageQueryParser), `generate-field-value-json.md` + `generate-field-value-text.md` (MixAIService), `agent-loop-rag-context.md` + `agent-loop-rag-nudge.md` + `agent-loop-clarity-gate.md` (AgentLoopService per-turn injections — missing file degrades gracefully, never fails the turn). Their `{{Key}}` placeholders are filled by `BuildFromTemplate` — unmatched `{{...}}` is stripped, so never add literal double-brace text.

---

## File Mapping

Sync is now **1:1 by folder name**. When you change a skill in `plugins/mixcore/skills/<name>/`, update `system-prompts/skills/<name>/` with the same content.

| Plugin skill | System skill (mirror) | Notes |
|---|---|---|
| `plugins/mixcore/skills/mixcore/` | `system-prompts/skills/mixcore/` | Router + start-here |
| `plugins/mixcore/skills/mix-mcp-cms/` | `system-prompts/skills/mix-mcp-cms/` | Templates, pages, modules, forms, razor |
| `plugins/mixcore/skills/mix-mcp-db/` | `system-prompts/skills/mix-mcp-db/` | MixDB tables, columns, rows |
| `plugins/mixcore/skills/mix-mcp-ai/` | `system-prompts/skills/mix-mcp-ai/` | SignalR, chat widgets, AI streaming |
| `plugins/mixcore/skills/mix-mcp-rag/` | `system-prompts/skills/mix-mcp-rag/` | Wiki, RAG search, documents |
| `plugins/mixcore/skills/mix-mcp-flows/` | `system-prompts/skills/mix-mcp-flows/` | Workflow automation |
| `plugins/mixcore/skills/mix-mcp-schedule/` | `system-prompts/skills/mix-mcp-schedule/` | Cron jobs |
| `plugins/mixcore/skills/mix-mcp-spa/` | `system-prompts/skills/mix-mcp-spa/` | SPA deployment |
| `plugins/mixcore/skills/mix-mcp-build-site/` | `system-prompts/skills/mix-mcp-build-site/` | Phased website builder |
| `plugins/mixcore/skills/mix-verify-mcp/` | `system-prompts/skills/mix-verify-mcp/` | MCP tool verification |
| `plugins/mixcore/skills/mix-verify-site/` | `system-prompts/skills/mix-verify-site/` | Site verification |
| `plugins/mixcore/skills/docs-sync/` | `system-prompts/skills/docs-sync/` | This skill |
| `plugins/mixcore/skills/mix-dev-*/` | **NOT SYNCED** | Developer tooling, not runtime AI |
| `plugins/mixcore/skills/mixdev/` | **NOT SYNCED** | Code router, not runtime AI |
| — | `system-prompts/skills/mix-mcp-tools/` | MCP prompt templates (no plugin counterpart) |
| — | `system-prompts/skills/mix-mcp-reference/` | CMS reference (no plugin counterpart) |
| — | `system-prompts/skills/mix-agent/` | Agent prompts (no plugin counterpart) |

**System-only skills** (`mix-mcp-tools`, `mix-mcp-reference`, `mix-agent`): These have no plugin counterpart. They were created from the old `system-prompts/agent/`, `mcp/`, and `instructions/reference/` folders during the #348 consolidation. When their content changes, update the relevant plugin skill that owns that domain (e.g. `mix-mcp-tools` changes → check if `mix-mcp-cms` or `mix-mcp-db` need updates).

---

## Sync Workflow

Follow this checklist every time you touch documentation in either location.

### Step 1 — Identify what changed

Before editing, note:
- Which file are you about to change?
- Which location is it in (plugin skill vs. system skill)?
- What is the nature of the change? (new fact, corrected fact, removed section, new pattern)

### Step 2 — Make the primary edit

Edit the file the user asked you to update. **Prefer editing the plugin skill first** (it is the authoritative source), then mirror to system-prompts.

**Skill files** use YAML frontmatter: `name`, `description`, `argument-hint`, `triggers`

### Step 3 — Mirror to the other location

Copy the changed files to the corresponding skill folder in the other location:

```
plugins/mixcore/skills/<name>/  ←→  system-prompts/skills/<name>/
```

1. Copy updated `SKILL.md` and any changed `references/*.md` files
2. If the file already exists in the target, overwrite it
3. Do NOT copy-paste selectively — the content must be identical

**Skip mirroring if:**
- The skill is `mix-dev-*` or `mixdev` (not synced to system-prompts)
- The skill is `mix-mcp-tools`, `mix-mcp-reference`, or `mix-agent` (system-only, no plugin counterpart — update the relevant domain skill instead)

### Step 4 — Update frontmatter

If the skill file has `last_modified` in its frontmatter, update it to today's date in both locations.

### Step 5 — Verify consistency

After both edits, do a quick spot-check:

```
Does the system-prompts copy say the same thing about [changed topic] as the plugin copy?
```

If the answer is "no" or "I'm not sure", fix it now before closing the task.

---

## Skill File Format

### SKILL.md

Every skill folder has exactly one `SKILL.md` with YAML frontmatter:

```yaml
---
name: mix-mcp-build-site
description: Build a complete website with Mixcore CMS using a phased, documented plan...
argument-hint: "[analyze|plan|phase-1|...] [site-name]"
triggers:
  - build site
  - create site
  - landing page
  - phases
---
```

| Field | Required | Description |
|---|---|---|
| `name` | Yes | Must match the folder name exactly |
| `description` | Yes | One sentence — used for search matching by `SkillService` |
| `argument-hint` | No | Shown in slash-command auto-complete |
| `triggers` | Yes | Keyword list — `SkillService.BuildSkillContextAsync` matches user query terms against these for scoring. Include 5-20 lowercase terms that cover the skill's domain. |

### references/*.md

Optional. Each file is plain markdown loaded on demand. No frontmatter required. Keep each reference under ~4,000 chars — `SkillService` truncates anything longer at injection time.

**References are ranked, not read in order.** Per turn, `SkillService.BuildSkillContextAsync` selects up to 2 skills (the top-scoring skill plus a secondary scoring ≥ 50% of it) and ranks each selected skill's references by query relevance — filename keyword matches weigh heaviest, then term frequency in the file body. Caps: 3 references from the primary skill, 2 from the secondary, 4 total, ~4,000 chars each. Authoring rules that follow from this:

- **Name reference files with the domain keywords users actually type** (`form-templates.md`, `data-loading.md`) — the filename is the strongest ranking signal.
- **One topic per reference file** — a grab-bag file ranks poorly for every specific query.
- Don't rely on alphabetical position; it applies only as a fallback when nothing matches the query.

---

## Writing Conventions

### For all skill files

- **Audience**: Both Claude Code agents (plugin) and the in-app Mix AI LLM (system-prompts)
- **Tone**: Direct, imperative ("Read X before starting", "Never call Y directly")
- **Format**: Short tables, code blocks, checklists
- **Critical rules**: Use `🚨 CRITICAL RULE:` headers for non-negotiable constraints
- **No fluff**: Every line earns its place
- **Keep SKILL.md thin**: Push depth into `references/` files, link them from SKILL.md

### Naming rules

- All file and folder names must be lowercase kebab-case
- Skill folder names use the `mix-<family>-<name>` convention
- Reference file names are descriptive: `razor-rules.md`, `form-templates.md`, `data-loading.md`
- Never use PascalCase, underscores, or ALL-CAPS

---

## Drift Audit Recipes

Run these when asked to "audit for drift" / "check docs are in sync" — they mechanize the checks that otherwise require re-reading every file pair from scratch. Run from the repo root (`platform/`).

### 1. Orphaned reference files (the #1 source of drift)

A file sitting in ONE side's `references/` folder with no counterpart in the other is the single biggest recurring problem — it silently diverges because nobody's told to update it. For every skill that has a plugin counterpart:

```bash
for d in plugins/mixcore/skills/*/; do
  name=$(basename "$d")
  sys="src/apps/MixCore.Cloud.Web/system-prompts/skills/$name"
  [ -d "$sys" ] || continue
  echo "=== $name ==="
  diff <(ls "$d/references/" 2>/dev/null | sort) <(ls "$sys/references/" 2>/dev/null | sort)
done
```

`<` lines exist only in the plugin; `>` lines exist only in system-prompts. Every `>`-only file is a candidate for: (a) genuinely being mirrored back to the plugin, (b) being misfiled under the wrong skill's folder entirely (check its actual topic against the skill's domain — a file about a DIFFERENT skill's topic sitting here means a past consolidation dumped it in the wrong place), or (c) describing a retired feature and should be deprecated/removed rather than mirrored. Don't reflexively copy every orphan to the plugin — read it first.

### 2. SKILL.md content drift (ignoring the expected `triggers:` difference)

```bash
for d in plugins/mixcore/skills/*/; do
  name=$(basename "$d")
  sys="src/apps/MixCore.Cloud.Web/system-prompts/skills/$name/SKILL.md"
  [ -f "$sys" ] || continue
  diff "$d/SKILL.md" "$sys" | grep -v '^[<>] *$\|triggers:\|^[<>]   - '
done
```

The system copy legitimately carries an extra `triggers:` frontmatter block the plugin doesn't (plugin = Claude Code name/description routing; system = `SkillService.BuildSkillContextAsync` keyword matching) — that's not drift, the grep above filters most of it. Anything else that survives the filter is real.

### 3. Broken cross-skill relative links

Reference files link across skill folders (`../../mix-mcp-ai/references/x.md`). A rename/move breaks these silently — markdown doesn't error on a dead link.

```bash
grep -rEon '\]\(\.\./[a-zA-Z0-9_./-]+\.md\)' src/apps/MixCore.Cloud.Web/system-prompts/skills/*/references/*.md src/apps/MixCore.Cloud.Web/system-prompts/skills/*/SKILL.md
```

For each match, resolve the relative path from the file's own location and confirm the target actually exists (`find . -name "<target-filename>"` is the fastest way to find where a file actually lives if the link is stale). A link using an OLD pre-consolidation subfolder name (`overview/`, `mixdb/`, `templates/`, `content/`, `workflows/`, `reference/`, `developer/` as a sibling of the linking file) is always broken — those subfolders don't exist anywhere under `system-prompts/skills/*/references/`; the real target lives flat inside some OTHER skill's own `references/` folder.

### 4. Documented tool/class names that don't exist in source

A reference can describe a tool by a name that was renamed or never actually shipped (e.g. a whole `MixDbSchemaTool` class that never existed — the real tools ended up split across `MixDbTableTool`/`MixDbColumnTool`/`MixDbTableRelationshipTool`). Spot-check by grepping the doc's claimed class/method names against the actual `[McpServerTool]`-attributed methods:

```bash
grep -rn "class .*Tool" src/modules/ai/mix.ai/Application/Mcp/McpTools/ src/cloud/*/  # real tool classes
grep -n "McpServerTool\]" -A1 <file>.cs   # real method names inside one
```

If a doc names a class/method you can't find here, treat it as stale — either it was renamed (find what replaced it and fix the doc) or it never shipped (mark the doc deprecated, point at the real tool set, keep the rest only as historical context — see mix-mcp-db's `datasource-schema.md` for the pattern). This class of bug isn't limited to Markdown docs — it can hide in a C# `///` doc comment too (e.g. `RagBackendSearchTool`'s own summary once described an old `WikiFolders.SystemInstructions` path/constant that had been renamed to `WikiFolders.Skills` — the CODE was already correct, only the comment lagged). When auditing a tool's docs, diff its XML doc comment against its actual implementation, not just against the Markdown skill files.

### 5. A whole system-only skill describing a retired architecture

The 3 system-only skills (`mix-mcp-tools`, `mix-mcp-reference`, `mix-agent`) have no plugin counterpart and can go stale invisibly since nobody edits them as a side effect of touching a plugin skill. Check whether a system-only skill's content still reflects current behavior by grepping whether the C# it claims to document actually still calls it:

```bash
grep -rn "LoadPrompt(" src/modules/ai/mix.ai/ | grep -oE '"[a-zA-Z0-9/_-]+\.md"'   # every prompt file actually loaded
```

If a system-only skill describes an architecture (e.g. a classify-then-dispatch scheme, a specific routing flow) and grepping the C# for its keywords turns up nothing, or turns up a code comment saying the mechanism was retired/replaced (`#195`, `#202`-style issue references in comments are a strong signal — this codebase leaves them when retiring old paths), the skill is describing dead architecture. Don't just leave it — `SkillService` still ranks and injects it into live agent turns if its `triggers:` match a query, meaning stale content actively reaches the model. Either fix it to match current behavior, or mark it clearly `DEPRECATED` in both the `description:`/`triggers:` frontmatter AND a banner at the top of every reference file it links (a query can rank a reference file into context even when nobody opens the SKILL.md first).

### 6. Skill Map staleness in the main system prompt

`system-prompts/system/mixcore-focused-system-prompt.md` hand-maintains a "Skill Map" table. Check it lists every real folder:

```bash
comm -3 <(ls src/apps/MixCore.Cloud.Web/system-prompts/skills/ | sort) \
        <(grep -oE '^\| `[a-z-]+`' src/apps/MixCore.Cloud.Web/system-prompts/system/mixcore-focused-system-prompt.md | tr -d '|` ' | sort)
```

Non-empty output on either side means a folder exists with no table row, or a table row names a folder that no longer exists.

---

## Common Gotchas

**`mix-dev-*` skills are NOT synced**: These are developer tooling — the in-app AI never uses them. Don't copy them to `system-prompts/skills/`.

**Locked prompt files cannot be moved**: Every file in `system-prompts/system/` (3 core + 7 operational) is hardcoded in C# via `SystemPromptService.LoadPrompt()`. Never rename or relocate them.

**`triggers:` frontmatter is required**: `SkillService.BuildSkillContextAsync` relies on triggers for keyword matching. Without them, the skill won't match user queries and won't be injected as context. Always include 5-20 relevant trigger keywords.

**Skill folder name must match `name:` frontmatter**: The directory name and the `name:` field must be identical.

**Critical rules must appear in both copies**: If you add a `🚨 CRITICAL RULE` to a plugin skill, copy it to the system-prompts mirror — the in-app AI needs to know too.

**Skill Map in the system prompt must track skill changes**: `system-prompts/system/mixcore-focused-system-prompt.md` contains a hand-maintained "Skill Map" table summarising every system skill's coverage (built from each `SKILL.md` frontmatter `description`). Adding, removing, renaming, or re-scoping a system skill requires updating that table in the same change — it drifts otherwise.

**Never let a platform commit record an unpushed submodule SHA**: after editing this repo (the plugin submodule), the order is push-submodule-FIRST, then `git add plugins/mixcore` + commit the pointer bump in the platform repo. A platform commit referencing an unpushed submodule commit is unresolvable for every other checkout and CI (`fatal: remote error: upload-pack: not our ref`). Watch for `git status` showing `M plugins/mixcore` getting swept into an unrelated commit by a broad `git add`.

**Renames don't rewrite history docs**: when a symbol/class rename touches documentation, update **living** docs only (skills in both copies, project READMEs, system prompts). Historical records — `docs/superpowers/plans/*`, `docs/superpowers/specs/*` — describe what was true at the time; leave the old names in them.

**Don't add Claude Code-specific instructions to system-prompts**: Things like "load the mixcore skill first" or slash commands (`/mixcore:mix-mcp-cms`) have no meaning in the server-side context. The system copy should work for both audiences — keep skill-invocation instructions generic.

---

## Quick Reference: Directory Roots

```
Plugin skills root:     plugins/mixcore/skills/
System skills root:     src/apps/MixCore.Cloud.Web/system-prompts/skills/
System prompts root:    src/apps/MixCore.Cloud.Web/system-prompts/system/
Wiki root:              wwwroot/mixcontent/documents/wiki/
```

---

## MCP Tools

<!-- mcp-tools:auto (generated by docs-sync; canonical names from live tools/list) -->
Wiki-doc CRUD goes through the RAG-indexed tools — never `write_text_file`/`read_text_file` (those bypass the in-memory index and serve stale content until restart).

- **Wiki docs** — `generate_document`, `read_document`, `list_documents`, `delete_document`, `reload_wiki`
<!-- /mcp-tools:auto -->

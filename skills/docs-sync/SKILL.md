---
name: docs-sync
description: Use for DOCUMENTATION CRUD in the mixcore-cloud repo — create/update/refine developer docs while keeping the two locations consistent: plugins/mixcore/skills/* (Claude Code agents) and src/apps/MixCore.Cloud.Web/wwwroot/system-prompts/skills/* (in-app Mix AI engine via SkillService/VectorLessService) MUST mirror each other. Trigger on "update docs", "update skill", "sync docs", "keep docs in sync", editing any system-prompts/skills/* or plugins/mixcore/skills/* file, adding a new skill, or whenever you detect drift between the two locations. Sibling routers: mixcore:mixcore (content CRUD via MCP) · mixcore:mixdev (source-code feature work).
---

# Mixcore Documentation Sync

> **Scope:** this is the **documentation** sibling of the router triad — CRUD developer docs and keep the two locations consistent. Siblings: **`mixcore:mixcore`** (content CRUD via MCP tools) · **`mixcore:mixdev`** (AI edits source code to implement features).

Mixcore CMS has **two documentation locations** that must stay in sync. They serve different audiences but share the same ground truth:

| Location | Path | Audience |
|---|---|---|
| **Plugin Skills** | `plugins/mixcore/skills/*/` | Claude Code agents (you, in developer sessions) |
| **System Skills** | `src/apps/MixCore.Cloud.Web/wwwroot/system-prompts/skills/*/` | The Mix AI engine — `SkillService` loads skills at runtime, `VectorLessService` indexes them for RAG, `AgentLoopService` injects skill context per turn |

A fact that is true in one must be true in the other. When one drifts, the in-app AI gives different answers than the developer AI — which causes user-facing inconsistencies.

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

### `src/apps/MixCore.Cloud.Web/wwwroot/system-prompts/` (runtime mirror)

```
system-prompts/
├── system/                           # Core system prompts (locked, no skill counterpart)
│   ├── mixcore-focused-system-prompt.md   [LOCKED — C# ref: SystemPromptService]
│   ├── planning-system-prompt.md          [LOCKED — C# ref: PlanningService]
│   └── site-knowledge-system-prompt.md    [LOCKED — C# ref: SiteKnowledgeAgent]
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
- **`system-prompts/system/*.md`** — locked core prompts, loaded by `SystemPromptService.LoadPrompt()`, no skill counterpart.

**Locked files:** The 3 files in `system/` are path-locked in C# via `SystemPromptService.LoadPrompt()`. Never rename or move them. They use `{{TenantName}}`, `{{Date}}`, `{{RAGContext}}` template variables.

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

Optional. Each file is plain markdown loaded on demand. No frontmatter required. Keep each reference under ~4,000 chars to avoid context blowout when `SkillService` injects them.

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

## Common Gotchas

**`mix-dev-*` skills are NOT synced**: These are developer tooling — the in-app AI never uses them. Don't copy them to `system-prompts/skills/`.

**Locked prompt files cannot be moved**: The 3 files in `system-prompts/system/` are hardcoded in C# via `SystemPromptService.LoadPrompt()`. Never rename or relocate them.

**`triggers:` frontmatter is required**: `SkillService.BuildSkillContextAsync` relies on triggers for keyword matching. Without them, the skill won't match user queries and won't be injected as context. Always include 5-20 relevant trigger keywords.

**Skill folder name must match `name:` frontmatter**: The directory name and the `name:` field must be identical.

**Critical rules must appear in both copies**: If you add a `🚨 CRITICAL RULE` to a plugin skill, copy it to the system-prompts mirror — the in-app AI needs to know too.

**Don't add Claude Code-specific instructions to system-prompts**: Things like "load the mixcore skill first" or slash commands (`/mixcore:mix-mcp-cms`) have no meaning in the server-side context. The system copy should work for both audiences — keep skill-invocation instructions generic.

---

## Quick Reference: Directory Roots

```
Plugin skills root:     plugins/mixcore/skills/
System skills root:     src/apps/MixCore.Cloud.Web/wwwroot/system-prompts/skills/
System prompts root:    src/apps/MixCore.Cloud.Web/wwwroot/system-prompts/system/
Wiki root:              wwwroot/mixcontent/documents/wiki/
```

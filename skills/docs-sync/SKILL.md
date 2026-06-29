---
name: docs-sync
description: Use for DOCUMENTATION CRUD in the mixcore-cloud repo — create/update/refine developer docs while keeping the two locations consistent: plugins/mixcore/skills/* (Claude Code agents) and wwwroot/system-prompts/ (in-app Mix AI engine) MUST mirror each other. Trigger on "update docs", "update skill", "sync instructions", "keep docs in sync", editing any system-prompts/instructions/*.md or mixcore:* SKILL/reference file, adding a new skill or instruction, or whenever you detect drift between the two locations. Sibling routers: mixcore:mixcore (content CRUD via MCP) · mixcore:mixdev (source-code feature work).
---

# Mixcore Documentation Sync

> **Scope:** this is the **documentation** sibling of the router triad — CRUD developer docs and keep the two locations consistent. Siblings: **`mixcore:mixcore`** (content CRUD via MCP tools) · **`mixcore:mixdev`** (AI edits source code to implement features).

Mixcore CMS has **two documentation locations** that must stay in sync. They serve different audiences but share the same ground truth:

| Location | Path | Audience |
|---|---|---|
| **Skills** | `plugins/mixcore/skills/*/` | Claude Code agents (you, in developer sessions) |
| **System Prompts** | `wwwroot/system-prompts/` | The Mix AI engine (in-app LLM, GenerationAgent, SiteKnowledgeAgent) |

A fact that is true in one must be true in the other. When one drifts, the in-app AI gives different answers than the developer AI — which causes user-facing inconsistencies.

---

## Directory Structure

### `wwwroot/system-prompts/`

```
system-prompts/
├── mixcore-focused-system-prompt.md   [LOCKED — C# ref: ChatAgent.cs]
├── site-knowledge-system-prompt.md    [LOCKED — C# ref: SiteKnowledgeAgent.cs]
├── planning-system-prompt.md          [LOCKED — C# ref: PlanningService.cs]  # NOTE: no YAML frontmatter — loaded raw (see caveat below)
├── agent/                             # Free-standing agent runtime prompts
│   ├── content-analysis.md
│   ├── data-analysis.md
│   ├── generation.md
│   ├── intent-classification.md      # 2-category (chat/plan)
│   ├── module-analysis.md
│   ├── step-execution.md
│   └── tool-classification.md
├── mcp/                               # MCP tool operation prompts
│   ├── intent-classification.md      [LOCKED — C# ref: RoutingAgent.cs]
│   ├── parse-query.md                [LOCKED — C# ref: SmartQueryParser.cs]
│   ├── parse-schema-description.md   [LOCKED — C# ref: MixDbSchemaParser.cs]
│   ├── tool-classification.md        [LOCKED — C# ref: ToolExecutionService.cs]
│   ├── tool-classification-default-context.md  [LOCKED — C# ref: ToolExecutionService.cs]
│   ├── extract-tool-params.md
│   ├── generate-column-value.md
│   ├── generate-mixdb-record.md
│   └── intent-classification-update-content.md
└── instructions/                      # AI agent & developer knowledge base
    ├── start-here.md                  # Master index
    ├── overview/
    │   ├── mixcore-cms-overview.md
    │   └── ai-chat-widget.md
    ├── content/
    │   ├── modules.md
    │   ├── pages.md
    │   └── posts.md
    ├── mixdb/
    │   ├── overview.md
    │   ├── best-practices.md
    │   ├── data-loading-guide.md
    │   ├── database-creation-guide.md
    │   └── datasource-services-guide.md
    ├── developer/
    │   ├── developer-guide.md
    │   ├── mcp-tools-reference.md
    │   └── infrastructure-providers.md
    ├── reference/                     # CMS-audience reference (distinct from developer/)
    │   ├── mix-cms-reference.md       # enums, folder types, status, query operators
    │   ├── mcp-tools-catalog.md       # ORCHESTRATOR INDEX — Available Tools map + links to mcp-tools/ detail files (≠ developer/mcp-tools-reference.md authoring doc)
    │   ├── mcp-tools/                  # per-tool-group detail files w/ full param schemas
    │   │   ├── datasource-schema.md · datasource-data.md · rag-search.md · fetch-url.md · vault-upload.md
    │   │   ├── text-file.md · cms-pages.md · cms-modules.md · page-module.md · templates.md
    │   │   └── scheduler.md · service-discovery.md · flows.md
    │   └── cms-csharp-extension-guide.md  # CMS C# extension guide (≠ developer/developer-guide.md cloud-module guide)
    ├── templates/
    │   ├── razor-syntax-guidelines.md
    │   ├── form-template.md
    │   ├── master-template.md
    │   ├── mixdb-template.md
    │   ├── module-template.md
    │   ├── page-template.md
    │   ├── post-template.md
    │   └── widget-template.md
    └── workflows/
        ├── ai-content-editor.md
        ├── admin-portal.md
        └── mix-build-site.md
```

### `wwwroot/mixcontent/documents/wiki/`

Each sub-folder is a site slug (tenant site name). Every wiki file must have YAML front matter.

```
wiki/
├── _system/
├── rose-whisk/
│   ├── index.md
│   ├── database/  (categories, contacts, newsletter, products)
│   ├── forms/     (contact-form, newsletter-widget)
│   ├── modules/   (best-sellers, featured-categories, hero-banner, our-story)
│   ├── pages/     (home, menu, about, contact)
│   └── templates/ (master)
└── mixcore-cloud/
    ├── index.md
    ├── database/  (mixcore-cloud-testimonials, mixcore-cloud-contacts)
    ├── forms/     (contact)
    ├── pages/     (home)
    └── templates/ (mixcore-cloud-layout, mixcore-cloud-home)
```

**Naming rules:** all file and folder names must be lowercase kebab-case (e.g., `razor-syntax-guidelines.md`, not `cshtml-razor-syntax-guidelines.md`). Never use PascalCase, underscores, or ALL-CAPS for file names.

**Locked files:** 5 prompt files in `mcp/` and 3 at root (`mixcore-focused-system-prompt.md`, `site-knowledge-system-prompt.md`, `planning-system-prompt.md`) are path-locked in C# — never rename or move them.

🚨 **Runtime prompts are loaded RAW.** `SystemPromptService.LoadPrompt()` returns `File.ReadAllText(...)` verbatim — it does **not** strip YAML frontmatter. Any frontmatter on a root / `agent/` / `mcp/` prompt is injected straight into the LLM system prompt. **Do not add frontmatter to these runtime prompts**, especially strict-output ones like `planning-system-prompt.md` (which must return "ONLY a JSON array"). Frontmatter belongs only on the RAG-indexed `instructions/**` docs. (The two existing locked root files carry legacy frontmatter that already leaks; leave it unless asked, but add no more.)

---

## File Mapping

| When you change… | Also update… |
|---|---|
| `plugins/mixcore/skills/mix-mcp-cms/references/razor-rules.md` | `system-prompts/instructions/templates/razor-syntax-guidelines.md` |
| `plugins/mixcore/skills/mix-mcp-cms/references/mixdb-in-razor.md` | `system-prompts/instructions/templates/mixdb-template.md` |
| `plugins/mixcore/skills/mix-mcp-cms/references/data-loading.md` | `system-prompts/instructions/mixdb/data-loading-guide.md` |
| `plugins/mixcore/skills/mix-mcp-cms/references/content-creation.md` | `system-prompts/instructions/content/pages.md`, `content/modules.md`, `content/posts.md` |
| `plugins/mixcore/skills/mix-mcp-cms/references/form-templates.md` | `system-prompts/instructions/templates/form-template.md` |
| `plugins/mixcore/skills/mix-mcp-cms/references/viewmodels.md` | `system-prompts/instructions/templates/page-template.md`, `post-template.md`, `module-template.md`, `widget-template.md` (ViewModel property tables) |
| `plugins/mixcore/skills/mix-mcp-cms/references/design-system.md` | `system-prompts/instructions/templates/design-system.md` |
| `plugins/mixcore/skills/mix-mcp-cms/references/design.md` | `system-prompts/instructions/templates/design.md` |
| MCP tool signatures (live via ToolSearch) | `system-prompts/mcp/` files |
| `plugins/mixcore/skills/mix-mcp-db/SKILL.md` | `system-prompts/instructions/mixdb/overview.md`, `database-creation-guide.md` |
| `plugins/mixcore/skills/mix-mcp-flows/SKILL.md` | `src/cloud/MixCore.Cloud.Flows/README.md` (MCP Tools section) |
| `plugins/mixcore/skills/mix-mcp-schedule/SKILL.md` | `src/cloud/MixCore.Cloud.Scheduler/README.md` (MCP Tools section) |
| `plugins/mixcore/skills/mix-dev-blazor-app/SKILL.md` | No direct counterpart — note architectural facts in `system-prompts/instructions/overview/mixcore-cms-overview.md` |
| `plugins/mixcore/skills/mixcore/SKILL.md` | `system-prompts/instructions/start-here.md` (agent protocol section) |
| `plugins/mixcore/skills/mixdev/SKILL.md` | `system-prompts/instructions/developer/developer-guide.md` (architectural facts, namespace patterns) |
| `plugins/mixcore/skills/mix-dev-dotnet-code/SKILL.md` | `system-prompts/instructions/developer/developer-guide.md` (coding standards, EF patterns) |
| `plugins/mixcore/skills/mix-dev-module/SKILL.md` | `system-prompts/instructions/developer/developer-guide.md` (module skeleton, controller/service base-class signatures) |
| `plugins/mixcore/skills/mix-mcp-rag/SKILL.md` | `system-prompts/instructions/reference/mcp-tools/rag-search.md` (RAGSearchTool — wiki document CRUD API + tenant-scoped paths) and `system-prompts/instructions/start-here.md` (Wiki-First Rule) |
| `plugins/mixcore/skills/mix-mcp-flows/SKILL.md` *(system-prompts side)* | `system-prompts/instructions/reference/mcp-tools/flows.md` (Flows action types + parameter injection — keep in sync with `src/cloud/MixCore.Cloud.Flows/README.md`) |
| `system-prompts/instructions/start-here.md` | `plugins/mixcore/skills/mixcore/SKILL.md` (routing rules, checklist) |
| `system-prompts/instructions/developer/developer-guide.md` | `plugins/mixcore/skills/mix-dev-dotnet-code/SKILL.md` and `plugins/mixcore/skills/mixdev/SKILL.md` |
| `system-prompts/instructions/developer/mcp-tools-reference.md` | `plugins/mixcore/skills/mix-dev-dotnet-code/references/` (MCP tool authoring) |
| `system-prompts/instructions/developer/infrastructure-providers.md` | `docs/04-mixcore-cloud-technical-architecture.md` and `docs/services/cloud-service-providers.md` |
| `system-prompts/instructions/mixdb/*.md` | `plugins/mixcore/skills/mix-mcp-db/SKILL.md` and `plugins/mixcore/skills/mix-mcp-cms/references/` |
| `system-prompts/instructions/templates/*.md` | `plugins/mixcore/skills/mix-mcp-cms/references/` |
| `system-prompts/instructions/overview/ai-chat-widget.md` | `plugins/mixcore/skills/mix-mcp-ai/` (chat-widget reference) |
| `system-prompts/instructions/reference/mix-cms-reference.md` | Enums/folder-types live in the live MCP tool schemas (ToolSearch); mirror in `mix-mcp-cms/SKILL.md` "Enum Values" |
| `system-prompts/instructions/reference/cms-csharp-extension-guide.md` | `plugins/mixcore/skills/mix-dev-dotnet-code/SKILL.md` (CMS C# extension patterns) |
| `system-prompts/instructions/workflows/*.md` | No direct skill counterpart — server-side AI workflow guides; mirror architectural facts in the relevant `mix-mcp-*` skill |
| `system-prompts/{mixcore-focused,site-knowledge,planning}-system-prompt.md` (root) | No skill counterpart — LOCKED runtime prompts (paths hardcoded in C#); never add frontmatter |
| `system-prompts/agent/*.md` | No skill counterpart — server-only LLM prompts |
| `system-prompts/mcp/*.md` | MCP tool signatures (live via ToolSearch) |

When no direct counterpart exists, check whether the change affects the **architecture overview** (`instructions/overview/mixcore-cms-overview.md`) and update it if so.

---

## Sync Workflow

Follow this checklist every time you touch documentation in either location.

### Step 1 — Identify what changed

Before editing, note:
- Which file are you about to change?
- Which location is it in (skill vs. system-prompts)?
- What is the nature of the change? (new fact, corrected fact, removed section, new pattern)

### Step 2 — Make the primary edit

Edit the file the user asked you to update. Follow the existing format and frontmatter conventions for that file.

**Skill files** use YAML frontmatter: `name`, `description`, `argument-hint`, `allowed-tools`  
**Instruction files** use YAML frontmatter — see the [YAML Front Matter Standard](#yaml-front-matter-standard) section below.

### Step 3 — Update the counterpart

Look up the mapping table above. For each counterpart file:

1. Read the counterpart file to understand its current state
2. Apply the same conceptual change — same fact, same correction — adapted to that file's audience and format
3. Update `last_modified` in instruction frontmatter to today's date
4. Do NOT just copy-paste — skills are imperative instructions ("do X"), instructions are reference docs ("X works like Y")

### Step 4 — Update the index if needed

If you added a **new file** to either location:
- New instruction file → add a row to `system-prompts/instructions/START-HERE.md`
- New skill reference → add a row to the skill's reference table in `SKILL.md`

### Step 5 — Verify consistency

After both edits, do a quick spot-check:

```
Does the skill say the same thing about [changed topic] as the instruction file?
```

If the answer is "no" or "I'm not sure", fix it now before closing the task.

### Step 6 — Use document CRUD tools; only bulk-reload when needed

**Always use the wiki document MCP tools instead of reading or writing `.md` files directly.** The tools write to disk AND update the in-memory RAG index atomically — no explicit reload needed.

| Operation | Tool | Notes |
|---|---|---|
| Create or update a wiki doc | `mcp__mixcore__generate_document` | Generates YAML frontmatter automatically; title → kebab-case filename |
| Read a wiki doc | `mcp__mixcore__read_document` | Returns raw markdown including frontmatter |
| List docs in a folder | `mcp__mixcore__list_documents` | Supports `recursive=true` for subtrees |
| Delete a wiki doc | `mcp__mixcore__delete_document` | Removes from disk **and** de-indexes immediately; requires `confirm='YES'` |
| Bulk reload (after manual edits) | `mcp__mixcore__reload_wiki` | Only needed after editing files outside the tool (e.g. manual file system changes) |

**Never use `mcp__mixcore__write_text_file` or `mcp__mixcore__read_text_file` for wiki documents.** Those tools write raw bytes with no index update — the in-app AI will serve stale content until the next restart.

**Why:** `SiteWikiService` keeps an in-memory BM25 + optional LLM-rerank index built from the `wwwroot/mixcontent/documents/wiki/` tree. `generate_document` and `delete_document` call `UpsertAsync`/`DeleteAsync` on that service after every disk write, so the index is always current. `reload_wiki` does a full rescan — use it only when you know files were changed outside the tool.

---

## YAML Front Matter Standard

Every `.md` file in `system-prompts/` and `wiki/` must have this exact front matter structure:

```yaml
---
title: "[Clear, descriptive title]"
category: "[Top-level folder / site name]"
sub_category: "[Sub-folder / content type]"
tags: [tag1, tag2, tag3]
last_modified: YYYY-MM-DD
summary: "[1-2 sentence summary for search indexing]"
---
```

| Field | Rule |
|---|---|
| `title` | Human-readable, title-cased. Not the filename. |
| `category` | Matches the top-level grouping: `system-prompts`, `instructions`, `rose-whisk`, `system` (for wiki/_system/) |
| `sub_category` | Matches the subfolder: `agent-prompts`, `mcp-prompts`, `overview`, `content`, `mixdb`, `reference`, `templates`, `workflows`, `database`, `forms`, `modules`, `pages` |
| `tags` | 4–8 lowercase kebab-case tags; include the primary technology/type and at least 2 specific terms |
| `last_modified` | ISO date — update every time you edit the file |
| `summary` | 1–2 sentences. Must be parseable as a standalone description for search indexing. |

**Do NOT use the old format:** `uuid`, `last_verified` — these are deprecated and must be removed if encountered.

---

## Writing Conventions

🚨 **CRITICAL RULE: never let a single document exceed 10,000 characters.** Applies to every file you create or edit in either location — skill files, `references/` files, `system-prompts/instructions/**`, runtime prompts, and `wiki/` docs. Oversized files index poorly (the RAG chunker splits mid-thought) and blow the context budget when loaded as a system prompt. When a doc approaches the limit:

- **Split by topic** into focused sibling files and cross-link them — exactly as `instructions/templates/` already does (`razor-syntax-guidelines.md` + `razor-encoding-security.md` + `razor-ai-workflow.md`).
- For a thin-index SKILL.md, push depth into a new `references/` file and link it; keep the index short.
- After splitting, update the index (`start-here.md` / the skill's reference table) **and** the File-Mapping table so both locations still mirror.

Check before saving: a file at ~10 KB on disk is at the limit (1 byte ≈ 1 char for ASCII markdown — `wc -c <file>`). If an existing counterpart is already over, prefer splitting it over appending more.

### For skill files (`plugins/mixcore/skills/`)

- **Audience**: You (Claude Code agent in a developer session)
- **Tone**: Direct, imperative ("Read X before starting", "Never call Y directly")
- **Format**: Short tables, code blocks, checklists
- **Critical rules**: Use `🚨 CRITICAL RULE:` headers for non-negotiable constraints
- **No fluff**: Every line earns its place

### For instruction files (`wwwroot/system-prompts/instructions/`)

- **Audience**: The Mix AI engine (GenerationAgent, SiteKnowledgeAgent) at runtime
- **Tone**: Reference documentation ("X is Y", "To do Z, call W")
- **Format**: Standard YAML front matter (see above) + `#` root heading + body
- **Context breadcrumb**: `> **Context:** Mixcore CMS > [section] > [topic]`
- **Cross-links**: Use relative markdown links to other instruction files (use new kebab-case paths)

### For runtime prompt files (`wwwroot/system-prompts/agent/` and `mcp/`)

- **Audience**: Server-side LLM prompts, not AI agents
- **Template variables**: `{{Date}}`, `{{TenantName}}`, `{{RAGContext}}`, `{{Modality}}`
- **No Claude Code-specific instructions** — these run in the server LLM context
- **Locked files**: Never rename/move the 5 locked `mcp/` files or the 2 root files — their paths are hardcoded in C#

---

## Common Gotchas

**Locked prompt files cannot be moved**: `mixcore-focused-system-prompt.md`, `site-knowledge-system-prompt.md`, `planning-system-prompt.md`, and 5 files in `mcp/` are hardcoded in C# via `SystemPromptService.LoadPrompt()`. Never rename or relocate them — and do **not** add YAML frontmatter (it is loaded raw and leaks into the LLM prompt; see the Runtime-prompts gotcha above).

**API method names drift**: When an MCP tool is renamed or its signature changes, update both the skill's `allowed-tools` list and the instruction's "MCP tools" table.

**Critical rules must appear in both places**: If you add a `🚨 CRITICAL RULE` to a skill, add the same constraint to the corresponding instruction file — the in-app AI needs to know too.

**`last_modified` must be updated**: Every edit to any documentation file must update `last_modified` in its front matter. Never use `last_verified` — that field is deprecated.

**File naming is kebab-case**: New files must be lowercase-kebab-case. Never use PascalCase (`ContactForm.md`), underscores (`rosewhisk_products.md`), or ALL-CAPS (`START-HERE.md`).

**Don't add skill-only concepts to instructions**: Things like "load the mixcore skill first" or Claude Code slash commands have no meaning in the server-side context. Keep them skill-only.

**Index files need updating when files move**: `instructions/start-here.md` is the master index. Adding or moving instruction files requires a corresponding row update there. Similarly, `rose-whisk/index.md` must reflect any wiki file changes.

**Never use raw file tools on wiki docs**: `mcp__mixcore__write_text_file` writes to disk only — no index update. Always use `mcp__mixcore__generate_document` for wiki writes so the RAG index stays current. Same for reads: `mcp__mixcore__read_document` is scoped to the wiki base path; raw `read_text_file` has no such guard.

---

## Quick Reference: Directory Roots

```
Skills root:          plugins/mixcore/skills/
Instructions root:    wwwroot/system-prompts/instructions/
Agent prompts root:   wwwroot/system-prompts/agent/
MCP prompts root:     wwwroot/system-prompts/mcp/
Wiki root:            wwwroot/mixcontent/documents/wiki/
```

### Path quick-lookup (old → new)

| Old path | New path |
|---|---|
| `instructions/START-HERE.md` | `instructions/start-here.md` |
| `instructions/MIXCORE-CMS-OVERVIEW.md` | `instructions/overview/mixcore-cms-overview.md` |
| `instructions/mixdb/README.md` | `instructions/mixdb/overview.md` |
| `instructions/reference/reference-mcp-tools.md` | `instructions/reference/mcp-tools-catalog.md` (complete catalog) |
| `instructions/reference/mcp-tools-reference.md` | `instructions/reference/mcp-tools-catalog.md` (renamed 2026-06-03 to disambiguate from developer/mcp-tools-reference.md authoring doc) |
| `instructions/reference/developer-guide.md` | `instructions/reference/cms-csharp-extension-guide.md` (renamed 2026-06-03 to disambiguate from developer/developer-guide.md cloud-module guide) |
| `instructions/reference/infrastructure-providers.md` | `instructions/developer/infrastructure-providers.md` |
| `instructions/templates/cshtml-razor-syntax-guidelines.md` | `instructions/templates/razor-syntax-guidelines.md` |
| `instructions/workflows/ai-content-editor-workflow.md` | `instructions/workflows/ai-content-editor.md` |
| `content-analysis-prompt.md` (root) | `agent/content-analysis.md` |
| `planning-prompt.md` (root) | `planning-system-prompt.md` (root — stays at root, loaded by PlanningService.cs) |
| `generation-system-prompt.md` (root) | `agent/generation.md` |
| `extract-tool-params.md` (root) | `mcp/extract-tool-params.md` |
| `wiki/rose-whisk/README.md` | `wiki/rose-whisk/index.md` |
| `wiki/mixcore-cloud/README.md` | `wiki/mixcore-cloud/index.md` |
| `wiki/mixcore-cloud/templates/MixcoreCloudLayout.md` | `wiki/mixcore-cloud/templates/mixcore-cloud-layout.md` |
| `wiki/mixcore-cloud/templates/MixcoreCloudHome.md` | `wiki/mixcore-cloud/templates/mixcore-cloud-home.md` |
| `wiki/mixcore-cloud/database/mixcore_cloud_testimonials.md` | `wiki/mixcore-cloud/database/mixcore-cloud-testimonials.md` |
| `wiki/mixcore-cloud/database/mixcore_cloud_contacts.md` | `wiki/mixcore-cloud/database/mixcore-cloud-contacts.md` |

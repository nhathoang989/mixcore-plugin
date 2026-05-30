---
name: mix-mcp-rag
description: Use when searching the wiki knowledge base, creating or updating wiki markdown documents, listing or deleting documents, or managing the RAG search index in mixcore-cloud. Trigger on "wiki", "knowledge base", "RAG", "generate document", "search docs", or any task writing .md files to wwwroot/mixcontent/documents/wiki/.
argument-hint: "[search|generate|read|list|delete|reload] [query or path]"
allowed-tools:
  - mcp__mixcore__search
  - mcp__mixcore__generate_document
  - mcp__mixcore__read_document
  - mcp__mixcore__list_documents
  - mcp__mixcore__delete_document
  - mcp__mixcore__reload_wiki
---

# Mix RAG — Wiki Knowledge Base

All wiki document operations go through the MCP tools below. **Never use `mcp__mixcore__write_text_file` or `mcp__mixcore__read_text_file` for wiki documents** — those tools bypass the RAG index and leave it stale.

---

## MCP Tool Reference

| Operation | Tool | Notes |
|---|---|---|
| Semantic search | `mcp__mixcore__search` | BM25 + optional LLM rerank; `topK` default 5 |
| Create or update doc | `mcp__mixcore__generate_document` | Writes to disk **and** upserts into index atomically |
| Read a doc | `mcp__mixcore__read_document` | Returns raw markdown incl. frontmatter |
| List docs in folder | `mcp__mixcore__list_documents` | `recursive=true` for subtrees |
| Delete a doc | `mcp__mixcore__delete_document` | Removes from disk **and** de-indexes; requires `confirm='YES'` |
| Bulk reload index | `mcp__mixcore__reload_wiki` | Only after manual file edits outside the tools |

`generate_document` and `delete_document` update the in-memory index immediately — **no `reload_wiki` call needed** after individual document operations.

---

## Wiki Folder Structure

Base path on disk: `wwwroot/mixcontent/documents/wiki/<tenantId>/`

🚨 **The RAG index is tenant-scoped — the disk path MUST include the numeric `<tenantId>`.** `SiteWikiService`/`RAGSearchTool` resolve the wiki base as `wwwroot/mixcontent/documents/wiki/{CurrentTenantId}/` (see `WikiFolders.SiteKnowledges`). Use the resolved tenant id — **`1` for a default single-tenant install**. Files written outside the tenant folder are NOT indexed for that tenant.

```
wiki/
└── <tenantId>/            # numeric resolved tenant id — MANDATORY (e.g. 1)
    └── <site-name>/       # one folder per site — name = site slug
        ├── README.md      # (or index.md) site overview & index
        ├── database/      # one .md per MixDB table
        ├── forms/         # one .md per form/widget
        ├── modules/       # one .md per module
        ├── pages/         # one .md per page
        └── templates/     # one .md per template
```

**Tool-relative paths are relative to the tenant folder `wiki/<tenantId>/`** — so `read_document`/`generate_document`/`search` paths look like `<site-name>/database/contacts.md` (the tenant id is applied automatically by the tool from `CurrentTenantId`; do not prefix it). When writing files directly with the `Write` tool, you MUST include the full disk path with `<tenantId>`.

Discover the current site folder with:
```
mcp__mixcore__search(query: "site index tenant name slug", topK: 3)
```
or list folders under the tenant base:
```
mcp__mixcore__list_documents(folder: "", recursive: false)
```

> Examples throughout this skill use `<site-name>` as a placeholder for the site slug. The on-disk parent is always `wiki/<tenantId>/`.

---

## Creating a Document

`generate_document` accepts:

| Parameter | Required | Description |
|---|---|---|
| `title` | Yes | Human-readable title → slugified to filename |
| `content` | Yes | Markdown body (no frontmatter — generated automatically) |
| `folder` | No | Subfolder relative to `wiki/`, e.g. `<tenant-name>/database` |
| `tags` | No | Comma-separated, e.g. `cms,api,contacts` |
| `description` | No | One-line summary for search indexing |

The tool slugifies the title to a kebab-case filename:  
`"Contact Form"` → `contact-form.md`

**Generated frontmatter format:**
```yaml
---
title: "Contact Form"
date: 2026-05-23
description: "Handles contact submissions for the mixcore-cloud site."
tags: [cms,forms,contact]
---

# Contact Form
```

---

## YAML Front Matter Rules

Every wiki `.md` must have these fields:

| Field | Rule |
|---|---|
| `title` | Human-readable, title-cased |
| `date` | ISO date (`YYYY-MM-DD`) — set by `generate_document` automatically |
| `description` | 1–2 sentences for search indexing |
| `tags` | 4–8 lowercase kebab-case tags |

Do **not** use deprecated fields: `uuid`, `last_verified`.

---

## File Naming Rules

- All file and folder names: **lowercase kebab-case** only
- `"User Profile"` → `user-profile.md` ✅
- `UserProfile.md` ❌ · `user_profile.md` ❌ · `README.md` ❌

`generate_document` enforces this automatically. For manual paths (read/delete/list), pass kebab-case paths.

---

## How the RAG Index Works

`SiteWikiService` (a `VectorLessService`) loads `.md` files from `wiki/` at startup into an in-memory BM25 tree. Search uses BM25 pre-filter + optional LLM reranking.

- `generate_document` → calls `UpsertAsync` after writing to disk
- `delete_document` → calls `DeleteAsync` after removing from disk
- `reload_wiki` → full disk rescan; use only when files were changed outside the tools

The in-memory index is scoped to the server process. After a server restart it is rebuilt automatically from disk.

---

## Common Mistakes

| Mistake | Fix |
|---|---|
| Using `mcp__mixcore__write_text_file` for a wiki doc | Use `mcp__mixcore__generate_document` — it writes and indexes |
| Calling `reload_wiki` after every `generate_document` | Not needed; the tool indexes on every write |
| Passing an absolute path to read/delete | Pass relative path only, e.g. `mixcore-cloud/index.md` |
| Writing PascalCase or underscored filenames | Pass title to `generate_document`; it slugifies automatically |
| Including `---` frontmatter block in `content` | The `content` parameter is body only — frontmatter is auto-generated |

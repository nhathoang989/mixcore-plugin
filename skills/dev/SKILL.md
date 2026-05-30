---
name: dev
description: Entry point for SOURCE-CODE feature work in the mixcore-cloud repo — routes to the mixcore:* skill that edits C#/Blazor/project source to implement features (Blazor components, C# services & controllers, modules, EF migrations, dotnet CLI, xUnit tests). Trigger on "blazor", "razor component", "C#", "dotnet", "module", "IStartupService", "EF migration", "xUnit test", or any backend/Blazor development in this repo. For content CRUD via MCP use mixcore; to keep skill↔system-prompt docs in sync use mixcore:docs-sync.
argument-hint: "<describe your coding task — auto-routes to the right mixcore:* dev skill>"
---

# Mixcore Dev Skill Router

> **Scope:** this router covers tasks where the **AI edits repo source code to implement features** — C#, Blazor `.razor`, modules, EF migrations, dotnet CLI, xUnit tests. It does not CRUD CMS content. Sibling routers: **`mixcore:guide`** (content CRUD via MCP tools) · **`mixcore:docs-sync`** (CRUD developer docs, keep skills ↔ system-prompts consistent).

When invoked with a task (e.g. `/mixcore:dev add a Blazor sidebar` or `/mixcore:dev scaffold a payments module`), you **must**:

1. Match the task to ONE row in the Skill Map below (closest match wins; never ask)
2. **Invoke that skill via the `Skill` tool** — do not paraphrase or "act as" the skill
3. **Also scan the [.NET Plugin Skills](#net-plugin-skills-load-alongside-mix--skills) table** — if the task matches a row there, load that `dotnet-*:*` plugin skill **in addition** to the `mixcore:*` skill (the `mixcore:*` skill owns repo conventions; the plugin skill adds framework-level depth). This is not optional — when a row matches, you must load it before doing the specialized work.
4. After they load, execute the task

If the task needs multiple skills, run the combination pattern in order. The first skill in the chain is the one to invoke immediately.

---

## Skill Map

| Task signal | Skill |
|---|---|
| **Implement a written plan** — `/goal implement plan`, "execute plan", pointing to a `docs/superpowers/plans/*.md` file | `superpowers:subagent-driven-development` |
| Shadcn-style dashboard/UI shells from `BlazorBlueprint.Components` — layouts, data grids, charts, sidebars, forms, page blueprints | `mixcore:blazor-blueprint` |
| Blazor `.razor` components, pages, services, `HttpClient` wiring, render modes (`@rendermode`), routing, DI registration | `mixcore:blazor-app` |
| **Scaffold a module** — a brand-new standalone module/project from scratch (new csproj + `IStartupService` + sln registration) OR add a controller/service to an existing module | `mixcore:module` |
| C# 12 / .NET 10 code — **adding ViewModels, CQRS handlers, MCP tools, EF entities, or any non-controller/service class to an existing module**; `mix.heart` ViewModels, safe-default review | `mixcore:dotnet-code` |
| `dotnet build` / `dotnet test` / `dotnet run` / `dotnet add package` | `mixcore:dotnet-cli` |
| **EF Core migration** — adding `dotnet ef migrations add` after changing an entity in `mix.database` | `mixcore:migration` |
| xUnit tests — controller unit tests, migration tests, fake services, integration tests | `mixcore:tests` |

---

## .NET Plugin Skills (load alongside mixcore:* skills)

These come from the installed `dotnet-agent-skills` plugins. They are deep, single-purpose framework skills — they do **not** know this repo's conventions, so they complement the `mixcore:*` skills, never replace them. **Load the `mixcore:*` skill first** (repo conventions, tenancy, Newtonsoft, sequential tests), **then** load the matching plugin skill below for the specialized work. Invoke with the fully-qualified namespaced name (e.g. `dotnet-test:run-tests`).

| Task signal | Plugin skill |
|---|---|
| Running / filtering `dotnet test`, VSTest-vs-MTP syntax, TRX, blame/hang diagnostics | `dotnet-test:run-tests` |
| Auditing existing tests for anti-patterns / smells (no-assert, flaky, tautological) | `dotnet-test:test-anti-patterns` |
| Generating new tests or pushing coverage (xUnit) | `dotnet-test:code-testing-agent` |
| Coverage plateau, CRAP scores, risk hotspots | `dotnet-test:coverage-analysis` (or `dotnet-test:crap-score` for one method) |
| Finding weak tests / untested edge cases (mutation-style) | `dotnet-test:test-gap-analysis` |
| Assertion quality — shallow or assertion-free tests | `dotnet-test:assertion-quality` |
| EF Core query perf — N+1, tracking mode, compiled queries, `mix.database` slowness | `dotnet-data:optimizing-ef-core-queries` |
| Blazor component authoring, forms/input, API data fetch, prerendering, JS interop, auth | `dotnet-blazor:*` — `author-component`, `collect-user-input`, `fetch-and-send-data`, `support-prerendering`, `use-js-interop`, `configure-auth` |
| ASP.NET Core Web API design, OpenTelemetry wiring, minimal-API file upload | `dotnet-aspnet:dotnet-webapi`, `dotnet-aspnet:configuring-opentelemetry-dotnet`, `dotnet-aspnet:minimal-api-file-upload` |
| Slow builds, binlog analysis, `.csproj` anti-patterns, SDK-style modernization | `dotnet-msbuild:*` — `build-perf-diagnostics`, `binlog-failure-analysis`, `msbuild-antipatterns`, `msbuild-modernization` |
| Runtime perf diagnosis, traces, crash dumps | `dotnet-diag:*` — `analyzing-dotnet-performance`, `dotnet-trace-collect`, `dump-collect` |
| .NET version upgrade, nullable-reference migration, AOT compat | `dotnet-upgrade:*` — `migrate-dotnet9-to-dotnet10`, `migrate-nullable-references`, `dotnet-aot-compat` |
| Convert to Central Package Management (`Directory.Packages.props`) | `dotnet-nuget:convert-to-cpm` |
| Selecting AI/ML approach (Microsoft.Extensions.AI, Agent Framework) for `mix.ai` | `dotnet-ai:technology-selection` |
| Authoring / validating `dotnet new` templates | `dotnet-template-engine:*` — `template-authoring`, `template-validation`, `template-discovery`, `template-instantiation` |
| One-off file-based C# scripts (no project) | `dotnet:csharp-scripts` |

**Not applicable to this repo — do NOT load:**
- `dotnet-test:writing-mstest-tests`, `dotnet-test:migrate-mstest-*` — the repo uses **xUnit**, not MSTest.
- `dotnet11:system-text-json-net11` — **System.Text.Json is banned**; the repo mandates Newtonsoft.Json (`JObject`/`JToken`).
- `dotnet-maui:*` — no MAUI / mobile projects in this solution.

---

## Verify UX/UI with Playwright

**Whenever a task changes user-facing UI (Blazor components, `.razor` pages, admin dashboard, cloud portal, signup wizard, CSS/layout) and you need to confirm it actually renders/behaves correctly, drive it with Playwright before reporting done.** Do not claim a UI change works on the strength of a clean build alone — see it in the browser.

Playwright is an **MCP server**, not a `Skill`-tool skill, so its `browser_*` tools are deferred. Load them first:

```
ToolSearch  →  query: "playwright browser navigate snapshot click"
```

That surfaces `mcp__plugin_playwright_playwright__browser_navigate`, `browser_snapshot`, `browser_click`, `browser_take_screenshot`, `browser_fill_form`, `browser_console_messages`, etc. Then:

1. Make sure the app is running — `dotnet run --project src/apps/MixCore.Cloud.Web` (HTTP `:5247` → `http://localhost:5247`). Route prefixes: `/p` portal · `/a` admin · `/` landing.
2. `browser_navigate` to the affected route, `browser_snapshot` to read the accessibility tree, interact (`browser_click` / `browser_fill_form`), and check `browser_console_messages` for errors.
3. 🚨 **Screenshots must be saved under `.playwright*/` (gitignored)** — never under `wwwroot/` or any committed directory (CLAUDE.md rule).

For a guided run/verify flow you can also use the built-in `verify` or `run` skills; use raw Playwright MCP tools for fine-grained UI assertions.

---

## Combination Patterns (first skill = invoke now)

- **Implement plan end-to-end** → create branch (worktree) → `superpowers:subagent-driven-development` → create PR → `superpowers:requesting-code-review` → collect experiences → `mixcore:docs-sync` (sync docs)
- **New Blazor dashboard with live data** → `mixcore:blazor-blueprint` → `mixcore:blazor-app` (wire HttpClient + DI) → `mixcore:dotnet-code` (backend service) → **Playwright** (verify it renders + no console errors)
- **Scaffold a full feature module** → `mixcore:module` (skeleton + controller/service) → `mixcore:dotnet-code` (fill in logic) → `mixcore:dotnet-cli` (build + verify)
- **Backend bugfix + verify** → `mixcore:dotnet-code` → `mixcore:dotnet-cli` → `dotnet-test:run-tests` (run/filter the affected tests)
- **Tests for a new service** → `mixcore:dotnet-code` (review service) → `mixcore:tests` → `dotnet-test:code-testing-agent` (coverage) / `dotnet-test:test-gap-analysis` (find gaps)
- **Slow EF query / N+1** → `mixcore:dotnet-code` (locate query) → `dotnet-data:optimizing-ef-core-queries`
- **Slow / failing build** → `mixcore:dotnet-cli` → `dotnet-msbuild:build-perf-diagnostics` or `dotnet-msbuild:binlog-failure-analysis`
- **New Blazor page with backend service** → `mixcore:blazor-app` → `dotnet-blazor:fetch-and-send-data` (async lifecycle) → `mixcore:dotnet-code` → **Playwright** (verify UI/UX)
- **Add EF migration after schema change** → `mixcore:dotnet-code` (entity change) → `mixcore:migration` (run all 4 provider migrations)
- **Full feature (module + Blazor UI + tests)** → `mixcore:module` → `mixcore:dotnet-code` → `mixcore:blazor-app` → `mixcore:tests` → `mixcore:dotnet-cli`
- **Add controller / service / MCP tool to existing module** → `mixcore:dotnet-code` → `mixcore:dotnet-cli` (build + verify)
- **Brand-new standalone project with API** → `mixcore:module` (scaffold entire project) → `mixcore:dotnet-cli` (build + verify)

---

## Pre-Flight Check

Before planning or implementing any non-trivial task, read `docs/ONBOARDING.md`:

1. **Complexity Hotspots** — know which files require extra care before touching them (bottom section of the doc)
2. **Architecture Layers** — confirm where the new code belongs (module vs. cloud pillar vs. platform)
3. **Key Concepts** — review if the task touches tenancy, MixDB, YARP, or the RAG pipeline

Skip this only for single-file, clearly-scoped fixes where the file path is already known.

---

## Plan Implementation Workflow

When the user says "implement plan", `/goal implement plan`, or points to a `docs/superpowers/plans/*.md` file, follow this 6-step sequence in full. **Never skip a step.**

### Step 0 — Create branch
**Always work on a new branch in a git worktree.** Never implement a plan directly on `main` or the current branch.

```bash
# Derive the branch slug from the plan file name or plan title
git worktree add .worktrees/feat/<branch-slug> -b feat/<branch-slug>
```

Then do all edits, builds, and commits inside `.worktrees/feat/<branch-slug>/`.

If the plan already specifies a branch name, use that. Otherwise derive it from the plan filename (e.g. `docs/superpowers/plans/2026-05-26-remove-tenant-fallback.md` → `feat/remove-tenant-fallback`).

Alternatively invoke `superpowers:using-git-worktrees` for the full worktree setup workflow.

### Step 1 — Implement
Invoke `superpowers:subagent-driven-development` (REQUIRED). It dispatches one subagent per plan task with two-stage review between tasks.

### Step 2 — Create PR
After all tasks pass and `dotnet build` is clean, push the branch and open a PR against `main`:

```bash
# Push the worktree branch
git -C .worktrees/feat/<branch-slug> push -u origin feat/<branch-slug>

gh pr create \
  --base main \
  --head feat/<branch-slug> \
  --title "feat: <plan title>" \
  --body "$(cat <<'EOF'
## Summary
- <bullet 1>
- <bullet 2>

## Test plan
- [ ] `dotnet build src/MixCore.Cloud.sln` succeeds
- [ ] `dotnet test src/MixCore.Cloud.sln` passes
- [ ] Key scenario manually verified

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Return the PR URL to the user before proceeding.

### Step 3 — Review PR
Invoke `superpowers:requesting-code-review` (or run `/code-review` in-session). Address **all** findings before closing the task. Do not mark the task done while review findings remain open.

### Step 3.5 — Check READMEs before merge
**Before the PR is merged**, for every project (`.csproj` folder) the PR touched, open that project's `README.md` and decide whether it needs updating. Update it in the same PR if any of these changed:
- What the project does, or which MVC views / routes mount it
- Models, API endpoints, or backend contracts
- Validation rules, step/flow logic, or namespaces
- Non-obvious architectural decisions or constraints

If a touched project has no `README.md`, create one (see **Project README Rule**). Commit any README changes to the PR branch **before** merging — never merge with a stale or missing project README.

### Step 4 — Collect experiences
Capture what you learned that was NOT in the plan:
- Gotchas and incorrect plan assumptions
- Architectural constraints discovered at implementation time
- Patterns that worked well or failed

Write `feedback_*.md` and/or `project_*.md` to `~/.claude/projects/.../memory/` using the auto-memory front-matter format (`name`, `description`, `metadata.type`).

### Step 5 — Sync docs via mixcore:docs-sync
Invoke `mixcore:docs-sync` skill to propagate any new facts:
- `plugins/mixcore/skills/*/` — update if a pattern or gotcha changed
- `wwwroot/system-prompts/instructions/developer/developer-guide.md` — new architectural facts
- `docs/04-mixcore-cloud-technical-architecture.md` — if architecture decisions changed

---

## Boundary Rules

- **`mixcore:blazor-blueprint` vs `mixcore:blazor-app`**: `blueprint` = layout/grid/chart shells from `BlazorBlueprint.Components`. `app` = HttpClient, DI, routing, render modes. Complex dashboards start with `blueprint`, then `app` for wiring.
- **`mixcore:module` vs `mixcore:dotnet-code`**: `mixcore:module` owns the module *skeleton* (new csproj + `IStartupService` + sln entry) and its *controller/service* surface — for both brand-new projects and additions to an existing module. `mixcore:dotnet-code` fills in everything else (ViewModels, CQRS handlers, MCP tools, EF entities, general logic). Scaffold with `mixcore:module` first, then fill with `mixcore:dotnet-code`.
- **`mixcore:dotnet-code` vs `mixcore:dotnet-cli`**: `dotnet-code` writes/reviews C# source files. `mixcore:dotnet-cli` runs terminal commands (build, test, migrate). Use both — code first, CLI to verify.
- **`mixcore:tests` vs `mixcore:dotnet-cli`**: `mixcore:tests` generates test source files. `mixcore:dotnet-cli` runs them. Always pair.
- **Dev vs CMS**: If the task touches `.cshtml` Razor view templates, MixDB tables, or CMS pages/modules/posts — that's `mixcore:guide` (not `mixcore:dev`).

---

## Source Layout Quick Reference

```
src/
├── apps/MixCore.Cloud.Web/        # Deployable ASP.NET Core host
├── host/MixCore.Cloud.Host/       # .NET Aspire orchestrator (local dev only)
├── cloud/                         # 15 cloud pillar modules (auto-discovered)
│   ├── Mixcore.Cloud.Account/     # Tenant registration, provisioning
│   ├── MixCore.Cloud.Auth/        # OIDC SSO, MFA, API keys, SCIM
│   ├── MixCore.Cloud.Database/    # Per-tenant SQLite provisioning
│   ├── MixCore.Cloud.Gateway/     # YARP dynamic routing
│   └── ... (Billing, Edge, Flows, Mail, Mind, Monitor, Run, Signal, Vault, Vector)
├── modules/                       # Feature modules (auto-discovered)
│   ├── account/                   # mix.account, mix.auth
│   ├── admin/mix.admin.ui/        # Blazor admin panel
│   ├── ai/mix.ai/                 # Mix.Mind AI gateway, agents
│   ├── ai/mix.ai.ui/              # Blazor AI chat UI
│   ├── cloud/mix.cloud.ui/        # Cloud services UI
│   └── cms/                       # mix.content, mix.datasource, mix.cms.lib
├── platform/
│   ├── mix.lib/                   # Base controllers, extensions
│   ├── mix.database/              # EF Core DbContexts, entities, migrations
│   ├── common/mix.heart/          # UoW, generic repos, exceptions
│   ├── common/mix.shared/         # DTOs, middleware, MixAssemblyFinder
│   └── common/mix.ui.shared/      # Blazor shared components
└── tests/                         # One xUnit project per module
```

**Module auto-discovery**: Every module implements `IStartupService` in `Startup.cs`. The host calls `builder.ConfigureStartupServices(assemblies)` — no `Program.cs` edits needed when adding a new module, just reference the csproj.

---

## Project README Rule

**Every project (`.csproj`) must have a `README.md` at its root.**

The README is the first thing an agent reads before touching code in that project. It must cover:
- What the project does and which MVC views / routes mount it
- Key sub-apps or components inside it (layout, namespaces)
- Any non-obvious architectural decisions or constraints
- API endpoints and backend contracts the project depends on

**Before working on any project:**
1. Read `<project-root>/README.md` if it exists.
2. If it does not exist, create one before or alongside your other changes.

**After completing changes to a project:**
1. Update `README.md` to reflect what changed — models, endpoints, validation rules, step flows, or architectural decisions.

**Before merging a PR:**
1. For each project folder the PR touched, re-open its `README.md` and verify it still matches the code. Update (or create) it in the same PR — never merge with a stale or missing project README. See **Step 3.5** in the Plan Implementation Workflow.

**Known project READMEs:**

| Project | README |
|---|---|
| `mix.cloud.ui` | `src/modules/cloud/mix.cloud.ui/README.md` — covers signup wizard, dashboard shell, styling |

---

## Architecture Constraints (always enforce)

- **Newtonsoft.Json only** — never `System.Text.Json`. Use `JObject`/`JToken` throughout.
- **Parameterized SQL only** — never string interpolation.
- **Tests run sequentially** — `[assembly: CollectionBehavior(DisableTestParallelization = true)]` must not be removed.
- **Integration tests → real PostgreSQL** — no DB mocks.
- **API keys** → SHA-256 hash storage. Credentials → AES-256-GCM.
- **FluentValidation** for all validation logic.
- Default to `net10.0` TFM.

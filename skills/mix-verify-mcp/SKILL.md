---
name: mix-verify-mcp
description: Round-trip-verify a mixcore-cloud /mcp tool end-to-end without disrupting the running dev app — isolated git worktree on an alternate port + stateless SSE JSON-RPC calls to /mcp. Use after adding or changing an MCP tool (server-side behavior a build + unit test can't fully prove).
argument-hint: "[tool_name] [merge-sha-or-branch]"
allowed-tools:
  - Bash
  - Read
---

You are verifying that a **mixcore-cloud `/mcp` tool** works end-to-end against a *running* host — the part a clean build and unit tests can't prove (real DI graph, runtime Razor compilation, MCP registration + transport). Do this without taking down the user's existing app on `:5000`.

## When to use

- You added or changed an MCP tool (a `[McpServerTool]` method in `src/modules/ai/mix.ai/Application/Mcp/McpTools/`) and need to confirm it registers and behaves correctly through the real MCP server.
- A tool's behavior depends on runtime services not exercised by unit tests (e.g. `ICompositeViewEngine` runtime compilation, `IMixDbDataService`, tenant resolution).
- Build is green and unit tests pass, but you want a live round-trip before claiming done.

Pair with `mixcore:mix-dev-dotnet-cli` (build) and `mixcore:mix-dev-dotnet-code` (the tool source). For UI/browser checks use Playwright instead (see `mixcore:mixdev` → "Verify UX/UI with Playwright").

---

## 0. Ask for the account/credentials BEFORE executing

🚨 **CRITICAL RULE: do not assume, auto-extract, or hardcode credentials. At the start of every run, ask the user which account to use** and wait for the answer before launching anything. `/mcp` is gated by `RequireAuthorization("AITools")`, which accepts **either**:

- an **`X-Api-Key`** (service-to-service) — the `Authentication:ServiceApiKey` value, **or**
- a **Bearer JWT** for a real user account (needed when the tool's behavior depends on the signed-in user / tenant).

Ask via `AskUserQuestion`, e.g. *"Which account/credentials should the verification run use?"* with options like **Service api-key** (paste it, or confirm reading it from the rsync'd `authsettings.json`), **a user login** (get email + password → exchange for a JWT, see `mixcore:mix-dev-dotnet-cli` / the REST `…/auth/login` endpoint), or **a JWT they paste directly**. Only read `ServiceApiKey` from `authsettings.json` when the user explicitly approves that. Use the supplied credential as `$KEY` (api-key) or `$JWT` (bearer) in the calls below — for a JWT, send `-H "Authorization: Bearer $JWT"` instead of the `X-Api-Key` header.

---

## Why the worktree + alt port

🚨 **CRITICAL RULE: never build the main tree while the dev app is running on `:5000`.** They share `bin/`, so the build locks/replaces DLLs the live process holds and takes the app (and its MCP server) down. Run the code-under-test from an **isolated git worktree** (separate `bin/obj`) on an **alternate port** so the user's `:5000` app keeps serving untouched.

The session's `mixcore` MCP client points at `:5000` (the *old* code) and won't auto-rediscover a new tool mid-session — so call the new instance's `/mcp` **directly over HTTP**, don't rely on the `mcp__mixcore__*` tools.

---

## Workflow

### 1. Isolated worktree at the code under test

```bash
git worktree add --detach .worktrees/verify-<slug> <merge-sha-or-branch>
cd .worktrees/verify-<slug>
git log --oneline -1   # confirm it's the commit you intend; `main` may point past your merge
```

If `main` already advanced past your merge, `git checkout <your-merge-sha>` explicitly.

### 2. Copy runtime content (gitignored)

`wwwroot/mixcontent` is gitignored (`.gitignore: mixcontent*`), so a fresh worktree lacks it. It carries `InitStatus:"Done"` and the MCP api key — without it the app shows the install wizard and `/mcp` 401s.

```bash
rsync -a --delete \
  ../../src/apps/MixCore.Cloud.Web/wwwroot/mixcontent/ \
  src/apps/MixCore.Cloud.Web/wwwroot/mixcontent/
```

- `InitStatus` + provider live in `mixcontent/setting-files/appsettings.json`.
- MCP key: `mixcontent/setting-files/authsettings.json` → `Authentication:ServiceApiKey`.

Each instance uses its **own** mixcontent copy, so the per-tenant SQLite files don't clash with the `:5000` app.

### 3. Build (isolated) and run on an alternate port

```bash
dotnet build src/apps/MixCore.Cloud.Web/MixCore.Cloud.Web.csproj -v q --nologo
cd src/apps/MixCore.Cloud.Web
ASPNETCORE_ENVIRONMENT=Development ASPNETCORE_URLS=http://localhost:5099 \
  nohup dotnet run --no-build --project MixCore.Cloud.Web.csproj > /tmp/verify5099.log 2>&1 &
```

The MQTT broker still tries port 1883 (MQTTnet default) and fails to bind because the `:5000` app owns it — that exception is swallowed, so HTTP/`/mcp` still serves. Poll until ready, authenticating with the credential the user gave you in **Step 0** (`$KEY` = api-key, or `$JWT` = bearer):

```bash
# $KEY / $JWT come from Step 0 (user-supplied). Only read authsettings.json if the user approved it:
#   KEY=$(python3 -c "import json;print(json.load(open('src/apps/MixCore.Cloud.Web/wwwroot/mixcontent/setting-files/authsettings.json'))['Authentication']['ServiceApiKey'])")
for i in $(seq 1 60); do
  code=$(curl -s -m 3 -o /dev/null -w "%{http_code}" -X POST http://localhost:5099/mcp \
    -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' \
    -H "X-Api-Key: $KEY" \
    -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}')
  [ "$code" = 200 ] && { echo "READY ($i s)"; break; }; sleep 1
done
```

### 4. Call the tool over stateless SSE JSON-RPC

The `/mcp` endpoint is **stateless** (`.WithHttpTransport(o => o.Stateless = true)`): a single POST works — **no `initialize` handshake**. Required headers: `Content-Type: application/json`, `Accept: application/json, text/event-stream`, `X-Api-Key: <ServiceApiKey>`. The response is **SSE** (`event: message\ndata: {json}`) — strip the `data: ` prefix. The tool's string result is at `result.content[0].text` (itself JSON from the tool's `Success()`/`Error()`).

```bash
call() { curl -s -m 30 -X POST http://localhost:5099/mcp \
  -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' \
  -H "X-Api-Key: $KEY" -d "$1"; }

call '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"<tool_name>","arguments":{ ... }}}' \
 | sed 's/^data: //' \
 | python3 -c "import sys,json;l=[x for x in sys.stdin.read().splitlines() if x.startswith('{')][0];print(json.dumps(json.loads(json.loads(l)['result']['content'][0]['text']),indent=2))"
```

🚨 **Naming**: MCP method names are **snake_cased** (`ValidateTemplate` → `validate_template`); **parameter names stay camelCase** (`templateId`, `folderType`); enum params serialize as their string names. Confirm the exact names with a `tools/list` call before `tools/call`.

Run a small matrix: a success case, the failure case(s) the change targets, and any skip/edge branch. Confirm the structured fields (not just HTTP 200).

### 5. Teardown (always)

```bash
kill $(lsof -ti :5099) 2>/dev/null
curl -s -m 5 -o /dev/null -w "user app :5000 -> %{http_code}\n" http://localhost:5000/mcp \
  -X POST -H 'Accept: application/json, text/event-stream' -H "X-Api-Key: $KEY" \
  -H 'Content-Type: application/json' -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}'   # confirm :5000 intact
cd ../.. && git worktree remove --force .worktrees/verify-<slug>
```

---

## Gotchas

- **`tools/list` first** — verifies registration (a new `[McpServerToolType]` is auto-discovered via `.WithToolsFromAssembly`) and gives you the exact snake_case name + camelCase param schema before calling.
- **401 on `/mcp`** → the api key didn't match or `InitStatus != Done`; re-check the rsync'd `authsettings.json`/`appsettings.json`.
- **Empty/`event: ` SSE with no `data:`** → you sent a malformed body or missing `Accept: text/event-stream`.
- **Background `dotnet run`** may report "completed" immediately when launched via `nohup … &`; the detached process keeps running — confirm with the readiness poll, not the launcher's exit.
- This is the **code-axis** counterpart to browser verification; it doesn't render pages. For visual/UX confirmation use Playwright.

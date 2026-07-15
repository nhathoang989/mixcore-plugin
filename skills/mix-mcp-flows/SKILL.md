---
name: mix-mcp-flows
description: Use when creating, managing, triggering, or monitoring Flows workflows via MCP tools — creating webhook/schedule/manual workflows, defining steps (HttpRequest, SendEmail, SignalRBroadcast, QueuePublish), triggering runs, reading run history, or cancelling in-progress executions. Trigger whenever the user mentions automating workflows, creating triggers, scheduling jobs, setting up webhooks that execute actions, monitoring workflow runs, or building anything that resembles "if X happens, do Y then Z."
argument-hint: "[create|list|trigger|history|cancel|update] [workflow description]"
---

You are working with **Mix.Flows** — the visual workflow automation engine for mixcore-cloud. Workflows are composed of a trigger (when to fire) and a sequence of action steps (what to do). MCP tools let you create, manage, trigger, and monitor workflows without writing any C# code.

The MCP tools live in the **mix.ai server** (endpoint `/mcp`, requires `AITools` authorization). Every tool accepts an optional `tenantId` — omit it to resolve from the current request domain.

---

## Quick reference

| Tool | What it does |
|------|-------------|
| `ListWorkflows` | List all workflows for the tenant |
| `GetWorkflow(id)` | Get a workflow + all steps by GUID |
| `CreateWorkflow(...)` | Create a new workflow with steps |
| `UpdateWorkflow(id, ...)` | Replace a workflow's config and steps |
| `DeleteWorkflow(id, confirm:"YES")` | Delete a workflow (irreversible) |
| `ToggleWorkflow(id)` | Enable / disable a workflow |
| `TriggerWorkflow(workflowId)` | Manually fire a workflow (async) |
| `GetRunHistory(workflowId)` | Last 100 execution runs with step results |
| `CancelRun(runId)` | Cancel an in-progress run |

---

## Trigger types

Choose the trigger that matches how the workflow should fire:

| `triggerType` | `triggerConfigJson` | When it fires |
|---|---|---|
| `Manual` | `{}` | Only when explicitly called via `TriggerWorkflow` or `POST /trigger` |
| `Webhook` | `{"path":"/hooks/your-path"}` | When `POST /api/v1/flows/hooks/your-path` is called (anonymous) |
| `Schedule` | `{"cron":"*/5 * * * *"}` | On a cron expression (NCrontab, 1-min minimum resolution) |
| `QueueEvent` | `{"topic":"Flows","action":"your.event"}` | Fires when a `QueuePublish` step in another workflow publishes a matching message |

Common cron examples:
- Every 5 minutes: `"*/5 * * * *"`
- Every hour at :00: `"0 * * * *"`
- Daily at 8:00 AM: `"0 8 * * *"`
- Every weekday at 9:00 AM: `"0 9 * * 1-5"`

🚨 **CRITICAL RULE — cron is always UTC; default to the requester's timezone.** Flows `TriggerConfig` has **no `timeZone` field**; `ScheduledTriggerJob` evaluates every cron in **UTC**. So a clock time in the cron is a UTC clock time. When the request specifies a timezone, convert that wall-clock time to UTC for the cron. **When the request does NOT specify a timezone, interpret the requested clock time in the requester's local timezone** (e.g. the session/host timezone), convert it to UTC, and **state the conversion you made** in your reply (e.g. "09:30 ICT = 02:30 UTC → `30 2 * * *`"). Never silently store the local clock time as if it were UTC.

## Action step schemas

Each step in `stepsJson` is `{"order":N,"actionType":"...","config":"<JSON string>","continueOnError":false}`.

> 🚨 **`config` MUST be a STRINGIFIED JSON string, not a nested object.** The engine's `CreateWorkflowStepDto.Config` is a `string`; a nested object fails with `Could not parse stepsJson: Unexpected character … Path '[0].config'`. Build each `config` object, then `JSON.stringify` it into the step. The config blocks below show the *shape*; serialize them to strings before sending. Easiest: build the whole `stepsJson` programmatically (e.g. Python `json.dumps`, with `config=json.dumps(obj)`) rather than hand-escaping triple-nested quotes.

**`order`** starts at 1 and must be unique across steps. Set `continueOnError:true` if this step's failure should not abort the workflow.

### HttpRequest
```json
{
  "method": "POST",
  "url": "https://api.example.com/webhooks/notify",
  "headers": { "X-Api-Key": "abc123" },
  "body": { "event": "user.signup", "email": "{{payload.email}}" }
}
```
`method` defaults to `GET`. Body is omitted for GET/DELETE. On non-2xx response the step fails.

### SendEmail
```json
{
  "to": "{{payload.email}}",
  "cc": "ops@example.com",
  "subject": "Welcome to the platform",
  "body": "Hi {{payload.name}}, your account is ready.",
  "templateId": "welcome-v1"
}
```
`templateId` and `cc` are optional. `to`, `cc`, `subject`, and `body` all support parameter injection. `to`/`cc` accept **multiple recipients** as a comma/semicolon-separated list (e.g. `a@x.com,b@y.com`). The step **fails** if the provider reports a delivery failure (e.g. SMTP not configured — blank `Smtp:Server`).

### SignalRBroadcast
```json
{
  "event": "notification.new",
  "hub": "notifications",
  "group": "tenant-admins",
  "payload": { "message": "New signup: {{payload.email}}" }
}
```
`hub` defaults to `"notifications"`. Omit `group` to broadcast to all connected clients.

### QueuePublish
```json
{
  "topic": "billing",
  "action": "invoice.created",
  "data": { "userId": "{{payload.userId}}", "amount": "{{payload.amount}}" }
}
```
Publishes a message to the in-process queue. Another subscriber picks it up.

### AskAI
**Agent-backed** (since #280) — runs the same full AI agent the admin helpdesk uses, carrying the whole MCP tool-belt. So ONE AskAI step can both **generate** content and **act** on it (e.g. read a table, fetch a URL, insert MixDB rows) from a single natural-language prompt — no separate login/HttpRequest/insert steps. Tokens stream live to the flow-detail UI (`FlowsHub`) as the agent works. Owned by **mix.ai**, not the Flows project (mix.ai → Flows dependency).
```json
{
  "prompt": "Read table 'news_article', fetch https://techcrunch.com/feed/, insert any new articles, then reply with the inserted titles.",
  "sessionId": "optional-conversation-id",
  "model": "optional-model-id",
  "provider": "optional-provider-name"
}
```
- `prompt` is required. `sessionId`, `model`, and `provider` are optional. **No `url` / `apiKey` / `body` / `json` / `responsePath`** — those were the old HTTP handler and no longer exist.
- **`planId`** (optional) — binds the agent to an EXISTING `AIPlan`: its `update_plan`/`revise_step` calls edit that plan's steps instead of creating a fresh plan (used by the site-build review workflow's planner/updater steps). Placeholder-friendly (`"{{payload.planId}}"`).
- **`planOnly: "true"`** (optional, only with `planId`) — marks the run as plan-AUTHORING: at turn end the loop restores the plan to `Pending` instead of finalizing it terminal (an un-executed plan must not be stamped Incomplete). The prompt should still say "do NOT execute any build step".
- **`failOnPrefix`** (optional) — when the agent's reply STARTS with this prefix (first non-empty line, case-insensitive), the step is recorded **FAILED** even though the agent ran fine, while the reply still travels as the step's output. This is how a reply's CONTENT can drive `OnError` branch edges (e.g. a reviewer step whose `FAIL: <reason>` verdict must divert the flow to a repair step) — the engine itself only branches on step success/error. 🚨 A `failOnPrefix` step MUST have a matching `OnError` (or fallback) edge: without one, a normal business rejection ends the WHOLE run `Failed` — indistinguishable from an infrastructure failure on dashboards.
- `provider` selects the LLM provider (e.g. `"Groq"`, `"DeepSeek"`); omitted → default provider.
- Tools run **auto-approved** (unattended; approval-gated tools execute without a human in the loop) and are tenant-scoped, so the agent can only touch the run's own tenant.
- Output: `{ "content": "<final answer>", "planId"?: "…" }`. Downstream: `{{steps.<n>.content}}` (no `.output` segment — see Parameter injection).

> The AskAI agent owns tool selection: describe the goal, not the HTTP calls. To pin an exact tool + arguments with no agent reasoning, use **CallMcpTool** instead.

### CallMcpTool
Invokes a **single named MCP tool** directly — no agent loop. Use when the flow already knows exactly which tool and arguments to run (`AskAI` is for "reason about which tool(s) to call"). Owned by **mix.ai**.
```json
{
  "tool": "create_row",
  "arguments": { "tableName": "news_article", "data": { "title": "{{steps.0.content}}" } }
}
```
- `tool` (required) — snake_case MCP tool name. `arguments` (object) — passed verbatim; `{{steps.N.field}}` / `{{payload.x}}` placeholders inside are resolved before the tool runs.
- The run's **tenant is stamped into the `tenantId` argument**, overriding any value in config — a flow can never reach across tenants.
- Output: the tool's JSON result `{ ...toolResult }`, or `{ "raw": "<text>" }` for a non-JSON result.

### SendSocialMessage
Sends a message over a social channel — one action, swappable backend (like Mix.Mind). The `provider` key picks the channel; **Telegram** ships today (Zalo, FB Messenger, … as more `ISocialMessageProvider`s register — no engine change).
```json
{
  "provider": "telegram",
  "botToken": "<BotFather token>",
  "chatId": "5003738008",
  "text": "📰 New posts:\n{{steps.0.content}}",
  "parseMode": "HTML",
  "disableWebPagePreview": true
}
```
- Telegram config: `botToken`, `chatId` (numeric id, `@channelusername`, or a placeholder), `text` all required; `parseMode` (`HTML`/`Markdown`/`MarkdownV2`) and `disableWebPagePreview` (bool) optional. The bot token lives in the step config (visible in the workflow definition; only ever placed in the request URL, never logged).
- The step **fails** (not false-success) when the channel reports an error, so a message that never sent does not read as Succeeded. Set `continueOnError:true` if a delivery failure should not abort the run.

### RunScript
**Not available** in this version — `ActionType.RunScript` is a Phase 3 stub (JS sandbox) and any RunScript step fails immediately with `"RunScript action is not available in this version"`. Don't author flows that depend on it yet.

---

## Parameter injection

Use `{{placeholder}}` in any string-valued config field to inject values at run time:

| Placeholder | Resolves to |
|---|---|
| `{{payload.fieldName}}` | Field from the trigger payload (webhook body, manual trigger data) |
| `{{payload}}` | Entire trigger payload as a JSON string |
| `{{steps.0.fieldName}}` | Output field of the step with `order:1` (**slot = order − 1**, so `steps.N` = step `order:N+1` — exact even in branch/loop graphs) |
| `{{steps.0.result.accessToken}}` | Nested field — dot-navigate into the step's output object |
| `{{steps.1}}` | Entire output of step at index 1 |
| `{{email}}` | Short form — looks in payload first, then step outputs |

Inject into URLs, email addresses, message bodies, headers, and nested JSON values. A placeholder that resolves to nothing is left as the literal `{{…}}` text.

**Slot semantics:** step outputs live in per-`order` slots (`steps.N` = the step with `order N+1`), and a step re-run through a loop edge **overwrites its slot** — downstream references always read the latest iteration, never a stale first attempt. A slot for a step that never ran resolves to nothing (the literal placeholder leaks through — a consumer can use that as a "this lane never ran" signal).

🚨 **There is NO `.output` segment.** The engine stores each step's output object *directly* in the `steps` array (`WorkflowEngine` does `stepOutputs.Add(result.Output)`), so you reference a field as `{{steps.<n>.<field>}}`, **not** `{{steps.<n>.output.<field>}}` (which resolves to null → the literal placeholder leaks into the config). Per action type, the step's output object is: **AskAI** → `{content, planId?}` (use `{{steps.<n>.content}}`); **CallMcpTool** → the tool's JSON result (drill straight in, e.g. `{{steps.<n>.id}}`); **HttpRequest** → the parsed JSON response body itself (login → `{{steps.<n>.result.accessToken}}`); **SendEmail** → `{to}`; **SendSocialMessage** → the channel's API response (Telegram `{ok, result}`); **QueuePublish/SignalRBroadcast** → their echoed config.

**Injected values are JSON-escaped before substitution** (`ParameterInjector.Inject` calls `EscapeJsonStringContent` on each resolved value — `"`, `\`, newlines, tabs, etc. are escaped — before splicing it into the serialized config string and re-parsing). A literal double-quote or newline inside an injected value is safe; it no longer breaks the re-parse. Still prefer single-line HTML/text from an upstream `AskAI` step for readability, but it's a style preference now, not a correctness requirement.

---

## Gotchas (hard-won)

- **`config` is a JSON *string*, not an object** — see the 🚨 note under [Action step schemas](#action-step-schemas). The single most common `CreateWorkflow`/`UpdateWorkflow` failure.
- **Step indices are 0-based, step `order` is 1-based** — the step with `order:1` is referenced as `{{steps.0.…}}`, `order:2` → `{{steps.1.…}}`.
- **Outputs are NOT wrapped in `.output`** — reference `{{steps.0.<field>}}`, never `{{steps.0.output.<field>}}` (the `.output` key does not exist → resolves null → literal placeholder leaks). An `HttpRequest` step's output *is* the parsed JSON response body, so drill straight into it (e.g. login → `{{steps.0.result.accessToken}}`).
- **Calling an *authenticated* Mixcore endpoint from a flow:** add a first `HttpRequest` step that logs in — `POST /api/v1/rest/auth/login` with body `{"userName":"…","password":"…"}` → token at `{{steps.0.result.accessToken}}` — then pass it as an `Authorization: Bearer {{…}}` header on later `HttpRequest` steps. (Tokens are short-lived but minted fresh each run.) For Mixcore data work, prefer an `AskAI` or `CallMcpTool` step instead — both run tenant-scoped through the MCP tool-belt and need no login step.
- **`SendEmail` to many recipients:** `to` (and `cc`) accept a comma/semicolon-separated list (parsed via `InternetAddressList`). Flows has **no foreach**, so to email a dynamic audience (e.g. all `newsletter_subscriber` rows), use an `AskAI` step that outputs ONLY the comma-joined address list, then `to: {{steps.<n>.content}}`. The step **fails** if the email provider reports failure — e.g. a blank `Smtp:Server` in `setting-files/smtp.json` (configure SMTP before relying on delivery).
- **Newsletter pattern (N items → all subscribers), no foreach:** step 1 `AskAI` → ONLY the comma-joined subscriber emails; step 2 `AskAI` → ONLY a single-line, single-quoted HTML digest of the N rows; step 3 `SendEmail` `to:{{steps.0.content}}` `body:{{steps.1.content}}`. Two independent AI outputs feed one send.
- **Typed columns when a flow POSTs to a MixDB insert** (`/api/v1/rest/mixdb/data/{table}`): placeholder injection yields **strings**. Quoting a number/bool/timestamp value (e.g. `"category_id":"{{…}}"`, `"published_at":"{{…}}"`) can fail server-side with PostgreSQL `42804: column … is of type … but expression is of type text`. Keep typed (int/bool/timestamp) columns OUT of a flow-built insert body, or generate the row with an agentic AI step that inserts via its own tools. (Server-side type coercion for this path is being improved.)
- **Scheduler → flow:** a Scheduler job (Webhook action) fires a flow by POSTing to the flow's webhook trigger `POST /api/v1/flows/hooks/{path}`. Build the flow with a **Webhook** trigger so both the scheduler and a manual `TriggerWorkflow` can run it.
- **Debug a failing run** by reading `GetRunHistory` → the first `stepResults` entry with `success:false`; each entry's `output` shows what that step produced (e.g. an `AskAI` step's generated JSON), which is what later `{{steps.N.<field>}}` placeholders see. If a downstream config still shows a literal `{{steps.N.…}}`, the path didn't resolve — most often a stray `.output` segment.

---

## Common patterns

For more detailed examples, see [`references/examples.md`](references/examples.md).

### Webhook → notify Slack-compatible endpoint
```
CreateWorkflow(
  name: "New User Alert",
  triggerType: "Webhook",
  triggerConfigJson: '{"path":"/hooks/user-created"}',
  stepsJson: '[{"order":1,"actionType":"HttpRequest","config":{"method":"POST","url":"https://hooks.example.com/services/abc","body":{"text":"New signup: {{payload.email}}"}}}]'
)
```

### Scheduled health ping
```
CreateWorkflow(
  name: "Daily Health Check",
  triggerType: "Schedule",
  triggerConfigJson: '{"cron":"0 9 * * *"}',
  stepsJson: '[{"order":1,"actionType":"HttpRequest","config":{"method":"GET","url":"https://status.example.com/health"},"continueOnError":false}]'
)
```

### Manual with email confirmation
```
CreateWorkflow(
  name: "Send Report",
  triggerType: "Manual",
  triggerConfigJson: '{}',
  stepsJson: '[{"order":1,"actionType":"SendEmail","config":{"to":"{{payload.recipient}}","subject":"Your report","body":"Report attached."}}]'
)
```

---

## Key rules

- **`triggerConfigJson` in UpdateWorkflow**: pass `null` to keep existing config, or pass the full JSON to replace it — never pass `"{}"` if you want to preserve a Webhook path or Schedule cron.
- **`isActive` in UpdateWorkflow**: always pass the current `isActive` value explicitly when updating other fields — the default `true` will re-activate a workflow you deliberately disabled.
- **`stepsJson`** must be a valid JSON array string, even for zero steps (`"[]"`).
- **`actionType` strings** are case-sensitive: `HttpRequest`, `SendEmail`, `SignalRBroadcast`, `QueuePublish`, `AskAI`, `CallMcpTool`, `SendSocialMessage`. (`RunScript` exists but is a Phase 3 stub that always fails.)
- **`TriggerWorkflow`** is async — it returns `{queued:true}` immediately. Use `GetRunHistory` to poll for the result.
- **`DeleteWorkflow`** requires `confirm:"YES"` and is irreversible.
- **`CancelRun`** must be called with a *run* GUID (from `GetRunHistory`), not a *workflow* GUID.

---

## Reading run history

`GetRunHistory(workflowId)` returns the last 100 runs, each with:

| Field | Meaning |
|---|---|
| `id` | Run GUID — pass to `CancelRun` |
| `status` | `Pending` → `Running` → `Succeeded` / `Failed` / `Cancelled` |
| `startedUtc` / `finishedUtc` | Timestamps |
| `errorMessage` | Set if the overall run failed |
| `stepResults` | JSON array of per-step results: `{order, actionType, success, durationMs, output, error}` |

To diagnose a failed run: look at the first step where `success:false` in `stepResults` and read its `error` field.

---

## Branch edges (Phase 3 — conditional flows)

Pass `edgesJson` to `CreateWorkflow` / `UpdateWorkflow` to define conditional routing between steps:

```json
[
  {"from": 1, "to": 2, "branch": "OnSuccess"},
  {"from": 1, "to": 3, "branch": "OnError"}
]
```

`branch` values: `Always` | `OnSuccess` | `OnError`. When edges are omitted, the engine runs steps in `order` sequence (linear mode).

### Bounded loops (`maxVisits`) + `fallback` edges

By default each step runs **at most once per run**. Two optional edge fields lift that for controlled retry/repair loops:

```json
[
  {"from": 1, "to": 2, "branch": "OnSuccess"},
  {"from": 2, "to": 4, "branch": "OnSuccess"},
  {"from": 2, "to": 3, "branch": "OnError", "maxVisits": 2},
  {"from": 2, "to": 3, "branch": "OnError", "fallback": true},
  {"from": 3, "to": 2, "branch": "Always", "maxVisits": 2}
]
```

- **`maxVisits: N`** marks a LOOP edge — it may re-enqueue an already-executed step, at most N traversals per run. 🚨 **Every edge participating in a cycle needs `maxVisits`** (re-entering either node of the cycle is a revisit); a cycle edge without it is silently dead. Non-positive values are ignored (edge degrades to once-only).
- **`fallback: true`** marks an edge that fires **only when the node's matching non-fallback edges enqueued nothing** (loop budget spent, or every target already ran) — the loop's deterministic exit lane. Put the fallback on the node that DECIDES (e.g. the failing reviewer), not on the loop body, if only the decider's output may reach the exit target.
- A step re-run via a loop edge **overwrites its output slot** — downstream `{{steps.N.field}}` placeholders always read the step's **latest** output (see Parameter injection).
- Example above: step 2 failing routes to 3 (repair) at most twice; 3 loops back into 2; when the budget is spent and 2 still fails, 2's own fallback edge exits. A run guard (`(steps+1)×8` iterations) backstops malformed graphs.

---

## MCP Tools

<!-- mcp-tools:auto (generated by docs-sync; canonical names from live tools/list) -->
Canonical `/mcp` tools this skill owns (exact `tools/list` names; confirm signatures live via ToolSearch).

- **Workflows** — `create_workflow`, `list_workflows`, `get_workflow`, `update_workflow`, `delete_workflow`, `toggle_workflow`, `trigger_workflow`
- **Runs** — `get_run_history`, `cancel_run`
<!-- /mcp-tools:auto -->

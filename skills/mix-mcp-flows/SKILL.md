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
| `QueueEvent` | `{"topic":"your-topic"}` | When a message arrives on that queue topic (Phase 3) |

Common cron examples:
- Every 5 minutes: `"*/5 * * * *"`
- Every hour at :00: `"0 * * * *"`
- Daily at 8:00 AM: `"0 8 * * *"`
- Every weekday at 9:00 AM: `"0 9 * * 1-5"`

---

## Action step schemas

Each step in `stepsJson` is `{"order":N,"actionType":"...","config":{...},"continueOnError":false}`.

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
  "subject": "Welcome to the platform",
  "body": "Hi {{payload.name}}, your account is ready.",
  "templateId": "welcome-v1"
}
```
`templateId` is optional. `to`, `subject`, and `body` all support parameter injection.

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

---

## Parameter injection

Use `{{placeholder}}` in any string-valued config field to inject values at run time:

| Placeholder | Resolves to |
|---|---|
| `{{payload.fieldName}}` | Field from the trigger payload (webhook body, manual trigger data) |
| `{{payload}}` | Entire trigger payload as a JSON string |
| `{{steps.0.output.fieldName}}` | Output field from step at index 0 (0-based) |
| `{{steps.1.output}}` | Entire output of step at index 1 |
| `{{email}}` | Short form — looks in payload first, then step outputs |

Inject into URLs, email addresses, message bodies, headers, and nested JSON values.

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
- **`actionType` strings** are case-sensitive: `HttpRequest`, `SendEmail`, `SignalRBroadcast`, `QueuePublish`.
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

---
name: mix-mcp-schedule
description: Use when creating, managing, running, or monitoring scheduled (cron) jobs via MCP tools — creating cron jobs that fire a Webhook or QueuePublish action, listing/getting jobs, updating cron or action config, enabling/disabling, running a job immediately (manual run), or reading run history. Trigger whenever the user mentions cron jobs, scheduled tasks, recurring jobs, "run every N minutes/hours/days", periodic webhooks, or anything resembling "on a schedule, do X." For event/webhook-triggered multi-step automations use mixcore:mix-mcp-flows instead.
argument-hint: "[create|list|get|update|delete|toggle|run|history] [job description]"
---

You are working with **Mix.Scheduler** (`MixCore.Cloud.Scheduler`) — the cron-driven scheduled-job engine for mixcore-cloud. A scheduled job is a 5-field cron expression plus a single action that runs when the cron fires. MCP tools let you create, manage, run, and monitor jobs without writing any C# code.

The MCP tools live in the **mix.ai server** (endpoint `/mcp`, requires `AITools` authorization) — the same server as the Flows tools. Every tool accepts an optional `tenantId`; omit it to resolve from the current request domain.

> **Scheduler vs Flows.** Use **Mix.Scheduler** (this skill) when the trigger is purely **time-based** (cron) and runs **one** action. Use **`mixcore:mix-mcp-flows`** when you need a **webhook/manual/queue trigger** or a **multi-step** pipeline with branching. A Flows `Schedule` trigger and a Scheduler job overlap for simple recurring single actions — prefer Scheduler when there are no extra steps.

> **Availability.** These tools are provided by `SchedulerTool` in the mix.ai assembly ([issue #168](https://github.com/mixcore-cloud/platform/issues/168)). If `tools/list` does not show them, the tool has not been built/deployed yet — escalate per the router's GitHub-issue rule rather than editing source from an MCP session.

---

## Quick reference

| Tool | What it does |
|------|-------------|
| `ListScheduledJobs` | List all scheduled jobs for the tenant |
| `GetScheduledJob(id)` | Get a single job by GUID |
| `CreateScheduledJob(...)` | Create a job (validates cron + action type) |
| `UpdateScheduledJob(id, ...)` | Full replace of a job's editable fields |
| `DeleteScheduledJob(id, confirm:"YES")` | Delete a job (irreversible) |
| `ToggleScheduledJob(id)` | Enable / disable a job; returns new `isEnabled` |
| `RunScheduledJobNow(id)` | Run immediately (manual; does NOT advance the cron cursor) |
| `ListJobRuns(id, take)` | Recent run history (default 20, max 200) |

---

## Cron expressions

`cronExpression` is the **standard 5-field** dialect, evaluated in the job's `timeZone` (IANA/Windows id; defaults to UTC when unset):

```
┌───────────── minute        (0–59)
│ ┌───────────── hour        (0–23)
│ │ ┌───────────── day-of-month (1–31)
│ │ │ ┌───────────── month     (1–12)
│ │ │ │ ┌───────────── day-of-week (0–6, Sun=0)
│ │ │ │ │
* * * * *
```

Common examples:

| Schedule | Cron |
|---|---|
| Every 5 minutes | `*/5 * * * *` |
| Every hour at :00 | `0 * * * *` |
| Daily at 08:00 UTC | `0 8 * * *` |
| Every weekday at 09:00 UTC | `0 9 * * 1-5` |
| First of the month at 00:00 | `0 0 1 * *` |

An invalid cron is rejected by `CreateScheduledJob` / `UpdateScheduledJob` (validated server-side via `CronEvaluator`).

🚨 **CRITICAL RULE — set `timeZone` to the requester's timezone; do NOT silently default to UTC.** Unlike Flows (cron-only, no tz field), a Scheduler job HAS a `timeZone` field that `CronEvaluator` honors — the cron's wall-clock time is interpreted in that zone. So **keep the cron as the literal clock time the user asked for and set `timeZone` to match**: when the request names a timezone, pass it as `timeZone`; **when the request gives NO timezone, pass the requester's local timezone** (e.g. the session/host IANA id like `Asia/Bangkok`) — not the `"UTC"` default — and state which zone you used. Leaving `timeZone` unset makes `0 8 * * *` fire at 08:00 **UTC**, which is rarely what a user who said "8am" meant.

---

## Action types & `actionConfigJson`

`actionType` is **case-insensitive** and must be one of exactly two values. Pass the action's settings as a JSON object string in `actionConfigJson`.

### Webhook
Send an HTTP request when the job fires.
```json
{
  "method": "POST",
  "url": "https://api.example.com/cron/heartbeat",
  "headers": { "X-Api-Key": "abc123" },
  "body": "{\"source\":\"scheduler\"}"
}
```
`method` defaults to `GET`. `headers` and `body` are optional. A non-2xx response marks the run `Failed`.

### QueuePublish
Publish a message to the in-process queue when the job fires.
```json
{
  "topic": "billing",
  "action": "nightly.reconcile",
  "data": { "batch": "all" }
}
```
`topic` is required; `action` is optional (defaults to `"trigger"`); `data` is optional. Another subscriber picks the message up.

---

## Common patterns

For more worked examples, see [`references/examples.md`](references/examples.md).

### Recurring health ping (Webhook)
```
CreateScheduledJob(
  name: "Hourly Health Ping",
  cronExpression: "0 * * * *",
  actionType: "Webhook",
  actionConfigJson: '{"method":"GET","url":"https://status.example.com/health"}'
)
```

### Nightly queue job (QueuePublish)
```
CreateScheduledJob(
  name: "Nightly Reconcile",
  cronExpression: "0 2 * * *",
  actionType: "QueuePublish",
  actionConfigJson: '{"topic":"billing","action":"nightly.reconcile","data":{"batch":"all"}}',
  description: "Kick off the 02:00 UTC reconciliation batch"
)
```

### Pause a job without deleting it
```
ToggleScheduledJob(id: "<job-guid>")   // flips isEnabled; returns the new state
```

### Test a job right now
```
RunScheduledJobNow(id: "<job-guid>")   // manual run — cron cursor (nextRunUtc) is unchanged
```

---

## Key rules

- **`actionType`** must be exactly `Webhook` or `QueuePublish` (case-insensitive). Anything else is rejected.
- **`cronExpression`** is 5-field; it is validated on create and update. It is evaluated in the job's `timeZone` (IANA/Windows id; defaults to UTC when unset) — `CronEvaluator.GetNextOccurrence` converts UTC → job tz → next occurrence → back to UTC; an unknown/blank/`"UTC"` id falls back to UTC.
- **`UpdateScheduledJob` is a full replace** of editable fields (name, description, cronExpression, timeZone, actionType, actionConfig, isEnabled) — always pass the values you want to keep. In particular, pass the current `isEnabled` explicitly; the default `true` will re-enable a job you deliberately disabled.
- **`RunScheduledJobNow` records a manual run and does NOT advance `nextRunUtc`** — the next scheduled fire is unaffected. Use it to test a job's action without disturbing the schedule.
- **`DeleteScheduledJob`** requires `confirm:"YES"` (exact) and is irreversible.
- **`ListJobRuns` `take`** is clamped to 1–200 (default 20).
- **GUIDs**: `id` must be a job GUID from `ListScheduledJobs` / `GetScheduledJob`. Run history items have their own run `id` (informational; there is no cancel-run tool — scheduled actions are short-lived).
- All enum fields come back as **strings** (e.g. `actionType:"Webhook"`, `status:"Succeeded"`), never integers.

---

## Reading run history

`ListJobRuns(id, take)` returns recent runs, newest first. Each run includes:

| Field | Meaning |
|---|---|
| `id` | Run GUID |
| `scheduledJobId` | The job this run belongs to |
| `startedUtc` / `completedUtc` | Timestamps (`completedUtc` null while running) |
| `status` | `Running` → `Succeeded` / `Failed` / `Skipped` |
| `output` | Action output (e.g. HTTP response summary) |
| `error` | Set when `status` is `Failed` |
| `durationMs` | Wall-clock duration |
| `triggerSource` | `"schedule"` (cron fired) or `"manual"` (RunScheduledJobNow) |

A `ScheduledJobDto` (from list/get) also surfaces `lastRunUtc`, `lastRunStatus`, and `nextRunUtc` so you can see a job's health without reading full history.

To diagnose a failure: find the most recent run with `status:"Failed"` and read its `error` (and `output`) field.

---

## MCP Tools

<!-- mcp-tools:auto (generated by docs-sync; canonical names from live tools/list) -->
Canonical `/mcp` tools this skill owns (exact `tools/list` names; confirm signatures live via ToolSearch).

- **Jobs** — `create_scheduled_job`, `list_scheduled_jobs`, `get_scheduled_job`, `update_scheduled_job`, `delete_scheduled_job`, `toggle_scheduled_job`, `run_scheduled_job_now`
- **Run history** — `list_job_runs`
<!-- /mcp-tools:auto -->

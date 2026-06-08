# Scheduler MCP — Extended Examples

All examples use the `mix-schedule` MCP tools (mix.ai `/mcp`). `tenantId` is omitted everywhere — it resolves from the request domain.

## Create a Webhook job (every 5 minutes)

Pings a status endpoint every 5 minutes and records the HTTP result.

```
CreateScheduledJob(
  name: "Status Ping",
  cronExpression: "*/5 * * * *",
  actionType: "Webhook",
  actionConfigJson: '{"method":"GET","url":"https://status.example.com/health"}',
  description: "5-min uptime probe"
)
```

## Create a Webhook job with headers + body (POST)

```
CreateScheduledJob(
  name: "Nightly Cache Warm",
  cronExpression: "0 3 * * *",
  actionType: "Webhook",
  actionConfigJson: '{"method":"POST","url":"https://app.example.com/internal/warm-cache","headers":{"X-Api-Key":"abc123"},"body":"{\"scope\":\"all\"}"}'
)
```

## Create a QueuePublish job (weekdays at 08:00 UTC)

Publishes a message every weekday morning for a downstream subscriber.

```
CreateScheduledJob(
  name: "Weekday Report Kickoff",
  cronExpression: "0 8 * * 1-5",
  actionType: "QueuePublish",
  actionConfigJson: '{"topic":"reports","action":"daily-summary","data":{"window":"24h"}}'
)
```

## List, then inspect a job

```
ListScheduledJobs()
# → [{ id, name, cronExpression, actionType, isEnabled, lastRunUtc, lastRunStatus, nextRunUtc, ... }]

GetScheduledJob(id: "<job-guid>")
# → full job, enums as strings (actionType:"Webhook", lastRunStatus:"Succeeded")
```

## Update a job (full replace — keep what you don't change)

`UpdateScheduledJob` replaces every editable field. To change only the cron, re-send the current name, actionType, actionConfig, and isEnabled too.

```
UpdateScheduledJob(
  id: "<job-guid>",
  name: "Status Ping",
  cronExpression: "*/10 * * * *",          // changed: now every 10 min
  actionType: "Webhook",
  actionConfigJson: '{"method":"GET","url":"https://status.example.com/health"}',
  isEnabled: true                           // pass explicitly — default true would re-enable a paused job
)
```

## Pause / resume

```
ToggleScheduledJob(id: "<job-guid>")
# → { id, isEnabled: false }   // call again to re-enable
```

## Run now (manual test) — schedule untouched

```
RunScheduledJobNow(id: "<job-guid>")
# → a JobRun with triggerSource:"manual"; nextRunUtc is NOT advanced
```

## Read run history and diagnose a failure

```
ListJobRuns(id: "<job-guid>", take: 50)
# → newest-first runs: { id, status, startedUtc, completedUtc, output, error, durationMs, triggerSource }
```

Find the most recent `status:"Failed"` run and read its `error` (and `output`) to see why the Webhook/QueuePublish action failed.

## Delete a job (irreversible)

```
DeleteScheduledJob(id: "<job-guid>", confirm: "YES")
```

Without `confirm:"YES"` the call returns an error and nothing is deleted.

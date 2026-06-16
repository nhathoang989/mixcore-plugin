# Flows MCP — Extended Examples

## Multi-step webhook workflow

Fires when a user registers. Sends a welcome email, then broadcasts a SignalR notification to admins, then POSTs to a third-party CRM.

```
CreateWorkflow(
  name: "User Registration Flow",
  triggerType: "Webhook",
  triggerConfigJson: '{"path":"/hooks/user-registered"}',
  stepsJson: '[
    {"order":1,"actionType":"SendEmail","config":{"to":"{{payload.email}}","subject":"Welcome!","body":"Hi {{payload.name}}, welcome to the platform."},"continueOnError":false},
    {"order":2,"actionType":"SignalRBroadcast","config":{"event":"admin.user-registered","hub":"notifications","group":"admins","payload":{"userId":"{{payload.userId}}","email":"{{payload.email}}"}},"continueOnError":true},
    {"order":3,"actionType":"HttpRequest","config":{"method":"POST","url":"https://crm.example.com/api/contacts","headers":{"Authorization":"Bearer {{payload.crmToken}}"},"body":{"email":"{{payload.email}}","name":"{{payload.name}}"}},"continueOnError":true}
  ]'
)
```

## Scheduled report pipeline

Every weekday at 8:00 AM, hits a report API and publishes the result to a queue for a downstream processor.

```
CreateWorkflow(
  name: "Weekday Report Pipeline",
  triggerType: "Schedule",
  triggerConfigJson: '{"cron":"0 8 * * 1-5"}',
  stepsJson: '[
    {"order":1,"actionType":"HttpRequest","config":{"method":"GET","url":"https://analytics.example.com/api/daily-summary","headers":{"X-Api-Key":"your-key"}},"continueOnError":false},
    {"order":2,"actionType":"QueuePublish","config":{"topic":"reports","action":"daily-summary","data":{"result":"{{steps.0}}"}},"continueOnError":false}
  ]'
)
```

## Branching workflow (conditional)

Step 1 calls a health check. If it succeeds (branch OnSuccess), step 2 logs success via SignalR. If it fails (branch OnError), step 3 sends an alert email.

```
CreateWorkflow(
  name: "Health Check with Alert",
  triggerType: "Schedule",
  triggerConfigJson: '{"cron":"*/15 * * * *"}',
  stepsJson: '[
    {"order":1,"actionType":"HttpRequest","config":{"method":"GET","url":"https://api.example.com/health"},"continueOnError":true},
    {"order":2,"actionType":"SignalRBroadcast","config":{"event":"health.ok","hub":"notifications"}},
    {"order":3,"actionType":"SendEmail","config":{"to":"ops@example.com","subject":"Health check FAILED","body":"The health endpoint returned an error."}}
  ]',
  edgesJson: '[
    {"from":1,"to":2,"branch":"OnSuccess"},
    {"from":1,"to":3,"branch":"OnError"}
  ]'
)
```

## Trigger a workflow with payload

```
TriggerWorkflow(
  workflowId: "3fa85f64-5717-4562-b3fc-2c963f66afa6",
  payloadJson: '{"email":"user@example.com","name":"Alice","userId":"42"}'
)
```

After calling, poll for the result:
```
GetRunHistory(workflowId: "3fa85f64-5717-4562-b3fc-2c963f66afa6")
```

## Update workflow — rename only (preserve trigger config)

When renaming a workflow without changing its trigger or steps, pass `triggerConfigJson: null` and the existing `isActive` value to avoid silently overwriting either.

```
# First, read the current state:
GetWorkflow(id: "3fa85f64-5717-4562-b3fc-2c963f66afa6")
# → shows isActive: false, triggerConfig: {"cron":"0 9 * * *"}, steps: [...]

# Then update with explicit values:
UpdateWorkflow(
  id: "3fa85f64-5717-4562-b3fc-2c963f66afa6",
  name: "Morning Report (Renamed)",
  triggerConfigJson: null,       # null = keep existing cron config
  stepsJson: "[...]",            # pass the existing steps back
  isActive: false                # pass current value to avoid re-activating
)
```

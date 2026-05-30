---
name: mcp-tool-authoring
description: Patterns and gotchas for writing MCP tool classes in mix.ai — McpToolBase inheritance, tenant resolution, and startup wiring
---

# MCP Tool Authoring Patterns

## Always extend McpToolBase

Every MCP tool class in `mix.ai` must extend `McpToolBase`. Never use `sealed` — it breaks refactoring.

```csharp
[McpServerToolType]
public class MyTool(
    ILogger<MyTool> logger,
    IHttpContextAccessor httpContextAccessor) : McpToolBase(logger, httpContextAccessor)
{
    [McpServerTool, Description("Does something.")]
    public Task<string> DoSomething(CancellationToken ct = default)
        => ExecuteAsync(async () =>
        {
            // CurrentTenantId is inherited — reads HttpContext.Items["ResolvedTenantId"]
            // ResolveTenantId(explicitId) returns explicit when > 0, else CurrentTenantId
            return Success(new { result = "ok" });
        });
}
```

`McpToolBase` is at `src/modules/ai/mix.ai/Application/Mcp/McpTools/Base/McpToolBase.cs`.

## Tenant scoping — two cases

### Content tools (pages, posts, modules, templates, navigation)

These call `service.SetTenantId(...)` and store `TenantId` on entities. **Always use `ResolveTenantId`:**

```csharp
public async Task<string> CreatePage(int? tenantId = null, ...)
{
    var effectiveTenantId = ResolveTenantId(tenantId);
    service.SetTenantId(effectiveTenantId);
    var tenant = await tenantService.GetTenantAsync(effectiveTenantId); // NOT GetDefaultTenantAsync
    var entity = new MixPageContent { TenantId = effectiveTenantId, ... };
}
```

Use `ITenantService.GetTenantAsync(int tenantId)` — added in this PR. `GetDefaultTenantAsync()` always returns tenant 1, bypassing resolution.

### Data tools (MixDB tables, columns, rows, smart queries)

`IMixDbDataService` and `DatabaseService` both read `HttpContext.Items["ResolvedTenantId"]` internally. No `tenantId` parameter needed on tool methods — tenant scoping is automatic.

```csharp
// No tenantId param, no ResolveTenantId call — automatic via DatabaseService
public async Task<string> GetRows(string tableName, ...) { ... }
```

## IHttpContextAccessor registration

`mix.ai` Startup.cs must call this **first** in `ConfigureServices`:

```csharp
builder.Services.AddHttpContextAccessor();
```

It is NOT registered in the platform base or the ASP.NET Core default pipeline — the module owns it. Without it, `McpToolBase` will get a null `IHttpContextAccessor` and all tools fall back to tenant 1.

## How tenant context reaches tools

```
HTTP request (MCP tool call)
  → TenantResolutionMiddleware
    → HttpContext.Items["ResolvedTenantId"] = tenantId (int)
      → McpToolBase.CurrentTenantId reads it
        → ResolveTenantId(null) returns it
```

MCP server is configured with `WithHttpTransport(Stateless = true)` — the full middleware pipeline runs for every tool call, including `TenantResolutionMiddleware`.

## Response formatting

Use base-class helpers — never raw `JsonConvert.SerializeObject(new { success = ... })`:

```csharp
return Success(data: new { id = entity.Id }, message: "Created.");
return Error("Validation failed: name is required.");
return NotFound("MixPageContent", id);
```

Wrapping in `ExecuteAsync` catches exceptions and formats them as errors automatically.

## Tool discovery registration

Tools are auto-discovered from the assembly — no manual registration:

```csharp
app.MapMcp("/mcp")
   .WithHttpTransport(Stateless = true)
   .WithToolsFromAssembly(Assembly.GetExecutingAssembly());
```

`[McpServerToolType]` on the class + `[McpServerTool]` on each method is all that is needed.

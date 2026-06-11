# Resolving `{MCP_PREFIX}` and `{SITE_URL}` (canonical)

Every Mixcore MCP tool is written in the skills as `mcp__mixcore__<tool>`. At runtime,
replace `mcp__mixcore__` with `{MCP_PREFIX}`, resolved **dynamically each session from the
connected MCP server** as follows. This file is the single source of truth; skills reference
it instead of re-deriving it.

> 🚨 **Never hardcode or persist the server.** No config file is read or written — the
> server is whatever is actually connected to the current session.

1. **Detect from the connected session** — the session's available MCP tools are named
   `mcp__{server-name}__<tool>`. Collect every distinct `{server-name}` that serves
   Mixcore tools (e.g. `mixcore`, `mixcore-local`, `mixcore-cloud`) from the deferred-tools
   list / `ToolSearch` results.
2. **Choose** — if exactly one is connected, use it. If several, ask the user once per
   session (one `AskUserQuestion` listing each `name` → `url`); the answer is
   session-scoped only — never written to a file.
3. **Set** `MCP_PREFIX = mcp__{server-name}__`.
4. **Derive `SITE_URL`** — read the chosen server's `url` from `.mcp.json` at the repo
   root and strip the `/mcp` path:

   ```
   "url": "https://mixcore.cloud/mcp"   →   SITE_URL = https://mixcore.cloud
   "url": "http://localhost:5000/mcp"   →   SITE_URL = http://localhost:5000
   ```

   Use `SITE_URL` for everything that touches the running site over HTTP — browser
   verification (Playwright), REST smoke tests, and links reported to the user. **Never
   default to `http://localhost:5000`**: the connected server may be the live cloud site.
   `.mcp.json` is consulted only for the `url` of an already-connected server — never to
   pick a server that isn't connected.

Example: `MCP_PREFIX = mcp__mixcore__` ⇒ `mcp__mixcore__search` → `mcp__mixcore__search`.

Load live tool schemas on demand with `ToolSearch` (`select:{MCP_PREFIX}<tool>`).

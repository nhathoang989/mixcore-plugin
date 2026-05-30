# Resolving `{MCP_PREFIX}` (canonical)

Every Mixcore MCP tool is written in the skills as `mcp__mixcore__<tool>`. At runtime,
replace `mcp__mixcore__` with `{MCP_PREFIX}`, resolved **once per session** as follows.
This file is the single source of truth; skills reference it instead of re-deriving it.

1. **Saved preference** — read `plugins/mixcore/skills/mixcore/server-config.md`.
   If it names a server, set `MCP_PREFIX = mcp__{server-name}__` and stop.
2. **Detect** — otherwise read `.mcp.json` at the repo root and collect `mcpServers`
   keys containing `mixcore` (e.g. `mixcore`, `mixcore-bk`).
3. **Choose** — if exactly one, use it. If several, ask the user (one `AskUserQuestion`
   listing each `name` → `url`), defaulting to the first.
4. **Persist** — write the chosen key to `server-config.md`:

   ```markdown
   # Mixcore MCP Server Config
   server: <name>
   ```

   then set `MCP_PREFIX = mcp__{name}__`.

Example: `MCP_PREFIX = mcp__mixcore-bk__` ⇒ `mcp__mixcore__search` → `mcp__mixcore-bk__search`.

**Reset:** delete `server-config.md` to be asked again next time.

Load live tool schemas on demand with `ToolSearch` (`select:{MCP_PREFIX}<tool>`).

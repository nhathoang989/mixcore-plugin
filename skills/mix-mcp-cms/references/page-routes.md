# Page Routes — Reserved System Routes & seoName Check

A page's `seoName` is its public URL: `/{seoName}` (it may contain `/`). Posts share the same namespace. The platform owns the routes below; they are matched **before** the page lookup, so a page with a colliding `seoName` is unreachable (or 404s).

## 🚨 CRITICAL RULE: check routes before setting `seoName`

Before every `CreatePageContent`, and every `UpdatePageContent` that sets or changes `seoName`:

1. Lower-case the `seoName`, take its **first segment** (text before the first `/`).
2. **Reserved?** If the first segment is in the table below → pick another name (e.g. `api` → `api-docs`, `admin` → `administration`, `account` → `my-account`, `login` is fine but `account/login` is not).
3. **Two-segment shapes:** never use `db/<x>/<number>`, `blog/<x>`, `products/<x>`, `collections/<x>` — those shapes are routed to posts/data/other pages.
4. **Already taken?** Call `ListPageContents` and `ListPostContents` (or `GetPageContentBySeoName` / `GetPostContentBySeoName`) — a page and a post with the same `seoName` conflict; only same-type duplicates are rejected by the server.
5. Only letters, digits and `-` (use `/` only for deliberate nesting). No file extension other than `.html` — any other extension 404s.
6. State the chosen route in your summary. If you renamed it to avoid a collision, say so.

The server does **not** reject reserved names today — this check is yours.

## Reserved first segments (case-insensitive)

| Segment | Owned by |
|---|---|
| `api` | REST API (all versions), CMS preview |
| `p`, `cloud` | Cloud portal (incl. `/p/login`, `/p/register`, `/p/invite`) |
| `admin`, `a` | CMS admin panel |
| `init` | Installation wizard |
| `account` | Sign-in / sign-out / external login |
| `error` | Error pages (`/error/404`) |
| `security` | Access-denied path |
| `mcp` | MCP server |
| `a2a`, `.well-known` | Agent-to-agent endpoint, agent card |
| `hub`, `hubs` | SignalR hubs |
| `mqtt` | MQTT over WebSocket |
| `health`, `alive`, `metrics` | Health checks, Prometheus |
| `openapi`, `scalar` | API docs (development) |
| `_blazor`, `_framework`, `_content` | Blazor runtime and static web assets |
| `mixcontent`, `default-mixcontent` | Uploaded / site content files |
| `css`, `js`, `lib`, `wiki` | Static assets |
| `favicon.ico` | Static file |
| `t` | Tenant path prefix (`/t/{tenant}/…`) |
| `signin-google`, `signin-facebook`, `signin-microsoft`, `signin-twitter`, `signin-github` | OAuth callbacks |
| `scim` | User provisioning API |

Also avoid any name that matches a file in the site's template folder (served at the site root).

## Routes that ARE fine
`/` (Home page — `type: "Home"`, its `seoName` is not used as a path), `login`, `about`, `contact`, `library`, `request`, `faq`, any brand/product word not in the table.

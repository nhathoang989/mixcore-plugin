---
title: "Building a Role-Guarded Admin Portal Page"
category: "instructions"
sub_category: "workflows"
tags: [admin-portal, superadmin, jwt, role-guard, authentication, datasource-crud, layout-null, standalone-page]
last_modified: 2026-06-09
summary: "End-to-end pattern for building a self-contained admin/management portal as a Mixcore CMS page — standalone rendering with layoutId=null, a client-side JWT role guard (e.g. SuperAdmin), and authenticated DataSource CRUD against MixDB tables."
---

# Building a Role-Guarded Admin Portal Page
> **Context:** Mixcore CMS > Workflows > Admin Portal
> **Role:** Pattern reference for authenticated, role-gated management UIs built as CMS pages

A Mixcore CMS page is public SSR by default, so an "admin portal" is built as a **standalone page** whose UI gates itself on the browser using the logged-in user's JWT, then talks to the authenticated MixDB REST API with a Bearer token. There are three parts: standalone rendering, the client-side role guard, and authenticated CRUD.

---

## 1. Standalone rendering — `layoutId = null`

To render a full-screen app shell **without** the public master layout (no site nav, footer, or chat widgets), create a Page template that contains a **complete `<!DOCTYPE html>…</html>` document** and create the page with `layoutId = null`.

- Template: `create_template(folderType: "Pages", fileName: "ManagePortal.cshtml", content: "<full html doc>")`. It still **must** begin with `@model Mix.Rendering.ViewModels.PageContentViewModel` (page templates always require this model — never `@model dynamic`).
- Page: `create_page_content(seoName: "manage", templateId: <id>, layoutId: null, status: "Published", type: "System")`.
- The page is reachable at `/{seoName}` (e.g. `/manage`).

When `layoutId` is null the page template **is** the entire response — `@RenderBody()` is not involved. Put all CSS/JS inline in the template content (CDN `<script src>` tags are fine; escape `@` in CSS as `@@`, e.g. `@@media`, `@@keyframes`).

---

## 2. Client-side role guard (JWT)

Authentication uses the same endpoints and token storage as the AI chat widget (see [chat-widget.md](../../mix-mcp-ai/references/chat-widget.md)).

| Item | Value |
|---|---|
| Login | `POST /api/v1/rest/auth/login` → body `{ userName, password, rememberMe }` |
| Login response token | `Result.AccessToken` (read defensively: `result\|Result`, `accessToken\|AccessToken`) |
| Refresh token | `Result.RefreshToken` |
| Renew | `POST /api/v1/rest/auth/renew-token` → body `{ refreshToken, accessToken }` |
| Token storage | `localStorage['mix_access_token']` (shared with the chat widget) |

**Roles live inside the JWT.** Decode the payload (2nd segment, base64url) client-side — no server call needed:

- **Role claim key:** `http://schemas.microsoft.com/ws/2008/06/identity/claims/role` (the Microsoft 2008 URI — **not** the xmlsoap 2005 URI). The value is an **array** of role-name strings, e.g. `["Owner","SuperAdmin","Guest"]`.
- **SuperAdmin role string:** exactly `"SuperAdmin"`. Other seeded roles include `Owner`, `Guest`.
- Other useful claims in the token: `UserName`, `Id`, `TenantId`, `ExpireAt`, and the standard `exp` (seconds since epoch — check it to detect expiry).

Read roles **defensively** across possible keys, since claim mapping can differ by config:

```js
var ROLE_KEYS = [
  'http://schemas.microsoft.com/ws/2008/06/identity/claims/role',
  'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/role',
  'role', 'roles'
];
function parseJwt(t){ try{ var p=t.split('.')[1].replace(/-/g,'+').replace(/_/g,'/');
  return JSON.parse(decodeURIComponent(escape(atob(p)))); }catch(e){ return null; } }
function rolesOf(p){ var out=[]; if(!p) return out;
  ROLE_KEYS.forEach(function(k){ var v=p[k]; if(v==null) return;
    Array.isArray(v) ? out=out.concat(v) : out.push(v); }); return out; }
function isSuperAdmin(t){ var p=parseJwt(t);
  return p && (!p.exp || p.exp*1000 > Date.now()) && rolesOf(p).indexOf('SuperAdmin') !== -1; }
```

**Guard flow:** on load, if no token → show login; if token expired/invalid → clear it and show login; if valid but role missing → show an "Access denied" view (signed in, not authorized); else enter the app. After a successful login, re-run the same role check before granting access.

> The client-side guard controls the **UI**. For server-side enforcement, also restrict the underlying MixDB table (section 3) — otherwise the REST endpoints may be reachable by anyone if the table has no permissions configured.

---

## 3. Authenticated MixDB CRUD (DataSource REST API)

Send the Bearer token on every call. See [data-loading.md](data-loading.md) (Path E) and [form-templates.md](form-templates.md) ("Authenticated DataSource CRUD endpoints") for the full endpoint reference. In short, against `DataSourceTableDataController`:

```
Base:   /api/v1/rest/data-source/master/table/{tableName}
LIST:   POST   …/{tableName}/filter   body: SearchDataSourceTableRequestDto
GET:    GET    …/{tableName}/{id}
CREATE: POST   …/{tableName}          body: flat JSON object → returns new id
UPDATE: PUT    …/{tableName}/{id}     body: flat JSON (partial) → 204
DELETE: DELETE …/{tableName}/{id}
```

- `dataSourceName` is `master` for internal MixDB tables.
- Never send `id`, `created_date_time`, `created_by`, `last_modified`, `modified_by` — the server sets them.
- On `401`/`403`, drop back to the login/denied gate.

---

## Verify before reporting done

Drive the page with Playwright: (1) anonymous load shows the login gate; (2) a non-privileged JWT shows "Access denied"; (3) the required-role user enters the app and can list + create + delete a row; (4) console has zero errors.

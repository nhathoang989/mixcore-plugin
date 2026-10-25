---
title: "AI Chat Hub — Backend Integration Reference"
category: "instructions"
sub_category: "overview"
tags: [ai-chat, signalr, site-knowledge-hub, anonymous, streaming, typed-events, auth, persistence, local-storage]
last_modified: 2026-10-11
summary: "Backend function implementation guide for AI chat features — SignalR hub connection to /hubs/site-knowledge, the 5-arg AskAI(message, sessionId, provider, model, thinking) invocation (SignalR ignores C# defaults — pass all five), streaming handlers (flat ReceiveChunk plus the additive #192 typed ReceiveEvent stream), auth failure detection (the hub is anonymous-friendly — no [Authorize]/RequireAuthorization), token management, and conversation persistence in localStorage. UI layout and CSS are handled separately via template context."
---

# AI Chat Hub — Backend Integration Reference

> **Context:** Mixcore CMS > AI Features > Hub Integration

This document covers the **function/backend implementation** of AI chat: hub connection, event handlers, auth detection, and token management. UI structure (drawer HTML, overlay CSS, trigger buttons) is not covered here — those belong in the widget template.

---

## 1. Hub Facts

| Property | Value |
|---|---|
| Endpoint | `/hubs/site-knowledge` |
| Auth | **Anonymous-friendly** — `SiteWikiHub` has no `[Authorize]` and its endpoint is mapped without `.RequireAuthorization()`, so anonymous visitors connect and chat (the hub falls back to `Context.ConnectionId`). A JWT (`localStorage['mix_access_token']`) is **optional** — it enables user-scoped server history. |
| Invoke method | `AskAI(message, sessionId, provider, model, thinking)` — **5 args**. SignalR does **not** apply C# default values, so the client must pass all five (pass `null` for unused trailing args). A short arg list (e.g. just `message`) fails binding → "cannot invoke AskAI". |
| `provider` / `model` / `thinking` | Can be `null` (hub uses configured defaults) |
| History method | `LoadHistory(sessionId?)` → `{ sessionId, messages: [{role, content}] }` — call after connect to restore server-side conversation |
| Event: chunk | `ReceiveChunk` — payload: `string` |
| Event: done | `ReceiveComplete` — payload: `{ content, success, planId, error }` |
| Event: error | `ReceiveError` — payload: `{ title, detail }` |
| Event: typed (#192) | `ReceiveEvent` — payload: `{ type, payload }`; additive + dual-sinked with `ReceiveChunk`, opt-in (see §4.1) |
| SignalR CDN (HTML) | `https://unpkg.com/@microsoft/signalr@8.0.7/dist/browser/signalr.min.js` |
| SignalR CDN (Razor) | `https://unpkg.com/@@microsoft/signalr@8.0.7/dist/browser/signalr.min.js` |
| Conversation history | **Server-side** — loaded via `LoadHistory(sessionId)` on connect; the server's `ConversationManager` holds the authoritative history (in-memory cache, TTL 120 min). ⚠️ This is an ALTERNATIVE pattern to the one actually shipped in the canonical copy-paste widget — see the note under §8. |

---

## 2. Hub Connection Setup

```javascript
var TOKEN_KEY = 'mix_access_token';
var token = localStorage.getItem(TOKEN_KEY) || '';

var hub = new signalR.HubConnectionBuilder()
    .withUrl('/hubs/site-knowledge', {
        accessTokenFactory: function () { return token; }
    })
    .withAutomaticReconnect()
    .build();

hub.on('ReceiveChunk', onChunk);
hub.on('ReceiveComplete', onComplete);
hub.on('ReceiveError', onError);
hub.onclose(function () { if (busy) endTurn(); });   // connection dropped mid-turn — release Send

hub.start()
    .then(function () { /* connected — show chat UI */ })
    .catch(function (e) { handleConnectError(e); });

window.addEventListener('beforeunload', function () { if (hub) hub.stop(); });
```

---

## 3. Sending a Message

🚨 **`endTurn()` is the ONLY busy reset; every terminal path calls it** — complete, error, invoke rejection, `hub.onclose`, the idle watchdog, New chat. A `busy = false` written after render calls is skipped by any render throw and wedges Send for the session.

```javascript
var sid = null;            // null = new session; reuse to continue
var busy = false;
var TURN_IDLE_MS = 90000;  // no chunk/complete/error for this long → recover
var watchdog = null;

function endTurn() {
    clearTimeout(watchdog); watchdog = null;
    rawText = ''; bubble = null; busy = false;
    setSend();
}

function armWatchdog() {   // re-armed on every chunk — long streamed answers are never cut off
    clearTimeout(watchdog);
    watchdog = setTimeout(function () {
        if (!busy) return;
        try { if (bubble) bubble.textContent = 'No response — please try again.'; } finally { endTurn(); }
    }, TURN_IDLE_MS);
}

function send(message) {
    if (busy || !message.trim()) return;
    busy = true; setSend();
    sid = sid || crypto.randomUUID();
    armWatchdog();
    hub.invoke('AskAI', message, sid, null, null, null)
       .catch(function (e) {
           try { if (bubble) bubble.textContent = 'Error: ' + ((e && e.message) || e); } finally { endTurn(); }
       });
}
```

---

## 4. Streaming Event Handlers

Use a `rawText` string accumulator — never read `bubble.textContent` to recover streamed text.

```javascript
var rawText = '';
var bubble  = null;

function onChunk(chunk) {
    if (!bubble) return;
    armWatchdog();
    rawText += chunk;
    bubble.innerHTML = fmt(rawText);
    msgs.scrollTop = msgs.scrollHeight;
}

function onComplete(vm) {
    try {
        // success:false means the server completed but the request failed — show error, not content
        var ok       = !vm || vm.success !== false;
        var fallback = (vm && (vm.content || vm.Content)) || '';
        if (!ok) {
            var errMsg = (vm && (vm.error || vm.Error)) || 'AI request failed.';
            if (bubble) bubble.textContent = errMsg;
        } else {
            if (bubble) bubble.innerHTML = fmt(rawText || fallback);
        }
    } catch (e) { console.warn('[chat] complete render failed', e); }
    finally { endTurn(); }
}

function onError(err) {
    try { if (bubble) bubble.textContent = (err && (err.detail || err.message)) || 'Error.'; }
    catch (e) { console.warn('[chat] error render failed', e); }
    finally { endTurn(); }
}
```

### 4.1 Typed Event Stream (#192) — Optional, Additive

Since epic #192 the hub emits a second stream alongside `ReceiveChunk`: `ReceiveEvent` carries typed, discriminated `{type, payload}` objects (camelCase). It is **purely additive and dual-sinked** — every message / plan / error line still flows through `ReceiveChunk` (and `ReceiveComplete` still fires), so a widget that listens only to `ReceiveChunk` keeps working unchanged. Do not refactor a working widget for this; opt in only for a richer (Cline-style) UI with collapsible tool calls, plan-progress, and a thinking indicator.

| `type` | `payload` | Live today? |
|---|---|---|
| `message` | `{ text }` | yes — mirrors `ReceiveChunk` |
| `thinking` | `{ text }` | yes |
| `plan_update` | `{ planId, step, totalSteps, status, text }` | yes (plan flow) |
| `error` | `{ title, detail }` | yes |
| `tool_call` | `{ toolName, arguments }` | only when the native loop is enabled (`EnableAgentLoop`, default off) |
| `tool_result` | `{ toolName, result }` | only when the native loop is enabled |
| `approval_request` | reserved | not yet (#196 paused) |

```javascript
hub.on('ReceiveEvent', function (evt) {
    switch (evt.type) {
        case 'thinking':    showThinking(evt.payload.text); break;
        case 'plan_update': renderPlanStep(evt.payload);    break;
        case 'tool_call':   renderToolCall(evt.payload);    break;
        // 'message'/'error' also arrive via ReceiveChunk/ReceiveError — ignore here to avoid double-render
    }
});
```

Because `message` is dual-sinked, consuming both `ReceiveChunk` and `ReceiveEvent(message)` double-renders the answer — pick one channel for the final text. Keep `ReceiveChunk` for the simple widget; switch fully to `ReceiveEvent` only when adopting the typed UI.

> The Blazor admin/cloud pickers (`ProviderModelPicker` → `GlobalAiChatPanel`) fetch the live model list from each provider's OpenAI-compatible `{baseUrl}/models` endpoint (`ILlmModelCatalogClient`), falling back to the hardcoded `AiProviderCatalog` catalog when there's no key or the call fails. This is a Blazor-UI concern only — the JS widget here passes `provider=null, model=null` and lets the server default.

---

## 5. Markdown Rendering

Add `marked.js` CDN in the template content field after the SignalR script — pin the exact version and add `crossorigin="anonymous"` (an unpinned "latest" can drift to a release without the root file → opaque `Script error.` on every page):

```html
<script src="https://cdn.jsdelivr.net/npm/marked@12.0.2/marked.min.js" crossorigin="anonymous"></script>
```

`fmt()` is the single render choke point — coerce to string **first** (`marked.parse` throws on `null`/`undefined`) and fall back to escaped plain text if `marked` is missing or throws:

```javascript
function fmt(t) {
    var s = (t === null || t === undefined) ? '' : String(t);
    if (typeof marked !== 'undefined' && typeof marked.parse === 'function') {
        try { return marked.parse(s, { breaks: true, gfm: true }); } catch (e) { /* fall through */ }
    }
    return s
        .replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;')
        .replace(/\n/g,'<br>');
}
```

If you persist history client-side (the `chat-widget.md` pattern), shape-validate after `JSON.parse` — keep only entries with role `user`/`assistant` and a string `text` — and wrap the history paint in `try { renderHistory(); } catch (e) {}` so `wireUI()`/`setSend()` always run.

---

## 6. Auth Failure Detection

Do **not** force login before connecting. Always attempt `hub.start()` when the drawer opens — a logged-out visitor sees the chat UI immediately, and the sign-in form appears only when the connection actually fails. The shipped site-knowledge hub (`/hubs/site-knowledge`) is **anonymous-friendly** — mapped without `.RequireAuthorization()` and with no `[Authorize]` — so a logged-out visitor connects and chats normally and this gate never fires for them. **Only when a deployment enforces auth on the hub externally** does a missing/expired token make the negotiate request fail with a real **HTTP 401** — the primary auth signal. The DOCTYPE / HTML-body / JSON-parse checks are the **secondary auth signal**: some hosts redirect an unauthenticated `negotiate` to an HTML login page (302 → `/p/login`) instead of returning 401, so `start()` fails with a JSON parse error rather than a clean status code. Keep them so a logged-out visitor on such a host still sees the gate. Any other failure (network, proxy, server 500) is not auth — show a generic error.

```javascript
function handleConnectError(e) {
    var m = (e && e.message) || String(e);
    // Primary: when auth is enforced on the hub, it returns a real 401 on missing/expired token.
    var isAuthFail = (e && e.statusCode === 401)
        || m.indexOf('401') !== -1
        // Optional fallback: a proxy/cookie redirect served an HTML login page
        // instead of a 401, so the JSON negotiate response fails to parse.
        || m.indexOf('DOCTYPE') !== -1
        || m.indexOf('not valid JSON') !== -1
        || m.indexOf('Unexpected token') !== -1;
    if (isAuthFail) {
        showLoginForm();
    } else {
        showError('Could not connect to AI.');
    }
}
```

**Connect first; the gate is driven by failure, not by a missing token.** Do not pre-check `localStorage['mix_access_token']` and gate before connecting. Open the drawer, attempt `hub.start()`, and let `handleConnectError` reveal the sign-in form only when the connection is rejected (a 401, or an HTML-login redirect per the two signals above). The one cost is a single expected SignalR error in the console for a logged-out visitor — that is the trigger for the gate, not a defect. After a successful login, set the token and reconnect.

> **Verifying:** when verifying chat against a live deployment, navigate to the origin of the configured MCP server (the `mixcore` entry in `.mcp.json`, e.g. `https://mixcore.cloud`) — not `localhost`, which may be a different instance.

---

## 7. Login Endpoint and Reconnect

```
POST /api/v1/rest/auth/login
Content-Type: application/json

{ "userName": "...", "password": "...", "rememberMe": true }
```

Response is `ApiResponseModel<TokenResponseModel>` — token is in `Result`, not `data`:

```javascript
var r   = res && (res.result || res.Result || res.data || res.Data);
var tok = r   && (r.accessToken || r.AccessToken);

localStorage.setItem(TOKEN_KEY, tok);
token = tok;   // updates the accessTokenFactory closure
hub.start()
   .then(function () { /* show chat */ })
   .catch(function () { /* show generic error */ });
```

---

## 8. Conversation Persistence (Server-Side) — an alternative to the shipped client-side pattern

> ⚠️ **The canonical copy-paste widget (`references/chat-widget.md`, the one `mix-mcp-ai`'s SKILL.md documents) does NOT use this pattern.** It restores history from `localStorage['mix_chat_history']` client-side (a JSON array, capped at 50 messages, FIFO-trimmed) and never calls `LoadHistory`. Both patterns work against the SAME hub (`SiteWikiHub` really does implement `LoadHistory`/`ClearHistory` backed by `ConversationManager`), so this section documents a genuine, functional alternative — not a stale/broken claim — but if you're implementing the standard widget from `mix-mcp-cms`/`mix-mcp-ai`, follow `chat-widget.md`'s localStorage pattern instead. Use THIS server-side pattern only when you specifically need cross-device/cross-browser continuity or don't want to trust client storage.

Conversation history lives on the server in the `ConversationManager` (in-memory cache per `(tenantId, sessionId)`, TTL 120 min). The client restores it on every connect/reconnect by calling `LoadHistory(sessionId?)`.

The client only persists the **session id** in `localStorage['mix_chat_session_id']` so it survives page reloads — the full message history is restored from the server via `LoadHistory` on connect.

### 8.1 Load History on Connect

Call `LoadHistory` immediately after `hub.start()` succeeds. Pass the remembered `sid` to continue; pass `null` for a new session. The hub returns `{ sessionId, messages }` — save the `sessionId` to localStorage and use it for all subsequent `AskAI` calls.

```javascript
var SESSION_KEY = 'mix_chat_session_id';
var sid = localStorage.getItem(SESSION_KEY) || null;

// After hub.start() succeeds:
hub.invoke('LoadHistory', sid)
   .then(function (result) {
       sid = result.sessionId;
       localStorage.setItem(SESSION_KEY, sid);
       result.messages.forEach(function (m) {
           if (m.role === 'user' || m.role === 'assistant') {
               renderMessage(m.role, m.content);
           }
       });
   })
   .catch(function () { /* hub unavailable — start fresh */ });
```

### 8.2 Server-Side Persistence is Automatic

Every `AskAI` call persists the user + assistant messages server-side via `ConversationManager.AddMessageAsync`. The client does **not** save message history — only the session id. The next `LoadHistory(sessionId)` on reconnect returns the authoritative history from the server.

### 8.3 New Chat (Reset)

To start a fresh conversation, clear the stored session id and call `LoadHistory(null)`:

```javascript
function onNewChat() {
    endTurn();                 // the single busy/watchdog reset
    msgs.innerHTML = '';
    sid = null;
    localStorage.removeItem(SESSION_KEY);
    hub.invoke('LoadHistory', null)
       .then(function (result) { sid = result.sessionId; localStorage.setItem(SESSION_KEY, sid); })
       .catch(function () { sid = crypto.randomUUID(); });
}
```

---

## 9. Suggestion Buttons

Setting `input.value` via JavaScript does **not** fire the `input` event. Always call the send-button state updater explicitly:

```javascript
suggBtn.addEventListener('click', function () {
    input.value = suggBtn.textContent;
    setSend();   // required — input event does not fire on programmatic assignment
    input.focus();
});
```

---

## 10. CRITICAL: Template Content Field

Widget templates deployed via `create_template(folderType: "Widgets")` are rendered with `Html.PartialAsync`. The `styles` and `scripts` parameters are silently discarded in this context.

**Rule:** ALL CSS, ALL CDN `<script src>` tags, and ALL JavaScript MUST go in the `content` field.

---

## 11. Razor Escaping for CDN URLs

| Raw | Escaped in Razor |
|---|---|
| `@microsoft` | `@@microsoft` |
| `@8.0.7` | `@8.0.7` (digit — safe) |
| `@keyframes` | `@@keyframes` |
| `@media` | `@@media` |

---

## Common Pitfalls

| Symptom | Root cause | Fix |
|---|---|---|
| Hub returns 401 immediately | No/expired token | Check `localStorage['mix_access_token']` |
| Logged-out visitor connects but the sign-in form never appears | A host redirected the anonymous `negotiate` to an HTML login page (302 → `/p/login`), so `start()` throws a `SyntaxError` instead of a clean 401 | In `handleConnectError`, gate on the redirect signal too (`DOCTYPE` / `not valid JSON` / `Unexpected token`) in addition to `statusCode === 401` — do **not** gate-first |
| `vm.content` undefined | camelCase vs PascalCase | Read `vm.content \|\| vm.Content` |
| Bubble empty after streaming | `bubble.textContent` used to recover text | Use `rawText` accumulator |
| Error swallowed — bubble shows stale streamed content | `vm.success` not checked in `onComplete` | Check `vm.success !== false` first; render `vm.error` as plain text |
| Send button stays disabled after suggestion click | `input` event not fired | Call `setSend()` after `input.value =` |
| Send stays disabled after a reply or an error | Busy reset written after render calls (a throw skips it), or a terminal path never resets it | Single `endTurn()`; `try/catch/finally` in `onComplete`/`onError`; invoke `.catch` → `endTurn()`; `hub.onclose`; idle watchdog re-armed per chunk |
| Widget dead from page load | Unguarded `renderHistory()`/`initHub()` threw before `wireUI()` | Guard both with `try/catch`; `wireUI()` + `setSend()` always run |
| `marked(): input parameter is undefined or null` | `fmt()` received `null` (missing content, poisoned stored row) | Coerce first in `fmt()`, `try/catch` around `marked.parse`; shape-validate persisted history |
| Every page logs `Script error.` | Unpinned/404 CDN script, cross-origin without CORS | Pin versions + `crossorigin="anonymous"` |
| `res.data.accessToken` undefined | Wrong response field | Use `res.result.AccessToken` |
| Reload restores bubbles but server replies "what conversation?" | `sid` lost — not restored via `LoadHistory` | Call `LoadHistory(previousSid)` after `hub.start()`; the hub returns the session id |
| Reload shows empty chat despite previous conversation | `LoadHistory` not called after connect, or called with wrong `sessionId` | Call `LoadHistory` after every successful connect/reconnect |
| New user on shared browser sees previous user's chat | Server session keyed by `(tenantId, sessionId)` — different users get different tenants | Each authenticated user resolves to their own tenant; anonymous users share a session only if they share the `sessionId` |

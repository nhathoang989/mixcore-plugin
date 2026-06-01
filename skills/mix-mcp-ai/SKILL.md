---
name: mix-mcp-ai
description: Implement AI chat backend functions for Mixcore CMS — SignalR hub connection, AskAI invocation, streaming event handlers, auth failure detection, token management. UI layout and CSS are handled by the mixcore:mix-mcp-cms skill.
argument-hint: "[hub-connection|auth|streaming|token] [context]"
---

You are implementing **AI chat backend functions** for Mixcore CMS — the SignalR hub wiring, event handlers, auth logic, and streaming pipeline that power chat widgets.

**Scope boundary:**
- **This skill covers:** Hub connection setup, `AskAI` invocation, `ReceiveChunk`/`ReceiveComplete`/`ReceiveError` handlers, auth failure detection, login flow, token management, markdown rendering JS, suggestion button JS handlers, MCP deployment.
- **Not covered here:** Drawer/overlay HTML structure, CSS layout, trigger button HTML, header button HTML/CSS. For UI implementation invoke the **`mixcore:mix-mcp-cms`** skill (it owns Razor templates and CSS-in-content-field).
- **Full copy-paste widget (CSS + HTML + assembled skeleton):** [references/chat-widget.md](references/chat-widget.md) — the UI/markup half; the JS inside its skeleton is the same wiring this skill documents below.

---

## Hub facts

| Item | Value |
|---|---|
| Hub URL | `/hubs/site-knowledge` |
| Auth requirement | `[Authorize]` — Bearer JWT required |
| Client method to invoke | `hub.invoke('AskAI', message, sessionId, provider, model)` |
| `provider` / `model` | Both nullable — pass `null` to use the server default |
| Server → client: chunk | `ReceiveChunk` → string chunk |
| Server → client: complete | `ReceiveComplete` → object `{content, success, planId, error}` (camelCase from SignalR) |
| Server → client: error | `ReceiveError` → object `{title, detail}` |
| Token source (vanilla JS) | `localStorage['mix_access_token']` |
| Conversation history key | `localStorage['mix_chat_history']` — JSON `[{role, text, ts}]` |
| Persisted session id key | `localStorage['mix_chat_session_id']` — string |
| History cap | 50 messages (FIFO trim before persist) |
| SignalR CDN | `https://unpkg.com/@@microsoft/signalr@@8.0.7/dist/browser/signalr.min.js` (note double-`@@` in Razor) |

---

## Razor escaping (CDN URLs in content field)

| Raw | Escaped | Why |
|---|---|---|
| `@microsoft` (in CDN URL) | `@@microsoft` | Razor parses `@` as code expression start |
| `@8.0.7` | `@8.0.7` | Digits cannot start a Razor expression — safe as-is |
| `@keyframes` | `@@keyframes` | Same rule — applies when CSS lands in content field |
| `@media` | `@@media` | Same rule |

---

## Hub connection — minimal setup

```js
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

hub.start()
    .then(function () { /* show chat UI */ })
    .catch(function (e) { handleConnectError(e); });

window.addEventListener('beforeunload', function () { if (hub) hub.stop(); });
```

---

## Sending a message

```js
var sid = null;   // session ID — null starts a new session, reuse to continue

function send(message) {
    if (busy || !message.trim()) return;
    busy = true;
    sid = sid || crypto.randomUUID();
    hub.invoke('AskAI', message, sid, null, null)
       .catch(function (e) { /* show error */ busy = false; });
}
```

---

## Streaming event handlers

```js
var rawText = '';   // accumulator — never use bubble.textContent to recover streamed text
var bubble  = null; // current AI message element

function onChunk(chunk) {
    if (!bubble) return;
    rawText += chunk;
    bubble.innerHTML = fmt(rawText);
    msgs.scrollTop = msgs.scrollHeight;
}

function onComplete(vm) {
    var ok       = !vm || vm.success !== false;
    var fallback = (vm && (vm.content || vm.Content)) || '';
    if (!ok) {
        var errMsg = (vm && (vm.error || vm.Error)) || 'AI request failed.';
        if (bubble) bubble.textContent = errMsg;
    } else {
        if (bubble) bubble.innerHTML = fmt(rawText || fallback);
    }
    rawText = '';
    bubble = null;
    busy = false;
}

function onError(err) {
    if (bubble) bubble.textContent = (err && (err.detail || err.message)) || 'Error.';
    rawText = '';
    bubble = null;
    busy = false;
}
```

`ReceiveComplete` uses defensive camelCase/PascalCase read because SignalR serializes with camelCase by default.

---

## Conversation persistence (localStorage)

Persist the full conversation and the server session id so a returning visitor continues mid-thread instead of starting from scratch. Save **after each user send** and **after each `onComplete`** — never on every chunk (write amplification + risk of saving half-streamed text).

```js
var HISTORY_KEY = 'mix_chat_history';
var SESSION_KEY = 'mix_chat_session_id';
var HISTORY_CAP = 50;
var history = [];   // [{role: 'user'|'assistant', text, ts}]

function loadHistory() {
    try {
        var raw = localStorage.getItem(HISTORY_KEY);
        history = raw ? JSON.parse(raw) : [];
        if (!Array.isArray(history)) history = [];
    } catch (e) { history = []; }
    sid = localStorage.getItem(SESSION_KEY) || null;
}

function persistHistory() {
    try {
        if (history.length > HISTORY_CAP) history = history.slice(-HISTORY_CAP);
        localStorage.setItem(HISTORY_KEY, JSON.stringify(history));
        if (sid) localStorage.setItem(SESSION_KEY, sid);
    } catch (e) { /* quota exceeded — drop oldest half and retry once */
        history = history.slice(-Math.floor(HISTORY_CAP / 2));
        try { localStorage.setItem(HISTORY_KEY, JSON.stringify(history)); } catch (_) {}
    }
}

function renderHistory() {
    history.forEach(function (m) {
        if (m.role === 'user') addUserBubble(m.text);
        else addAssistantBubbleFinal(m.text);   // render markdown, no streaming class
    });
}

function clearHistory() {
    history = [];
    sid = null;
    try {
        localStorage.removeItem(HISTORY_KEY);
        localStorage.removeItem(SESSION_KEY);
    } catch (e) {}
}
```

**Init order** — load before connecting so `sid` is reused server-side:

```js
document.addEventListener('DOMContentLoaded', function () {
    loadHistory();
    renderHistory();
    initHub();
    wireUI();
});
```

**Push to history** at exactly two points:

```js
function send(message) {
    if (busy || !message.trim()) return;
    busy = true;
    sid = sid || crypto.randomUUID();
    history.push({ role: 'user', text: message, ts: Date.now() });
    persistHistory();
    hub.invoke('AskAI', message, sid, null, null)
       .catch(function () { busy = false; });
}

function onComplete(vm) {
    var ok       = !vm || vm.success !== false;
    var fallback = (vm && (vm.content || vm.Content)) || '';
    var finalText;
    if (!ok) {
        finalText = (vm && (vm.error || vm.Error)) || 'AI request failed.';
        if (bubble) bubble.textContent = finalText;
    } else {
        finalText = rawText || fallback;
        if (bubble) bubble.innerHTML = fmt(finalText);
        history.push({ role: 'assistant', text: finalText, ts: Date.now() });
        persistHistory();   // ← persist only the final text, not chunks
    }
    rawText = ''; bubble = null; busy = false;
}
```

> **Privacy:** `localStorage` is per-origin and survives logout. If your token rotation flow signs out the user, also clear `mix_chat_history` and `mix_chat_session_id` — otherwise a new account on the same browser inherits the previous chat.

---

## Markdown rendering (JS only)

Add `marked.js` after the SignalR CDN in the content field:

```html
<script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>
```

```js
function fmt(t) {
    if (typeof marked !== 'undefined') {
        return marked.parse(t, { breaks: true, gfm: true });
    }
    return String(t)
        .replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;')
        .replace(/\n/g,'<br>');
}
```

CSS for the AI bubble (`.mix-b`) belongs in the template content field — implement via the mixcore:mix-mcp-cms skill.

---

## Auth failure detection

The hub endpoint is `[Authorize]`. When no valid token exists, ASP.NET Core redirects to the login page — returning HTML, not a 401 response. SignalR's negotiate request fails with a JSON parse error.

```js
function handleConnectError(e) {
    var m = (e && e.message) || String(e);
    var isAuthFail = (e && e.statusCode === 401)
        || m.indexOf('401') !== -1
        || m.indexOf('DOCTYPE') !== -1        // HTML redirect body
        || m.indexOf('not valid JSON') !== -1  // parse error
        || m.indexOf('Unexpected token') !== -1;
    if (isAuthFail) {
        showGate();   // reveal the full-cover sign-in overlay (see chat-widget.md)
    } else {
        showError('Could not connect to AI.');
    }
}
```

**Present sign-in as a full-cover gate, not an inline bubble.** When auth fails, reveal a `position:absolute; inset:0` overlay inside the drawer (its own bar + close, centered login form) that covers the messages list AND the input row — so a logged-out visitor can't type into a dead chat. Hide it on a successful `hub.start()` and after login. Markup, CSS, and the `showGate`/`hideGate`/`wireGate` wiring are in [references/chat-widget.md](references/chat-widget.md) § Auth failure → full-cover sign-in gate.

---

## Login endpoint and reconnect

```
POST /api/v1/rest/auth/login
Content-Type: application/json

{ "userName": "...", "password": "...", "rememberMe": true }
```

Response is `ApiResponseModel<TokenResponseModel>` — field is `Result` (not `data`):

```js
// Defensive read — handles PascalCase or camelCase
var r   = res && (res.result || res.Result || res.data || res.Data);
var tok = r   && (r.accessToken || r.AccessToken);

// After successful login: update closure and reconnect
localStorage.setItem(TOKEN_KEY, tok);
token = tok;   // updates accessTokenFactory closure
hub.start()
   .then(function () { /* show chat */ })
   .catch(function () { /* show generic error */ });
```

---

## Suggestion buttons — programmatic value + send state

Setting `input.value` via JavaScript does **not** fire the `input` event. Always call `setSend()` explicitly after a programmatic assignment:

```js
suggBtn.addEventListener('click', function () {
    input.value = suggBtn.textContent;
    setSend();   // required — input event does not fire on programmatic assignment
    input.focus();
});
```

---

## MCP tool to deploy

Deploy widgets via:
```
CreateTemplate(
  folderType: "Widgets",
  fileName:   "ai-chat-widget.cshtml",   // MUST include .cshtml
  content:    "... full HTML + <style> + <script src CDN> + <script> ..."
)
```

**ALL CSS, ALL CDN `<script src>` tags, and ALL JavaScript MUST go in the `content` field.** The `styles` and `scripts` parameters are silently discarded when templates are rendered via `Html.PartialAsync`. There is no workaround.

Include in a master layout before `@await RenderSectionAsync("Scripts", false)`:
```cshtml
@await Html.PartialAsync("Widgets/ai-chat-widget")
@await RenderSectionAsync("Scripts", false)
</body>
</html>
```

---

## Verify (run after every deploy)

After deploying the widget template and the page that includes it, verify with Playwright before reporting done. A passing typecheck or build is not evidence the hub wired up.

### Minimum verification procedure

```
1. Navigate to the page URL with browser_navigate
2. Screenshot — confirm widget renders (trigger button visible, no broken layout)
3. Open the widget and send a test message (e.g. "hello")
4. Screenshot — confirm a streaming reply appears in the bubble
5. Check console_messages — must be zero SignalR errors
```

### Observable checks

| Check | Pass | Fail |
|---|---|---|
| Trigger button visible | button rendered in corner | page blank or button missing |
| Hub connects | no `negotiate` 401 / parse error in console | red error, login form shown unexpectedly |
| Streaming reply | bubble fills with text as chunks arrive | spinner hangs, bubble stays empty |
| `onComplete` fires | busy flag clears, input re-enables | input stays disabled after response |
| localStorage written | `mix_chat_history` key exists after send | key absent |
| `marked.js` renders | reply is formatted HTML (bold, code) | raw `**` markdown text |
| New chat button | clears bubbles AND `mix_chat_history` / `mix_chat_session_id` | old messages persist on reload |

### Playwright snippet (adapt as needed)

```js
// After navigate:
// 1. Open the widget
await page.click('.ai-trigger-btn');  // adjust selector to actual trigger

// 2. Send a message
await page.fill('.ai-input', 'hello');
await page.press('.ai-input', 'Enter');

// 3. Wait for response and screenshot
await page.waitForFunction(() =>
  document.querySelector('.mix-b.assistant') !== null
);
await page.screenshot({ path: '.playwright-mcp/ai-chat-verify.png' });

// 4. Check localStorage
const history = await page.evaluate(() => localStorage.getItem('mix_chat_history'));
console.assert(history !== null, 'mix_chat_history should be set after a message');
```

### Common failures and fixes

| Symptom | Cause | Fix |
|---|---|---|
| Login form shown on widget open | Token missing or expired in `localStorage` | Set `mix_access_token` before navigating, or log in first |
| Spinner hangs, no reply | Hub URL wrong (`/hubs/llm` vs `/hubs/site-knowledge`) | Check hub URL constant in JS |
| `@@microsoft` visible in page source | `@` not escaped in template | Double every `@` in CDN URLs in the content field |
| Reply renders as raw markdown | `marked.js` not loaded or loaded after the script that calls `fmt()` | Move marked CDN `<script>` before the widget `<script>` |
| "New chat" leaves history on reload | `clearHistory()` not called | Call `clearHistory()` in the new-chat handler |

---

## New session reset

A "New chat" button must clear both UI state AND persisted storage — otherwise the next reload re-renders the abandoned conversation.

```js
function onNewChat() {
    rawText = '';
    bubble  = null;
    busy    = false;
    clearHistory();                 // wipes localStorage + in-memory history + sid
    msgs.innerHTML = '';            // clear rendered bubbles
}
```

Also call `clearHistory()` from your sign-out / token-rotation flow.

---

## Quick start checklist

- [ ] All CSS and JS are inside the `content` field — nothing in `styles`/`scripts`
- [ ] `@@microsoft` in the SignalR CDN URL (Razor escaping)
- [ ] Hub URL is `/hubs/site-knowledge`
- [ ] Token read from `localStorage['mix_access_token']`
- [ ] `hub.invoke('AskAI', message, sessionId, null, null)` — provider and model default to null
- [ ] `marked.js` CDN added for markdown rendering — `rawText` accumulator used (not `bubble.textContent`)
- [ ] Auth failure detection checks for HTML/parse errors, not just HTTP 401
- [ ] Sign-in renders as a full-cover gate overlaying the whole drawer (covers messages + input), hidden on successful connect/login — not an inline bubble
- [ ] Suggestion button click handlers call `setSend()` explicitly after setting `input.value`
- [ ] `window.beforeunload` → `hub.stop()` to clean up the connection
- [ ] `onComplete` checks `vm.success !== false` before rendering — errors shown as text, not HTML
- [ ] `loadHistory()` runs **before** `initHub()` on `DOMContentLoaded` so the persisted `sid` is reused
- [ ] `persistHistory()` is called **only** after user `send` and after `onComplete` success — never inside `onChunk`
- [ ] Persisted assistant entries store the **final** text (`rawText || fallback`), not partial streaming chunks
- [ ] History is capped at 50 messages with FIFO trim before each persist; quota-exceeded path drops oldest half
- [ ] "New chat" and sign-out flows both call `clearHistory()` — removes `mix_chat_history` AND `mix_chat_session_id`
- [ ] UI structure (drawer HTML, overlay, trigger button) implemented via the mixcore:mix-mcp-cms skill

---

## Critical don'ts

- Never put CSS or JS in the `styles` or `scripts` parameters of `CreateTemplate` for widget templates
- Never use `bubble.textContent` to recover streamed text — use a separate `rawText` accumulator
- Never check only for `statusCode === 401` on hub connect failure — ASP.NET redirect returns HTML causing a JSON parse error
- Never look for `res.data.accessToken` in the login response — the field is `res.result.AccessToken`
- Never render the sign-in form as an inline chat bubble in the message list — use a full-cover gate (`position:absolute; inset:0`) that overlays the whole drawer, so the input row is blocked while logged out
- Never set `input.value` programmatically without calling `setSend()` — the `input` event does not fire
- Never hardcode `provider` or `model` unless the user requests a specific provider — pass `null`
- Never read the token from a cookie — always from `localStorage['mix_access_token']`
- Never connect to `/hubs/llm` for site-knowledge chat — that hub uses a different agent pipeline
- Never skip `window.beforeunload → hub.stop()` — dangling WebSocket connections accumulate
- Never render `ReceiveComplete` content when `vm.success === false` — always check first and show the error field instead
- Never persist inside `onChunk` — you'll write to localStorage on every token and may save half-streamed text if the user reloads mid-stream
- Never persist the streaming bubble's `innerHTML` — store the raw markdown source (`rawText || fallback`), and re-render with `fmt()` on load
- Never call `initHub()` before `loadHistory()` — the persisted `sid` must be in place so the server treats the connection as a continuation
- Never persist auth tokens, plan IDs, or PII alongside chat text in `mix_chat_history` — keep the schema to `{role, text, ts}` only
- Never leave the persisted history in place after sign-out — `localStorage` is per-origin and survives the session
- Never implement drawer CSS, overlay HTML, or trigger button HTML in this skill — delegate to mixcore:mix-mcp-cms

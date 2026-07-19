# AI Chat Widget — UI & Copy-Paste Skeleton

Drawer-style AI chat widget for `SiteWikiHub`. This reference is the **UI / markup half**: CSS, HTML structure, the `wireUI` glue, master-layout include, trigger button, the full copy-paste template skeleton, the inline login form, and a troubleshooting checklist. It is deployed as a Mixcore Widget template (everything goes in the `content` field) and included via `Html.PartialAsync`.

> **Backend behavior lives in the skill body — read [`../SKILL.md`](../SKILL.md) first.** Hub connection, `AskAI` invocation, the `ReceiveChunk`/`ReceiveComplete`/`ReceiveError` handlers, conversation persistence, auth-failure detection, and the login/reconnect flow are documented there. This file is the assembled artifact you paste in; the JS inside the skeleton below is the same wiring SKILL.md explains. (Widget UI/markup is owned by the `mixcore:mix-mcp-cms` skill.)

---

## Complete CSS for drawer widget

Paste ALL of this inside a `<style>` tag in the `content` field. Note `@@keyframes` (not `@keyframes`).

```html
<style>
/* Overlay */
#mix-chat-overlay {
    position: fixed;
    inset: 0;
    background: rgba(0,0,0,0.45);
    opacity: 0;
    pointer-events: none;
    transition: opacity 0.3s ease;
    z-index: 1040;
}
#mix-chat-overlay.mix-open {
    opacity: 1;
    pointer-events: all;
}

/* Drawer */
#mix-chat-drawer {
    position: fixed;
    top: 0;
    right: 0;
    height: 100%;
    width: 380px;
    max-width: 100vw;
    background: #fff;
    box-shadow: -4px 0 24px rgba(0,0,0,0.15);
    transform: translateX(100%);
    transition: transform 0.35s cubic-bezier(0.4,0,0.2,1);
    z-index: 1050;
    display: flex;
    flex-direction: column;
    font-family: system-ui, sans-serif;
}
#mix-chat-drawer.mix-open {
    transform: translateX(0);
}

/* Header */
#mix-chat-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 16px 20px;
    border-bottom: 1px solid #e5e7eb;
    background: #f9fafb;
    flex-shrink: 0;
}
#mix-chat-header h3 {
    margin: 0;
    font-size: 16px;
    font-weight: 600;
    color: #111827;
}
#mix-chat-close-btn {
    background: none;
    border: none;
    cursor: pointer;
    font-size: 20px;
    color: #6b7280;
    line-height: 1;
    padding: 4px;
}
#mix-chat-close-btn:hover { color: #111827; }

/* Message list */
#mix-chat-messages {
    flex: 1;
    overflow-y: auto;
    padding: 16px;
    display: flex;
    flex-direction: column;
    gap: 12px;
}

/* Chat bubbles */
.mix-chat-msg {
    max-width: 80%;
    padding: 10px 14px;
    border-radius: 12px;
    font-size: 14px;
    line-height: 1.5;
    word-break: break-word;
}
.mix-chat-user {
    align-self: flex-end;
    background: #2563eb;
    color: #fff;
    border-bottom-right-radius: 4px;
}
.mix-chat-assistant {
    align-self: flex-start;
    background: #f3f4f6;
    color: #111827;
    border-bottom-left-radius: 4px;
}
.mix-chat-assistant:empty::before {
    content: '...';
    color: #9ca3af;
    font-style: italic;
}
.mix-chat-error {
    background: #fee2e2;
    color: #991b1b;
}

/* Typing indicator animation */
@@keyframes mix-pulse {
    0%, 100% { opacity: 1; }
    50%       { opacity: 0.4; }
}
.mix-chat-typing::after {
    content: '▌';
    animation: mix-pulse 1s infinite;
    color: #6b7280;
}

/* Input area */
#mix-chat-input-row {
    padding: 12px 16px;
    border-top: 1px solid #e5e7eb;
    display: flex;
    gap: 8px;
    flex-shrink: 0;
    background: #fff;
}
#mix-chat-input {
    flex: 1;
    padding: 10px 12px;
    border: 1px solid #d1d5db;
    border-radius: 8px;
    font-size: 14px;
    outline: none;
    resize: none;
    font-family: inherit;
    line-height: 1.4;
}
#mix-chat-input:focus {
    border-color: #2563eb;
    box-shadow: 0 0 0 2px rgba(37,99,235,0.15);
}
#mix-chat-send-btn {
    padding: 10px 16px;
    background: #2563eb;
    color: #fff;
    border: none;
    border-radius: 8px;
    cursor: pointer;
    font-size: 14px;
    font-weight: 500;
    white-space: nowrap;
}
#mix-chat-send-btn:hover { background: #1d4ed8; }
#mix-chat-send-btn:disabled {
    background: #93c5fd;
    cursor: not-allowed;
}

/* Responsive: full-width on mobile */
@@media (max-width: 480px) {
    #mix-chat-drawer { width: 100vw; }
}
</style>
```

---

## Complete HTML structure

```html
<!-- Hidden trigger button — header can call this.click() without knowing widget internals -->
<button id="mix-chat-btn" style="display:none" aria-hidden="true"></button>

<!-- Overlay -->
<div id="mix-chat-overlay"></div>

<!-- Drawer -->
<div id="mix-chat-drawer" role="dialog" aria-label="AI Chat" aria-modal="true">
    <div id="mix-chat-header">
        <h3>AI Assistant</h3>
        <button id="mix-chat-close-btn" aria-label="Close chat">&times;</button>
    </div>
    <div id="mix-chat-messages" role="log" aria-live="polite" aria-label="Chat messages"></div>
    <div id="mix-chat-input-row">
        <textarea id="mix-chat-input"
                  rows="1"
                  placeholder="Ask anything..."
                  aria-label="Message input"></textarea>
        <button id="mix-chat-send-btn">Send</button>
    </div>
</div>
```

---

## Complete JS init function (`wireUI`)

```js
function wireUI() {
    var overlay   = document.getElementById('mix-chat-overlay');
    var drawer    = document.getElementById('mix-chat-drawer');
    var closeBtn  = document.getElementById('mix-chat-close-btn');
    var triggerBtn = document.getElementById('mix-chat-btn');
    var input     = document.getElementById('mix-chat-input');
    var sendBtn   = document.getElementById('mix-chat-send-btn');

    function setOpen(v) {
        isOpen = v;
        overlay.classList.toggle('mix-open', v);
        drawer.classList.toggle('mix-open', v);
        document.body.style.overflow = v ? 'hidden' : '';
        // Sync header AI button active state
        var aiBtn = document.getElementById('rwAiBtn');
        if (aiBtn) aiBtn.classList.toggle('active', v);
        if (v && input) input.focus();
    }

    // Expose globals so any element on the page can open/close
    window.mixChatToggle = function () { setOpen(!isOpen); };
    window.mixChatOpen   = function () { setOpen(true); };
    window.mixChatClose  = function () { setOpen(false); };

    // Hidden trigger button (for header onclick delegation)
    if (triggerBtn) triggerBtn.addEventListener('click', window.mixChatToggle);

    // Close via overlay click or X button
    if (overlay) overlay.addEventListener('click', function () { setOpen(false); });
    if (closeBtn) closeBtn.addEventListener('click', function () { setOpen(false); });

    // Send on button click
    if (sendBtn) sendBtn.addEventListener('click', function () {
        var text = input ? input.value.trim() : '';
        if (!text) return;
        input.value = '';
        autoResize(input);
        sendMessage(text);
    });

    // Send on Enter (Shift+Enter = new line)
    if (input) {
        input.addEventListener('keydown', function (e) {
            if (e.key === 'Enter' && !e.shiftKey) {
                e.preventDefault();
                sendBtn.click();
            }
        });
        input.addEventListener('input', function () { autoResize(input); });
    }

    // Escape key closes drawer
    document.addEventListener('keydown', function (e) {
        if (e.key === 'Escape' && isOpen) setOpen(false);
    });
}

function autoResize(el) {
    el.style.height = 'auto';
    el.style.height = Math.min(el.scrollHeight, 120) + 'px';
}
```

---

## Including the widget in a master layout

In the master template (e.g. `Masters/SiteMaster.cshtml`), add the partial at the bottom of `<body>`, just before the closing tag:

```cshtml
@* AI Chat Widget — includes its own <style>, CDN <script>, and JS. Must be last. *@
@await Html.PartialAsync("../Widgets/AIChatWidget.cshtml")
```

The widget registers global functions (`window.mixChatOpen`, etc.) so it must be included once, exactly here. Do not include it in page templates — it would be duplicated on multi-module pages.

**Update the widget via MCP:**
```
UpdateTemplate(
  id: <template id returned by CreateTemplate>,
  content: "... updated full HTML ..."
)
```

---

## Adding a trigger button in the header

In the header template or module, add a button that delegates to the widget's hidden trigger:

```html
<!-- Header nav button -->
<button id="rwAiBtn"
        class="header-icon-btn"
        onclick="document.getElementById('mix-chat-btn').click()"
        aria-label="Open AI Chat"
        title="AI Assistant">
    <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" fill="none"
         viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
        <path stroke-linecap="round" stroke-linejoin="round"
              d="M8 10h.01M12 10h.01M16 10h.01M9 16H5a2 2 0 01-2-2V6
                 a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-5l-3 3v-3z"/>
    </svg>
</button>
```

Or using `window.mixChatOpen` directly (if the header renders after the widget script has run):

```html
<button onclick="window.mixChatOpen && window.mixChatOpen()" ...>...</button>
```

The `setOpen(v)` function inside the widget automatically adds/removes `.active` on `#rwAiBtn`, so you can style the active state with:

```css
#rwAiBtn.active { color: #2563eb; }
#rwAiBtn.active svg { fill: #dbeafe; }
```

---

## Full template skeleton (copy-paste ready)

This is the entire content field for `CreateTemplate`. Paste as-is into the MCP call — it is Razor-safe.

```html
<style>
/* ... paste the "Complete CSS for drawer widget" block here ... */
</style>

<!-- Hidden trigger -->
<button id="mix-chat-btn" style="display:none" aria-hidden="true"></button>

<!-- Overlay + Drawer (see "Complete HTML structure") -->
<div id="mix-chat-overlay"></div>
<div id="mix-chat-drawer" role="dialog" aria-label="AI Chat" aria-modal="true">
    <div id="mix-chat-header">
        <h3>AI Assistant</h3>
        <button id="mix-chat-close-btn">&times;</button>
    </div>
    <div id="mix-chat-messages" role="log" aria-live="polite"></div>
    <div id="mix-chat-input-row">
        <textarea id="mix-chat-input" rows="1" placeholder="Ask anything..."></textarea>
        <button id="mix-chat-send-btn">Send</button>
    </div>
</div>

<script src="https://unpkg.com/@@microsoft/signalr@@8.0.7/dist/browser/signalr.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>
<script>
(function () {
    var hub = null;
    var sessionId = null;       // set by loadHistory() — never overwrite once loaded
    var isOpen = false;
    var activeBubble = null;
    var rawText = '';

    // ---- Persistence ----
    var HISTORY_KEY = 'mix_chat_history';
    var SESSION_KEY = 'mix_chat_session_id';
    var HISTORY_CAP = 50;
    var history = [];

    function loadHistory() {
        try {
            var raw = localStorage.getItem(HISTORY_KEY);
            history = raw ? JSON.parse(raw) : [];
            if (!Array.isArray(history)) history = [];
        } catch (e) { history = []; }
        sessionId = localStorage.getItem(SESSION_KEY)
            || ('sk-' + Date.now() + '-' + Math.random().toString(36).slice(2));
    }
    function persistHistory() {
        try {
            if (history.length > HISTORY_CAP) history = history.slice(-HISTORY_CAP);
            localStorage.setItem(HISTORY_KEY, JSON.stringify(history));
            localStorage.setItem(SESSION_KEY, sessionId);
        } catch (e) {
            history = history.slice(-Math.floor(HISTORY_CAP / 2));
            try { localStorage.setItem(HISTORY_KEY, JSON.stringify(history)); } catch (_) {}
        }
    }
    function renderHistory() {
        history.forEach(function (m) {
            var d = document.createElement('div');
            d.className = 'mix-chat-msg ' + (m.role === 'user' ? 'mix-chat-user' : 'mix-chat-assistant');
            if (m.role === 'user') d.textContent = m.text;
            else d.innerHTML = fmt(m.text);
            msgs().appendChild(d);
        });
        scrollBottom();
    }
    function clearHistory() {
        var oldSid = sessionId;
        history = [];
        sessionId = 'sk-' + Date.now() + '-' + Math.random().toString(36).slice(2);
        try { localStorage.removeItem(HISTORY_KEY); localStorage.removeItem(SESSION_KEY); } catch (e) {}
        // Delete the server-side conversation too — orphaned sessions accumulate forever otherwise.
        if (hub && oldSid) hub.invoke('ClearHistory', oldSid).catch(function () {});
    }

    // ---- Hub ----
    function getToken() { return localStorage['mix_access_token'] || ''; }

    function initHub() {
        hub = new signalR.HubConnectionBuilder()
            .withUrl('/hubs/site-knowledge', { accessTokenFactory: getToken })
            .withAutomaticReconnect()
            .build();

        hub.on('ReceiveChunk', appendChunk);
        hub.on('ReceiveComplete', function (vm) {
            var ok = !vm || vm.success !== false;
            var fallback = (vm && (vm.content || vm.Content)) || '';
            if (!ok) { showError((vm && (vm.error || vm.Error)) || 'AI request failed.'); return; }
            finalizeMessage(fallback);
        });
        hub.on('ReceiveError',    function (err) { showError((err && (err.detail || err.message)) || 'Error'); });
        // Connect first, gate on failure — no token pre-check. handleConnectError reveals the
        // sign-in gate only on a real auth failure (401, or an HTML-login redirect). See
        // § Auth failure → full-cover sign-in gate for the detection body + showGate().
        hub.start().then(function () { hideGate(); }).catch(handleConnectError);
    }

    window.addEventListener('beforeunload', function () { if (hub) hub.stop(); });

    // ---- Markdown ----
    function fmt(t) {
        if (typeof marked !== 'undefined') return marked.parse(t, { breaks: true, gfm: true });
        return String(t).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/\n/g,'<br>');
    }

    // ---- Messaging ----
    function sendMessage(text) {
        if (!hub || hub.state !== signalR.HubConnectionState.Connected) {
            showError('Not connected — please wait a moment and try again.'); return;
        }
        addUserBubble(text);
        addAssistantBubble();
        history.push({ role: 'user', text: text, ts: Date.now() });
        persistHistory();
        hub.invoke('AskAI', text, sessionId, null, null, null)  // 5 args: message, sessionId, provider, model, thinking (SignalR ignores C# defaults — pass all five)
           .catch(function (e) { showError(e.toString()); });
    }

    function addUserBubble(text) {
        var d = document.createElement('div');
        d.className = 'mix-chat-msg mix-chat-user';
        d.textContent = text;
        msgs().appendChild(d); scrollBottom();
    }
    function addAssistantBubble() {
        rawText = '';
        var d = document.createElement('div');
        d.className = 'mix-chat-msg mix-chat-assistant mix-chat-typing';
        msgs().appendChild(d); scrollBottom();
        activeBubble = d;
    }
    function appendChunk(chunk) {
        if (!activeBubble) return;
        activeBubble.classList.remove('mix-chat-typing');
        rawText += chunk;
        activeBubble.innerHTML = fmt(rawText);
        scrollBottom();
    }
    function finalizeMessage(fallback) {
        if (!activeBubble) return;
        activeBubble.classList.remove('mix-chat-typing');
        var finalText = rawText || fallback || '';
        activeBubble.innerHTML = fmt(finalText);
        history.push({ role: 'assistant', text: finalText, ts: Date.now() });
        persistHistory();
        rawText = ''; activeBubble = null; scrollBottom();
    }
    function showError(msg) {
        if (activeBubble) {
            activeBubble.classList.remove('mix-chat-typing');
            activeBubble.classList.add('mix-chat-error');
            activeBubble.textContent = 'Error: ' + msg;
            activeBubble = null;
        }
        rawText = '';
    }
    function msgs() { return document.getElementById('mix-chat-messages'); }
    function scrollBottom() { var m = msgs(); if (m) m.scrollTop = m.scrollHeight; }

    // ---- Drawer UI ----
    function wireUI() {
        var overlay  = document.getElementById('mix-chat-overlay');
        var drawer   = document.getElementById('mix-chat-drawer');
        var closeBtn = document.getElementById('mix-chat-close-btn');
        var trigger  = document.getElementById('mix-chat-btn');
        var input    = document.getElementById('mix-chat-input');
        var sendBtn  = document.getElementById('mix-chat-send-btn');

        function setOpen(v) {
            isOpen = v;
            overlay.classList.toggle('mix-open', v);
            drawer.classList.toggle('mix-open', v);
            document.body.style.overflow = v ? 'hidden' : '';
            var aiBtn = document.getElementById('rwAiBtn');
            if (aiBtn) aiBtn.classList.toggle('active', v);
            if (v && input) input.focus();
        }

        window.mixChatToggle = function () { setOpen(!isOpen); };
        window.mixChatOpen   = function () { setOpen(true); };
        window.mixChatClose  = function () { setOpen(false); };

        if (trigger)  trigger.addEventListener('click',  window.mixChatToggle);
        if (overlay)  overlay.addEventListener('click',  function () { setOpen(false); });
        if (closeBtn) closeBtn.addEventListener('click', function () { setOpen(false); });

        if (sendBtn) sendBtn.addEventListener('click', function () {
            var t = input ? input.value.trim() : '';
            if (!t) return;
            input.value = ''; autoResize(input); sendMessage(t);
        });

        if (input) {
            input.addEventListener('keydown', function (e) {
                if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); sendBtn.click(); }
            });
            input.addEventListener('input', function () { autoResize(input); });
        }

        document.addEventListener('keydown', function (e) {
            if (e.key === 'Escape' && isOpen) setOpen(false);
        });
    }

    function autoResize(el) {
        el.style.height = 'auto';
        el.style.height = Math.min(el.scrollHeight, 120) + 'px';
    }

    document.addEventListener('DOMContentLoaded', function () {
        loadHistory();    // restore messages + sessionId from localStorage FIRST
        renderHistory();  // paint restored bubbles
        initHub();        // then connect (sessionId now in scope for AskAI)
        wireUI();
    });
})();
</script>
```

---

## Auth failure → full-cover sign-in gate

**Connect first, gate on failure — never force login up front.** Open the drawer and attempt `hub.start()` even with no token; the gate is revealed by the connection *failing*, not by a pre-check (see SKILL.md § Auth failure detection). The shipped `/hubs/site-knowledge` hub (`SiteWikiHub`) is **anonymous-friendly** — mapped without `.RequireAuthorization()` and with no `[Authorize]` (`mix.ai/Startup.cs`) — so anonymous visitors connect and chat normally and this gate never fires for them. Only when a deployment enforces auth on the hub externally does an unauthenticated `negotiate` return a proper **HTTP 401** — `e.statusCode === 401` is the primary, reliable signal. The DOCTYPE/JSON-parse checks below are the **secondary auth signal**: some hosts redirect `/hubs/site-knowledge/negotiate` to an HTML login page (302 → `/p/login`) instead of returning 401 JSON, so SignalR sees `<!DOCTYPE html>` and throws a `SyntaxError`. Because we no longer gate before connecting, keep those checks so a logged-out visitor on such a host still gets the gate. On a standard mixcore-cloud setup `statusCode === 401` alone is enough.

**Present the login as a full-cover gate that overlays the entire widget**, not as a message appended into the chat list. The gate is an `position:absolute; inset:0` panel inside the drawer with its own title bar + close button and a centered login form, shown when the hub fails auth and hidden on a successful sign-in. This blocks the messages list AND the input row so an unauthenticated user can't type into a dead chat, and it reads as a deliberate "sign in to continue" screen rather than a stray bubble. (The drawer is `position:fixed`, so it is the containing block for the `inset:0` gate.)

### Detection

```js
// initHub() calls hub.start().catch(handleConnectError) — connect first, gate only on failure.
function handleConnectError(e) {
    var m = (e && e.message) || String(e);
    var isAuthFail = (e && e.statusCode === 401)   // primary, reliable signal (hub is Bearer/.RequireAuthorization)
        || m.indexOf('401') !== -1
        // secondary auth signal — a host that redirects the anonymous negotiate to an HTML login page:
        || m.indexOf('DOCTYPE') !== -1
        || m.indexOf('not valid JSON') !== -1
        || m.indexOf('Unexpected token') !== -1;
    if (isAuthFail) {
        showGate();          // reveal the full-cover sign-in overlay
    } else {
        showError('Could not connect to AI.');   // network / 500 / proxy — not an auth problem
    }
}
```

Also call `showGate()` from `sendMessage()` when the hub is not connected, so a click "send" on a logged-out widget surfaces the gate instead of a silent failure.

### Gate markup (inside the drawer, after the input row)

```html
<div id="mix-chat-gate" aria-hidden="true">
  <div class="mix-gate-bar">
    <span class="t"><b>&gt;_</b> sign in</span>
    <button id="mix-gate-close" class="mix-hbtn" aria-label="Close">esc &times;</button>
  </div>
  <div class="mix-gate-body">
    <div class="who">// sign in required</div>
    <h4>Chat with the assistant</h4>
    <p>Sign in with your account to use the assistant.</p>
    <form id="mix-lf" class="mix-login-form">
      <input id="mix-lu" class="mix-login-input" type="text" placeholder="username or email" autocomplete="username"/>
      <input id="mix-lp" class="mix-login-input" type="password" placeholder="password" autocomplete="current-password"/>
      <div id="mix-le" class="mix-login-err"></div>
      <button class="mix-login-btn" type="submit">sign in</button>
    </form>
  </div>
</div>
```

### Gate CSS (covers the whole drawer)

```css
#mix-chat-gate { position: absolute; inset: 0; z-index: 6; background: var(--ink,#0a0d0e); display: none; flex-direction: column; }
#mix-chat-gate.show { display: flex; }
.mix-gate-bar { display: flex; align-items: center; justify-content: space-between; padding: 14px 16px; border-bottom: 1px solid var(--line,#202c31); flex-shrink: 0; }
.mix-gate-body { flex: 1; display: flex; flex-direction: column; justify-content: center; padding: 1.8rem; }
```

### Show/hide + login (reconnect)

The login form is **static markup wired once** (not rebuilt each time). Toggle the gate with a `.show` class; on success store the token, hide the gate, and reconnect the hub.

```js
function showGate() { var g = document.getElementById('mix-chat-gate'); if (g) { g.classList.add('show'); g.setAttribute('aria-hidden','false'); var u = document.getElementById('mix-lu'); if (u) u.focus(); } }
function hideGate() { var g = document.getElementById('mix-chat-gate'); if (g) { g.classList.remove('show'); g.setAttribute('aria-hidden','true'); } }

function wireGate() {
    var f = document.getElementById('mix-lf'); if (!f) return;
    var gc = document.getElementById('mix-gate-close');
    if (gc) gc.addEventListener('click', function () { if (window.mixChatClose) window.mixChatClose(); });
    f.addEventListener('submit', function (e) {
        e.preventDefault();
        var u = document.getElementById('mix-lu').value.trim(), p = document.getElementById('mix-lp').value;
        var le = document.getElementById('mix-le'), btn = f.querySelector('.mix-login-btn');
        if (!u || !p) { le.textContent = 'Enter username and password.'; le.style.display = 'block'; return; }
        btn.disabled = true; btn.textContent = 'signing in…'; le.style.display = 'none';
        fetch('/api/v1/rest/auth/login', {
            method: 'POST', headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ userName: u, password: p, rememberMe: true })
        })
        .then(function (r) { return r.ok ? r.json() : r.json().then(function (j) { throw new Error((j && j.errors && j.errors[0]) || 'Login failed'); }); })
        .then(function (res) {
            // ApiResponseModel<TokenResponseModel> — field is Result, not data
            var rr = res && (res.result || res.Result || res.data || res.Data);
            var tok = rr && (rr.accessToken || rr.AccessToken);
            if (!tok) throw new Error('Invalid response from server');
            localStorage.setItem(TOKEN_KEY, tok);
            btn.disabled = false; btn.textContent = 'sign in'; f.reset();
            hideGate();
            // accessTokenFactory reads localStorage on each (re)connect, so no closure var to update
            hub.start().then(function () { hideGate(); /* show welcome */ }).catch(function () { showError('Could not connect to AI.'); });
        })
        .catch(function (err) { le.textContent = (err && err.message) || 'Login failed.'; le.style.display = 'block'; btn.disabled = false; btn.textContent = 'sign in'; });
    });
}
```

Call `hideGate()` from the hub's successful `.start()` too, so a valid token never leaves the gate showing. Wire the gate **once** on `DOMContentLoaded` (alongside `wireUI()`), before/after `initHub()`.

### API contract

| Field | Value |
|---|---|
| Endpoint | `POST /api/v1/rest/auth/login` |
| Request body | `{ userName, password, rememberMe: true }` |
| Response wrapper | `ApiResponseModel<TokenResponseModel>` |
| Token field path | `res.result.AccessToken` (or `res.Result.AccessToken`) — **not** `res.data.accessToken` |

### CSS for the login form

```css
.mix-login-form{display:flex;flex-direction:column;gap:.5rem;width:100%;text-align:left}
.mix-login-input{width:100%;border:1px solid #e5e7eb;border-radius:.5rem;padding:.5rem .75rem;font-size:.8125rem;font-family:inherit;background:#fff;color:#111;outline:none;transition:border-color .12s;box-sizing:border-box}
.mix-login-input:focus{border-color:var(--primary,#6366f1)}
.mix-login-err{font-size:.75rem;color:#dc2626;display:none;padding:.25rem 0}
.mix-login-btn{width:100%;padding:.5rem;border:none;border-radius:.5rem;cursor:pointer;background:var(--primary,#6366f1);color:#fff;font-size:.8125rem;font-family:inherit;font-weight:600;transition:opacity .12s}
.mix-login-btn:hover:not(:disabled){opacity:.88}
.mix-login-btn:disabled{opacity:.5;cursor:not-allowed}
```

---

## Troubleshooting checklist

| Symptom | Likely cause | Fix |
|---|---|---|
| Logged-out visitor connects but the sign-in gate never appears | A host that redirects the anonymous `negotiate` to an HTML login page (302 → `/p/login`) makes `hub.start()` throw a `SyntaxError` instead of a clean 401, so a 401-only check misses it | In `handleConnectError`, treat the redirect as a secondary auth signal: gate on `m.indexOf('DOCTYPE')`, `m.indexOf('not valid JSON')`, `m.indexOf('Unexpected token')` in addition to `statusCode === 401` |
| Login succeeds but widget shows "Invalid response from server" | Wrong field path — `ApiResponseModel<T>` uses `Result` not `data`; `TokenResponseModel.AccessToken` is PascalCase | Read: `var r = res.result \|\| res.Result; var tok = r.accessToken \|\| r.AccessToken;` |
| Hub connect fails with 401 (the expected case) | Token not in `localStorage['mix_access_token']` or expired — the hub is `.RequireAuthorization()` (Bearer), so it returns proper 401 JSON | Verify login flow sets this key; inspect Network → WS handshake headers. Detect with `statusCode === 401` and show the login gate |
| Suggestion button click populates input but send button stays disabled | Programmatic `input.value =` does not fire the `input` event | Call `setSend()` explicitly after setting `input.value` |
| AI responses show raw markdown (e.g. `[link text](/url)` instead of a link) | `marked.js` not loaded, or `bubble.innerHTML = fmt(text)` not called | Add `marked.js` CDN; use `rawText` accumulator + `bubble.innerHTML = fmt(rawText)` |
| Razor throws `@keyframes` error at render | Unescaped `@` in CSS | Change all `@keyframes`, `@media`, `@font-face` to `@@keyframes`, `@@media`, `@@font-face` |
| SignalR CDN 404 or `signalR is not defined` | CDN URL has wrong escaping | Use `@@microsoft/signalr@@8.0.7` — both `@@` positions required |
| Widget shows but CSS is missing | CSS placed in `styles` parameter, not `content` | Move all `<style>` tags into the `content` field |
| `ReceiveComplete` fires but `vm.content` is undefined | Server serialized PascalCase | Access `vm.content || vm.Content` |
| Bubble fills during streaming but markdown renders wrong on complete | Using `bubble.textContent` to recover streamed text | Use a separate `rawText` string accumulator — `textContent` strips HTML after `innerHTML` is set |
| Drawer opens but body still scrolls | `document.body.style.overflow = 'hidden'` not reached | Verify `setOpen(true)` path — add `console.log` to confirm the code runs |
| Header button click does nothing | `#mix-chat-btn` not found | Ensure widget partial is included in the master layout, not a page template |
| Hub disconnects on idle | SignalR server keepalive / client timeout mismatch | `.withAutomaticReconnect()` handles this; no additional config needed for defaults |
| Multiple connect attempts on SPA nav | `initHub` called more than once | Guard with `if (hub) return;` before `buildHub()` |
| Reloaded conversation looks intact but server replies "what conversation?" | `sessionId` not restored from `localStorage` — a fresh one was generated on init | `loadHistory()` must run **before** `initHub()` and must populate `sessionId` from `mix_chat_session_id` |
| Reloaded assistant bubbles show raw markdown like `**bold**` | History rendered via `textContent` instead of `fmt()` | In `renderHistory()`, use `div.innerHTML = fmt(m.text)` for assistant entries |
| Page reload mid-stream shows a truncated assistant bubble as if it were finished | Persisted inside `onChunk` — saved a partial snapshot | Persist only after `send` (user) and after `onComplete` success (assistant) — never inside `onChunk` |
| `QuotaExceededError` after long sessions | History grew past the 5 MB localStorage cap | Cap at 50 messages, FIFO trim before each `setItem`, and add a quota-exceeded catch that drops the oldest half |
| New user on shared browser sees previous user's chat | `mix_chat_history` not cleared on sign-out | Call `clearHistory()` from the sign-out / token-rotation flow |
| `JSON.parse` throws on init and breaks the widget | Corrupted/legacy value in `mix_chat_history` | Wrap `JSON.parse` in `try/catch` and fall back to `history = []` |

# Template Editing — get_template / search_replace_template / validate_template

Safe edit-and-verify loop for existing templates. Pair with [razor-rules.md](razor-rules.md) (syntax) — this file covers the tool mechanics that cause silent or confusing failures.

## 1. Sequence writes before validation

- Call `validate_template` only **after** the write (`update_template` / `search_replace_template`) has returned — never in the same parallel batch, or it can compile the pre-edit content. A result that seems to predate your edit → re-run `validate_template` on its own.
- Two edits to the same template = two **sequential** calls; a parallel read-modify-write can drop one.
- Converting several templates (e.g. literals → `@(L["key"])`): validate **each template right after its own edit**, so a self-introduced error stays in one file.
- Parameter names differ: `get_template(id=…)`, but `validate_template(templateId=…)` (newer builds also accept `id`). On "Provide either templateId or content", retry with `templateId`.

## 2. What `validate_template` does NOT catch

It is a Razor/C# compile check only. It does **not** parse inline JavaScript, does not render `@section`s, and does not notice a query or relationship join that is always empty. After any JS edit, re-read the stored template with `get_template(id=…)` and inspect the actual `<script>` text; runtime errors need a browser pass or full scan.

## 3. JavaScript inside `<script>` — never HTML-escape it

The HTML parser does **not** decode character references inside `<script>`. Writing `&amp;&amp;` for `&&` (or `&lt;` for `<`) sends those literal characters to the browser → `SyntaxError` → the whole inline script dies, while `validate_template` still says `success:true`. Write JS operators raw.

Razor still applies inside `<script>`:
- Literal `@` → `@@` (regex `[^@@\s]+@@`, CDN `@@microsoft`) — see razor-rules.md §2.
- An explicit expression must close its paren: `'@(L["ws.task.record"])'`. A missing `)` makes the compiler swallow the following `});` as C#.

## 4. `search_replace_template` — `oldString` must byte-match the stored text

The tool does not HTML-decode its parameters.
- Pass raw markup: `<link rel="icon" … />`, never `&lt;link … /&gt;`.
- If the file genuinely stores `&amp;&amp;`, pass exactly those 8 characters — not the over-escaped `&amp;amp;&amp;amp;`. Pass the desired output (`&&`) literally in `newString`.
- Escape sequences stored as literal bytes must be passed the same way — a JS string stored as `'Submitting…'` matches only with backslash-u-2026, not the `…` character.
- On "old_string not found": stop guessing — re-read with `get_template(id=…)` and build `oldString` from that live text. **Never** copy `oldString` from a wiki / knowledge-base `search` result; indexed copies can be stale (report the stale doc for regeneration). After 2 mismatches, switch to `update_template` with the full body.

## 5. Reading `get_template` output

The raw tool result is JSON-encoded twice (`{"Text":"{\"data\":{\"Content\":\"…\"}}"}`). Hand-decoding it can silently drop characters — e.g. `href="/library"` misread as `href="library"`, or `/\n/g` looking like `/\\n/g`. Do not "fix" a defect you only saw in the escaped dump: confirm with an exact-match `search_replace_template`. "old_string not found" disproves the phantom — no edit needed.

## 6. Tenant document URLs

`write_text_file` paths are relative to the tenant folder `wwwroot/mixcontent/documents/tenant_{id}/`, so a file is served at `/mixcontent/documents/tenant_{id}/<path>`. An `href`/`src` without the `tenant_{id}` segment 404s, and the tenant-less path cannot be written. Confirm the real folder with `list_text_files` (`basePath`) before linking an asset.

# Building a Multilingual Site

How to author and render content in multiple cultures (languages) with Mixcore. Load this when a task mentions multiple languages, cultures, translations, `specificulture`, a language/culture switcher, or `@L["..."]`.

## 0. 🚨 Pre-flight — run this BEFORE any language / multilingual work

🚨 **CRITICAL RULE: never start translating or editing a multilingual template before completing these checks.** Skipping them is the cause of "the page title changed but the labels didn't", duplicate-slug 400s, switcher 404s, blank module regions, and untranslated MixDB content.

1. **Check the existing cultures.** Call `list_cultures`. Is the tenant single- or multi-culture, and what are the exact codes (`en-us`, `vi-vn`)? The first culture is the default. A single-culture site applies no filtering — adding a 2nd culture is what turns multilingual on (§1). Use the full registered code everywhere — `en` ≠ `en-us` (§4).
2. **Check whether the template is already translated.** Read the master/page template. Does it use `@L["key"]` keys (translated, option 2 §6) or hardcoded literals / `@if (culture == "vi-vn")` branches (NOT translated — both are hardcoding, §6)? If not translated, localize it via `@L` + `set_language_content` before authoring per-culture content. Cross-check the keys exist with `list_languages`.
3. **Check the switch-language URL rule.** Confirm each switcher link resolves **path → route key → that key's URL in the TARGET culture** (not `?culture=` appended to the current path — that 404s on per-culture slugs), that **only** the switcher link carries `?culture=` (plain nav relies on the `mix_culture` cookie), and that culture is **never** a URL path segment (no `/en/` routing) (§5). The target-culture URL comes from the `nav.*.url` key via `L.GetKey(path)` (path → key) + `L.GetForCulture(key, culture)` (key → target-culture URL) — see §5.
4. **Check the navigation URLs are translated.** Every regular nav / menu / footer link must localize **both label and URL** as language keys — `<a href="@(L["nav.menu.url"])">@(L["nav.menu"])</a>` — never a hardcoded `href="/menu"` (that 404s in vi). The `nav.*.url` key holds the active culture's full path (vi `/thuc-don`); links stay plain (no `?culture=`; the cookie holds the culture). A nav menu hardcoded to one culture's slugs is the most common multilingual break after the switcher itself (§6).

After `create_culture`, follow the post-create workflow: validate templates → translate cloned content → translate language keys → verify. Content cloning and page-module associations are automatic (backend). See §7 "After creating a culture."

## 1. Cultures

- Each tenant has one or more cultures. The **first** culture is the **default**. Create one with `create_culture(specificulture, displayName)` (e.g. `en-us`, `vi-vn`).
- 🚨 **`create_culture` creates the culture; the backend automatically handles content cloning and page-module associations.** After calling `create_culture`, follow the workflow in §7 "After creating a culture" (translate cloned content, translate language keys, handle MixDB tables, verify). The backend auto-creates per-culture content and auto-syncs page-module associations — no manual step needed for cloning or linking.
- A site with a single culture behaves exactly like a non-multilingual site — no culture filtering is applied (see §5). You only "go multilingual" by adding a 2nd culture.

## 2. Per-culture content (Entity / EntityContent)

Pages, posts, and modules store **one content row per culture** (like `MixPage`→`MixPageContent`). Each culture gets its **own** SEO name (slug) and its **own** translated HTML content.

- **`create_culture` auto-creates per-culture content and page-module associations on the backend** — no manual step needed for cloning or association syncing. The backend handles both automatically when a new culture is created.
- 🚨 **The same `seoName` is allowed across cultures** (e.g. `gioi-thieu` in both `en-us` and `vi-vn`). A duplicate `(tenant, culture, seoName)` is rejected at write time (400). Two same-culture rows with one slug would make the culture-scoped read throw `Sequence contains more than one element`.

## 3. Read a specific culture

When a slug/system-name exists in several cultures, pass the culture to disambiguate (otherwise you get the first match):

- MCP: `get_page_content_by_seo_name(seoName, specificulture)`, `get_post_content_by_seo_name(seoName, specificulture)`, `get_module_content_by_system_name(systemName, specificulture)`. The `list_*` tools also take an optional `specificulture` filter.
- REST: `GET /api/v1/rest/{pages|posts|modules}/by-seo-name/{slug}?specificulture=vi-vn` (modules: `/by-system-name/{name}?specificulture=`).

## 3b. MixDB-driven content — add a `specificulture` column

🚨 **Custom MixDB tables are NOT culture-aware on their own.** Pages/posts/modules get per-culture rows automatically (§2/§7), but a hand-built table (`mix_products`, `mix_news`, `mix_testimonials`, …) has no culture dimension — a template renders the **same rows for every culture**, so its text shows one language regardless of the active culture.

When building a multilingual site, give any table whose **displayed text differs per culture** a `specificulture` column and store **one row per (item, culture)**, mirroring the Entity/EntityContent pattern:

- Add the column on the schema pass: `create_column(tableName, "specificulture", "Text")` (varchar) — do this **before** seeding (re-migrating a populated table can drop rows).
- Seed one row per culture (`en-us`, `vi-vn`, …). Culture-neutral fields (price, image URL, coordinates) can stay duplicated or be split into a shared parent table — only split the text that actually translates.
- **Filter by the resolved request culture** in the template/query — add `specificulture` to the filter array:

```cshtml
@{ var culture = Context.Items["Specificulture"] as string ?? "en-us";
   var filter = "[{\"fieldName\":\"status\",\"value\":\"Published\",\"operator\":\"=\"},"
              + "{\"fieldName\":\"specificulture\",\"value\":\"" + culture + "\",\"operator\":\"=\"}]";
   var products = await DbService.GetDataAsync("mix_products", filter); }
```

Without the column, MixDB text is frozen to whatever single language was seeded (and locale-specific values stay stuck). Add it during the schema phase of a multilingual build.

## 4. Rendering resolves the request culture

For a multilingual tenant (>1 culture), the server resolves the request culture and serves that culture's content. Precedence: **`?culture=` query → `mix_culture` cookie → `Accept-Language` (q-value aware) → tenant default**, each validated against the tenant's cultures. A single-culture tenant skips this entirely.

🚨 **Read the resolved culture in a template from `Context.Items["Specificulture"]`** — `TenantResolutionMiddleware` sets only this `HttpContext.Items` entry; it does **NOT** set `Thread.CurrentCulture`. So `System.Globalization.CultureInfo.CurrentCulture` stays the server default and any `CultureInfo.CurrentCulture.Name.StartsWith("vi")` check never flips (the page *title* may still change because content-row selection uses the resolved culture — that masks the bug). Use:

```cshtml
@{ var culture = Context.Items["Specificulture"] as string ?? "en-us";
   var isVietnamese = culture.StartsWith("vi", StringComparison.OrdinalIgnoreCase); }
```

🚨 **Culture codes match EXACTLY** (case-insensitive) against registered cultures — `?culture=en` does NOT match a registered `en-us`; it silently falls back to the default. Always use the full registered code (`en-us`, `vi-vn`).

## 5. Culture switcher (template)

Show it only when the tenant has >1 culture, and use the **full** culture code in `?culture=` (see the exact-match rule above).

🚨 **A switcher that only appends `?culture=` to the current path 404s on any page whose slug differs per culture.** Pages store one slug per culture (e.g. en `/menu`, vi `/thuc-don`), so `/menu?culture=vi-vn` resolves no vi page named `menu`. The correct algorithm is **current path → route key → that key's URL in the TARGET culture → switch link**.

The route URL is itself a **localized language key**, stored right next to its label (§6): `nav.menu` = the label, `nav.menu.url` = the full path per culture (`/menu` in `en-us`, `/thuc-don` in `vi-vn`). So a regular nav link localizes **both**:

```cshtml
<li><a href="@(L["nav.menu.url"])">@(L["nav.menu"])</a></li>   @* en → /menu Menu · vi → /thuc-don Thực Đơn *@
```

The switcher needs the **target** culture's value of that URL key. `IMixLocalizer` provides two methods for this (beyond the current-culture `this[key]` / `Get(key, fallback)`):

| Method | Purpose |
|---|---|
| `string? GetKey(string value)` | **Reverse lookup** — the key whose value (current culture, then default) equals `value`. Maps the request path back to its `nav.*.url` key. Returns `null` if unmatched; first match wins when a value is shared. |
| `string GetForCulture(string key, string culture, string? fallback = null)` | The key's value in an **explicit** culture (the language switcher's target). Empty culture = current culture. **Named distinctly from `Get`** because a 2-arg `Get(key, culture)` would silently bind to the existing `Get(key, fallback)` overload. |

Canonical switcher — `GetKey` the current path, then `GetForCulture` each target culture. No path map to maintain; it covers **every** `nav.*.url` key automatically:

```cshtml
@{
    var switchKey = L.GetKey(Context.Request.Path.ToString());   // "/thuc-don" → "nav.menu.url"
    var enPath = string.IsNullOrEmpty(switchKey) ? "/" : L.GetForCulture(switchKey, "en-us", "/");
    var viPath = string.IsNullOrEmpty(switchKey) ? "/" : L.GetForCulture(switchKey, "vi-vn", "/");
}
<a href="@(enPath)?culture=en-us" class="lang-link">EN</a>
<a href="@(viPath)?culture=vi-vn" class="lang-link">VN</a>
```

🚨 **A route URL value is the *complete* target path — emit it verbatim; never re-prepend a culture segment.** Mixcore carries culture in `?culture=` + the `mix_culture` cookie, **not** in a URL path segment — there is **no `/en/`-style culture routing** (the only path prefix middleware reads is `/t/{slug}/`, for *tenant* resolution). If a site happens to give one culture prefixed slugs (en `/en/menu` vs vi `/thuc-don`), that `/en` is just part of that page's stored `seoName` and is **already inside the `nav.*.url` value**. So `"/en" + L["nav.menu.url"]` on a value that is already `/en/menu` yields `/en/en/menu` (404). The key value is the whole href — emit it as-is (plus `?culture=…` on the switcher), prepending nothing.

`TenantResolutionMiddleware` **persists a valid `?culture=` to the `mix_culture` cookie automatically**, so the chosen culture survives later *plain* navigation (the per-culture nav slugs then resolve in the right culture instead of 404ing). No JS cookie-setting needed — a plain `?culture=` switch link is enough. The slug map above still matters so the switch *link itself* lands on the target culture's slug.

🚨 **Only the switcher link carries `?culture=`. Regular nav, menu, and footer links use the plain per-culture slug** (`/thuc-don`, `/menu`, …) — the `mix_culture` cookie set by the switcher keeps every later plain link in that culture. Do **not** append `?culture=` to every URL on the page: it's noise, the cookie already handles persistence, and it's the wrong instinct to "make each link safe." The switcher is the *one* link whose job is to force a culture, so it's the only one that needs the query.

## 6. Translating a template — two options

When the template renders one language but you need it in others, pick one:

1. **Separate template/master per culture** — clone the template, translate the literals, assign the culture's pages to their own `templateId`/`layoutId`. Use this only when the cultures need **structurally different** layouts (different sections, RTL, distinct nav). Cost: N templates to keep in sync forever.
2. **One template + the `@L` localizer** *(default — recommended)* — keep a single template; replace hardcoded labels with `@L["key"]` and store the per-culture strings as language keys. One template serves every culture; translators edit strings, not Razor. Use this whenever the layout is the same across cultures (the usual case).

Default to **option 2**; reach for option 1 only for genuinely divergent per-culture layouts.

🚨 **Per-culture `@if (culture == "vi-vn") { "Trang Chủ" } else { "Home" }` label branches ARE hardcoding** — both languages live in the Razor and every new string forces a template edit. For a multilingual site that is **wrong**: translate the template (option 2) with one `@L["nav.home"]` key per label and store the strings as language content. The moment a tenant has >1 culture, replace hardcoded literals (and per-culture `@if`/`else` text branches) with `@L[...]` keys. Hardcoded literals are only acceptable on a single-culture site.

🚨 **A nav link's URL is a language key too, not just its label.** Don't hardcode `href="/menu"` — store the per-culture path as `nav.<name>.url` next to the label `nav.<name>`, so the link localizes end to end:

```cshtml
✅  <li><a href="@(L["nav.menu.url"])">@(L["nav.menu"])</a></li>   @* both href and text are keys *@
❌  <li><a href="/menu">@(L["nav.menu"])</a></li>                  @* hardcoded en slug → 404 in vi *@
```

Create the pair with `set_language_content`: `set_language_content("nav.menu.url","en-us","/menu")` + `set_language_content("nav.menu.url","vi-vn","/thuc-don")`, alongside `nav.menu` = `Menu`/`Thực Đơn`. The switcher (§5) reuses the same `nav.*.url` keys via the target culture.

### Option 2 — the i18n localizer (`@L`)

For hardcoded UI labels (nav, buttons), use localization **keys** instead of literals so one template serves every culture:

- In a Razor template: `@inject Mix.Lib.Services.IMixLocalizer L` then `@L["nav.home"]`. `this[key]` / `Get(key, fallback)` resolve the **current request culture** (falling back current-culture → default-culture → the key itself, never blank); `GetForCulture(key, culture, fallback)` resolves an **explicit** culture (the switcher's target, §5); `GetKey(value)` reverse-looks-up a value to its key. For a value inside an HTML attribute use the explicit form `@(L["key"])` (the `["..."]` quotes confuse the implicit-expression parser inside `attr="..."`).
- Create/set the key/value strings via the **language MCP tools** (snake_case): `set_language_content(systemName, specificulture, content)` — **creates the key on demand** + upserts the translation in one call (the easiest path); plus `create_language`, `list_languages`, `get_language_contents`, `delete_language`. Or the **portal** `/p` → **Content → Languages** (key × culture grid). Or **REST**: `POST /api/v1/rest/languages` to create the key, then `PUT /api/v1/rest/languages/content` per culture — ⚠️ the REST PUT returns **404 if the key doesn't exist yet** (unlike the MCP tool, it does NOT create on demand). All require an Admin/Editor JWT; the `X-Api-Key` is MCP-only. Edits take effect live (the localization cache busts on every write).

### Worked example — converting a hardcoded-language template

Symptom: the page **content** is one language but the **master/page template** renders another (hardcoded labels). Fix = localize the template, don't fork a per-culture template:

1. `@inject Mix.Lib.Services.IMixLocalizer L` at the top of the master.
2. Replace each hardcoded label with a key: `>Trang Chủ<` → `>@L["nav.home"]<`, `>Giỏ Hàng<` → `>@L["nav.cart"]<`, footer/heading text likewise. Make `<html lang>` dynamic too: `lang="@(currentCulture.Split('-')[0])"`.
3. Create each key for **every** culture: `set_language_content("nav.home", "en-us", "Home")` + `set_language_content("nav.home", "vi-vn", "Trang Chủ")`.
4. `validate_template` → then verify: `/` renders the default-culture labels, `/?culture=vi-vn` renders the other. One template, both languages.

> Create the keys **before** the template references them — a missing key renders the raw key string (`nav.home`), not blank.

## 7. Per-culture content workflow

`create_culture` creates the culture record, fans out every language key, auto-creates per-culture content, and auto-syncs page-module associations — all handled by the backend.

- **Language key create → fan-out.** Creating a key fans out an (empty) content row per culture; deleting the key cascades all its translations.
- **Content cloning and page-module associations are automatic.** The backend handles both when `create_culture` is called. No manual step needed.

### After creating a culture

`create_culture` creates the culture; the backend auto-clones content and auto-syncs page-module associations. Follow these steps to translate the clones:

**Step 1 — Create the new culture.** Call `create_culture(specificulture, displayName)` (e.g. `"vi-vn"`, `"Tiếng Việt"`). The backend automatically: fans out language keys, clones all default-culture pages/posts/modules, and syncs page-module associations. The call returns the new culture; cloned content is immediately queryable.

**Step 2 — Validate templates use `@L` (MixLocalizer).** 🚨 Before translating content, verify every template renders user-facing strings through `IMixLocalizer` — a template with hardcoded literals will show the wrong language regardless of the active culture.

1. **List all templates** for the site theme via `list_templates`.
2. **Read each template** via `get_template(id)` and inspect the `content` field:
   - ✅ **Translated:** `@inject Mix.Lib.Services.IMixLocalizer L` at the top + `@L["key"]` for every label, nav item, heading, button, and placeholder. The `IMixLocalizer` indexer (`this[key]` → `L["key"]`) reads a `Dictionary<string,string>` loaded from `MixLanguageContent` rows keyed by `(tenant, culture, MixLanguage.SystemName)` — it returns the current-culture translated value, falling back default-culture → key itself (never blank). Source: `src/platform/mix.lib/Services/MixLocalizer.cs`.
   - ❌ **Not translated:** hardcoded string literals (`"Home"`, `"Liên Hệ"`) or `@if (culture == "vi-vn") { … } else { … }` branches — both languages are baked into the Razor. Localize before proceeding (§6 option 2).
   - ❌ **Missing injection:** `@L[...]` used but no `@inject IMixLocalizer L` → `CS0103` at render. Add the injection.
3. **Fix all hardcoded templates** before continuing. Create language keys for every string with `set_language_content` (one call per key per culture), then `update_template` to replace literals with `@L["key"]`. Validate with `validate_template` after each edit. A template that mixes `@L` keys and hardcoded literals still renders the hardcoded parts in one language — be exhaustive.

**Step 3 — Translate the auto-cloned content.** List everything filtered by the new culture, then translate in place. The backend already cloned pages/posts/modules and synced page-module associations — you only need to translate.

3a. **List the cloned content:**
```
list_page_contents(specificulture: "vi-vn")
list_post_contents(specificulture: "vi-vn")
list_module_contents(specificulture: "vi-vn")
```

3b. **Page-module associations are auto-synced by the backend** — no manual step needed.

3c. **Translate pages, posts, and modules in place:**
```
update_page_content(
    id: <pageId>,
    title: "<Translated title>",
    content: "<Translated HTML content>",
    excerpt: "<Translated excerpt>",
    seoName: "<translated-slug>"   // optional
)
```
Same for posts (`update_post_content`) and modules (`update_module_content`). Translate the `content` field (body HTML) — that's what the visitor sees.

3d. **Translate every language key** for the new culture:
```
set_language_content("nav.home", "vi-vn", "Trang Chủ")
set_language_content("nav.home.url", "vi-vn", "/")
set_language_content("nav.about", "vi-vn", "Giới Thiệu")
set_language_content("nav.about.url", "vi-vn", "/gioi-thieu")
// ... one call per key per culture
```
Use `list_languages` to see all existing keys; call `set_language_content` for each key+culture pair (creates the key on demand — just pass the name, culture, and value).

3e. **Handle MixDB tables with a `specificulture` column.** For any table whose displayed text differs per culture (§3b):

- **First, determine the default culture** — call `list_cultures`. The first culture is the default. Use its `specificulture` as the column default so existing rows are stamped with the current site language.
- **Table already has a `specificulture` column** — create rows for the new culture via `create_row`, then translate text columns with `update_row`.
- **Table does NOT yet have a `specificulture` column** — add one with the default culture as the column default:
  ```
  add_column_to_table(databaseSystemName: "mix_products", schemaText: "Add a specificulture text column with default value '<defaultCulture>'")
  ```
  This stamps all existing rows. Then create rows for the new culture and translate.

Without this step, MixDB-driven content renders the same text in every culture.

**Step 4 — Verify language keys for the new culture.** 🚨 A language key with an empty or untranslated `Content` value renders the raw key string as fallback text — the visitor sees `nav.home` instead of `Trang Chủ`.

1. **List all language keys** with `list_languages`. Filter to the new culture: `get_language_contents(specificulture: "vi-vn")`.
2. **Check every key has a translated value.** For each key, confirm `Content` is filled with the correct translation for the new culture. A key whose `Content` is null/empty but has a `DefaultContent` will show the default culture's text — not wrong, but not translated. A key with neither renders the key name itself.
3. **Fix gaps** with `set_language_content(key, "vi-vn", "<translated>")` for any missing or incorrect entry.
4. **Browser-verify.** Open the site with `?culture=vi-vn` and confirm every page renders translated content and labels. The switcher links resolve correctly (§5) once the `nav.*.url` keys are translated.

## Gotchas

- **Single-culture site, content not in the default culture / NULL culture:** no filter is applied, so it renders — adding a 2nd culture turns filtering on.
- **Never** create a second same-culture page/post with an existing slug — it's rejected; translate into a *different culture* instead.

# Building a Multilingual Site

How to author and render content in multiple cultures (languages) with Mixcore. Load this when a task mentions multiple languages, cultures, translations, `specificulture`, a language/culture switcher, or `@L["..."]`.

## 1. Cultures

- Each tenant has one or more cultures. The **first** culture is the **default**. Create one with `create_culture(specificulture, displayName)` (e.g. `en-us`, `vi-vn`).
- A site with a single culture behaves exactly like a non-multilingual site — no culture filtering is applied (see §5). You only "go multilingual" by adding a 2nd culture.

## 2. Per-culture content (Entity / EntityContent)

Pages, posts, and modules store **one content row per culture** (like `MixPage`→`MixPageContent`). To author a translation, create a **separate** content row stamped with the target culture:

- `create_page_content(..., specificulture: "vi-vn")` — omit `specificulture` to use the tenant default.
- Same for `create_post_content` / `create_module_content`.
- 🚨 The **same `seoName` is allowed across cultures** (e.g. `quan-ao` in both `en-us` and `vi-vn`) but **NOT twice within one culture** — a duplicate `(tenant, culture, seoName)` is rejected at write time (400). Two same-culture rows with one slug would make the culture-scoped read throw `Sequence contains more than one element`.

## 3. Read a specific culture

When a slug/system-name exists in several cultures, pass the culture to disambiguate (otherwise you get the first match):

- MCP: `get_page_content_by_seo_name(seoName, specificulture)`, `get_post_content_by_seo_name(seoName, specificulture)`, `get_module_content_by_system_name(systemName, specificulture)`. The `list_*` tools also take an optional `specificulture` filter.
- REST: `GET /api/v1/rest/{pages|posts|modules}/by-seo-name/{slug}?specificulture=vi-vn` (modules: `/by-system-name/{name}?specificulture=`).

## 4. Rendering resolves the request culture

For a multilingual tenant (>1 culture), the server resolves the request culture and serves that culture's content. Precedence: **`?culture=` query → `mix_culture` cookie → `Accept-Language` (q-value aware) → tenant default**, each validated against the tenant's cultures. A single-culture tenant skips this entirely.

## 5. Culture switcher (template)

Add a switcher to the master layout that sets the choice and reloads. Show it only when the tenant has >1 culture. Set both the cookie (site-wide persistence) and `?culture=` (shareable URL):

```html
<select onchange="(function(c){document.cookie='mix_culture='+c+';path=/;max-age=31536000';var u=new URL(location.href);u.searchParams.set('culture',c);location.href=u;})(this.value)">
  <option value="en-us">English</option>
  <option value="vi-vn">Tiếng Việt</option>
</select>
```

## 6. Translating a template — two options

When the template renders one language but you need it in others, pick one:

1. **Separate template/master per culture** — clone the template, translate the literals, assign the culture's pages to their own `templateId`/`layoutId`. Use this only when the cultures need **structurally different** layouts (different sections, RTL, distinct nav). Cost: N templates to keep in sync forever.
2. **One template + the `@L` localizer** *(default — recommended)* — keep a single template; replace hardcoded labels with `@L["key"]` and store the per-culture strings as language keys. One template serves every culture; translators edit strings, not Razor. Use this whenever the layout is the same across cultures (the usual case).

Default to **option 2**; reach for option 1 only for genuinely divergent per-culture layouts.

### Option 2 — the i18n localizer (`@L`)

For hardcoded UI labels (nav, buttons), use localization **keys** instead of literals so one template serves every culture:

- In a Razor template: `@inject Mix.Lib.Services.IMixLocalizer L` then `@L["nav.home"]`. It resolves the key for the current request culture, falling back current-culture → default-culture → the key itself (never blank).
- Manage the key/value strings in the **portal**: `/p` → **Content → Languages** (key × culture grid). Or via MCP `set_language_content(systemName, specificulture, content)` (creates the key on demand), or REST `PUT /api/v1/rest/languages/content`. Edits take effect live (cache busts on write).

### Worked example — converting a hardcoded-language template

Symptom: the page **content** is one language but the **master/page template** renders another (hardcoded labels). Fix = localize the template, don't fork a per-culture template:

1. `@inject Mix.Lib.Services.IMixLocalizer L` at the top of the master.
2. Replace each hardcoded label with a key: `>Trang Chủ<` → `>@L["nav.home"]<`, `>Giỏ Hàng<` → `>@L["nav.cart"]<`, footer/heading text likewise. Make `<html lang>` dynamic too: `lang="@(currentCulture.Split('-')[0])"`.
3. Create each key for **every** culture: `set_language_content("nav.home", "en-us", "Home")` + `set_language_content("nav.home", "vi-vn", "Trang Chủ")`.
4. `validate_template` → then verify: `/` renders the default-culture labels, `/?culture=vi-vn` renders the other. One template, both languages.

> Create the keys **before** the template references them — a missing key renders the raw key string (`nav.home`), not blank.

## 7. Auto-sync across cultures (server behavior — happens for you)

The server keeps cultures in sync automatically; you rarely hand-author every culture:

- **Content create → fan-out.** Creating a page/post/module in the **default** culture auto-creates a clone in **every other** culture, with a culture-suffixed slug `"<seo>-<culture>"` (e.g. `quan-ao` → `quan-ao-vi-vn`) and its **own** parent entity. Deleting the default-culture row cascades those clones. (Non-default rows don't fan out — they *are* translations.)
- **Culture create → clone.** Creating a new culture clones **all** the default culture's pages/posts/modules (suffixed slugs, own parents) **and** every language key into the new culture. Deleting a culture removes all of that culture's page/post/module/language content.
- **Language key create → fan-out.** Creating a key fans out an (empty) content row per culture; deleting the key cascades all its translations.
- **Implication:** to add a language, just create the culture (or author the default-culture content) — the siblings appear pre-populated as copies of the source; then edit each translation in place (the suffixed slug is editable). Don't hand-create one page per culture.

## Gotchas

- **Single-culture site, content not in the default culture / NULL culture:** no filter is applied, so it renders — adding a 2nd culture turns filtering on.
- **Never** create a second same-culture page/post with an existing slug — it's rejected; translate into a *different culture* instead.
- The localizer resolves keys off the parent `MixLanguage` key, so renaming a key doesn't orphan its translations.

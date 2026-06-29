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

## 6. UI strings — the i18n localizer (`@L`)

For hardcoded UI labels (nav, buttons), use localization **keys** instead of literals so one template serves every culture:

- In a Razor template: `@inject Mix.Lib.Services.IMixLocalizer L` then `@L["nav.home"]`. It resolves the key for the current request culture, falling back current-culture → default-culture → the key itself (never blank).
- Manage the key/value strings in the **portal**: `/p` → **Content → Languages** (key × culture grid). Or via MCP `set_language_content(systemName, specificulture, content)` (creates the key on demand), or REST `PUT /api/v1/rest/languages/content`. Edits take effect live (cache busts on write).

## Gotchas

- **Single-culture site, content not in the default culture / NULL culture:** no filter is applied, so it renders — adding a 2nd culture turns filtering on.
- **Never** create a second same-culture page/post with an existing slug — it's rejected; translate into a *different culture* instead.
- The localizer resolves keys off the parent `MixLanguage` key, so renaming a key doesn't orphan its translations.

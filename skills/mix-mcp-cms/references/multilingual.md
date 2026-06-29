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

🚨 **A switcher that only appends `?culture=` to the current path 404s on any page whose slug differs per culture.** Pages store one slug per culture (e.g. en `/menu`, vi `/thuc-don`), so `/menu?culture=vi-vn` resolves no vi page named `menu`. Each switcher link must point at the **target culture's slug**:

- **Default (auto-sync) slugs** are suffixed `"<seo>-<culture>"` (§7), so the target slug is derivable from the default-culture slug.
- **Custom per-culture slugs** (hand-set, e.g. `thuc-don`) need an explicit **slug map** in the master. `@L` cannot help here — `IMixLocalizer` resolves the *current* culture only (no `L["key", culture]` overload), so it can't emit the other culture's slug.

```cshtml
@{
    // (en, vi) slug pairs — match the current path by EITHER culture's slug, link to the TARGET slug.
    var slugPairs = new[] { ("/menu","/thuc-don"), ("/about","/ve-chung-toi") };
    var cur = Context.Request.Path.ToString().TrimEnd('/'); if (cur == "") cur = "/";
    string enSlug = "/", viSlug = "/";   // fallback: home → /?culture=
    foreach (var (en, vi) in slugPairs)
        if (string.Equals(cur, en, StringComparison.OrdinalIgnoreCase) || string.Equals(cur, vi, StringComparison.OrdinalIgnoreCase))
        { enSlug = en; viSlug = vi; break; }
}
<a href="@(viSlug)?culture=vi-vn" class="lang-link">VI</a>
<span>|</span>
<a href="@(enSlug)?culture=en-us" class="lang-link">EN</a>
```

`TenantResolutionMiddleware` **persists a valid `?culture=` to the `mix_culture` cookie automatically**, so the chosen culture survives later *plain* navigation (the per-culture nav slugs then resolve in the right culture instead of 404ing). No JS cookie-setting needed — a plain `?culture=` switch link is enough. The slug map above still matters so the switch *link itself* lands on the target culture's slug.

## 6. Translating a template — two options

When the template renders one language but you need it in others, pick one:

1. **Separate template/master per culture** — clone the template, translate the literals, assign the culture's pages to their own `templateId`/`layoutId`. Use this only when the cultures need **structurally different** layouts (different sections, RTL, distinct nav). Cost: N templates to keep in sync forever.
2. **One template + the `@L` localizer** *(default — recommended)* — keep a single template; replace hardcoded labels with `@L["key"]` and store the per-culture strings as language keys. One template serves every culture; translators edit strings, not Razor. Use this whenever the layout is the same across cultures (the usual case).

Default to **option 2**; reach for option 1 only for genuinely divergent per-culture layouts.

### Option 2 — the i18n localizer (`@L`)

For hardcoded UI labels (nav, buttons), use localization **keys** instead of literals so one template serves every culture:

- In a Razor template: `@inject Mix.Lib.Services.IMixLocalizer L` then `@L["nav.home"]`. It resolves the key for the **current request culture only** (no culture-override overload — `this[key]` / `Get(key, fallback)`), falling back current-culture → default-culture → the key itself (never blank). For a value inside an HTML attribute use the explicit form `@(L["key"])` (the `["..."]` quotes confuse the implicit-expression parser inside `attr="..."`).
- Create/set the key/value strings via the **language MCP tools** (snake_case): `set_language_content(systemName, specificulture, content)` — **creates the key on demand** + upserts the translation in one call (the easiest path); plus `create_language`, `list_languages`, `get_language_contents`, `delete_language`. Or the **portal** `/p` → **Content → Languages** (key × culture grid). Or **REST**: `POST /api/v1/rest/languages` to create the key, then `PUT /api/v1/rest/languages/content` per culture — ⚠️ the REST PUT returns **404 if the key doesn't exist yet** (unlike the MCP tool, it does NOT create on demand). All require an Admin/Editor JWT; the `X-Api-Key` is MCP-only. Edits take effect live (the localization cache busts on every write).

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

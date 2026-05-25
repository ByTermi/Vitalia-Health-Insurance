---
name: content-validator
description: "Validate translation completeness across all locales, check data file schema consistency, find hardcoded strings, and audit SEO fields (title/description length, canonical, hreflang). Trigger: /content-validator"
trigger: /content-validator
---

# /content-validator

Validate that all user-facing content is correct, complete, and consistent: translations, data schemas, SEO metadata, and internal links.

## Usage

```
/content-validator                    # full validation pass
/content-validator --i18n             # translation completeness only
/content-validator --data             # JSON data schema validation only
/content-validator --seo              # SEO fields audit only
/content-validator --links            # broken internal links only
/content-validator --hardcoded        # find hardcoded strings that should be translated
```

---

## What You Must Do When Invoked

### Step 1 — Discover project structure

Read `package.json`, check for next-intl, i18n config. Find:
- Locale list (e.g. `i18n/routing.ts`)
- Translation files location (e.g. `messages/*.json`)
- Data files (e.g. `data/*.json`)
- Page files (all `app/**/page.tsx`)

### Step 2 — Translation completeness (--i18n)

For each locale file, compare keys against the `en` baseline:

```powershell
# Find all message files
Get-ChildItem messages -Filter "*.json" | ForEach-Object { $_.Name }
```

Read all locale JSON files. Build a flat key set for each. Diff against `en`:

- **Missing keys**: key exists in `en` but not in locale → flag as missing
- **Extra keys**: key exists in locale but not in `en` → flag as orphan (probably a mistake)
- **Empty values**: key exists but value is `""` → flag as untranslated

Report per locale:
```
Locale completeness:
  en:    289/289 keys  100%  ✅
  de:    287/289 keys   99%  🟡 Missing: footer.tagline, nav.tools
  ja:    251/289 keys   87%  🔴 38 missing keys
  fr:    289/289 keys  100%  ✅
  es:    289/289 keys  100%  ✅
  pt-BR: 284/289 keys   98%  🟡
  zh:    246/289 keys   85%  🔴 43 missing keys
```

List all missing keys grouped by namespace.

### Step 3 — Hardcoded strings (--hardcoded)

Grep all `.tsx`/`.ts` page and component files for English text that isn't going through the translation function:

- Strings longer than 3 words in JSX that aren't using `t('...')` or `tCommon('...')`
- Hardcoded link text like `"Open tool"`, `"View all"`, `"Learn more"`
- Button labels that aren't translated

```powershell
# Find JSX text nodes with English words (rough heuristic)
Select-String -Path "app/**/*.tsx","components/**/*.tsx" -Pattern '>[A-Z][a-z]+ [a-z]' -Recurse
```

Flag each finding with file + line number. Note: don't flag text inside `aria-label` (often intentional), SVG `<title>`, or code comments.

### Step 4 — Data file schema validation (--data)

For each JSON file in `data/`:

1. Read the file.
2. Sample the first 3 and last 3 entries.
3. Check that all entries have the same top-level keys (no missing fields).
4. Check types are consistent (no entry has `capital: string` when others have `capital: string[]`).
5. Check for null/undefined values in required fields.
6. For `countries.json` specifically: verify `cca2`, `name`, `region`, `flag` are present for all entries.

Report:
```
Data validation:
  countries.json: 195 entries, 0 schema errors ✅
  currencies.json: 162 entries, 3 entries missing 'symbol' field 🟡
```

### Step 5 — SEO fields audit (--seo)

For each page file, check:
- `generateMetadata` exists
- `title` is present and 40-65 characters
- `description` is present and 100-160 characters
- `canonical` URL is set in `alternates`
- `hreflang` alternatives are set for all 7 locales

```powershell
Select-String -Path "app/**/*.tsx" -Pattern "generateMetadata" -Recurse | Select-Object -ExpandProperty Path
```

For each page that has `generateMetadata`, read it and check the above. Flag:
- Missing metadata function entirely
- Title too short (<40) or too long (>65)
- Description too short (<100) or too long (>160)
- Missing canonical
- Missing hreflang

### Step 6 — Internal links (--links)

Collect all `href` values from `Link` and `<a>` components across all pages. For each internal link (starts with `/`):

1. Parse the locale prefix out.
2. Check if the corresponding page file exists in `app/[locale]/`.
3. Flag any link whose target page doesn't exist.

```powershell
Select-String -Path "app/**/*.tsx","components/**/*.tsx" -Pattern 'href=["'`][/][^"'`]+["'`]' -Recurse
```

### Step 7 — Report summary

```
Content Validation Report — <project>

Translations:     3 locales incomplete (ja: 38 missing, zh: 43 missing, pt-BR: 5 missing)
Hardcoded text:   12 strings found across 4 files
Data schemas:     1 issue (currencies.json missing 'symbol' in 3 entries)
SEO metadata:     2 pages missing descriptions, 1 title too long
Internal links:   0 broken links ✅
```

Then list all issues with file + line + exact fix needed.

### Step 8 — Write Obsidian report

Write to `projects/<name>/content/YYYY-MM-DD-validation.md` in the vault.

---

## Rules

- Don't auto-fix translations — a missing translation needs a human (or a translation pass).
- Do auto-fix clearly mechanical issues: hardcoded `key` in `.map()` that's just the index, missing `alt=""` on decorative images, whitespace-only translation values.
- When reporting missing translations, group by namespace so it's easy to batch-fix.
- SEO length guidelines are soft — flag but don't auto-truncate titles without user approval.

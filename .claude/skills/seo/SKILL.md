---
name: seo
description: "Audit and improve a website's SEO: technical health, on-page content, structured data, Core Web Vitals, sitemap/robots, and keyword strategy. Trigger: /seo"
trigger: /seo
---

# /seo

Full SEO audit and improvement workflow. Analyzes technical health, on-page signals, structured data, performance, and content strategy — then delivers prioritized fixes with copy-paste-ready code.

## Usage

```
/seo                          # audit current project (reads HTML, config, source files)
/seo <url>                    # audit a live URL (fetches and analyzes)
/seo <path>                   # audit a local project directory
/seo --technical              # technical SEO only (meta, robots, sitemap, canonicals)
/seo --content                # content and keyword optimization only
/seo --performance            # Core Web Vitals and page speed only
/seo --structured-data        # schema.org / JSON-LD audit and generation
/seo --fix                    # apply fixes automatically (edits files in place)
```

## What /seo Does

Three things a developer needs that generic SEO tools miss:

1. **Code-level fixes** — not just "add a meta description" but the exact `<meta>` tag, schema JSON, or sitemap entry to add to which file.
2. **Framework awareness** — knows the difference between Next.js `<Head>`, Remix `meta()`, Astro frontmatter, and raw HTML.
3. **Priority ranking** — issues are sorted by impact so you fix what matters first, not what's easiest.

## What You Must Do When Invoked

If no path or URL was given, use `.` (current directory). Do not ask the user for one unless the project root is truly ambiguous.

Follow these steps in order.

---

### Step 1 — Detect project type and entry points

Identify the framework and locate the main HTML entry points:

- **Next.js / Remix / Astro / SvelteKit**: look for `app/`, `pages/`, `src/routes/`, `src/pages/` — read `_document.tsx`, `layout.tsx`, `root.tsx`, `+layout.svelte` as applicable
- **Raw HTML**: glob `**/*.html`
- **WordPress / CMS**: look for `functions.php`, theme files, `wp-config.php`
- **SPA (React/Vue/Angular)**: look for `index.html`, `vite.config.*`, `webpack.config.*`

Print a one-line summary:
```
Project: Next.js 14 · Entry: app/layout.tsx, app/page.tsx · Pages found: 12
```

---

### Step 2 — Technical SEO audit

Check each item and record pass/fail/missing:

**Meta tags (per page)**
- `<title>` — present, unique, 50–60 characters
- `<meta name="description">` — present, unique, 150–160 characters
- `<meta name="robots">` or `<meta name="googlebot">` — not accidentally set to `noindex`
- `<link rel="canonical">` — present and self-referencing on canonical pages
- `<meta property="og:*">` — Open Graph tags for title, description, image, url, type
- `<meta name="twitter:*">` — Twitter Card tags

**Structural**
- One `<h1>` per page (not zero, not multiple)
- Heading hierarchy: h1 → h2 → h3, no skipped levels
- `<html lang="...">` attribute present
- Image `alt` attributes on all `<img>` tags
- Internal links use descriptive anchor text (flag generic "click here" / "read more")

**Crawlability**
- `robots.txt` exists at root — check for accidental `Disallow: /`
- `sitemap.xml` exists and is referenced in `robots.txt`
- No `noindex` on pages that should be indexed
- No broken internal links (check `href` values, flag `#`, `javascript:void(0)`, empty strings)

**Canonicals**
- Canonical tag points to the correct URL (not to a redirect chain)
- `www` vs non-`www` consistent
- Trailing slash consistent

---

### Step 3 — Structured data audit

Search for existing JSON-LD (`<script type="application/ld+json">`) or Microdata.

Validate against common schema types:
- **Article / BlogPosting**: `headline`, `author`, `datePublished`, `dateModified`, `image`
- **Product**: `name`, `price`, `priceCurrency`, `availability`
- **Organization / WebSite**: `name`, `url`, `logo`, `sameAs`
- **BreadcrumbList**: `item`, `position`, `name`
- **FAQPage**: `mainEntity` with `Question` / `Answer`

Flag: missing required properties, incorrect `@type`, wrong `@context` URL, date format not ISO 8601.

---

### Step 4 — Core Web Vitals and performance signals

Check for patterns that hurt CWV without running Lighthouse:

**LCP (Largest Contentful Paint)**
- Hero images: missing `loading="eager"` or `fetchpriority="high"`
- No `<link rel="preload">` for above-the-fold images or fonts
- Render-blocking `<script>` in `<head>` without `defer` or `async`

**CLS (Cumulative Layout Shift)**
- `<img>` tags missing explicit `width` and `height` attributes
- Web fonts without `font-display: swap`
- Dynamic ad slots without reserved space (`min-height`)

**INP (Interaction to Next Paint)**
- Long tasks from synchronous third-party scripts in the critical path
- Missing `passive: true` on scroll/touch event listeners

**General**
- Unoptimized image formats (`.jpg`/`.png` where `.webp`/`.avif` should be used)
- No lazy loading on below-the-fold images (`loading="lazy"`)
- CSS/JS not minified in production

---

### Step 5 — Content and keyword signals

If source files are HTML/MDX/Markdown, analyze:
- Title and H1 alignment: do they share the primary keyword?
- Keyword density: is the primary topic mentioned in the first 100 words?
- Internal linking: are there opportunities to link to related pages?
- Content length: flag pages under 300 words that are meant to rank
- Duplicate content: flag pages with near-identical `<title>` or `<meta description>`

Do not invent keywords. Identify them from the existing content.

---

### Step 6 — Generate prioritized findings

Present findings as a ranked list. Use this format exactly:

```
SEO AUDIT — <project name>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CRITICAL (fix immediately — blocks indexing or ranking)
  [1] Missing <title> on 3 pages: /about, /contact, /blog
  [2] robots.txt Disallow: / blocks all crawlers

HIGH (significant ranking impact)
  [3] No <meta description> on 8/12 pages
  [4] Missing canonical tags on paginated routes (/blog?page=2)
  [5] 14 images missing alt attributes

MEDIUM (good practice, measurable lift)
  [6] Open Graph tags missing on all pages
  [7] No sitemap.xml found
  [8] Hero image missing fetchpriority="high" (LCP impact)

LOW (polish)
  [9] <html> missing lang attribute
  [10] 2 pages have multiple <h1> tags

PASSING (no action needed)
  ✓ Canonical tags present on main pages
  ✓ robots.txt present and well-formed
  ✓ Heading hierarchy correct on 10/12 pages
```

---

### Step 7 — Generate fixes

For each CRITICAL and HIGH issue, output the exact fix:

**Format per fix:**
```
Fix #1 — Missing <title> on /about
File: src/app/about/page.tsx
Add inside <Head> (or return from metadata export):

  <title>About Us | Company Name</title>
  <meta name="description" content="Learn about our mission, team, and values." />

Next.js 14 App Router version:
  export const metadata = {
    title: 'About Us | Company Name',
    description: 'Learn about our mission, team, and values.',
  }
```

For MEDIUM issues, provide the fix but group them by file to minimize edits.

For structured data generation, output complete, valid JSON-LD blocks ready to paste.

For sitemap.xml, generate a complete file if missing.

---

### Step 8 — Summary and next steps

End with:
```
Summary: X critical · Y high · Z medium · W low
Estimated indexability improvement: [high/medium/low] based on findings

Quick wins (under 5 min each):
  1. Add <html lang="en"> to index.html
  2. Add alt attributes to images in Hero.tsx (14 images)
  3. Add <link rel="sitemap"> to robots.txt

Needs design input:
  - Meta descriptions require knowing your target keywords and tone
  - OG images need to be created (1200×630px recommended)
```

---

## Multilingual SEO

When a project uses `/i18n` (next-intl with locale routing), these checks extend the standard audit.

### hreflang — the most commonly broken multilingual SEO element

Every page must declare all language variants in `<head>`. Missing or wrong hreflang causes Google to treat pages as duplicates and suppress all variants.

Required set for the 7-language stack:
```tsx
// In generateMetadata() — must appear on EVERY page, not just the homepage
alternates: {
  canonical: `https://yoursite.com/${locale}/current-path`,
  languages: {
    'en':      'https://yoursite.com/en/current-path',
    'de':      'https://yoursite.com/de/current-path',
    'ja':      'https://yoursite.com/ja/current-path',
    'fr':      'https://yoursite.com/fr/current-path',
    'es':      'https://yoursite.com/es/current-path',
    'pt-BR':   'https://yoursite.com/pt-BR/current-path',
    'zh':      'https://yoursite.com/zh/current-path',
    'x-default': 'https://yoursite.com/en/current-path', // always point to English
  },
}
```

Audit checks:
- [ ] hreflang present on every page (not just home)
- [ ] Canonical matches the current locale URL (not pointing to /en)
- [ ] `x-default` points to English
- [ ] hreflang is reciprocal — if /en points to /de, /de must point back to /en
- [ ] `<html lang="de">` matches the locale being served

### Per-locale keyword strategy

Do not just translate keywords literally. Search intent differs by language:

- **German (de):** Users often search with compound words — "Hypothekenrechner" not "Hypotheken Rechner". Check local variants.
- **Japanese (ja):** Mix of kanji, hiragana, katakana in queries — check what form searchers actually use.
- **Spanish (es):** LATAM vs Spain can use different terms for the same concept.
- **Chinese (zh):** Simplified characters only for zh — Traditional is a separate audience (zh-TW).

When auditing a multilingual site: check that each locale's `metaTitle` and `metaDescription` uses the locally-searched keyword phrase, not a literal translation of the English version.

### Multilingual sitemap

The sitemap must include every locale variant of every URL, with `alternates`:
```ts
// Each URL entry should look like:
{
  url: 'https://yoursite.com/de/tools/calculator',
  alternates: {
    languages: {
      'en': 'https://yoursite.com/en/tools/calculator',
      'de': 'https://yoursite.com/de/tools/calculator',
      // ... all locales
    }
  }
}
```

Flag if the sitemap only lists English URLs — Google won't discover the other locale pages reliably.

### Duplicate content check

Each locale URL must return genuinely translated content. Flag if:
- A locale page returns English text (translation missing, fallback showing)
- Multiple locales return identical content
- The `<html lang="">` attribute doesn't match the page's actual language

---

## Honesty Rules

- Never claim a page ranks or doesn't rank — you can only assess signals, not Google's algorithm.
- Never invent keywords. Work from what's already in the content.
- Never suggest removing `noindex` from pages you don't understand (login, admin, staging).
- If you can't read the files (live URL, CMS-rendered content), say so and describe what to check manually.
- Always flag `--fix` changes before writing them. Do not silently edit production files.
- hreflang errors are silent — Google won't warn you. Always verify the output HTML, not just the code.

---
name: i18n
description: "Set up and manage multilingual Next.js projects with next-intl. Covers 7 languages (en, de, ja, fr, es, pt-BR, zh), hreflang SEO, locale routing, translation workflow, and per-language sitemap. Trigger: /i18n"
trigger: /i18n
---

# /i18n

Full internationalization for Next.js App Router projects using next-intl. Wires locale routing, hreflang tags, multilingual sitemap, and translation workflow for 7 target languages ranked by AdSense revenue potential.

## Target languages (revenue-ordered)

| Code | Language | Market | RPM tier |
|------|----------|--------|----------|
| `en` | English | US/UK/AU/CA | Highest |
| `de` | German | DE/AT/CH | High |
| `ja` | Japanese | JP | High |
| `fr` | French | FR + global diaspora | Medium-high |
| `es` | Spanish | ES + LATAM | Medium |
| `pt-BR` | Portuguese (Brazil) | BR | Medium |
| `zh` | Chinese Simplified | TW/HK/SG + diaspora | Medium |

## Usage

```
/i18n                               # full setup wizard for a new project
/i18n --setup                       # install and wire next-intl from scratch
/i18n --add <locale>                # add a new language to existing setup
/i18n --translate <locale>          # generate translations for a locale from English source
/i18n --audit                       # find missing translation keys across all locales
/i18n --seo                         # verify hreflang tags and multilingual sitemap
/i18n --revenue                     # show language priority and RPM data
```

---

## What You Must Do When Invoked

Default locale set: `['en', 'de', 'ja', 'fr', 'es', 'pt-BR', 'zh']`
Default locale: `en`

---

### /i18n or /i18n --setup — Full setup from scratch

Install and wire next-intl in a Next.js 14+ App Router project. Follow these steps in order.

---

#### Step 1 — Install

```bash
pnpm add next-intl
```

---

#### Step 2 — next.config.ts

```ts
import createNextIntlPlugin from 'next-intl/plugin'

const withNextIntl = createNextIntlPlugin()

const nextConfig = {
  // your existing config
}

export default withNextIntl(nextConfig)
```

---

#### Step 3 — src/i18n/request.ts

```ts
import { getRequestConfig } from 'next-intl/server'

export default getRequestConfig(async ({ locale }) => ({
  messages: (await import(`../../messages/${locale}.json`)).default,
}))
```

---

#### Step 4 — middleware.ts (at project root, not inside src/)

```ts
import createMiddleware from 'next-intl/middleware'

export default createMiddleware({
  locales: ['en', 'de', 'ja', 'fr', 'es', 'pt-BR', 'zh'],
  defaultLocale: 'en',
  localePrefix: 'always', // → /en/... /de/... /ja/... etc.
})

export const config = {
  // Match all paths except API routes, _next internals, and static files
  matcher: ['/((?!api|_next/static|_next/image|favicon.ico|.*\\..*).*)'],
}
```

---

#### Step 5 — Move app content under [locale]

Restructure `src/app/` so every route is under a `[locale]` segment:

```
src/app/
  [locale]/
    layout.tsx        ← was app/layout.tsx
    page.tsx          ← was app/page.tsx
    blog/
      page.tsx
      [slug]/
        page.tsx
    not-found.tsx
  layout.tsx          ← minimal root layout (just <html> and <body>, no providers)
```

**Root `src/app/layout.tsx`** (thin wrapper — next-intl requires this):
```tsx
export default function RootLayout({ children }: { children: React.ReactNode }) {
  return children
}
```

**`src/app/[locale]/layout.tsx`**:
```tsx
import { NextIntlClientProvider } from 'next-intl'
import { getMessages, getLocale } from 'next-intl/server'
import { notFound } from 'next/navigation'
import type { Metadata } from 'next'

const locales = ['en', 'de', 'ja', 'fr', 'es', 'pt-BR', 'zh'] as const
type Locale = typeof locales[number]

interface Props {
  children: React.ReactNode
  params: { locale: string }
}

export function generateStaticParams() {
  return locales.map((locale) => ({ locale }))
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { locale } = params
  const baseUrl = process.env.NEXT_PUBLIC_BASE_URL ?? 'https://yoursite.com'
  
  return {
    alternates: {
      canonical: `${baseUrl}/${locale}`,
      languages: {
        'en':      `${baseUrl}/en`,
        'de':      `${baseUrl}/de`,
        'ja':      `${baseUrl}/ja`,
        'fr':      `${baseUrl}/fr`,
        'es':      `${baseUrl}/es`,
        'pt-BR':   `${baseUrl}/pt-BR`,
        'zh':      `${baseUrl}/zh`,
        'x-default': `${baseUrl}/en`,
      },
    },
  }
}

export default async function LocaleLayout({ children, params }: Props) {
  const { locale } = params
  
  if (!locales.includes(locale as Locale)) notFound()
  
  const messages = await getMessages()

  return (
    <html lang={locale}>
      <body>
        <NextIntlClientProvider messages={messages}>
          {children}
        </NextIntlClientProvider>
      </body>
    </html>
  )
}
```

---

#### Step 6 — Message files

Create `messages/` at the project root (next to `src/`):

```
messages/
  en.json
  de.json
  ja.json
  fr.json
  es.json
  pt-BR.json
  zh.json
```

**Structure convention** — namespace by page/component, then key:

```json
{
  "Nav": {
    "home": "Home",
    "blog": "Blog",
    "tools": "Tools",
    "about": "About"
  },
  "HomePage": {
    "title": "Free Online Tools",
    "subtitle": "Fast, accurate, and always free",
    "cta": "Get started"
  },
  "Footer": {
    "privacy": "Privacy Policy",
    "copyright": "© {year} Your Site"
  },
  "Common": {
    "loading": "Loading...",
    "error": "Something went wrong",
    "tryAgain": "Try again"
  }
}
```

---

#### Step 7 — Using translations in components

**Server Component:**
```tsx
import { useTranslations } from 'next-intl'

export default function HomePage() {
  const t = useTranslations('HomePage')
  return (
    <main>
      <h1>{t('title')}</h1>
      <p>{t('subtitle')}</p>
    </main>
  )
}
```

**Client Component:**
```tsx
'use client'
import { useTranslations } from 'next-intl'

export function Nav() {
  const t = useTranslations('Nav')
  return (
    <nav>
      <a href="/">{t('home')}</a>
      <a href="/blog">{t('blog')}</a>
    </nav>
  )
}
```

**With variables:**
```tsx
// In JSON: "welcome": "Welcome, {name}!"
t('welcome', { name: 'Juan' }) // → "Welcome, Juan!"

// In JSON: "copyright": "© {year} Your Site"
t('copyright', { year: new Date().getFullYear() })
```

**Pluralization:**
```json
{
  "items": "{count, plural, =0 {No items} =1 {One item} other {# items}}"
}
```
```tsx
t('items', { count: 3 }) // → "3 items"
```

---

#### Step 8 — Per-page metadata with locale

Every page should override `generateMetadata` to add locale-specific title and description:

```tsx
import { getTranslations } from 'next-intl/server'

interface Props {
  params: { locale: string }
}

export async function generateMetadata({ params: { locale } }: Props) {
  const t = await getTranslations({ locale, namespace: 'HomePage' })
  const baseUrl = process.env.NEXT_PUBLIC_BASE_URL ?? 'https://yoursite.com'

  return {
    title: t('metaTitle'),
    description: t('metaDescription'),
    alternates: {
      canonical: `${baseUrl}/${locale}`,
      languages: {
        'en': `${baseUrl}/en`,
        'de': `${baseUrl}/de`,
        'ja': `${baseUrl}/ja`,
        'fr': `${baseUrl}/fr`,
        'es': `${baseUrl}/es`,
        'pt-BR': `${baseUrl}/pt-BR`,
        'zh': `${baseUrl}/zh`,
        'x-default': `${baseUrl}/en`,
      },
    },
  }
}
```

Add to each locale's message file:
```json
{
  "HomePage": {
    "metaTitle": "Free Mortgage Calculator | YourSite",
    "metaDescription": "Calculate your monthly mortgage payment instantly. Free, accurate, no sign-up required."
  }
}
```

---

#### Step 9 — Multilingual sitemap

Create `src/app/sitemap.ts`:

```ts
import { MetadataRoute } from 'next'

const locales = ['en', 'de', 'ja', 'fr', 'es', 'pt-BR', 'zh'] as const
const baseUrl = process.env.NEXT_PUBLIC_BASE_URL ?? 'https://yoursite.com'

// Add all static routes here
const routes = ['', '/blog', '/tools', '/about']

export default function sitemap(): MetadataRoute.Sitemap {
  const entries: MetadataRoute.Sitemap = []

  for (const route of routes) {
    for (const locale of locales) {
      entries.push({
        url: `${baseUrl}/${locale}${route}`,
        lastModified: new Date(),
        changeFrequency: route === '' ? 'daily' : 'weekly',
        priority: route === '' ? 1.0 : 0.8,
        alternates: {
          languages: Object.fromEntries(
            locales.map((l) => [l, `${baseUrl}/${l}${route}`])
          ),
        },
      })
    }
  }

  return entries
}
```

---

#### Step 10 — Language switcher component

```tsx
// src/components/LanguageSwitcher.tsx
'use client'
import { useLocale } from 'next-intl'
import { usePathname, useRouter } from 'next/navigation'

const localeNames: Record<string, string> = {
  en: 'English',
  de: 'Deutsch',
  ja: '日本語',
  fr: 'Français',
  es: 'Español',
  'pt-BR': 'Português',
  zh: '中文',
}

export function LanguageSwitcher() {
  const locale = useLocale()
  const pathname = usePathname()
  const router = useRouter()

  function switchLocale(newLocale: string) {
    // Replace the current locale prefix in the path
    const pathWithoutLocale = pathname.replace(`/${locale}`, '') || '/'
    router.push(`/${newLocale}${pathWithoutLocale}`)
  }

  return (
    <select
      value={locale}
      onChange={(e) => switchLocale(e.target.value)}
      aria-label="Select language"
    >
      {Object.entries(localeNames).map(([code, name]) => (
        <option key={code} value={code}>{name}</option>
      ))}
    </select>
  )
}
```

---

### /i18n --add <locale> — Add a new language

1. Add the locale code to the `locales` array in:
   - `middleware.ts`
   - `src/app/[locale]/layout.tsx` (both the array and the `alternates.languages` object)
   - `src/app/sitemap.ts`
   - `src/components/LanguageSwitcher.tsx` (add to `localeNames`)

2. Create `messages/<locale>.json` — copy from `en.json` as the starting point.

3. Run `/i18n --translate <locale>` to generate translations.

4. Verify the new route works: `http://localhost:3000/<locale>`

---

### /i18n --translate <locale> — Generate translations

Translate all keys in `messages/en.json` into the target locale.

**Rules for translation:**
- Translate the VALUE, not the key — keys stay in English always
- Preserve placeholders exactly: `{name}`, `{count}`, `{year}` must remain unchanged
- Preserve ICU message format: `{count, plural, ...}` structure must be kept
- For Chinese (zh): use Simplified Chinese characters (不是繁體)
- For Spanish (es): use neutral Latin American Spanish — avoid Spain-specific vocabulary
- For Portuguese (pt-BR): use Brazilian Portuguese, not European Portuguese
- For Japanese (ja): use formal register (です/ます form) unless the site is casual
- For German (de): capitalize all nouns — this is grammatically required

SEO-critical keys (`metaTitle`, `metaDescription`) must be:
- Naturally written in the target language — not literal translations
- Including the primary keyword in that language
- Within character limits (title: 50–60 chars, description: 150–160 chars)

Output the translated JSON file. Then write it to `messages/<locale>.json`.

---

### /i18n --audit — Find missing translations

Read all `messages/*.json` files. Compare every locale against `en.json` (the source of truth).

Output:
```
Translation Audit
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Source: en.json (47 keys)

de.json      ✓ Complete (47/47)
ja.json      ✓ Complete (47/47)
fr.json      ⚠ Missing 3 keys:
               - HomePage.newFeatureTitle
               - HomePage.newFeatureCta
               - Common.retry
es.json      ✓ Complete (47/47)
pt-BR.json   ⚠ Missing 1 key:
               - Common.retry
zh.json      ✗ Missing 8 keys: [run /i18n --translate zh to fix]

Action: run /i18n --translate <locale> for each incomplete locale.
```

---

### /i18n --seo — Verify multilingual SEO

Check the following for every page that has locale variants:

1. **hreflang tags present** — every `<head>` must include all language variants plus `x-default`
2. **Canonical tag matches current locale URL** — not pointing to the English version
3. **`lang` attribute on `<html>`** — must match the current locale (`lang="de"`, `lang="ja"`, etc.)
4. **Page title and description are translated** — not the English version served for all locales
5. **Sitemap includes all locale URLs** — with `alternates.languages` entries
6. **No duplicate content** — each locale URL must return unique translated content (not the same English text)

Output pass/fail per check per locale.

---

### /i18n --revenue — Revenue by language

Print the revenue prioritization table (from the marketing skill) and recommend which pages to translate first based on current traffic:

```
Language Revenue Priority
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Build in this order:

1. English (en)    — $5–50 RPM  — DONE (baseline)
2. German (de)     — $3–15 RPM  — best ROI for translation effort
3. Japanese (ja)   — $3–15 RPM  — high CPM, low competition in most niches
4. French (fr)     — $2–8 RPM   — large diaspora, often overlooked
5. Spanish (es)    — $1–5 RPM   — high volume, lower CPM
6. Portuguese (pt) — $0.5–3 RPM — Brazil market, growing fast
7. Chinese (zh)    — $1–5 RPM   — targets TW/HK/SG diaspora

Translation effort per page: ~15 min with AI translation + review
Payoff: German version of a high-traffic tool page can match English RPM with 10x less traffic.

Translate these pages first (highest impact):
  1. Homepage
  2. Top tool page by traffic
  3. Top article page by traffic
```

---

## Content translation notes by language

### German (de)
- All nouns are capitalized: "Der Rechner" not "der rechner"
- Formal address: "Sie" (capital S) not "du" for professional sites
- Compound words are one word: "Hypothekenrechner" not "Hypotheken Rechner"
- Search intent can differ — check local keyword variants, not just translations

### Japanese (ja)
- Use です/ます form (polite) for most sites
- Numbers can use Arabic numerals (1, 2, 3) — no need for kanji numerals in UI
- CTA buttons should be concise — Japanese users prefer shorter action text
- Date format: YYYY年MM月DD日

### French (fr)
- Space before colon, question mark, exclamation mark: `Bonjour : bienvenue`
- Guillemets for quotes: « like this »
- Formal "vous" for professional sites, "tu" for very casual ones

### Spanish (es)
- Use neutral Spanish that works for both Spain and LATAM (avoid "vosotros")
- Inverted punctuation: `¿Cómo calcular tu hipoteca?`
- Dates: DD/MM/YYYY format

### Portuguese Brazil (pt-BR)
- Distinct from European Portuguese — different vocabulary and spelling
- Informal register is generally accepted (Brazil culture is warmer)
- Currency: R$ (real)

### Chinese Simplified (zh)
- No spaces between words — Chinese text flows without spaces
- Use simplified characters (简体) — not traditional (繁體)
- Punctuation: 。，！？「」— not Western punctuation
- Full-width parentheses: （like this）

---

---

## Blog / Article Content Translation

UI strings (nav, buttons, labels) live in `messages/*.json`. Blog and article **content** is different — each article is a large document that may or may not exist in all languages.

### File structure

Use locale-scoped content files rather than one file with all translations:

```
content/
  blog/
    {slug}/
      en.mdx        ← source of truth
      de.mdx        ← translated when ready
      ja.mdx
      fr.mdx
      es.mdx
      pt-BR.mdx
      zh.mdx
```

This allows each locale to have its own content independently, and makes it easy to check which translations exist.

### Static params — only generate pages that exist

```ts
// src/app/[locale]/blog/[slug]/page.tsx
import { readdirSync, existsSync } from 'fs'
import { join } from 'path'

const contentDir = join(process.cwd(), 'content/blog')

export async function generateStaticParams() {
  const slugs = readdirSync(contentDir)
  const params: { locale: string; slug: string }[] = []

  for (const slug of slugs) {
    const locales = ['en', 'de', 'ja', 'fr', 'es', 'pt-BR', 'zh']
    for (const locale of locales) {
      if (existsSync(join(contentDir, slug, `${locale}.mdx`))) {
        params.push({ locale, slug })
      }
    }
  }

  return params
}
```

This prevents 404s and avoids generating empty pages for untranslated content.

### hreflang on content pages — only for existing translations

Only include language variants in hreflang that actually have translated content:

```ts
export async function generateMetadata({ params }: Props) {
  const { locale, slug } = params
  const baseUrl = process.env.NEXT_PUBLIC_BASE_URL ?? 'https://yoursite.com'
  const allLocales = ['en', 'de', 'ja', 'fr', 'es', 'pt-BR', 'zh']

  // Build alternates only for locales that have a translation
  const languages: Record<string, string> = {}
  for (const l of allLocales) {
    if (existsSync(join(contentDir, slug, `${l}.mdx`))) {
      languages[l] = `${baseUrl}/${l}/blog/${slug}`
    }
  }
  // x-default always points to English
  if (languages['en']) languages['x-default'] = languages['en']

  return {
    title: frontmatter.title,
    description: frontmatter.description,
    alternates: {
      canonical: `${baseUrl}/${locale}/blog/${slug}`,
      languages,
    },
  }
}
```

**Never add hreflang for a locale that doesn't have translated content.** Google will find the English page and treat it as duplicate content, triggering a penalty.

### Handling missing translations (when a user navigates to an untranslated locale)

Three acceptable approaches — pick one per project:

**Option A: 404 (simplest, cleanest for SEO)**
The `generateStaticParams` approach above already handles this — Next.js will return 404 for any locale/slug combination that wasn't generated.

**Option B: Redirect to English**
```ts
export default async function BlogPost({ params }: Props) {
  const { locale, slug } = params
  const filePath = join(contentDir, slug, `${locale}.mdx`)

  if (!existsSync(filePath)) {
    redirect(`/en/blog/${slug}`)
  }
  // ... render the post
}
```

**Option C: Show English with a language banner**
```tsx
{locale !== 'en' && !translationExists && (
  <div className="mb-6 rounded-md border border-yellow-300 bg-yellow-50 p-3 text-sm text-yellow-800">
    This article is not yet available in {localeName}. Showing the English version.
  </div>
)}
```
Use this only if you have the English content available as a fallback. Don't include hreflang for the non-translated locales if you use this approach.

### Article translation workflow (with AI)

When a new article exists in English and needs to be translated:

1. Read the source `en.mdx`
2. Translate the **body content** naturally — not word-for-word
3. Translate the **frontmatter fields**: title, description, tags (if locale-specific)
4. Keep MDX syntax intact — components (`<Calculator />`, `<Callout>`), links, and image paths are unchanged
5. Adapt locale-specific content:
   - Currency examples: use local currency (€ for de/fr/es, ¥ for ja, R$ for pt-BR)
   - Date formats: DD/MM/YYYY for es, YYYY年MM月DD日 for ja
   - Phone/address formats in examples: use local patterns
6. Write to `content/blog/{slug}/{locale}.mdx`
7. Update the sitemap (automatic if using `generateStaticParams`)

### Sitemap for content with partial translations

The static sitemap generator must iterate over actual files, not assume all locales exist:

```ts
// src/app/sitemap.ts — blog section
import { readdirSync, existsSync } from 'fs'
import { join } from 'path'

const contentDir = join(process.cwd(), 'content/blog')
const allLocales = ['en', 'de', 'ja', 'fr', 'es', 'pt-BR', 'zh']

function getBlogEntries(): MetadataRoute.Sitemap {
  const slugs = readdirSync(contentDir)
  const entries: MetadataRoute.Sitemap = []

  for (const slug of slugs) {
    for (const locale of allLocales) {
      if (!existsSync(join(contentDir, slug, `${locale}.mdx`))) continue

      // Build alternates only for existing translations
      const languages: Record<string, string> = {}
      for (const l of allLocales) {
        if (existsSync(join(contentDir, slug, `${l}.mdx`))) {
          languages[l] = `${baseUrl}/${l}/blog/${slug}`
        }
      }

      entries.push({
        url: `${baseUrl}/${locale}/blog/${slug}`,
        lastModified: new Date(),
        changeFrequency: 'monthly',
        priority: 0.7,
        alternates: { languages },
      })
    }
  }

  return entries
}
```

---

## Honesty Rules

- Never add a language and leave the messages file in English — Google will detect duplicate content and penalize it.
- hreflang tags are required for every language variant on every page — missing hreflang causes Google to treat the pages as duplicates.
- **Only include hreflang for locales that actually have translated content** — not for every locale in your setup.
- Machine translation (AI) is acceptable for a first pass, but SEO-critical copy (titles, descriptions, headings, CTAs) should be reviewed by a native speaker or be a genuinely natural translation — not word-for-word.
- Chinese (zh) will have very low AdSense fill rates for mainland China visitors — the value comes from the Chinese diaspora in Taiwan, Hong Kong, Singapore, and Western countries.

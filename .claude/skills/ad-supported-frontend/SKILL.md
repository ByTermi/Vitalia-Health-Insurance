---
name: ad-supported-frontend
description: "Build and optimize ad-supported frontends: integrate Google AdSense/AdMob, place ad units for maximum revenue without hurting Core Web Vitals or UX, handle ad blockers, and implement consent management for GDPR/CCPA. Trigger: /ad-supported-frontend"
trigger: /ad-supported-frontend
---

# /ad-supported-frontend

Full ad monetization skill for web and mobile frontends. Covers ad network integration, unit placement strategy, performance protection, consent management, and revenue optimization — with working code for each step.

## Usage

```
/ad-supported-frontend                        # interactive setup for a new project
/ad-supported-frontend --network adsense      # Google AdSense (web)
/ad-supported-frontend --network admob        # Google AdMob (React Native / mobile)
/ad-supported-frontend --network mediavine    # Mediavine (content sites)
/ad-supported-frontend --network custom       # custom ad server / header bidding
/ad-supported-frontend --framework react      # React implementation
/ad-supported-frontend --framework next       # Next.js (SSR-aware ad loading)
/ad-supported-frontend --framework vue        # Vue 3
/ad-supported-frontend --consent gdpr         # add GDPR consent management (EU)
/ad-supported-frontend --consent ccpa         # add CCPA opt-out (California)
/ad-supported-frontend --consent both         # GDPR + CCPA
/ad-supported-frontend --audit                # audit existing ad setup for revenue leaks and CWV issues
/ad-supported-frontend --layout <path>        # suggest ad placement for a specific page layout
```

## What /ad-supported-frontend Delivers

Ad monetization done wrong kills two things simultaneously: revenue (bad placements, slow loads) and SEO (CLS, LCP, intrusive interstitials). This skill avoids both:

1. **CWV-safe placements** — reserved space before ads load, no layout shift
2. **Lazy loading** — ads below the fold load only when near the viewport
3. **Consent-first** — no ad scripts fire before user consent where required
4. **Fallback handling** — graceful display when ads are blocked or not filled

---

## What You Must Do When Invoked

If no flags were given, run the setup wizard. If flags are present, go directly to the relevant step.

---

### Step 1 — Setup wizard (when no flags given)

Ask these questions in one message:

```
To set up ad monetization, I need a few details:

1. Frontend framework: React / Next.js / Vue / Vanilla HTML
2. Ad network: Google AdSense / AdMob / Mediavine / Custom
3. Site type: Blog/Content / E-commerce / Tool/App / Game
4. Geo audience: Global / Primarily EU / Primarily US / Mixed
5. Consent management: Do you already have a CMP (Consent Management Platform)?
6. Approximate monthly pageviews (helps with placement recommendations): <10K / 10K-100K / 100K+
```

Wait for answers before proceeding.

---

### Step 2 — Ad network setup

#### Google AdSense (Web)

**Step 2a — Add the AdSense script correctly**

For Next.js (App Router), add to `app/layout.tsx`:
```tsx
import Script from 'next/script'

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <head />
      <body>
        {children}
        {/* Load AdSense after page is interactive — afterInteractive avoids render blocking */}
        <Script
          async
          src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=ca-pub-XXXXXXXXXXXXXXXX"
          crossOrigin="anonymous"
          strategy="afterInteractive"
        />
      </body>
    </html>
  )
}
```

For Vanilla HTML (always `async`, never in `<head>` without `async`):
```html
<script async src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=ca-pub-XXXXXXXXXXXXXXXX" crossorigin="anonymous"></script>
```

**Never**: synchronous AdSense script, script in `<head>` without `async`, or loading before consent check.

**Step 2b — Ad unit component**

```tsx
// components/AdUnit.tsx
'use client'
import { useEffect, useRef } from 'react'

interface AdUnitProps {
  slot: string
  format?: 'auto' | 'rectangle' | 'horizontal' | 'vertical'
  style?: React.CSSProperties
  className?: string
}

export function AdUnit({ slot, format = 'auto', style, className }: AdUnitProps) {
  const adRef = useRef<HTMLModElement>(null)
  const pushed = useRef(false)

  useEffect(() => {
    if (pushed.current) return
    pushed.current = true
    try {
      ;(window as any).adsbygoogle = (window as any).adsbygoogle || []
      ;(window as any).adsbygoogle.push({})
    } catch (e) {
      // Ad blocker or script not loaded — fail silently
    }
  }, [])

  return (
    // IMPORTANT: always set min-height to prevent CLS
    <div style={{ minHeight: 90, ...style }} className={className}>
      <ins
        ref={adRef}
        className="adsbygoogle"
        style={{ display: 'block' }}
        data-ad-client="ca-pub-XXXXXXXXXXXXXXXX"
        data-ad-slot={slot}
        data-ad-format={format}
        data-full-width-responsive="true"
      />
    </div>
  )
}
```

---

### Step 3 — Ad placement strategy

Present a placement map based on the site type. Use this scoring guide:

| Placement | CWV Impact | Revenue | Recommendation |
|-----------|-----------|---------|----------------|
| Below header (728×90) | Low if reserved | High | **Use** — reserve 90px |
| Mid-content (336×280) | Low if reserved | Highest | **Use** — best RPM |
| Sidebar (300×250) | None | Medium | Use on desktop only |
| Before footer (320×100) | Low | Low | Use only with reserved space |
| Between list items (every 3-4 items) | Low if reserved | High | Good for feeds |
| Sticky header/footer | Medium | High | Use with caution — mobile UX risk |
| Interstitial (full-page) | High | High | Avoid for SEO — Google penalizes |
| Auto ads | High (unpredictable CLS) | Variable | Disable until layout is stable |

**Generate placement for blog layout:**
```
┌─────────────────────────────────────┐
│ Header (Logo + Nav)                 │
│ ─────────────────────────────────── │
│ [Ad: Leaderboard 728×90, reserved]  │  ← above the fold, reserved space
│ ─────────────────────────────────── │
│ H1 Title                            │
│ Author · Date                       │
│ ─────────────────────────────────── │
│ Article paragraph 1...              │
│ Article paragraph 2...              │
│ Article paragraph 3...              │
│ ─────────────────────────────────── │
│ [Ad: In-content 336×280, reserved]  │  ← highest RPM placement
│ ─────────────────────────────────── │
│ Article paragraph 4...              │
│ ...                                 │
│ ─────────────────────────────────── │
│ [Ad: Below content 320×100]         │  ← lazy loaded
│ ─────────────────────────────────── │
│ Footer                              │
└─────────────────────────────────────┘

Sidebar (desktop only):
│ [Ad: 300×250, sticky after scroll]  │
```

---

### Step 4 — CWV protection

**CLS prevention** (most common ad-related issue):

```tsx
// Always reserve space BEFORE the ad loads
// BAD — causes layout shift:
<AdUnit slot="12345" />

// GOOD — space reserved, no shift:
<div style={{ minHeight: '250px', minWidth: '300px' }}>
  <AdUnit slot="12345" />
</div>
```

**LCP protection** — ads must not delay the LCP element:

```tsx
// Load ad scripts with low priority relative to content
// In Next.js:
<Script strategy="afterInteractive" src="...adsense..." />
// NOT strategy="beforeInteractive"

// For AdSense auto ads, disable until hero image/text has loaded:
// Delay push() call until after window.load or IntersectionObserver fires
```

**Lazy loading for below-fold ads:**

```tsx
// components/LazyAdUnit.tsx
'use client'
import { useEffect, useRef, useState } from 'react'

export function LazyAdUnit({ slot }: { slot: string }) {
  const ref = useRef<HTMLDivElement>(null)
  const [visible, setVisible] = useState(false)

  useEffect(() => {
    const observer = new IntersectionObserver(
      ([entry]) => { if (entry.isIntersecting) setVisible(true) },
      { rootMargin: '200px' }  // load 200px before viewport
    )
    if (ref.current) observer.observe(ref.current)
    return () => observer.disconnect()
  }, [])

  return (
    <div ref={ref} style={{ minHeight: 250 }}>
      {visible && <AdUnit slot={slot} />}
    </div>
  )
}
```

---

### Step 5 — Consent management

#### GDPR (EU visitors)

Ad scripts must not load until the user has given consent. Use a CMP or a lightweight custom gate:

```tsx
// hooks/useConsent.ts
export function useConsent() {
  const [consented, setConsented] = useState<boolean | null>(null)

  useEffect(() => {
    const stored = localStorage.getItem('ad-consent')
    if (stored !== null) setConsented(stored === 'true')
  }, [])

  const accept = () => { localStorage.setItem('ad-consent', 'true'); setConsented(true) }
  const decline = () => { localStorage.setItem('ad-consent', 'false'); setConsented(false) }

  return { consented, accept, decline }
}
```

```tsx
// Wrap ad loading in consent gate
function ConsentGatedAd({ slot }: { slot: string }) {
  const { consented } = useConsent()
  if (consented === null) return <div style={{ minHeight: 90 }} />  // placeholder while pending
  if (!consented) return null  // no ad shown if declined
  return <AdUnit slot={slot} />
}
```

**If using Google's TCF-compatible CMP**: generate the `__tcfapi` listener and load AdSense only after `tcloaded` or `useractioncomplete` events.

#### CCPA (California visitors)

```tsx
// Add "Do Not Sell My Personal Information" link in footer
// Pass non-personalized ads flag when opted out:
const npa = localStorage.getItem('ccpa-optout') === 'true'
// In AdSense tag:
data-npa-on-consent-fail={npa ? 'true' : undefined}
```

---

### Step 6 — Ad blocker handling

```tsx
// utils/detectAdBlocker.ts
export async function isAdBlockerActive(): Promise<boolean> {
  try {
    await fetch('https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js', {
      method: 'HEAD',
      mode: 'no-cors',
    })
    return false
  } catch {
    return true
  }
}
```

Recommended responses to ad blockers (in order of UX friendliness):
1. **Do nothing** — accept the revenue loss, prioritize UX (best for content sites)
2. **Soft message** — "We rely on ads to keep this free. Please consider allowlisting us." (non-blocking)
3. **Metered gate** — allow N free views then show a non-blocking prompt
4. **Hard gate** — require allowlist or subscription (use sparingly, hurts bounce rate)

Generate the soft message component if requested.

---

### Step 7 — Revenue optimization checklist

After setup, present this checklist:

```
Revenue optimization:
  [ ] A/B test ad placements — same slot, different positions on page
  [ ] Enable Auto Ads temporarily to discover high-performing positions, then hardcode them
  [ ] Check RPM by page type in AdSense dashboard — invest in content for high-RPM pages
  [ ] Use Responsive ad units (data-ad-format="auto") — fill rate is higher than fixed sizes
  [ ] Enable page-level ads (sticky ads) on mobile — typically +15-30% RPM
  [ ] Apply for Google Ad Manager if >50K monthly sessions — unlocks header bidding
  [ ] Set up Ad Refresh for long-session pages (dwell time > 3 min)

Performance guard rails:
  [ ] Run Lighthouse — CLS must stay < 0.1 with ads loaded
  [ ] Check LCP with ads — must not regress by more than 200ms
  [ ] Verify no layout shift on slow 3G (Chrome DevTools throttling)
  [ ] Test with ad blocker enabled — page must not break or show empty space > 90px
```

---

### For --audit (existing ad setup)

Read existing ad code and check:

- AdSense script loaded synchronously → CRITICAL (blocks render)
- No `minHeight` on ad containers → CLS risk
- Ad script loaded before consent check → GDPR violation risk
- `(adsbygoogle = window.adsbygoogle || []).push({})` called multiple times per slot → duplicate ads
- Auto Ads enabled globally → CWV unpredictability risk
- AdSense and AdMob publisher IDs hardcoded differently in dev vs prod → revenue attribution error
- No fallback/placeholder when ad is not filled → layout collapse

---

### For --layout (placement suggestion for specific page)

Read the provided page file. Identify:
1. The LCP element (largest above-fold element)
2. Content sections > 3 paragraphs (good mid-content ad candidates)
3. Sidebar presence (desktop-only placements)
4. Scroll depth for high-engagement pages

Output a visual placement map with specific slot recommendations and `minHeight` values.

---

## Multilingual Ad Revenue

When a project serves multiple languages (via `/i18n`), ad revenue varies significantly by locale. These considerations must be factored into ad placement and consent strategy.

### RPM expectations by language market

| Locale | Market | RPM Range | Key considerations |
|--------|--------|-----------|-------------------|
| `en` (US) | United States | $5–50 | Highest CPM. Finance/legal niches can hit $50+. |
| `en` (UK/AU) | UK, Australia | $4–20 | High CPM, English content is shared. |
| `de` | Germany, Austria, Switzerland | $3–15 | Best non-English RPM. Affluent audience. |
| `ja` | Japan | $3–15 | High CPM. Very low ad blocker usage (~10%). |
| `fr` | France + diaspora | $2–8 | Good CPM. Large French-speaking Africa adds volume. |
| `es` (Spain) | Spain | $1–5 | Higher than LATAM. |
| `pt-BR` | Brazil | $0.5–3 | Large audience, growing advertiser market. |
| `es` (LATAM) | Latin America | $0.5–3 | High volume, lower CPM. |
| `zh` | TW/HK/SG diaspora | $1–5 | AdSense doesn't fill well for mainland China IPs. |

**Implication for ad placement:** The same ad unit earns different amounts per impression depending on the visitor's locale. Optimize placement for the `/en` and `/de` routes first — they produce the most revenue per visitor.

### Consent requirements by market

| Market | Requirement | What to implement |
|--------|-------------|-------------------|
| EU (DE, FR, ES, IT, NL...) | GDPR — explicit opt-in required | Consent banner before AdSense loads |
| UK | UK GDPR — same as EU | Same as EU |
| US | CCPA (California) — opt-out | "Do Not Sell" link in footer |
| Brazil | LGPD — similar to GDPR | Consent banner (treat like EU) |
| Japan | APPI — softer than GDPR | Minimal disclosure required, no strict opt-in |
| Taiwan/HK/SG | Varies — generally permissive | Basic disclosure sufficient |

**Practical implementation for a 7-language site:**
- Show the consent banner to all EU/UK/Brazil visitors (detect by IP or `Accept-Language` header).
- Show the CCPA opt-out link to US visitors in the footer.
- For Japan and the Chinese diaspora markets: basic cookie disclosure is sufficient, no blocking consent required.
- Use `vanilla-cookieconsent` — it supports per-region rules in one configuration.

### Ad format performance by language market

| Market | Best performing formats | Notes |
|--------|------------------------|-------|
| US (en) | Leaderboard (728×90), Medium Rectangle (300×250) | Standard desktop formats |
| DE, JP | Medium Rectangle (300×250), Large Rectangle (336×280) | Desktop-heavy audiences |
| ES, PT-BR | Mobile banner (320×50), Medium Rectangle | More mobile traffic |
| ZH (TW/HK/SG) | Medium Rectangle, Responsive | Mobile-first audience |

### AdSense language configuration

AdSense auto-detects the page language and serves relevant ads. To maximize fill rate:
- Set `<html lang="de">` correctly — AdSense reads this to target German-language ads.
- Don't mix languages on a page — a German page with English content confuses the ad targeting.
- Each locale must have its content genuinely in that language (not English fallback) — otherwise AdSense serves lower-value cross-language ads.

### Revenue-ordered ad optimization priority

When optimizing ad placements across locales, work in this order:
1. `/en` routes (US traffic) — highest RPM, optimize first
2. `/de` routes — best non-English RPM
3. `/ja` routes — high CPM, low ad blocker rate
4. `/fr` routes — good CPM
5. `/es`, `/pt-BR`, `/zh` — optimize for volume, not RPM

---

## Honesty Rules

- Never recommend interstitial or full-screen ads on content pages — Google penalizes them in Search.
- Never load ad scripts before GDPR consent for EU visitors.
- Never skip `minHeight` on ad containers — CLS from ads is one of the most common SEO issues.
- Always tell the user their AdSense publisher ID needs to replace the placeholder `ca-pub-XXXXXXXXXXXXXXXX`.
- Revenue estimates are illustrative only — actual RPM depends on niche, geography, and traffic quality.
- Chinese mainland (CN) visitors will see very low AdSense fill rates — the revenue comes from the diaspora, not mainland China.

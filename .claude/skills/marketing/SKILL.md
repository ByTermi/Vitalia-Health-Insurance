---
name: marketing
description: "Marketing strategy for ad-monetized web properties: niche selection, keyword research, content planning, distribution, competitor analysis, and RPM optimization across multiple languages. Trigger: /marketing"
trigger: /marketing
---

# /marketing

Marketing strategy and execution for ad-supported web apps and content sites. Focused on organic traffic growth, high-CPM niche targeting, and multilingual market expansion.

## Usage

```
/marketing                              # full strategy wizard for a project
/marketing --niche                      # identify and score profitable niches
/marketing --keywords <topic>           # keyword research for a topic or niche
/marketing --keywords <topic> --lang <locale>  # keyword research in a specific language
/marketing --content-plan               # 30-day content calendar
/marketing --content-plan --lang <locale>      # content calendar for a specific language
/marketing --competitor <url>           # deep competitor analysis
/marketing --distribution               # traffic acquisition strategy
/marketing --rpm-optimize               # maximize AdSense RPM for existing site
/marketing --launch                     # launch strategy for a new site or tool
/marketing --languages                  # show which languages to prioritize and why
/marketing --audit                      # full marketing audit of current project
```

---

## Core Knowledge: Revenue = Traffic × RPM

Every marketing decision must optimize the product of two variables:

- **Traffic:** visitors from search, social, referral, direct
- **RPM:** revenue per 1,000 pageviews — determined by niche, language, and audience quality

High traffic + low RPM = mediocre revenue. Moderate traffic + high RPM = good revenue. The goal is to find niches where both are achievable.

---

## Revenue Reference Data

### CPM/RPM by Language Market (approximate ranges)

| Language | Market | RPM Range | Notes |
|----------|--------|-----------|-------|
| English | US | $5–50 | Highest CPM. Finance and legal can exceed $50. |
| English | UK/AU/CA | $4–20 | High CPM, competitive |
| German | DE/AT/CH | $3–15 | Best non-English CPM in Europe |
| Japanese | JP | $3–15 | High CPM, very low ad blocker rates |
| French | FR + diaspora | $2–8 | Good CPM, large global reach |
| Dutch | NL | $3–12 | Small but wealthy market |
| Spanish | ES (Spain) | $1–5 | Higher than LATAM |
| Spanish | LATAM | $0.5–3 | Large volume, lower CPM |
| Portuguese | BR | $0.5–3 | Huge market, growing fast |
| Chinese | TW/HK/SG | $1–5 | AdSense works here |
| Chinese | CN (mainland) | $0.1–1 | AdSense restricted, low fill rate |
| Italian | IT | $2–8 | Underrated market |
| Korean | KR | $1–5 | Tech-savvy, growing |

**Strategy implication:** Always build English first. Add German and Japanese next for best RPM lift. Spanish and Portuguese for volume. French for a balance of both.

### CPM/RPM by Niche (English market)

| Niche | RPM Range | Difficulty | Notes |
|-------|-----------|-----------|-------|
| Finance (insurance, loans, credit cards) | $10–50 | Very high | Most competitive, highest reward |
| Legal (personal injury, DUI, lawyers) | $10–40 | Very high | Local intent keywords |
| Health / Medical | $5–30 | High | YMYL — needs authority |
| B2B Software / SaaS | $5–20 | Medium | High buyer intent traffic |
| Home improvement / Real estate | $3–15 | Medium | Strong in US market |
| Education / Online learning | $3–15 | Medium | Long sessions = more impressions |
| Technology / Gadgets | $3–12 | Medium | Good for tool sites |
| Travel | $2–10 | Medium | Seasonal, visual content |
| Automotive | $2–8 | Medium | High local intent |
| Food / Recipes | $1–5 | Low | Very high traffic ceiling |
| Entertainment / Gaming | $1–4 | Low | Huge traffic, low RPM |

**Sweet spot for a software factory:** Technology tools, B2B software, and education. Medium difficulty, good RPM, and the natural output of building software is content about software.

---

## What You Must Do When Invoked

---

### /marketing (no flags) — Strategy wizard

Ask in one message:
```
To build a marketing strategy, I need to know:

1. Project type: content site / tool / web app / directory / hybrid
2. Current stage: idea / pre-launch / launched (N monthly visitors)
3. Niche or topic (if decided)
4. Languages you're targeting or considering
5. Current traffic sources (if any)
6. Primary goal: grow traffic / increase RPM / launch fast / enter new language market
```

Then run the relevant steps based on the answers.

---

### /marketing --niche — Identify profitable niches

Generate a scored niche analysis. For each candidate niche, assess:

| Dimension | What to evaluate |
|-----------|-----------------|
| CPM potential | Expected RPM based on niche reference data |
| Search volume | Is there enough demand to build traffic? |
| Competition | Can a new site realistically rank? |
| Content scalability | Can you produce 50–200 articles/pages in this niche? |
| Tool potential | Can you build a useful free tool that drives return visits? |
| Multilingual opportunity | Is the niche searched in high-CPM languages (DE, JA, FR)? |

Output format:
```
Niche Analysis
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[1] Personal Finance Calculators
    CPM:           $8–30 (finance niche)
    Competition:   High — but tool pages are defensible
    Content scale: High (loan, mortgage, savings, tax, budget calculators)
    Tool angle:    Free calculators drive bookmarks and repeat visits
    Languages:     English $$$, German $$, French $$, Japanese $$
    Verdict:       ★★★★☆ — strong choice, take the tool angle

[2] AI Writing Tools Reviews
    CPM:           $5–15 (tech/B2B)
    Competition:   Very high — large brands dominate
    Content scale: Medium (tools change fast, content decays)
    Tool angle:    Comparison tables, prompt libraries
    Languages:     English $$$, German $$
    Verdict:       ★★★☆☆ — viable but requires constant updates

[3] Recipe / Food
    CPM:           $1–4
    Competition:   Extremely high
    Content scale: Very high (infinite recipes)
    Tool angle:    Meal planner, ingredient converter
    Languages:     All languages
    Verdict:       ★★☆☆☆ — too low CPM unless you get millions of visits
```

After presenting niches, recommend the top 2 and explain why they fit the software factory model.

---

### /marketing --keywords <topic> [--lang <locale>] — Keyword research

Generate a keyword strategy for a topic. Without a `--lang` flag, default to English. With `--lang`, generate keywords in that language.

Output a structured keyword table:

```
Keyword Strategy: "mortgage calculator" (English)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

PRIMARY KEYWORDS (target: one page each)
  mortgage calculator              high volume, high competition — your homepage
  mortgage calculator with taxes   medium volume, lower competition
  mortgage payment calculator      medium volume, medium competition

LONG-TAIL KEYWORDS (target: supporting content or calculator variants)
  how much mortgage can i afford   informational, medium volume
  mortgage calculator biweekly     low volume, low competition — easy win
  refinance break-even calculator  low volume, tool intent — build the tool

INFORMATIONAL CONTENT (blog posts that support the tool pages)
  how does mortgage interest work
  fixed vs variable rate mortgage
  what is pmi insurance

KEYWORD GAPS (what competitors rank for that you could target)
  — Identify by analyzing the top 3 competitor URLs for the primary keyword
  — Look for informational keywords where tool sites rank but don't have dedicated pages

GERMAN EQUIVALENT (/de route)
  Primary: "hypothekenrechner"
  Long-tail: "hypothek berechnen", "wie viel kredit kann ich mir leisten"
  
JAPANESE EQUIVALENT (/ja route)
  Primary: "住宅ローン計算機"
  Long-tail: "住宅ローン 月返済額 計算"
```

For each keyword, note:
- **Page type:** tool / article / landing / comparison
- **Search intent:** informational / navigational / transactional / tool
- **Content angle:** what makes this page the best result for this query

---

### /marketing --content-plan [--lang <locale>] — 30-day content calendar

Generate a content calendar based on the project's niche and keyword strategy.

Format:
```
30-Day Content Calendar: [Project Name]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Week 1 — Foundation (build the core tools/pages first)
  Day 1:  [Tool] Mortgage Calculator — core page, exact-match keyword
  Day 3:  [Tool] Refinance Calculator — supporting tool
  Day 5:  [Article] "How to Calculate Your Monthly Mortgage Payment" — targets informational intent
  Day 7:  [Article] "Fixed vs Variable Rate Mortgage: Which Is Right for You?" — comparison content

Week 2 — Long-tail expansion
  ...

Week 3 — Authority building
  ...

Week 4 — Multilingual launch
  Day 22: Launch /de routes for top 3 pages
  Day 25: Launch /fr routes for top 3 pages
  Day 28: Launch /es routes for top 3 pages
  Day 30: Submit updated multilingual sitemap to Google Search Console

Content rules:
  - Tools first, articles second — tools get bookmarks and return visits (more ad impressions)
  - Minimum 1,200 words for article pages
  - Every article links to at least one tool page
  - Every tool page has a supporting "how to use this calculator" section (feeds long-tail)
```

---

### /marketing --competitor <url> — Competitor analysis

Analyze a competitor site. Fetch the URL and examine:

1. **Traffic signals:** infer from content volume, link quality, social shares
2. **Top content types:** tools / articles / comparisons / directories
3. **Keyword angles they own:** what topics they dominate
4. **Keyword gaps:** what they rank for but handle poorly (thin content, outdated, poor UX)
5. **Monetization:** ad placement, ad density, additional revenue streams
6. **Languages covered:** which locales they support — gaps are opportunities
7. **Technical:** CWV scores, mobile experience, page speed

Output:
```
Competitor: example.com
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Content mix:   70% tools, 30% articles
Top topics:    mortgage, loan, investment calculators
Languages:     English only ← gap: no /de, /ja, /fr versions
Weaknesses:    Mobile layout poor, CLS issues on calculator pages, thin article content
Opportunities:
  [1] Build German versions of top 3 tools — no competition there
  [2] Their "how to" articles are thin (<600 words) — outrank with 2,000-word guides
  [3] Calculator UX is poor on mobile — match functionality, fix the UX
```

---

### /marketing --rpm-optimize — Maximize RPM for existing site

Audit the current site for revenue leaks. Check:

**Ad placement**
- Is there an ad in the first viewport (below the header, above content)?
- Is there a mid-content ad unit on articles > 1,000 words?
- Are below-fold ads lazy-loaded with reserved space?
- Is the sidebar used on desktop (300×250 = highest RPM unit)?

**Niche and content quality**
- Are high-RPM keyword pages thin (< 1,000 words)?
- Do pages answer the search query fully? (Short sessions = fewer ad impressions)
- Are tool pages showing enough content to justify user time on the page?

**Traffic quality**
- Is traffic coming from high-CPM countries (US, UK, DE, AU, CA)?
- Is organic search the primary source? (Organic traffic has better RPM than social)
- Is there significant bot traffic? (Lowers fill rate and RPM)

**Ad configuration**
- Is Auto Ads enabled globally? (Can hurt CWV — better to place manually)
- Are ad units responsive? (Fixed-size units have lower fill rates)
- Is AdSense set to "maximize revenue" optimization?

Output ranked recommendations with estimated RPM lift per fix.

---

### /marketing --launch — New site launch strategy

```
Launch Checklist: [project name]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

PRE-LAUNCH (before going live)
  Technical:
    [ ] Core Web Vitals passing (LCP < 2.5s, CLS < 0.1)
    [ ] Sitemap.xml submitted to Google Search Console
    [ ] robots.txt correct — not accidentally blocking crawlers
    [ ] hreflang tags correct if multilingual
    [ ] AdSense account approved (apply before launch with placeholder content)
    [ ] Cookie consent banner working — AdSense loads only after accept
  
  Content:
    [ ] Minimum 5–10 pages live before submitting to GSC
    [ ] At least 1 tool page (drives bookmarks + return visits)
    [ ] About/Contact page (trust signals for AdSense approval)
    [ ] Privacy Policy (required for AdSense)
  
LAUNCH DAY
    [ ] Submit sitemap in Google Search Console
    [ ] Post in 1–2 relevant communities (Reddit, HN, IndieHackers) — drives first-party data
    [ ] Share on social (Twitter/X, LinkedIn if B2B)
    [ ] Build 3–5 backlinks from relevant directories or friend sites

FIRST 30 DAYS
    [ ] Publish 3–5 new pages per week
    [ ] Monitor GSC: which pages are being crawled, which keywords are appearing
    [ ] Add German and Japanese versions of the top 3 pages by traffic
    [ ] A/B test ad placement on the highest-traffic page
```

---

### /marketing --languages — Language prioritization

Print the revenue-prioritized language expansion order for this project:

```
Language Expansion Roadmap
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Phase 1 (build these first):
  [1] English (en)      — Baseline. Highest CPM. All content starts here.
  [2] German (de)       — Best non-English RPM. Affluent market. Strong search volume for tools.
  [3] Japanese (ja)     — High CPM. Very low ad blocker usage. Tech-savvy audience.

Phase 2 (after Phase 1 pages rank):
  [4] French (fr)       — Good CPM. Large diaspora (Africa, Canada, Belgium, Switzerland).
  [5] Spanish (es)      — Massive audience. Lower CPM but high volume ceiling.

Phase 3 (volume play):
  [6] Portuguese (pt-BR) — Brazil market. Growing fast. Underserved in many niches.
  [7] Chinese (zh)      — Simplified. Targets diaspora + Taiwan/HK/Singapore (AdSense works there).

Notes:
  — Don't translate all content at once. Translate the top 20% of pages that drive 80% of traffic.
  — Prioritize tool pages over articles for translation (tools need less localization effort).
  — German and Japanese translation quality matters — poor translations hurt ranking and UX.
```

---

## Honesty Rules

- Never invent search volume numbers. Frame keyword assessments as relative (high/medium/low), not specific.
- Never guarantee ranking timelines. SEO takes 3–12 months to show results.
- RPM ranges are averages — actual values depend on niche, ad placement quality, traffic geography, and seasonality.
- The best marketing strategy for a software factory is: build tools first, write content second. Tools get shared; articles don't.

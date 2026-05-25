---
name: research
description: "Research trending topics, keywords, and content opportunities using live web data. Pulls from Reddit, Hacker News, Google Trends, and web search. Supports multilingual research per target market. Trigger: /research"
trigger: /research
---

# /research

Live content research using public web APIs and search. Finds what people are actually searching and discussing right now — then turns that into content opportunities ranked by traffic and revenue potential.

## Usage

```
/research <niche>                          # full research report for a niche
/research <niche> --lang <locale>          # research in a specific language market
/research --trends <keyword>               # Google Trends data for a keyword
/research --trends <keyword> --geo <code>  # trends for a specific country (US, DE, ES, JP...)
/research --reddit <subreddit>             # top posts this week in a subreddit
/research --reddit <query>                 # search Reddit for a topic
/research --hn                             # top Hacker News stories right now
/research --ideas <niche>                  # generate content ideas from research
/research --gap <url>                      # find content gaps vs a competitor
/research --questions <topic>              # what questions people ask about a topic
/research --lang-compare <keyword>         # compare search interest across all 7 locales
```

---

## Data Sources

These are free, no API key required. Use WebFetch or the `fetch` MCP to pull data.

| Source | URL pattern | Best for |
|--------|-------------|---------|
| Reddit JSON | `reddit.com/r/{sub}/top.json?t=week&limit=25` | Community trending topics |
| Reddit search | `reddit.com/search.json?q={query}&sort=top&t=month` | Topic-specific discussions |
| Hacker News | `hacker-news.firebaseio.com/v0/topstories.json` | Tech topics |
| HN item | `hacker-news.firebaseio.com/v0/item/{id}.json` | Story details |
| Google Trends | `trends.google.com/trends/explore?q={keyword}&geo={code}` | Search trend direction |
| AnswerThePublic-style | WebSearch: `site:quora.com {topic}` | Questions people ask |
| People Also Ask | WebSearch: `{keyword} questions people ask` | FAQ content opportunities |

---

## What You Must Do When Invoked

Always use WebFetch, WebSearch, or the `fetch` MCP to pull LIVE data. Never invent or estimate trend data — if a source is unreachable, say so and use an alternative.

---

### /research <niche> — Full research report

Pull from multiple sources and synthesize. Steps:

**Step 1 — Reddit scan**

Identify 2-3 relevant subreddits for the niche. Fetch top posts for each:
```
GET https://www.reddit.com/r/{subreddit}/top.json?t=week&limit=25
Headers: User-Agent: Mozilla/5.0 (research bot)
```

Extract from response: post titles, scores (upvotes), number of comments, flair. High-score posts = proven audience interest.

**Step 2 — Google Trends direction**

Fetch the Google Trends explore page for the main keyword to get the trend direction (rising/stable/declining):
```
GET https://trends.google.com/trends/explore?q={keyword}&geo=US
```

Also search: `site:trends.google.com "{niche}" trending` to find related rising queries.

**Step 3 — Search for "People Also Ask"**

Use WebSearch: `{niche} most searched questions` and `{niche} frequently asked questions`

Extract: what questions appear repeatedly across sources = content gaps to fill.

**Step 4 — Synthesize into opportunities**

Format output:

```
Research Report: [Niche]
Date: [today] | Sources: Reddit, Google Trends, Web Search
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

TRENDING RIGHT NOW (from Reddit + search)
  [1] "How to calculate mortgage with variable rate" — 2.4k upvotes this week
      Angle: tool + explainer article
      Keyword opportunity: "variable rate mortgage calculator"
      
  [2] "Fed rate hike — what it means for my mortgage" — 1.8k upvotes
      Angle: timely explainer, links to calculator
      Keyword: "impact of fed rate increase on mortgage payments"

RISING SEARCHES (Google Trends signals)
  ↑ "home equity loan calculator" — rising 45% MoM
  ↑ "refinance break-even point" — rising 30% MoM
  → "mortgage calculator" — stable
  ↓ "ARM mortgage" — declining 10% MoM

QUESTIONS PEOPLE ASK
  "How do I calculate my mortgage payment manually?"
  "What is a good mortgage rate right now?"
  "How much can I borrow based on salary?"
  "Is it better to pay extra on principal?"

CONTENT OPPORTUNITIES (ranked by traffic + RPM)
  [1] Tool: Variable-rate mortgage calculator — trending + high CPM + low competition
  [2] Article: "Fed rate hike mortgage calculator" — timely, links to tool
  [3] Tool: Home equity loan calculator — rising fast, no dominant result
  [4] Article: "How much mortgage can I afford on [salary]?" — FAQ, high volume

SUBREDDITS ENGAGED
  r/personalfinance   — 1.2M members, very active on mortgage topics
  r/FirstTimeHomeBuyer — 200K members, tool-friendly audience
  r/realestate        — 800K members, more general

Next: run /research --ideas [niche] to get 20 specific content ideas, or /i18n --translate to start German/Japanese versions of top opportunities.
```

---

### /research --trends <keyword> [--geo <code>] — Google Trends

Fetch Google Trends for the keyword. Countries: US, DE, ES, JP, FR, GB, BR, etc.

```
WebFetch: https://trends.google.com/trends/explore?q={keyword}&geo={country_code}
```

Also search: `"{keyword}" google trends {year}` to find trend reports from SEO publications (Search Engine Journal, Moz, etc. often publish Trends data in article form).

Report:
```
Google Trends: "mortgage calculator"
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Overall trend: Stable (score ~75/100 consistently)
Peak month:    January (tax season + new year resolutions)
Low month:     July (summer)

Related rising queries:
  "mortgage calculator with taxes and insurance" — breakout (+250%)
  "mortgage payment calculator biweekly" — +45%
  "how much mortgage can I afford" — +30%

Related top queries:
  "mortgage calculator" — 100
  "home loan calculator" — 65
  "monthly payment calculator" — 40

Country comparison:
  US: 100 | UK: 72 | CA: 68 | AU: 61 | DE: 35
  → English-speaking markets dominate. German market has room.
```

---

### /research --reddit <subreddit or query> — Reddit trending

```
# Top posts in a subreddit
GET https://www.reddit.com/r/{subreddit}/top.json?t=week&limit=25
  → sort by score, extract: title, score, num_comments, url, flair

# Search across Reddit
GET https://www.reddit.com/search.json?q={query}&sort=top&t=month&limit=25
  → extract: title, score, subreddit, num_comments
```

Format output as a ranked table with titles, scores, and the content angle each suggests.

---

### /research --hn — Hacker News top stories

```
GET https://hacker-news.firebaseio.com/v0/topstories.json
→ returns array of item IDs

# Fetch details for top 20
GET https://hacker-news.firebaseio.com/v0/item/{id}.json
→ extract: title, score, url, descendants (comment count)
```

Filter for items relevant to the current project's niche. Present the top 10 with titles and scores.

Useful for: identifying tech topics with high developer interest that could become tool pages.

---

### /research --ideas <niche> — Generate content ideas

After pulling research data (or if called standalone, run the research first), generate 20 specific content ideas:

```
Content Ideas: [Niche]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

TOOLS (build these first — drive return visits)
  [1] Variable rate mortgage calculator — calculate payments as rates change
  [2] Mortgage affordability calculator — "how much can I borrow on X salary"
  [3] Refinance break-even calculator — when does refinancing pay off?
  [4] Extra payment calculator — how much interest does one extra payment save?
  [5] Rent vs buy calculator — compare total costs over N years

PILLAR ARTICLES (long-form, target competitive keywords)
  [6] "Complete Guide to Mortgage Types in 2025" — 3,000 words
  [7] "How to Get the Best Mortgage Rate" — high CPM keyword
  [8] "First-Time Buyer Mortgage Guide" — high search volume

QUICK ANSWERS (target question keywords, short pages, fast to produce)
  [9] "What is a good mortgage interest rate?"
  [10] "How is mortgage interest calculated?"
  [11] "Can I get a mortgage with a 600 credit score?"
  [12] "What happens if I miss a mortgage payment?"

COMPARISON PAGES (comparison intent = high CPM)
  [13] "15-year vs 30-year mortgage: which is better?"
  [14] "Fixed vs adjustable-rate mortgage explained"
  [15] "Conventional vs FHA loan: pros and cons"

TIMELY / NEWS-DRIVEN (lower evergreen value but spike traffic)
  [16] "What today's Fed rate means for your mortgage"
  [17] "Mortgage rates forecast [current year]"

MULTILINGUAL OPPORTUNITIES (high value, low competition)
  [18] "Hypothekenrechner" (DE) — German mortgage calculator
  [19] "住宅ローン計算機" (JA) — Japanese mortgage calculator
  [20] "Calculadora hipotecaria" (ES) — Spanish mortgage calculator
  
Priority order: [1] → [3] → [2] → [18] → [19] → [6]
```

---

### /research --questions <topic> — What people ask

Use WebSearch to find the most common questions:

Searches to run:
1. `{topic} site:quora.com` — questions with answers
2. `{topic} site:reddit.com questions` — community questions
3. `"{topic}" "how do I"` — how-to intent
4. `"{topic}" "what is"` — informational intent
5. `"{topic}" "vs"` — comparison intent

Compile into a list of 15-20 questions, grouped by intent. These become:
- FAQ sections on existing pages
- Standalone short-answer pages (good for long-tail traffic)
- Structured data (FAQ schema = rich results in Google)

---

### /research --lang-compare <keyword> — Cross-locale comparison

Research the same keyword across all 7 target locales to identify which markets are underserved:

For each locale, search: `{keyword in that language} site:google.com`

Output:
```
Keyword comparison: "mortgage calculator"
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Locale  | Local keyword              | Competition | Opportunity
--------|---------------------------|-------------|------------
en      | mortgage calculator        | Very high   | Baseline
de      | Hypothekenrechner          | Medium      | ★★★★ Build now
ja      | 住宅ローン計算機             | Low         | ★★★★★ Priority
fr      | calculateur hypothèque     | Medium      | ★★★☆
es      | calculadora hipotecaria    | High        | ★★☆☆
pt-BR   | calculadora de financiamento | Low       | ★★★★ Low competition
zh      | 房贷计算器                  | Low (diaspora) | ★★★

Recommendation: Build /ja and /pt-BR versions immediately — low competition, decent CPM.
```

---

### /research --gap <url> — Competitor content gap

Fetch the competitor's sitemap or crawl their blog index. Identify:
1. Topics they cover well (high post count, good structure)
2. Topics they mention but don't have dedicated pages for
3. Questions in their comments they don't answer
4. Languages they don't support

```
Content Gap: example.com vs your site
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
They have: 45 pages on mortgage calculators
They lack:
  - Variable rate mortgage calculator (only fixed)
  - Biweekly payment calculator
  - Rent vs buy tool
  - Any non-English content (opportunity)
  
Their weak pages (thin content, could outrank):
  - "What is PMI?" — 200 words, no examples, outrank with 1,500 words + calculator
  - "Mortgage glossary" — no search intent alignment, generic content
```

---

## Proactive research triggers

Claude should offer to run research when:
- Starting a new content site or blog project
- User mentions they need article or tool ideas
- A project's ideas.md is empty or stale
- User asks "what should I write about?"

Offer: "Want me to research trending topics in [niche]? I can pull from Reddit and Google Trends right now."

---

## Honesty Rules

- Always state the data source and date for every claim. Research data expires fast.
- Never invent Reddit post scores, upvote counts, or trend numbers.
- If a source is unreachable (Reddit blocks, Trends changes format), say so and use an alternative.
- Trend direction (rising/falling) is more reliable than absolute numbers.
- Competition estimates are qualitative — actual difficulty requires paid tools (Ahrefs, SEMrush).

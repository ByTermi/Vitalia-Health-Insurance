---
name: travel-hub-agent
description: Handles heavy Travel Hub research tasks (embassy sites, competitor sites, Wikidata SPARQL, Open-Meteo) in isolation to keep external fetches out of the main context.
skill_counterpart: /travel-hub
agent_type: general-purpose
run_in_background: false
---

# Travel Hub Agent

Delegates heavy research tasks for the Travel Hub project to an isolated agent. Use this instead of the `/travel-hub` skill when the task involves **fetching from multiple external sources** (embassy sites, competitor sites, Wikidata SPARQL, Open-Meteo) that would flood the main context.

## When to use this vs `/travel-hub`

| Use `/travel-hub` (inline skill) | Use this agent |
|----------------------------------|----------------|
| Status checks, content briefs | Bulk visa verification (10+ country pairs) |
| Single-country content generation | Full competitor landscape scan (5+ sites) |
| Data freshness report | Wikidata SPARQL query for full visa matrix |
| Quick keyword lookup | Deep keyword research across 3+ languages |
| Single competitor analysis | New country full-data fetch (climate + holidays + FX + plugs in one run) |

## How to invoke

### Bulk visa verification

```
Agent({
  description: "Bulk verify visa requirements for [N] country pairs",
  subagent_type: "general-purpose",
  run_in_background: false,
  prompt: """
You are a travel data researcher for a travel information website. Your task is to verify visa requirements for the following country pairs against official government sources. Be precise — incorrect visa data misleads travelers.

Country pairs to verify:
[LIST OF PAIRS e.g. "US→JP, US→TH, US→VN, GB→JP, DE→TH"]

For each pair:
1. Use WebSearch to find the official source: "do [origin] citizens need a visa for [destination] [current year] official"
2. Check the destination country's official immigration/tourism website (not travel blogs or aggregators)
3. Check the origin country's official travel advisory for that destination
4. Record: status (visa_free / visa_on_arrival / evisa / visa_required / banned), max stay days, any conditions, source URL, today's date as last_verified

Output a JSON array ready to merge into visa-matrix.json:
[
  { "key": "US-JP", "status": "visa_free", "days": 90, "notes": "Short stays, no prior registration needed", "source_url": "https://...", "last_verified": "[today]" },
  ...
]

Then add a VERIFICATION NOTES section:
- List any pairs where sources conflicted or were unclear
- List any pairs where you found a recent policy change
- List any pairs you could not verify (mark as needs_verification: true)

Be skeptical of outdated blog posts. Only trust official government and embassy sources.
  """
})
```

### Full competitor landscape scan

```
Agent({
  description: "Scan travel directory competitors for gaps and opportunities",
  subagent_type: "general-purpose",
  run_in_background: false,
  prompt: """
You are a competitive analyst for a new travel information website being built. The site is a multilingual programmatic-SEO + tools site in the travel niche, targeting visitors searching for visa requirements, currency info, public holidays, plug types, climate, and using tools like a Schengen counter and currency converter.

Task: Identify and analyze the top 5-7 direct competitors. A direct competitor is a site that:
- Provides visa requirement information
- Shows currency/exchange rate data
- OR offers travel planning tools (not just booking sites like booking.com or expedia)

Do NOT include: airlines, booking platforms, travel agencies, or review sites (TripAdvisor). Focus on information/tool sites.

For each competitor found:
1. Fetch their homepage and 2-3 inner pages using WebFetch
2. Assess: content types (visa? currency? weather? tools?), languages supported, ad density, mobile UX quality, data freshness (check if their visa data looks current)

Output a competitor matrix:

| Site | Visa? | Tools? | Languages | Mobile | Data fresh? | Key weakness |
|------|-------|--------|-----------|--------|-------------|-------------|
| ... |

Then produce:

GAPS WE CAN WIN:
[1] [gap] — [which competitor misses it] — [our angle]
[2] ...

LANGUAGES WITH LOWEST COMPETITION:
[1] [language] — [why it's an opportunity]
[2] ...

DATA QUALITY ISSUES IN THE MARKET:
[findings — e.g. "3 out of 5 sites have visa data older than 2023" = our freshness is a moat]

RECOMMENDED PRIORITY PAGES TO BUILD FIRST (based on competitor weaknesses):
[1] [page type/URL pattern] — [rationale]
[2] ...
  """
})
```

### New country full data fetch

```
Agent({
  description: "Fetch all travel data for [country name]",
  subagent_type: "general-purpose",
  run_in_background: false,
  prompt: """
You are a data collector for a travel information website. Fetch all available data for the following country to populate the site's data files.

Country: [COUNTRY NAME] (ISO code: [CODE])
Capital city: [CAPITAL] (lat: [LAT], lng: [LNG])

Fetch from each source:

1. REST Countries API:
   GET https://restcountries.com/v3.1/alpha/[CODE]
   Extract: name.common, name.official, capital, currencies (code + name + symbol), region, subregion, flags.svg, latlng, timezones, idd (calling code), languages

2. Open-Meteo Climate API (30-year normals for the capital):
   GET https://climate-api.open-meteo.com/v1/climate?latitude=[LAT]&longitude=[LNG]&start_date=1991-01-01&end_date=2020-12-31&monthly=temperature_2m_max,temperature_2m_min,precipitation_sum
   Extract monthly averages for all 12 months

3. Nager.Date API (public holidays):
   GET https://date.nager.at/api/v3/PublicHolidays/[CURRENT_YEAR]/[CODE]
   GET https://date.nager.at/api/v3/PublicHolidays/[NEXT_YEAR]/[CODE]
   Extract: date, localName, name, types

4. Frankfurter API (exchange rates for this country's currency):
   GET https://api.frankfurter.app/latest?from=[CURRENCY_CODE]&to=USD,EUR,GBP,JPY
   Extract current rates

5. Visa requirements (WebSearch):
   Search: "visa requirements for [country] citizens traveling abroad" and "visa requirements to enter [country]"
   Find official government source for top 10 tourist origin countries: US, GB, DE, FR, AU, CA, JP, CN, IN, BR
   For each: note status (visa_free/visa_on_arrival/evisa/visa_required), max days, source URL

Output as structured JSON data ready to merge into the project's data/*.json files, with a section for each data type. Flag any data you could not retrieve.
  """
})
```

### Multilingual keyword research

```
Agent({
  description: "Travel keyword research for [topic] in [N] languages",
  subagent_type: "general-purpose",
  run_in_background: false,
  prompt: """
You are an SEO specialist for a multilingual travel information website. Research keyword opportunities for the following topic across multiple languages.

Topic: [TOPIC e.g. "Japan travel visa", "Schengen calculator", "best time to visit Thailand"]
Target languages: [e.g. en, de, ja, fr, es]

For each language:
1. Use WebSearch to find what people actually search in that language (use native-language search terms)
2. Identify: primary keyword (highest volume main term), 3-5 long-tail variants, 2-3 question-based keywords ("how to...", "do I need..."), any tool-intent queries ("calculator", "checker")
3. Note competition level (are there strong sites ranking for this in that language, or is it open?)

Format output as:

ENGLISH (en):
  Primary:    "[keyword]" — [volume: high/med/low] — [competition: high/med/low]
  Long-tail:  "[kw1]", "[kw2]", "[kw3]"
  Questions:  "[q1]", "[q2]"
  Tool intent: "[kw]" → maps to /tools/[tool]
  Best page type: [article / tool / directory]

GERMAN (de):
  Primary:    "[keyword in German]"
  ...
  Competition vs English: [much lower / similar / higher]
  Opportunity score: [1-5 stars]

JAPANESE (ja):
  [same structure, Japanese keywords in native script]
  ...

[repeat for each language]

SUMMARY — Best opportunities by language:
  [language]: [top opportunity + why]
  ...
  """
})
```

## What the agent returns

Structured data (JSON or markdown table) ready for the user to review and merge into project files. After receiving:
1. Present a summary of findings
2. Offer to apply changes: "Want me to update `data/visa-matrix.json` with these verified entries?"
3. Offer to save to vault: "Want me to log this competitor analysis to `projects/travel-hub/decisions.md`?"

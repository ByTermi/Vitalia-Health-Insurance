---
name: verify
description: "Assess the reliability and credibility of blog posts, articles, and web content. Checks source reputation, citation quality, claim corroboration, and bias signals. Returns a reliability verdict and recommendation on whether the information can be used. Trigger: /verify"
trigger: /verify
---

# /verify

Content reliability assessment. Fetches an article, extracts its key claims, then cross-references them against authoritative sources to determine whether the information is trustworthy enough to use as research material, cite in content, or build upon.

## Usage

```
/verify <url>                      # assess reliability of a specific article
/verify --text "<paste text>"      # assess reliability of pasted content
/verify --batch <url1> <url2> ...  # assess multiple sources at once
/verify --compare <url1> <url2>    # compare two sources on the same topic
/verify --sources <topic>          # find reliable sources on a topic
```

---

## What You Must Do When Invoked

Always fetch and read the actual content. Never estimate reliability without reading the source. Use WebFetch to retrieve the URL, then WebSearch to cross-reference key claims.

---

## Reliability Dimensions

Score each dimension 0–10. Final score = weighted average.

| Dimension | Weight | What to check |
|-----------|--------|---------------|
| Source credibility | 25% | Is the domain known? Editorial standards? Academic/government/established media? |
| Citation quality | 20% | Are claims cited? Do citations point to primary sources? Are sources themselves reliable? |
| Claim corroboration | 25% | Do other independent, reliable sources confirm the key claims? |
| Author credentials | 10% | Is the author identified? Do they have relevant expertise? |
| Recency | 10% | Is the information current? Outdated data can be factually wrong even if originally correct. |
| Bias indicators | 10% | Emotional language, one-sided framing, sponsored content, conflicts of interest? |

---

## Reliability Score → Verdict

| Score | Verdict | Recommendation |
|-------|---------|----------------|
| 8.0–10 | ✅ Reliable | Safe to use as a source. Cite with confidence. |
| 6.0–7.9 | ⚠️ Use with caution | Verify specific claims independently before using. |
| 4.0–5.9 | 🔶 Questionable | Key claims need corroboration from better sources. |
| 0–3.9 | ❌ Unreliable | Do not use. Find an alternative source. |

---

### /verify <url> — Single article assessment

**Step 1 — Fetch and read the content**

```
WebFetch: <url>
```

Extract:
- Publication name and URL domain
- Author name and bio/credentials (if present)
- Publication date
- All key factual claims (not opinions or analysis)
- Citations and linked sources
- Any sponsorship disclosures, affiliate disclaimers, or "partner content" labels

**Step 2 — Assess source credibility**

Run a WebSearch: `"<domain>" reputation OR credibility OR "fact check"`

Also check:
- Is the domain a known news organization, academic institution, or government body?
- Does it have an About/Editorial page describing standards?
- Has it appeared in media bias databases (AllSides, MediaBias/FactCheck)?

**Step 3 — Check citation quality**

For each cited source:
- Follow the link (WebFetch) or identify the publication
- Is it a primary source (study, official data, government report) or another article?
- Is the citation used accurately — does it actually support the claim?

Red flags:
- Claims without any citation
- Citations that don't match the claim when checked
- Citing other articles that themselves have no primary source
- "Studies show..." with no link to the actual study

**Step 4 — Corroborate key claims**

For each major factual claim, run a WebSearch:
```
WebSearch: "<claim>" site:gov OR site:edu OR "<established news outlet>"
```

Check if at least 2 independent reliable sources confirm the same fact.

**Step 5 — Check recency**

- When was the article published?
- If the topic is time-sensitive (statistics, laws, scientific consensus, tech), is the data current?
- Is there a more recent version of the data that contradicts or updates the claim?

**Step 6 — Bias signals**

Scan for:
- Emotional, alarmist, or loaded language in headlines ("SHOCKING", "DESTROYS", "You won't believe")
- Only presenting one side without acknowledging counterarguments
- Anonymous authorship (no byline)
- Clear political or commercial agenda without disclosure
- "Sponsored content" / "Partner post" / "Paid partnership" labels
- Comments or sections that blur opinion and fact

**Step 7 — Output the report**

```
Reliability Assessment: [Article title]
Source: [domain] | Author: [name or "Unknown"] | Date: [date]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

VERDICT: ✅ Reliable  [or ⚠️ / 🔶 / ❌]
Score: 7.8 / 10

DIMENSION BREAKDOWN
  Source credibility  [████████░░] 8/10  — Established tech publication, clear editorial policy
  Citation quality    [███████░░░] 7/10  — 4 of 6 claims cited; 2 cite secondary articles only
  Corroboration       [████████░░] 8/10  — Core statistics confirmed by 3 independent sources
  Author credentials  [██████░░░░] 6/10  — Named author, no stated expertise in this field
  Recency             [██████████] 10/10 — Published last month, data is current
  Bias indicators     [████████░░] 8/10  — Balanced framing, one section slightly promotional

KEY CLAIMS CHECKED
  ✅ "Global AI investment reached $67B in 2024" — confirmed by Bloomberg, Pitchbook
  ✅ "75% of enterprises plan to adopt AI by 2026" — sourced from Gartner report (linked, verified)
  ⚠️ "AI reduces customer churn by 30%" — single vendor case study, not independently verified
  ❌ "Most experts agree AI will replace 40% of jobs" — misrepresents the cited McKinsey study

RED FLAGS
  ⚠️ One statistic attributed to a vendor white paper (commercial bias risk)
  ⚠️ "Most experts agree..." used without naming or linking experts

RECOMMENDATION
  Safe to use as a secondary source. Verify the churn statistic independently and
  replace the job-replacement claim with the actual McKinsey numbers.
  
  Reliable for: General framing, the $67B and 75% statistics
  Verify before using: Vendor-sourced statistics, expert consensus claims
```

---

### /verify --text "<text>" — Assess pasted content

When the user pastes content directly (no URL):

1. Extract key claims from the text
2. Run WebSearch for each claim to find corroborating or contradicting sources
3. Note: source credibility and citation checks are limited — the output will say "Source: Unknown (no URL provided)" and weight corroboration higher
4. Apply the same scoring rubric, noting that score is based only on claim corroboration and bias analysis

---

### /verify --batch <url1> <url2> ... — Multiple sources

Assess each URL independently, then output a comparison table:

```
Batch Reliability Assessment
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[1] example.com/article-1    ✅ Reliable     8.2/10
[2] blog.example.org/post    🔶 Questionable  4.7/10
[3] news.example.net/story   ⚠️ Caution      6.1/10

Best source: [1] — use as primary
Avoid: [2] — unverified claims, no citations
```

Then show full reports for each.

---

### /verify --compare <url1> <url2> — Side-by-side comparison

Both URLs cover the same topic. Assess both, then compare:

```
Source Comparison: [Topic]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                        Source A          Source B
Reliability score:      8.1/10  ✅       5.3/10  🔶
Source credibility:     9/10             5/10
Citation quality:       8/10             4/10
Corroboration:          8/10             6/10
Recency:                9/10             3/10  (2019 data)
Bias signals:           7/10             6/10

Agreement on core facts: ✅ Both agree on X, Y, Z
Contradiction found:     ⚠️ Source A says 45%, Source B says 23% — check primary data

Recommendation: Use Source A. Source B uses outdated data and lacks primary citations.
```

---

### /verify --sources <topic> — Find reliable sources on a topic

When you need sources but don't have any yet:

Run searches targeting authoritative domains:

```
WebSearch: "<topic>" site:gov
WebSearch: "<topic>" site:edu
WebSearch: "<topic>" site:who.int OR site:nih.gov OR site:ec.europa.eu
WebSearch: "<topic>" site:reuters.com OR site:apnews.com OR site:bbc.com
```

Return a list of 5–10 reliable sources with quick credibility notes:

```
Reliable Sources: [Topic]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[1] who.int/...              — WHO official report, primary source ✅
[2] nejm.org/...             — Peer-reviewed, New England Journal of Medicine ✅
[3] reuters.com/...          — Established newswire, named author ✅
[4] bbc.com/...              — Public broadcaster, editorial standards ✅
[5] ourworldindata.org/...   — Research aggregator, cites primary sources ✅
```

---

## Trusted Domain Reference

These domains are generally reliable starting points. Always still verify specific claims.

**Academic / Scientific**
- `*.edu` (universities), `scholar.google.com`, `pubmed.ncbi.nlm.nih.gov`, `nature.com`, `science.org`, `thelancet.com`, `nejm.org`

**Government / Official**
- `*.gov`, `*.gov.es`, `ec.europa.eu`, `who.int`, `un.org`, `oecd.org`, `eurostat.ec.europa.eu`

**Data / Statistics**
- `ourworldindata.org`, `statista.com` (check primary sources they cite), `worldbank.org`, `ine.es` (Spain), `bls.gov` (US)

**Established journalism**
- `reuters.com`, `apnews.com`, `bbc.com`, `theguardian.com`, `nytimes.com`, `economist.com`, `ft.com`, `elpais.com`

**Tech / Science journalism (reliable)**
- `arstechnica.com`, `wired.com`, `technologyreview.mit.edu`, `scientificamerican.com`

## Red-Flag Patterns

These do NOT automatically disqualify a source, but require extra corroboration:

- Domain ending in `.info`, `.biz`, or unusual TLDs mimicking real news outlets
- URL with words like "truth", "real", "actual", "hidden", "what-they-don't-want-you-to-know"
- No About page or contact information
- No author name or credentials
- Headlines in ALL CAPS or with excessive exclamation marks
- Heavy reliance on anonymous sources or unnamed "experts"
- Publication date missing or unclear
- Quotes that can't be traced to an original source
- Sponsored content without clear disclosure

---

## Honesty Rules

- Never assign a reliability score without actually reading the content and cross-referencing at least the top 2–3 claims.
- A domain being well-known does not make a specific article reliable — check the specific claims.
- "Reliable" means the verifiable facts hold up. A reliable source can still contain opinion or analysis — distinguish between factual claims and editorial judgement.
- If WebFetch cannot retrieve a URL (paywalled, blocked), say so. Do not score based on the title alone.
- When uncertain, round down the score. A cautious verdict is safer than a false endorsement.
- Always note the date of assessment — reliability of a source can change over time.

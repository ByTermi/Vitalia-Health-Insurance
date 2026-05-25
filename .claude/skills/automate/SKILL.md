---
name: automate
description: "Content creation pipeline orchestrator. Chains /research, /verify, /marketing, and /seo to go from a niche or topic to a verified, SEO-ready draft in one command. Trigger: /automate"
trigger: /automate
---

# /automate

Multi-skill content pipeline. Chains `/research`, `/verify`, `/marketing`, and `/seo` to produce publish-ready content without manually invoking each skill one by one.

Give it a niche and it researches what's trending, picks the best opportunity, verifies the sources are trustworthy, and drafts a complete SEO-structured post.

## Usage

```
/automate --post <niche>                   # full pipeline: research → topic pick → verify → draft → SEO
/automate --post <niche> --lang <locale>   # same pipeline, output in a specific language
/automate --batch <niche> <N>              # generate N post drafts back-to-back from one research run
/automate --draft "<topic>"               # skip research, draft a specific topic with verified sources
/automate --calendar <niche>               # research + verify top sources → 30-day content calendar
/automate --pipeline                       # interactive: choose which modules to chain and in what order
```

---

## Pipeline Map

| Mode | Modules chained |
|------|----------------|
| `--post` | Research → Rank → Verify → Draft → SEO outline |
| `--batch` | Research → Rank → [Verify → Draft] × N |
| `--draft` | Verify sources → Draft → SEO outline |
| `--calendar` | Research → Rank → Verify top 5 → Marketing calendar |
| `--pipeline` | User-defined module chain |

Each module below maps to the logic defined in the corresponding SKILL.md (`/research`, `/verify`, `/marketing`, `/seo`). Run their steps inline — do NOT invoke the Skill tool recursively.

Always show which step is running: `[Step 1/4 — Research]`, `[Step 2/4 — Verify]`, etc. Separate steps visually with `━━━` dividers.

---

## What You Must Do When Invoked

---

### /automate --post <niche> [--lang <locale>] — Full single-post pipeline

**[Step 1/5 — Research]**

Identify 2–3 relevant subreddits for the niche. Fetch top posts:
```
GET https://www.reddit.com/r/{subreddit}/top.json?t=week&limit=25
Headers: User-Agent: Mozilla/5.0
```

Also run:
- `WebSearch: {niche} trending {current month year}`
- `WebSearch: {niche} most searched questions`

Extract 5 candidate topics. Rank by: signal strength (upvotes / search volume) × monetization potential (CPM niche relevance from `/marketing` reference data).

**[Step 2/5 — Select topic]**

Pick the #1 candidate. Criteria in order:
1. Clear content angle (how-to, explainer, comparison, tool)
2. Verifiable with authoritative sources (not purely opinion)
3. Search intent is explicit (informational or transactional)

Show the selection before continuing:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[Step 2/5 — Topic selected]
Title:   "[selected topic]"
Angle:   [how-to / explainer / comparison / tool page]
Signals: Reddit [X upvotes] | Trend [rising/stable/declining]
Why:     [1-line reason]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**[Step 3/5 — Verify sources]**

Find 3–5 authoritative sources on the topic:
```
WebSearch: "{topic}" site:gov OR site:edu OR site:reuters.com OR site:apnews.com
WebSearch: "{topic}" "research" OR "study" OR "data"
```

For each source, apply `/verify` scoring criteria (source credibility, citation quality, corroboration, recency, bias). Keep only sources scoring ≥ 6.0. If fewer than 2 pass, run additional targeted searches before proceeding.

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[Step 3/5 — Sources verified]
  ✅ [domain] — [score]/10 — [one-line credential]
  ✅ [domain] — [score]/10 — [one-line credential]
  ⚠️ [domain] — [score]/10 — use with caution (noted in draft)
  ❌ [domain] — [score]/10 — discarded
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**[Step 4/5 — Draft]**

Write a complete, copy-paste-ready post. No placeholders.

Required structure:
```
# [SEO title — under 60 chars, includes primary keyword]

**Meta description:** [under 155 chars, includes primary keyword and a benefit]

## Introduction
[150–200 words. Hook → problem → what this covers → why trust it. Cite one verified source.]

## [H2 — Main concept or context]
[300–400 words. Use the verified sources here. Include data or stats only if sourced.]

## [H2 — Core how-to, explanation, or comparison]
[400–600 words. Numbered steps, comparison table, or practical example as appropriate.]

## [H2 — Practical implications or examples]
[200–300 words. Real-world relevance, edge cases, common mistakes.]

## Frequently Asked Questions

**[Question 1 — from research signals]**
[2–4 sentence answer, direct.]

**[Question 2]**
[answer]

**[Question 3]**
[answer]

**[Question 4]**
[answer]

**[Question 5]**
[answer]

## Conclusion
[100–150 words. Summary → next step or CTA → internal link suggestion.]
```

If `--lang <locale>` was specified, write the entire draft in that language and adapt examples and references to that market.

**[Step 5/5 — SEO outline]**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[Step 5/5 — SEO checklist]
  Title tag:          "[title]" (XX chars)
  Meta description:   "[meta]" (XXX chars)
  Primary keyword:    H1 ✅ | first 100 words ✅ | ≥2 H2s ✅
  Internal link:      suggest 1–2 existing site pages to link to
  Image alt text:     "[suggestion for hero image]"
  FAQ schema:         add JSON-LD for FAQ section
  Estimated read:     ~X min
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

After completing, offer: "Want me to save this draft to the vault (`/capture`)?"

---

### /automate --batch <niche> <N> — Generate N posts back-to-back

1. Run Step 1 (research) **once** — pull all top candidates. Do NOT re-fetch Reddit for each post.
2. Rank and select the top N candidates.
3. For each candidate, run Steps 3–5 (Verify → Draft → SEO outline).
4. Present all N drafts sequentially, clearly separated.

```
Batch run: [niche] — [N] posts requested
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Post [1/N]: "[title]"
[full draft + SEO checklist]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Post [2/N]: "[title]"
[full draft + SEO checklist]
...
```

If research yields fewer strong candidates than N requested, produce what's available and explain: "Research returned X strong topics — producing X posts instead of N."

---

### /automate --draft "<topic>" — Skip research, draft specific topic

When the user already knows what to write:

1. **[Step 1/3 — Verify]** Run Step 3 logic (verify sources) for the specific topic.
2. **[Step 2/3 — Draft]** If ≥ 2 reliable sources found, run Step 4 (draft). If no reliable sources: warn "Could not verify sources for this topic — draft will not include sourced statistics. Verify manually before publishing." Then draft anyway.
3. **[Step 3/3 — SEO outline]** Run Step 5.

---

### /automate --calendar <niche> — Research-backed content calendar

1. **[Step 1 — Research]** Run Step 1 (full research). Collect top 10–15 topic candidates.
2. **[Step 2 — Verify top 5]** Run Step 3 (verify sources) for the top 5 candidates only — verifying all 15 is too slow.
3. **[Step 3 — Build calendar]** Apply `/marketing --content-plan` logic: distribute topics across 30 days, prioritize tools and pillar content first, then supporting articles.

Output:
```
Content Calendar: [niche]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Week 1 — Foundation
  Day 1:  [Tool/Article] "[title]" — keyword: [kw] — Sources: ✅ verified
  Day 3:  [Article] "[title]" — keyword: [kw] — Sources: ✅ verified
  Day 5:  [Article] "[title]" — keyword: [kw] — Sources: ⚠️ verify manually
  Day 7:  [Tool] "[title]" — keyword: [kw] — Sources: ✅ verified

Week 2 — Long-tail expansion
  ...

Week 3 — Authority building
  ...

Week 4 — Multilingual launch
  Day 22: Translate top 3 posts → /de
  Day 25: Translate top 3 posts → /fr
  Day 28: Translate top 3 posts → /es
  Day 30: Submit updated sitemap to Google Search Console
```

Offer: "Want me to save this calendar to `projects/<name>/roadmap.md`?"

---

### /automate --pipeline — Interactive custom pipeline

Present the available modules and ask the user to define their chain:

```
Available pipeline modules:
  [R] Research   — trending topics from Reddit, Google Trends, HN
  [V] Verify     — cross-check sources for reliability
  [D] Draft      — write the full structured post
  [S] SEO        — SEO checklist and optimization notes
  [M] Marketing  — keyword strategy and distribution notes
  [C] Capture    — save output to vault

Define your pipeline (e.g. R → V → D → S → C):
```

Run each module in the order specified. If the user skips V (verify), note in the draft output: "Sources not verified — check before publishing."

---

## Output Format Rules

- Show step progress at the start of each step: `[Step X/Y — Name]`
- Separate steps with `━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`
- Draft must be completely written out — no `[insert example here]` or `[add data]` placeholders
- If a step fails (site unreachable, no sources found), log the failure and continue with a fallback rather than stopping the whole pipeline
- Always state the data source and date for every researched claim

---

## Honesty Rules

- Never invent Reddit upvote counts, search volume estimates, or trend direction without fetching real data
- Never mark a source as verified without actually fetching and checking it
- Never include statistics in the draft that couldn't be traced to a verified source — flag them explicitly if used
- If a site is unreachable during verification, say so and search for an alternative rather than skipping
- Don't pad drafts to hit word counts — cut, don't inflate
- Round down reliability scores when uncertain — a cautious verdict is safer than a false endorsement

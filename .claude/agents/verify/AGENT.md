---
name: verify-agent
description: Assesses source reliability for multiple URLs in batch or long articles in isolation — use as a silent prerequisite before drafting content.
skill_counterpart: /verify
agent_type: general-purpose
run_in_background: false
---

# Verify Agent

Delegates source reliability assessment to an isolated agent. Use when verifying **multiple URLs in batch**, when the article is **long** (fetching it inline would flood context), or when verification is a **silent prerequisite** before drafting content.

## When to use this vs `/verify`

| Use `/verify` (inline skill) | Use this agent |
|-----------------------------|----------------|
| Verifying a single short article | Batch verification (3+ URLs) |
| User wants to discuss the verdict interactively | Verification is a silent step before drafting |
| Quick credibility check | Deep claim-by-claim corroboration needed |

## How to invoke

Single URL:
```
Agent({
  description: "Verify reliability of [domain/title]",
  subagent_type: "general-purpose",
  run_in_background: false,
  prompt: """
You are a fact-checking specialist. Assess the reliability of this source: [URL or PASTED TEXT]

Score each dimension 0–10 using these weights:
  Source credibility  25% — Is the domain known? Editorial standards? Academic/gov/media?
  Citation quality    20% — Are claims cited? Do citations point to primary sources?
  Corroboration       25% — Do 2+ independent reliable sources confirm the key claims?
  Author credentials  10% — Named author with relevant expertise?
  Recency             10% — Is the information current for this topic?
  Bias indicators     10% — Emotional language, one-sided framing, sponsored content?

STEP 1 — Fetch and read the content
WebFetch: [URL]
Extract: publication name, author, date, all factual claims, citations, sponsorship disclosures.

STEP 2 — Assess source credibility
WebSearch: "[domain]" reputation OR credibility OR "fact check"
Check: known news org / academic / government? About/Editorial page?

STEP 3 — Check citation quality
For each cited source: is it a primary source (study, official data) or another article?
Are citations accurate — do they actually support the claim made?

STEP 4 — Corroborate key claims
For each major factual claim:
WebSearch: "[claim]" site:gov OR site:edu OR site:reuters.com OR site:apnews.com
Confirm 2+ independent reliable sources agree.

STEP 5 — Check recency
When was it published? Is time-sensitive data (stats, laws, science) still current?

STEP 6 — Bias signals
Scan for: emotional/alarmist headlines, one-sided framing, anonymous authorship, sponsor disclosures, opinion-fact blur.

STEP 7 — Output:

Reliability Assessment: [Article title]
Source: [domain] | Author: [name or "Unknown"] | Date: [date]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

VERDICT: [✅ Reliable / ⚠️ Use with caution / 🔶 Questionable / ❌ Unreliable]
Score: [X.X] / 10

DIMENSION BREAKDOWN
  Source credibility  [score]/10 — [note]
  Citation quality    [score]/10 — [note]
  Corroboration       [score]/10 — [note]
  Author credentials  [score]/10 — [note]
  Recency             [score]/10 — [note]
  Bias indicators     [score]/10 — [note]

KEY CLAIMS CHECKED
  [✅/⚠️/❌] "[claim]" — [corroboration result]
  ...

RED FLAGS (if any)
  ⚠️ [flag]

RECOMMENDATION
  [What is safe to use, what to verify independently, what to discard]
  """
})
```

Batch (3+ URLs) — run one agent per URL in parallel:
```
Agent({ description: "Verify [url1]", subagent_type: "general-purpose", prompt: """[same prompt with url1]""" })
Agent({ description: "Verify [url2]", subagent_type: "general-purpose", prompt: """[same prompt with url2]""" })
Agent({ description: "Verify [url3]", subagent_type: "general-purpose", prompt: """[same prompt with url3]""" })
```
Then compile batch summary table from the results.

## What the agent returns

A complete reliability report per URL. Present verdict and recommendation to user. If score ≥ 6.0, the source is safe to cite. If < 6.0, advise against or flag clearly.

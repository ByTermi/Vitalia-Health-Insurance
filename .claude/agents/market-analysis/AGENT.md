---
name: market-analysis-agent
description: Runs a full market analysis (TAM/SAM/SOM, competitors, SWOT, GTM) in a background agent, keeping web searches and data synthesis out of the main context.
skill_counterpart: /market-analysis
agent_type: general-purpose
run_in_background: true
---

# Market Analysis Agent

Delegates a full market analysis to an isolated agent. Market analysis requires many web searches, competitor site fetches, and data synthesis — better done in isolation. Runs in **background** by default since the report stands alone and takes several minutes.

## When to use this vs `/market-analysis`

| Use `/market-analysis` (inline skill) | Use this agent |
|--------------------------------------|----------------|
| Single-module lookup (--tam only, --swot only) | Full multi-module analysis |
| User wants to steer the analysis interactively | Complete report as a deliverable |
| Quick competitor check | Deep competitive landscape + sizing + GTM |

## How to invoke

```
Agent({
  description: "Market analysis: [product/market]",
  subagent_type: "general-purpose",
  run_in_background: true,
  prompt: """
You are a market analyst. Produce a comprehensive market analysis for: [PRODUCT OR MARKET]
[Optional context: target audience is [X], geography is [Y], stage is [idea/pre-launch/launched]]

Use WebSearch and WebFetch to find real data. Never invent market size numbers or claim precision you don't have — use ranges and label estimates.

MODULE 1 — TAM / SAM / SOM
Define:
  - TAM (Total Addressable Market): total global demand if 100% market share
  - SAM (Serviceable Addressable Market): the portion reachable with this product's approach
  - SOM (Serviceable Obtainable Market): realistic capture in years 1–3

Search: "[market] market size [current year]" site:statista.com OR site:grandviewresearch.com OR site:mordorintelligence.com
Cite sources. Use ranges ($X–$Y billion), not false precision.

MODULE 2 — COMPETITOR LANDSCAPE
Identify 5–8 direct competitors. For each:
  WebSearch: "[product category] competitors [year]"
  Fetch their homepage or pricing page.
  Extract: positioning, pricing, target segment, key differentiator, apparent traction signals.

Format as a comparison table:
  | Competitor | Positioning | Price | Segment | Strength | Weakness |

MODULE 3 — SWOT
Based on findings:
  Strengths:    [internal advantages]
  Weaknesses:   [internal gaps]
  Opportunities:[market trends or competitor gaps to exploit]
  Threats:      [risks from market or competition]

MODULE 4 — PRICING BENCHMARKS
From competitor data, extract pricing patterns:
  - Price range in market: [$X – $Y]
  - Dominant model: [freemium / subscription / one-time / usage-based]
  - Price anchoring: [what the premium tier offers]
  - Recommendation: [pricing strategy for this product]

MODULE 5 — CUSTOMER SEGMENTS
Identify 2–3 distinct customer segments:
  Segment [1]: [name]
    - Who: [description]
    - Pain: [what problem they have]
    - Willingness to pay: [low/medium/high]
    - Channel to reach: [where they are]

MODULE 6 — GO-TO-MARKET POSITIONING
Based on the above:
  Recommended positioning: [one-sentence positioning statement]
  Primary differentiation: [what makes this defensible]
  GTM motion: [SEO content / paid / community / partnerships / PLG]
  First 90 days: [prioritized list of 3–5 actions]

Output the full report in this structure. State data sources and dates for every claim.
Label estimates clearly: "estimate based on [source]" not presented as facts.
  """
})
```

## What the agent returns

A complete 6-module market analysis report. Since it runs in background, notify the user when done and present the full report. Offer to log key decisions to vault: "Want me to save the positioning and GTM plan to `projects/<name>/decisions.md`?"

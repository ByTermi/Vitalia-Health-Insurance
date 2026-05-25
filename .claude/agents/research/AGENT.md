---
name: research-agent
description: Delegates trending-topic research (Reddit, HN, Google Trends) to an isolated agent — use when research feeds another task or spans 5+ data sources.
skill_counterpart: /research
agent_type: general-purpose
run_in_background: false
---

# Research Agent

Delegates a full trending-topic research run to an isolated agent. Use this instead of the `/research` skill when the research is a **preliminary step feeding another task** (so raw results don't fill the main context), or when doing a **full niche scan** that will touch 5+ data sources.

## When to use this vs `/research`

| Use `/research` (inline skill) | Use this agent |
|-------------------------------|----------------|
| Quick single-source lookup | Full niche scan (Reddit + Trends + web) |
| Research is the end goal | Research feeds another task (e.g. /automate) |
| User wants to discuss results interactively | Results should be a clean deliverable |

## How to invoke

```
Agent({
  description: "Research trending topics in [niche]",
  subagent_type: "general-purpose",
  run_in_background: false,
  prompt: """
You are a content research specialist. Your task is to produce a live research report on trending topics and content opportunities for the niche: [NICHE].
[If locale is specified: Focus on the [LOCALE] market and include non-English keywords where relevant.]

Use WebFetch and WebSearch to pull LIVE data. Never invent or estimate trend data.

STEP 1 — Reddit scan
Identify 2-3 relevant subreddits for [NICHE]. For each, fetch:
  GET https://www.reddit.com/r/{subreddit}/top.json?t=week&limit=25
  Headers: User-Agent: Mozilla/5.0
Extract: post titles, scores (upvotes), num_comments, flair.
High-score posts = proven audience interest.

STEP 2 — Search signals
Run these WebSearches:
  - "[NICHE] trending [current month year]"
  - "[NICHE] most searched questions"
  - "[NICHE] frequently asked questions"

STEP 3 — Rising queries
Fetch: https://trends.google.com/trends/explore?q=[main keyword]&geo=US
Also search: site:trends.google.com "[NICHE]" to find published trend reports.

STEP 4 — Synthesize into a report using this exact format:

Research Report: [Niche]
Date: [today] | Sources: Reddit, Google Trends, Web Search
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

TRENDING RIGHT NOW
  [1] "[post title]" — [X] upvotes this week
      Angle: [content type]
      Keyword: "[keyword opportunity]"
  [2] ...

RISING SEARCHES
  ↑ "[keyword]" — [signal]
  → "[keyword]" — stable
  ↓ "[keyword]" — declining

QUESTIONS PEOPLE ASK
  "[question 1]"
  "[question 2]"
  ...

CONTENT OPPORTUNITIES (ranked by traffic + revenue potential)
  [1] [type]: [title] — [why it ranks high]
  [2] ...

SUBREDDITS ENGAGED
  r/[name] — [size], [engagement note]
  ...

If any source is unreachable, say so and use an alternative. Never invent scores or trend numbers.
  """
})
```

## What the agent returns

A complete research report in the format above. After receiving it:
1. Present the report to the user
2. Offer: "Want to run `/automate --post [niche]` to turn the top opportunity into a full draft?"
3. Offer to save to vault: "Want me to capture the top opportunities to `projects/<name>/ideas.md`?"

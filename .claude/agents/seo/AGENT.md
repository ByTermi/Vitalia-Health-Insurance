---
name: seo-agent
description: Audits an entire project directory or live URL for SEO issues (meta, hreflang, CWV, structured data) via an Explore agent, returning only prioritized findings.
skill_counterpart: /seo
agent_type: Explore
run_in_background: false
---

# SEO Agent

Delegates a full SEO audit to an Explore agent. The Explore agent reads source files and fetches URLs in isolation, returning only the prioritized findings — not the raw file contents. Use when auditing an **entire project directory** or a **live URL** you haven't opened.

## When to use this vs `/seo`

| Use `/seo` (inline skill) | Use this agent |
|--------------------------|----------------|
| Quick single-file check | Full project directory audit |
| User wants to discuss findings interactively | Clean audit report needed |
| Already in the relevant files | Auditing a live URL or unfamiliar project |

## How to invoke

Project audit:
```
Agent({
  description: "SEO audit of [project name or path]",
  subagent_type: "Explore",
  run_in_background: false,
  prompt: """
You are an SEO specialist. Perform a full SEO audit of the project at: [PATH or URL]

Read all relevant files: HTML files, next.config.js/ts, app/layout.tsx, sitemap.xml, robots.txt, any _document files, meta tag components, structured data files.
If a live URL: fetch it and inspect the rendered HTML, headers, and page source.

Audit these 5 categories and score each 0–10:

1. TECHNICAL SEO
   - Title tags: present, unique, 50–60 chars, primary keyword in each?
   - Meta descriptions: present, unique, 140–155 chars?
   - Canonical tags: correct, no self-referential issues?
   - robots.txt: exists, not blocking key pages?
   - sitemap.xml: exists, submitted, all key pages included, no noindex pages?
   - hreflang: correct if multilingual (x-default + all locales)?
   - 404 handling: custom page exists?

2. ON-PAGE SIGNALS
   - H1: one per page, includes primary keyword?
   - H2/H3 structure: logical hierarchy?
   - Keyword in first 100 words?
   - Image alt text: descriptive, not empty?
   - Internal linking: pages link to each other?
   - Content length: key pages ≥ 800 words?

3. STRUCTURED DATA
   - JSON-LD present? Type appropriate for content (Article, FAQPage, Tool, Product)?
   - Required fields present?
   - Test via: search "rich results test [url]" for known issues

4. CORE WEB VITALS / PERFORMANCE
   - LCP: image preload, no render-blocking resources?
   - CLS: reserved space for images and ads?
   - FID/INP: large JS bundles, third-party scripts?
   - Ad scripts: lazy-loaded, not blocking?

5. CONTENT & KEYWORDS
   - Primary keyword targeted per page?
   - FAQ sections present on informational pages?
   - Thin content (< 300 words) on non-tool pages?
   - Duplicate content across pages?

Output format:

SEO Audit: [Project/URL]
Date: [today]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

OVERALL SCORE: [X]/10

CATEGORY SCORES
  Technical SEO       [X]/10
  On-page signals     [X]/10
  Structured data     [X]/10
  Core Web Vitals     [X]/10
  Content & keywords  [X]/10

CRITICAL ISSUES (fix first)
  ❌ [issue] — [file:line or page] — Fix: [copy-paste solution]
  ❌ ...

HIGH PRIORITY
  ⚠️ [issue] — Fix: [solution]
  ...

QUICK WINS
  💡 [issue] — Fix: [solution]
  ...

PASSING
  ✅ [what's already correct]
  ...

ESTIMATED TRAFFIC IMPACT
  Fixing critical issues: [high/medium/low impact]
  Fixing high priority: [impact estimate]
  """
})
```

## What the agent returns

A complete audit report. Present the critical issues and quick wins to the user. Offer to implement any of the fixes inline (`/seo` skill handles the implementation).

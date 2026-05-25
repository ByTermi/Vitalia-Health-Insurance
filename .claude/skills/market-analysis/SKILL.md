---
name: market-analysis
description: "Conduct structured market analysis: competitor landscape, TAM/SAM/SOM sizing, SWOT, trend identification, pricing benchmarks, and go-to-market positioning. Produces actionable reports grounded in available data. Trigger: /market-analysis"
trigger: /market-analysis
---

# /market-analysis

Structured market analysis skill. Turns a product idea, business question, or competitive challenge into a prioritized, evidence-grounded analysis — covering market size, competitive landscape, customer segments, pricing, and strategic positioning.

## Usage

```
/market-analysis                              # full analysis wizard
/market-analysis "<product or market>"        # analyze a specific product or market
/market-analysis --competitors                # competitor landscape only
/market-analysis --tam                        # TAM/SAM/SOM sizing only
/market-analysis --swot                       # SWOT analysis only
/market-analysis --pricing                    # pricing benchmark and strategy
/market-analysis --segments                   # customer segmentation analysis
/market-analysis --trends                     # market trends and growth signals
/market-analysis --positioning                # differentiation and positioning map
/market-analysis --gtm                        # go-to-market strategy
/market-analysis --report                     # compile all sections into a full report
```

## What /market-analysis Produces

Not a generic "here are five competitors" list. A market analysis should answer the questions a founder, PM, or investor actually needs:

1. **Is this market worth entering?** (size, growth, saturation)
2. **Who will I be fighting for customers?** (competitive landscape, moats)
3. **Who is my customer and what do they actually want?** (segments, jobs-to-be-done)
4. **What should I charge?** (pricing benchmarks, willingness-to-pay signals)
5. **How do I win?** (positioning, differentiation, GTM)

---

## What You Must Do When Invoked

If no subject was given, ask for it. Otherwise proceed to the wizard.

---

### Step 1 — Setup wizard

If no subject or flags were given, ask:

```
To run a market analysis, I need a few details:

1. What is the product or market? (e.g. "B2B project management SaaS", "AI photo editing app")
2. What stage are you at? (Idea validation / Pre-launch / Post-launch / Fundraising)
3. Target geography: Global / North America / Europe / Specific country
4. Primary question to answer: (e.g. "Is there room for another player?", "How should we price?", "Who are the top 5 competitors?")
5. Do you have any existing data? (revenue numbers, interview notes, traffic data)
```

Wait for answers before proceeding.

---

### Step 2 — Market definition and sizing (TAM / SAM / SOM)

**Market definition** — before sizing, define the market precisely:
- **Too broad**: "AI software market" → useless
- **Too narrow**: "AI headshot generation for LinkedIn in Ohio" → no data
- **Right**: "AI-powered professional photo editing for individuals, global, B2C"

Present the definition and ask the user to confirm before sizing.

**TAM/SAM/SOM framework:**

| Level | Definition | Estimation Method |
|-------|-----------|-------------------|
| TAM (Total Addressable Market) | Everyone who could theoretically use this | Top-down: industry reports, analyst data |
| SAM (Serviceable Addressable Market) | Those reachable with your business model | Bottom-up: target segments × avg contract value |
| SOM (Serviceable Obtainable Market) | Realistic 3-5 year capture | Benchmark: 1-10% of SAM for new entrants |

**Bottom-up sizing (preferred — more defensible):**

```
Example: B2B project management SaaS, US market

Target: Software companies with 10-500 employees
→ ~85,000 companies in the US (source: US Census NAICS 5112)

Decision-makers per company: ~1 (Head of Engineering or Operations)
→ 85,000 potential buyers

Conversion funnel assumption: 2% trial → paid in year 1
→ ~1,700 customers

Average Contract Value: $150/month × 12 = $1,800/year
→ Year 1 SOM: ~$3M ARR

SAM at 10% penetration: $153M
TAM (all geographies, all company sizes): ~$2.4B
```

Show the math. Flag assumptions clearly. Never present a number without its assumption chain.

---

### Step 3 — Competitive landscape

Map competitors across three categories:

**Direct competitors** — same product, same customer, same use case
**Indirect competitors** — different product, same problem (e.g. spreadsheets vs. project management SaaS)
**Potential entrants** — companies that could enter (e.g. large platforms adding a feature)

For each direct competitor, fill this table:

| Competitor | Pricing | Key features | Target segment | Estimated revenue | Funding | Moat |
|-----------|---------|-------------|----------------|------------------|---------|------|
| Asana | $10-25/user/mo | Tasks, timelines, portfolios | Enterprise | ~$600M ARR | Public | Brand + integrations |
| Monday.com | $9-19/user/mo | Customizable workflows | SMB + Enterprise | ~$900M ARR | Public | Low-code flexibility |
| Linear | $8/user/mo | Dev-focused, fast UX | Tech startups | ~$35M ARR (est.) | Series B | Developer brand |

**Competitive dimensions to assess:**
- Pricing model (per seat, usage-based, flat, freemium)
- Core differentiator ("we are the X for Y")
- Customer reviews: common praise and recurring complaints (signals unmet needs)
- Distribution: PLG, sales-led, channel
- Geographic focus
- Funding and runway (signals competitive pressure)

**Flag gaps**: Which segment is underserved? Which complaint appears across all competitors?

---

### Step 4 — Customer segmentation

Identify 2-4 distinct customer segments. For each:

```
Segment: [Name]
─────────────────────────────────────────────────
Who they are: [job title, company type, size, geography]
Primary job-to-be-done: [what they're trying to accomplish]
Current solution: [how they solve it today]
Pain with current solution: [specific frustration]
Willingness to pay: [price point evidence]
Where to reach them: [channels, communities, events]
Deal-breaker requirements: [must-haves or they won't buy]
```

Example:
```
Segment: Indie Developer / Solo Founder
─────────────────────────────────────────────────
Who they are: 1-person team, building SaaS, self-funded
Primary job-to-be-done: Ship features without losing track of what's next
Current solution: Notion, GitHub Issues, or nothing
Pain: Context-switching between tools; GitHub Issues not designed for product thinking
Willingness to pay: $0-15/month (price-sensitive; already paying Notion, GitHub, Vercel)
Where to reach them: Indie Hackers, r/SideProject, X/Twitter #buildinpublic, Product Hunt
Deal-breaker: Must integrate with GitHub; must not require team setup; must be fast
```

---

### Step 5 — SWOT analysis

Present as a 2×2 with specific, evidence-backed items — not generic observations:

```
                 HELPFUL                    HARMFUL
              ┌─────────────────┐        ┌─────────────────┐
  INTERNAL    │   STRENGTHS     │        │   WEAKNESSES    │
              │                 │        │                 │
              │ • [specific]    │        │ • [specific]    │
              │ • [specific]    │        │ • [specific]    │
              └─────────────────┘        └─────────────────┘
              ┌─────────────────┐        ┌─────────────────┐
  EXTERNAL    │  OPPORTUNITIES  │        │    THREATS      │
              │                 │        │                 │
              │ • [specific]    │        │ • [specific]    │
              │ • [specific]    │        │ • [specific]    │
              └─────────────────┘        └─────────────────┘
```

Rules for SWOT items:
- Each item must be a complete sentence with evidence ("Competitors charge $25+/seat — price gap exists for <$10 tier")
- Avoid "we have a great team" (not a market insight)
- Opportunities must be external market conditions, not internal plans
- Threats must be plausible and time-bounded where possible

---

### Step 6 — Pricing analysis

**Benchmark pricing across competitors** (already partially done in Step 3).

**Pricing model selection:**

| Model | Best for | Risk |
|-------|---------|------|
| Per-seat | Collaboration tools | Customers hide usage to save cost |
| Usage-based | APIs, infrastructure | Revenue unpredictability |
| Flat / tiered | Tools with clear tiers | Undercharging power users |
| Freemium | PLG products | High support cost at free tier |
| Free trial → paid | High-ACV B2B | Conversion optimization complexity |

**Willingness-to-pay signals** (look for in reviews, forums, interviews):
- "I wish they had a cheaper plan" → pricing above willingness-to-pay
- "I'd pay for X feature" → pricing floor for premium tier
- "The enterprise plan is overkill" → missing a mid-market tier

**Recommended pricing structure:**

```
Tier         Price      Target         Key Features
Free         $0         Indie/student  Core features, limited seats/storage
Pro          $X/mo      SMB            All features, priority support
Business     $Y/mo      Growing teams  SSO, audit logs, admin controls
Enterprise   Custom     Large orgs     SLA, dedicated support, custom contracts
```

Suggest specific price points based on competitor benchmarks.

---

### Step 7 — Trend analysis

Identify macro and micro trends relevant to the market:

**Macro trends** (technology, regulation, behavior shifts):
- AI integration expectations (customers expect AI features in category)
- Remote work / distributed team tools demand
- Data privacy regulation (GDPR, CCPA) impact on tooling choices
- Economic climate impact on SaaS spending (compression vs. expansion)

**Micro trends** (signals within the specific market):
- Emerging competitor funding rounds in the category
- Product Hunt launches in the space (volume = market interest)
- Search trend data patterns (growing / plateau / declining)
- Community discussion volume (forums, subreddits, Slack groups)
- Open-source alternatives gaining traction (commoditization risk)

Categorize each trend:
- **Tailwind** (helps your entry)
- **Headwind** (hurts your entry)
- **Neutral** (watch but don't act yet)

---

### Step 8 — Positioning and differentiation

**Positioning statement template:**

```
For [target customer]
who [has this problem / wants this outcome],
[Product name] is a [category]
that [primary differentiator].

Unlike [primary alternative],
[Product name] [specific contrast].
```

Example:
```
For indie developers and solo founders
who need to ship fast without a project management overhead,
Linear is a product management tool
that prioritizes speed and developer workflow over feature completeness.

Unlike Jira and Asana,
Linear loads instantly, syncs with GitHub natively, and doesn't require admin setup.
```

**Differentiation map** — place your product and top 3 competitors on a 2-axis perceptual map. Choose axes relevant to the market (e.g., Price vs. Power, Simplicity vs. Customization, Speed vs. Completeness).

---

### Step 9 — Go-to-market strategy

Recommend a GTM motion based on the market analysis findings:

**PLG (Product-Led Growth)** — when:
- Freemium or free trial is viable
- Product sells itself through usage
- Target users have low buyer authority but high adoption influence

**Sales-Led** — when:
- ACV > $10K/year
- Complex procurement (security reviews, legal, procurement)
- Need to educate the market

**Community-Led** — when:
- Strong developer or creator community exists
- Word-of-mouth is the primary discovery channel
- Building in public is viable

For the recommended motion, specify:
1. **Acquisition channel** (where to find early customers)
2. **Activation hook** (first moment of value delivery)
3. **Retention lever** (what keeps them)
4. **Expansion play** (seat growth, tier upgrade, referral)
5. **First 90 days playbook** (specific actions, in order)

---

### Step 10 — Report compilation (--report flag)

When `--report` is given, compile all sections into a structured Markdown document:

```markdown
# Market Analysis: [Product/Market Name]
**Date:** [today's date]  
**Stage:** [from wizard]  
**Geography:** [from wizard]

## Executive Summary
[3-5 bullets: key findings, go/no-go recommendation, top risk]

## Market Size
[TAM/SAM/SOM with assumptions]

## Competitive Landscape
[Table + analysis]

## Customer Segments
[2-4 segments]

## SWOT
[2×2]

## Pricing Analysis
[Benchmark table + recommendation]

## Market Trends
[Tailwinds, headwinds, neutral]

## Positioning
[Statement + differentiation map]

## Go-to-Market
[Motion + 90-day playbook]

## Risks and Open Questions
[What could invalidate this analysis; what to validate next]
```

---

## Honesty Rules

- Never present a market size number without showing the assumption chain behind it.
- Never claim a competitor's revenue or funding unless citing a credible public source.
- Always distinguish between evidence-based claims and reasoned estimates.
- If there is insufficient data to size a niche market, say so — a ranged estimate ("$50M–$500M") is more honest than false precision.
- Do not tell users what they want to hear. If the market is saturated, declining, or dominated by a well-funded incumbent, say so clearly.
- SWOT items must reflect the actual market, not what the user hopes is true.

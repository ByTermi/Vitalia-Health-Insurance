# Agents

Agent definitions for tasks that are better delegated to an isolated Claude subagent than run inline in the main conversation.

## Skills vs Agents — when to use each

| Use a **Skill** (`/command`) | Use an **Agent** (AGENT.md) |
|-----------------------------|-----------------------------|
| Task writes code or vault files | Task is read-only analysis |
| Needs Q&A with user mid-flow | Output is a self-contained report |
| Part of a larger interactive pipeline | Can run independently (or in background) |
| Fast — touches < 10 files or URLs | Heavy I/O — touches 10+ files or data sources |
| Result feeds immediately into next step | Result is a deliverable the user reviews |

**The core principle:** if running the task inline would flood the conversation with raw search results or file contents, use an agent. The agent does all the I/O in isolation and returns only the clean output.

## Agent catalog

| Agent | Skill equivalent | Agent type | Background? | When to prefer agent |
|-------|-----------------|------------|-------------|----------------------|
| [research](research/AGENT.md) | `/research` | general-purpose | No | Full niche scan (5+ sources), or research feeds another task |
| [verify](verify/AGENT.md) | `/verify` | general-purpose | No | Batch verification (3+ URLs), or silent prereq before drafting |
| [seo](seo/AGENT.md) | `/seo` | Explore | No | Full project directory audit or live URL audit |
| [security](security/AGENT.md) | `/security` | Explore | No | Any comprehensive audit — always prefer agent |
| [market-analysis](market-analysis/AGENT.md) | `/market-analysis` | general-purpose | Yes | Full multi-module report |
| [graphify](graphify/AGENT.md) | `/graphify` | general-purpose | No | Always — graphify should never run inline |

## How agents are invoked

Agents are not slash commands. They're invoked by Claude using the `Agent()` tool when conditions match. Claude reads the relevant AGENT.md to get the prompt template, fills in the parameters, and delegates.

You can also explicitly request an agent version:
- "run research as an agent for [niche]"
- "use the security agent on this project"
- "delegate the SEO audit to an agent"

## Agent file format

Each AGENT.md has:
- **Frontmatter**: name, skill_counterpart, agent_type, run_in_background
- **When to use this vs the skill**: decision table
- **How to invoke**: exact `Agent({...})` call with filled prompt template
- **What the agent returns**: what to do with the output

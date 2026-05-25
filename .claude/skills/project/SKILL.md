---
name: project
description: "Manage projects through the Obsidian vault: create projects, browse status, add ideas/decisions/roadmap items, generate Claude suggestions, and update the registry. Trigger: /project"
trigger: /project
---

# /project

Full project lifecycle management through the vault at `E:\obsidian\vault_claude_code\Claude Code`.

## Usage

```
/project                              # list all projects from registry
/project new <name>                   # scaffold a new project in the vault
/project <name>                       # show project overview + recent ideas + status
/project <name> --ideas               # show all ideas for this project
/project <name> --idea "<text>"       # add a new idea to this project
/project <name> --suggest             # Claude analyzes the project and generates suggestions
/project <name> --decision "<title>"  # log an architectural decision (ADR)
/project <name> --roadmap             # show the project roadmap
/project <name> --keys                # show key names stored for this project (not values)
/project <name> --status <status>     # update project status in registry
/project <name> --edit overview       # open overview.md for editing guidance
```

---

## What You Must Do When Invoked

The vault is accessible via the MCP server named `obsidian`. Use MCP filesystem tools to read/write files.

Base path: `E:\obsidian\vault_claude_code\Claude Code`

---

### /project (no args) — List all projects

Read `projects/_REGISTRY.md`. Display a formatted summary:

```
Active projects:
  my-app         active      Next.js + Postgres    C:\dev\my-app
  api-service    mvp         Node.js + DynamoDB    C:\dev\api

On hold:
  old-project    paused      React + Firebase      C:\dev\old-project

Run /project <name> for details, or /project new <name> to create one.
```

---

### /project new <name> — Create a new project

1. Ask for missing info if not provided in the command:
   ```
   Creating project: <name>
   
   I need a few details:
   - Stack (e.g. "Next.js + Postgres + Vercel")
   - Local path on disk (e.g. "C:\dev\my-app")
   - One-line description
   - Initial status: active / paused / mvp
   ```

2. Create the project folder: `projects/<name>/`

3. Copy template files, replacing `{{name}}` and `{{stack}}` and `{{date}}`:
   - `projects/<name>/overview.md`
   - `projects/<name>/ideas.md`
   - `projects/<name>/decisions.md`
   - `projects/<name>/roadmap.md`

4. Fill in `overview.md` with the provided details.

5. Append a row to `projects/_REGISTRY.md` under "Active Projects":
   ```
   | <name> | active | <stack> | <path> | <description> |
   ```

6. Confirm:
   ```
   Project '<name>' created.
     overview:   projects/<name>/overview.md
     ideas:      projects/<name>/ideas.md
     decisions:  projects/<name>/decisions.md
     roadmap:    projects/<name>/roadmap.md
   
   Run /project <name> --suggest to get Claude's first-look suggestions.
   ```

---

### /project <name> — Show project overview

1. Read `projects/<name>/overview.md`.
2. Read `projects/<name>/ideas.md` — show only the last 3 ideas (most recent, by date).
3. Print a compact summary:

```
Project: <name>
Status:  active | Stack: Next.js + Postgres
Path:    C:\dev\my-app

Description:
  <description from overview>

Current focus:
  <current focus from overview>

Recent ideas (3 of N total — /project <name> --ideas to see all):
  [2026-05-12] Add dark mode toggle (medium)
  [2026-05-10] Switch to edge runtime for better latency (low)
  [2026-05-08] Add rate limiting to API (high)

Constraints to remember:
  <constraints from overview>

/project <name> --suggest   → get Claude's suggestions
/project <name> --roadmap   → view roadmap
/project <name> --decision  → log a decision
```

---

### /project <name> --ideas — Show all ideas

Read `projects/<name>/ideas.md`. Display the full backlog table, sorted by priority (high → medium → low).

Offer: "Want me to analyze these ideas and prioritize them?"

---

### /project <name> --idea "<text>" — Add an idea

Append a row to `projects/<name>/ideas.md` under "Backlog":
```
| <today's date> | <text> | User | medium | new |
```

Confirm: `Idea added to <name>. Run /project <name> --ideas to see all.`

---

### /project <name> --suggest — Claude's suggestions

This is the most valuable command. Claude analyzes the project and generates concrete, actionable suggestions.

1. Read `projects/<name>/overview.md` (full).
2. Read `projects/<name>/ideas.md` (full).
3. Read `projects/<name>/decisions.md` (full).
4. Read `projects/<name>/roadmap.md` (full).
5. If the project's local path is accessible, optionally scan its directory structure.

Then generate 3-7 suggestions in this format:

```
Suggestions for <name>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

HIGH IMPACT
  [1] Add rate limiting to the API endpoints
      Why: No rate limiting on a public API is a security and cost risk.
      How: Use upstash/ratelimit with Redis — 10 lines of middleware.
      Effort: Low (2-3 hours)

  [2] Move secrets from .env.local to the vault
      Why: Found hardcoded keys in config — risk if repo is ever made public.
      How: Run /keys to save them, then reference from .env.
      Effort: Minimal (30 min)

MEDIUM IMPACT  
  [3] Add error boundary to the React tree
      Why: Unhandled errors currently crash the whole page.
      How: Wrap app root with a simple <ErrorBoundary> component.
      Effort: Low (1 hour)

LOW IMPACT / FUTURE
  [4] Consider switching from REST to tRPC
      Why: You're already using TypeScript end-to-end — tRPC would eliminate manual type sync.
      How: Not urgent — worth considering at next architecture review.
      Effort: High (multi-day refactor)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Want me to add any of these to the project's ideas.md? (say "add all" or list numbers)
```

After user responds, append selected suggestions to `projects/<name>/ideas.md` under "Suggestions from Claude" with source "Claude".

---

### /project <name> --decision "<title>" — Log an architectural decision

1. Ask for decision details if not provided:
   ```
   Logging decision: "<title>"
   
   Context (what forced this decision)?
   Decision (what was decided)?
   Consequences (what gets easier/harder)?
   ```

2. Append to `projects/<name>/decisions.md`:
   ```markdown
   ### ADR-<next number>: <title>
   **Date:** <today>  
   **Status:** accepted  
   **Context:** <context>  
   **Decision:** <decision>  
   **Consequences:** <consequences>  
   ```

3. Confirm: `Decision logged as ADR-<N> in <name>/decisions.md`

---

### /project <name> --roadmap — Show roadmap

Read and display `projects/<name>/roadmap.md`. Offer: "Want me to suggest what to prioritize next?"

---

### /project <name> --keys — Show key names

Read `secrets/keys.md`. Find the section for `<name>`. Display key names and services only — never values.

```
Keys for <name>:
  DATABASE_URL    →  PostgreSQL (dev)
  STRIPE_KEY      →  Stripe
  OPENAI_API_KEY  →  OpenAI

Use /keys get <key-name> to retrieve a value.
```

---

### /project <name> --status <status> — Update status

1. Edit `projects/_REGISTRY.md` — find the row for `<name>`, update the Status column.
2. Edit `projects/<name>/overview.md` — update the Status line at the top.
3. Confirm: `<name> status updated to '<status>'`

---

## Error handling

- If `<name>` doesn't match any project in the registry: list similar names and suggest `/project new <name>`.
- If a vault file is missing: offer to recreate it from the template.
- If the MCP server is unavailable: tell the user to restart Claude Code (MCP needs to be active).

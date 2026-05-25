---
name: forge-skill
description: "Create a new Claude Code skill from a repeatable task pattern identified during a session. Writes the SKILL.md, registers it in the vault catalog, and optionally adds a trigger to CLAUDE.md. Trigger: /forge-skill"
trigger: /forge-skill
---

# /forge-skill

Turn a repeatable task into a permanent Claude Code skill. When a complex workflow is done manually and is likely to recur, forge it into a SKILL.md so it's always available — from any project, in any session.

## Usage

```
/forge-skill                              # interactive — Claude asks what to capture
/forge-skill "<description>"              # describe the skill to create
/forge-skill --from-session               # Claude analyzes the current session and proposes skills
/forge-skill --list                       # show all forged skills (from vault catalog)
/forge-skill --edit <skill-name>          # improve an existing forged skill
/forge-skill --remove <skill-name>        # delete a forged skill
```

---

## What You Must Do When Invoked

Skills live in: `C:\Users\Vaquin\.claude\skills\`
Vault catalog: `E:\obsidian\vault_claude_code\Claude Code\skills\_catalog.md`
Global instructions: `C:\Users\Vaquin\.claude\CLAUDE.md`

---

### /forge-skill or /forge-skill "<description>" — Create a skill

**Step 1 — Define the skill**

If no description was given, ask:
```
What task should this skill handle?

1. What triggers it? (e.g. "when I need to set up a new database schema")
2. What does it do step by step? (describe the workflow)
3. Should it have a /slash-command trigger? If so, what command?
4. Are there variations or options the user might want? (e.g. --framework, --db)
```

If a description was given, extract trigger, steps, and options from it, then confirm with a brief summary before writing.

**Step 2 — Draft the SKILL.md**

Write a complete SKILL.md following this structure:

```markdown
---
name: <skill-name>
description: "<one-line description of what it does — this appears in the skills list>"
trigger: /<command>
---

# /<command>

<What this skill does and why it exists.>

## Usage

\`\`\`
/<command>                      # default behavior
/<command> --option1            # variant 1
/<command> --option2 <arg>      # variant 2
\`\`\`

## What You Must Do When Invoked

<Step-by-step instructions Claude must follow. Be precise — treat this as executable instructions, not documentation.>

### Step 1 — <name>
<instructions>

### Step 2 — <name>
<instructions>

...

## Honesty Rules

- <What Claude must not do or assume>
- <Edge cases to handle explicitly>
```

**Step 3 — Determine the skill name and path**

- Skill name: lowercase, hyphens, no spaces (e.g. `db-migration`, `api-scaffold`)
- Path: `C:\Users\Vaquin\.claude\skills\<skill-name>\SKILL.md`

**Step 4 — Write the file**

Create the directory and write the SKILL.md.

**Step 5 — Register in vault catalog**

Append to `skills/_catalog.md` under "Forged Skills":
```
| /<command> | <skill-name> | <description> | <today's date> | <what session/task it came from> |
```

**Step 6 — Ask about CLAUDE.md trigger**

"Should this skill be auto-triggered in any context? (e.g. 'always run this when starting a React project')"

If yes, add an instruction to `C:\Users\Vaquin\.claude\CLAUDE.md`.

**Step 7 — Confirm**

```
Skill forged: /<command>

  File:     C:\Users\Vaquin\.claude\skills\<skill-name>\SKILL.md
  Trigger:  /<command>
  Catalog:  added to skills/_catalog.md

The skill is active immediately — type /<command> to use it.
```

---

### /forge-skill --from-session — Analyze session for skill candidates

Review the current conversation and identify tasks that were done that:
- Required 5+ steps to figure out
- Are likely to recur across projects
- Have a clear repeatable pattern
- Would save meaningful time if automated

Present findings:
```
Skills worth forging from this session:

  [1] Database migration workflow
      You walked through create → apply → verify → rollback pattern.
      Proposed trigger: /db-migrate
      Recurrence: any project using Prisma or Drizzle

  [2] Docker compose dev setup
      You set up postgres + redis + app in docker compose.
      Proposed trigger: /dev-compose
      Recurrence: any backend project

  [3] Not worth forging:
      The debug session was too project-specific.

Forge any of these? (say numbers or "all")
```

Then run the forge flow for each confirmed skill.

---

### /forge-skill --list — Show forged skills

Read `skills/_catalog.md`. Display the "Forged Skills" table.

---

### /forge-skill --edit <skill-name> — Improve a skill

1. Read `C:\Users\Vaquin\.claude\skills\<skill-name>\SKILL.md`.
2. Ask: "What needs to improve? (add a step, fix a command, add a variant, etc.)"
3. Make the edit. Show the diff. Confirm before writing.

---

### /forge-skill --remove <skill-name> — Delete a skill

1. Confirm: "Delete `<skill-name>` skill? This removes the SKILL.md file and the catalog entry."
2. Delete `C:\Users\Vaquin\.claude\skills\<skill-name>\SKILL.md` (and the folder if empty).
3. Remove the row from `skills/_catalog.md`.
4. Confirm deletion.

---

## When Claude should proactively offer to forge a skill

During any session, when Claude notices:

- The same multi-step task was done that Claude has done before in a different session
- A workflow was developed that took >10 minutes to figure out
- The user says "I always do this" or "I have to do this every time"
- A task spans multiple tools (file edits + shell commands + config changes) in a predictable pattern

Say: "This pattern looks repeatable — want me to forge it as a `/skill-name` skill? It'll be available from any project."

One offer. If declined, don't repeat.

---

## Quality bar for a forged skill

A skill is worth forging only if:
- It saves at least 5 minutes when reused
- It would work (with minor adaptation) in at least 2 different projects
- The steps are stable enough to codify (not highly situational)

Don't forge one-off scripts, project-specific hacks, or things that change too frequently to codify.

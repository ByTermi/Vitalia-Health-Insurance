---
name: capture
description: "Quick-capture ideas, notes, suggestions, and snippets into the Obsidian vault. Routes to inbox or directly to a project. Trigger: /capture"
trigger: /capture
---

# /capture

Zero-friction capture of anything worth saving — ideas, code snippets, decisions, links, observations. Routes to the right vault location automatically.

## Usage

```
/capture <text>                       # add to ideas inbox (fastest path)
/capture <text> --project <name>      # add directly to a project's ideas.md
/capture <text> --decision            # capture as a decision (asks for project)
/capture <url>                        # save a link to resources/links.md
/capture <url> --project <name>       # save a project-specific resource link
/capture --snippet <lang> "<code>"    # save a code snippet to snippets/<lang>.md
/capture --process                    # triage everything in ideas/inbox.md
```

---

## What You Must Do When Invoked

Base path: `E:\obsidian\vault_claude_code\Claude Code`
Use MCP filesystem tools to read/write vault files.

---

### /capture <text> — Add to inbox

Append to `ideas/inbox.md` table:
```
| <today's date> | <text> | | | new |
```

Confirm in one line: `Captured → inbox. Run /capture --process to triage.`

Do not ask for clarification. Capture first, triage later.

---

### /capture <text> --project <name> — Add to project ideas

1. Verify the project exists in `projects/_REGISTRY.md`. If not, say so and ask if they want to create it.
2. Append to `projects/<name>/ideas.md`:
   ```
   | <today's date> | <text> | User | medium | new |
   ```
3. Confirm: `Captured → <name>/ideas.md`

---

### /capture <text> --decision — Capture as a decision

1. Ask which project (if not obvious from context).
2. Delegate to `/project <name> --decision "<text>"` flow — ask for context, decision, consequences, then write the ADR.

---

### /capture <url> — Save a link

Detect if it looks like a URL (starts with http/https or is a domain).

Ask in one message: "What is this link for? (description + category: Documentation / Tool / Community / Learning)"

Append to `resources/links.md` under the appropriate section:
```
| <name/title> | <url> | <description> |
```

Confirm: `Link saved to resources/links.md`

---

### /capture <url> --project <name> — Save project resource

Same as above but note the project name in the Notes column of `resources/links.md`.

---

### /capture --snippet <lang> "<code>" — Save a code snippet

1. Check if `snippets/<lang>.md` exists. If not, create it with a header:
   ```markdown
   # <Lang> Snippets
   
   > Reusable patterns. Claude checks here before writing boilerplate.
   ```

2. Ask for a name/description if not provided.

3. Append to `snippets/<lang>.md`:
   ````markdown
   ## <description>
   
   ```<lang>
   <code>
   ```
   ````

4. Add an entry to `INDEX.md` under Snippets if this is a new language file.

Confirm: `Snippet saved to snippets/<lang>.md`

---

### /capture --process — Triage the inbox

Read `ideas/inbox.md`. For each unprocessed item (status = "new"):

1. Show the item.
2. Suggest which project it belongs to, or whether it should become a new project, or whether to discard.
3. Wait for user decision:
   - `→ <project>` — move to that project's ideas.md, mark as "triaged" in inbox
   - `new project` — run `/project new` flow
   - `discard` — mark as "discarded" in inbox
   - `keep` — leave in inbox, mark as "reviewed"

After processing all items, show a summary:
```
Inbox triaged: 5 items
  → my-app:        2 ideas added
  → api-service:   1 idea added  
  → new project:   1 project created (landing-page)
  → discarded:     1
```

---

## Autonomous capture (no explicit /capture needed)

Claude should proactively offer to capture without the user typing /capture when:

- A key design decision is made mid-session → "Want me to log this as a decision in <project>?"
- An interesting code pattern is written → "This auth middleware pattern is reusable — want me to save it to snippets?"
- A useful URL is mentioned → "Want me to save that link to the vault?"
- An idea surfaces in conversation → "That's a good idea — want me to add it to <project>/ideas.md?"
- An API key is shared in chat → "I'll save that to the vault and remove it from context — confirm?"

Keep offers brief (one line). Don't ask more than once if the user declines.

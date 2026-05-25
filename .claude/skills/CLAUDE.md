# Claude Code — Global Operating Instructions

---

# obsidian-vault

**Vault:** `E:\obsidian\vault_claude_code\Claude Code`
**MCP server:** `obsidian` (filesystem — active globally in all projects)

## Session start protocol (run every new conversation)

1. Read `INDEX.md` from the vault via MCP. Always. One file, fast.
2. Check if CWD matches any `Path` in `projects/_REGISTRY.md`. If yes, read that project's `overview.md`.
3. Read `preferences/coding.md` only if the task involves writing or reviewing code.
4. Read `preferences/communication.md` only if the task is non-trivial and preferences aren't already established.
5. Read `preferences/legal.md` if the task involves legal documents, cookie consent, GDPR, or deploying a public website.
6. Everything else: load on-demand, never pre-emptively.

## Project detection

When working in any directory, scan `projects/_REGISTRY.md` for a matching `Path`. If found:
- Load `projects/<name>/overview.md` silently (don't announce it unless it changes what you'd do).
- Use the project's stack, constraints, and current focus to inform all responses.
- If a decision is made, offer to log it: "Want me to add this to <name>/decisions.md?"

## Proactive research offer

When starting work on a content site, blog, or tool site where topic selection matters, offer:
"Want me to research trending topics in [niche]? I can pull from Reddit and Google Trends right now (`/research [niche]`)."

Only offer once per session. If the user declines, proceed without repeating.

## Legal awareness (Spain)

The user operates from Spain. All public websites must comply with GDPR + LOPDGDD + LSSI.
- Any site with cookies (analytics, AdSense) requires: Aviso Legal, Política de Privacidad, Política de Cookies.
- AdSense must NOT load before cookie consent — AEPD requires explicit opt-in, reject button equally prominent.
- For legal document generation or compliance questions: use `/legal` skill.
- Full legal context: `preferences/legal.md` in vault.

## Autonomous write-back (offer, don't force)

During any session, offer to write back to the vault when:

| Situation | Offer |
|-----------|-------|
| A design/architecture decision is made | "Log this to `<project>/decisions.md`?" |
| An idea surfaces | "Add to `<project>/ideas.md`?" |
| A useful code pattern is written | "Save to `snippets/<tech>.md`?" |
| An API key appears in chat | "Save to vault and remove from context?" |
| A useful URL is referenced | "Save to `resources/links.md`?" |
| A repeatable task >5 steps is completed | "Forge this as a skill with `/forge-skill`?" |

One offer per situation. If declined, proceed without repeating.

## Key management protocol

- Before any task requiring API access: check `secrets/keys.md` for the key. If found, use it silently.
- If a key is missing: ask the user, then offer to save it with `/keys`.
- Never write key values into source files. Always use environment variables.
- Never echo a full key value in plain text in chat.

## Autonomous skill creation

When a session involves a repeatable, multi-step workflow that would benefit from a skill:
1. Complete the task first.
2. At the end, offer: "This pattern looks reusable — forge it as a skill? (`/forge-skill --from-session`)"
3. If the user says yes, invoke the `forge-skill` skill.
4. Write the SKILL.md to `~/.claude/skills/<name>/SKILL.md`.
5. Add the entry to `skills/_catalog.md` in the vault.

Quality bar: only offer if the skill would save ≥5 minutes and applies to ≥2 projects.

---

# graphify

Skill at `~/.claude/skills/graphify/SKILL.md`.
When the user types `/graphify`, invoke the Skill tool with `skill: "graphify"` before doing anything else.

---

# Skills Reference

All skills are in `C:\Users\Vaquin\.claude\skills\`. Check `skills/_catalog.md` in the vault for the full list.

| Trigger | What it does |
|---------|-------------|
| `/project` | Create/manage projects in the vault |
| `/capture` | Quick-capture ideas, links, snippets, decisions |
| `/keys` | Store and retrieve API keys and secrets |
| `/forge-skill` | Create a new skill from a repeatable pattern |
| `/graphify` | Visualize a **codebase or research corpus** as a knowledge graph. Not for the vault — use Obsidian's native graph (Ctrl+G) there. |
| `/seo` | Full SEO audit and fix generator |
| `/serverless-backend` | Scaffold AWS/Azure/GCP serverless backends |
| `/ad-supported-frontend` | AdSense/AdMob integration with CWV safety |
| `/market-analysis` | TAM/SAM/SOM, competitors, SWOT, GTM |
| `/android-development` | Kotlin + Jetpack Compose full Android projects |
| `/cross-platform-dev` | React Native, Flutter, KMP apps |
| `/marketing` | Niche selection, keyword research, content planning, RPM optimization |
| `/i18n` | Multilingual Next.js setup (7 languages, hreflang, sitemap, translations) |
| `/research` | Live research: trending topics from Reddit, HN, Google Trends |
| `/verify` | Assess reliability/credibility of any article or blog before using it |
| `/security` | Full cybersecurity audit: secrets, CVEs, OWASP Top 10, headers, API validation |
| `/legal` | Spanish legal docs: Aviso Legal, Privacidad, Cookies, GDPR/LSSI |

When a user request clearly matches one of these skills, invoke it via the Skill tool before responding.

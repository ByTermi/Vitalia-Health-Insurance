# Claude Code Factory

A complete Claude Code setup for building ad-monetized web properties — skill library, project management vault, and MCP integrations. Drop this into your `~/.claude/` folder and Claude becomes a full-stack software factory with persistent memory, live research, and multilingual SEO built in.

---

## What's included

| Component | Location | Purpose |
|-----------|----------|---------|
| **Skills** | `skills/*/SKILL.md` | 16 slash-command workflows |
| **Obsidian vault template** | `vault/` | Project memory, preferences, decisions |
| **Global config** | `CLAUDE.md` | Session protocol, skill triggers, write-back rules |
| **MCP setup** | `settings.example.json` | Filesystem + fetch MCP servers |

---

## Prerequisites

- [Claude Code CLI](https://claude.ai/code) installed and authenticated
- [Node.js 20 LTS](https://nodejs.org/) (for MCP servers via npx)
- [Obsidian](https://obsidian.md/) (optional but recommended — for the vault)
- `pnpm` — `npm install -g pnpm`

---

## Installation

> **Principle: never overwrite, always merge.** Every step below checks for existing files before touching them. Read each step before running any command.

### 1. Clone the repository

```bash
git clone https://github.com/ByTermi/claude_code_factory.git
cd claude_code_factory
```

---

### 2. Install skills

Skills live in individual named folders. Copying a skill only overwrites that skill — it does not touch anything else. If you have customized a skill with the same name, it will be replaced.

**Check for conflicts first:**

```bash
# macOS / Linux — list which skills already exist locally
ls ~/.claude/skills/ 2>/dev/null
```
```powershell
# Windows
Get-ChildItem "$env:USERPROFILE\.claude\skills\" -Name 2>$null
```

Any name that appears in both places will be overwritten. Rename or back up the local version first if you want to keep it.

**Copy skills (safe — adds new folders, only overwrites same-named ones):**

```bash
# macOS / Linux
mkdir -p ~/.claude/skills
cp -rn skills/ ~/.claude/skills/   # -n = no-clobber, skips existing files
```

```powershell
# Windows — copies each skill folder individually, skips if already exists
$src = "skills"
$dst = "$env:USERPROFILE\.claude\skills"
New-Item -ItemType Directory -Path $dst -Force | Out-Null
Get-ChildItem $src -Directory | ForEach-Object {
    $target = Join-Path $dst $_.Name
    if (-not (Test-Path $target)) {
        Copy-Item $_.FullName $target -Recurse
        Write-Host "Installed: $($_.Name)"
    } else {
        Write-Host "Skipped (already exists): $($_.Name) — delete it first to reinstall"
    }
}
```

---

### 3. Add the global config (`CLAUDE.md`)

`CLAUDE.md` contains the session start protocol and skills reference. **Do not blindly overwrite an existing one** — you will lose your own instructions.

**If you have no `~/.claude/CLAUDE.md` yet:**
```bash
# macOS / Linux
cp CLAUDE.md ~/.claude/CLAUDE.md
```
```powershell
# Windows
Copy-Item CLAUDE.md "$env:USERPROFILE\.claude\CLAUDE.md"
```

**If you already have a `~/.claude/CLAUDE.md`**, open both files and manually append the sections you want. At minimum, add the vault path and the skills reference table from this repo's `CLAUDE.md`. Do not replace your existing instructions — add to them.

---

### 4. Add MCP servers to `settings.json`

> ⚠️ **Never copy `settings.example.json` over your existing `settings.json`.** Doing so will erase your model preference, theme, permissions, hooks, and any other MCPs you have configured.

Open your existing `~/.claude/settings.json` (create it if it doesn't exist) and **add only the `mcpServers` key**:

```jsonc
{
  // your existing settings stay here — model, theme, permissions, etc.
  // add or merge this key:
  "mcpServers": {
    "obsidian": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-filesystem",
        "/absolute/path/to/your/obsidian/vault"
      ]
    },
    "fetch": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-fetch"]
    }
  }
}
```

If you already have a `mcpServers` key, add the two server entries inside it — don't create a second `mcpServers` key.

Replace `/absolute/path/to/your/obsidian/vault` with the actual path to your vault folder. Use forward slashes even on Windows (or escape backslashes: `C:\\Users\\you\\vault`).

The MCP packages install automatically on first use via `npx` — no separate install step needed.

---

### 5. Set up the Obsidian vault (optional but recommended)

The `vault/` folder is a ready-to-use template with project management structure, preferences, and skill catalog pre-wired.

**Option A — Fresh vault (no existing vault):**
Open Obsidian → "Open folder as vault" → select the `vault/` directory from this repo. Update `vault/INDEX.md` with your own vault path.

**Option B — Merge into an existing vault:**

Do not copy the whole `vault/` folder over your existing vault — you will overwrite your own notes. Instead, copy only the subfolders that don't exist yet:

```bash
# macOS / Linux — copies only folders that don't already exist in your vault
VAULT=~/path/to/your/vault
for dir in preferences projects skills ideas resources secrets; do
  if [ ! -d "$VAULT/$dir" ]; then
    cp -r vault/$dir "$VAULT/$dir"
    echo "Copied: $dir"
  else
    echo "Skipped (already exists): $dir"
  fi
done
```

```powershell
# Windows
$vault = "C:\path\to\your\vault"
foreach ($dir in @("preferences","projects","skills","ideas","resources","secrets")) {
    $target = Join-Path $vault $dir
    if (-not (Test-Path $target)) {
        Copy-Item (Join-Path "vault" $dir) $target -Recurse
        Write-Host "Copied: $dir"
    } else {
        Write-Host "Skipped (already exists): $dir"
    }
}
```

Then manually merge `vault/INDEX.md` into your existing `INDEX.md` — copy the quick reference table rows and vault structure entries you're missing, don't replace the whole file.

**After setting up the vault**, update `CLAUDE.md` with the correct vault path:
```
Vault: /absolute/path/to/your/vault
```

---

### 6. Verify the installation

Open a terminal in any project directory and run:
```
claude
```

Type `/project list` — if you see the project management interface, everything is working.

---

## MCP Servers

Two MCP servers are pre-configured:

### `obsidian` — Filesystem access to your vault

Gives Claude read/write access to your Obsidian vault. Used for:
- Reading project context and preferences at session start
- Writing back decisions, ideas, and snippets
- Managing API keys (stored in `vault/secrets/keys.md`)

**Package:** `@modelcontextprotocol/server-filesystem`

### `fetch` — Web fetching

Allows Claude to fetch URLs without requiring user permission on each request. Used by:
- `/research` — fetches Reddit, Hacker News, Google Trends
- `/verify` — fetches articles to assess their reliability
- `/seo` — fetches competitor pages for analysis

**Package:** `@modelcontextprotocol/server-fetch`

---

## Skills Reference

Invoke any skill by typing its trigger in Claude Code.

| Trigger | What it does |
|---------|-------------|
| `/project` | Create and manage projects in the vault |
| `/capture` | Quick-capture ideas, links, decisions into the vault |
| `/keys` | Store and retrieve API keys from the vault (never in code) |
| `/forge-skill` | Create a new skill from a repeatable workflow |
| `/research` | Live research: trending topics from Reddit, HN, Google Trends |
| `/verify` | Assess reliability and credibility of articles and blogs |
| `/seo` | Full SEO audit and fix generator |
| `/marketing` | Niche selection, keyword research, content planning, RPM optimization |
| `/i18n` | Multilingual Next.js setup (7 languages, hreflang, sitemap, content) |
| `/legal` | Spanish legal docs: Aviso Legal, Privacidad, Cookies, GDPR/LSSI |
| `/ad-supported-frontend` | AdSense/AdMob integration with Core Web Vitals safety |
| `/serverless-backend` | Scaffold AWS/Azure/GCP serverless backends |
| `/market-analysis` | TAM/SAM/SOM sizing, SWOT, competitor mapping |
| `/android-development` | Kotlin + Jetpack Compose Android projects |
| `/cross-platform-dev` | React Native, Flutter, Kotlin Multiplatform |
| `/graphify` | Turn any folder into a navigable knowledge graph |

---

## Vault Structure

```
vault/
├── INDEX.md                   ← Claude reads this every session (entry point)
├── preferences/
│   ├── coding.md              ← stack, style, patterns (Next.js, TypeScript, pnpm)
│   ├── communication.md       ← tone and response format preferences
│   └── legal.md               ← Spain jurisdiction: GDPR/LOPDGDD/LSSI/AEPD
├── projects/
│   ├── _REGISTRY.md           ← all projects: status, stack, path
│   ├── _template/             ← copy this when creating a new project
│   │   ├── overview.md
│   │   ├── ideas.md
│   │   ├── decisions.md
│   │   └── roadmap.md
│   └── <project-name>/        ← created by /project new
├── ideas/
│   └── inbox.md               ← unprocessed ideas (/capture sends here)
├── secrets/
│   ├── README.md              ← security rules
│   └── keys.md                ← API keys (NOT in git — add your own)
├── skills/
│   └── _catalog.md            ← skills index
└── resources/
    └── links.md               ← useful docs and tools
```

> `vault/secrets/keys.md` is excluded from git. Create it locally and never commit it.

---

## How Claude uses this setup

**Every new session:**
1. Reads `vault/INDEX.md` (entry point — always fast, one file)
2. Detects the current project from `vault/projects/_REGISTRY.md`
3. Loads `preferences/coding.md` only if coding is involved
4. Loads `preferences/legal.md` only if building a public site or generating legal docs

**During a session, Claude proactively offers to:**
- Log design decisions → `projects/<name>/decisions.md`
- Capture ideas → `projects/<name>/ideas.md`
- Save API keys → `secrets/keys.md`
- Save reusable code patterns → `snippets/<tech>.md`
- Forge new skills from completed workflows

**When starting a content/blog project**, Claude offers:
> "Want me to research trending topics in [niche]? (`/research [niche]`)"

---

## Default Tech Stack

Preferences are pre-configured for the following stack. Change `vault/preferences/coding.md` to customize.

- **Framework:** Next.js 14+ App Router (SSG-first)
- **Language:** TypeScript (strict)
- **Package manager:** pnpm
- **Styling:** Tailwind CSS v3 + shadcn/ui
- **i18n:** next-intl (7 locales: en, de, ja, fr, es, pt-BR, zh)
- **Analytics:** Plausible (GDPR-compliant, no consent needed)
- **Consent:** vanilla-cookieconsent (AEPD/GDPR compliant)
- **Deployment:** Vercel or Cloudflare Pages

No user data management. No auth. No database. Stateless, CDN-served apps that scale to any traffic.

---

## Usage Examples

### Start a new project
```
/project new
```
Claude will ask for the project name, stack, and goal, then scaffold the vault entries.

### Research a niche before building
```
/research personal finance
```
Pulls trending topics from Reddit, HN, and Google Trends. Returns content opportunities ranked by RPM.

### Verify a source before citing it
```
/verify https://example.com/article-about-mortgages
```
Checks source credibility, citation quality, and cross-references key claims. Returns a reliability score and verdict.

### Set up multilingual support
```
/i18n --setup
```
Installs next-intl, wires 7 locales, generates hreflang metadata, and creates the multilingual sitemap.

### Generate Spanish legal pages
```
/legal --generate all
```
Creates Aviso Legal, Política de Privacidad, and Política de Cookies compliant with GDPR, LOPDGDD, LSSI, and AEPD 2023 guidelines.

### Audit SEO
```
/seo
```
Full SEO audit: technical health, metadata, structured data, Core Web Vitals, hreflang, and multilingual sitemap.

---

## Customization

### Adding your own skills

```
/forge-skill
```

Or manually: create `~/.claude/skills/<name>/SKILL.md` with the frontmatter:
```markdown
---
name: my-skill
description: "What this skill does. Trigger: /my-skill"
trigger: /my-skill
---

# /my-skill
...
```

Then add it to `vault/skills/_catalog.md`.

### Adapting for a different jurisdiction

The legal skill and `preferences/legal.md` are configured for Spain (GDPR + LOPDGDD + LSSI). To adapt:
1. Edit `vault/preferences/legal.md` with your jurisdiction's requirements
2. Edit `skills/legal/SKILL.md` to update the legal templates

### Changing the default language set

Edit the locales array in `skills/i18n/SKILL.md` and in `vault/preferences/coding.md`. The 7 defaults are revenue-ordered for AdSense: `en, de, ja, fr, es, pt-BR, zh`.

---

## Security

- `vault/secrets/keys.md` is gitignored — never committed
- Keys are stored only in the vault, never in source code
- Use `/keys set <name> <value>` to store keys through Claude
- The `.claude/settings.local.json` (machine-specific overrides) is also gitignored

---

## Contributing

1. Fork the repo
2. Create a new skill or improve an existing one
3. Test it in Claude Code
4. Submit a PR with a short description of what the skill does and when to use it

---

## License

MIT — use freely, modify as needed.

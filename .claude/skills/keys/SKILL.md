---
name: keys
description: "Manage API keys and secrets. The vault's keys.md is an index only (name, service, where stored) — actual values live in Windows SecretStore or per-project .env.local files. Never stores key values in the vault. Trigger: /keys"
trigger: /keys
---

# /keys

API key management with two principles:
1. `secrets/keys.md` is an **index** — it records that a key exists and where to find it, but never the value itself.
2. Actual values live in **Windows SecretStore** (OS-encrypted, reusable) or **`.env.local`** (per-project, gitignored).

## Storage locations

| Where | When to use | How secure |
|-------|-------------|-----------|
| Windows SecretStore | Global/reusable keys (OpenAI, Stripe, etc.) | OS-encrypted, survives vault deletion |
| `.env.local` | Project-specific keys, generated connection strings | Machine-only, gitignored |

## Usage

```
/keys                                           # list index (names, services, where stored)
/keys set <name> <service>                      # save a key — prompts for value, stores in SecretStore
/keys set <name> <service> --env <project-path> # save to .env.local instead of SecretStore
/keys get <name>                                # retrieve value from wherever it's stored
/keys env <project-path>                        # generate/update .env.local from SecretStore entries
/keys rotate <name>                             # update key value in its storage location
/keys remove <name>                             # remove from index and from SecretStore
/keys audit                                     # scan project source for hardcoded keys
/keys setup                                     # install Windows SecretStore (first-time setup)
```

---

## What You Must Do When Invoked

Index file: `E:\obsidian\vault_claude_code\Claude Code\secrets\keys.md`
Use MCP filesystem tools to read/write the index.
Use PowerShell (via Bash tool) to read/write Windows SecretStore.

**Security invariants — never break these:**
1. Never write a key value into `secrets/keys.md` or any vault file.
2. Never print a full key value in chat. If you must show it (for user verification), show only the first 8 characters followed by `...`.
3. Never write a key into source code. Only in `.env.local` (gitignored).
4. Never commit `.env.local` or `.env` to git.
5. The index entry for a key tells Claude *where to look* — not what the value is.

---

## First-time setup: `/keys setup`

Windows SecretStore must be installed once. Run:

```powershell
Install-Module Microsoft.PowerShell.SecretManagement -Scope CurrentUser -Force
Install-Module Microsoft.PowerShell.SecretStore -Scope CurrentUser -Force
Register-SecretVault -Name ClaudeFactory -ModuleName Microsoft.PowerShell.SecretStore -DefaultVault
```

Confirm setup worked:
```powershell
Get-SecretVault
```

Should show `ClaudeFactory` as registered. After this, all `/keys set` calls will store to SecretStore by default.

---

## Index format (keys.md)

The index has two sections. Never add a "Value" column.

```markdown
## Global Keys

| Key Name | Service | Stored In | Expires | Notes |
|----------|---------|-----------|---------|-------|
| OPENAI_API_KEY | OpenAI | SecretStore | 2027-01 | GPT-4, embeddings |
| ANTHROPIC_API_KEY | Anthropic | SecretStore | — | Claude API |
| STRIPE_SECRET_KEY | Stripe | SecretStore | — | Live key |

## Project Keys

### my-project
| Key Name | Service | Stored In | Expires | Notes |
|----------|---------|-----------|---------|-------|
| DATABASE_URL | Neon PostgreSQL | .env.local | — | |
| RESEND_API_KEY | Resend | SecretStore | — | Transactional email |
```

---

### /keys — List the index

Read `secrets/keys.md` and display it as-is (names, services, locations — never values).

---

### /keys set <name> <service> — Save to SecretStore (default)

1. Ask: "Paste the value for `<name>` (`<service>`) — it will not be stored in the vault."
2. Once provided, run:
```powershell
Set-Secret -Vault ClaudeFactory -Name "<name>" -Secret "<value>"
```
3. Add the index entry to `secrets/keys.md`:
```
| <name> | <service> | SecretStore | — | |
```
4. Confirm: "`<name>` saved to SecretStore. Index updated."
5. Offer: "Want me to write this to a `.env.local` file for a project?"
6. If the value appeared in chat: "Consider clearing this chat session — the value was visible in plain text."

---

### /keys set <name> <service> --env <project-path> — Save to .env.local

1. Ask for the value.
2. Append to `<project-path>/.env.local`:
```
<name>=<value>
```
3. If `.env.local` doesn't exist, create it with header:
```
# Local environment — do not commit
<name>=<value>
```
4. Verify `.env.local` is in `<project-path>/.gitignore`. If not, add it:
```
.env.local
.env
```
5. Add to index under the project section:
```
| <name> | <service> | .env.local | — | |
```
6. Confirm: "`<name>` written to `.env.local`. Index updated."

---

### /keys get <name> — Retrieve a value

1. Read the index to find the key's storage location.
2. If **SecretStore**:
```powershell
Get-Secret -Vault ClaudeFactory -Name "<name>" -AsPlainText
```
3. If **`.env.local`** in a project — read the project path from the index notes, then read the file and extract the value.
4. Display only the first 8 characters as confirmation: "`<name>`: `sk-abc123...` (truncated for safety)"
5. Ask: "Want me to write this to a specific project's `.env.local`?"

---

### /keys env <project-path> — Generate .env.local from SecretStore

1. Find the project section in the index (match by project name or path).
2. For each SecretStore key in that project:
```powershell
Get-Secret -Vault ClaudeFactory -Name "<name>" -AsPlainText
```
3. Write/update `<project-path>/.env.local`:
```
# Generated from SecretStore — do not commit
OPENAI_API_KEY=<value>
STRIPE_SECRET_KEY=<value>
```
4. Verify `.gitignore` contains `.env.local`.
5. Confirm: "`.env.local` written with N keys. File is gitignored ✓"

---

### /keys rotate <name> — Update a key value

1. Find the key in the index. Show its service and current storage location.
2. Ask: "New value for `<name>` (`<service>`)?"
3. Update in SecretStore:
```powershell
Set-Secret -Vault ClaudeFactory -Name "<name>" -Secret "<new-value>"
```
   Or update `.env.local` if that's where it lives.
4. Confirm: "`<name>` rotated. Run `/keys env <project>` to push the new value to project `.env.local` files."

---

### /keys remove <name> — Delete a key

1. Find the key in the index. Show service and storage location.
2. Confirm: "Remove `<name>` (`<service>`) from index and SecretStore?"
3. Remove from SecretStore:
```powershell
Remove-Secret -Vault ClaudeFactory -Name "<name>"
```
4. Remove the row from the index.
5. Confirm: "`<name>` removed."

---

### /keys audit — Find leaked keys in source

Scan the current project directory for strings that look like key values:

Patterns to search for:
- `sk-` (OpenAI)
- `pk_live_`, `sk_live_`, `rk_` (Stripe)
- `ghp_`, `github_pat_` (GitHub)
- `xoxb-`, `xoxp-` (Slack)
- `SG.` (SendGrid)
- `Bearer ` followed by a long string
- `postgres://`, `mongodb+srv://`, `mysql://` with credentials
- Long random strings (32+ chars) assigned to variables named `KEY`, `SECRET`, `TOKEN`, `PASSWORD`

Scan these file types: `.ts`, `.tsx`, `.js`, `.jsx`, `.py`, `.env.example`, `.json` (non-lock), `.yaml`, `.toml`

Skip: `.env`, `.env.local`, `node_modules/`, `*.lock`

Report:
```
Key audit: C:\dev\my-project
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠ Potential exposures:
  src/lib/openai.ts:8    OPENAI_API_KEY = "sk-abc..."   → move to process.env
  README.md:34           mongodb+srv://user:pass@...     → rotate immediately

✓ Clean files checked: 47
✓ .gitignore contains: .env, .env.local ✓

Action: run /keys rotate for any key that appeared in a file that was ever committed.
```

---

## Autonomous detection (no /keys needed)

Proactively offer to save keys when:
- User pastes something that matches a key pattern in chat
- A `.env` file is read during a session and contains values not in the index
- Hardcoded secrets are found during a code review

Offer: "That looks like an API key. Want me to save it to SecretStore and remove it from chat?"

One offer, no nagging.

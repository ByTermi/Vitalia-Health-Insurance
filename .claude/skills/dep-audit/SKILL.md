---
name: dep-audit
description: "Audit project dependencies for security vulnerabilities and outdated packages. Auto-updates safe patches, asks before minor/major bumps, and reports findings to Obsidian. Trigger: /dep-audit"
trigger: /dep-audit
---

# /dep-audit

Dependency health audit: security vulnerabilities (pnpm/npm audit + CVE cross-reference), outdated packages, and safe automated updates.

## Usage

```
/dep-audit                   # full audit: security + outdated
/dep-audit --security        # vulnerabilities only
/dep-audit --outdated        # outdated packages only
/dep-audit --fix             # auto-apply safe patch updates (no breaking changes)
/dep-audit --interactive     # walk through each outdated package and decide together
```

---

## What You Must Do When Invoked

### Step 1 — Detect package manager

```powershell
if (Test-Path "pnpm-lock.yaml") { "pnpm" }
elseif (Test-Path "yarn.lock") { "yarn" }
else { "npm" }
```

### Step 2 — Security audit

**pnpm:**
```powershell
pnpm audit --json 2>&1 | ConvertFrom-Json
```
**npm:**
```powershell
npm audit --json 2>&1 | ConvertFrom-Json
```

Parse: package name, severity (critical/high/moderate/low), CVE ID, affected version range, patched version, whether it's a dev dependency.

Group findings:
| Severity | Action |
|----------|--------|
| critical / high | Flag immediately — block deployment if unpatched |
| moderate | Fix before next release |
| low | Fix when convenient |
| dev-only | Lower urgency — doesn't affect production bundle |

### Step 3 — Outdated packages

```powershell
pnpm outdated --format json 2>&1  # or npm outdated --json
```

For each outdated package, classify the update type:
- **Patch** (1.2.3 → 1.2.4): Safe. Auto-update with `--fix`.
- **Minor** (1.2.x → 1.3.x): Usually safe, but breaking changes possible. Ask user.
- **Major** (1.x → 2.x): Almost certainly has breaking changes. Requires review.

Flag framework packages (next, react, tailwindcss, typescript) separately — these need extra care.

### Step 4 — Auto-fix patch vulnerabilities (only if --fix passed)

```powershell
pnpm audit --fix  # or npm audit fix
```

Then verify build still passes:
```powershell
npx tsc --noEmit 2>&1 | Select-Object -First 10
```

If TypeScript fails after patching, **revert** the specific package and report it as NEEDS_REVIEW.

### Step 5 — Interactive walk-through (only if --interactive)

For each outdated package (minor and major):
1. Show: current version → latest, changelog URL if available, what the package does.
2. Ask: "Update X from 1.2 → 1.4? [yes/no/skip]"
3. If yes: update, run tsc check, report result.
4. If build breaks after update: revert and mark as NEEDS_REVIEW.

### Step 6 — Report

Print summary:
```
Dependency Audit — <project>

Security:
  🔴 Critical: N  (auto-fixed: M)
  🟠 High:     N  (auto-fixed: M)
  🟡 Moderate: N
  🔵 Low:      N

Outdated:
  Patch updates available: N  (auto-applied with --fix)
  Minor updates available: N  (review recommended)
  Major updates available: N  (manual migration required)

Notable:
  - next: 15.1.2 → 15.5.18 (minor — changelog: ...)
  - react: 19.0.0 → 19.1.0 (patch — auto-applied)
```

### Step 7 — Write Obsidian report

Write to `projects/<name>/deps/YYYY-MM-DD-audit.md` in the vault:
```markdown
# Dependency Audit — YYYY-MM-DD

## Security Vulnerabilities
| Package | Severity | CVE | Patched in | Dev only? | Status |
|---------|----------|-----|------------|-----------|--------|

## Outdated Packages
| Package | Current | Latest | Type | Action |
|---------|---------|--------|------|--------|

## Auto-applied Patches
- package@old → package@new
```

---

## Rules

- Never update major versions without explicit user approval per package.
- Always run `tsc --noEmit` after any update and revert if it fails.
- Dev-only vulnerabilities get a lower urgency label but are still reported.
- If the audit reveals a CVE with a public exploit, say so clearly.
- Never silently skip a failed update — always report what was reverted and why.

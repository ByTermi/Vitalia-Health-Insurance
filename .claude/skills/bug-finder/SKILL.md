---
name: bug-finder
description: "Scan the codebase for bugs (TypeScript errors, runtime errors, logic errors, broken imports), fix them automatically, and write a bug report to the Obsidian vault. Trigger: /bug-finder"
trigger: /bug-finder
---

# /bug-finder

Find bugs, fix them, report what changed. Covers TypeScript type errors, runtime errors, broken imports, logic errors, and common React/Next.js pitfalls.

## Usage

```
/bug-finder                  # full scan + fix on current project
/bug-finder --scan-only      # find only, do not apply fixes
/bug-finder <path>           # scope to a specific file or directory
/bug-finder --type ts        # TypeScript errors only
/bug-finder --type runtime   # runtime/logic errors only
/bug-finder --type imports   # broken imports/exports only
```

---

## What You Must Do When Invoked

### Step 1 — Identify project type

Read `package.json` to determine stack (Next.js, React, Node, etc.) and `tsconfig.json` for TypeScript config. Note the project name — you'll need it for the Obsidian report.

### Step 2 — Run automated scanners in parallel

Run all applicable scanners simultaneously:

**TypeScript errors:**
```powershell
cd <project-root>; npx tsc --noEmit 2>&1
```
Parse output: extract file path, line number, error code, message for each error.

**Lint errors (if ESLint configured):**
```powershell
npx eslint . --ext .ts,.tsx --format json 2>&1
```

**Import resolution check:**
Grep for broken imports by looking for `Cannot find module` patterns in the tsc output. Also check for files that import from paths that don't exist on disk.

**Next.js specific checks (if Next.js project):**
- `'use client'` on server components that use server-only APIs
- Missing `key` props in `.map()` calls
- `<img>` tags instead of Next.js `<Image>`
- `useEffect` with missing dependencies
- Hardcoded `localhost` URLs in non-dev code

### Step 3 — Triage findings

Group bugs by severity:

| Severity | Criteria |
|----------|----------|
| 🔴 CRITICAL | Build-breaking: TypeScript errors that prevent compilation, broken imports that crash at runtime |
| 🟠 HIGH | Logic errors, incorrect hook usage, missing error boundaries on async operations |
| 🟡 MEDIUM | Missing `key` props, `useEffect` dependency issues, type `any` usage |
| 🔵 LOW | Lint warnings, style inconsistencies, dead code |

If `--scan-only` was passed: print the triage table and stop here. Do not modify any files.

### Step 4 — Fix bugs (unless --scan-only)

Fix bugs in order of severity. For each fix:

1. Read the file first (always).
2. Apply the minimal change that resolves the bug. Do not refactor surrounding code.
3. Re-run the relevant scanner on that file to confirm the fix.
4. If a fix requires user input (e.g., the correct value for a broken import path is ambiguous), **ask the user** before guessing.

**Never:**
- Delete a feature or component to fix a bug — ask the user instead.
- Change public API signatures without asking.
- Apply a fix you're not confident about — mark it as NEEDS_REVIEW instead.

### Step 5 — Write Obsidian bug report

Determine the vault path from global CLAUDE.md (`E:\obsidian\vault_claude_code\Claude Code`). Find the matching project in `projects/_REGISTRY.md`. Write the report to `projects/<project-name>/bugs/YYYY-MM-DD-bug-report.md`.

Report format:
```markdown
# Bug Report — YYYY-MM-DD

**Project:** <name>
**Scanner:** /bug-finder
**Bugs found:** N
**Bugs fixed:** M
**Needs review:** K

---

## Fixed

### 🔴 [CRITICAL] Short title
- **File:** `path/to/file.tsx:42`
- **Error:** Original error message
- **Fix:** One-line description of what changed
- **Confidence:** High / Medium

### 🟡 [MEDIUM] Short title
...

---

## Needs Review

### [ISSUE] Short title
- **File:** `path/to/file.tsx:88`
- **Issue:** Description
- **Why not auto-fixed:** Reason (ambiguous import path, needs user decision, etc.)

---

## Scan Summary

| Category | Found | Fixed |
|----------|-------|-------|
| TypeScript | N | N |
| Imports | N | N |
| React/Next.js | N | N |
| Lint | N | N |
```

### Step 6 — Report to user

Print a concise summary in chat:
- Total bugs found / fixed
- Any NEEDS_REVIEW items (with the question you need answered)
- Path to the Obsidian report

Then offer: "Want me to add this to the project decisions log as well?"

---

## Rules

- Always read a file before editing it.
- One bug = one focused fix. Don't bundle unrelated changes.
- If fixing bug A would require breaking change B, surface it and ask.
- Pre-existing errors that were there before this session are noted but marked `[pre-existing]` in the report — you fix them only if the user asks.
- When uncertain about the intended behavior, ask before fixing.

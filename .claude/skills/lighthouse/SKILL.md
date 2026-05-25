---
name: lighthouse
description: "Run Lighthouse audits against the local dev server or a URL, interpret results with dev-environment awareness, and propose safe performance/accessibility improvements. Asks before removing any visual element or feature. Trigger: /lighthouse"
trigger: /lighthouse
---

# /lighthouse

Run Lighthouse reports, interpret them correctly for the current environment (dev server ≠ production CDN), and propose improvements that won't break the project.

## Usage

```
/lighthouse                          # audit http://localhost:3000 (or 3001 if 3000 is busy)
/lighthouse <url>                    # audit a specific URL
/lighthouse --category performance   # single category only
/lighthouse --category accessibility
/lighthouse --category seo
/lighthouse --category best-practices
/lighthouse --mobile                 # mobile viewport (default is desktop)
/lighthouse --fix                    # apply safe, non-visual improvements automatically
/lighthouse --report-only            # generate report, no suggestions
```

---

## Critical Context: Dev vs Production

**Always tell the user upfront** which environment you're auditing and what that means for scores:

| Metric | Dev server impact | Why |
|--------|------------------|-----|
| Performance score | 30-40 pts lower | No minification, no CDN, no compression, source maps loaded |
| LCP / FCP | 2-5× slower | Cold webpack/Turbopack compilation on first request |
| Unused JavaScript | Much higher | Dev bundles include HMR, error overlays, source maps |
| Cache headers | Missing | Dev server doesn't set long-lived cache headers |

**Never suggest removing a feature because Lighthouse penalizes it in dev.** Always check if the issue exists in a production build (`pnpm build && pnpm start`) before recommending removal.

---

## What You Must Do When Invoked

### Step 1 — Find the running server

```powershell
# Check common ports
@(3000, 3001, 3002, 4000, 8080) | ForEach-Object {
  $r = try { Invoke-WebRequest -Uri "http://localhost:$_" -TimeoutSec 2 -UseBasicParsing -ErrorAction Stop; $true } catch { $false }
  if ($r) { Write-Host "Found server on port $_"; $_ }
} | Select-Object -First 1
```

If no server is found, tell the user to start the dev server first and stop.

### Step 2 — Check Lighthouse CLI is available

```powershell
lighthouse --version 2>&1
```

If not installed:
```powershell
npm install -g lighthouse
```

### Step 3 — Run Lighthouse

```powershell
lighthouse http://localhost:<PORT> `
  --output=json `
  --output-path="$env:TEMP\lh-report.json" `
  --chrome-flags="--headless --no-sandbox" `
  --only-categories=performance,accessibility,best-practices,seo `
  --quiet 2>&1
```

If `--mobile` was passed, omit `--preset=desktop`. Default to desktop (typical for travel/content sites).

If the command fails (Chrome not found, etc.), try:
```powershell
lighthouse http://localhost:<PORT> `
  --output=json `
  --output-path="$env:TEMP\lh-report.json" `
  --chrome-flags="--headless --disable-gpu --no-sandbox --disable-dev-shm-usage" `
  --quiet 2>&1
```

### Step 4 — Parse and display results

Read `$env:TEMP\lh-report.json`. Extract:
- Overall scores per category (0-100)
- Top 5 failing audits per category by impact
- Core Web Vitals: LCP, FID/INP, CLS, FCP, TTFB

Display as:
```
Lighthouse Report — http://localhost:3001 (DEV SERVER)
⚠️  Dev scores are typically 30-40 pts lower than production.

Performance:     72/100  (est. prod: ~85-90)
Accessibility:   94/100
Best Practices:  83/100
SEO:             91/100

Core Web Vitals (dev baseline):
  LCP:  2.8s   🟡 Needs improvement
  CLS:  0.02   🟢 Good
  FCP:  1.2s   🟢 Good
  TTFB: 320ms  🟢 Good
```

### Step 5 — Triage issues

For each failing audit, classify it:

**Category A — Safe to fix automatically:**
- Images missing `width`/`height` attributes → add them
- Missing `alt` attributes on `<img>` → add descriptive ones
- Missing `<meta name="description">` → add from existing content
- Links without discernible text → add `aria-label`
- Form elements missing labels → add `<label>`
- Missing `lang` attribute on `<html>` → already handled or easy fix
- Console errors → investigate and fix

**Category B — Dev-environment artifacts (DO NOT suggest removing):**
- Large JavaScript bundles → explain it's a dev artifact, check production first
- Unused CSS → explain it's Tailwind JIT in dev mode
- Render-blocking resources → check if it's source maps / HMR
- Slow server response time → note it's a cold-start dev artifact
- `cache-control` headers missing → dev server behavior, not app code

**Category C — Need user approval before touching:**
- Removing a visual element that affects UX
- Removing a script that provides functionality
- Changing font loading strategy (might affect FOUT)
- Disabling animations (affects branding)
- Changing hero image (affects above-the-fold)

For Category C items, **always ask the user first**:
> "Lighthouse flagged [X] as a performance issue. Fixing it would [specific change]. This affects [what users see/do]. Should I make this change?"

### Step 6 — Apply safe fixes (only if --fix was passed)

Apply all Category A fixes. For each fix:
1. Read the file.
2. Apply minimal change.
3. Note it in the report.

Do NOT touch Category B or C without explicit user approval.

### Step 7 — Write improvement plan

Present a prioritized table:

```
## Improvement Plan

### Safe to fix now (Category A)
| Issue | File | Fix | Est. impact |
|-------|------|-----|-------------|
| Missing alt on flag images | CountryCard.tsx | Add alt="" (decorative) | +3 Accessibility |
| ...

### Check in production build first (Category B)
| Issue | Why it's a dev artifact | How to verify |
|-------|------------------------|---------------|
| 847KB JS bundle | Includes HMR and source maps | Run pnpm build && pnpm start |
| ...

### Needs your decision (Category C)
| Issue | What would change | Impact |
|-------|------------------|--------|
| Hero image not preloaded | Add <link rel="preload"> | +5 LCP |
| ...
```

Then ask: "Want me to apply the Category A fixes now?"

### Step 8 — Save report to Obsidian (optional)

If the user asks, save to `projects/<name>/lighthouse/YYYY-MM-DD-report.md` in the vault.

---

## Rules

- Never frame dev scores as production scores.
- Never remove UI elements or features without user approval.
- Never suggest disabling animations as a performance fix without asking.
- Always distinguish between "fix this in code" and "this is a dev artifact."
- If a fix requires a production build to verify, say so clearly.
- One audit per session — don't run Lighthouse in a loop.

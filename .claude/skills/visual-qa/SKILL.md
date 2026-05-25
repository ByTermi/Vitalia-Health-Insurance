---
name: visual-qa
description: "Autonomously open a browser with Playwright, navigate all routes, capture screenshots and console/network errors, then analyze screenshots with vision to find visual and functional bugs. Trigger: /visual-qa"
trigger: /visual-qa
---

# /visual-qa

Autonomous browser QA. Opens a real browser, visits every page of the site, captures screenshots + console errors + network failures, and uses Claude's vision to identify visual and functional bugs — without any human interaction.

## Usage

```
/visual-qa                        # full scan of all routes, desktop viewport
/visual-qa --mobile               # 375×812 mobile viewport
/visual-qa --dark                 # enable dark mode before scanning
/visual-qa --interactive          # also test clicks: nav links, dropdowns, theme toggle, lang switcher
/visual-qa --route /en/           # scan a single specific route
/visual-qa --url http://...       # scan an external URL (production, staging)
/visual-qa --mobile --dark        # combine flags
```

---

## What You Must Do When Invoked

### Step 1 — Find the running server

```powershell
$port = $null
foreach ($p in @(3000, 3001, 3002, 4000, 8080)) {
  try {
    $null = Invoke-WebRequest -Uri "http://localhost:$p" -TimeoutSec 2 -UseBasicParsing -ErrorAction Stop
    $port = $p; break
  } catch {}
}
if (-not $port) { Write-Host "ERROR: No dev server found. Start it first (pnpm dev)."; exit 1 }
Write-Host "Found server on port $port"
```

If `--url` was passed, skip this step and use that URL directly.

### Step 2 — Ensure Playwright is available

```powershell
node -e "require('playwright')" 2>$null
if ($LASTEXITCODE -ne 0) {
  Write-Host "Installing Playwright..."
  npm install -g playwright
  npx playwright install chromium
}
```

If already installed, skip silently.

### Step 3 — Discover routes to test

Read the project's route structure from `app/[locale]/` directory. Collect all `page.tsx` files and derive their URL paths. Build the full list of routes to test using the default locale (`en`).

Example for Travel Hub:
- `/en/`
- `/en/visa/`
- `/en/country/`
- `/en/tools/`
- `/en/tools/schengen-counter/`
- `/en/tools/currency-converter/`
- `/en/tools/time-zone-planner/`
- `/en/tools/packing-list/`
- `/en/currency/`
- `/en/holidays/`
- `/en/power-plugs/`
- `/en/about/`
- `/en/contact/`

If `--route` was passed, only test that one route.

Cap at 20 routes per run to avoid very long sessions. If more routes exist, test the most important ones first (home, main sections, tools) and tell the user which were skipped.

### Step 4 — Write and run the Playwright capture script

Write this script to `$env:TEMP\vqa-capture.mjs`, then run it:

```powershell
$screenshotDir = "$env:TEMP\vqa-screenshots"
New-Item -ItemType Directory -Force -Path $screenshotDir | Out-Null

$script = @"
import { chromium } from 'playwright';
import { writeFileSync, mkdirSync } from 'fs';
import { join } from 'path';

const BASE = 'BASE_URL';
const ROUTES = ROUTES_ARRAY;
const MOBILE = MOBILE_FLAG;
const DARK = DARK_FLAG;
const INTERACTIVE = INTERACTIVE_FLAG;
const OUT_DIR = 'SCREENSHOT_DIR';

const viewport = MOBILE
  ? { width: 375, height: 812 }
  : { width: 1440, height: 900 };

const report = { routes: [], interactions: [], timestamp: new Date().toISOString() };

const browser = await chromium.launch({ headless: true });
const context = await browser.newContext({
  viewport,
  colorScheme: DARK ? 'dark' : 'light',
  deviceScaleFactor: 1,
});

// Intercept console and network for all pages
context.on('page', page => {
  page._consoleErrors = [];
  page._networkErrors = [];
  page.on('console', msg => {
    if (msg.type() === 'error' || msg.type() === 'warning') {
      page._consoleErrors.push({ type: msg.type(), text: msg.text() });
    }
  });
  page.on('requestfailed', req => {
    page._networkErrors.push({ url: req.url(), failure: req.failure()?.errorText });
  });
  page.on('response', resp => {
    if (resp.status() >= 400) {
      page._networkErrors.push({ url: resp.url(), status: resp.status() });
    }
  });
});

for (const route of ROUTES) {
  const page = await context.newPage();
  const url = BASE + route;
  const slug = route.replace(/\//g, '_').replace(/^_/, '') || 'home';

  let routeReport = { route, url, slug, consoleErrors: [], networkErrors: [], screenshotFile: null, error: null };

  try {
    await page.goto(url, { waitUntil: 'networkidle', timeout: 15000 });

    // Apply dark mode class if needed (for class-based dark mode)
    if (DARK) {
      await page.evaluate(() => document.documentElement.classList.add('dark'));
      await page.waitForTimeout(300);
    }

    // Scroll to trigger lazy-loaded content
    await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight / 2));
    await page.waitForTimeout(400);
    await page.evaluate(() => window.scrollTo(0, 0));
    await page.waitForTimeout(200);

    const screenshotPath = join(OUT_DIR, slug + '.png');
    await page.screenshot({ path: screenshotPath, fullPage: true });
    routeReport.screenshotFile = screenshotPath;

    // Check for overflow elements
    const overflowIssues = await page.evaluate(() => {
      const issues = [];
      document.querySelectorAll('*').forEach(el => {
        if (el.scrollWidth > el.clientWidth + 5 && el.clientWidth > 0) {
          const tag = el.tagName.toLowerCase();
          const cls = el.className?.toString().slice(0, 60) || '';
          issues.push({ element: tag + (cls ? '.' + cls.split(' ')[0] : ''), scrollWidth: el.scrollWidth, clientWidth: el.clientWidth });
        }
      });
      return issues.slice(0, 5); // top 5 overflow issues
    });

    if (overflowIssues.length > 0) routeReport.overflowIssues = overflowIssues;

    // Check for broken images
    const brokenImages = await page.evaluate(() =>
      Array.from(document.images)
        .filter(img => !img.complete || img.naturalWidth === 0)
        .map(img => img.src)
    );
    if (brokenImages.length > 0) routeReport.brokenImages = brokenImages;

    routeReport.consoleErrors = page._consoleErrors || [];
    routeReport.networkErrors = (page._networkErrors || []).filter(e =>
      !e.url?.includes('favicon') && !e.url?.includes('hot-update')
    );

    // Interactive tests
    if (INTERACTIVE) {
      // Test nav links hover (visual only — no navigation)
      const navLinks = await page.$$('header nav a');
      routeReport.navLinksFound = navLinks.length;

      // Test language switcher
      try {
        const langBtn = await page.$('button[aria-label*="language" i], button[aria-label*="lang" i]');
        if (langBtn) {
          await langBtn.click();
          await page.waitForTimeout(300);
          const dropdownShot = join(OUT_DIR, slug + '_lang-dropdown.png');
          await page.screenshot({ path: dropdownShot, fullPage: false });
          routeReport.langDropdownScreenshot = dropdownShot;
          await page.keyboard.press('Escape');
        }
      } catch {}

      // Test theme toggle
      try {
        const themeBtn = await page.$('button[aria-label*="dark" i], button[aria-label*="light" i], button[aria-label*="theme" i]');
        if (themeBtn) {
          await themeBtn.click();
          await page.waitForTimeout(400);
          const afterToggle = join(OUT_DIR, slug + '_after-theme-toggle.png');
          await page.screenshot({ path: afterToggle, fullPage: false });
          routeReport.themeToggleScreenshot = afterToggle;
          await themeBtn.click(); // toggle back
        }
      } catch {}

      // Test mobile menu (if mobile viewport)
      if (MOBILE) {
        try {
          const menuBtn = await page.$('button[aria-label*="menu" i], button[aria-label*="toggle" i]');
          if (menuBtn) {
            await menuBtn.click();
            await page.waitForTimeout(300);
            const menuShot = join(OUT_DIR, slug + '_mobile-menu.png');
            await page.screenshot({ path: menuShot, fullPage: false });
            routeReport.mobileMenuScreenshot = menuShot;
          }
        } catch {}
      }
    }

  } catch (err) {
    routeReport.error = err.message;
  }

  report.routes.push(routeReport);
  await page.close();
}

await browser.close();
writeFileSync(join(OUT_DIR, '_report.json'), JSON.stringify(report, null, 2));
console.log('DONE:' + JSON.stringify({ routes: report.routes.length, screenshots: report.routes.filter(r => r.screenshotFile).length }));
"@

$script | Set-Content "$env:TEMP\vqa-capture.mjs" -Encoding utf8
node "$env:TEMP\vqa-capture.mjs" 2>&1
```

Replace placeholders:
- `BASE_URL` → `http://localhost:<PORT>` or the `--url` value
- `ROUTES_ARRAY` → JSON array of route strings
- `MOBILE_FLAG` → `true` or `false`
- `DARK_FLAG` → `true` or `false`
- `INTERACTIVE_FLAG` → `true` or `false`
- `SCREENSHOT_DIR` → `$env:TEMP\vqa-screenshots` (with forward slashes for JS)

### Step 5 — Read the JSON report

Read `$env:TEMP\vqa-screenshots\_report.json`. Parse:
- Any routes that errored (failed to load)
- Console errors per route
- Network failures per route
- Broken images per route
- Overflow issues per route

### Step 6 — Analyze screenshots with vision

For each route that has a screenshot, use the Read tool to view the PNG file. Analyze it as a QA tester would:

**Visual checks for each screenshot:**
- Header visible and correct? Logo, nav links, theme toggle, lang switcher present?
- No text overflowing containers
- No broken layout (elements on top of each other, content cut off)
- Images loading (no broken image icons)
- Colors look correct for the current mode (light/dark)
- Fonts loaded (no fallback system font visible)
- CTAs visible and not hidden behind other elements
- Footer visible at bottom
- No empty sections (missing content shows as large blank areas)
- Spacing looks consistent — no collapsed margins, no unexpected gaps
- Mobile: no horizontal scroll bar, content fits viewport
- Hero section renders correctly
- Cards (tool cards, country cards) display data correctly

**Functional checks from the JSON report:**
- JS errors in console → note the error message and which page
- 404 image responses → note the broken asset URL
- Failed API calls → note the endpoint
- Overflow elements → note which component is overflowing

**Interactive checks (if --interactive):**
- Language dropdown appears and is readable
- Theme toggle works (before/after screenshots show color change)
- Mobile menu opens and items are tappable

### Step 7 — Compile bug report

Present findings grouped by severity:

```
Visual QA Report — http://localhost:3001 (desktop, light mode)
Tested: 12 routes | Screenshots: 12 | Time: ~45s

🔴 CRITICAL (blocks users)
───────────────────────────
[/en/tools/] Nav links invisible — white text on white background
  → Screenshot: vqa-screenshots/en_tools_.png

🟠 HIGH (significant visual defect)
───────────────────────────
[/en/] Hero CTA button overflows on mobile (tested at 1440px but element width exceeds container)
  → Element: button.rounded-full, scrollWidth: 892, clientWidth: 840

🟡 MEDIUM (noticeable but not blocking)
───────────────────────────
[/en/country/] Flag images return 404 for 3 countries (VN, MM, KH)
  → Network error: https://flagcdn.com/vn.svg → 404
[/en/tools/schengen-counter/] Console error: "TypeError: Cannot read properties of undefined"
  → Likely a data loading issue

🔵 LOW (minor polish)
───────────────────────────
[/en/about/] Large blank section — content may be missing or not loading
[/en/contact/] Uses hardcoded gray colors (not dark-mode aware)

✅ PASSED
───────────────────────────
/en/ — Layout correct, hero renders, stats visible, tool cards correct
/en/visa/ — Page loads, form elements visible
/en/currency/ — Currency list renders correctly
... (N more)
```

### Step 8 — Write Obsidian report (optional, ask user)

If the user confirms, write to `projects/<name>/qa/YYYY-MM-DD-visual-qa.md` in the vault at `E:\obsidian\vault_claude_code\Claude Code`.

### Step 9 — Clean up temp files

```powershell
Remove-Item "$env:TEMP\vqa-capture.mjs" -ErrorAction SilentlyContinue
# Keep screenshots in case user wants to review them manually
Write-Host "Screenshots saved to: $env:TEMP\vqa-screenshots\"
```

---

## Rules

- **Never navigate away from localhost in the browser** unless `--url` explicitly points to an external host.
- **Do not fill in or submit any forms** with real data — only check that form elements are visible and accessible.
- **Do not click links that navigate to new pages** during the interactive scan — use Playwright's `page.$()` click for UI components only (dropdowns, toggles, menus).
- If a page takes more than 15 seconds to load, mark it as a timeout error and continue with the next route.
- If Playwright can't be installed (no Node.js, corporate proxy, etc.), fall back to telling the user what to manually check — do not silently fail.
- Screenshots are the source of truth for visual bugs. If the JSON report shows an error but the screenshot looks fine, note both.
- Dev server artifacts (HMR overlay, React error boundary screen) are bugs — report them.
- If you see a completely blank page in the screenshot, that's always a 🔴 CRITICAL bug regardless of the JSON report.

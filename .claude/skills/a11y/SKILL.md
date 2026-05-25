---
name: a11y
description: "Accessibility audit for Next.js/React projects: WCAG 2.1 AA checks, dark mode contrast, form labels, keyboard nav, ARIA, semantic HTML. Ranks findings and auto-fixes safe issues."
trigger: /a11y
---

# /a11y

Full accessibility audit for Next.js + Tailwind projects. Checks WCAG 2.1 AA compliance, dark mode contrast, missing ARIA labels, form labeling, keyboard navigation, and semantic HTML. Ranks findings by severity and auto-fixes safe mechanical issues (alt text, aria-label, role).

## Usage

```
/a11y                        # full audit — all checks
/a11y --contrast             # color contrast audit only (light + dark mode)
/a11y --forms                # form labeling and input accessibility only
/a11y --keyboard             # focus management and keyboard nav only
/a11y --dark                 # dark mode token audit — find hardcoded colors that break in dark
/a11y --fix                  # auto-apply safe fixes (missing alt="", decorative aria-hidden, etc.)
/a11y <path>                 # audit a specific file or directory
```

---

## Severity Levels

| Severity | Meaning |
|----------|---------|
| 🔴 CRITICAL | Blocks users with disabilities entirely (missing form label, keyboard trap) |
| 🟠 HIGH | Fails WCAG AA — will fail automated audits (missing alt, low contrast) |
| 🟡 MEDIUM | Degrades experience significantly (missing focus ring, poor ARIA) |
| 🔵 LOW | Best practice — passes WCAG but can be improved |
| ⚪ INFO | Informational, no action required |

---

## What You Must Do When Invoked

### Step 1 — Discover project structure

```
Glob: app/**/*.tsx, components/**/*.tsx
Read: app/globals.css (extract CSS custom properties for light + dark mode tokens)
Read: tailwind.config.* or check @theme block in globals.css
```

Extract the semantic color token map — both light and dark values. You need this to evaluate contrast.

---

### Step 2 — Dark mode token audit (--dark)

**Goal:** find any hardcoded Tailwind color classes (`bg-white`, `bg-gray-*`, `text-gray-*`, `border-gray-*`, `text-blue-*`, `bg-blue-*`) that do NOT adapt in dark mode.

Grep all component and page files:
```
pattern: \b(bg-white|bg-gray-\d+|text-gray-\d+|border-gray-\d+|bg-blue-\d+|text-blue-\d+|text-deep)\b
glob: **/*.tsx
```

For each match:
- Check if the same element has a `dark:` override counterpart on the same className string
- If NO `dark:` override: flag as 🟠 HIGH — will render wrong in dark mode
- Report: file, line, the hardcoded class, and the correct semantic token to use

**Semantic token mapping for this project:**

| Hardcoded | Semantic replacement |
|-----------|---------------------|
| `bg-white` | `bg-surface` |
| `bg-gray-50` / `bg-gray-100` | `bg-foam` |
| `text-gray-900` / `text-gray-800` | `text-ink` |
| `text-gray-600` / `text-gray-700` | `text-ink-soft` |
| `text-gray-400` / `text-gray-500` | `text-mist-text` |
| `border-gray-100` / `border-gray-200` | `border-line` |
| `border-gray-300` | `border-line` |
| `text-blue-600` / `text-blue-700` | `text-ocean` |
| `bg-blue-600` | `bg-ocean` |
| `bg-blue-50` / `bg-blue-100` | `bg-foam` or `bg-ocean/10` |
| `text-deep` (on dark bg) | `text-ink` |
| `focus:ring-blue-500` | `focus:ring-ocean` |

Auto-fix with --fix: replace hardcoded classes with their semantic equivalents in all flagged files.

---

### Check 3 — Missing `alt` text on images (🟠 HIGH)

```
Grep pattern: <img\b(?![^>]*\balt=)
glob: **/*.tsx
```

Also grep:
```
Grep pattern: <img[^>]+alt="[^"]{1,}"
```
to find images with non-empty alt — verify the alt text is descriptive (not just "image" or the filename).

For decorative images (icons, backgrounds), `alt=""` is correct — verify these have `aria-hidden="true"` too if they use an SVG wrapper.

If using Next.js `<Image>` component, verify `alt` prop is present and non-empty.

Auto-fix with --fix:
- Add `alt=""` to images that are clearly decorative (inside `<button>`, `<a>`, or `aria-hidden` context)
- For content images, flag and report without auto-fixing (needs human-written alt text)

---

### Check 4 — Form label association (🔴 CRITICAL)

For every `<input>`, `<select>`, `<textarea>` in component files:

**Pattern A — explicit label:**
```tsx
<label htmlFor="email">Email</label>
<input id="email" type="email" />
```

**Pattern B — wrapping label:**
```tsx
<label>
  Email
  <input type="email" />
</label>
```

**Pattern C — aria-label:**
```tsx
<input aria-label="Email address" />
```

**Pattern D — aria-labelledby:**
```tsx
<h2 id="section-title">Section</h2>
<input aria-labelledby="section-title" />
```

Grep for `<input` / `<select` / `<textarea` that lack ALL of:
- `htmlFor` + matching `id` pair
- wrapped in `<label>`
- `aria-label`
- `aria-labelledby`

Flag each as 🔴 CRITICAL. Report: file, line, element type, missing label type.

---

### Check 5 — Interactive elements keyboard accessibility (🔴 CRITICAL / 🟠 HIGH)

**A. `onClick` on non-interactive elements:**
```
Grep pattern: onClick.*<div|onClick.*<span|onClick.*<p\b
```
Non-`<button>`, non-`<a>` elements with click handlers are not keyboard accessible.
→ 🔴 CRITICAL. Fix: change to `<button>` or add `role="button" tabIndex={0} onKeyDown`.

**B. Focus ring suppression:**
```
Grep pattern: outline-none|outline-0|focus:outline-none
```
Check if `focus:outline-none` is used without a replacement focus indicator (`focus:ring-*`, `focus-visible:ring-*`, or custom `box-shadow`).
→ 🟠 HIGH if no replacement focus indicator on the same element.

**C. `tabIndex` misuse:**
```
Grep pattern: tabIndex={[^-]
```
`tabIndex` values > 0 disrupt natural tab order. Report any `tabIndex={1}`, `tabIndex={2}`, etc.
→ 🟡 MEDIUM

---

### Check 6 — ARIA usage (🟠 HIGH / 🟡 MEDIUM)

**A. Buttons without accessible names:**
```
Grep pattern: <button(?![^>]*(?:aria-label|aria-labelledby))[^>]*>[\s]*<(?:svg|img|span class="sr-only")
```
Icon-only buttons (no visible text, no `aria-label`) → 🔴 CRITICAL.

**B. Dialogs and modals:**
Any element with `role="dialog"` must have `aria-label` or `aria-labelledby`.
```
Grep pattern: role="dialog"
```
→ Check each for accessible name.

**C. Decorative SVGs:**
```
Grep pattern: <svg(?![^>]*aria-hidden)
```
SVGs that are purely decorative should have `aria-hidden="true"`. SVGs that convey meaning need a `<title>` or `aria-label`.
→ 🟡 MEDIUM for decorative SVGs without `aria-hidden`.

**D. Live regions for dynamic content:**
If content updates dynamically (error messages, status updates) without `aria-live`, screen readers won't announce it.
→ Check tool output areas and form validation messages.

---

### Check 7 — Semantic HTML (🟡 MEDIUM)

**A. Heading hierarchy:**
Grep for `<h1>`, `<h2>`, `<h3>` etc. Check that:
- Only one `<h1>` per page
- No heading levels are skipped (h1 → h3 without h2)

**B. Landmark regions:**
- Page should have `<header>`, `<main>`, `<footer>` (or `role="banner"`, `role="main"`, `role="contentinfo"`)
- Navigation should use `<nav>` with `aria-label` when multiple navs exist

**C. Lists:**
Groups of related links (nav menus, tag lists) should use `<ul>/<li>`, not repeated `<div>` elements.

---

### Check 8 — Color contrast (🟠 HIGH)

Read the CSS token definitions from `globals.css`. Extract light and dark mode hex values for:
- `--color-ink` on `--color-surface`
- `--color-ink-soft` on `--color-surface`
- `--color-mist-text` on `--color-surface`
- `--color-ocean` on `--color-foam`
- `--color-ink-soft` on `--color-foam`

Calculate contrast ratio for each pair using WCAG formula:
```
L1 = relative luminance of lighter color
L2 = relative luminance of darker color
Contrast = (L1 + 0.05) / (L2 + 0.05)
```

Requirements:
- Normal text (< 18pt / 14pt bold): contrast ≥ 4.5:1
- Large text (≥ 18pt or 14pt bold): contrast ≥ 3:1
- UI components (borders, icons): contrast ≥ 3:1

Report each pair with its ratio and PASS/FAIL. Flag failures as 🟠 HIGH.

---

### Check 9 — `lang` attribute on `<html>` (🟠 HIGH)

For multilingual projects with next-intl:
```
Grep pattern: <html
glob: app/**/*.tsx
```
Verify `lang` attribute is set dynamically from the locale, not hardcoded to `"en"` or missing.

Check for a `LangUpdater` or similar component that sets `document.documentElement.lang` on the client when locale changes.

→ Missing lang attribute: 🟠 HIGH (screen readers can't select correct voice/pronunciation)

---

### Step 10 — Report

```
Accessibility Audit — <project>
WCAG 2.1 AA | Next.js + Tailwind | <date>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

SUMMARY
  🔴 CRITICAL   N   ← Fix before launch
  🟠 HIGH       N   ← Fix before launch
  🟡 MEDIUM     N
  🔵 LOW        N
  ⚪ INFO       N

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FINDINGS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔴 CRITICAL — Unlabeled <select> in VisaChecker
  File: components/tools/VisaChecker.tsx:44
  Why:  No <label>, aria-label, or aria-labelledby — screen readers cannot identify the field
  Fix:  Add <label htmlFor="from-country">Passport / nationality</label> and id="from-country" on the select

🟠 HIGH — bg-white in dark mode (no dark: override)
  File: components/tools/PackingList.tsx:175
  Why:  bg-white renders as a white block in dark mode — unreadable content
  Fix:  Replace with bg-surface

[... etc ...]

✓ PASSED CHECKS
  alt text on all <img> tags ✓
  lang attribute managed by LangUpdater ✓
  Single <h1> per page ✓
  <header> / <main> / <footer> landmarks present ✓
```

---

### Step 11 — Auto-fix (--fix)

Safe to auto-fix without asking:
- `bg-white` → `bg-surface`, `bg-gray-*` → `bg-foam`, etc. (full token replacement table above)
- `alt=""` on clearly decorative images (inside icon buttons)
- `aria-hidden="true"` on decorative `<svg>` elements
- `text-deep` → `text-ink` on elements without explicit `dark:` override

Must confirm before fixing:
- Missing form labels (need to know the right label text)
- Missing alt text on content images (needs human-written description)
- Heading hierarchy changes (restructuring HTML)

Show diff for each change. Report count of auto-applied fixes.

---

## Honesty Rules

- Never mark a check PASS without actually grepping or reading the relevant files.
- If a file uses `dark:` prefix on a class, that IS a valid dark mode override — don't flag it.
- CSS-in-JS or runtime className construction can't be statically analyzed — note this limitation.
- Contrast calculations require reading actual hex values from CSS — don't guess.
- `outline-none` is acceptable if the same element has `focus-visible:ring-*` (modern browsers only show focus rings on keyboard nav).
- Don't flag semantic status colors (red for errors, green for success) as contrast failures — they're intentional.
- Native `<select>` and `<input type="date">` get OS-level dark mode styling when `color-scheme: dark` is set in CSS — verify this before flagging.

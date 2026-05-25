---
name: security
description: "Cybersecurity expert review for web projects. Audits for hardcoded secrets, dependency CVEs, OWASP Top 10, Next.js security headers, API input validation, cookie flags, and environment variable leaks. Delivers severity-ranked findings with copy-paste fixes. Trigger: /security"
trigger: /security
---

# /security

Full-stack security audit for web projects. Reads source code, config files, and dependencies — then delivers findings ranked by severity with exact fixes. Covers secrets, dependencies, OWASP Top 10, framework-specific risks, and deployment configuration.

## Usage

```
/security                   # full audit of the current project
/security --secrets         # scan for hardcoded credentials and secrets only
/security --deps            # dependency vulnerability scan (pnpm/npm audit + CVE check)
/security --headers         # HTTP security headers audit
/security --owasp           # OWASP Top 10 checklist for this stack
/security --env             # environment variable handling audit
/security --quick           # fast sanity check — top 10 issues only, no deep scan
/security --fix             # apply safe auto-fixes for confirmed issues
/security <path>            # audit a specific file or directory
```

---

## Severity Levels

Every finding is tagged with a severity. Fix in this order.

| Severity | Meaning | Fix by |
|----------|---------|--------|
| 🔴 CRITICAL | Exploitable now. Data breach, account takeover, or server compromise possible. | Before next deploy |
| 🟠 HIGH | Serious vulnerability. Likely to be exploited. | Before launch |
| 🟡 MEDIUM | Real risk, lower likelihood or lower impact. | This sprint |
| 🔵 LOW | Best-practice violation. No immediate exploit path. | When convenient |
| ⚪ INFO | Informational. No action required but worth knowing. | — |

---

## What You Must Do When Invoked

1. Read the project structure (Glob for file layout, Read for key config files).
2. Run `pnpm audit --json` or `npm audit --json` via Bash.
3. Grep for secret patterns, dangerous functions, and misconfigurations.
4. Check every category below in order of severity.
5. Output a ranked findings report. Never skip a category — output "✓ No issues" if clean.

---

## Full Audit — /security

### Phase 1 — Reconnaissance (run first, parallel)

```
Glob: **/*.{ts,tsx,js,jsx,mjs,cjs,json,yaml,toml,env*}
Read: next.config.ts (or next.config.js)
Read: package.json
Read: .gitignore
Read: middleware.ts
Read: src/app/[locale]/layout.tsx (or app/layout.tsx)
Bash: pnpm audit --json 2>/dev/null || npm audit --json 2>/dev/null
Bash: git log --oneline -20 (check if .env files appear in history)
```

Then run the checks below against the collected data.

---

### Check 1 — Hardcoded Secrets 🔴

Grep for patterns that indicate a secret value is in source code:

```
Grep patterns (search all non-test, non-lock source files):
  sk-[a-zA-Z0-9]{20,}                  # OpenAI
  sk_live_[a-zA-Z0-9]+                  # Stripe live secret
  pk_live_[a-zA-Z0-9]+                  # Stripe live publishable (ok in client, flag anyway)
  rk_live_[a-zA-Z0-9]+                  # Stripe restricted key
  ghp_[a-zA-Z0-9]{36}                   # GitHub personal token
  github_pat_[a-zA-Z0-9_]+              # GitHub fine-grained token
  xoxb-[0-9]+-[a-zA-Z0-9]+             # Slack bot token
  xoxp-[0-9]+-[a-zA-Z0-9]+             # Slack user token
  SG\.[a-zA-Z0-9._-]{20,}              # SendGrid
  AIza[0-9A-Za-z\-_]{35}               # Google API key
  [Aa][Ww][Ss][_-]?[Aa][Cc][Cc][Ee][Ss][Ss][_-]?[Kk][Ee][Yy].*=.*[A-Z0-9]{20}
  postgres://[^:]+:[^@]+@               # PostgreSQL with credentials
  mongodb(\+srv)?://[^:]+:[^@]+@        # MongoDB with credentials
  mysql://[^:]+:[^@]+@                  # MySQL with credentials
  -----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----   # Private keys
```

Skip: `*.test.*`, `*.spec.*`, `node_modules/`, `*.lock`, `.git/`

For each match:
- Report: file, line number, matched pattern (mask value after first 8 chars)
- Severity: 🔴 CRITICAL if it's a live/production key, 🟠 HIGH otherwise
- Fix: move to `.env.local`, reference via `process.env.KEY_NAME`

Also check git history for secrets:
```bash
git log --all --full-history -- "*.env" "**/.env" 2>/dev/null | head -20
```
If `.env` files appear in history → 🔴 CRITICAL (rotate all keys that were ever committed).

---

### Check 2 — Environment Variable Leaks 🟠

**A. `NEXT_PUBLIC_` secrets** — Any variable prefixed `NEXT_PUBLIC_` is bundled into the client-side JS and visible to anyone who downloads the page.

Grep `NEXT_PUBLIC_` in all `.env*` files and `src/env.ts`. Flag any that look like secrets:
```
NEXT_PUBLIC_OPENAI_API_KEY     → 🔴 CRITICAL — exposed to all users
NEXT_PUBLIC_STRIPE_SECRET_KEY  → 🔴 CRITICAL
NEXT_PUBLIC_DATABASE_URL       → 🔴 CRITICAL
NEXT_PUBLIC_ADSENSE_ID         → ✓ OK — publisher ID is intentionally public
NEXT_PUBLIC_BASE_URL           → ✓ OK — not a secret
```

**B. `@t3-oss/env-nextjs` usage** — Verify `src/env.ts` exists and all env vars are validated there. If not:
- 🟡 MEDIUM — missing build-time validation means misconfigured env fails silently in prod

**C. Server-only imports in Client Components** — A `'use client'` file importing `src/env.ts` can leak server env vars into the bundle.

Grep: files with `'use client'` that also import from `@/env` or `process.env` directly.
- 🟠 HIGH if server secrets are reachable from a Client Component

---

### Check 3 — Dependency Vulnerabilities 🟠

Parse `pnpm audit --json` output. Group by severity:

```
Dependency Audit
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔴 CRITICAL  0
🟠 HIGH      2  ← list package names, CVE IDs, affected version ranges
🟡 MEDIUM    5
🔵 LOW       3
✓ Total packages scanned: 847
```

For each HIGH or CRITICAL finding:
- Package name + version currently installed
- CVE ID + CVSS score
- Fixed in version X
- Fix: `pnpm update <package>@<fixed-version>`

Also check:
- **Lock file present?** `pnpm-lock.yaml` must be committed. Missing → 🟠 HIGH (supply chain risk)
- **Lock file up to date?** If `package.json` was modified without regenerating the lock → 🟡 MEDIUM

---

### Check 4 — Next.js Security Headers 🟠

Read `next.config.ts`. Check for a `headers()` function with these response headers:

| Header | Required value | Severity if missing |
|--------|---------------|-------------------|
| `X-Content-Type-Options` | `nosniff` | 🟡 MEDIUM |
| `X-Frame-Options` | `DENY` or `SAMEORIGIN` | 🟡 MEDIUM |
| `X-XSS-Protection` | `1; mode=block` | 🔵 LOW (modern browsers ignore it, but belt+suspenders) |
| `Referrer-Policy` | `strict-origin-when-cross-origin` | 🟡 MEDIUM |
| `Permissions-Policy` | restrict camera, microphone, geolocation | 🔵 LOW |
| `Content-Security-Policy` | non-empty policy | 🟠 HIGH |
| `Strict-Transport-Security` | `max-age=63072000; includeSubDomains` | 🟡 MEDIUM |

If missing or incomplete, generate the fix as a complete `headers()` block to paste into `next.config.ts`:

```ts
async headers() {
  return [
    {
      source: '/(.*)',
      headers: [
        { key: 'X-Content-Type-Options', value: 'nosniff' },
        { key: 'X-Frame-Options', value: 'DENY' },
        { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
        { key: 'Permissions-Policy', value: 'camera=(), microphone=(), geolocation=()' },
        { key: 'Strict-Transport-Security', value: 'max-age=63072000; includeSubDomains; preload' },
        {
          key: 'Content-Security-Policy',
          value: [
            "default-src 'self'",
            "script-src 'self' 'unsafe-inline' https://pagead2.googlesyndication.com https://www.googletagmanager.com",
            "style-src 'self' 'unsafe-inline'",
            "img-src 'self' data: https:",
            "connect-src 'self'",
            "frame-src https://googleads.g.doubleclick.net https://tpc.googlesyndication.com",
          ].join('; '),
        },
      ],
    },
  ]
},
```

Note: CSP with AdSense requires allowlisting Google domains. Always generate CSP tailored to the project's actual third-party scripts.

---

### Check 5 — API Route Security 🟠

For each file in `src/app/api/` and `src/app/**/route.ts`:

**A. Input validation** — Does every route parse and validate request input with Zod before using it?
```ts
// Required pattern
const body = await request.json()
const parsed = MySchema.safeParse(body)
if (!parsed.success) return NextResponse.json({ error: 'Invalid input' }, { status: 400 })
```
Missing Zod validation → 🟠 HIGH (injection and type confusion risk)

**B. HTTP method guard** — Does the route only export the handlers it intends to serve?
```ts
// Only export what you need
export async function POST(req: Request) { ... }
// Not exporting GET means GET returns 405 automatically — good
```

**C. CORS** — Does any route set `Access-Control-Allow-Origin: *`?
- If yes and the route mutates data → 🟠 HIGH
- If yes and the route is read-only public data → 🔵 LOW (acceptable but document intent)

**D. Rate limiting** — Are API routes that could be abused (contact forms, search, AI calls) rate-limited?
- Missing rate limiting on expensive endpoints → 🟡 MEDIUM

**E. Error responses** — Do error handlers expose stack traces or internal details?
```ts
// BAD — leaks internals
catch (e) { return NextResponse.json({ error: e.message, stack: e.stack }) }

// GOOD
catch (e) { return NextResponse.json({ error: 'Internal server error' }, { status: 500 }) }
```
Leaking stack traces → 🟡 MEDIUM

---

### Check 6 — Cookie Security 🟡

For any cookie set in the project (check API routes, middleware, layout):

Required flags for sensitive cookies:
```ts
cookies().set('name', 'value', {
  httpOnly: true,    // not accessible via document.cookie
  secure: true,      // HTTPS only
  sameSite: 'lax',   // CSRF protection
  path: '/',
})
```

| Missing flag | Severity |
|-------------|---------|
| `httpOnly` on session/auth cookie | 🔴 CRITICAL (XSS can steal it) |
| `secure` | 🟠 HIGH (transmittable over HTTP) |
| `sameSite` | 🟡 MEDIUM (CSRF risk) |

For the **cookie consent cookie** (vanilla-cookieconsent):
- Must be `SameSite=Lax` at minimum
- `httpOnly: false` is acceptable (JS needs to read it to gate AdSense)
- `secure: true` required in production

---

### Check 7 — AdSense & Consent Gate 🟡

This project uses AdSense. Verify the consent gate is not bypassable.

Check `src/app/[locale]/layout.tsx` or wherever the AdSense `<Script>` is loaded:

```tsx
// Required pattern — AdSense must NOT load without consent
// BAD:
<Script src="https://pagead2.googlesyndication.com/..." strategy="afterInteractive" />

// GOOD — gated on consent cookie:
{hasConsent && (
  <Script src="https://pagead2.googlesyndication.com/..." strategy="afterInteractive" />
)}
```

Also check:
- Is the consent cookie value read server-side (from `cookies()`) or client-side?
- Is the reject button as prominent as accept? (AEPD requirement — failure is a legal risk, not a code risk)
- Does the consent component load Google's ad scripts before the user interacts? → 🟠 HIGH (GDPR violation)

---

### Check 8 — .gitignore Completeness 🔵

Read `.gitignore`. Verify it contains at minimum:

```
.env
.env.local
.env*.local
*.env

node_modules/
.next/

# If using the vault
vault/secrets/keys.md
```

Missing `.env` from `.gitignore` → 🔴 CRITICAL if a `.env` file exists in the project
Missing `.env.local` → 🟠 HIGH

---

### Check 9 — Dependency Confusion Risk ⚪

Check `package.json` for any private/internal package names (scoped packages like `@company/internal`).

If found, check that these are published on npm or have a matching npm scope. If not published, an attacker could register them on npm and serve malicious code.
→ 🟠 HIGH if internal package names are used without a registry lock

---

### Check 10 — Information Disclosure 🔵

Grep for `console.log`, `console.error`, `console.warn` in server-side files (not Client Components):
- Logging `req.headers`, user input, or API responses → 🟡 MEDIUM (logs end up in Vercel log drain, potentially visible to operators)
- No logs at all → ⚪ INFO (recommend structured logging for debugging)

Check `next.config.ts` for `poweredByHeader`:
```ts
// Add to nextConfig:
poweredByHeader: false,  // removes X-Powered-By: Next.js header (no need to advertise the stack)
```
Missing → 🔵 LOW

---

## Report Format

```
Security Audit: [project name]
Date: [today] | Stack: Next.js App Router + TypeScript
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

SUMMARY
  🔴 CRITICAL   0
  🟠 HIGH       2
  🟡 MEDIUM     4
  🔵 LOW        3
  ⚪ INFO       2
  
  Overall: ⚠️ Fix 2 HIGH issues before launch

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FINDINGS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🟠 HIGH — Missing Content-Security-Policy header
  File: next.config.ts
  Why:  Without CSP, any injected script (XSS, compromised CDN) runs unrestricted.
  Fix:  Add headers() block — see generated code below.

🟠 HIGH — No input validation on POST /api/contact
  File: src/app/api/contact/route.ts:14
  Why:  Raw request body used without Zod parsing — injection and type confusion possible.
  Fix:  
    const schema = z.object({ name: z.string().max(100), email: z.string().email(), message: z.string().max(2000) })
    const parsed = schema.safeParse(await req.json())
    if (!parsed.success) return NextResponse.json({ error: 'Invalid' }, { status: 400 })

🟡 MEDIUM — Stack trace exposed in error handler
  File: src/app/api/contact/route.ts:31
  Why:  catch (e) { return NextResponse.json({ error: e.message }) } leaks internals.
  Fix:  return NextResponse.json({ error: 'Internal server error' }, { status: 500 })

🟡 MEDIUM — Missing Referrer-Policy header
  [... etc]

🔵 LOW — X-Powered-By header present
  Fix: add poweredByHeader: false to next.config.ts

✓ PASSED CHECKS
  Secrets scan:     No hardcoded credentials found
  Dependencies:     0 critical, 0 high CVEs (pnpm audit clean)
  Env vars:         No NEXT_PUBLIC_ secrets found
  .gitignore:       .env and .env.local present ✓
  Cookie consent:   AdSense gated behind consent check ✓
  Cookie flags:     Consent cookie has Secure + SameSite ✓
  Git history:      No .env files in commit history ✓

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
GENERATED FIXES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[paste-ready code for each finding that has a code fix]
```

---

### /security --quick — Fast sanity check

Run only the highest-value checks. Takes ~30 seconds:

1. Grep for secret patterns in source (Check 1)
2. Check `.gitignore` for `.env` entries (Check 8)
3. Check `NEXT_PUBLIC_` vars (Check 2A)
4. Run `pnpm audit --json | head -50` for critical/high CVEs (Check 3)
5. Check if `headers()` exists in `next.config.ts` (Check 4)
6. Check if AdSense is gated behind consent (Check 7)

Output: pass/fail per check. If all pass → "✅ Quick check passed. Run /security for full audit."

---

### /security --fix — Apply safe auto-fixes

Auto-fix only what is safe to change without understanding business logic:

| Fix | Safe to auto-apply |
|-----|--------------------|
| Add security headers to `next.config.ts` | ✅ Yes — additive change |
| Add `poweredByHeader: false` | ✅ Yes |
| Add `.env.local` to `.gitignore` | ✅ Yes |
| Wrap error handlers | ✅ Yes — conservative generic message |
| Add Zod schema to API route | ⚠️ Only if no existing validation logic |
| Remove hardcoded key from source | ❌ Ask first — key must be stored before removing |

For each auto-fix, show a diff before applying. Confirm: "Apply N fixes?"

---

### /security --deps — Dependency audit only

```bash
pnpm audit --json
```

Parse and display:
- Critical and High CVEs with: package, version, CVE ID, CVSS score, description, fix command
- Check if a patch exists: if yes, show `pnpm update <pkg>@<version>`
- If no patch exists: show `pnpm why <pkg>` to find what requires it, and suggest alternatives

---

### /security --headers — Headers audit only

Fetch the live site (if `NEXT_PUBLIC_BASE_URL` is set) or read `next.config.ts`:

```
WebFetch: <base-url> (check response headers)
```

Compare actual headers against the required set. More reliable than static analysis since some headers may be added by Vercel or middleware.

---

### /security --env — Environment variable audit only

1. Read all `.env*` files in the project root
2. Read `src/env.ts` (if exists)
3. Search for `process.env.` usage across all source files
4. Check:
   - Every `process.env.X` usage has a corresponding entry in `src/env.ts`
   - No `NEXT_PUBLIC_` variable contains a secret value
   - `.env.local` is gitignored
   - No `.env` file with real values is tracked by git

---

### /security --owasp — OWASP Top 10 checklist

Run a focused check for each OWASP category relevant to this stack:

```
OWASP Top 10 — Next.js App Router
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
A01 Broken Access Control      — No auth in this project (by design) ✓
                                  Verify: no admin routes exposed, API routes don't assume identity
A02 Cryptographic Failures     — Check: no secrets in source, HTTPS enforced, secure cookies
A03 Injection                  — Check: Zod on all API inputs, no raw SQL/eval/exec
A04 Insecure Design            — Check: threat model matches no-user-data architecture
A05 Security Misconfiguration  — Check: security headers, error handling, debug mode off
A06 Vulnerable Components      — Run: pnpm audit
A07 Auth/ID Failures           — N/A (no auth). Verify nothing accidentally requires auth
A08 Software/Data Integrity    — Check: lock file present, no unverified third-party scripts
A09 Logging/Monitoring         — Check: no sensitive data in logs, errors are generic
A10 SSRF                       — Check: any server-side URL fetch validates the target domain
```

For each: ✓ PASS / ⚠ FINDING with specific file and fix.

---

## Honesty Rules

- Never mark a check as ✓ PASS without actually running it against the real files.
- If a file can't be read (permission, doesn't exist), say so — don't assume it's fine.
- `pnpm audit` output can be empty for a clean project — that's a real pass, not an error.
- CRITICAL findings must be called out at the top of the report, not buried in the list.
- If the project has no API routes, mark API checks as "N/A — no API routes found" not PASS.
- CSP is hard to get right with AdSense — always generate the CSP tailored to the actual scripts in use, never a generic one.
- Dependency CVEs in transitive dependencies (not direct) are still real findings — note which direct dep pulls them in.

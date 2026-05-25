---
name: security-agent
description: Runs a full security audit (secrets, CVEs, OWASP Top 10, headers, cookie flags) across 20+ source files via an Explore agent, returning only severity-ranked findings.
skill_counterpart: /security
agent_type: Explore
run_in_background: false
---

# Security Agent

Delegates a full security audit to an Explore agent. Security audits require reading 20+ source files, config files, and dependency manifests — far too much for the main context. This agent reads everything, returns only severity-ranked findings with copy-paste fixes.

## When to use this vs `/security`

| Use `/security` (inline skill) | Use this agent |
|-------------------------------|----------------|
| Quick spot check on a single file | Full project audit |
| User wants to step through findings interactively | Full audit report as a deliverable |
| `--quick` mode (top 10 only) | Any comprehensive scan |

**Default recommendation: always use the agent for security audits.** The Explore agent is purpose-built for reading large codebases.

## How to invoke

```
Agent({
  description: "Full security audit of [project name]",
  subagent_type: "Explore",
  run_in_background: false,
  prompt: """
You are a security engineer. Perform a comprehensive security audit of the project at: [PATH]

Read ALL of these file types:
- Source files: *.ts, *.tsx, *.js, *.jsx, *.py, *.go, *.java (focus on API routes, auth, DB queries, form handlers)
- Config files: next.config.js, vercel.json, .htaccess, nginx.conf, middleware.ts
- Dependency manifests: package.json, package-lock.json, pnpm-lock.yaml, requirements.txt, go.mod
- Environment files: .env.example (never .env itself), any .env.* that are committed
- CI/CD: .github/workflows/*.yml, Dockerfile, docker-compose.yml

Audit these 7 categories:

1. HARDCODED SECRETS
   Grep for: API_KEY, SECRET, PASSWORD, TOKEN, PRIVATE_KEY, Bearer, sk-, pk-, ghp_, aws_access
   in source files and config files (not .env.local or gitignored files).
   Flag any literal secret values committed to code.

2. DEPENDENCY VULNERABILITIES
   Check package.json for known vulnerable packages (check known CVEs for listed versions).
   Flag: packages with known high/critical CVEs in their version range.
   Check for: outdated major versions of security-critical packages (jsonwebtoken, bcrypt, express).

3. OWASP TOP 10
   A01 Broken Access Control: are API routes protected? Is auth middleware applied consistently?
   A02 Cryptographic Failures: are passwords hashed (bcrypt/argon2)? TLS enforced?
   A03 Injection: SQL queries using parameterized queries or ORM? No string concatenation in queries?
   A04 Insecure Design: rate limiting on auth endpoints? Account lockout?
   A05 Security Misconfiguration: debug mode in prod? Default credentials? Verbose errors exposed?
   A06 Vulnerable Components: see dependency scan above.
   A07 Auth Failures: JWT verified correctly? Session fixation possible? Cookie flags set?
   A08 Integrity Failures: npm scripts from untrusted sources? No integrity checks on CDN resources?
   A09 Logging Failures: sensitive data logged (passwords, tokens, PII)?
   A10 SSRF: any URL fetch from user input without validation?

4. HTTP SECURITY HEADERS
   Check next.config.js or middleware for: Content-Security-Policy, X-Frame-Options,
   X-Content-Type-Options, Referrer-Policy, Permissions-Policy, HSTS.
   Flag any missing critical headers.

5. API INPUT VALIDATION
   Are API route handlers validating and sanitizing user input?
   Is there a schema validation library (zod, yup, joi) in use?
   Are file uploads restricted by type and size?
   Are query parameters sanitized before use in queries or responses?

6. COOKIE & SESSION FLAGS
   Are auth cookies set with: HttpOnly, Secure, SameSite=Strict/Lax?
   Are session tokens rotated after login?

7. ENVIRONMENT VARIABLE HANDLING
   Are any .env files committed (excluding .env.example)?
   Are secrets accessed via process.env correctly (not hardcoded fallbacks)?
   Is .env.local in .gitignore?

Output format:

Security Audit: [Project]
Date: [today]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CRITICAL (fix before any deployment)
  🔴 [finding] — [file:line] — Fix: [exact fix]
  ...

HIGH (fix this sprint)
  🟠 [finding] — [file:line] — Fix: [fix]
  ...

MEDIUM (fix in next sprint)
  🟡 [finding] — Fix: [fix]
  ...

LOW / HARDENING
  🔵 [finding] — Fix: [fix]
  ...

PASSING
  ✅ [what's already secure]
  ...

DEPENDENCY VULNERABILITIES
  [package@version] — CVE-XXXX-XXXX — [severity] — Fix: upgrade to [version]
  ...

Never access or output contents of .env, .env.local, or any file that may contain real credentials.
Only report patterns and line numbers — never the actual secret values.
  """
})
```

## What the agent returns

A severity-ranked findings report. Present critical and high findings immediately. Offer to implement fixes inline using the `/security` skill for specific remediation steps.

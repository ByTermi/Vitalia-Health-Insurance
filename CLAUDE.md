# Vitalia Health Insurance — Project Instructions

## Project Overview
Vitalia Health Insurance is a collaborative health insurance platform built with modern web and mobile technologies.

**Stack:**
- Frontend: React/Next.js with Tailwind CSS
- Mobile: Flutter (via flutter-expert skill)
- Backend: RTK (Redux Toolkit) for state management, Caveman for API utilities
- Collaboration: Multi-person development with shared global skills

---

## Dependencies & Tools

### Installed Packages
- **caveman** — API utilities and client tooling
- **flutter-expert** — Flutter development skill for mobile builds

### External Tools (Managed by Team)
- **rtk** (Token Management CLI) — Available via team member setup
  - Repo: https://github.com/rtk-ai/rtk
  - Contact team lead for installation/setup

### Development Commands
```bash
npm install        # Install dependencies
npm run dev       # Start development server
npm run build     # Build for production
pnpm update      # Update dependencies
```

---

## Global Skills (Shared with Team)

The following skills are available globally for all team members working on this project:

### Architecture & Planning
- `/project` — Create/manage project documentation
- `/graphify` — Visualize codebase architecture as knowledge graph
- `/init` — Initialize codebase documentation

### Code Quality & Review
- `/review` — Pull request reviews
- `/security-review` — Security-focused code review
- `/code-review` — General code review at configurable depth
- `/bug-finder` — Automatic bug detection and fixing
- `/dep-audit` — Dependency security and update audit

### Testing & Verification
- `/verify` — Test changes in real app (not just unit tests)
- `/visual-qa` — Screenshot-driven visual regression testing
- `/lighthouse` — Performance/accessibility/SEO audits

### Performance & Optimization
- `/perf-profiler` — React/Next.js render performance profiling
- `/ad-supported-frontend` — AdSense/AdMob integration (if monetized)

### Content & Marketing (if applicable)
- `/seo` — Full SEO audit and optimization
- `/marketing` — Marketing strategy and RPM optimization
- `/i18n` — Multilingual setup (7 languages)
- `/content-validator` — Translation completeness and schema validation

### Security & Legal
- `/security` — Cybersecurity audit (CVEs, OWASP, headers, secrets)
- `/legal` — Spanish legal docs (GDPR, LSSI compliant)

### Mobile Development
- `/flutter-expert` — Flutter development for Vitalia mobile app
- `/android-development` — Kotlin + Jetpack Compose (Android alternative)
- `/cross-platform-dev` — React Native, Flutter, KMP multi-platform apps

### Backend & APIs
- `/serverless-backend` — AWS/Azure/GCP serverless setup
- `/claude-api` — Claude API integration and optimization

### Automation & Workflow
- `/loop` — Recurring task runner
- `/schedule` — Cron-scheduled remote agents
- `/capture` — Quick note capture to vault
- `/forge-skill` — Create new reusable skills from patterns

### Configuration
- `/update-config` — Configure Claude Code harness (hooks, permissions, env vars)
- `/keybindings-help` — Customize keyboard shortcuts
- `/fewer-permission-prompts` — Reduce permission prompts with allowlists

---

## Team Collaboration

### Code Review Workflow
1. Create a branch and commit changes
2. When ready, use `/review` or `/code-review` for inline feedback
3. Use `/security-review` for security-critical changes
4. Team members can use `/verify` to test changes in real environment before merging

### Performance & Quality
- Run `/lighthouse` before production deploys
- Use `/perf-profiler` when adding new React components
- Run `/bug-finder` during code review
- Use `/visual-qa` for UI changes

### Documentation
- Use `/project` to log decisions and architecture
- Use `/capture` to save design decisions, patterns, or useful snippets
- Use `/graphify` when onboarding new team members to architecture

---

## Key Permissions

Pre-approved commands (no prompt required):
- `Bash(npm install *)`
- `Bash(pnpm skills *)`

Add more in `.claude/settings.local.json` to reduce permission prompts during development.

---

## Session Protocol

When starting a new conversation:
1. Read this file to understand project setup
2. Check recent commits: `git log --oneline -10`
3. Ask about current focus before diving in

---

## Useful References

- **Global instructions:** `C:\Users\Vaquin\.claude\CLAUDE.md`
- **Vault:** `E:\obsidian\vault_claude_code\Claude Code`
- **Skills catalog:** `~/.claude/skills/_catalog.md`

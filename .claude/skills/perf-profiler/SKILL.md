---
name: perf-profiler
description: "Profile React/Next.js app code for performance issues: unnecessary re-renders, missing memoization, N+1 data fetching, large bundle contributions, and wrong use of client vs server components. Does not run Lighthouse — use /lighthouse for that. Trigger: /perf-profiler"
trigger: /perf-profiler
---

# /perf-profiler

Code-level performance audit for React/Next.js. Finds patterns that cause unnecessary work: re-renders, over-fetching, bundle bloat, and incorrect server/client boundaries.

This is **not** Lighthouse. Use `/lighthouse` for runtime metrics. This skill reads source code and identifies structural performance problems before they hit the browser.

## Usage

```
/perf-profiler                       # full scan
/perf-profiler --renders             # unnecessary re-render patterns
/perf-profiler --bundle              # bundle size contributors
/perf-profiler --fetching            # data fetching patterns (N+1, waterfalls)
/perf-profiler --client-server       # client vs server component boundary issues
/perf-profiler <path>                # scope to specific directory
```

---

## What You Must Do When Invoked

### Step 1 — Discover scope

Read `package.json` to confirm React/Next.js versions. Determine if it's App Router or Pages Router. Collect all component files.

### Step 2 — Client/Server boundary audit (--client-server)

In Next.js App Router, most components should be Server Components. `'use client'` should only be used when a component needs browser APIs, event handlers, or React state.

Scan all `.tsx` files for `'use client'`:

```powershell
Select-String -Path "app/**/*.tsx","components/**/*.tsx" -Pattern "'use client'" -Recurse |
  Select-Object Path, LineNumber
```

For each `'use client'` component, check if it actually needs to be a client component:
- Has `useState`, `useEffect`, `useRef`, `useContext` → needs client ✅
- Has `onClick`, `onChange`, event handlers → needs client ✅
- Has `window`, `document`, `localStorage` → needs client ✅
- Has browser-only APIs → needs client ✅
- Has none of the above → **likely unnecessary client component** 🔴

Flag unnecessary client components — converting them to server components reduces the client bundle.

Also check: large server components that import heavy client libraries. These should either:
- Lazy-load the client component with `dynamic(() => import(...), { ssr: false })`
- Or extract the interactive part into a small client island

### Step 3 — Re-render patterns (--renders)

Scan for patterns that cause unnecessary re-renders:

**Inline object/array creation in JSX:**
```tsx
// Bad — new object on every render
<Component style={{ margin: 0 }} />
<Component options={['a', 'b']} />
```
Flag any prop that creates a new object/array literal inline.

**Missing useCallback on event handlers passed as props:**
```tsx
// Bad — new function on every render
<Child onChange={(e) => setValue(e.target.value)} />
```
Flag anonymous arrow functions passed as props to child components.

**Missing useMemo for expensive computations:**
Look for `.filter()`, `.map()`, `.reduce()`, `.sort()` chains inside component body (not inside useMemo) that operate on arrays with more than trivial logic.

**Context that changes too often:**
If a Context value is an object literal (not memoized), every consumer re-renders whenever the provider's parent re-renders. Flag `<Context.Provider value={{ ... }}>` without `useMemo`.

**State that should be derived:**
```tsx
// Redundant state
const [fullName, setFullName] = useState(`${first} ${last}`)
```
Flag `useState` values that are always set to a computed value from other state.

### Step 4 — Data fetching patterns (--fetching)

**Waterfall fetches (sequential instead of parallel):**
```tsx
// Bad — each await blocks the next
const user = await fetchUser(id)
const posts = await fetchPosts(user.id)  // waits for user first
const comments = await fetchComments(posts[0].id)  // waits for posts
```
Flag multiple sequential `await` calls that could be parallelized with `Promise.all`.

**N+1 in server components:**
```tsx
// Bad — fetches once per country instead of once total
{countries.map(async (c) => {
  const data = await fetch(`/api/country/${c.code}`)
  ...
})}
```
Flag `.map()` with async callbacks that each make a fetch call.

**Missing `generateStaticParams` / `dynamicParams`:**
Dynamic routes that could be statically generated but aren't. Check all `[param]` route segments for the presence of `generateStaticParams`.

**Fetching the same data in multiple places:**
If the same fetch URL or data file is read in multiple sibling components (not a parent+child), flag it — the fetch should be hoisted to the parent.

### Step 5 — Bundle size contributors (--bundle)

Check for heavy imports that could be tree-shaken or replaced:

```powershell
# Find large library imports
Select-String -Path "**/*.tsx","**/*.ts" -Pattern "^import .* from" -Recurse |
  Select-String "lodash|moment|date-fns|recharts|d3|three|@mui|antd"
```

Flag:
- `import _ from 'lodash'` → should be `import debounce from 'lodash/debounce'`
- `import moment from 'moment'` → recommend `date-fns` or `dayjs`
- Full icon library imports → `import { IconName } from 'lucide-react'` ✅ (already optimal)
- `import * as X from 'library'` → flags for investigation

Check `next.config` for bundle analyzer setup. If not present, suggest:
```powershell
pnpm add -D @next/bundle-analyzer
```

### Step 6 — Image optimization

```powershell
Select-String -Path "**/*.tsx" -Pattern "<img " -Recurse
```

Every `<img>` tag in a Next.js app should be `<Image>` from `next/image` unless it's:
- Inside an SVG
- In a third-party embed
- Dynamically generated (canvas, etc.)

Flag all `<img>` tags that should be `<Image>` with `width`/`height` props.

### Step 7 — Report

```
Performance Profile — <project>

Client/Server Boundaries:
  🔴 3 components marked 'use client' with no client-side APIs
     → converting would remove ~42KB from client bundle (estimated)
  🟡 2 server components import heavy client libraries without dynamic()

Re-render Risks:
  🟠 5 inline object props (new object per render)
  🟡 8 anonymous arrow function props (new function per render)
  🔵 2 Context providers with unmemoized values

Data Fetching:
  🔴 1 waterfall fetch (3 sequential awaits — could be Promise.all)
  🟡 2 routes missing generateStaticParams (running as dynamic instead of static)

Bundle:
  🟡 1 full lodash import (only 2 functions used)
  🔵 No heavy date libraries detected

Images:
  🟠 4 <img> tags that should be <Image> (no lazy loading, no size optimization)
```

Then list each finding with file + line + exact fix.

For each fix, classify:
- **Auto-fix safe**: `<img>` → `<Image>`, lodash tree-shaking, `Promise.all` parallelization
- **Needs review**: removing `'use client'` (could break if you missed a dependency), adding `useMemo` (adds complexity — only worth it for actually expensive ops)

### Step 8 — Apply safe fixes (only if explicitly asked)

Don't apply fixes automatically unless the user says so. Present the list first, then ask which ones to apply.

---

## Rules

- Don't add `useMemo`/`useCallback` speculatively. Only flag genuinely expensive computations or props passed to memoized children.
- Premature optimization is real. Frame each finding with its actual impact, not just "it could be faster."
- Never remove `'use client'` without verifying all usages of the component — it may be used in ways you can't see from grep alone.
- Converting a dynamic route to static generation can change behavior — always note the tradeoff.
- This skill reads code, not runtime profiles. Actual hot paths need React DevTools Profiler or server traces.

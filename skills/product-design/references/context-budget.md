# Execution Context Budget

> Canonical reference for how super-ralph keeps each execution-level issue (STORY/BE/FE/INT)
> within the 200k-token context window of the downstream `/super-ralph:build-story` subagent.
>
> **Why this is the only place to enforce this:** The build subagent has no recourse. If the `[BE]` body is 180k tokens of code examples, the agent will never finish — it will spend all its context reading the issue and have nothing left to compile, test, or commit. SLICE must produce stories small enough that every resulting sub-issue sits under the target.

## The envelope

Every execution-level issue — `[STORY]`, `[BE]`, `[FE]`, `[INT]` — will later be loaded into a fresh 200k-token context window by a `/super-ralph:build-story` subagent. Design-time decisions lock in how much of that window each issue consumes. A story that cannot fit is not executable.

| Bucket | Target | Hard cap | Notes |
|--------|--------|----------|-------|
| Build subagent total window | 200,000 tok | 200,000 tok | Fixed by model |
| System prompt + tool schemas + skill loads (`build.md`, `review-fix.md`) | ~20,000 tok | — | Fixed overhead |
| Plan + context temp files (`plan-result.md`, `context.md`) | ~5,000 tok | 10,000 tok | Small bridge files |
| **Issue body** (one of STORY/BE/FE/INT) | **≤ 30,000 tok** | **≤ 40,000 tok** | The main lever |
| **Referenced existing files read during build** | **≤ 60,000 tok** | **≤ 80,000 tok** | Files the agent must Read to understand patterns and edit in place |
| Scratch (tool outputs, test runs, incremental writes, reasoning) | ≥ 80,000 tok | ≥ 60,000 tok | Must be protected — build fails without it |

**Combined input budget target:** issue body + referenced files ≤ **90,000 tokens** per execution-level issue. **Hard cap:** ≤ 120,000 tokens.

## Token estimation heuristics

- `1 token ≈ 4 characters` for mixed markdown + TypeScript (conservative).
- `wc -c <file>` returns bytes, which ≈ characters for ASCII + UTF-8 English/Chinese.
- **30k tokens ≈ 120,000 chars ≈ ~3,000 LOC of typical markdown/code.**
- **60k tokens ≈ 240,000 chars ≈ ~6,000 LOC referenced in existing files.**
- **120k tokens ≈ 480,000 chars** — anything over this red-lines the budget.

## Per-output-body caps (for the Phase 4 story-planner sub-agent)

Each output body the planner produces will later be loaded by a build subagent into a fresh 200,000-token context window, alongside the existing files the agent must read to follow patterns. The planner MUST produce bodies small enough that the build subagent has working room:

| Per output body | Target | Hard cap |
|-----------------|--------|----------|
| STORY body | ≤ 20,000 tok (~80,000 chars) | 30,000 tok |
| BE body     | ≤ 30,000 tok (~120,000 chars) | 40,000 tok |
| FE body     | ≤ 30,000 tok (~120,000 chars) | 40,000 tok |
| INT body    | ≤ 15,000 tok (~60,000 chars) | 20,000 tok |
| **STORY + BE + FE + INT combined** | **≤ 90,000 tok (~360,000 chars)** | **≤ 120,000 tok** |

## SLICE-time estimation rule

Before dispatching the Phase 4 planner, pre-estimate each story's build-time footprint — sum of BE/FE/INT body sizes it will need + LOC of existing files a build agent must read to understand patterns (schema file, nearest pattern service, nearest pattern route, nearest pattern page, i18n files). If that estimate exceeds **~90,000 tokens** (≈ 360,000 chars, ≈ ~9,000 LOC combined), the story MUST be split — even if its AI-hours size says "M". Common culprits: touching >2 existing tables, >3 existing services, or editing large pages (>500 LOC) in place.

## Keeping issue bodies lean

| Bloat source | Fix |
|--------------|-----|
| Pasting existing code to "show the pattern" | Reference by path: `Pattern: $BE_SERVICES_DIR/knowledge.ts` |
| Long prose explanations of TDD loop | Rely on the TDD loop structure; no commentary |
| Duplicating Gherkin across STORY + BE + FE | Gherkin lives in STORY only; BE/FE/INT say `See parent #STORY_NUMBER` |
| Per-task commit-message templates repeated verbatim | Show once in the story template; agents follow the pattern |
| "Relevant Existing Files" list with 15+ entries | Cap at 8 files × ≤ 500 LOC each |

Rules inside the Phase 4 planner prompt:

- Put EXACT code in the TDD tasks — but keep per-task code blocks focused on ONE layer (schema OR service OR route, not all three). If you find yourself writing a 500-LOC single TDD task, the story is too big — STOP and emit SPLIT_NEEDED (see below).
- Reference existing files by path + line hint instead of quoting them in full. Example: `Service pattern: $BE_SERVICES_DIR/knowledge.ts` (path only).
- Limit the "Relevant Existing Files" / "Patterns to Follow" list to **≤ 8 files**, each ≤ 500 LOC. If you need more, the story is too big.
- Do NOT paste long existing-file excerpts. The build agent will Read them.
- Prefer concise tables over narrative prose. Every table row is cheap; every prose paragraph costs ~50-100 tokens you could spend on code.

## SPLIT_NEEDED protocol

If after initial exploration the planner estimates the combined bodies will exceed the hard cap (120,000 tok ≈ 480,000 chars), DO NOT produce bloated bodies. Instead, write a split-sentinel file to the SAME run-state directory that would have held the plan file, with the filename pattern:

```
story-N-split-needed.md
```

Full path: `$(git rev-parse --show-toplevel)/.claude/runs/design-[EPIC_SLUG]/story-N-split-needed.md`, fallback `/tmp/super-ralph-design-[EPIC_SLUG]/story-N-split-needed.md`.

With this exact shape:

```markdown
# SPLIT_NEEDED: Story N — [Title]

## Reason
Estimated combined body size: ~NNN,NNN chars (over 480,000 char cap).
Primary driver: [schema with 4 tables / page with 900 LOC of controls / etc.]

## Proposed split
- Story N.a: [sub-title] — [scope]
- Story N.b: [sub-title] — [scope]
- (Story N.c if needed)

## Per-split estimate
| Sub-story | BE body | FE body | INT body | Combined |
|-----------|---------|---------|----------|----------|
| N.a       | ~Xk     | ~Yk     | ~Zk      | ~Tk tok  |
| N.b       | ~Xk     | ~Yk     | ~Zk      | ~Tk tok  |
```

Then STOP — do not write a plan file for Story N. The orchestrator will re-dispatch the split sub-stories.

## Post-plan audit

After Phase 4 completes, every generated plan file is byte-audited against these thresholds. See `execution-planning.md` — Step 10.5 "Post-Plan Context Budget Audit" for the full audit procedure, remediation tiers, and the Context Budget Report format.

## Design-review gates (CTX-G1..G3)

Every execution-level issue will be loaded by a `/super-ralph:build-story` subagent into a fresh 200k-token context window. Design-time sizing is the only lever — enforce it at review time too.

Char thresholds assume `1 token ≈ 4 chars`. Measure body size via `echo "$BODY" | wc -c`.

| Gate | Rule | How to check |
|------|------|--------------|
| CTX-G1 | Each individual issue body under hard cap | STORY ≤ 120,000 chars; BE ≤ 160,000 chars; FE ≤ 160,000 chars; INT ≤ 80,000 chars |
| CTX-G2 | Combined STORY + BE + FE + INT for a given story group ≤ 480,000 chars (~120k tok) | Sum the four body char counts; must be ≤ 480,000 |
| CTX-G3 | "Relevant Existing Files" / "Patterns to Follow" list ≤ 8 file refs per BE or FE body | `grep -cE "^- \`?\\\$[A-Z_]+_(DIR\|FILE)" <body>` ≤ 8 |

**Verdict logic for CTX gates:**
- CTX soft-warn (combined body size between 360k and 480k chars) with no other failures → **CONDITIONAL** (emit warning, allow ship, recommend trim/reference-by-path before re-running `/super-ralph:build-story`)
- CTX hard-cap violation → **BLOCKED** — split the story and re-run `/super-ralph:design` or `/super-ralph:improve-design` before creating issues

## Related references

- `story-planner-spec.md` — Phase 4 sub-agent that enforces budget at plan time
- `execution-planning.md` — Step 10.5 audit procedure
- `../../design-review/references/gate-catalog.md` — Where CTX-G gates are catalogued alongside STORY/BE/FE/INT/CX gates

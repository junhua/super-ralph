# Super-Ralph: Local Mode + Improve-Design Command

**Date:** 2026-04-18
**Status:** Draft
**Scope:** `commands/design.md`, `commands/build.md`, `commands/build-story.md`, `commands/e2e.md`, `commands/review-design.md`, new `commands/improve-design.md`

## Problem

Today `/super-ralph:design` produces:
- A short epic doc at `docs/epics/YYYY-MM-DD-<slug>.md`
- One `[EPIC]` GitHub issue + N `[STORY]` / `[BE]` / `[FE]` / `[INT]` sub-issues whose bodies hold all implementation detail (Gherkin AC, Shared Contracts, TDD tasks)

Downstream commands (`/build-story`, `/e2e`, `/review-design`) read those bodies from GitHub, re-fetching them on every invocation. For a 10-story epic that is ~40 issues × ~2 KB of body text, re-read repeatedly across waves.

For iterative design work (adjusting stories before they are stable, experimental spikes, quick internal work) this is wasteful: it pollutes issue tracking with work that may be deleted or reshaped, and it burns tokens re-fetching the same bodies.

## Goals

1. Let `/design` write the complete plan (epic header + all story/BE/FE/INT bodies) into a single local markdown file, skipping GitHub issue creation.
2. Let `/build`, `/build-story`, `/e2e`, `/review-design` operate on that local file via path-based arguments, auto-detecting local vs. GitHub mode.
3. Add `/super-ralph:improve-design "<prompt>"` for targeted adjustments to an existing design (local or GitHub), with autonomous target resolution from the prompt.

## Non-goals

- Replace GitHub as the SSOT for the team's main roadmap. Local mode is opt-in per invocation via `--local` or path-based args; the default stays GitHub.
- Support partial hybrids (e.g., one story local, another on GitHub in the same epic). An epic is fully local or fully GitHub.
- Migrate existing GitHub epics to local files. No conversion tooling.
- Rename or renumber stories after creation. Removed stories leave numbering holes to preserve cross-references.

## Local-mode file format

One file per epic at `docs/epics/YYYY-MM-DD-<slug>.md`. Structure:

```markdown
# EPIC: <title>

<!-- super-ralph: local-mode -->

## Goal
<1-2 sentences>

## Business Context
<2-3 sentences>

## Success Metrics
| Metric | Current | Target | How to Measure |

## Personas
- <persona 1> — <relevance>

## Scope — In
- <capability>

## Scope — Out
- <excluded capability> — <why>

## Dependencies
| Prereq | Status | Notes |

## Risks
| Risk | Impact | Likelihood | Mitigation |

## PM Summary

### Story Priority Table
| # | Story | Priority | Size | Can Ship Without? | Notes |

### Execution Plan

#### AI-Hours Estimate
| Story | BE | FE | INT | Total |

#### Dependency Graph
(text or mermaid)

#### Wave Assignments
| Wave | Stories | Parallel Slots | Estimated Hours |

---

## Stories

### Story 1: <Title>

**Persona:** <X>   **Priority:** P0   **Size:** M   **Status:** PENDING
<!-- Status values: PENDING | IN_PROGRESS | READY | COMPLETED -->
<!-- PR: (set by finalise, e.g., #1234) -->
<!-- Branch: (set by finalise, e.g., super-ralph/story-1-slug) -->

#### [STORY] Story 1

**Parent:** (local epic)

## User Story
**As a** <persona>, **I want** <action>, **So that** <outcome>.

## User Journey
<narrative>

## Acceptance Criteria
Feature: <name>
  Background:
    Given <shared precondition>
  Scenario: [HAPPY] <name>
    Given ...
    When ...
    Then ...
  Scenario: [EDGE] <name>
    ...
  Scenario: [SECURITY] <name>
    ...

## Shared Contract
```typescript
export interface Foo { /* ... */ }
```

## E2E Test Skeleton
```typescript
// tests/e2e/<story-slug>.test.ts
import { describe, test, expect } from "bun:test";
describe("<story title>", () => {
  test("<AC-1>", async () => { /* ... */ });
});
```

## Sub-Issues
- [BE] (local, see below)
- [FE] (local, see below)
- [INT] (local, see below)

#### [BE] Story 1 — Backend

**Parent:** (local epic — Story 1)

## Backend Implementation

### Schema Changes
File: `<path>`
Section: `// ─── <Feature> ────`
```typescript
// EXACT code
```

### Service
File: `<path>` (Create)
```typescript
// EXACT code
```

### Route
File: `<path>` (Create)
```typescript
// EXACT code
```

### Route Registration
File: `<path>`
Action: APPEND to end of protected routes section
```typescript
app.route("/api/<feature>", <feature>Routes);
```

### Test Helpers
File: `<path>`
Action: APPEND at end
```typescript
import { <table> } from "./schema";
tables.set("<table_name>", <table>);
```

## TDD Tasks

**Progress check:** `<command>` — Expected: `<output>`

### Task 0: E2E Test Skeleton (Outer RED)
```bash
# EXACT commands
```

### Task 1: Schema + Migration
```bash
# EXACT commands with expected outputs and git commit
```

### Task 2: Service Layer
### Task 3: Route Layer
### Task 4: Route Registration + Test Helpers

## Completion Criteria
- [ ] `<test command>` — 0 failures
- [ ] `bun test tests/e2e/<story-slug>.test.ts` — BE scenarios pass

#### [FE] Story 1 — Frontend

**Parent:** (local epic — Story 1)

## Frontend Implementation

### Mock Data
File: `<path>` (Create)
```typescript
// EXACT mock data
```

### API Client
### Types
### i18n (EN + zh-CN)
### Components

## TDD Tasks
(same structure as BE)

## PM Checkpoints
| Checkpoint | When | What to Verify |
| CP1: Mock renders | After Task 1-2 | ... |
| CP2: i18n complete | After Task 3 | ... |
| CP3: API integrated | After BE ready | ... |
| CP4: AC pass | After all tasks | ... |

## Completion Criteria
- [ ] ...

#### [INT] Story 1 — Integration & E2E

**Parent:** (local epic — Story 1)
**Depends on:** [BE] Story 1 (merged), [FE] Story 1 (merged)

## Gherkin User Journey
See Story 1 `[STORY]` section above — Acceptance Criteria.

## Integration Tasks

### Task 0: Mock Swap
### Task 1: Gherkin Scenarios as E2E Tests

## Verification Tasks

### Task 2: /super-ralph:verify against staging preview
### Task 3: Integration PR

## Completion Criteria
- [ ] ...

---

### Story 2: <Title>
... (same structure)
```

**Anchor conventions:**

| Fragment | Resolves to |
|----------|-------------|
| `docs/epics/foo.md#story-1` | The `### Story 1:` section and all its nested `[STORY]` / `[BE]` / `[FE]` / `[INT]` sub-sections |
| `docs/epics/foo.md#story-1-story` | Only the `#### [STORY]` sub-section under Story 1 |
| `docs/epics/foo.md#story-1-be` | Only the `#### [BE]` sub-section under Story 1 |
| `docs/epics/foo.md#story-1-fe` | Only the `#### [FE]` sub-section under Story 1 |
| `docs/epics/foo.md#story-1-int` | Only the `#### [INT]` sub-section under Story 1 |
| `docs/epics/foo.md` (no fragment) | Whole epic (used by `/e2e` and `/review-design`) |

**Parser rules:**

- Fragment matches case-insensitively against a normalized slug of the heading.
- `### Story N:` is the primary story boundary; the story section ends at the next `### ` heading at the same level or EOF.
- `#### [STORY]`, `#### [BE]`, `#### [FE]`, `#### [INT]` are the sub-section boundaries; each ends at the next `#### ` heading or the next `### Story` heading.
- Status line parsing is whitespace-tolerant: fields are identified by `**<FieldName>:**` regex, separated by any whitespace. Status values are `PENDING`, `IN_PROGRESS`, `READY`, `COMPLETED`. Runtime failures (FAILED, BLOCKED) live in `.claude/runs/story-*/status.md`, not in the epic file — a failed run leaves the epic status at `IN_PROGRESS` so a re-run picks it up.

## Command changes

### `/super-ralph:design` — add `--local` flag

New flag: `--local` (default: false). When set:

| Phase | Behavior with `--local` |
|-------|------------------------|
| 0 Load config | unchanged |
| 1 Context | unchanged |
| 2 Research (3 parallel agents) | unchanged |
| 3 Epic definition | write `docs/epics/<slug>.md` with `<!-- super-ralph: local-mode -->` marker at the top |
| 4 Story planning | story-planner sub-agents still write to `.claude/runs/design-<slug>/story-N-plan.md` (unchanged — avoids race on concurrent writes). After all planners finish, the orchestrator sequentially consolidates each `story-N-plan.md` into the epic file under each `### Story N:` heading. |
| 5 Issue creation | SKIPPED ENTIRELY — no `gh issue create` calls |
| 6 Review | dispatch `/review-design docs/epics/<slug>.md` instead of `/review-design <EPIC_NUMBER>` |
| 7 Report | launch commands show `/super-ralph:build-story docs/epics/<slug>.md#story-N` |

Commit after Phase 4: `epic: <title> (local-mode draft)`.

**Collision handling:** If `docs/epics/<slug>.md` already exists, `/design --local` exits with `"Epic file already exists at <path>. Use /super-ralph:improve-design to modify, or delete the file first."` — do not overwrite a possibly in-flight design.

### `/super-ralph:build-story` — path-based local mode

Extend Step 0b argument parsing:

- If the argument matches `*.md` (with optional `#fragment`) → **local mode**:
  - Read the epic file; extract the referenced `### Story N` section plus nested sub-sections
  - Build `$STORY_DIR/context.md` from the extracted `[STORY]` sub-section + parent epic Goal/Scope
  - Write `$STORY_DIR/plan-result.md` with `mode: embedded`, `source: docs/epics/<slug>.md#story-N`, `be_body:` and `fe_body:` pointers to offsets in the epic file (or copies in `$STORY_DIR/be.md` and `$STORY_DIR/fe.md` for isolation)
  - **Skip Phase 1 plan** entirely — TDD tasks live in the file
  - Phase 2 build dispatches with model=`sonnet` (mode=embedded branch; already exists today for GitHub issues with embedded TDD)
  - Phase 3 review-fix unchanged
  - Phase 4 verify unchanged
  - Phase 5 finalise (local variant):
    - Rebase, push, `gh pr create` — unchanged
    - PR body: omit `Closes #N`. Use `Closes local epic docs/epics/<slug>.md#story-N` as a human-readable reference (GitHub does not auto-close this, but it is a durable pointer)
    - Vercel deployment verification — unchanged
    - After merge: skip `gh issue close`, skip `gh project item-edit`
    - Edit the epic file: flip `**Status:** PENDING` → `**Status:** COMPLETED` under Story N, insert `<!-- PR: #<num> -->` and `<!-- Branch: <branch> -->` lines
    - Commit: `docs: mark Story N as completed in <epic-slug>`
    - Check if all stories in the epic file are `COMPLETED`; if so, print `"Epic complete. Ready for: /super-ralph:release"`
- If the argument matches `#(\d+)` or pure digits → **GitHub mode** (current behavior, unchanged)
- If the argument is a free-form string → **Description mode** (current behavior, unchanged)

`--resume` still works: resume detection reads `$STORY_DIR/` temp files; they are created the same way in either mode.

### `/super-ralph:e2e` — path-based local mode

Extend argument parsing:

- If the argument matches `*.md` → **local mode**:
  - Step 0b: read the epic file instead of `gh issue view`. Parse stories by `### Story N:` headings.
  - Step 0b: write `$E2E_DIR/stories/story-N/brief.md` by extracting each `#### [STORY]` sub-section (same schema as today).
  - Step 1 Filter: read `**Status:**` field from each story. Skip `COMPLETED`; include `PENDING` / `IN_PROGRESS` / `READY`.
  - Step 2 Wave planning: unchanged (SME brainstormer reads briefs).
  - Step 4a dispatch: pass `docs/epics/<slug>.md#story-N` to each story executor instead of an issue number.
  - Step 4c finalise: use the local-mode finalise described above — no `gh issue close`, no `gh project item-edit`, but still do Vercel deployment verification.
  - Step 4d docs updates: skip the `docs/plans/` commit (no plan files). Keep the epic-file edit for completion markers.
  - Step 5 roadmap update: unchanged.
  - Step 6 release: unchanged (release is about staging→main promotion, independent of issue mode).
- If the argument is numeric → **GitHub mode** (current behavior, unchanged).

### `/super-ralph:review-design` — path-based local mode

Extend argument parsing:

- If the argument matches `*.md` → **local mode**:
  - Step 1 Resolve: read the file, validate the `<!-- super-ralph: local-mode -->` marker is present.
  - Step 2 Load sub-issues: build a synthetic issue tree by parsing `### Story N:` + nested `[STORY]` / `[BE]` / `[FE]` / `[INT]` sub-sections. Each becomes a virtual "issue" with `number: "story-N-<kind>"`, `body: <extracted section text>`.
  - Step 2.5 Enforcement gates: apply STORY-G1..3, BE-G1..2, FE-G1..2, INT-G1..2 rules unchanged — they are pure text grep against the body.
  - Step 3 Per-story review agents: dispatch one per story, passing extracted sub-section text blocks. Same PM/BE/FE/SC gates.
  - Step 4 Cross-issue checks: adapt CX-1..CX-5 to operate on sub-sections instead of issues. CX-5 becomes "epic header table matches the `### Story N` sections below" instead of "epic doc matches GitHub issues."
  - Step 6 Auto-fix (`--fix`): edit the epic file in place (same conservative rules: i18n rows, placeholder comments, missing section markers). Never rewrite Gherkin, TDD code, or Shared Contract types.
  - Step 7 Verdict: launch commands point to `docs/epics/<slug>.md#story-N`. Findings cite section anchors instead of issue numbers.
- If the argument is numeric → **GitHub mode** (current behavior, unchanged).

### `/super-ralph:build` — accept epic section

Extend argument parsing in the build skill's Step 1:

- If the argument matches `*.md#story-<N>` (or `*.md#story-<N>-<kind>`) → **epic-section mode**:
  - Read the epic file; extract the referenced section(s)
  - Write the concatenated `[BE]` + `[FE]` TDD tasks to a temp plan file at `.claude/runs/build-<story-slug>/plan.md`
  - Hand that temp plan to the existing ralph-loop prompt template (standard mode)
  - All other ralph-loop machinery unchanged
- If the argument matches `*.md` without a fragment → treat as a standard plan file (current behavior)
- If the argument is any other path → current behavior

## New command: `/super-ralph:improve-design`

### File: `commands/improve-design.md`

### Arguments

```
/super-ralph:improve-design "<prompt>"
```

Single quoted prompt. Target and feedback are both extracted from the prompt.

### Philosophy

Unlike `/design` and `/e2e` which are fire-and-forget, `/improve-design` may pause once for user disambiguation (Phase 0a) and once to surface a clarification question (Phase 1). These are the only interactive points. All other phases run autonomously.

### Phase 0a: Resolve target from prompt

Extraction order:

1. **Explicit file path** — regex `docs/epics/[^\s]+\.md` matched in prompt → local mode.
2. **Explicit issue reference** — regex `#(\d+)` or `\bEPIC\s*#?(\d+)\b` → GitHub mode.
3. **Fuzzy match** — dispatch a target-resolver sub-agent (sonnet, 10 turns):

   ```
   Task tool:
     model: sonnet
     max_turns: 10
     description: "Resolve epic target from improvement prompt"
     prompt: |
       User prompt: "<full prompt>"

       Available local epics:
       [for each file in docs/epics/*.md, output: path + first `# EPIC:` heading + mtime]

       Available GitHub EPICs:
       [gh issue list --label epic --state open --json number,title]

       Identify which epic the prompt most likely refers to.
       Return JSON:
       {
         "best_match": "docs/epics/foo.md" | "#123" | null,
         "confidence": "high" | "medium" | "low",
         "candidates": [{ "target": "...", "reason": "..." }],
         "feedback_stripped": "<prompt minus target-identifying words>"
       }
   ```

4. **Disambiguation gate:**
   - `confidence: high` + single candidate → proceed silently.
   - `confidence: medium` OR 2+ candidates → surface candidates via `AskUserQuestion`, then exit after the user picks (do not proceed without confirmation).
   - `confidence: low` / no candidates → exit with `"Could not identify which epic to improve. Please include the file path or #EPIC_NUMBER in your prompt."`

### Phase 1: Interpret feedback (1 Sonnet sub-agent)

Dispatch a feedback-interpreter sub-agent (sonnet, 15 turns):

```
prompt: |
  Feedback (target already resolved to <TARGET>): "<feedback_stripped>"

  Current design contents:
  [full epic file contents for local, or issue tree for GitHub]

  Map the feedback to one or more structured change entries using only these types:
  - ADD_STORY
  - REMOVE_STORY
  - SPLIT_STORY
  - MERGE_STORIES
  - EDIT_AC
  - EDIT_TDD
  - EDIT_SHARED_CONTRACT
  - EDIT_SCOPE
  - RE_WAVE
  - EDIT_METADATA (priority, size, persona)

  Return JSON:
  {
    "clarification_needed": false | true,
    "clarification_question": "<string if true>",
    "changes": [
      {
        "type": "SPLIT_STORY",
        "target": "story-5",
        "details": { /* type-specific fields */ }
      }
    ]
  }

  If the feedback cannot be mapped to supported change types, set clarification_needed=true and return a focused question — do NOT guess.
```

If `clarification_needed` is true, print the question and exit cleanly.

### Phase 2: Apply changes (1 Opus sub-agent per change, up to 3 parallel)

For each change entry, dispatch an apply-change sub-agent (opus, 30-40 turns). The agent receives:

- The change type and target
- The current contents of the affected section(s) only
- The project config (shared file protocol, test commands, etc.)
- The same templates `/design` uses for STORY/BE/FE/INT bodies (from `skills/product-design/references/`)

The agent produces the new/edited section text and writes it to `.claude/runs/improve-<slug>/change-N.md`.

Run up to 3 apply-change agents in parallel (same concurrency cap as `/design` Phase 4).

**Safety enforcement inside the apply-change agent prompt:**

> "If the target section has `**Status:** COMPLETED` (local) or its `[STORY]` issue is CLOSED (GitHub), refuse the edit. Return `{status: REFUSED, reason: 'Shipped work is immutable — cut a new story instead.'}`."

### Phase 3: Commit changes

**Local mode:**

- Read all `change-N.md` files in order.
- For ADD_STORY: append new `### Story N+1:` section.
- For REMOVE_STORY: delete the `### Story N:` section; leave the number hole.
- For SPLIT_STORY: replace the `### Story N:` section with two new sections. Numbering: if Story 6 is being split, new sections are `### Story 5.5:` (for the split-off part) and `### Story 5:` (edited original) — or append as next integer if no ordering concern. Agent decides and documents rationale in the change log.
- For MERGE_STORIES: combine two into one; delete the second; leave the second's number as a hole.
- For EDIT_* : in-place section replacement.
- For RE_WAVE: update PM Summary wave assignments table.
- Update the Story Priority Table and PM Summary wave assignments to match any structural changes.
- Commit: `design: improve epic <slug> — <summary from feedback>`.

**GitHub mode:**

- For ADD_STORY: `gh issue create` new `[STORY]` + `[BE]` + `[FE]` + `[INT]` sub-issues. Update EPIC body to reference them.
- For REMOVE_STORY: `gh issue close <num> --reason not_planned` for STORY + all sub-issues. Do not delete. Update EPIC body.
- For SPLIT_STORY: close the original STORY (+ sub-issues) with `not_planned`, create 2 new STORYs + sub-issue families.
- For MERGE_STORIES: close the secondary STORY with `not_planned`, edit the primary STORY body to incorporate the merged AC/TDD.
- For EDIT_* : `gh issue edit <num> --body "<new body>"`.
- For RE_WAVE: update EPIC body's wave assignment table.
- Also update `docs/epics/<slug>.md` summary table to reflect structural changes.
- Commit doc changes with the same commit message format as local mode.

### Phase 4: Re-validate

Automatically invoke `/super-ralph:review-design <TARGET>` on the updated design. Include the verdict in the final report.

### Final report

```markdown
# Design Improved: <epic title>

## Target
<file path or #EPIC_NUMBER>

## Changes Applied
| # | Type | Target | Result |
|---|------|--------|--------|
| 1 | SPLIT | Story 5 | Now Story 5 (list) + Story 5.5 (detail) |
| 2 | EDIT_AC | Story 1 | Added [SECURITY] scenario |

## Skipped
| Target | Reason |
|--------|--------|
| Story 3 | REFUSED — Status: COMPLETED. Shipped work is immutable. |

## Re-Validation Verdict
READY | CONDITIONAL | BLOCKED
<findings summary if any>

## Next
/super-ralph:build-story docs/epics/<slug>.md#story-5
/super-ralph:build-story docs/epics/<slug>.md#story-5.5
```

## Safety rules (applies to improve-design and local-mode finalise)

- **Shipped stories are immutable.** `**Status:** COMPLETED` (local) or CLOSED `[STORY]` issue (GitHub) → refuse the edit. No exceptions from the command; the user must cut a new story.
- **No silent target guesses.** If the target resolver cannot pick a unique high-confidence epic, ask the user (or exit with an explicit error).
- **No silent feedback guesses.** If the feedback interpreter cannot map to a supported change type, return a clarification question and exit.
- **No deletion on GitHub.** Removed stories close with `reason: not_planned`, not `deleted`. Preserves audit trail.
- **No renumbering on remove.** Leaving holes in Story N sequence preserves cross-references in dependency graphs and PR discussions.
- **Re-validate after edit.** Phase 4 always runs `/review-design` on the updated target; user sees the verdict before deciding to build.

## Test plan / acceptance criteria

### AC-1: `/design --local` produces a self-contained epic file
- Given a feature description
- When I run `/super-ralph:design "feature X" --local`
- Then `docs/epics/YYYY-MM-DD-<slug>.md` exists containing epic header + all `### Story N:` sections with nested `[STORY]` / `[BE]` / `[FE]` / `[INT]` sub-sections
- And no GitHub issues are created
- And `git log -1 docs/epics/` shows commit `epic: <title> (local-mode draft)`

### AC-2: `/build-story` operates on a local file
- Given a local epic file with Story 1 containing full TDD bodies
- When I run `/super-ralph:build-story docs/epics/<slug>.md#story-1`
- Then Phase 1 (plan) is skipped (`mode: embedded` in plan-result.md)
- And Phase 2 builds from the extracted sections
- And after Phase 5, the epic file shows `**Status:** COMPLETED` under Story 1
- And no `gh issue close` calls were made

### AC-3: `/e2e` operates on a local file
- Given a local epic file with 3 stories, all `PENDING`
- When I run `/super-ralph:e2e docs/epics/<slug>.md`
- Then all 3 stories execute through plan→build→review-fix→verify
- And sequential finalise updates each story's `**Status:**` to `COMPLETED`
- And the final report shows all 3 stories complete

### AC-4: `/review-design` validates a local file
- Given a local epic file with a story missing a `[SECURITY]` Gherkin scenario
- When I run `/super-ralph:review-design docs/epics/<slug>.md`
- Then the verdict is `BLOCKED` with failure `STORY-G2: story-3 has 2 scenarios, [SECURITY]=0`
- And findings cite `docs/epics/<slug>.md#story-3` instead of `#<issue-number>`

### AC-5: `/improve-design` resolves target from prompt
- Given only `docs/epics/2026-04-18-module-catalog.md` exists in `docs/epics/`
- When I run `/super-ralph:improve-design "Add a SECURITY scenario to Story 1 of the module catalog epic"`
- Then the target resolver returns `docs/epics/2026-04-18-module-catalog.md` with `confidence: high`
- And the feedback interpreter maps it to `EDIT_AC` for `story-1`
- And after apply + commit, the epic file's Story 1 Gherkin block contains a new `Scenario: [SECURITY]` line

### AC-6: `/improve-design` refuses to edit shipped stories
- Given a local epic file with Story 1 marked `**Status:** COMPLETED`
- When I run `/super-ralph:improve-design "Rewrite Story 1's AC"`
- Then the apply-change agent returns `REFUSED`
- And the final report shows Story 1 in the `## Skipped` table with reason `Shipped work is immutable`
- And the epic file is unchanged

### AC-7: `/improve-design` asks for disambiguation on low confidence
- Given two local epics exist: `2026-04-15-foo.md` and `2026-04-16-foo-v2.md`
- When I run `/super-ralph:improve-design "Split Story 5 into list + detail"`
- Then the target resolver returns 2 candidates
- And `AskUserQuestion` surfaces both file paths
- And the command exits after the user picks

### AC-8: `/build` accepts an epic-section path
- Given a local epic file with Story 3 containing BE + FE TDD tasks
- When I run `/super-ralph:build docs/epics/<slug>.md#story-3`
- Then a temp plan is written to `.claude/runs/build-story-3-<slug>/plan.md`
- And ralph-loop executes the extracted tasks

### AC-9: Auto-detect falls through to GitHub mode for numeric args
- When I run `/super-ralph:build-story #42`
- Then current GitHub flow runs unchanged
- When I run `/super-ralph:e2e 123`
- Then current GitHub flow runs unchanged

### AC-10: `--local` and path-based modes are independently toggleable
- `/design --local` produces local output, but a subsequent `/build-story #<num>` still works on GitHub issues (no state carried over between invocations).

## Rollout plan

1. Ship all command edits together (single PR in the plugin). No feature flag — `--local` and path-based args are additive and default off.
2. Update `CHANGELOG.md` in the plugin with a section describing the new mode + new command.
3. Update `commands/help.md` to list `/improve-design` and mention the `--local` / path-based modes.
4. No migration needed — existing GitHub-mode workflows are unaffected.

## Out of scope

- Conversion command `/design --export-to-github <local-file>` (can be added later if needed).
- Auto-sync between a local file and an existing GitHub epic (explicitly a non-goal — one mode per epic).
- Web UI for editing the local epic file (markdown + editor is sufficient).
- Cross-epic refactors (moving stories between epics).

## Dependencies

None new. Uses existing:

- `product-design` skill templates (for re-generating sections in `/improve-design`)
- `issue-management` skill (for GitHub mutations in `/improve-design` GitHub mode)
- `ralph-planning` skill (for `/build` prompt templates)
- `AskUserQuestion` tool (for target disambiguation)
- `Task` tool (for sub-agent dispatch)

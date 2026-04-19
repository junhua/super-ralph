---
name: story-execution
description: "Execute a single story end-to-end from plan to merged PR via a 5-phase state machine (plan → build → review-fix → verify → finalise). Triggers when /super-ralph:build-story is invoked, or when the user mentions 'build a story', 'execute a story', 'run a story', 'story lifecycle', 'phased build', 'TDD build', 'autonomous build', 'fire and forget build', 'build from epic', 'build from issue', 'build from description'. Owns the temp-file bridge between phases so each sub-agent starts with fresh context."
---

> **Config:** Project-specific values (paths, repo, team, test commands) are loaded from `.claude/super-ralph-config.md` (auto-generated on first use by any super-ralph command).

# Story Execution — Phased TDD Lifecycle

## Overview

Execute a single story end-to-end in one fire-and-forget command. Each phase runs as a dedicated sub-agent with a fresh context window. Temp files bridge state between phases so no sub-agent holds the entire story lifecycle in memory.

**Announce at start:** "I'm using the story-execution skill to drive this story through plan → build → review-fix → verify → finalise with fresh-context sub-agents per phase."

**Core insight:** A full story spans ~200 turns across 5 phases. No single sub-agent can hold that context. Temp files let each phase start fresh and read only the 10-20 lines it needs from the previous phase's output. The skill is deterministic: phase N reads `$STORY_DIR/<phase-(N-1)>-result.md`, dispatches a sub-agent, writes `$STORY_DIR/<phase-N>-result.md`.

## The 5-Phase State Machine (at a glance)

| Phase | Goal | Sub-agent | Writes |
|-------|------|-----------|--------|
| 0 | Resolve story context, detect mode (local/GitHub/description), detect resume | orchestrator | `context.md`, `progress.md` |
| 1 | Plan (skipped when TDD tasks already embedded) | opus, 50 turns | `plan-result.md` |
| 2 | Build in isolated worktree with TDD | sonnet (embedded) or opus (standard/hybrid) | `build-result.md` |
| 3 | Review-fix, create PR targeting staging | opus, 80 turns | `review-result.md` |
| 4 | Browser-verify preview deployment (skippable) | — | `verify-result.md` |
| 5 | Merge PR, update board, cascade-close parents (skippable) | — | `final-result.md` |

Each phase has its own reference:
- `references/state-machine.md` — Step 0 context resolution + Step 1 resume detection + `[INT]` sub-issue handling + temp-file layout
- `references/phase-1-plan.md` — Phase 1 plan sub-agent dispatch and skip conditions
- `references/phase-2-build.md` — Phase 2 build sub-agent dispatch and turn budgeting
- `references/phase-3-review-fix.md` — Phase 3 review-fix loop and PR creation
- `references/phase-4-verify.md` — Phase 4 browser verification
- `references/phase-5-finalise.md` — Phase 5 merge + cascade close

## Arguments Accepted by `/super-ralph:build-story`

- **STORY** (required): one of
  - `#<issue-number>` or `<issue-number>` — GitHub issue
  - `docs/epics/<slug>.md#story-N[-<be|fe|int|story>]` — local epic story
  - `"<description string>"` — free text (plan-from-description)
- **`--skip-verify`** — skip Phase 4 (browser verify). Default: verify runs.
- **`--skip-finalise`** — skip Phase 5 (merge + board update).
- **`--resume`** — force resume detection even if temp directory doesn't exist.
- **`--mode auto|standard|hybrid`** — force plan mode. Default: `auto`.
- **`--max-build-iterations N`** — override iteration budget for Phase 2.

## Temp File Strategy

All inter-phase state lives in a per-story directory:

```
$STORY_DIR/ ≡ $(git rev-parse --show-toplevel)/.claude/runs/story-$STORY_ID/
             (fallback: /tmp/super-ralph-story-$STORY_ID/ when .claude not writable)

├── context.md           # Requirements, AC, dependencies (written in Phase 0)
├── plan-result.md       # Phase 1 output: path, branch, mode, task count
├── build-result.md      # Phase 2 output: status, branch, test results
├── review-result.md     # Phase 3 output: PR number, iterations, findings
├── verify-result.md     # Phase 4 output: pass/fail, criteria results
├── final-result.md      # Phase 5 output: merge status, issues closed
└── progress.md          # Live phase tracker for resume detection
```

**Why temp files:** A full story lifecycle spans ~200 turns across 5 phases. No single sub-agent can hold that context. Temp files let each phase start fresh and read only the 10-20 lines it needs from the previous phase's output.

**Durability:** Prefer `$(git rev-parse --show-toplevel)/.claude/runs/` over `/tmp/` — survives reboots and OS `/tmp` cleanup. Fall back to `/tmp/` only when the repo root isn't writable (e.g. sandboxed env).

## Workflow

### Step 0: Resolve & Load

1. Load project config from `.claude/super-ralph-config.md` (same variables as `/super-ralph:design` + `$APP_URL`, `$FE_TEST_CMD`, `$BE_TEST_CMD`).
2. Detect mode via `${CLAUDE_PLUGIN_ROOT}/scripts/parse-local-epic.sh detect-mode "$STORY_REF"`.
3. Branch on mode:
   - `local` → extract STORY/BE/FE/INT bodies from the epic file via `parse-local-epic.sh extract-substory`
   - `github` → `gh issue view` + fetch parent `[EPIC]` for broader context
   - `description` → use the description directly; no GitHub context
4. Write `context.md` and initialize `progress.md`.

Full Step 0 procedure: see `references/state-machine.md`.

### Step 1: Detect Resume State

Based on which result files exist in `$STORY_DIR`, resume from the correct phase. Also check git state (branch exists? PR open?). Full resume-detection table: see `references/state-machine.md`.

### Phase 1: Plan

**Skip detection (important):** If the story source already has TDD tasks embedded (local mode always, or GitHub issue with `## TDD Tasks` in body, or sibling `[BE]`/`[FE]` sub-issues with TDD content), write `plan-result.md` with `mode: embedded` and skip the plan sub-agent entirely.

Otherwise dispatch the plan sub-agent. Full dispatch spec: see `references/phase-1-plan.md`.

### `[INT]` Sub-Issue Handling (branches before Phase 1)

If the target is itself an `[INT]` sub-issue, the flow branches: verify that sibling `[BE]` + `[FE]` are both merged, then execute mock-swap + Gherkin E2E + `/super-ralph:verify` instead of the standard TDD cycle. Do NOT invoke the TDD red/green cycle — that already ran inside `[BE]`/`[FE]`. Full `[INT]` spec: see `references/state-machine.md` § "Handling `[INT]` sub-issues".

### Phase 2: Build

**Model selection:**
- `mode: embedded` → **sonnet** (instructions are implementation-ready, agent copies and executes)
- `mode: standard` or `mode: hybrid` → **opus** (agent needs to reason through implementation)

**Turn budget:** standard = `task_count * 8`, hybrid = `task_count * 12`, min 30, max 200.

Full dispatch spec including worktree setup: see `references/phase-2-build.md`.

### Phase 3: Review-Fix

Loop: rebase to staging default branch → run regression tests → dispatch 6 review agents in parallel (code-reviewer, silent-failure-hunter, pr-test-analyzer, comment-analyzer, type-design-analyzer, code-simplifier) → classify findings (Critical ≥90 conf, Important ≥80) → fix in batches of 3 → re-run tests → loop until 0 Critical + 0 Important or 5 iterations. Then create PR targeting staging with `Closes #<story-id>` (GitHub) or `Closes local epic <path>#story-N` (local).

Full dispatch spec: see `references/phase-3-review-fix.md`.

### Phase 4: Verify (skippable)

Browser-verify the preview deployment against Gherkin acceptance criteria via `/super-ralph:verify`. Skipped when `--skip-verify` is passed.

Full dispatch spec: see `references/phase-4-verify.md`.

### Phase 5: Finalise (skippable)

Merge PR, update project board status to Shipped, cascade-close parent `[STORY]`/`[EPIC]` when all children closed. Skipped when `--skip-finalise` is passed.

In local mode, also update the epic file's `**Status:** PENDING` line to `**Status:** COMPLETED` for the executed story.

Full dispatch spec: see `references/phase-5-finalise.md`.

### Step 6: Summary

Emit final report summarizing each phase's outcome (plan mode, build test results, review iterations, verify verdict, merge status). Template: see `references/phase-5-finalise.md`.

## Failure Handling

### Phase failures

| Phase fails at | Recovery |
|----------------|----------|
| Phase 1 (plan) | Analyze via SME brainstormer, retry once; if retry fails, report and stop |
| Phase 2 (build) | Analyze blockers, attempt one retry; if BLOCKED.md tasks remain, report and stop |
| Phase 3 (review-fix) | If >5 iterations without clean, mark PR as DRAFT and report; do not auto-approve |
| Phase 4 (verify) | Capture verifier report; if RED, open a `[FIX]` issue linked to the story |
| Phase 5 (finalise) | If merge fails due to checks, do not force; report the blocking check |

### Full retry

If the entire flow fails, the run-state directory persists. User can re-invoke `/super-ralph:build-story` with the same target — Step 1 resume detection picks up where it left off.

## Critical Rules

- **Fresh context per phase.** Never chain a sub-agent across phase boundaries; always go back through the temp-file bridge.
- **Deterministic resume.** Phase transitions are driven by file existence + status markers in result files. Never rely on agent memory.
- **Never auto-approve.** Phase 3 stops if iterations exhaust without clean. Phase 4 opens a `[FIX]` instead of marking verified. Phase 5 does not merge without passing checks.
- **Preserve the worktree until Phase 5 merges.** A rolled-back merge means the worktree still holds recoverable state.
- **[INT] is NOT TDD.** Never invoke the TDD red/green cycle for an [INT] sub-issue; it's integration-level work only (mock swap + E2E + verify).
- **Local mode and GitHub mode diverge only at the I/O boundary.** The same phase references apply; mode detection happens once in Step 0.

## Epic-level orchestration (multi-story)

`/super-ralph:build-story` handles ONE story. `/super-ralph:e2e` handles an entire epic by dispatching `story-execution` sub-agents wave-by-wave, then invoking `/super-ralph:release` at the end. The wave-driven multi-story pattern (DAG building, wave gates, sequential finalise, resume detection) is documented in **`references/epic-orchestration.md`**.

## References

- `references/state-machine.md` — Step 0 context resolution, Step 1 resume detection, [INT] handling, temp-file layout
- `references/phase-1-plan.md` — Plan sub-agent dispatch + skip conditions
- `references/phase-2-build.md` — Build sub-agent dispatch + turn budget + worktree setup
- `references/phase-3-review-fix.md` — Review-fix loop, review-agent dispatch, PR creation
- `references/phase-4-verify.md` — Browser verification via `/super-ralph:verify`
- `references/phase-5-finalise.md` — Merge, board update, cascade-close, local epic Status update
- `references/epic-orchestration.md` — Wave-driven multi-story execution for `/super-ralph:e2e`

### Sibling skills

- `../product-design/SKILL.md` — Produces the stories this skill executes
- `../design-review/SKILL.md` — Validates the design before execution starts
- `../issue-management/SKILL.md` — Board/milestone mechanics used by Phase 5
- `../review-fix-loop/` — The review-fix loop this skill's Phase 3 is built on (intentionally command-only — `DO_NOT_ADD_SKILL.md`)
- `../browser-verification/SKILL.md` — Backs the `/super-ralph:verify` invocation used in Phase 4
- `../build/SKILL.md` — Backs the `/super-ralph:build` invocation used inside Phase 2

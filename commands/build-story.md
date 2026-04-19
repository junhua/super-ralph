---
name: build-story
description: "Execute a single story end-to-end — build, review-fix, verify, finalise. Skips plan phase when story issue contains TDD tasks."
argument-hint: "<STORY> [--skip-verify] [--skip-finalise] [--resume] [--mode auto|standard|hybrid] [--max-build-iterations N]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph-loop.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/parse-local-epic.sh:*)", "Bash(git:*)", "Bash(gh:*)", "Bash(bun:*)", "Bash(codex:*)", "Bash(mkdir:*)", "Bash(cat:*)", "Bash(rm:*)", "Bash(wc:*)", "Bash(jq:*)", "Bash(date:*)", "Bash(realpath:*)", "Bash(test:*)", "Bash(cp:*)", "Read", "Write", "Edit", "Glob", "Grep", "Task"]
---

# Super-Ralph Build-Story Command

Execute a single story from plan to merged PR in one fire-and-forget command. Each phase runs as a dedicated sub-agent with a fresh context window. Temp files bridge state between phases so no sub-agent holds the entire story lifecycle in memory.

**This is a zero-touch command.** Once invoked, it drives a story through build → review-fix → verify → finalise (skipping plan when TDD tasks are embedded in the issue) with zero human interaction.

## Arguments

- **STORY** (required): one of
  - **GitHub issue**: `#42` or `42` — fetches story context from the issue
  - **Local epic story**: `docs/epics/my-epic.md#story-3` (optionally `...#story-3-be`, `...#story-3-fe`, `...#story-3-int`, `...#story-3-story`)
  - **Description string**: `"Add JWT authentication"` — used directly as the feature description
- **`--skip-verify`** (optional): Skip Phase 4 (browser verification). Default: verify runs.
- **`--skip-finalise`** (optional): Skip Phase 5 (merge + status update). Useful when you want to review the PR manually first.
- **`--resume`** (optional): Force resume detection even if temp directory doesn't exist. Default: auto-detect.
- **`--mode`** (optional): Force plan mode. `auto` (default), `standard`, or `hybrid`.
- **`--max-build-iterations`** (optional): Override iteration budget for the build phase. Default: from plan.

## Workflow

Execute the 5-phase state machine defined by the `super-ralph:story-execution` skill. **NEVER ask for human input** — dispatch research + SME agents for all decisions.

### Step 0: Load Project Config & Skill

Read `.claude/super-ralph-config.md` to load every `$VARIABLE` referenced by the skill and its references. If the file does not exist, attempt auto-init via the init command logic; otherwise tell the user to run `/super-ralph:init`.

Invoke the `super-ralph:story-execution` skill for the full state machine, temp-file bridge, and per-phase sub-agent dispatch specifications.

### Step 1: Resolve Story Context & Detect Resume

Follow `${CLAUDE_PLUGIN_ROOT}/skills/story-execution/references/state-machine.md`:

- Detect mode (`local` / `github` / `description`) via `${CLAUDE_PLUGIN_ROOT}/scripts/parse-local-epic.sh detect-mode "$STORY_REF"`
- Resolve story context and write `context.md`
- Initialize `progress.md`
- Detect resume state (which phase to start from based on existing result files and git state)
- Branch on `[INT]` sub-issue if the target is one (state-machine.md § "Handling `[INT]` sub-issues")

### Step 2: Execute the 5 Phases

For each phase in order, dispatch the sub-agent per its reference, read the result file, update `progress.md`, and proceed to the next phase:

| Phase | Reference |
|-------|-----------|
| Phase 1 (Plan, skip-when-embedded) | `${CLAUDE_PLUGIN_ROOT}/skills/story-execution/references/phase-1-plan.md` |
| Phase 2 (Build in worktree with TDD) | `${CLAUDE_PLUGIN_ROOT}/skills/story-execution/references/phase-2-build.md` |
| Phase 3 (Review-fix loop → PR) | `${CLAUDE_PLUGIN_ROOT}/skills/story-execution/references/phase-3-review-fix.md` |
| Phase 4 (Verify — skippable via `--skip-verify`) | `${CLAUDE_PLUGIN_ROOT}/skills/story-execution/references/phase-4-verify.md` |
| Phase 5 (Finalise — skippable via `--skip-finalise`) | `${CLAUDE_PLUGIN_ROOT}/skills/story-execution/references/phase-5-finalise.md` |

### Step 3: Summary

Emit the final report summarizing each phase's outcome (plan mode, build test results, review iterations, verify verdict, merge status). See `phase-5-finalise.md` § "Summary" for the template.

## Critical Rules

- **Fresh context per phase.** Never chain a sub-agent across phase boundaries; always go back through the temp-file bridge.
- **Deterministic resume.** Phase transitions are driven by file existence + status markers in result files. Never rely on agent memory.
- **Never auto-approve.** Phase 3 stops if iterations exhaust without clean. Phase 4 opens a `[FIX]` instead of marking verified. Phase 5 does not merge without passing checks.
- **Preserve the worktree until Phase 5 merges.** A rolled-back merge means the worktree still holds recoverable state.
- **`[INT]` is NOT TDD.** Never invoke the TDD red/green cycle for an `[INT]` sub-issue; it's integration-level work only.
- **Local mode and GitHub mode diverge only at the I/O boundary.** Mode detection happens once in Step 1; phase references apply uniformly after that.

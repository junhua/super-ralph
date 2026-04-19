---
name: e2e
description: "Execute an entire epic end-to-end — plan, build, review, verify, finalise all stories, then release"
argument-hint: "EPIC_NUMBER [--milestone NAME] [--max-parallel N] [--skip-release] [--skip-verify]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph-loop.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/parse-local-epic.sh:*)", "Bash(git:*)", "Bash(gh:*)", "Bash(bun:*)", "Bash(codex:*)", "Bash(mkdir:*)", "Bash(cat:*)", "Bash(rm:*)", "Bash(wc:*)", "Bash(jq:*)", "Bash(date:*)", "Read", "Write", "Edit", "Glob", "Grep", "Task"]
---

# Super-Ralph E2E Command

Execute an entire epic from start to finish: load the epic, plan story execution waves, dispatch parallel story executors (plan → build → review-fix → verify), finalise stories sequentially, then run release to promote staging → main.

**This is a fire-and-forget command.** Once invoked, it drives an entire epic to completion with zero human interaction. All decisions are made autonomously via research + SME brainstorming.

## Branch Model Context

```
story branches ──review-fix→PR──▶ staging (default, preview deploys)
                                       │
                              /super-ralph:release
                                       │
                                       ▼
                                  main (production)
```

All story PRs target `staging` (GitHub default branch). The release phase at the end promotes staging → main.

## Arguments

- **EPIC** (required): GitHub issue number of the `[EPIC]` (`#123` or `123`), or a local epic file path (`docs/epics/<slug>.md`).
- **`--milestone`** (optional): Milestone name for the release phase. If omitted, auto-detect from the epic's milestone.
- **`--max-parallel`** (optional): Max stories executing in parallel per wave. Default: `3`.
- **`--skip-release`** (optional): Skip the final release phase. Useful for partial epic execution.
- **`--skip-verify`** (optional): Skip browser verification for all stories (passes through to each story-executor's `/super-ralph:build-story --skip-verify`).

## Workflow

Execute the wave-driven multi-story flow defined by the `super-ralph:story-execution` skill's epic orchestration.

### Step 0: Load Project Config & Skills

Read `.claude/super-ralph-config.md` to load every `$VARIABLE` used by the skill and its references (same set as `/super-ralph:build-story` + `$PM_USER`, `$TECH_LEAD`, `$TESTERS`, `$MAIN_BRANCH`, `$STAGING_BRANCH`).

Invoke:
- **`super-ralph:story-execution`** — for per-story lifecycle (each wave story is handled by this skill's 5 phases)
- **`super-ralph:release-flow`** — for the final staging → main promotion (unless `--skip-release`)
- **`super-ralph:product-design`** — for wave assignment + DAG concepts (`execution-planning.md`)
- **`super-ralph:issue-management`** — for epic/story status tracking

### Step 1: Execute the Wave Orchestration

Follow `${CLAUDE_PLUGIN_ROOT}/skills/story-execution/references/epic-orchestration.md`:

1. **Load epic context** — fetch epic body + all `[STORY]` sub-issues (GitHub) or parse the epic file (local)
2. **Filter actionable stories** — skip `COMPLETED` / CLOSED; prefer P0 → P1 → P2; respect `--max-parallel`
3. **Plan execution waves** — topological sort on the dependency DAG from the epic's Execution Plan; cross-reference `${CLAUDE_PLUGIN_ROOT}/skills/product-design/references/execution-planning.md` § "Wave Assignment"
4. **Initialize progress tracker** at `$(git rev-parse --show-toplevel)/.claude/runs/e2e-<epic-slug>/progress.md`
5. **For each wave, in order:**
   - Dispatch up to `--max-parallel` story-executor sub-agents in parallel. Each executor invokes the `super-ralph:story-execution` skill (effectively runs `/super-ralph:build-story` internally) for one story.
   - Monitor wave completion via temp-file polling
   - Run finalise sequentially (per the `super-ralph:release-flow` skill's Flow A) after all stories in the wave merge
   - Update plan + epic status for each merged story
   - Wave gate: verify all merged and CD healthy before starting next wave

### Step 2: Release (unless `--skip-release`)

After the final wave completes successfully, invoke `/super-ralph:release` to promote staging → main. This delegates to `super-ralph:release-flow` Flow B (10-phase promotion). See `${CLAUDE_PLUGIN_ROOT}/skills/release-flow/references/release-flow.md`.

### Step 3: Final Summary

Emit the epic-level summary: stories completed per wave, release tag + URL, any `[FIX]` issues opened, time consumed. Template in `${CLAUDE_PLUGIN_ROOT}/skills/story-execution/references/epic-orchestration.md` § "Final Summary".

## Resuming After Failures

Run-state in `.claude/runs/e2e-<epic-slug>/` persists. On re-invoke, the orchestrator detects which waves completed, which stories merged, and which are still open — then resumes from the appropriate point.

Full resume-detection table: see `${CLAUDE_PLUGIN_ROOT}/skills/story-execution/references/epic-orchestration.md` § "Resuming After Failures".

## Critical Rules

- **Waves are atomic.** Never start Wave N+1 before Wave N is fully merged and CD green. A half-shipped wave creates integration risk.
- **Max-parallel is per wave, not global.** Respect it strictly to avoid overwhelming CI / Vercel build concurrency.
- **Never skip finalise.** Even with `--skip-release`, each story's PR must be finalised (merged + board-updated) before the next wave starts.
- **`--skip-release` is for partial work, not shortcuts.** The release phase is the only way to promote staging → production.
- **Story failures don't sink the wave automatically.** Failed stories are logged; decide per wave whether to proceed (see `epic-orchestration.md` § "Wave-Level Decisions").
- **Resumable by design.** Never delete run-state mid-flow. Cleanup happens only after the release succeeds or the user explicitly runs `/super-ralph:cleanup`.

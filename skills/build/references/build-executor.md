# Build Executor — Detailed Reference

This document is a detailed reference for the build skill. The skill's `SKILL.md` is the canonical action guide — read that first. This file explains edge cases, gotchas, and reasoning behind the 7 steps.

## Why 7 Steps in One Turn?

The build skill is the bridge between a static plan file and the autonomous ralph-loop. If any step is skipped or printed instead of executed, the ralph-loop never starts. The skill MUST:
- Create isolation (worktree)
- Ingest the plan (read, extract header values)
- Construct the first iteration message
- Write the state file that the Stop hook reads
- Emit the first iteration

Splitting this across turns means a human has to press "continue" after each step — defeating the fire-and-forget design.

## Slug Derivation

Given `docs/plans/2026-04-17-admin-module-activation.md`:
- basename: `2026-04-17-admin-module-activation.md`
- strip date prefix: `admin-module-activation.md`
- strip `.md`: `admin-module-activation`
- worktree name: `super-ralph/admin-module-activation`

Regex: `s/^[0-9]{4}-[0-9]{2}-[0-9]{2}-//`

## Worktree Gotchas

- `EnterWorktree` persists CWD across tool calls. `cd` in Bash does NOT.
- If the skill is invoked from within an existing worktree, `EnterWorktree` will error — catch and continue.
- The worktree is created from current HEAD of the main repo, branched as `worktree-<name>`. Rename to `super-ralph/<slug>` immediately.
- Untracked files (including the plan itself) do NOT appear in the new worktree. Copy the plan from `PLAN_ABS_PATH` BEFORE resolving it relative to CWD.

## Mode Detection

Scan the first 80 lines of the plan for:
```
> **Mode:** hybrid
```
or
```
Mode: standard
```

Case-insensitive. If both or neither found, default to `hybrid` (more robust for complex plans).

## Iteration Budget Parsing

Look for lines like:
- `> **Iteration Budget:** 45 expected, 65 max`
- `Iteration Budget: 30 (--max-iterations 30)`
- `11 tasks → 45 iterations expected, 65 max`

Extract the `max` number. Fallback: `50`.

## Completion Promise

Scan for:
- `<promise>ALL_TASKS_COMPLETE</promise>` → use `ALL_TASKS_COMPLETE`
- `Completion Promise: X` → use `X`
- Default: `COMPLETE`

## Template Substitution

Standard template placeholders:
- `[PLAN_PATH]` — replace with relative path to plan (CWD is worktree)
- `[N]` — replace with iteration budget max

Hybrid template placeholders:
- `[PLAN_FILE_PATH]` — same
- `[N]` — same

Some templates have `[N]` appearing multiple times — use global replace.

## Autonomous Decision Injection

Always append this block to the Skills section of the prompt, regardless of mode:

```
## Autonomous Decisions

When you encounter ambiguity or need to make a design decision: dispatch a research-agent (Task tool) for web references, then dispatch 1-2 sme-brainstormer agents for analysis. Pick the most rational option. NEVER wait for human input.
```

This is what differentiates super-ralph from plain ralph-loop.

## Setup Script Contract

`${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph-loop.sh` takes:
1. Positional arg: the full prompt text (single-quoted)
2. `--max-iterations N`
3. `--completion-promise TEXT`

It writes `.claude/ralph-loop.local.md` in CWD with `active: true`.

The script expects CWD to be the worktree (or repo root). If misdirected, the state file lands in the wrong `.claude/`.

## Output of Step 7

The skill's final output (visible to the user) is the first iteration of the ralph-loop prompt. It is NOT wrapped in a code fence. It starts with something like:

```
You are running an autonomous implementation loop via Ralph Loop (hybrid mode).
You are the ORCHESTRATOR...
```

The Stop hook catches the model's natural exit and re-injects this same prompt for the next iteration. No user interaction needed between iterations until the promise (`ALL_TASKS_COMPLETE`) is emitted.

## Failure Modes

| Problem | Symptom | Fix |
|---------|---------|-----|
| Plan file missing | `realpath` error | Require absolute path in user input |
| Already in worktree | `EnterWorktree` errors | Catch, use current directory |
| Plan untracked in main repo | File not in worktree after switch | Copy from `PLAN_ABS_PATH` |
| Template placeholder not found | Empty substitution | Fall back to bracketed placeholder |
| Setup script errors | `.claude/ralph-loop.local.md` not written | Re-run script with absolute script path |
| Print-instead-of-execute | User sees orchestrator prompt as documentation | Ensure skill emits prompt as assistant message, not user-facing quote |

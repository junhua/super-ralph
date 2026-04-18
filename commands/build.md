---
name: build
description: "Execute an implementation plan autonomously via ralph-loop with superpowers"
argument-hint: "<plan-path | epic-file.md#story-N> [--max-iterations N] [--mode standard|hybrid]"
allowed-tools: ["EnterWorktree", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph-loop.sh:*)", "Bash(git:*)", "Bash(bun:*)", "Bash(npm:*)", "Bash(realpath:*)", "Bash(cp:*)", "Bash(mkdir:*)", "Bash(test:*)", "Read", "Write", "Glob", "Grep", "Task", "Skill"]
---

# /super-ralph:build

Execute an implementation plan autonomously via ralph-loop.

**Usage:**
- `/super-ralph:build <plan-path>` — execute a standalone plan from `docs/plans/`
- `/super-ralph:build <epic-file.md>#story-N` — execute a specific story from a local epic (concatenates BE+FE TDD tasks)
- `/super-ralph:build <epic-file.md>#story-N-<be|fe|int>` — execute a specific sub-body only

Optional: `[--max-iterations N] [--mode standard|hybrid]`

## Execution

This command invokes the `build` skill, which handles all 7 steps (worktree creation, plan parsing, prompt construction, ralph-loop setup, first-iteration emission) in a single turn.

**Invoke the skill:** `Skill(skill: "super-ralph:build", args: "<plan-path> [flags]")`

The skill is at `${CLAUDE_PLUGIN_ROOT}/skills/build/SKILL.md`.

## What the Skill Does

1. Parses arguments (plan path, optional flags)
2. Resolves plan to absolute path, creates isolated worktree via `EnterWorktree`
3. Reads plan header for mode, iteration budget, completion promise
4. Optionally validates via `plan-reviewer` agent
5. Constructs orchestrator prompt from `skills/ralph-planning/references/prompt-{standard,hybrid}.md`
6. Writes `.claude/ralph-loop.local.md` via `scripts/setup-ralph-loop.sh`
7. Emits first iteration message — ralph-loop Stop hook takes over

## Do NOT

- Read this file and try to re-execute the full 7-step workflow yourself. Invoke the skill.
- Print the plan or the prompt.
- Ask the user for clarification.

## See Also

- Skill: `${CLAUDE_PLUGIN_ROOT}/skills/build/SKILL.md`
- Executor reference: `${CLAUDE_PLUGIN_ROOT}/skills/build/references/build-executor.md`
- Standard prompt template: `${CLAUDE_PLUGIN_ROOT}/skills/ralph-planning/references/prompt-standard.md`
- Hybrid prompt template: `${CLAUDE_PLUGIN_ROOT}/skills/ralph-planning/references/prompt-hybrid.md`
- Plan reviewer agent: `${CLAUDE_PLUGIN_ROOT}/agents/plan-reviewer.md`

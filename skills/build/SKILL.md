---
name: super-ralph:build
description: "Execute an implementation plan autonomously via ralph-loop. Triggers when `/super-ralph:build <plan-path>` is invoked."
---

# Super-Ralph Build Skill

Execute an implementation plan autonomously via ralph-loop with superpowers integration.

## Invocation

```
/super-ralph:build <plan-path> [--max-iterations N] [--mode standard|hybrid]
```

Examples:
```
/super-ralph:build docs/plans/2026-04-17-admin-module-activation.md
/super-ralph:build docs/plans/my-feature.md --max-iterations 80 --mode hybrid
```

## Your Job

DO NOT print the plan or prompt. Execute these 7 steps in sequence, in THIS TURN:

### 1. Parse Arguments
Extract: `plan_path`, optional `--max-iterations N`, optional `--mode standard|hybrid`

### 2. Resolve Plan Path & Create Worktree
- `PLAN_ABS_PATH=$(realpath <plan_path>)`
- `PLAN_SLUG=` strip date prefix + .md from basename
- Call `EnterWorktree` with `name="super-ralph/$PLAN_SLUG"`
- Copy plan file into worktree if it doesn't exist
- Install dependencies
- Report: `"Worktree ready. Proceeding."`

### 3. Read Plan
Extract from plan file headers:
- Mode (standard or hybrid)
- Iteration Budget
- Completion Promise (e.g., "ALL_TASKS_COMPLETE")

### 4. Validate Plan (optional)
Dispatch `super-ralph:plan-reviewer` agent if validation needed.

### 5. Construct Execution Prompt
- Read template: `prompt-standard.md` or `prompt-hybrid.md` (from skills/ralph-planning/references/)
- Fill `[PLAN_FILE_PATH]` with actual path (relative, CWD is worktree)
- Fill `[N]` with iteration budget (apply --max-iterations override if provided)
- Append autonomous decision section from template

### 6. Setup Ralph Loop
Run the setup script:
```bash
/Users/junhua/.claude/plugins/super-ralph/scripts/setup-ralph-loop.sh \
  "<PROMPT>" \
  --max-iterations <N> \
  --completion-promise "<PROMISE>"
```

Creates `.claude/ralph-loop.local.md` in the worktree.

### 7. Start Execution
Output the execution prompt. The ralph-loop Stop hook will take it from there.

## Critical Rules

- **DO NOT ask questions.** Execute all 7 steps now.
- **DO NOT print the plan.** Read it and extract values, don't output it.
- **DO NOT print the prompt.** Construct it, then output it as the ralph-loop prompt.
- **Use `EnterWorktree`** — it persists CWD across tool calls.
- **Resolve paths to absolute BEFORE switching CWD**.
- **Copy untracked plans** into the worktree.
- **Execute steps 1–7 in this single turn** — no waiting, no pausing.

## See Also

- Execution templates: `skills/ralph-planning/references/prompt-standard.md` and `prompt-hybrid.md`
- Plan template: `skills/ralph-planning/references/plan-template.md`
- Plan reviewer: `agents/plan-reviewer.md`

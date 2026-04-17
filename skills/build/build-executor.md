# Build Executor — Internal Implementation

This document is read by the build skill to understand how to execute the build workflow.

## Quick Reference

For `/super-ralph:build <plan-path>`, execute these steps in order:

### 1. Parse Arguments

Extract from user input:
- `plan_path` = the file path (required)
- `max_iterations` = from `--max-iterations N` (optional, overrides plan)
- `mode` = from `--mode standard|hybrid` (optional, overrides plan)

### 2. Resolve Plan Path (Step 0)

```bash
PLAN_ABS_PATH=$(realpath "<plan_path>")
PLAN_SLUG=$(basename "<plan_path>" .md | sed 's/^[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}-//')
WORKTREE_NAME="super-ralph/$PLAN_SLUG"
```

Create worktree and switch CWD into it:
```bash
git branch -m "super-ralph/$PLAN_SLUG"  # if already in one
# OR
EnterWorktree with name="$WORKTREE_NAME"
```

Then:
```bash
bun install  # or npm install
test -f docs/plans/2026-04-17-admin-module-activation-workflow.md || cp "$PLAN_ABS_PATH" "docs/plans/..."
```

Report: `"Worktree ready at <cwd> on branch $WORKTREE_NAME. Proceeding with build."`

### 3. Read Plan (Step 1)

Read the plan file and extract:
- Mode (standard or hybrid) — from header "Mode:"
- Skills — from header "Skills:"
- Iteration Budget — from header "Iteration Budget:"
- Completion Promise — from header or "Completion Criteria" section

### 4. Validate Plan (Step 2)

Dispatch Task tool with `super-ralph:plan-reviewer` agent. If issues found, auto-fix where possible.

### 5. Construct Prompt (Step 3)

Read the appropriate template:
- Standard: `/Users/junhua/.claude/plugins/super-ralph/skills/ralph-planning/references/prompt-standard.md`
- Hybrid: `/Users/junhua/.claude/plugins/super-ralph/skills/ralph-planning/references/prompt-hybrid.md`

Fill in:
- `[PLAN_FILE_PATH]` or `[PLAN_PATH]` → actual plan path (relative, CWD is worktree)
- `[N]` → max iterations from plan (or override)

Append autonomous decision section:
```
## Autonomous Decisions

When you encounter ambiguity or need to make a design decision: dispatch a research-agent (Task tool) for web references, then dispatch 1-2 sme-brainstormer agents for analysis. Pick the most rational option. NEVER wait for human input.
```

### 6. Setup Ralph Loop (Step 4)

```bash
/Users/junhua/.claude/plugins/super-ralph/scripts/setup-ralph-loop.sh \
  "<PROMPT>" \
  --max-iterations <N> \
  --completion-promise "<PROMISE>"
```

This creates `.claude/ralph-loop.local.md` in the worktree.

### 7. Start Execution (Step 5)

Output the execution prompt. The ralph-loop Stop hook will intercept exit and feed it back.

## Do NOT

- Ask the user any questions
- Print the plan file
- Print the prompt before executing
- Try to reason about what to build — just follow the steps
- Break the steps into multiple turns — do all 7 steps in this turn

## DO

- Resolve paths to absolute before switching directories
- Use EnterWorktree to switch CWD persistently
- Copy plan files if they're untracked
- Report progress after Step 0
- Let the ralph-loop handle the rest after Step 7

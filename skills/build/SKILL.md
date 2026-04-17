---
name: build
description: "Execute an implementation plan autonomously via ralph-loop. Triggers on `/super-ralph:build <plan-path>`, or when user mentions 'run plan', 'execute plan', 'autonomous build', 'ralph-loop build', 'walk-away build', 'overnight build', or wants a plan file executed fire-and-forget."
---

# Build Skill

Execute an implementation plan autonomously via ralph-loop with superpowers integration.

**Announce at start:** "Using the build skill to launch autonomous execution of the plan."

## Invocation

```
/super-ralph:build <plan-path> [--max-iterations N] [--mode standard|hybrid]
```

## Your Job — Execute ALL Steps in THIS TURN

**DO NOT print the plan. DO NOT print the orchestrator prompt. DO NOT ask questions. Execute the 7 steps below in this single turn.**

### 1. Parse Arguments

Extract from user input:
- `plan_path` = the file path (required)
- `max_iterations` = from `--max-iterations N` (optional, overrides plan)
- `mode` = from `--mode standard|hybrid` (optional, overrides plan)

### 2. Resolve Path & Create Worktree

```bash
PLAN_ABS_PATH=$(realpath "<plan_path>")
PLAN_SLUG=$(basename "<plan_path>" .md | sed -E 's/^[0-9]{4}-[0-9]{2}-[0-9]{2}-//')
```

Call `EnterWorktree` with `name="super-ralph/$PLAN_SLUG"`. If already in a worktree, skip and use current directory.

Then:
```bash
git branch -m "super-ralph/$PLAN_SLUG" 2>/dev/null || true
test -f "<relative-plan-path>" || (mkdir -p "$(dirname "<relative-plan-path>")" && cp "$PLAN_ABS_PATH" "<relative-plan-path>")
# install dependencies
if [ -f bun.lock ] || [ -f bun.lockb ]; then bun install; elif [ -f package.json ]; then npm install; fi
```

Report: `"Worktree ready at <cwd> on branch super-ralph/$PLAN_SLUG. Proceeding with build."`

### 3. Read Plan Header

Read ONLY the first 80 lines of the plan file. Extract:
- `mode` — from "Mode: standard" or "Mode: hybrid"
- `iteration_budget_max` — from "Iteration Budget: ... N max"
- `completion_promise` — from header (default: `ALL_TASKS_COMPLETE`)

Apply CLI overrides (`--max-iterations`, `--mode`) if provided.

### 4. Validate Plan (optional fast-path)

Dispatch `super-ralph:plan-reviewer` agent (Task tool, haiku model). If ISSUES found, auto-fix trivial ones via Edit; otherwise warn and proceed.

### 5. Construct Execution Prompt

Read template from the skill references (use `${CLAUDE_PLUGIN_ROOT}` — do NOT hardcode paths):
- Standard mode: `${CLAUDE_PLUGIN_ROOT}/skills/ralph-planning/references/prompt-standard.md`
- Hybrid mode: `${CLAUDE_PLUGIN_ROOT}/skills/ralph-planning/references/prompt-hybrid.md`

Substitute:
- `[PLAN_FILE_PATH]` or `[PLAN_PATH]` → relative path (CWD = worktree)
- `[N]` → iteration_budget_max

Append at the end of the Skills section:
```
## Autonomous Decisions

When you encounter ambiguity or need to make a design decision: dispatch a research-agent (Task tool) for web references, then dispatch 1-2 sme-brainstormer agents for analysis. Pick the most rational option. NEVER wait for human input.
```

### 6. Write Ralph-Loop State File

Run the setup script (use `${CLAUDE_PLUGIN_ROOT}`):
```bash
${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph-loop.sh "<PROMPT>" \
  --max-iterations <N> \
  --completion-promise "<PROMISE>"
```

This creates `.claude/ralph-loop.local.md` in the current worktree.

### 7. Emit First Iteration

Output the constructed execution prompt as an assistant message. The ralph-loop Stop hook will feed it back on each iteration.

Do NOT quote it inside a code fence. Do NOT prefix with "Here is the prompt:". Do NOT print the full plan. Output the prompt as the first iteration message — nothing else.

## Critical Rules

- **ORCHESTRATOR ONLY** — do not write task code; dispatch subagents.
- **DO NOT print** the plan, the template, or intermediate state.
- **Use `EnterWorktree`** — Bash `cd` does not persist across tool calls.
- **Use `${CLAUDE_PLUGIN_ROOT}`** for every path to the plugin — never hardcode `/Users/...`.
- **Copy untracked plan files** into the worktree before execution.
- **All 7 steps in ONE turn.** No waiting, no pausing.
- **Never ask the user questions.** All ambiguity resolves through research-agent + sme-brainstormer.

## References

- Execution templates: `${CLAUDE_PLUGIN_ROOT}/skills/ralph-planning/references/prompt-standard.md` and `prompt-hybrid.md`
- Plan template: `${CLAUDE_PLUGIN_ROOT}/skills/ralph-planning/references/plan-template.md`
- Plan reviewer: `${CLAUDE_PLUGIN_ROOT}/agents/plan-reviewer.md`
- Detailed executor reference: `references/build-executor.md`

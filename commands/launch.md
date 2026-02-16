---
name: launch
description: "Launch a ralph-loop to execute an implementation plan autonomously with superpowers"
argument-hint: "<plan-path> [--max-iterations N] [--mode standard|hybrid]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph-loop.sh:*)", "Bash(git:*)", "Bash(bun:*)", "Bash(npm:*)", "Read", "Write", "Glob", "Grep", "Task"]
---

# Super-Ralph Launch Command

Read an implementation plan and launch a Ralph Loop to execute it autonomously with superpowers integration.

## Arguments

Parse the user's input for:
- **plan-path** (required): Path to the implementation plan file
- **--max-iterations** (optional): Override iteration budget from plan
- **--mode** (optional): Override mode from plan (`standard` or `hybrid`)

## Workflow

### Step 0: Create Isolated Worktree

Create a git worktree so the ralph loop doesn't interfere with other Claude windows.

1. **Detect worktree directory** (autonomous — never ask the user):
   ```bash
   # Priority: existing .worktrees/ > existing worktrees/ > CLAUDE.md preference > default .worktrees/
   if [ -d .worktrees ]; then WTDIR=".worktrees"
   elif [ -d worktrees ]; then WTDIR="worktrees"
   else WTDIR=".worktrees"
   fi
   ```

2. **Ensure directory is git-ignored** (fix immediately if not):
   ```bash
   git check-ignore -q "$WTDIR" 2>/dev/null || echo "$WTDIR/" >> .gitignore
   ```

3. **Derive branch name** from the plan filename:
   ```bash
   # e.g. docs/plans/2026-02-15-auth-api.md → super-ralph/auth-api
   PLAN_SLUG=$(basename "<plan-path>" .md | sed 's/^[0-9-]*//')
   BRANCH="super-ralph/${PLAN_SLUG}"
   ```

4. **Create worktree**:
   ```bash
   git worktree add "$WTDIR/$PLAN_SLUG" -b "$BRANCH"
   ```

5. **Install dependencies** (auto-detect):
   ```bash
   cd "$WTDIR/$PLAN_SLUG"
   if [ -f bun.lock ] || [ -f bun.lockb ]; then bun install
   elif [ -f package.json ]; then npm install
   fi
   ```

6. **All subsequent steps run inside the worktree.** The ralph-loop state file (`.claude/ralph-loop.local.md`) will be created inside the worktree, keeping it isolated from the main working directory.

7. **Report**: `"Worktree created at <path> on branch <BRANCH>. Starting execution."`

### Step 1: Read and Parse the Plan

1. Read the plan file at the provided path
2. Extract from the plan header:
   - **Mode:** standard or hybrid
   - **Skills:** list of superpowers to invoke
   - **Iteration Budget:** max iterations
   - **Completion Promise:** what promise tag to use (default: COMPLETE)
3. Apply any command-line overrides (--max-iterations, --mode)

### Step 2: Validate the Plan

Dispatch the `super-ralph:plan-reviewer` agent (Task tool) to validate the plan for autonomous execution readiness.

- If **APPROVED**: proceed to Step 3
- If **ISSUES**: attempt to auto-fix by editing the plan file. If unfixable, warn but proceed anyway (don't block launch)

### Step 3: Construct Execution Prompt

Based on the mode, construct the ralph-loop prompt:

**For standard mode:**
Read `${CLAUDE_PLUGIN_ROOT}/skills/ralph-planning/references/prompt-standard.md` and fill in:
- `[PLAN_PATH]` → the actual plan file path
- `[N]` → max iterations

**For hybrid mode:**
Read `${CLAUDE_PLUGIN_ROOT}/skills/ralph-planning/references/prompt-hybrid.md` and fill in:
- `[PLAN_FILE_PATH]` → the actual plan file path
- `[N]` → max iterations

**Add autonomous decision injection to the prompt:**
Append to the Skills section:
```
- When you encounter ambiguity or need to make a design decision: dispatch a research-agent (Task tool) for web references, then dispatch 1-2 sme-brainstormer agents for analysis. Pick the most rational option. NEVER wait for human input.
```

### Step 4: Set Up Ralph Loop

Run the ralph-loop setup script to create `.claude/ralph-loop.local.md`:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph-loop.sh "<PROMPT>" --max-iterations <N> --completion-promise "<PROMISE>"
```

Where:
- `<PROMPT>` is the constructed execution prompt from Step 3
- `<N>` is the max iterations value
- `<PROMISE>` is the completion promise (default: COMPLETE)

### Step 5: Start Execution

Output the execution prompt as the first iteration message. The ralph-loop Stop hook will intercept exit and feed the prompt back for subsequent iterations.

## Critical Rules

- **Always create a worktree.** Never run a ralph loop in the main working directory.
- **Never ask the user** about worktree location. Default to `.worktrees/` autonomously.
- **Read the plan completely** before constructing the prompt. The plan contains the context the executor needs.
- **Paste full task text** into hybrid mode subagent prompts — never make subagents read the plan file.
- **Include skill directives** in the prompt — these tell the executor which superpowers to invoke.
- **Include the autonomous decision pattern** — this is what makes super-ralph different from plain ralph-loop.

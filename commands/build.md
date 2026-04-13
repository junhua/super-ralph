---
name: build
description: "Execute an implementation plan autonomously via ralph-loop with superpowers"
argument-hint: "<plan-path> [--max-iterations N] [--mode standard|hybrid]"
allowed-tools: ["EnterWorktree", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph-loop.sh:*)", "Bash(git:*)", "Bash(bun:*)", "Bash(npm:*)", "Bash(realpath:*)", "Bash(cp:*)", "Bash(mkdir:*)", "Bash(test:*)", "Read", "Write", "Glob", "Grep", "Task"]
---

# Super-Ralph Build Command

Read an implementation plan and launch a Ralph Loop to execute it autonomously with superpowers integration.

> **AUTONOMOUS FLOW: Steps 0–5 are a single continuous sequence. Execute ALL steps without pausing, without asking the user questions, without requesting manual commands. NEVER tell the user to `cd`, run a command, or switch directories. If you hit an issue, resolve it yourself and keep going.**

## Arguments

Parse the user's input for:
- **plan-path** (required): Path to the implementation plan file
- **--max-iterations** (optional): Override iteration budget from plan
- **--mode** (optional): Override mode from plan (`standard` or `hybrid`)

## Workflow

### Step 0: Create Isolated Worktree and Switch CWD Into It

Create a git worktree and **persistently switch your session CWD** into it so the ralph loop runs in isolation. You MUST use the `EnterWorktree` tool — Bash `cd` does NOT persist across tool calls.

1. **Resolve the plan file to an absolute path** BEFORE switching directories (it may be untracked and absent from the worktree):
   ```bash
   realpath "<plan-path>"
   ```
   Store the result as `PLAN_ABS_PATH`.

2. **Derive the worktree name** from the plan filename:
   ```
   # e.g. docs/plans/2026-02-15-auth-api.md → super-ralph/auth-api
   PLAN_SLUG = strip leading date-and-dashes prefix and .md extension from basename
   WORKTREE_NAME = "super-ralph/<PLAN_SLUG>"
   ```

3. **Call `EnterWorktree`** with `name: "super-ralph/<plan-slug>"`:
   - This creates a git worktree inside `.claude/worktrees/`, creates a branch, and **switches your session CWD** to the worktree
   - After this call, ALL tool operations (Read, Write, Bash, Glob, Grep) operate inside the worktree
   - If `EnterWorktree` fails because you are already in a worktree: skip to sub-step 5 and use the current directory as-is

4. **Rename the branch** to follow super-ralph convention:
   ```bash
   git branch -m "super-ralph/<plan-slug>"
   ```

5. **Install dependencies** (CWD is now the worktree, so relative paths work):
   ```bash
   if [ -f bun.lock ] || [ -f bun.lockb ]; then bun install
   elif [ -f package.json ]; then npm install
   fi
   ```

6. **Ensure plan file exists** in the worktree. If the plan was untracked in the main repo, it won't be in the fresh checkout — copy it:
   ```bash
   # Check if plan exists at its relative path; if not, copy from absolute path
   test -f "<relative-plan-path>" || (mkdir -p "$(dirname "<relative-plan-path>")" && cp "$PLAN_ABS_PATH" "<relative-plan-path>")
   ```

7. **Report** (brief, then immediately continue):
   `"Worktree ready at <cwd> on branch super-ralph/<slug>. Proceeding with build."`

**→ Proceed IMMEDIATELY to Step 1. Do NOT stop here.**

### Step 1: Read and Parse the Plan

1. Read the plan file at the provided path (relative path works — CWD is the worktree)
2. Extract from the plan header:
   - **Mode:** standard or hybrid
   - **Skills:** list of superpowers to invoke
   - **Iteration Budget:** max iterations
   - **Completion Promise:** what promise tag to use (default: COMPLETE)
3. Apply any command-line overrides (--max-iterations, --mode)

**→ Proceed IMMEDIATELY to Step 2.**

### Step 2: Validate the Plan

Dispatch the `super-ralph:plan-reviewer` agent (Task tool) to validate the plan for autonomous execution readiness.

- If **APPROVED**: proceed to Step 3
- If **ISSUES**: attempt to auto-fix by editing the plan file. If unfixable, warn but proceed anyway (don't block build)

**→ Proceed IMMEDIATELY to Step 3.**

### Step 3: Construct Execution Prompt

Based on the mode, construct the ralph-loop prompt:

**For standard mode:**
Read `${CLAUDE_PLUGIN_ROOT}/skills/ralph-planning/references/prompt-standard.md` and fill in:
- `[PLAN_PATH]` → the actual plan file path (relative path — CWD is the worktree)
- `[N]` → max iterations

**For hybrid mode:**
Read `${CLAUDE_PLUGIN_ROOT}/skills/ralph-planning/references/prompt-hybrid.md` and fill in:
- `[PLAN_FILE_PATH]` → the actual plan file path (relative path — CWD is the worktree)
- `[N]` → max iterations

**Add autonomous decision injection to the prompt:**
Append to the Skills section:
```
- When you encounter ambiguity or need to make a design decision: dispatch a research-agent (Task tool) for web references, then dispatch 1-2 sme-brainstormer agents for analysis. Pick the most rational option. NEVER wait for human input.
```

**→ Proceed IMMEDIATELY to Step 4.**

### Step 4: Set Up Ralph Loop

Run the ralph-loop setup script to create `.claude/ralph-loop.local.md` (CWD is the worktree, so the state file is isolated from the main repo):

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph-loop.sh "<PROMPT>" --max-iterations <N> --completion-promise "<PROMISE>"
```

Where:
- `<PROMPT>` is the constructed execution prompt from Step 3
- `<N>` is the max iterations value
- `<PROMISE>` is the completion promise (default: COMPLETE)

**→ Proceed IMMEDIATELY to Step 5.**

### Step 5: Start Execution

Output the execution prompt as the first iteration message. The ralph-loop Stop hook will intercept exit and feed the prompt back for subsequent iterations.

## Critical Rules

- **Always create a worktree.** Never run a ralph loop in the main working directory.
- **Use `EnterWorktree` to switch CWD.** Bash `cd` does NOT persist across tool calls — this is why you MUST use `EnterWorktree`.
- **NEVER ask the user to `cd`, switch directories, or run commands.** This is fully autonomous.
- **This is a SINGLE continuous flow.** Execute Steps 0–5 without pausing. Each step has a "→ Proceed IMMEDIATELY" marker — follow it.
- **Copy untracked plan files** into the worktree. Plans may not be committed yet.
- **Read the plan completely** before constructing the prompt. The plan contains the context the executor needs.
- **Paste full task text** into hybrid mode subagent prompts — never make subagents read the plan file.
- **Include skill directives** in the prompt — these tell the executor which superpowers to invoke.
- **Include the autonomous decision pattern** — this is what makes super-ralph different from plain ralph-loop.

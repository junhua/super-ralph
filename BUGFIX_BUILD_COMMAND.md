# Bug Fix: `/super-ralph:build` Printing Instead of Executing

## The Problem

When invoking `/super-ralph:build @docs/plans/2026-04-17-admin-module-activation-workflow.md`, the command would print the entire orchestrator prompt instead of executing the build workflow.

### Root Cause

The `commands/build.md` file contained detailed step-by-step instructions that were too verbose and context-heavy for Claude to execute in a single turn. When the command was invoked, Claude would:

1. Load the command definition from `commands/build.md`
2. Read the frontmatter and allowed tools
3. Start executing the steps
4. At Step 3 (Construct Execution Prompt), output the constructed prompt as visible text
5. Never reach Steps 4–5 (Setup ralph-loop and Start execution)

This happened because the instructions were written as **documentation** that a human could follow, not as **executable directives** that would immediately complete all steps.

## The Solution

Created a new **skill** at `skills/build/SKILL.md` that:

1. **Executes all 7 steps in a single turn** — no printing, no pausing
2. **Uses action-oriented language** — "DO" and "DO NOT" directives instead of explanatory documentation
3. **Clarifies that it should not print anything** — the skill explicitly states "DO NOT print the plan or prompt"
4. **Streamlines the workflow** — removes detailed explanations and focuses on concrete actions

### Files Changed

1. **Created:** `skills/build/SKILL.md` — The executable skill
2. **Created:** `skills/build/build-executor.md` — Internal reference for execution flow
3. **Updated:** `commands/build.md` — Added disclaimer pointing to the skill

## How It Works Now

When you invoke `/super-ralph:build <plan-path>`:

1. Claude Code recognizes the command and loads the `super-ralph:build` skill
2. The skill executes all 7 steps **in the current turn** without pausing:
   - Parse arguments
   - Resolve plan path and create worktree
   - Read plan file
   - Validate plan (optional)
   - Construct execution prompt
   - Setup ralph-loop
   - Output execution prompt (no printing, direct execution)
3. The ralph-loop Stop hook intercepts the exit and continues the autonomous loop

## Testing

To verify the fix works:

```bash
/super-ralph:build docs/plans/2026-04-17-admin-module-activation-workflow.md
```

**Expected behavior:** The skill immediately starts the ralph-loop without printing any intermediate prompts. The orchestrator prompt becomes the first ralph-loop iteration.

**NOT expected:** Printing the orchestrator prompt and stopping.

## Design Insight

★ Skill Design for Autonomous Execution ─────────────────────────────
The key difference between a **documentation command** and an **executable skill**:
- Documentation: explains what to do (often verbose, multi-step)
- Executable: directs what to do (concise, action-oriented, must complete in one turn)

Claude Code skills that invoke autonomous workflows (like ralph-loop) need to be **executable**, not **explanatory**. They should use imperative language ("DO", "DO NOT") and avoid printing intermediate state. The hidden output (reasoning) can be as detailed as needed; the visible output should only be the final result or the actual prompt to be executed.
─────────────────────────────────────────────────────────────────────

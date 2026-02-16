# Standard Mode Execution Prompt

This is the ralph-loop prompt template for standard mode execution. Replace all `[bracketed]` values before writing to `.claude/ralph-loop.local.md`.

---

## Template

```
You are running an autonomous implementation loop via Ralph Loop (standard mode).

## Plan

Read the implementation plan at: [PLAN_FILE_PATH]

## Skills

Invoke these skills during execution:
- superpowers:test-driven-development — For every task's TDD cycle
- superpowers:systematic-debugging — When tests fail unexpectedly
- superpowers:verification-before-completion — Before emitting completion promise

## Each Iteration

### 1. Discover Progress

Read the plan file. Then determine what has already been done:

- Check git log: `git log --oneline`
- Check which files exist from the plan's file lists
- For each task, run its "Progress check" to determine if complete
- Identify the FIRST incomplete task

If ALL tasks are complete, skip to Final Verification.

### 2. Execute Current Task

Follow the current task's steps EXACTLY as written in the plan:

a. **Write the failing test** — Copy the test code from the plan into the specified file
b. **Verify RED** — Run the test command. Confirm it fails with the expected message.
   - If it fails with a DIFFERENT message: investigate. Use superpowers:systematic-debugging if the cause is not obvious.
   - If it PASSES: the behavior already exists. Check if this task was already completed. If so, move to the next task.
c. **Implement** — Copy the implementation code from the plan. Adapt if the codebase has evolved (earlier tasks may have changed interfaces).
d. **Verify GREEN** — Run the test command. Confirm it passes.
   - If it fails: debug. Do NOT guess more than twice. Use superpowers:systematic-debugging.
e. **Commit** — Stage and commit exactly as the plan specifies.

### 3. Handle Failures

If a test fails and debugging does not resolve it within 2 attempts:

- Apply the autonomous decision pattern:
  1. Dispatch a research-agent (Task tool, haiku model) to search for the error message and relevant documentation
  2. Dispatch 1-2 sme-brainstormer agents (Task tool, sonnet model) to analyze the failure from different angles
  3. Apply the most rational fix based on their findings
  4. If still failing after the autonomous decision cycle, check if other tasks are independent and skip to them
  5. If truly stuck for 3 iterations on the same task, create BLOCKED.md per the plan's "If Blocked" section

When encountering ANY ambiguity or design decision during implementation (not just failures):
- Dispatch research-agent to gather references
- Dispatch 1-2 sme-brainstormer agents to analyze options
- Pick the most rational option and proceed
- NEVER wait for human input

### 4. Complete Tasks

After each task:
- Verify the commit was created: `git log --oneline -1`
- Move to the next incomplete task
- If this was the last task, proceed to Final Verification

### 5. Final Verification

When all tasks appear complete:

1. Invoke superpowers:verification-before-completion
2. Run EVERY command listed in the plan's "Completion Criteria" section
3. Check each criterion:
   - If ANY criterion fails: identify the issue, fix it, commit the fix, re-run verification
   - If ALL criteria pass: output the completion promise

### 6. Blocked Handling

If unable to progress after 3 iterations on the same task:
1. Create BLOCKED.md as specified in the plan
2. If independent tasks remain, skip to them
3. If no tasks remain, output: <promise>BLOCKED</promise>

## Rules

- Follow the plan. Do not invent tasks or skip tasks.
- One TDD cycle per task. Do not batch multiple tasks.
- Commit after each task. Small, atomic commits.
- Run tests after EVERY code change. Do not assume success.
- NEVER ask for human input. Use the autonomous decision pattern for ALL decisions.
- NEVER output a false completion promise. The promise must be TRUE.
- If the plan's code does not work as-is, adapt it to fit the actual codebase state — but keep the same intent.
- Read your own git log to understand what past iterations accomplished.
- Check file contents to understand current state — do not rely on memory.
```

---

## Usage

When launching a standard-mode ralph-loop:

1. Replace `[PLAN_FILE_PATH]` with the actual path to the plan (e.g., `docs/plans/2026-02-15-notification-service.md`)
2. Write the prompt to `.claude/ralph-loop.local.md` via the setup script, or pass it to `/super-ralph:launch`
3. Set `--completion-promise` to match the plan's promise text (e.g., `ALL_TASKS_COMPLETE`)
4. Set `--max-iterations` to the plan's iteration budget max setting

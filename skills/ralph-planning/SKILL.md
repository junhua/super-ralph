---
name: ralph-planning
description: This skill should be used when writing implementation plans for autonomous Ralph Loop execution. Use when the user mentions "ralph plan", "autonomous plan", "fire-and-forget development", "walk-away development", "overnight development", or wants plans optimized for /ralph-loop. Also triggers when /super-ralph:plan is invoked. For interactive planning with subagents, use superpowers:writing-plans instead.
---

# Ralph Planning

## Overview

Write implementation plans optimized for autonomous Ralph Loop execution. Ralph feeds the SAME prompt repeatedly — Claude sees progress through files and git history, not conversation context. Plans must be hyper-explicit: complete code, exact commands, self-correction loops, and machine-verifiable completion criteria.

**Announce at start:** "I'm using the ralph-planning skill to create an autonomous execution plan."

**Core insight:** The executing agent has NO memory between iterations. It reads the plan file, checks files on disk, reads git log, and decides what to do next. Every task must be self-discoverable — the agent must be able to determine its own progress without any conversation history.

## Choosing Execution Mode

Select between standard and hybrid mode based on task characteristics.

### Standard Mode

Use when:
- Fewer than 6 tightly-coupled tasks
- Tasks share state between them (e.g., later tasks depend on earlier task output)
- Each task is a simple 2-3 step TDD cycle
- Total scope fits within 15-20 iterations

Standard mode: one agent executes all tasks sequentially in a single ralph-loop.

### Hybrid Mode

Use when:
- More than 5 independent tasks
- Each task is substantial enough to warrant its own subagent
- Quality gates are desired between tasks (spec review after each)
- Tasks can be parallelized

Hybrid mode: an orchestrator agent dispatches implementer subagents per task plus spec-reviewer subagents for quality gates.

### When Uncertain

NEVER ask the user which mode to use. Instead, apply the autonomous decision pattern:

1. Dispatch a research-agent (Task tool, haiku) to analyze the task breakdown and dependencies
2. Dispatch 1-2 sme-brainstormer agents (Task tool, sonnet) to evaluate mode suitability
3. Pick the mode with strongest evidence and proceed

See `references/autonomous-decision-pattern.md` for the full pattern.

## Plan Structure

Every ralph-planning plan follows this structure. See `references/plan-template.md` for the complete template.

### Header Block

```markdown
# [Feature Name] Implementation Plan

> **Executor:** super-ralph (autonomous)
> **Mode:** standard | hybrid
> **Skills:** super-ralph:ralph-planning, superpowers:test-driven-development, superpowers:systematic-debugging, superpowers:verification-before-completion, superpowers:dispatching-parallel-agents
> **Run:** `/super-ralph:build` with this plan
```

### Required Sections

1. **Goal** — One sentence describing what the plan builds
2. **Tech Stack** — Key technologies, libraries, versions
3. **Iteration Budget** — Estimated iterations with safety margin (see table below)
4. **Skill Directives** — Which superpowers skills to invoke and when
5. **Completion Criteria** — Machine-verifiable checks (test commands, build commands, lint commands with exact expected output)
6. **If Blocked** — What to do when stuck (create BLOCKED.md, document state, continue on other tasks)
7. **Tasks** — Numbered, ordered, each following TDD cycle

## Task Granularity

Each task equals one TDD cycle. Include:

- **Complete code snippets** — Not "add validation logic" but the actual validation code
- **Exact file paths** — Absolute or repo-relative, never ambiguous
- **Runnable commands** — With expected output (exit code, test count, specific strings)
- **Progress markers** — How the agent detects this task is already done (file exists, test passes, git log contains commit message)

Task template:

```markdown
### Task N: [Name]

**Progress check:** [How to detect this task is already complete]
**Files:** Create `path/to/file.ts`, Test `path/to/file.test.ts`

1. Write failing test
   [Complete test code]
   Run: `bun test path/to/file.test.ts`
   Expected: FAIL — [specific failure message]

2. Implement
   [Complete implementation code]
   Run: `bun test path/to/file.test.ts`
   Expected: PASS — N tests passed

3. Commit
   `git add path/to/file.ts path/to/file.test.ts`
   `git commit -m "feat: [description]"`
```

## Superpowers Compatibility

Not all superpowers skills work inside a ralph-loop. See `references/superpowers-compatibility.md` for the full table.

**Compatible (include in Skill Directives):**
- `superpowers:test-driven-development` — TDD cycle for every task
- `superpowers:systematic-debugging` — When tests fail unexpectedly
- `superpowers:verification-before-completion` — Before emitting completion promise
- `superpowers:dispatching-parallel-agents` — For parallel investigation in hybrid mode

**NOT compatible (never reference in ralph plans):**
- `superpowers:brainstorming` — Requires interactive discussion
- `superpowers:writing-plans` — Meta-planning, not execution
- `superpowers:executing-plans` — Different execution model (human checkpoints)
- `superpowers:subagent-driven-development` — Different execution model
- `superpowers:using-git-worktrees` — Setup state does not persist across iterations
- `superpowers:finishing-a-development-branch` — Requires human review for merge/PR decision

## Autonomous Decision Pattern

When ANY ambiguity arises during planning — architecture choices, library selection, API design, error handling strategy — apply the autonomous decision pattern instead of asking the user.

1. Dispatch research-agent to gather evidence
2. Dispatch 1-3 sme-brainstormer agents to analyze from different angles
3. Pick the option with strongest evidence and expert consensus
4. Document the decision in the plan
5. Move on

See `references/autonomous-decision-pattern.md` for detailed steps.

This pattern applies during plan creation AND during plan execution. Include it as a Skill Directive in every plan so the executing agent knows to use it when encountering ambiguity.

## Iteration Budget

Estimate iteration count based on task count, then add a safety margin.

| Tasks | Iterations | Safety Margin | Max Iterations Setting |
|-------|-----------|---------------|----------------------|
| 3-5   | 15-20     | +5            | 25                   |
| 6-10  | 25-35     | +10           | 45                   |
| 11-15 | 40-50     | +15           | 65                   |
| 16+   | Split into phases — each phase is a separate plan |  |  |

Set `--max-iterations` to the Max Iterations Setting column value. If the agent hits the limit, it creates BLOCKED.md with remaining work.

Plans with 16+ tasks indicate scope creep. Split into 2-3 phase plans, each with 8-12 tasks. Phase N+1 can reference Phase N's output as existing files.

## Skill Directives Section

Include this section in every plan to tell the executing agent which skills to invoke:

```markdown
## Skill Directives

- **TDD:** Follow superpowers:test-driven-development for every task. No production code without a failing test.
- **Debugging:** When a test fails unexpectedly, invoke superpowers:systematic-debugging. Do not guess-and-check more than twice.
- **Verification:** Before emitting the completion promise, invoke superpowers:verification-before-completion. Run ALL test commands and confirm zero failures.
- **Parallel agents:** (Hybrid mode only) Use superpowers:dispatching-parallel-agents when multiple independent tasks can be worked concurrently.
- **Autonomous decisions:** When encountering ambiguity, apply the autonomous decision pattern (dispatch research-agent + sme-brainstormer agents). NEVER wait for human input.
```

## Completion Criteria

Write completion criteria that a machine can verify without human judgment:

```markdown
## Completion Criteria

All of the following must be true:
- [ ] `bun test` exits with code 0
- [ ] `bun run build` exits with code 0
- [ ] `bun run lint` reports 0 errors
- [ ] All N tasks have corresponding git commits
- [ ] No TODO or FIXME comments in new code

When ALL criteria are met, output: `<promise>ALL_TASKS_COMPLETE</promise>`
```

Avoid subjective criteria like "code is clean" or "architecture is sound." Every criterion must be checkable by running a command and inspecting its output.

## If Blocked Section

Include a fallback for when the agent gets stuck:

```markdown
## If Blocked

If unable to make progress after 3 consecutive iterations on the same task:
1. Create `BLOCKED.md` at repo root with:
   - Which task is blocked
   - What was attempted
   - Exact error messages
   - Suggested approaches not yet tried
2. Skip to the next independent task if one exists
3. If no independent tasks remain, output: `<promise>BLOCKED</promise>`
```

## Progress Discovery

Every task must include a machine-checkable progress indicator so the executing agent can determine what has already been completed. The agent runs these checks at the start of each iteration to find its place.

Good progress checks:
- `test -f src/services/auth.ts && bun test src/services/auth.test.ts 2>/dev/null | grep -q "pass"` — File exists AND test passes
- `git log --oneline | grep -q "feat: add auth service"` — Commit with specific message exists
- `grep -q "export function authenticate" src/services/auth.ts` — Specific function exists in file

Bad progress checks:
- "Auth service is implemented" — Subjective, not machine-checkable
- `test -f src/services/auth.ts` — File might exist but be empty or incomplete
- "Previous iteration should have done this" — Relies on memory, which does not exist

Order progress checks from cheapest to most expensive. File existence checks first, then grep for specific content, then running tests. The agent runs these dozens of times across iterations — keep them fast.

## Common Planning Mistakes

### Vague Implementation Steps

Do not write "implement the validation logic." Write the actual code. The executing agent works from the plan as its sole source of truth. If the plan says "add error handling," the agent must guess what error handling means. If the plan contains the actual try/catch block with specific error types and messages, the agent copies it verbatim.

### Missing Expected Output

Every `Run:` command needs an `Expected:` line. Without it, the agent cannot distinguish between success and failure. A test command that exits with code 0 but prints warnings is ambiguous. Specify: "Expected: PASS — 5 tests passed, 0 warnings."

### Implicit Dependencies

If Task 4 depends on Task 2's output (e.g., an interface defined in Task 2's file), state this explicitly: "Depends on: Task 2 (uses `UserService` interface from `src/types.ts`)." The agent does not infer dependencies — it follows tasks in order, but if it skips a blocked task, it needs to know which other tasks also become blocked.

### Over-Scoped Tasks

A task that requires more than one TDD cycle is too large. Split it. If a task has 3 test cases and 3 implementation steps, it is 3 tasks. The rule: one failing test, one implementation, one commit. This keeps progress granular and observable.

### Under-Specified Blocked Handling

Do not just say "if blocked, move on." Specify what BLOCKED.md must contain (task number, error message, attempted approaches). Future iterations — or the human who returns — needs this information to unblock the work.

## Execution Prompts

After the plan is written, generate the ralph-loop execution prompt. See:
- `references/prompt-standard.md` — For standard mode
- `references/prompt-hybrid.md` — For hybrid mode

Save the plan to `docs/plans/YYYY-MM-DD-<feature-name>.md` and offer to launch with `/super-ralph:build`.

## GitHub Issue Integration

Plans should reference the GitHub Issue they implement. This creates traceability from issue → plan → code → PR → issue closure.

### Plan Header

Include the issue reference in the plan header:

```markdown
# [Plan Title]

> **Issue:** #N ([EPIC]/[REQ]/[FIX] title)
> **Branch:** `feat/<dev>/<feature>`
> ...
```

### PR Body

When the plan's review-fix cycle creates a PR, include `Closes #N` in the PR body to auto-close the issue and move it to "Shipped" on the project board.

### Multiple Issues

If a plan implements multiple sub-issues of an [EPIC], reference all of them:

```markdown
> **Issues:** #N1, #N2, #N3 (sub-issues of [EPIC] #M)
```

And in the PR body:
```
Closes #N1
Closes #N2
Closes #N3
```

## References

- `references/plan-template.md` — Complete plan template
- `references/prompt-standard.md` — Standard mode execution prompt
- `references/prompt-hybrid.md` — Hybrid mode execution prompt
- `references/autonomous-decision-pattern.md` — Autonomous decision-making pattern
- `references/superpowers-compatibility.md` — Which superpowers skills work in ralph-loop

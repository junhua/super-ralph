# Ralph Plan Template

Use this template when creating autonomous execution plans. Fill in all bracketed sections. Remove comments before finalizing.

---

````markdown
# [Feature Name] Implementation Plan

> **Issue:** #N (if applicable — reference the GitHub Issue this plan implements)
> **Executor:** super-ralph (autonomous)
> **Mode:** [standard | hybrid]
> **Skills:** super-ralph:ralph-planning, superpowers:test-driven-development, superpowers:systematic-debugging, superpowers:verification-before-completion, superpowers:dispatching-parallel-agents
> **Run:** `/super-ralph:build` with this plan

## Goal

[One clear sentence: what this plan builds, for whom, and the primary user-facing outcome.]

## Tech Stack

- **Runtime:** [e.g., Bun 1.x]
- **Language:** [e.g., TypeScript 5.x]
- **Framework:** [e.g., Hono, Next.js, etc.]
- **Testing:** [e.g., bun:test, vitest, jest]
- **Key libraries:** [list with versions if version-sensitive]

## Iteration Budget

- **Tasks:** [N]
- **Estimated iterations:** [range, e.g., 25-35]
- **Max iterations setting:** [number, e.g., 45]
- **Completion promise:** `[PROMISE_TEXT]`

## Skill Directives

- **TDD:** Follow superpowers:test-driven-development for every task. No production code without a failing test first. Watch the test fail, then implement.
- **Debugging:** When a test fails unexpectedly (not the expected RED failure), invoke superpowers:systematic-debugging. Do not guess-and-check more than twice — gather evidence systematically.
- **Verification:** Before emitting the completion promise, invoke superpowers:verification-before-completion. Run ALL verification commands listed in Completion Criteria and confirm each passes.
- **Parallel agents:** [Standard mode: "Not applicable — sequential execution." | Hybrid mode: "Use superpowers:dispatching-parallel-agents when dispatching independent implementer subagents."]
- **Autonomous decisions:** When encountering ANY ambiguity — library choice, API design, error handling approach, architectural decision — apply the autonomous decision pattern:
  1. Dispatch research-agent (Task tool, haiku model) to search web + codebase for references
  2. Dispatch 1-3 sme-brainstormer agents (Task tool, sonnet model) to analyze options from different angles
  3. Pick the option with strongest evidence and expert consensus
  4. Document decision in a brief code comment or commit message
  5. Proceed immediately — NEVER wait for human input

## Completion Criteria

All of the following must be true before emitting the completion promise:

- [ ] `[test command]` exits with code 0 (0 failures)
- [ ] `[build command]` exits with code 0
- [ ] `[lint command]` reports 0 errors
- [ ] All [N] tasks have corresponding git commits (verify with `git log --oneline | head -[N]`)
- [ ] No TODO or FIXME comments in new code (`grep -r "TODO\|FIXME" [src-dir]` returns empty)
- [ ] [Any additional project-specific criteria]

When ALL criteria are verified, output: `<promise>[PROMISE_TEXT]</promise>`

## If Blocked

If unable to make progress after 3 consecutive iterations on the same task:

1. Create `BLOCKED.md` at repo root:
   ```markdown
   # Blocked

   ## Task: [Task N: Name]
   ## Iterations stuck: [count]

   ## What was attempted
   - [Attempt 1: description + result]
   - [Attempt 2: description + result]
   - [Attempt 3: description + result]

   ## Error messages
   ```
   [exact error output]
   ```

   ## Suggested approaches not yet tried
   - [Approach A]
   - [Approach B]
   ```

2. If other independent tasks remain, skip to them
3. If no independent tasks remain, output: `<promise>BLOCKED</promise>`

---

## Tasks

### Task 1: [Component/Feature Name]

**Progress check:** [How the agent detects this task is done, e.g., "file `src/foo.ts` exists AND `bun test src/foo.test.ts` passes"]

**Files:**
- Create: `[exact/path/to/file.ts]`
- Create: `[exact/path/to/file.test.ts]`
- Modify: `[exact/path/to/existing.ts]` (lines [N-M] if relevant)

**Step 1: Write failing test**

```typescript
// [exact/path/to/file.test.ts]
import { describe, test, expect } from "bun:test";
import { [function] } from "../[module]";

describe("[component]", () => {
  test("[specific behavior being tested]", () => {
    const result = [function]([input]);
    expect(result).toEqual([expected]);
  });
});
```

Run: `bun test [exact/path/to/file.test.ts]`
Expected: FAIL — `[specific failure message, e.g., "Cannot find module '../module'"]`

**Step 2: Implement**

```typescript
// [exact/path/to/file.ts]
export function [function]([params]: [types]): [returnType] {
  [complete implementation — not pseudocode]
}
```

Run: `bun test [exact/path/to/file.test.ts]`
Expected: PASS — 1 test passed

**Step 3: Commit**

```bash
git add [exact/path/to/file.ts] [exact/path/to/file.test.ts]
git commit -m "feat: [concise description of what this task adds]"
```

---

### Task 2: [Next Component]

[Same structure as Task 1]

---

[Continue for all tasks...]

---

## Final Verification

After all tasks complete, run the full verification sequence:

```bash
# Run full test suite
bun test
# Expected: [N] tests passed, 0 failures

# Run build
bun run build
# Expected: exit code 0, no errors

# Run lint
bun run lint
# Expected: 0 errors, 0 warnings

# Check for leftover TODOs
grep -r "TODO\|FIXME" [src-dir]
# Expected: empty output

# Verify all task commits exist
git log --oneline | head -[N]
# Expected: [N] commits with feat: messages
```

If all pass: `<promise>[PROMISE_TEXT]</promise>`
If any fail: Fix the failure, re-run verification, loop continues.

**PR note:** When creating the PR, include `Closes #N` (where N is the issue number from the header) in the PR body to auto-close the linked issue.
````

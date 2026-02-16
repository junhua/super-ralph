---
name: review-fix-loop
description: This skill should be used when orchestrating an autonomous PR review-and-fix cycle. Triggers when /super-ralph:review-fix is invoked, or when the user mentions "review and fix PR", "autonomous PR review", "fix PR issues automatically", or wants to iterate on PR feedback without human intervention. Combines pr-review-toolkit agents with autonomous issue fixing in a ralph-loop.
---

# Review-Fix Loop

## Overview

Orchestrate an autonomous feedback loop: review PR, run regression tests, parse findings, fix Critical/Important issues, push, re-review, repeat until clean and all tests pass. Uses ralph-loop's Stop hook for iteration control with `REVIEW_CLEAN` as the completion promise. After convergence, automatically merges the PR.

**Announce at start:** "I'm using the review-fix-loop skill to set up an autonomous PR review-and-fix cycle with regression testing and auto-merge."

**Core concept:** The review-fix loop converts PR review from a human-in-the-loop process into an autonomous convergence loop. Each iteration runs all regression tests (functional, integration, e2e), reviews the current PR state, classifies findings by severity, fixes blocking issues, pushes, and loops. The loop terminates when no Critical or Important issues remain AND all tests pass. Upon clean completion, the PR is automatically merged.

## Severity Classification

All review findings are classified into four severity levels. Only Critical and Important block completion.

### Critical (Must Fix — Blocks Completion)

Confidence threshold: >= 90% certain this is a real issue.

- Definite bugs (logic errors, off-by-one, null dereference)
- Security vulnerabilities (injection, auth bypass, secret exposure)
- Data loss risks (missing transactions, race conditions on writes)
- Broken core functionality (feature does not work as specified)
- Crash-causing issues (unhandled exceptions in critical paths)

### Important (Should Fix — Blocks Completion)

Confidence threshold: >= 80% certain this matters.

- Architecture problems (wrong abstraction, circular dependencies)
- Missing error handling that affects users (API returns 500 instead of 400)
- Test coverage gaps for critical paths (no test for the happy path)
- Explicit CLAUDE.md or project convention violations
- Type safety issues (unsafe casts, any types in critical code)

### Minor (Logged — Does NOT Block)

Confidence threshold: >= 50%.

- Code style inconsistencies
- Performance optimizations (unless measurably impactful)
- Minor DRY violations (2 occurrences, not systemic)
- Non-critical naming improvements

### Suggestions (Logged — Does NOT Block)

- Documentation improvements
- Refactoring opportunities for future consideration
- Nice-to-have features or enhancements
- Alternative approaches worth considering

See `references/severity-rules.md` for detailed classification rules and edge cases.

## Each Iteration Cycle

The review-fix prompt (written to `.claude/ralph-loop.local.md`) drives each iteration. The full prompt template is in `references/review-fix-prompt.md`.

### Step 1: Ensure PR Exists

Check if the PR exists. If not, create it:

```bash
gh pr create --title "[title]" --body "[body]" --base [default-branch]
```

If the PR already exists, verify it is up to date with local commits:

```bash
git push
```

### Step 2: Run Regression Tests

Run ALL regression tests before code review. This catches regressions introduced by previous fix iterations early and provides test results as additional context for review agents.

**Auto-detect and run all test suites:**

```bash
# Detect test runner
if [ -f bun.lock ] || [ -f bun.lockb ]; then
  RUNNER="bun"
elif [ -f package.json ]; then
  RUNNER="npm"
fi

# Run all test categories that exist
# Functional / unit tests
$RUNNER test 2>&1

# Integration tests (if directory exists)
if [ -d tests/integration ] || [ -d test/integration ]; then
  $RUNNER test -- tests/integration/ 2>&1
fi

# E2E / behavior tests (if directory exists)
if [ -d tests/e2e ] || [ -d test/e2e ]; then
  $RUNNER test -- tests/e2e/ 2>&1
fi
```

**Collect test results as structured data:**
- Total tests: N passed, M failed, K skipped
- List of failing tests with file paths and error messages
- Whether this is a new failure (not present in previous iteration) or a pre-existing failure

**Test failure classification:**
- **New test failure** (introduced by a review-fix commit): Classify as Critical issue — the fix broke something
- **Pre-existing test failure** (present before review-fix started): Log but do not block — these are not caused by the review-fix loop
- **Flaky test** (passes on retry): Log as Minor — not actionable

To distinguish new from pre-existing failures, check if the failing test file was modified in a review-fix commit:
```bash
git log --oneline --grep="review-fix" --name-only | grep "<failing-test-path>"
```

### Step 3: Run PR Review Agents

Dispatch pr-review-toolkit agents via the Task tool:

- **code-reviewer** — General code quality, logic, architecture
- **silent-failure-hunter** — Silent failures, swallowed errors, missing error paths

Additional agents can be added based on the PR's nature:
- **pr-test-analyzer** — Test quality and coverage gaps
- **type-design-analyzer** — Type system design issues

Each agent returns structured findings with severity classifications.

**Include test results in review agent context:** Pass the regression test results from Step 2 to all review agents so they can correlate code issues with test failures.

### Step 4: Parse and Classify Findings

Aggregate findings from all review agents AND test failures from Step 2. Classify each by severity using the rules in `references/severity-rules.md`. De-duplicate findings that multiple agents flag.

**New test failures from Step 2 are automatically classified as Critical** — they indicate a regression introduced by the review-fix process itself.

### Step 5: Evaluate Completion

Completion requires BOTH conditions:

1. **No Critical findings AND No Important findings** from code review
2. **All regression tests pass** (no new test failures; pre-existing failures are exempt)

If BOTH conditions are met:
- Output `<promise>REVIEW_CLEAN</promise>`
- The ralph-loop Stop hook detects this and terminates the loop
- Proceed to **Step 8: Merge PR**

If either condition fails, proceed to Step 6.

### Step 6: Dispatch Issue Fixer

Dispatch an issue-fixer subagent (Task tool, sonnet model) with the structured findings, including both code review findings AND test failures:

```
You are fixing issues found during PR review and regression testing.

## Issues to Fix (ordered by severity)

### Critical
[list of critical issues with file paths, line numbers, descriptions]
[include new test failures with their error messages and stack traces]

### Important
[list of important issues with file paths, line numbers, descriptions]

## Rules
- Fix Critical issues first (including test failures), then Important
- For each fix: read the code context, implement the fix, run relevant tests
- After fixing a test failure, run the specific test to verify it passes:
  `bun test <test-file-path>`
- Commit each fix separately: `git commit -m "fix: [what] (review-fix)"`
- Push after each commit: `git push`
- If a fix requires a design decision, search the codebase for existing patterns and follow them
- If stuck on a fix, skip it and note why in a comment

## Autonomous Decisions
When encountering ambiguity about how to fix an issue:
1. Search codebase for similar patterns
2. If unclear, dispatch research-agent for references
3. Pick the approach most consistent with existing code
4. NEVER wait for human input
```

### Step 7: Continue Loop

After the issue-fixer completes, the ralph-loop Stop hook feeds the same prompt back for the next iteration. The next iteration re-runs all regression tests AND re-reviews the updated PR, catching any remaining or newly introduced issues.

### Step 8: Merge PR (on REVIEW_CLEAN)

When the loop terminates with `REVIEW_CLEAN` (no Critical/Important issues AND all tests pass), automatically merge the PR:

1. **Verify PR is mergeable:**
   ```bash
   gh pr view [PR_NUMBER] --json mergeable,mergeStateStatus --jq '{mergeable, mergeStateStatus}'
   ```

2. **Wait for CI checks** (if any are running):
   ```bash
   gh pr checks [PR_NUMBER] --watch
   ```

3. **Merge the PR** using squash merge (consolidates review-fix commits into a clean history):
   ```bash
   gh pr merge [PR_NUMBER] --squash --delete-branch
   ```

4. **If merge fails** (e.g., merge conflicts, branch protection rules):
   - Log the error
   - Output: `"PR #[PR_NUMBER] is review-clean but could not be auto-merged: [reason]. Manual merge required."`
   - Do NOT retry or force-merge — this requires human intervention

5. **If merge succeeds:**
   - Output: `"PR #[PR_NUMBER] merged successfully. Branch deleted."`
   - The loop is complete

## Anti-Oscillation

Track fix history across iterations to detect oscillation patterns.

### What Is Oscillation

Oscillation occurs when:
- Iteration N finds issue A, fixes it
- Iteration N+1 finds issue B (introduced by fixing A), fixes it
- Iteration N+2 finds issue A again (re-introduced by fixing B)
- The loop cycles between A and B indefinitely

### Detection

Maintain a fix history by checking git log for `(review-fix)` commits:

```bash
git log --oneline --grep="review-fix"
```

If the same issue description appears in alternating iterations (detected by similar commit messages or the same file being fixed repeatedly), this indicates oscillation.

### Resolution

After 2 oscillation cycles on the same issue:

1. Dispatch sme-brainstormer agents (Task tool, sonnet model) to analyze the root cause:

```
Two fixes are oscillating:
- Fix A: [description, diff]
- Fix B: [description, diff]

Fixing A introduces B. Fixing B re-introduces A.

Analyze the root cause. This likely needs an architectural change, not a local patch.
Recommend a solution that resolves BOTH issues simultaneously.
```

2. Apply the architectural fix recommended by the brainstormers
3. Commit with: `fix: resolve oscillation between [A] and [B] (review-fix)`
4. Continue the loop — the next review should catch any remaining issues
5. If brainstormers cannot resolve the oscillation, document in `BLOCKED.md` and output `<promise>REVIEW_BLOCKED</promise>` to terminate the loop

## Integration with Ralph Loop

The review-fix command sets up the ralph-loop infrastructure:

1. Create an isolated git worktree for the loop (keeps the main working directory free for other work)
2. Write the review-fix prompt to `.claude/ralph-loop.local.md` inside the worktree (see `references/review-fix-prompt.md`)
3. Set completion promise to `REVIEW_CLEAN` (or `REVIEW_BLOCKED` if oscillation is unresolvable)
4. Set max iterations (default: 0/unlimited, recommended cap: 10-15 for typical PRs, 20-25 for large PRs)
5. Ralph-loop's Stop hook handles iteration: blocks exit, feeds same prompt, increments counter

The review-fix prompt is self-contained — it includes all instructions for review, classification, fixing, and completion detection. Each iteration discovers progress by checking the PR's current state and git log.

## Launching

To start a review-fix cycle:

1. Ensure changes are committed and pushed to a branch
2. Invoke `/super-ralph:review-fix` with the PR number (or let it create one)
3. The command creates an isolated worktree, writes the review-fix prompt, and activates ralph-loop
4. Walk away — the loop runs regression tests, reviews, fixes, pushes, and re-reviews until clean, then auto-merges the PR

Alternatively, integrate into a ralph-planning plan as the final phase:

```markdown
### Task N+1: Review-Fix Cycle

**Progress check:** `gh pr checks [PR_NUMBER]` shows all passing AND last review-fix iteration found no Critical/Important issues

1. Create PR if not exists: `gh pr create --title "[title]" --body "[body]"`
2. Launch review-fix loop (invoke super-ralph:review-fix-loop)
3. Loop runs until REVIEW_CLEAN or max iterations
```

## Convergence Monitoring

Track the health of the review-fix loop by observing issue counts across iterations.

### Healthy Convergence

Each iteration finds fewer issues and test failures than the previous one. Typical PRs converge in 3-6 iterations:
- Iteration 1: 2 Critical, 3 Important, 5 Minor, 1 test failure
- Iteration 2: 0 Critical, 2 Important, 4 Minor, 0 test failures
- Iteration 3: 0 Critical, 0 Important, 3 Minor, 0 test failures
- Iteration 4: REVIEW_CLEAN (0 Critical, 0 Important, all tests pass) → auto-merge

Minor issues decrease naturally as fixes improve overall code quality, but they do not block completion.

### Slow Convergence

Each fix introduces minor new issues while resolving the original ones. Normal for complex PRs with many interdependencies. Converges in 6-10 iterations. No action needed — the loop handles this naturally.

### Divergence

More issues found each iteration than the previous one. This indicates a fundamental problem — fixes are introducing more issues than they resolve. When detected:

1. Dispatch sme-brainstormer agents to analyze the pattern of increasing issues
2. The root cause is usually that the code needs a structural change, not incremental fixes
3. Apply the architectural recommendation before continuing incremental fixes

### Stalled

Same number and type of issues persist across 3+ iterations. The issue-fixer is either not fixing the right thing or its fixes are being reverted by subsequent changes. Escalate to sme-brainstormer analysis.

## Review Agent Configuration

Configure review agents based on the PR's characteristics. Not every PR needs every agent.

| PR Type | Recommended Agents |
|---|---|
| Feature implementation | code-reviewer, silent-failure-hunter, pr-test-analyzer |
| Bug fix | code-reviewer, silent-failure-hunter |
| Refactoring | code-reviewer, type-design-analyzer |
| API changes | code-reviewer, silent-failure-hunter, type-design-analyzer |
| Test-only changes | pr-test-analyzer |
| Infrastructure/config | code-reviewer |

For unknown PR types, default to code-reviewer + silent-failure-hunter. These two cover the most common blocking issues.

## Fix Commit Conventions

Every fix committed by the review-fix loop follows a strict commit message format:

```
fix: [concise description of what was fixed] (review-fix)
```

The `(review-fix)` suffix serves multiple purposes:
- Distinguishes automated fixes from manual ones in git log
- Enables oscillation detection via `git log --grep="review-fix"`
- Provides audit trail for which issues were found and fixed automatically
- Allows post-loop analysis of the review-fix cycle's effectiveness

Each fix gets its own commit. Do not batch fixes into a single commit — this makes oscillation detection impossible and makes it harder to revert individual fixes if needed.

## Workflow Boundaries

- **Input:** A branch with commits ready for review (PR may or may not exist yet)
- **Output:** A merged PR with no Critical or Important review findings and all regression tests passing
- **Does NOT handle:** Release management, deployment — those are post-merge concerns
- **Pairs with:** ralph-planning (review-fix as final phase), super-ralph:launch (for the ralph-loop infrastructure), super-ralph:update (for post-merge project status updates)

## References

- `references/review-fix-prompt.md` — Complete ralph-loop prompt template for review-fix cycles
- `references/severity-rules.md` — Detailed severity classification guide with examples and edge cases

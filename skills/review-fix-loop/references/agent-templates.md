# Review-Fix Agent Dispatch Templates

Exact Task-tool dispatch templates for every review agent and the issue-fixer. Invoked from `commands/review-fix.md` Step 3.

## Ground rules (apply to every dispatch)

- **Set `max_turns`** on every Task dispatch. Review agents: `20`. Issue-fixer: `30`. SME brainstormer (oscillation escalation): `15`.
- **Summarize, don't paste.** Never paste raw test output or full diff into a sub-agent prompt. Summarize to counts + one-line error messages.
- **Agents read the branch diff themselves.** Every review agent expects to run `git diff origin/<default-branch>...HEAD` internally. Do not paste the diff into the prompt.
- **Substitute `<default-branch>`** with whatever `gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name'` returned in Step 3.1.
- **Filter findings by confidence.** Only report issues with confidence ≥ 80 (see `severity-rules.md`).

---

## Review Agents

Dispatch in parallel based on the `--aspects` argument. `--aspects all` (default) dispatches every agent whose optional dependency (`pr-review-toolkit`) is installed.

### Code Reviewer

```
Task tool:
  subagent_type: pr-review-toolkit:code-reviewer
  max_turns: 20
  description: "Review branch for code quality"
  prompt: "Review the changes on this branch. Read the diff: `git diff origin/<default-branch>...HEAD`. Focus on bugs, logic errors, security vulnerabilities, and project convention violations. Only report issues with confidence >= 80.

  Test summary: [PASTE SUMMARIZED TEST RESULTS]"
```

### Silent Failure Hunter

```
Task tool:
  subagent_type: pr-review-toolkit:silent-failure-hunter
  max_turns: 20
  description: "Hunt silent failures on branch"
  prompt: "Review the error handling in this branch's changes. Read the diff: `git diff origin/<default-branch>...HEAD`. Look for empty catch blocks, swallowed errors, inappropriate fallbacks, and missing error logging."
```

### Test Analyzer

```
Task tool:
  subagent_type: pr-review-toolkit:pr-test-analyzer
  max_turns: 20
  description: "Analyze test coverage for branch"
  prompt: "Review the test coverage quality for this branch's changes. Read the diff: `git diff origin/<default-branch>...HEAD`. Identify critical gaps, missing edge cases, and tests that don't actually test real behavior."
```

### Comment Analyzer

```
Task tool:
  subagent_type: pr-review-toolkit:comment-analyzer
  max_turns: 20
  description: "Analyze comment quality on branch"
  prompt: "Analyze code comments in this branch's changes. Read the diff: `git diff origin/<default-branch>...HEAD`. Check for factual inaccuracy, misleading comments, missing documentation for complex logic."
```

### Type Design Analyzer (dispatch only if new types detected)

```
Task tool:
  subagent_type: pr-review-toolkit:type-design-analyzer
  max_turns: 20
  description: "Review type design on branch"
  prompt: "Review the type definitions added or modified in this branch's changes. Read the diff: `git diff origin/<default-branch>...HEAD`. Focus on encapsulation, invariant expression, and correct use of the type system."
```

### Code Simplifier

```
Task tool:
  subagent_type: pr-review-toolkit:code-simplifier
  max_turns: 20
  description: "Suggest simplifications on branch"
  prompt: "Review the implementation in this branch for clarity, consistency, and maintainability. Read the diff: `git diff origin/<default-branch>...HEAD`. Suggest only simplifications that preserve behavior — no refactoring that changes functionality."
```

---

## Issue-Fixer (Batched Dispatch)

**Dispatch in batches of at most 3 issues per dispatch.** Sub-agents cannot compact context — a single dispatch with many issues will exhaust the context window.

```
Task tool:
  subagent_type: super-ralph:issue-fixer
  max_turns: 30
  description: "Fix review findings batch [N]/[TOTAL] on branch"
  prompt: |
    Fix the following code review findings on branch <BRANCH>.
    This is batch [N] of [TOTAL].

    ## Findings to Fix (max 3 — Critical first, then Important)

    <PASTE ONLY THIS BATCH'S FINDINGS>

    ## Instructions

    For each finding:
    1. Read 20 lines of context around the issue
    2. Implement the minimal fix
    3. Run the specific test file: bun test <test-file-path>
    4. Commit: git add [files] && git commit -m "fix: [what] (review-fix)"

    Skip Minor and Suggestions — they don't block completion.
    NEVER ask for human input.
```

### Batching example

2 Critical + 5 Important issues → 3 dispatches:

- **Batch 1:** 2 Critical + 1 Important
- **Batch 2:** 2 Important
- **Batch 3:** 2 Important

Process batches sequentially. After each batch, verify with `git log --oneline -5` before dispatching the next.

---

## SME Brainstormer (Oscillation Escalation Only)

Dispatched only when the same issue (same file, same type) appears in **3+ consecutive iterations**. This indicates an architectural problem, not a local bug.

```
Task tool:
  subagent_type: super-ralph:sme-brainstormer
  max_turns: 15
  description: "Root-cause oscillating fix"
  prompt: |
    The following review finding keeps recurring across iterations:
    <FINDING>

    Fix history (what was tried, why it broke again):
    <LIST OF PAST ATTEMPTS FROM FIX HISTORY>

    Analyze the root cause from an architectural perspective. Is this a local bug or a design issue?
    If architectural, propose the smallest refactor that resolves the oscillation.
    Return: ROOT_CAUSE + RECOMMENDED_FIX (with file paths and one-line rationale).
```

If the brainstormer proposes an architectural change beyond the review-fix scope, emit `<promise>REVIEW_BLOCKED</promise>`, write to `BLOCKED.md` with the brainstormer's analysis, and stop.

---

## Promise Strings (completion signals)

Ralph-loop uses these exact strings to detect the end-state:

- `<promise>REVIEW_CLEAN</promise>` — all review agents returned clean + all tests pass. Proceed to PR creation.
- `<promise>REVIEW_BLOCKED</promise>` — oscillation detected and brainstormer can't resolve. Stop; wait for human.

Emit the promise string on its own line when the condition is met.

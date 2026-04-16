---
name: plan
description: "Create implementation plans for ad-hoc work ([FIX], [CHORE], spikes). For epic-driven features, use /super-ralph:design instead."
argument-hint: "<feature-description> [--mode standard|hybrid|auto] [--output PATH] [--story EPIC_PATH#STORY_ID]"
allowed-tools: ["Bash(git:*)", "Bash(bun:*)", "Bash(npm:*)", "Read", "Write", "Glob", "Grep", "Task", "WebSearch", "WebFetch"]
---

# Super-Ralph Plan Command

> **Note:** For epic-driven product features, use `/super-ralph:design` instead — it produces implementation-ready stories with embedded TDD tasks. This command is for:
> - `[FIX]` hotfixes and bug fixes
> - `[CHORE]` infrastructure, DevOps, dependency upgrades
> - Exploratory spikes and prototypes
> - Small ad-hoc improvements by tech lead

Create an implementation plan optimized for autonomous Ralph Loop execution with superpowers integration.

## Arguments

Parse the user's input for:
- **Feature description** (required unless --story provided): What to build
- **--mode** (optional): `standard`, `hybrid`, or `auto` (default: `auto`)
- **--output** (optional): Plan output path (default: `docs/plans/YYYY-MM-DD-<slug>.md`)
- **--story** (optional): Reference to an epic story: `EPIC_PATH#story-N` or `EPIC_PATH#story-1,story-2` for multiple stories. When provided, generates e2e tests from acceptance criteria as Task 0.

## Workflow

Execute these steps in order. **Do NOT ask the user for input at any point.** Make all decisions autonomously using the research + SME pattern.

### Step 1: Load Planning Skill

Invoke the `super-ralph:ralph-planning` skill. Follow its instructions for plan structure, task granularity, and superpowers integration.

### Step 1.5: Extract Story Context (if --story provided)

If `--story` is provided:

1. **Parse the reference:** Split `EPIC_PATH#story-N` into file path and story IDs
2. **Read the epic file** at the path
3. **Extract each referenced story:**
   - Story title, persona, action, outcome
   - Priority (P0/P1/P2) and Complexity (S/M/L/XL)
   - All acceptance criteria in Given/When/Then format
   - E2E test skeleton if present
   - Dependencies and technical notes
4. **Use story as feature description:** The story's "I want to [action] so that [outcome]" replaces the feature description argument
5. **Use story complexity** to inform iteration budget (S→10, M→20, L→35, XL→split)
6. **Store acceptance criteria** — these will be used in Step 5 to generate Task 0 (e2e tests)

### Step 2: Explore the Codebase

Before planning, understand the existing codebase:
1. Read CLAUDE.md and any project documentation
2. Use Glob and Grep to understand project structure, tech stack, existing patterns
3. Identify relevant files, modules, and conventions that the plan must follow

### Step 3: Research and Brainstorm

Launch agents in parallel to inform the plan:

1. **Dispatch research-agent** (Task tool, subagent_type: general-purpose):
   - Search web for architectural patterns, best practices, and known pitfalls relevant to the feature
   - Return concise findings with source URLs

2. **Dispatch 2-3 sme-brainstormer agents** (Task tool, subagent_type: general-purpose) in parallel:
   - Agent 1 focus: "Task decomposition — how to break this feature into bite-sized TDD tasks for autonomous execution"
   - Agent 2 focus: "Architecture — what patterns fit this codebase and tech stack for this feature"
   - Agent 3 focus (if complex): "Risks and edge cases — what could go wrong, what needs special handling"

3. Synthesize findings from all agents.

### Step 4: Select Mode

If `--mode auto` (default):
- **Standard** if: fewer than 6 tasks, tasks are tightly coupled, shared state between tasks
- **Hybrid** if: 6+ independent tasks, each substantial enough for own subagent, quality gates desired

If uncertain, dispatch an sme-brainstormer with the specific task breakdown to decide.

### Step 5: Write the Plan

Using the `super-ralph:ralph-planning` skill's plan template (`references/plan-template.md`):

1. Fill in the header: Executor (super-ralph), Mode, Skills, Run directive
2. Write Goal (one sentence)
3. Define Tech Stack from codebase exploration
4. Calculate Iteration Budget from number of tasks
5. Add Skill Directives (TDD, debugging, verification + autonomous decision pattern)
6. Define machine-verifiable Completion Criteria
7. Add If Blocked handling

**If --story was provided (outside-in TDD):**

8. **Write Task 0: E2E Tests from Acceptance Criteria (outer RED)**
   - Create the e2e test file from the story's acceptance criteria
   - Each Given/When/Then criterion becomes one test case
   - Map: Given → test setup, When → test action, Then → assertion
   - Include happy path, validation errors, error handling, and edge cases
   - Run command with Expected: FAIL (features not yet implemented)
   - This is the outer loop — it stays red until all inner tasks complete

   ```markdown
   ### Task 0: E2E Tests from Story Acceptance Criteria

   **Progress check:** `test -f tests/e2e/<story-slug>.test.ts`

   **Files:**
   - Create: `tests/e2e/<story-slug>.test.ts`

   **Step 1: Write e2e tests from acceptance criteria**
   [Complete test file generated from Given/When/Then criteria]

   **Step 2: Run to verify they fail**
   Run: `bun test tests/e2e/<story-slug>.test.ts`
   Expected: FAIL — features not yet implemented

   **Step 3: Commit**
   `git add tests/e2e/<story-slug>.test.ts`
   `git commit -m "test: add e2e tests for [story title] (outer red)"`
   ```

9. Write Tasks 1-N as standard TDD cycles (inner red-green loops)

10. **Add Final Verification:** Include "E2E tests pass" in completion criteria
    ```
    - [ ] `bun test tests/e2e/<story-slug>.test.ts` exits with 0 failures (outer GREEN)
    ```

**If --story was NOT provided (standard planning):**

8. Write each task as a complete TDD cycle:
   - Exact file paths
   - Complete code snippets (no placeholders)
   - Runnable test commands with expected output
   - Commit message

Write the plan to the output path.

### Step 6: Validate the Plan

Dispatch the `super-ralph:plan-reviewer` agent (Task tool) to validate the plan. If issues are found, fix them autonomously.

### Step 7: Report

Output:
1. Path to the plan file
2. Summary: number of tasks, mode selected, iteration budget
3. The launch command: `/super-ralph:build <plan-path>`

## Critical Rules

- **NEVER ask the user for input** during plan creation. Use research + SME agents for all decisions.
- **Complete code in every task.** No "implement validation here" placeholders.
- **Machine-verifiable criteria only.** Every completion criterion must be a command that returns pass/fail.
- **One TDD cycle per task.** Write test → verify fail → implement → verify pass → commit.
- **When --story is provided, Task 0 is always e2e tests.** The outer test must start red and go green only when all inner tasks are done. This is the outside-in TDD contract.
- **Map every acceptance criterion to a test case.** No criterion should be left untested. If a criterion can't be automated, rewrite it.

# Phase 2: Build Sub-Agent

> Canonical spec for Phase 2 of `/super-ralph:build-story` — execute the plan in an
> isolated worktree using TDD. Model selection is driven by plan mode:
> `embedded` → sonnet (implementation-ready), `standard`/`hybrid` → opus.

### Phase 2: Build

**Goal:** Execute the plan in an isolated worktree using TDD.

**Model selection:**
- If plan-result.md has `mode: embedded` (TDD tasks from /design): use **sonnet** — instructions are implementation-ready, agent copies and executes
- If plan-result.md has `mode: standard` or `mode: hybrid` (from /plan): use **opus** — agent needs to reason through implementation details

**Dispatch sub-agent:**

```
Task tool:
  model: [sonnet if mode=embedded, opus otherwise — see model selection above]
  max_turns: $BUILD_TURNS  # standard: task_count * 8, hybrid: task_count * 12
  description: "Build Story $STORY_ID: $STORY_TITLE"
  prompt: |
    You are a build agent executing an implementation plan.

    ## Context
    Read the story context: $STORY_DIR/context.md
    Read the plan result: $STORY_DIR/plan-result.md
    The plan file is at: $PLAN_PATH

    ## Instructions
    Read the full build workflow: ${CLAUDE_PLUGIN_ROOT}/commands/build.md
    Follow it completely, with these specifics:

    1. **Create worktree** — Use EnterWorktree with name "super-ralph/$STORY_SLUG".
       If EnterWorktree is not available, create manually:
       ```bash
       git worktree add .claude/worktrees/super-ralph-$STORY_SLUG -b super-ralph/$STORY_SLUG
       ```
       Install dependencies in the worktree.

    2. **Copy plan** into the worktree if it's untracked:
       ```bash
       PLAN_ABS=$(realpath "$PLAN_PATH")
       test -f "$PLAN_PATH" || (mkdir -p "$(dirname "$PLAN_PATH")" && cp "$PLAN_ABS" "$PLAN_PATH")
       ```

    3. **Execute mode: $MODE**

       **Standard mode:**
       Execute each task sequentially following TDD:
       - Write failing test (RED) → run test → verify FAIL
       - Implement code (GREEN) → run test → verify PASS
       - Commit with descriptive message
       Move to next task. Skip completed tasks (check git log).

       **Hybrid mode:**
       Orchestrate by dispatching sub-agents:
       - For independent tasks: dispatch UP TO 3 in parallel
       - Each sub-agent gets full task text + context
       - After each sub-agent: run spec compliance reviewer, then code quality reviewer
       - Fix issues found before proceeding

    4. **After all tasks:** Run final verification:
       ```bash
       $BE_TEST_CMD
       $FE_TEST_CMD
       ```

    5. **Push the branch:**
       ```bash
       git push -u origin super-ralph/$STORY_SLUG
       ```

    6. **Write result** to $STORY_DIR/build-result.md:
       ```
       phase: build
       status: COMPLETE|FAILED
       branch: super-ralph/$STORY_SLUG
       worktree: [path]
       mode: [standard|hybrid]
       tasks_completed: [N/M]
       tasks_failed: [list or "none"]
       test_results: [X passed, Y failed, Z skipped]
       commits: [number of commits]
       ```

    If a task fails after 3 attempts, mark it in BLOCKED.md and continue with
    independent tasks. Write FAILED status only if blocking tasks remain.

    NEVER ask for human input. Use research + SME agents for all decisions.
```

**Calculating BUILD_TURNS:**
- Standard mode: `task_count * 8` (each task ~8 turns: test + implement + verify + commit)
- Hybrid mode: `task_count * 12` (adds review gates per task)
- Minimum: 30, Maximum: 200

**After sub-agent completes:**
1. Read `$STORY_DIR/build-result.md`
2. Check status:
   - COMPLETE → proceed to Phase 3
   - FAILED → dispatch SME brainstormer to analyze failure, attempt one retry, then report
3. Update `$STORY_DIR/progress.md`: Build → DONE or FAILED

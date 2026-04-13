---
name: e2e
description: "Execute an entire epic end-to-end — plan, build, review, verify, finalise all stories, then release"
argument-hint: "EPIC_NUMBER [--milestone NAME] [--max-parallel N] [--skip-release] [--skip-verify]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph-loop.sh:*)", "Bash(git:*)", "Bash(gh:*)", "Bash(bun:*)", "Bash(codex:*)", "Bash(mkdir:*)", "Bash(cat:*)", "Bash(rm:*)", "Bash(wc:*)", "Bash(jq:*)", "Bash(date:*)", "Read", "Write", "Edit", "Glob", "Grep", "Task"]
---

# Super-Ralph E2E Command

Execute an entire epic from start to finish: load the epic from GitHub, plan story execution waves, dispatch parallel story executors (plan → build → review-fix → verify), finalise stories sequentially, then run release to promote staging → main.

**This is a fire-and-forget command.** Once invoked, it drives an entire epic to completion with zero human interaction. All decisions are made autonomously via research + SME brainstorming.

## Branch Model Context

```
story branches ──review-fix→PR──▶ staging (default, preview deploys)
                                       │
                              /super-ralph:release
                                       │
                                       ▼
                                  main (production)
```

All story PRs target `staging` (GitHub default branch). The release phase at the end promotes staging → main.

## Arguments

Parse the user's input for:
- **EPIC_NUMBER** (required): GitHub issue number of the `[EPIC]` issue
- **--milestone** (optional): Milestone name for the release phase. If omitted, auto-detect from the epic's milestone.
- **--max-parallel** (optional): Max stories executing in parallel per wave. Default: `3`.
- **--skip-release** (optional): Skip the final release phase. Useful for partial epic execution.
- **--skip-verify** (optional): Skip browser verification for all stories.

## Temp File Strategy

All inter-phase communication uses temp files. This prevents context overflow in sub-agents — each phase reads only what it needs.

```
/tmp/super-ralph-e2e-$EPIC_NUMBER/
├── epic-context.md              # Full epic body + all stories
├── waves.md                     # Planned execution waves
├── progress.md                  # Live progress tracker
├── stories/
│   ├── $STORY_NUMBER/
│   │   ├── brief.md             # Story requirements + acceptance criteria
│   │   ├── plan-result.md       # Phase 1 output: plan path, branch name
│   │   ├── build-result.md      # Phase 2 output: completion status
│   │   ├── review-result.md     # Phase 3 output: PR number, review status
│   │   ├── verify-result.md     # Phase 4 output: pass/fail
│   │   └── status.md            # Overall: READY | FAILED | BLOCKED
│   └── ...
└── release-result.md            # Final release output
```

## Workflow

Execute all steps in order. **NEVER ask for human input** at any point.

### Step 0: Load Epic Context

1. **Fetch the epic issue:**
   ```bash
   gh issue view $EPIC_NUMBER --repo Forth-AI/work-ssot --json number,title,body,labels,milestone,state
   ```

2. **Validate it's an epic:**
   - Title must contain `[EPIC]`
   - State must be `OPEN`
   - If closed: `"Epic #$EPIC_NUMBER is already closed. Nothing to do."` → stop

3. **Fetch all sub-issues (stories):**
   ```bash
   gh issue list --repo Forth-AI/work-ssot --state all --json number,title,body,state,labels,assignees \
     --jq '.[] | select(.body | test("Parent:?\\s*#'$EPIC_NUMBER'"; "i"))'
   ```

4. **If no sub-issues found, parse stories from epic body:**
   - Look for story sections (e.g., `### Story 1:`, `## Story-1:`)
   - Extract: title, persona, action, outcome, acceptance criteria (Given/When/Then)
   - These inline stories won't have GitHub issue numbers — create a synthetic ID (story-1, story-2, etc.)

5. **Create temp directory and write epic context:**
   ```bash
   E2E_DIR="/tmp/super-ralph-e2e-$EPIC_NUMBER"
   mkdir -p "$E2E_DIR/stories"
   ```
   Write `$E2E_DIR/epic-context.md` with:
   ```markdown
   # Epic #$EPIC_NUMBER: $EPIC_TITLE

   ## Epic Body
   [full body]

   ## Stories
   | # | Number | Title | State | Priority | Complexity | Dependencies |
   |---|--------|-------|-------|----------|------------|-------------|
   [table of all stories]

   ## Milestone
   [milestone name if set]
   ```

6. **Write individual story briefs:**
   For each story, write `$E2E_DIR/stories/$STORY_NUMBER/brief.md`:
   ```markdown
   # Story #$STORY_NUMBER: $STORY_TITLE

   **Epic:** #$EPIC_NUMBER — $EPIC_TITLE
   **Epic file path:** [path to epic .md file if it exists in docs/epics/]

   ## Requirements
   [story body — persona, action, outcome]

   ## Acceptance Criteria
   [Given/When/Then blocks extracted from story body or epic body]

   ## Dependencies
   [list of story numbers this depends on, or "none"]

   ## Technical Notes
   [any technical notes from the story body]
   ```

7. **Report:**
   ```
   Epic #$EPIC_NUMBER: $EPIC_TITLE
   Stories found: $STORY_COUNT ($OPEN_COUNT open, $CLOSED_COUNT already completed)
   Temp directory: $E2E_DIR
   ```

### Step 1: Filter Actionable Stories

Remove stories that don't need execution:
- **Already closed**: Skip (work already done)
- **Already has a merged PR**: Skip
- **Already has an open PR**: Include but skip plan+build phases (resume from review-fix)

Write the filtered list to `$E2E_DIR/actionable-stories.md`.

### Step 2: Plan Execution Waves

Dispatch an SME brainstormer to analyze story dependencies and plan parallel waves:

```
Task tool:
  subagent_type: super-ralph:sme-brainstormer
  model: sonnet
  max_turns: 20
  description: "Plan execution waves for Epic #$EPIC_NUMBER"
  prompt: |
    Analyze these stories from Epic #$EPIC_NUMBER and plan execution waves
    for maximum parallelism.

    Read the epic context: $E2E_DIR/epic-context.md
    Read each story brief: $E2E_DIR/stories/*/brief.md

    ## Your Task

    1. For each story, identify:
       - Explicit dependencies ("Depends on Story X", "After Story Y")
       - Implicit dependencies (shared schema tables, shared API routes, shared UI components)
       - File conflict risk (stories modifying the same files)

    2. Group stories into execution waves:
       - Wave 1: Stories with NO dependencies (can all run in parallel)
       - Wave 2: Stories that depend on Wave 1 stories
       - Wave N: Stories that depend on Wave N-1 stories
       - Within each wave, limit to $MAX_PARALLEL concurrent stories

    3. For stories that touch shared files (schema.ts, types.ts, i18n):
       - Put them in the SAME wave if they append to DIFFERENT sections
       - Put them in SEQUENTIAL waves if they modify the SAME section

    4. Write the result to $E2E_DIR/waves.md:

    ```markdown
    # Execution Waves for Epic #$EPIC_NUMBER

    ## Wave 1 (parallel, no dependencies)
    - Story #N1: [title] — [reason for this wave]
    - Story #N2: [title] — [reason for this wave]

    ## Wave 2 (depends on Wave 1)
    - Story #N3: [title] — depends on #N1 for [reason]

    ## Wave 3 (depends on Wave 2)
    - Story #N4: [title] — depends on #N3 for [reason]

    ## Dependency Graph
    [mermaid diagram or text representation]

    ## Risk Notes
    [any shared file conflicts or coordination concerns]
    ```

    Optimize for FEWEST waves (maximum parallelism) while respecting dependencies.
```

Read the resulting `$E2E_DIR/waves.md` and parse waves into an ordered list.

### Step 3: Initialize Progress Tracker

Write `$E2E_DIR/progress.md`:
```markdown
# E2E Progress: Epic #$EPIC_NUMBER

| Story | Wave | Plan | Build | Review | Verify | Finalise | Status |
|-------|------|------|-------|--------|--------|----------|--------|
| #N1   | 1    | -    | -     | -      | -      | -        | PENDING |
| #N2   | 1    | -    | -     | -      | -      | -        | PENDING |
| #N3   | 2    | -    | -     | -      | -      | -        | PENDING |

Started: [timestamp]
```

### Step 4: Execute Waves

For each wave in order:

#### 4a. Dispatch Story Executors (Parallel)

For each story in the current wave, dispatch a **Story Executor** sub-agent that follows the `build-story` workflow (plan → build → review-fix → verify). Dispatch up to `--max-parallel` stories simultaneously.

Each story executor uses the same temp-file protocol as `/super-ralph:build-story`, but writes to the e2e temp directory so the orchestrator can monitor progress.

```
Task tool:
  model: opus
  max_turns: 200
  description: "Execute Story #$STORY_NUMBER for Epic #$EPIC_NUMBER"
  prompt: |
    You are a Story Executor for Epic #$EPIC_NUMBER, Story #$STORY_NUMBER.

    Follow the build-story workflow from:
      /Users/junhua/.claude/plugins/super-ralph/commands/build-story.md

    Key overrides for e2e context:
    - Temp directory: $E2E_DIR/stories/$STORY_NUMBER (NOT /tmp/super-ralph-story-*)
    - Story context is pre-written at: $E2E_DIR/stories/$STORY_NUMBER/brief.md
    - Epic context is at: $E2E_DIR/epic-context.md
    - Skip Step 0 (context already prepared by e2e orchestrator) — start from Phase 1
    - SKIP FINALISE — write status as READY, do NOT merge. The orchestrator merges sequentially.
    - $VERIFY_INSTRUCTION

    Read build-story.md for the full phase-by-phase workflow:
    Phase 1 (Plan), Phase 2 (Build), Phase 3 (Review-Fix), Phase 4 (Verify).

    Write phase result files to $E2E_DIR/stories/$STORY_NUMBER/ after each phase.
    Write final status to $E2E_DIR/stories/$STORY_NUMBER/status.md when done.

    NEVER ask for human input. Use research + SME agents for all decisions.
```

#### 4b. Monitor Wave Completion

After dispatching all story executors for the wave, wait for all to complete. As each finishes:
1. Read its status file: `$E2E_DIR/stories/$STORY_NUMBER/status.md`
2. Update `$E2E_DIR/progress.md` with the result
3. Report: `"Story #$STORY_NUMBER: [STATUS] — [summary]"`

#### 4c. Sequential Finalise

After all story executors in the wave report READY status:

For each completed story **one at a time** (sequential to avoid merge conflicts):

1. Read `$E2E_DIR/stories/$STORY_NUMBER/review-result.md` to get PR number
2. Execute finalise for this story:
   ```bash
   # Ensure we're on the staging branch
   git checkout staging
   git pull origin staging

   # Get PR info
   PR_NUMBER=$(cat "$E2E_DIR/stories/$STORY_NUMBER/review-result.md" | grep "pr_number:" | awk '{print $2}')

   # Wait for CI
   gh pr checks $PR_NUMBER --repo Forth-AI/work-ssot --watch

   # Merge (squash into staging)
   gh pr merge $PR_NUMBER --squash --delete-branch --repo Forth-AI/work-ssot

   # Pull merged changes
   git pull origin staging
   ```
3. Close related GitHub issues (same logic as finalise.md Step 2b)
4. Update progress tracker
5. Report: `"Finalised Story #$STORY_NUMBER — PR #$PR_NUMBER merged into staging"`

**Why sequential?** Stories within a wave may touch shared files (schema.ts, types.ts, i18n). Sequential merging with rebase ensures clean history. Git handles the append-only sections from the shared file protocol.

#### 4d. Update Plan and Epic Status

After all stories in the wave are finalised:
1. Update plan files (mark tasks as completed)
2. Update epic file (mark stories as completed)
3. Commit documentation updates:
   ```bash
   git add docs/plans/ docs/epics/
   git commit -m "docs: mark Wave $WAVE_NUM stories as completed for Epic #$EPIC_NUMBER"
   git push origin staging
   ```

#### 4e. Wave Gate

Before proceeding to the next wave:
- If any story in this wave is BLOCKED or FAILED: report but continue
- If a BLOCKED story is a dependency for the next wave: dispatch sme-brainstormer to decide whether to proceed, skip dependent stories, or attempt a fix
- Update progress tracker

### Step 5: Post-Wave Completion

After all waves are done:

1. **Update roadmap:** Follow the same roadmap-update logic as finalise.md Step 5
2. **Commit:**
   ```bash
   git add docs/roadmap.md
   git commit -m "docs: update roadmap — Epic #$EPIC_NUMBER complete"
   git push origin staging
   ```
3. **Close the epic issue** if all sub-issues are closed:
   ```bash
   OPEN_SUBS=$(gh issue list --repo Forth-AI/work-ssot --json body,state \
     --jq "[.[] | select(.body | test(\"Parent:?\\s*#$EPIC_NUMBER\"; \"i\")) | select(.state==\"OPEN\")] | length")
   if [ "$OPEN_SUBS" = "0" ]; then
     gh issue close $EPIC_NUMBER --repo Forth-AI/work-ssot --comment "All stories shipped. Epic complete."
   fi
   ```

### Step 6: Release (if not --skip-release)

If `--skip-release` was NOT passed and all stories completed successfully:

1. **Determine milestone:**
   - If `--milestone` provided: use it
   - Else: extract from the epic issue's milestone
   - If no milestone: skip release, report `"No milestone set — skipping release. Run /super-ralph:release manually."`

2. **Execute the release command logic** (from `release.md`):
   - Pre-flight checks on staging
   - QA verification on staging
   - Create staging → main PR
   - Codex review
   - Merge to main
   - Tag, milestone closure, GitHub Release
   - Sync staging with main

   The simplest way: invoke the release workflow directly by reading and following `${CLAUDE_PLUGIN_ROOT}/commands/release.md`.

### Step 7: Final Summary

Write `$E2E_DIR/summary.md` and output to the user:

```markdown
# Epic #$EPIC_NUMBER: $EPIC_TITLE — Complete

## Execution Summary
- Stories executed: $TOTAL
- Successful: $SUCCESS_COUNT
- Failed/Blocked: $FAILED_COUNT
- Waves: $WAVE_COUNT
- Total time: [start to finish]

## Story Results
| Story | Status | PR | Merged |
|-------|--------|-----|--------|
| #N1   | ✅ Done | #PR1 | Yes |
| #N2   | ✅ Done | #PR2 | Yes |
| #N3   | ❌ Blocked | - | No |

## Release
- Tag: $TAG
- Release PR: #$RELEASE_PR
- Production: Deployed to main

## Failed Stories (if any)
[Details of what went wrong and suggested remediation]
```

Output completion promise: `E2E_COMPLETE`

---

## Story Executor Reference

Each story executor sub-agent follows the `/super-ralph:build-story` workflow defined in:
`${CLAUDE_PLUGIN_ROOT}/commands/build-story.md`

The e2e orchestrator overrides these aspects when dispatching story executors:
- **Temp directory**: `$E2E_DIR/stories/$STORY_NUMBER/` (not `/tmp/super-ralph-story-*`)
- **Context**: Pre-prepared by the orchestrator in Step 0 (skip build-story's Step 0)
- **Finalise**: SKIPPED — the orchestrator handles merging sequentially in Step 4c
- **Verify**: Follows `--skip-verify` flag from the e2e invocation

---

## Resuming After Failures

If the e2e command is re-run for the same epic:

1. Check if `$E2E_DIR` already exists
2. Read `$E2E_DIR/progress.md` to see what's already done
3. Skip stories with status READY or already finalised
4. Re-run only FAILED or PENDING stories
5. This makes the command **idempotent** — safe to re-run after partial failures

### How to detect resume state per story:
- `status.md` exists with `READY` → skip executor, proceed to finalise if not yet merged
- `status.md` exists with `FAILED` → re-run from the failed phase
- `review-result.md` exists but `status.md` doesn't → resume from verify
- `build-result.md` exists but `review-result.md` doesn't → resume from review-fix
- `plan-result.md` exists but `build-result.md` doesn't → resume from build
- Nothing exists → run from plan

To resume from a specific phase, adjust the story executor prompt to skip earlier phases and read their output from existing temp files.

---

## Error Handling

### Story-Level Failures
- A failed story does NOT block other stories in the same wave (unless it's a dependency)
- A failed story DOES block stories in later waves that depend on it
- Failed stories are reported in the final summary with remediation suggestions

### Wave-Level Decisions
When a story fails and it's a dependency for the next wave, dispatch an sme-brainstormer:
```
Task tool:
  subagent_type: super-ralph:sme-brainstormer
  description: "Decide how to handle failed dependency"
  prompt: |
    Story #$FAILED_STORY failed during phase $PHASE with error: $ERROR
    The following stories depend on it: $DEPENDENT_STORIES
    Options:
    1. Skip dependent stories (mark as BLOCKED)
    2. Attempt to fix the failure and retry
    3. Reorder: promote independent stories from later waves
    Analyze and recommend the best option.
```

### Phase-Level Retries
- Plan: retry once with different SME brainstormers
- Build: retry failed task up to 3 times, then mark task as BLOCKED
- Review-fix: max 5 iterations (built into the review-fix logic)
- Verify: retry 2 times with repair between retries
- If all retries exhausted: mark story as FAILED, continue with other stories

---

## Critical Rules

- **Fire and forget.** Once started, the e2e command runs to completion without human input. ALL decisions use research + SME agents.
- **Temp files are the context bridge.** Every phase writes structured output. Every phase reads only what it needs. This prevents context overflow in sub-agents.
- **Story executors are parallel; finalise is sequential.** Stories within a wave build concurrently. Merging happens one at a time to respect the shared file protocol.
- **Respect the shared file protocol.** The SME wave planner accounts for shared file conflicts. Sequential finalise handles the rest.
- **Idempotent.** Re-running detects existing progress and resumes. Never duplicates work.
- **Graceful degradation.** A failed story doesn't kill the epic. Other stories continue. The summary reports what failed and why.
- **Always target staging.** Story PRs merge into staging. Release promotes staging → main. Never merge directly to main.
- **Max parallelism is bounded.** Default 3 concurrent story executors. Configurable via `--max-parallel`.
- **Clean up temp files last.** Keep `/tmp/super-ralph-e2e-$EPIC_NUMBER/` until the final summary is output. The user may need to inspect it for debugging.
- **Story executor branches follow naming convention:** `super-ralph/$STORY_SLUG` where slug is derived from the story title.
- **Commit from worktrees, not main repo.** Story executors operate in isolated worktrees. Only the orchestrator commits to the main repo (docs updates, roadmap).
- **Version convention follows release.md.** The final release phase uses the same staging→main promotion with Codex review.

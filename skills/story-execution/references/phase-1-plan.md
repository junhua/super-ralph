# Phase 1: Plan Sub-Agent

> Canonical spec for Phase 1 of `/super-ralph:build-story` — the plan sub-agent that
> produces (or skips, when TDD tasks are already embedded) a ralph-optimized plan.
>
> Skip detection: when the story source has TDD tasks embedded (local-mode epic or
> GitHub issue with embedded TDD), plan phase is skipped and `plan-result.md` is
> written directly with `mode: embedded`.

### Phase 1: Plan

**Skip detection:** Before dispatching the plan sub-agent, check if the story source has TDD tasks already embedded:

- **Local mode** (`$MODE = local`): Check whether the extracted sub-story files have content. Use `detect-story-level` from `parse-local-epic.sh` to determine the story level:
  ```bash
  LEVEL=$(${CLAUDE_PLUGIN_ROOT}/scripts/parse-local-epic.sh detect-story-level "$EPIC_FILE" "$STORY_NUM")
  ```

  **If `LEVEL = "full"`** (story has `#### [BE]` / `[FE]` / `[INT]` subsections, so `$STORY_DIR/be.md` + `$STORY_DIR/fe.md` are non-empty): write `$STORY_DIR/plan-result.md` with:
  ```
  phase: plan
  status: DONE
  mode: embedded
  source: $STORY_REF
  be_body_file: $STORY_DIR/be.md
  fe_body_file: $STORY_DIR/fe.md
  int_body_file: $STORY_DIR/int.md
  branch: super-ralph/$STORY_SLUG
  ```
  Skip the plan sub-agent entirely. Log: "Local epic full story — TDD embedded, skipping plan phase." Proceed to Phase 2.

  **If `LEVEL = "brief"`** (story has only bulleted AC, no `#### [BE/FE/INT]` subsections): fall through to the Standard Plan Dispatch path below. The plan sub-agent will read `$STORY_DIR/context.md` (which holds the brief story block including AC bullets) and synthesize TDD tasks. Log: "Local epic brief story — dispatching plan sub-agent." The `$STORY_REF` is treated like a `description` for plan purposes, with the brief AC as the source of truth.

- **GitHub mode** (`$MODE = github`): existing detection path below.

```bash
STORY_BODY=$(gh issue view $STORY_ID --repo $REPO --json body --jq '.body')
HAS_TDD=$(echo "$STORY_BODY" | grep -c "## TDD Tasks\|### Task 0:\|### Task 1:" || true)
```

If `HAS_TDD > 0`:
1. Extract the TDD tasks section from the issue body
2. Write it to `$STORY_DIR/plan-result.md` with status: DONE and mode: embedded
3. Skip the plan sub-agent entirely
4. Log: "TDD tasks found in issue body — skipping plan phase"
5. Proceed to Phase 2 (Build)

**Also check for [FE] and [BE] sub-issues:**
```bash
FE_ISSUE=$(gh issue list --repo $REPO --json number,title,body \
  --jq "[.[] | select(.body | test(\"Parent:?\\s*#$STORY_ID\"; \"i\")) | select(.title | startswith(\"[FE]\"))] | first | .number")
BE_ISSUE=$(gh issue list --repo $REPO --json number,title,body \
  --jq "[.[] | select(.body | test(\"Parent:?\\s*#$STORY_ID\"; \"i\")) | select(.title | startswith(\"[BE]\"))] | first | .number")
```

If FE and BE sub-issues exist:
1. Read their bodies for TDD tasks
2. Build can execute FE tasks and BE tasks independently
3. Write to plan-result.md: `fe_issue: $FE_ISSUE`, `be_issue: $BE_ISSUE`

If `HAS_TDD = 0` and no FE/BE sub-issues:
1. Proceed with existing Phase 1 plan sub-agent (unchanged)

## Standard Plan Dispatch (when TDD is not embedded)

This path runs when:
- GitHub mode and the issue body has no `## TDD Tasks` section AND no `[BE]`/`[FE]` sibling sub-issues (existing behavior), OR
- Local mode and `detect-story-level` returns `brief` (new — see Task 4 of the brief-design plan).

The plan sub-agent reads `$STORY_DIR/context.md` for the story context (user story + AC, in Gherkin or bullets depending on source) and produces a full TDD plan.

**Goal:** Create a ralph-optimized implementation plan with TDD tasks.

**Dispatch sub-agent:**

```
Task tool:
  model: opus
  max_turns: 50
  description: "Plan Story $STORY_ID: $STORY_TITLE"
  prompt: |
    You are a planning agent for Story "$STORY_TITLE".

    ## Context
    Read the story context: $STORY_DIR/context.md

    ## Instructions
    Read the full planning workflow: ${CLAUDE_PLUGIN_ROOT}/commands/plan.md
    Follow it completely, with these specifics:

    1. **Explore the codebase** — Read CLAUDE.md, understand project structure, tech stack,
       existing patterns, and conventions. Pay special attention to the shared file protocol.

    2. **Research + brainstorm** — Dispatch these agents IN PARALLEL:
       - research-agent: search for best practices relevant to this feature
       - sme-brainstormer 1: task decomposition for autonomous TDD execution
       - sme-brainstormer 2: architecture patterns that fit this codebase
       Synthesize findings.

    3. **Select mode** — If story complexity is S/M: standard. L/XL: hybrid. Auto if unknown.
       Override with: $MODE_OVERRIDE

    4. **Write the plan** with Task 0 as e2e tests from acceptance criteria (outside-in TDD).
       Use the story reference for the --story flag logic in plan.md.

    5. **Validate** — Dispatch plan-reviewer agent.

    6. **Write plan** to: docs/plans/$(date +%Y-%m-%d)-$STORY_SLUG.md

    7. **Write result** to $STORY_DIR/plan-result.md:
       ```
       phase: plan
       status: DONE
       plan_path: [absolute path to plan file]
       branch: super-ralph/$STORY_SLUG
       mode: [standard|hybrid]
       task_count: [N]
       iteration_budget: [N]
       story_ref: [epic_path#story-id if available]
       ```

    NEVER ask for human input. Use research + SME agents for all decisions.
```

**After sub-agent completes:**
1. Read `$STORY_DIR/plan-result.md`
2. Verify plan file exists at the specified path
3. Update `$STORY_DIR/progress.md`: Plan → DONE
4. Extract: `PLAN_PATH`, `BRANCH`, `MODE`, `TASK_COUNT`, `ITERATION_BUDGET`

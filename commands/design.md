---
name: design
description: "Create implementation-ready epics with stories, Gherkin AC, TDD tasks, and FE/BE sub-issues"
argument-hint: "<feature-or-goal> [--output PATH] [--local] [--brief]"
allowed-tools: ["Bash(git:*)", "Bash(gh:*)", "Read", "Write", "Glob", "Grep", "Task", "WebSearch", "WebFetch"]
---

# Super-Ralph Design Command (SADD Flow)

Translate product vision, business goals, or user feedback into implementation-ready epics with full Gherkin acceptance criteria, pre-decided implementation details, TDD task lists, and FE/BE sub-issues. Produces artifacts that feed directly into `/super-ralph:build-story` for autonomous execution.

**This command absorbs `/super-ralph:plan`.** Design produces EVERYTHING: EPIC doc + GitHub issues with Gherkin AC + Pre-Decided Implementation + TDD tasks + FE/BE/INT sub-issues. No separate planning step is needed.

## Arguments

Parse the user's input for:
- **Feature or goal description** (required): What to design — a feature idea, business goal, user feedback, or OKR
- **--output** (optional): Output path (default: `docs/epics/YYYY-MM-DD-<slug>.md`)
- **--local** (optional, boolean): Produce a self-contained local epic file; SKIP GitHub issue creation entirely. Downstream commands (`/build-story`, `/e2e`, `/review-design`) must then be invoked with the epic file path rather than an issue number. Default: false.
- **--brief** (optional, boolean): Produce a brief epic (EPIC header + story skeletons with bulleted AC). SKIPS Phase 4 full story-planner, Step 10.5 context-budget audit, and `[BE]`/`[FE]`/`[INT]` sub-issue creation. Combines with `--local`. Default: false.

When `--brief` is set:
- Phase 4 dispatches brief-story-planner sub-agents (see `skills/product-design/references/sadd-workflow.md` § Phase 4b).
- Step 10.5 (context-budget audit) is skipped; minimal budget report written to `.claude/runs/design-<slug>/context-budget.md`.
- Phase 5 creates `[EPIC]` (with `brief` label) + `[STORY]` issues only. NO `[BE]`/`[FE]`/`[INT]` sub-issues.
- Step 11b (local consolidation) inserts `<!-- super-ralph: brief -->` as line 3 of the epic file.
- Phase 6 (review) uses lite BRIEF-G1..G3 gates via `/review-design`'s auto-detection; the READY verdict becomes `READY FOR EXPAND`.

When `--local` is set:
- Resolve the target path to `docs/epics/YYYY-MM-DD-<slug>.md` (same rules as default).
- If the file already exists, EXIT with `"Epic file already exists at <path>. Use /super-ralph:improve-design to modify, or delete the file first."` — do not overwrite.

## Workflow

Execute the 6-phase SADD flow. **Do NOT ask the user for input at any point.** Make all decisions autonomously using the research + SME pattern described in the skill.

### Step 0: Load Project Config

Read `.claude/super-ralph-config.md` to load project-specific values. If the file does not exist, first attempt auto-init by invoking the init command logic, then tell the user to run `/super-ralph:init` manually if auto-init fails.

The config supplies every `$VARIABLE` used in the referenced skill and its reference files (`$REPO`, `$ORG`, `$PROJECT_NUM`, `$PROJECT_ID`, `$STATUS_FIELD_ID`, `$STATUS_TODO`, `$STATUS_IN_PROGRESS`, `$STATUS_PENDING_REVIEW`, `$STATUS_SHIPPED`, `$BE_DIR`, `$SCHEMA_FILE`, `$ROUTE_REG_FILE`, `$BE_SERVICES_DIR`, `$BE_ROUTES_DIR`, `$BE_TEST_CMD`, `$FE_DIR`, `$TYPES_FILE`, `$API_CLIENT_DIR`, `$I18N_BASE_FILE`, `$I18N_SECONDARY_FILE`, `$FE_PAGES_DIR`, `$FE_COMPONENTS_DIR`, `$FE_TEST_CMD`, `$APP_URL`, `$RUNTIME`).

### Step 1: Load Skills

Invoke the `super-ralph:product-design` skill (full SADD procedure, SLICE, context budget, pre-decided implementation) and `super-ralph:issue-management` skill (taxonomy and GitHub mechanics). Follow their instructions for every subsequent step in this workflow.

### Step 2: Execute the 6-Phase SADD Flow

Follow the step-by-step procedure in:
- **`${CLAUDE_PLUGIN_ROOT}/skills/product-design/references/sadd-workflow.md`** — Phases 0–3 (Config, Context, Research, Epic Definition), Phase 5 (Issue Creation), Phase 6 (Review + Final Report), and the Local Mode (Step 11b) consolidation branch.
- **`${CLAUDE_PLUGIN_ROOT}/skills/product-design/references/story-planner-spec.md`** — Phase 4 Step 9 (dispatch parallel story-planner sub-agents; produces STORY/BE/FE/INT bodies with pre-decided implementation + exact TDD tasks).
- **When `--brief` is set:** dispatch brief-story-planner sub-agents instead; skip `story-planner-spec.md`. See `sadd-workflow.md` § "Phase 4b: Brief Story Planning" for the prompt.
- **`${CLAUDE_PLUGIN_ROOT}/skills/product-design/references/execution-planning.md`** — Step 10 (DAG), Step 10.5 (context-budget audit + remediation), Step 11 (AI-hours + wave assignment).
- **`${CLAUDE_PLUGIN_ROOT}/skills/product-design/references/context-budget.md`** — Execution Context Budget rules, per-output-body caps, SPLIT_NEEDED protocol, CTX gate definitions.

### Step 3: Invoke Design Review (Phase 6)

Dispatch `/super-ralph:review-design` inline as a sub-agent to validate the generated design:

```
Task tool:
  model: sonnet
  max_turns: 30
  description: "Review design quality for EPIC <target>"
  prompt: |
    You are a design-reviewer agent.

    Read the review-design command: ${CLAUDE_PLUGIN_ROOT}/commands/review-design.md
    Follow it completely for:
      - `#<epic-number>` when `--local` was NOT set
      - `docs/epics/<slug>.md` when `--local` WAS set

    Run all PM Gates, Developer Gates, Context Budget Gates, and Cross-Issue Checks.
    Return a structured verdict: READY / CONDITIONAL / BLOCKED.
```

If the review returns Critical findings:
1. Parse each Critical finding.
2. Fix the issue in the relevant GitHub issue body or epic doc.
3. Re-validate the fix.
4. Do NOT rewrite AC or TDD code for non-Critical findings.

### Step 4: Output Final Report

Produce the final report in the format defined in `sadd-workflow.md` § "Step 17: Report", including:

- EPIC metadata (document path, issue number, milestone)
- Stories Created table
- Execution Plan (waves + AI-hours)
- **Context Budget Audit** (from `execution-planning.md` Step 10.5 — largest combined story, splits triggered, hard-cap violations)
- Review verdict (from Step 3)
- Launch Commands (local-mode `docs/epics/<slug>.md#story-N` form vs GitHub `#<story-number>` form)

## Critical Rules

- **NEVER ask for input.** Use research + SME agents for all decisions. Make autonomous choices and document rationale in the epic.
- **Every AC must be full Gherkin.** See `product-design/references/acceptance-criteria-guide.md`.
- **TDD tasks contain exact code — no placeholders.** Never write "implement X here", "...", or "TODO". Every code block is copy-pasteable.
- **FE sub-issues include mock data.** FE development starts immediately without waiting for BE.
- **Stories must be independently buildable.** Each story is executable via `/super-ralph:build-story #N`.
- **AI-readable output: tables over prose.** Markdown tables for priority, sizing, dependencies, waves.
- **Expected output on every command.** Every `Run:` or `bun test` command shows PASS/FAIL + counts.
- **Decisions pre-made.** Every design choice (component library, state management, API shape) is decided and documented.
- **Shared file protocol enforced.** Every BE/FE sub-issue specifies exact file, section marker, and append location.
- **i18n coverage required.** Both `$I18N_BASE_FILE` and `$I18N_SECONDARY_FILE` entries in every FE sub-issue.
- **Use product vision personas.** Never "As a user" — always a specific persona from the vision doc.
- **Respect non-goals.** If the vision says something is out of scope, the epic must not include it.
- **Concrete over vague.** "Shows 3 templates" not "shows templates." "Within 2 seconds" not "quickly."
- **Fit every execution-level issue in a 200k context window.** Every `[STORY]`, `[BE]`, `[FE]`, `[INT]` body is loaded by a build subagent alongside the files it must read. Target combined body ≤ 90k tokens (~360k chars); hard cap 120k tokens (~480k chars). Enforce via SLICE (pre-estimate), Phase 4 planner prompt constraint, and the Step 10.5 post-plan audit. Hard-cap violation after splitting → verdict **BLOCKED**. See `product-design/references/context-budget.md`.

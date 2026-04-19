---
name: review-design
description: "Validate design quality — review EPIC stories, AC, TDD tasks, shared contracts, and cross-issue consistency"
argument-hint: "<EPIC_NUMBER_or_local_epic_path> [--fix] [--strict]"
allowed-tools: ["Bash(gh:*)", "Bash(git:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/parse-local-epic.sh:*)", "Read", "Write", "Edit", "Glob", "Grep", "Task"]
---

# Super-Ralph Review-Design Command

Validate the quality of a design produced by `/super-ralph:design`. Reviews EPIC stories, Gherkin acceptance criteria, TDD tasks, shared contracts, context-budget compliance, and cross-issue consistency. Returns a structured verdict: **READY**, **CONDITIONAL**, or **BLOCKED**.

## Arguments

- **EPIC target** (required): The `[EPIC]` to review, in one of two forms:
  - **GitHub mode:** `#<issue-number>` or `<issue-number>` (e.g. `123`)
  - **Local mode:** `docs/epics/<slug>.md` (must contain the `<!-- super-ralph: local-mode -->` marker)
- **--fix** (optional): Auto-fix conservative issues (missing i18n rows, placeholder comments). Default: report only.
- **--strict** (optional): Treat Important findings as Critical (blocks READY verdict). Also treats CTX soft-warn as BLOCKED. Default: false.

## Workflow

Execute these steps in order. **Do NOT ask the user for input.** All decisions are autonomous and mechanical.

### Step 0: Load Project Config

Read `.claude/super-ralph-config.md` to load every `$VARIABLE` referenced by the skill and its references. If the file does not exist, attempt auto-init via the init command logic; otherwise tell the user to run `/super-ralph:init`.

### Step 1: Load Skill

Invoke the `super-ralph:design-review` skill for the full gate model, per-story review agent dispatch, cross-issue checks, and verdict logic. Follow its instructions for all subsequent steps.

### Step 2: Execute the Review

Follow the step-by-step procedure in the skill:

- **`${CLAUDE_PLUGIN_ROOT}/skills/design-review/SKILL.md`** — Step 1 (Resolve EPIC), Step 2 (Load sub-issues), Step 2.5 (Apply enforcement gates from `references/gate-catalog.md`), Step 3 (Dispatch per-story review agents in parallel), Step 4 (Cross-issue checks CX-1..CX-5), Step 5 (Classify findings), Step 6 (Auto-fix if `--fix`), Step 7 (Emit verdict).
- **`${CLAUDE_PLUGIN_ROOT}/skills/design-review/references/gate-catalog.md`** — Exact definitions of STORY-G1..G3, BE-G1..G2, FE-G1..G2, INT-G1..G2, CTX-G1..G3, CX-1..CX-5, plus verdict logic.
- **`${CLAUDE_PLUGIN_ROOT}/skills/product-design/references/context-budget.md`** — The context-budget model that CTX-G1..G3 gates enforce.

### Step 3: Emit Verdict & Report

Output the full report in the structure defined in `design-review/SKILL.md` § "Full Report Structure", including:

1. Summary metrics (stories reviewed, check counts, severity counts, auto-fixes applied)
2. Per-Story Results (PM / BE / FE / SC gate tables for every story)
3. Cross-Issue Checks table (CX-1..CX-5 with PASS/FAIL + detail)
4. Gate Summary (STORY-G, BE-G, FE-G, INT-G, CTX-G per issue)
5. Findings Summary classified Critical / Important / Minor
6. **Verdict** — one of READY / CONDITIONAL / BLOCKED:
   - **READY:** output the Wave Plan with exact `/super-ralph:build-story <target>` launch commands in wave order.
   - **CONDITIONAL:** list stories that can start now + blocked stories with fix required; recommend re-running after fixes.
   - **BLOCKED:** list all Critical findings with fix required; recommend re-running after fixes.

`<target>` in launch commands resolves to `#<issue-number>` (GitHub mode) or `docs/epics/<slug>.md#story-N` (local mode).

## Critical Rules

- **NEVER ask for input.** All checks are mechanical against criteria in `gate-catalog.md`.
- **Parallel review agents.** One Sonnet per story in Step 3. Cross-issue checks run inline after.
- **Conservative auto-fix.** Only safe items (i18n, placeholders, section markers). NEVER rewrite AC, TDD code, types, or scope.
- **Severity is objective.** Critical = build blocker. Important = quality gap. Minor = style preference.
- **Wave plan in READY verdict.** Output exact `/super-ralph:build-story` commands so the user can start immediately.
- **Re-run after fixes.** If findings are fixed (manually or via `--fix`), re-run to confirm the verdict changes.
- **Context-budget gates block.** CTX hard-cap violation → BLOCKED (split required). CTX soft-warn (360k-480k chars combined) → CONDITIONAL unless `--strict`.

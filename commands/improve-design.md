---
name: improve-design
description: "Make targeted adjustments to an existing design (local file or GitHub EPIC) from a single natural-language prompt. Autonomously resolves the target epic, interprets feedback, applies conservative structured edits, and re-validates via /review-design."
argument-hint: "\"<prompt>\""
allowed-tools: ["Bash(gh:*)", "Bash(git:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/parse-local-epic.sh:*)", "Read", "Write", "Edit", "Glob", "Grep", "Task", "AskUserQuestion"]
---

# Super-Ralph Improve-Design Command

Make targeted adjustments to an existing design — either a local epic file or a GitHub `[EPIC]` — from a single natural-language prompt. The command autonomously resolves the target, interprets the feedback into structured changes, applies them conservatively, and re-validates via `/super-ralph:review-design`.

## Philosophy

Unlike `/design` and `/e2e` which are fire-and-forget, `/improve-design` may pause once for user disambiguation (Phase 0a) and once to surface a clarification question (Phase 1). These are the only interactive points. All other phases run autonomously.

Shipped work is immutable: stories with `**Status:** COMPLETED` (local) or a CLOSED `[STORY]` issue (GitHub) are refused — the user must cut a new story to change shipped behavior. This guards against destructive retroactive edits.

## Arguments

Parse the user's input as a single quoted prompt containing both:
- Target identifier — a file path (`docs/epics/foo.md`), a `#NNN` issue reference, or absent (in which case Phase 0a infers it)
- Feedback text — free-form description of the desired change

Example prompts:
- `/super-ralph:improve-design "Split Story 5 in docs/epics/2026-04-18-foo.md into list + detail"`
- `/super-ralph:improve-design "Add SSO to epic #531"`
- `/super-ralph:improve-design "The module catalog epic needs a SECURITY scenario in Story 1"`
- `/super-ralph:improve-design "Improve the latest epic: add error handling"`

## Workflow

### Step 0: Load Project Config

Read `.claude/super-ralph-config.md` to load project-specific values. If the file does not exist, first attempt auto-init by invoking the init command logic, then tell the user to run `/super-ralph:init` manually if auto-init fails.

Extract every `$VARIABLE` referenced in the `product-design` skill (at minimum: `$REPO`, `$ORG`, `$PROJECT_NUM`, plus the paths any apply-change sub-agent may need).

### Step 0b: Load Skills

Invoke the `super-ralph:product-design` and `super-ralph:issue-management` skills so apply-change agents can follow canonical patterns (epic structure, SLICE, context budget, Gherkin format, TDD task shape, issue taxonomy, gh mechanics). The apply-change prompts reference those skill's `references/` files directly.

### Phase 0a: Resolve target from prompt

Extraction order:

1. **Explicit file path:**
   ```bash
   TARGET_PATH=$(echo "$PROMPT" | grep -oE 'docs/epics/[^[:space:]]+\.md' | head -1)
   ```
   If non-empty: `TARGET=$TARGET_PATH`, `MODE=local`.

2. **Explicit issue reference:**
   ```bash
   TARGET_NUM=$(echo "$PROMPT" | grep -oE '#[0-9]+|\bEPIC[[:space:]]*#?[0-9]+' | head -1 | grep -oE '[0-9]+')
   ```
   If non-empty: `TARGET="#$TARGET_NUM"`, `MODE=github`.

3. **Fuzzy match** — only if neither above yielded a target. Dispatch a target-resolver sub-agent:

   ```
   Task tool:
     model: sonnet
     max_turns: 10
     description: "Resolve epic target from improvement prompt"
     prompt: |
       User prompt: "$PROMPT"

       Available local epics (path + first `# EPIC:` heading + mtime):
       [glob docs/epics/*.md; for each, read line 1 + `stat -f %m`]

       Available GitHub EPICs:
       [output of: gh issue list --repo $REPO --label epic --state open --json number,title]

       Identify which epic the prompt most likely refers to.
       Return JSON on stdout (single object, no prose):
       {
         "best_match": "docs/epics/foo.md" | "#123" | null,
         "confidence": "high" | "medium" | "low",
         "candidates": [{"target": "...", "reason": "..."}],
         "feedback_stripped": "<prompt minus target-identifying words>"
       }
   ```

4. **Disambiguation gate:**
   - `confidence: high` + single candidate → proceed silently with that target.
   - `confidence: medium` OR 2+ candidates → invoke `AskUserQuestion` listing the candidates. Exit after the user picks (the picked target becomes `TARGET`).
   - `confidence: low` or null → exit with: `"Could not identify which epic to improve. Please include the file path or #EPIC_NUMBER in your prompt."`

After this phase, you MUST have:
- `TARGET` (string)
- `MODE` (`local` or `github`)
- `FEEDBACK` (the prompt with any target-identifying words stripped — use `feedback_stripped` when the resolver ran; otherwise the original prompt)

### Phase 1: Interpret feedback (1 Sonnet sub-agent)

Dispatch a feedback-interpreter sub-agent:

```
Task tool:
  model: sonnet
  max_turns: 15
  description: "Interpret improve-design feedback into structured changes"
  prompt: |
    TARGET: $TARGET (mode: $MODE)
    FEEDBACK: "$FEEDBACK"

    CURRENT DESIGN:
    [if MODE=local: full contents of $TARGET]
    [if MODE=github: issue body + all child STORY/BE/FE/INT bodies (fetch with gh)]

    Map the feedback to one or more structured change entries using ONLY these types:
    - ADD_STORY
    - REMOVE_STORY
    - SPLIT_STORY
    - MERGE_STORIES
    - EDIT_AC
    - EDIT_TDD
    - EDIT_SHARED_CONTRACT
    - EDIT_SCOPE
    - RE_WAVE
    - EDIT_METADATA (priority, size, persona)

    For each change, include:
    - `target`: either `story-N` (local) or `#issue-number` (GitHub) or `epic-header` (for scope/wave edits)
    - `type`: one of the above
    - `details`: type-specific fields (what to add/change, exact wording if user provided it)

    Return JSON on stdout (single object, no prose):
    {
      "clarification_needed": false | true,
      "clarification_question": "<string if true>",
      "changes": [
        {"type": "...", "target": "...", "details": { ... }}
      ]
    }

    If the feedback cannot be mapped to any supported change type (e.g., "make Story 3 simpler" with no specifics), set clarification_needed=true and return a focused question — do NOT guess.
```

Parse the JSON output:
- `clarification_needed=true` → print the question verbatim and exit cleanly (exit code 0, no changes applied).
- `changes` empty → print `"No actionable changes identified in feedback."` and exit.
- Otherwise → proceed to Phase 2.

Persist the changes array to `$(git rev-parse --show-toplevel)/.claude/runs/improve-$(basename $TARGET .md)/changes.json` for audit and Phase 3 consumption.

### Phase 2: Apply changes (up to 3 Opus sub-agents in parallel)

**Pre-flight per change (orchestrator):** before dispatching, the orchestrator checks shipped-immutability:

```bash
if [ "$MODE" = "local" ]; then
  STATUS=$(${CLAUDE_PLUGIN_ROOT}/scripts/parse-local-epic.sh get-status "$TARGET" "$STORY_NUM")
  if [ "$STATUS" = "COMPLETED" ]; then
    SKIPPED+=("story-$STORY_NUM: REFUSED — Status=COMPLETED")
    continue
  fi
else
  STATE=$(gh issue view "#$STORY_NUM" --repo $REPO --json state --jq '.state')
  if [ "$STATE" = "CLOSED" ]; then
    SKIPPED+=("#$STORY_NUM: REFUSED — issue CLOSED")
    continue
  fi
fi
```

Changes targeting `epic-header` (scope, waves, metadata) bypass this check.

**Each apply-change sub-agent:**

```
Task tool:
  model: opus
  max_turns: 40
  description: "Apply improve-design change N: <type> <target>"
  prompt: |
    Change to apply:
      type: $CHANGE_TYPE
      target: $CHANGE_TARGET
      details: $CHANGE_DETAILS

    Mode: $MODE ($TARGET)

    Current section(s) to modify:
    [if MODE=local: extracted via parse-local-epic.sh extract-substory]
    [if MODE=github: fetched via gh issue view for the target issue(s)]

    Relevant references (same shape /design uses):
      Story template:     ${CLAUDE_PLUGIN_ROOT}/skills/product-design/references/story-template.md
      Epic template:      ${CLAUDE_PLUGIN_ROOT}/skills/product-design/references/epic-template.md
      AC guide:           ${CLAUDE_PLUGIN_ROOT}/skills/product-design/references/acceptance-criteria-guide.md
      Story-planner spec: ${CLAUDE_PLUGIN_ROOT}/skills/product-design/references/story-planner-spec.md
      Context budget:     ${CLAUDE_PLUGIN_ROOT}/skills/product-design/references/context-budget.md

    Produce the new/edited section text(s) following the same format conventions as `/design`:
      - Gherkin AC: full Feature/Background/Scenario, ≥3 scenarios, ≥1 [SECURITY]
      - TDD Tasks: exact code, expected outputs, commit messages
      - Mock data included in [FE] bodies
      - i18n in both base + secondary locale files
      - Respect the Execution Context Budget — combined STORY+BE+FE+INT ≤ 90k tok target, hard cap 120k tok. If a split-induced story exceeds the cap, emit SPLIT_NEEDED per the budget reference.

    Write outputs to:
      .claude/runs/improve-<slug>/change-N-new-<target>.md  (replacement content)
      .claude/runs/improve-<slug>/change-N-meta.json        (operation metadata: path_in_file, issue_number_to_edit, issue_numbers_to_close, etc.)

    NEVER ask the user. Use research/SME agents if architectural decisions are needed.
```

Run up to 3 apply-change sub-agents in parallel (match `/design` Phase 4 concurrency).

After all apply-change sub-agents complete, the orchestrator has `change-N-new-*.md` files + `change-N-meta.json` metadata ready for Phase 3.

### Phase 3: Commit changes

**Local mode:**

For each `change-N-meta.json`, apply the new section text to `$TARGET` using the `Edit` tool:

- `ADD_STORY`: append `### Story N+1: ...` block at the end of `## Stories` (before any trailing horizontal rule).
- `REMOVE_STORY`: locate `### Story N:`, remove to the next `### Story` heading. Leave the number hole.
- `SPLIT_STORY`: replace `### Story N:` with two sections (agent provides both).
- `MERGE_STORIES`: replace primary; remove secondary. Leave secondary's number as a hole.
- `EDIT_*`: locate the sub-section via `extract-substory`; replace its body with the new content.
- `RE_WAVE`: edit the `#### Wave Assignments` table in the epic header.
- `EDIT_METADATA`: edit the `**Persona:**  **Priority:**  **Size:**  **Status:**` line.

Update Story Priority Table + Wave Assignments in the epic header to reflect structural changes.

Commit:
```bash
git add "$TARGET"
git commit -m "design: improve epic $(basename $TARGET .md) — $FEEDBACK_SUMMARY"
```

Where `$FEEDBACK_SUMMARY` is a ≤60-char one-line summary (e.g., `split story 5; add [SECURITY] to story 1`).

**GitHub mode:**

For each change:
- `ADD_STORY`: `gh issue create` new `[STORY]` + `[BE]` + `[FE]` + `[INT]` sub-issues. Update EPIC body to reference them.
- `REMOVE_STORY`: `gh issue close <num> --reason not_planned` for STORY + all sub-issues. Do NOT delete. Update EPIC body.
- `SPLIT_STORY`: close original STORY (+ subs) with `not_planned`; create 2 new STORYs + sub-issue families.
- `MERGE_STORIES`: close secondary STORY with `not_planned`; edit primary STORY body to incorporate merged AC/TDD.
- `EDIT_*`: `gh issue edit <num> --body "<new body>"`.
- `RE_WAVE`: update EPIC body's wave assignment table.

Also edit `docs/epics/<slug>.md` summary table to reflect structural changes. Commit the doc change:
```bash
git add docs/epics/
git commit -m "design: improve epic #$TARGET_NUM — $FEEDBACK_SUMMARY"
```

### Phase 4: Re-validate

Automatically invoke `/super-ralph:review-design "$TARGET"` on the updated design:

```
Task tool:
  model: sonnet
  max_turns: 30
  description: "Re-validate after improve-design"
  prompt: |
    Read ${CLAUDE_PLUGIN_ROOT}/commands/review-design.md.
    Follow it for target: $TARGET
    Return the verdict: READY / CONDITIONAL / BLOCKED with findings summary.
```

Capture verdict + findings summary for the final report.

## Final Report

Output this structured report:

```markdown
# Design Improved: $EPIC_TITLE

## Target
$TARGET (mode: $MODE)

## Changes Applied
| # | Type | Target | Result |
|---|------|--------|--------|
[one row per successful change]

## Skipped
| Target | Reason |
|--------|--------|
[one row per skipped change, e.g., REFUSED shipped]

## Re-Validation Verdict
READY | CONDITIONAL | BLOCKED
[findings summary if any]

## Next
[if local: `/super-ralph:build-story $TARGET#story-N` per new/modified story]
[if github: `/super-ralph:build-story #<new-story-num>` per new/modified story]
```

## Critical Rules

- **No silent target guesses.** If neither explicit nor high-confidence fuzzy match, ask the user (or exit with an explicit error).
- **Never modify a story with `**Status:** COMPLETED` (local) or a CLOSED `[STORY]` issue (GitHub).** Refuse the edit — the user must cut a new story.
- **No deletion on GitHub.** Removed stories close with `reason: not_planned`, preserving audit trail.
- **No renumbering.** Leaving holes preserves cross-references.
- **Re-validate after edit.** Phase 4 always runs `/review-design` so the user sees the verdict before deciding to build.
- **No silent feedback guesses.** If the interpreter can't map feedback to a supported change type, return a clarification question and exit.
- **Never ask the user in Phases 1-4.** Only Phase 0a and the interpreter's clarification in Phase 1 are interactive.

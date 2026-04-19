---
name: design-review
description: "Validate design quality of super-ralph epics and stories via gate-driven review. Triggers when /super-ralph:review-design is invoked, or when the user mentions 'review design', 'validate epic', 'check design quality', 'gate check', 'design gates', 'AC coverage', 'story readiness', 'design verdict', or asks whether stories are ready to build. Produces READY / CONDITIONAL / BLOCKED verdict with wave plan when READY."
---

> **Config:** Project-specific values (paths, repo, team) are loaded from `.claude/super-ralph-config.md`.

# Design Review — Gate-Driven Validation

## Overview

Validate design artifacts produced by `/super-ralph:design` against enforcement gates and cross-issue consistency checks. Every EPIC, STORY, BE, FE, and INT issue must pass its gates before any `/super-ralph:build-story` dispatch. The review returns a machine-readable verdict: **READY**, **CONDITIONAL**, or **BLOCKED**.

**Announce at start:** "I'm using the design-review skill to validate the epic against all PM, Developer, and Cross-Issue gates."

**Core insight:** A design review is not subjective critique — it is a deterministic gate-check. Every gate has a pass criterion expressible as a grep pattern or a count. Verdicts drive automation: READY means "build now," CONDITIONAL means "build safe stories now, fix others," BLOCKED means "fix before touching build."

## Modes

| Mode | Input | Detection |
|------|-------|-----------|
| GitHub | `#<epic-number>` or `<epic-number>` | Integer argument |
| Local  | `docs/epics/<slug>.md` | File argument with `<!-- super-ralph: local-mode -->` marker |

Mode detection uses the shared parser:

```bash
MODE=$(${CLAUDE_PLUGIN_ROOT}/scripts/parse-local-epic.sh detect-mode "$EPIC_REF")
```

For **local mode**, every gate reference to "issue number" below substitutes the local anchor `story-N-<kind>`. All gate rules apply unchanged because they are pure text matches on body content.

## Workflow

Execute these steps in order. **Never ask for human input.** All checks are mechanical against defined criteria.

### Step 1: Resolve EPIC

**GitHub mode:**
```bash
gh issue view $EPIC_REF --repo $REPO --json number,title,body,labels,milestone,state
EPIC_DOC=$(gh issue view $EPIC_REF --repo $REPO --json body --jq '.body' \
  | grep -oE 'docs/epics/[a-zA-Z0-9._-]+\.md' | head -1)
```

**Local mode:**
```bash
EPIC_DOC="$EPIC_REF"
grep -q '<!-- super-ralph: local-mode -->' "$EPIC_DOC" \
  || { echo "$EPIC_DOC is not a local-mode epic."; exit 1; }
```

Extract: EPIC title, goal, story list, execution plan (waves, AI-hours), PM Summary (priority table, decision points).

### Step 2: Load All Sub-Issues

**GitHub mode:**
```bash
gh issue list --repo $REPO --state all --json number,title,body,labels \
  --jq "[.[] | select(.body | test(\"Parent:?\\s*#$EPIC_REF\"; \"i\"))]"
```

For each [STORY] issue found, fetch its [BE], [FE], [INT] sub-issues using the same pattern with `$STORY_NUMBER`.

**Local mode:** parse `$EPIC_DOC` using `${CLAUDE_PLUGIN_ROOT}/scripts/parse-local-epic.sh extract-substory` to load each story group.

### Step 2.5: Apply Enforcement Gates

For every issue loaded in Step 2, evaluate the per-issue and context-budget gates defined in `references/gate-catalog.md`.

**Categories (see gate-catalog.md for full tables):**

- **STORY Gates** — STORY-G1 (User Journey), STORY-G2 (≥3 Gherkin scenarios incl. [SECURITY]), STORY-G3 (sub-issue refs)
- **[BE] Gates** — BE-G1 (TDD Tasks section), BE-G2 (progress checks, no placeholders)
- **[FE] Gates** — FE-G1 (Mock Data section), FE-G2 (CP1-CP4 checkpoints)
- **[INT] Gates** — INT-G1 (Gherkin reference to parent), INT-G2 (Verification with `/super-ralph:verify`)
- **Context Budget Gates (CTX-G1..G3)** — body size caps, combined cap, file-ref count cap. See also `../product-design/references/context-budget.md`.

Emit **BLOCKED** verdict for any hard-cap failure. Collect all failures before returning.

**Gate evaluation loop (example — full example in gate-catalog.md):**

```bash
STORY_BODY=$(gh issue view $STORY_NUMBER --repo $REPO --json body --jq '.body')

if ! echo "$STORY_BODY" | grep -q "^## User Journey"; then
  FAILURES+=("STORY-G1: #$STORY_NUMBER missing User Journey narrative")
fi

# CTX-G1 / CTX-G2: Context budget audit per story group
STORY_CHARS=$(echo "$STORY_BODY" | wc -c | tr -d ' ')
[ "$STORY_CHARS" -gt 120000 ] && FAILURES+=("CTX-G1: #$STORY_NUMBER STORY body $STORY_CHARS chars exceeds 120,000 cap")
# ...BE, FE, INT char counts, combined cap — see gate-catalog.md
```

### Step 3: Dispatch Per-Story Review Agents (parallel)

For each STORY (with its BE/FE/INT sub-issues), dispatch a review agent. Run all in parallel.

```
Task tool:
  model: sonnet
  max_turns: 20
  description: "Review Story #<STORY_NUMBER>: <Title>"
  prompt: |
    You are a design-review agent. Review one story and its sub-issues for quality.

    ## Story to Review
    ### [STORY] Issue #<STORY_NUMBER>
    <PASTE FULL STORY ISSUE BODY>
    ### [BE] Issue #<BE_NUMBER>
    <PASTE FULL BE ISSUE BODY>
    ### [FE] Issue #<FE_NUMBER>
    <PASTE FULL FE ISSUE BODY>

    ## Review Checklist
    Run every check below. For each, report: PASS, FAIL, or N/A with a one-line explanation.

    ### PM Gates
    | ID | Check | Pass Criteria |
    |----|-------|---------------|
    | PM-1 | Persona specificity | Uses a specific persona from product vision, NOT generic "user" |
    | PM-2 | Measurable outcome | "So that" clause is measurable/observable, not "I can do X" |
    | PM-3 | AC coverage | ≥3 Gherkin scenarios: 1 happy + 1 error/validation + 1 edge |
    | PM-4 | Gherkin format | Every AC uses full Feature/Background/Scenario format |
    | PM-5 | Concrete values | AC uses specific numbers/strings, not vague terms |
    | PM-6 | Independent story | Buildable without other stories, or dependencies declared |

    ### Developer Gates — BE Sub-Issue
    | ID | Check | Pass Criteria |
    |----|-------|---------------|
    | BE-1 | Task 0 is e2e | First TDD task creates e2e test from AC (outer RED) |
    | BE-2 | No pseudocode | No placeholders, no "...", no "TODO" — all code exact |
    | BE-3 | Exact file paths | Every file ref uses repo-relative paths |
    | BE-4 | Expected output | Every Run command has expected output (PASS/FAIL, counts) |
    | BE-5 | Shared file protocol | Shared-file mods use append-only with section markers |
    | BE-6 | Commit messages | Every TDD task ends with exact `git commit -m "..."` |
    | BE-7 | Completion criteria | Machine-verifiable section with runnable commands |

    ### Developer Gates — FE Sub-Issue
    | ID | Check | Pass Criteria |
    |----|-------|---------------|
    | FE-1 | Task 0 is e2e | First TDD task creates/extends e2e test |
    | FE-2 | No pseudocode | All code blocks exact |
    | FE-3 | Exact file paths | Repo-relative paths only |
    | FE-4 | Expected output | Every Run command has expected output |
    | FE-5 | Shared file protocol | Append-only with section markers |
    | FE-6 | Commit messages | Exact commit commands |
    | FE-7 | Completion criteria | Machine-verifiable section |
    | FE-8 | i18n coverage | Both primary and secondary i18n files have entries |
    | FE-9 | Mock data | Mock data file exists for concurrent dev |
    | FE-10 | PM checkpoints | CP1-CP4 defined with verification criteria |

    ### Shared Contract Gates
    | ID | Check | Pass Criteria |
    |----|-------|---------------|
    | SC-1 | Types defined | STORY Shared Contract section defines TS interfaces/types |
    | SC-2 | BE/FE alignment | BE route types match FE API client types |
    | SC-3 | Complete types | All fields have explicit types (no bare `any`) |

    ## Output Format
    Return per-gate PASS/FAIL tables + a Findings list classified [CRITICAL]/[IMPORTANT]/[MINOR].
    NEVER ask for human input.
```

### Step 4: Cross-Issue Checks

After all per-story reviews complete, run cross-issue consistency checks inline (no sub-agent). Definitions in `references/gate-catalog.md`:

- **CX-1** Shared File Conflicts — 2+ BE/FE sub-issues modifying the same section
- **CX-2** Dependency DAG Cycle-Free — no circular dependencies, valid wave ordering
- **CX-3** AC-to-Test 1:1 Coverage — every Gherkin scenario has ≥1 test case
- **CX-4** Wave Plan Consistency — P0 in Wave 1-2, P1 in Wave 1-3, no wave-before-dep
- **CX-5** Epic Doc and GitHub Issues in Sync — same story counts, titles, priorities

### Step 5: Classify Findings

| Severity | Definition | Impact on Verdict |
|----------|-----------|-------------------|
| **Critical** | Build blocker — story cannot be built autonomously | Blocks READY |
| **Important** | Quality issue — story can be built but result may be wrong | Blocks READY if `--strict` |
| **Minor** | Style or preference — does not affect buildability | Does not block READY |

### Step 6: Auto-Fix (if `--fix`)

If `--fix` is passed, apply conservative fixes only:

**Safe to auto-fix:**
- Missing i18n rows — mirror primary into secondary
- Placeholder comments (`// ...`) → exact code
- Missing section markers → add `// ─── [Feature] ────`
- Missing commit messages → add exact `git commit -m "..."`
- `#??` placeholders in EPIC body → real issue numbers

**NEVER auto-fix:**
- Gherkin AC (requirements risk)
- TDD task code (test-logic risk)
- Shared Contract types (BE/FE mismatch risk)
- Story scope or priority (PM decision)
- Dependency graph (architectural decision)

**Process:**
1. Apply fix via `gh issue edit <number> --body "<fixed>"` (GitHub) or Edit against `$EPIC_DOC` sub-section (local)
2. Commit epic-doc fixes: `git add $EPIC_DOC && git commit -m "fix(design): [what was fixed]"`
3. Mark the finding as FIXED in the report

### Step 7: Verdict

| Condition | Verdict |
|-----------|---------|
| 0 Critical AND 0 Important | **READY** — output wave plan with launch commands |
| CTX soft-warn only (combined 360k-480k chars) | **CONDITIONAL** — allow ship with warning |
| Some stories clean, some Critical | **CONDITIONAL** — list safe stories + blocked stories |
| Any Critical, or CTX hard-cap violation | **BLOCKED** — list all findings, recommend re-run after fixes |

### READY verdict output

```markdown
## Verdict: READY

### Wave Plan
#### Wave 1 (start immediately, parallel)
| Story | Command | AI-Hours |
|-------|---------|----------|
| Story 1: [Title] | `/super-ralph:build-story <target>` | Xh |
| Story 3: [Title] | `/super-ralph:build-story <target>` | Yh |

**Total AI-Hours:** Zh
**Critical Path:** Story 1 --> Story 2 (Xh)
```

`<target>` resolves to `#<issue-number>` (GitHub) or `docs/epics/<slug>.md#story-N` (local).

### CONDITIONAL verdict output

```markdown
## Verdict: CONDITIONAL
### Can Start Now
| Story | Command | AI-Hours |
### Blocked — Needs Fixes
| Story | Blocker | Fix Required |
### Recommended Action
Fix blocked stories, then re-run: `/super-ralph:review-design <EPIC_NUMBER>`
```

### BLOCKED verdict output

```markdown
## Verdict: BLOCKED
No stories can start. The following Critical findings must be resolved:
| # | Finding | Story | Fix Required |
### Recommended Action
Fix all Critical findings, then re-run.
```

## Full Report Structure

```markdown
# Design Review: [EPIC Title] (#<EPIC_NUMBER>)

## Summary
| Metric | Value |
|--------|-------|
| Stories reviewed | N |
| Total checks run | N |
| Critical findings | N |
| Important findings | N |
| Minor findings | N |
| Auto-fixed (if --fix) | N |

## Per-Story Results
[PM/BE/FE/SC gate tables per story]

## Cross-Issue Checks
[CX-1..CX-5 table]

## Gate Summary
[STORY-G, BE-G, FE-G, INT-G, CTX-G per issue — see gate-catalog.md]

## Findings Summary
### Critical (build blockers)
### Important (quality issues)
### Minor (style)

## Verdict: [READY / CONDITIONAL / BLOCKED]
[Wave plan with launch commands, OR list of fixes needed]
```

## Critical Rules

- **NEVER ask for input.** All checks are mechanical.
- **Parallel review agents.** One Sonnet per story, all in parallel. Cross-issue checks run inline after.
- **Conservative auto-fix.** Only safe items (i18n, placeholders, section markers). NEVER rewrite AC, TDD code, types, or scope.
- **Severity is objective.** Critical = build blocker. Important = quality gap. Minor = style preference.
- **Wave plan in READY verdict.** Output exact `/super-ralph:build-story` commands in wave order so the user can start building immediately.
- **Re-run after fixes.** If findings are fixed, re-run `/super-ralph:review-design` to confirm the verdict changes.

## References

- `references/gate-catalog.md` — Full catalog of STORY-G, BE-G, FE-G, INT-G, CTX-G, CX-x gates with exact grep/check patterns
- `../product-design/references/context-budget.md` — Context-budget model that CTX gates enforce
- `../product-design/references/story-template.md` — Shape of a well-formed STORY body (gates check against this)
- `../product-design/references/acceptance-criteria-guide.md` — Gherkin format and coverage patterns

### Sibling skills
- `../product-design/SKILL.md` — Produces the designs this skill reviews
- `../issue-management/SKILL.md` — Issue taxonomy this skill validates against

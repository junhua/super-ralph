---
name: review-design
description: "Validate design quality — review EPIC stories, AC, TDD tasks, shared contracts, and cross-issue consistency"
argument-hint: "<EPIC_NUMBER> [--fix] [--strict]"
allowed-tools: ["Bash(gh:*)", "Bash(git:*)", "Read", "Write", "Edit", "Glob", "Grep", "Task"]
---

# Super-Ralph Review-Design Command

Validate the quality of a design produced by `/super-ralph:design`. Reviews EPIC stories, Gherkin acceptance criteria, TDD tasks, shared contracts, and cross-issue consistency. Returns a structured verdict: READY, CONDITIONAL, or BLOCKED.

## Arguments

Parse the user's input for:
- **EPIC_NUMBER** (required): The GitHub issue number of the `[EPIC]` to review (e.g., `#123` or `123`)
- **--fix** (optional): Auto-fix conservative issues (missing i18n rows, placeholder comments). Default: report only.
- **--strict** (optional): Treat Important findings as Critical (blocks READY verdict). Default: false.

## Workflow

Execute these steps in order. **Do NOT ask the user for input at any point.** All decisions are autonomous.

---

### Step 0: Load Project Config

Read `.claude/super-ralph-config.md` to load project-specific values. If the file does not exist, first attempt auto-init by invoking the init command logic, then tell the user to run `/super-ralph:init` manually if auto-init fails.

Extract these values for use in all subsequent steps:
- `$REPO` — GitHub repo (e.g., `Forth-AI/work-ssot`)
- `$ORG` — GitHub org
- `$PROJECT_NUM` — Project board number (or `none`)
- `$PROJECT_ID` — Project board GraphQL ID
- `$STATUS_FIELD_ID` — Status field ID
- `$STATUS_TODO` / `$STATUS_IN_PROGRESS` / `$STATUS_PENDING_REVIEW` / `$STATUS_SHIPPED`
- `$BE_DIR` — Backend directory
- `$SCHEMA_FILE` — Schema file path
- `$ROUTE_REG_FILE` — Route registration file
- `$BE_SERVICES_DIR` — Services directory
- `$BE_ROUTES_DIR` — Routes directory
- `$BE_TEST_CMD` — Backend test command
- `$FE_DIR` — Frontend directory
- `$TYPES_FILE` — Types file path
- `$API_CLIENT_DIR` — API client directory
- `$I18N_BASE_FILE` — Primary i18n file
- `$I18N_SECONDARY_FILE` — Secondary i18n file (may be blank)
- `$FE_PAGES_DIR` — Pages directory
- `$FE_COMPONENTS_DIR` — Components directory
- `$FE_TEST_CMD` — Frontend test command
- `$APP_URL` — Production app URL
- `$RUNTIME` — Runtime (bun/node)

---

### Step 1: Resolve EPIC

Fetch the EPIC issue and locate the epic document.

```bash
# Fetch EPIC issue
gh issue view $EPIC_NUMBER --repo $REPO --json number,title,body,labels,milestone,state

# Extract epic doc path from issue body
EPIC_DOC=$(gh issue view $EPIC_NUMBER --repo $REPO --json body --jq '.body' \
  | grep -oE 'docs/epics/[a-zA-Z0-9._-]+\.md' | head -1)
```

Read the EPIC issue body and the epic document file. Extract:
- EPIC title and goal
- Story list with issue numbers
- Execution plan (waves, AI-hours)
- PM Summary (priority table, decision points)

---

### Step 2: Load All Sub-Issues

Fetch all sub-issues (STORYs + FE/BE subs) linked to this EPIC.

```bash
# List all issues that reference this EPIC as parent
gh issue list --repo $REPO --state all --json number,title,body,labels \
  --jq "[.[] | select(.body | test(\"Parent:?\\s*#$EPIC_NUMBER\"; \"i\"))]"
```

For each [STORY] issue found, also fetch its [BE] and [FE] sub-issues:

```bash
# For each STORY_NUMBER
gh issue list --repo $REPO --state all --json number,title,body,labels \
  --jq "[.[] | select(.body | test(\"Parent:?\\s*#$STORY_NUMBER\"; \"i\"))]"
```

Build a complete issue tree:

```
EPIC #N
├── STORY #A
│   ├── [BE] #B
│   └── [FE] #C
├── STORY #D
│   ├── [BE] #E
│   └── [FE] #F
└── ...
```

---

### Step 2.5: Apply Enforcement Gates

For every issue loaded in Step 2, evaluate these gates in order. Emit **BLOCKED** verdict for any failure. Collect all failures before returning.

#### STORY Gates

| Gate | Rule | How to check |
|------|------|--------------|
| STORY-G1 | Body contains `## User Journey` (or `## User Journey (narrative)`) section | `grep -q "^## User Journey" <body>` |
| STORY-G2 | Body contains Gherkin block with ≥3 scenarios AND at least one line matching `Scenario: \[SECURITY\]` | `grep -c "^  Scenario:" <gherkin_block>` ≥ 3 AND `grep -q "Scenario: \[SECURITY\]"` |
| STORY-G3 | Body lists 3 sub-issues: `[BE] #N`, `[FE] #N`, `[INT] #N` | regex each label present in `## Sub-Issues` block |

#### [BE] Gates

| Gate | Rule | How to check |
|------|------|--------------|
| BE-G1 | Body contains `## TDD Tasks` section | `grep -q "^## TDD Tasks" <body>` |
| BE-G2 | TDD Tasks contain at least 2 `**Progress check:**` lines AND no disallowed placeholders | `grep -c "Progress check:" <body>` ≥ 2 AND `! grep -E "(TODO|\.\.\.|implement X here)" <body>` |

#### [FE] Gates

| Gate | Rule | How to check |
|------|------|--------------|
| FE-G1 | Body contains `## Mock Data` section | `grep -q "^## Mock Data" <body>` |
| FE-G2 | Body contains `## PM Checkpoints` with 4 checkpoints (CP1, CP2, CP3, CP4) | `grep -c "CP[1-4]" <body>` ≥ 4 |

#### [INT] Gates

| Gate | Rule | How to check |
|------|------|--------------|
| INT-G1 | Body contains `## Gherkin User Journey` referencing parent story | `grep -q "^## Gherkin User Journey" <body>` AND `grep -q "See parent #" <body>` |
| INT-G2 | Body contains `## Verification Tasks` with `/super-ralph:verify` invocation | `grep -q "/super-ralph:verify" <body>` |

#### Gate Evaluation Example

For each STORY in the epic:
```bash
STORY_BODY=$(gh issue view $STORY_NUMBER --repo $REPO --json body --jq '.body')

# STORY-G1
if ! echo "$STORY_BODY" | grep -q "^## User Journey"; then
  FAILURES+=("STORY-G1: #$STORY_NUMBER missing User Journey narrative")
fi

# STORY-G2
SCENARIO_COUNT=$(echo "$STORY_BODY" | grep -c "^  Scenario:" || echo 0)
HAS_SECURITY=$(echo "$STORY_BODY" | grep -c "Scenario: \[SECURITY\]" || echo 0)
if [ "$SCENARIO_COUNT" -lt 3 ] || [ "$HAS_SECURITY" -lt 1 ]; then
  FAILURES+=("STORY-G2: #$STORY_NUMBER has $SCENARIO_COUNT scenarios, [SECURITY]=$HAS_SECURITY (need ≥3 and ≥1 SECURITY)")
fi

# STORY-G3
if ! echo "$STORY_BODY" | grep -q "\[INT\] #"; then
  FAILURES+=("STORY-G3: #$STORY_NUMBER missing [INT] sub-issue reference")
fi

# ... repeat for BE, FE, INT issues
```

#### Verdict Logic

- Any gate failure → **BLOCKED** (list all failures in report)
- No failures → continue to existing Steps 3+
- With `--strict`: treat `[PERF]` missing as BLOCKED as well
- With `--fix`: auto-append missing sections using templates (experimental, default off)

---

### Step 3: Dispatch Per-Story Review Agents (parallel)

For each STORY (and its BE/FE sub-issues), dispatch a review agent. Run all in parallel.

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
    | PM-1 | Persona specificity | Story uses a specific persona from the product vision, NOT generic "user" or "someone" |
    | PM-2 | Measurable outcome | "So that" clause contains a measurable or observable result, not "I can do X" |
    | PM-3 | AC coverage | At least 3 Gherkin scenarios: 1 happy path + 1 error/validation + 1 edge case |
    | PM-4 | Gherkin format | Every AC uses full Gherkin: Feature / Background / Scenario (not abbreviated Given/When/Then) |
    | PM-5 | Concrete values | AC uses specific numbers and strings ("3 items", "within 2 seconds"), not vague terms ("some", "quickly") |
    | PM-6 | Independent story | This story can be built without requiring other stories to be complete first (or dependencies are explicitly declared) |

    ### Developer Gates — BE Sub-Issue

    | ID | Check | Pass Criteria |
    |----|-------|---------------|
    | BE-1 | Task 0 is e2e | First TDD task creates e2e test from AC (outer RED) |
    | BE-2 | No pseudocode | No "implement X here", no "...", no "TODO" — all code blocks are exact and complete |
    | BE-3 | Exact file paths | Every file reference uses repo-relative paths (e.g., `$BE_SERVICES_DIR/foo.ts`) |
    | BE-4 | Expected output | Every `Run:` or `bun test` command has an expected output (PASS/FAIL, counts) |
    | BE-5 | Shared file protocol | Modifications to shared files ($SCHEMA_FILE, $ROUTE_REG_FILE, test-helpers.ts) use append-only with section markers |
    | BE-6 | Commit messages | Every TDD task ends with an exact `git commit -m "..."` command |
    | BE-7 | Completion criteria | Issue has a machine-verifiable completion criteria section with runnable commands |

    ### Developer Gates — FE Sub-Issue

    | ID | Check | Pass Criteria |
    |----|-------|---------------|
    | FE-1 | Task 0 is e2e | First TDD task creates/extends e2e test (outer RED) |
    | FE-2 | No pseudocode | No "implement X here", no "...", no "TODO" — all code blocks are exact and complete |
    | FE-3 | Exact file paths | Every file reference uses repo-relative paths (e.g., `$FE_PAGES_DIR/foo/page.tsx`) |
    | FE-4 | Expected output | Every `Run:` or `bun test` command has an expected output (PASS/FAIL, counts) |
    | FE-5 | Shared file protocol | Modifications to shared files ($TYPES_FILE, i18n) use append-only with section markers |
    | FE-6 | Commit messages | Every TDD task ends with an exact `git commit -m "..."` command |
    | FE-7 | Completion criteria | Issue has a machine-verifiable completion criteria section |
    | FE-8 | i18n coverage | Both `$I18N_BASE_FILE` and `$I18N_SECONDARY_FILE` entries are present with complete translations |
    | FE-9 | Mock data | Mock data file exists for concurrent development without BE dependency |
    | FE-10 | PM checkpoints | CP1-CP4 checkpoints are defined with clear verification criteria |

    ### Shared Contract Gate

    | ID | Check | Pass Criteria |
    |----|-------|---------------|
    | SC-1 | Types defined | Shared Contract section in STORY issue defines TypeScript interfaces/types |
    | SC-2 | BE/FE alignment | Types used in BE routes match types used in FE API client |
    | SC-3 | Complete types | All fields have explicit types (no `any`, no `unknown` unless justified) |

    ## Output Format

    Return a structured report:

    ```markdown
    ## Story #<N>: <Title>

    ### PM Gates
    | ID | Result | Detail |
    |----|--------|--------|
    | PM-1 | PASS/FAIL | [one-line explanation] |
    ...

    ### BE Gates
    | ID | Result | Detail |
    |----|--------|--------|
    | BE-1 | PASS/FAIL | [one-line explanation] |
    ...

    ### FE Gates
    | ID | Result | Detail |
    |----|--------|--------|
    | FE-1 | PASS/FAIL | [one-line explanation] |
    ...

    ### Shared Contract Gates
    | ID | Result | Detail |
    |----|--------|--------|
    | SC-1 | PASS/FAIL | [one-line explanation] |
    ...

    ### Findings
    - [CRITICAL] [ID]: [description of what's wrong and how to fix it]
    - [IMPORTANT] [ID]: [description]
    - [MINOR] [ID]: [description]
    ```

    NEVER ask for human input. Base all judgments on the checklist criteria above.
```

---

### Step 4: Cross-Issue Checks (orchestrator, inline)

After all per-story review agents complete, run cross-issue consistency checks inline (no sub-agent needed).

#### CX-1: Shared File Conflicts

Check if 2+ BE sub-issues modify the same section of a shared file:

```
Shared files to check:
- $SCHEMA_FILE — section markers
- $ROUTE_REG_FILE — route registration
- $BE_DIR/src/db/test-helpers.ts — table registration
- $TYPES_FILE — type sections
- $I18N_BASE_FILE — feature keys
- $I18N_SECONDARY_FILE — feature keys
```

For each shared file, scan all BE/FE sub-issue bodies. If 2+ issues modify the same section marker:
- **PASS** if they append to the END of different sections
- **FAIL** if they modify the SAME section (conflict risk)
- **FAIL** if they insert in the middle (protocol violation)

#### CX-2: Dependency DAG Cycle-Free

Parse the EPIC body's dependency graph. Verify:
- No circular dependencies (A depends on B depends on A)
- All referenced story numbers exist in the EPIC
- Wave assignments respect dependencies (no story in Wave N depends on a story in Wave N+1)

#### CX-3: AC-to-Test 1:1 Coverage

For each STORY, count:
- Number of Gherkin scenarios in the AC section
- Number of test cases in the e2e test skeleton (STORY) + Task 0 tests (BE + FE)

**PASS** if test count >= scenario count.
**FAIL** if any scenario has no corresponding test case.

#### CX-4: Wave Plan Consistency

Verify the EPIC's wave assignments match priority:
- All P0 stories must be in Wave 1 or Wave 2 (never Wave 3+)
- All P1 stories must be in Wave 1, 2, or 3
- P2 stories can be in any wave
- No story is assigned to a wave before its dependencies

#### CX-5: Epic Doc and GitHub Issues in Sync

Compare the epic document (`docs/epics/*.md`) with the EPIC GitHub issue:
- Same number of stories in both
- Same story titles in both
- Same priority assignments in both
- Issue numbers in EPIC body are not `#??` placeholders

---

### Step 5: Classify Findings

Aggregate all findings from per-story reviews (Step 3) and cross-issue checks (Step 4). Classify each:

| Severity | Definition | Impact on Verdict |
|----------|-----------|-------------------|
| **Critical** | Build blocker — story cannot be built autonomously. Examples: missing e2e Task 0, pseudocode in TDD tasks, no completion criteria, shared file conflict, dependency cycle | Blocks READY |
| **Important** | Quality issue — story can be built but result may be wrong. Examples: missing i18n, vague AC values, incomplete mock data, weak persona | Blocks READY if `--strict` |
| **Minor** | Style or preference — does not affect buildability. Examples: could use a better commit message, verbose comments | Does not block READY |

---

### Step 6: Auto-Fix (if --fix)

If `--fix` is passed, apply conservative fixes only:

**Safe to auto-fix:**
- Missing i18n rows — add the `[feature]` key to `$I18N_SECONDARY_FILE` mirroring the `$I18N_BASE_FILE` structure
- Placeholder comments in code blocks — replace `// ...` with actual implementation code
- Missing section markers — add `// ─── [Feature] ────` to shared file instructions
- Missing commit messages — add `git commit -m "..."` to TDD tasks
- `#??` placeholders in EPIC body — replace with actual issue numbers

**NEVER auto-fix:**
- Gherkin acceptance criteria (risk of changing requirements)
- TDD task code (risk of breaking test logic)
- Shared Contract types (risk of BE/FE mismatch)
- Story scope or priority (PM decision)
- Dependency graph (architectural decision)

**Process:**
1. For each auto-fixable finding, edit the GitHub issue body:
   ```bash
   gh issue edit <number> --body "<fixed body>" --repo $REPO
   ```
2. If the fix involves the epic doc, edit the file and commit:
   ```bash
   git add docs/epics/<file>
   git commit -m "fix(design): [what was fixed]"
   ```
3. Mark the finding as FIXED in the report

---

### Step 7: Verdict

Based on classified findings, determine the verdict:

#### READY — 0 Critical, 0 Important (or 0 Critical with --fix applied to all Important)

All stories can be built autonomously. Output the wave plan with launch commands:

```markdown
## Verdict: READY

All stories pass PM and Developer gates. No cross-issue conflicts detected.

### Wave Plan

#### Wave 1 (start immediately, parallel)
| Story | Command | AI-Hours |
|-------|---------|----------|
| Story 1: [Title] | `/super-ralph:build-story #<N>` | Xh |
| Story 3: [Title] | `/super-ralph:build-story #<N>` | Yh |

#### Wave 2 (after Wave 1 completes)
| Story | Command | AI-Hours |
|-------|---------|----------|
| Story 2: [Title] | `/super-ralph:build-story #<N>` | Xh |

#### Wave 3 (after Wave 2 completes)
| Story | Command | AI-Hours |
|-------|---------|----------|
| Story 4: [Title] | `/super-ralph:build-story #<N>` | Xh |

**Total AI-Hours:** Zh
**Critical Path:** Story 1 --> Story 2 (Xh)
```

#### CONDITIONAL — Some stories pass, others have Critical findings

Some stories can start while others need fixes:

```markdown
## Verdict: CONDITIONAL

### Can Start Now
| Story | Command | AI-Hours |
|-------|---------|----------|
| Story 1: [Title] | `/super-ralph:build-story #<N>` | Xh |

### Blocked — Needs Fixes
| Story | Blocker | Fix Required |
|-------|---------|--------------|
| Story 2: [Title] | BE-2: pseudocode in Task 2 | Replace placeholder with exact implementation code |

### Recommended Action
Fix blocked stories, then re-run: `/super-ralph:review-design <EPIC_NUMBER>`
```

#### BLOCKED — Critical findings prevent any story from starting

```markdown
## Verdict: BLOCKED

No stories can start. The following Critical findings must be resolved:

| # | Finding | Story | Fix Required |
|---|---------|-------|--------------|
| 1 | CX-2: Dependency cycle | Stories 1,3 | Break cycle by removing dependency of Story 1 on Story 3 |
| 2 | PM-4: No Gherkin format | All stories | Rewrite AC in Feature/Background/Scenario format |

### Recommended Action
Fix all Critical findings, then re-run: `/super-ralph:review-design <EPIC_NUMBER>`
```

---

## Output Format

The full report follows this structure:

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

### Story #A: [Title]

#### PM Gates
| ID | Result | Detail |
|----|--------|--------|
| PM-1 | PASS | Uses "Business Operator" persona |
| PM-2 | PASS | Outcome: "processing time reduced to < 5 minutes" |
| PM-3 | PASS | 4 scenarios: happy + 2 error + 1 edge |
| PM-4 | FAIL | AC uses abbreviated Given/When/Then, not full Gherkin Feature format |
| PM-5 | PASS | Uses concrete values throughout |
| PM-6 | PASS | No undeclared dependencies |

#### BE Gates
| ID | Result | Detail |
|----|--------|--------|
| BE-1 | PASS | Task 0 creates e2e test skeleton |
| BE-2 | FAIL | Task 3 has "// ... implement validation" placeholder |
| ...

#### FE Gates
| ID | Result | Detail |
|----|--------|--------|
| FE-1 | PASS | Task 0 extends e2e test |
| FE-8 | FAIL | zh-CN.ts entries missing |
| ...

#### Shared Contract Gates
| ID | Result | Detail |
|----|--------|--------|
| SC-1 | PASS | Types defined in Shared Contract section |
| ...

---

[Repeat for each story]

---

## Cross-Issue Checks

| ID | Check | Result | Detail |
|----|-------|--------|--------|
| CX-1 | Shared file conflicts | PASS | No overlapping section modifications |
| CX-2 | Dependency DAG cycle-free | PASS | No cycles detected |
| CX-3 | AC-to-test 1:1 coverage | FAIL | Story 2 has 5 AC scenarios but only 3 test cases |
| CX-4 | Wave plan consistency | PASS | P0 in Wave 1-2, P1 in Wave 2-3 |
| CX-5 | Epic doc <-> issues sync | PASS | 8 stories in doc, 8 STORY issues on GitHub |

### Gate Summary
| Issue | Gate | Status |
|-------|------|--------|
| #N [STORY] | STORY-G1..3 | PASS / BLOCKED (reason) |
| #N [BE] | BE-G1..2 | PASS / BLOCKED (reason) |
| #N [FE] | FE-G1..2 | PASS / BLOCKED (reason) |
| #N [INT] | INT-G1..2 | PASS / BLOCKED (reason) |

## Findings Summary

### Critical (build blockers)
1. [BE-2] Story #A: Task 3 has pseudocode placeholder — replace with exact implementation
2. [CX-3] Story #B: 2 AC scenarios have no corresponding test case

### Important (quality issues)
1. [FE-8] Story #A: zh-CN.ts entries missing for [feature] key
2. [PM-4] Story #C: AC not in full Gherkin Feature format

### Minor (style)
1. [BE-6] Story #D: Commit message could be more descriptive

## Verdict: [READY / CONDITIONAL / BLOCKED]

[Wave plan with launch commands, OR list of fixes needed]
```

---

## Critical Rules

- **NEVER ask for input.** All checks are mechanical against defined criteria.
- **Parallel review agents.** Dispatch one Sonnet per story, all in parallel. Only cross-issue checks run sequentially after all agents complete.
- **Conservative auto-fix.** When `--fix` is passed, only fix safe items (i18n, placeholders, section markers). NEVER rewrite AC, TDD code, types, or scope.
- **Severity is objective.** Critical = build blocker (story cannot be autonomously built). Important = quality gap (story can be built but result may be wrong). Minor = style preference.
- **Cross-issue checks catch systemic problems.** Individual story reviews catch per-story issues. Cross-issue checks catch conflicts, cycles, and inconsistencies between stories.
- **Verdict determines next action.** READY = start building. CONDITIONAL = start safe stories, fix blocked ones. BLOCKED = fix everything first.
- **Wave plan in READY verdict.** When the design is ready, output the exact `/super-ralph:build-story` commands in wave order so the user can start building immediately.
- **Re-run after fixes.** If findings are fixed (manually or via --fix), the user should re-run `/super-ralph:review-design` to confirm the verdict changes.

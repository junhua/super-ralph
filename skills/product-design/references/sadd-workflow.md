# SADD Workflow Reference

> Canonical reference for the 6-phase SADD flow executed by `/super-ralph:design`.
> The skill body points here; this file holds the full procedure.

## Phase 0 — Config Load

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

## Phase 1 — Context Gathering

Gather all project and codebase context needed to inform the design.

### Step 1: Load Skills

Invoke the `super-ralph:product-design` and `super-ralph:issue-management` skills. Follow their instructions for epic structure, story format, acceptance criteria, and issue taxonomy.

### Step 2: Read Product Documentation

Read product documentation to understand vision, architecture, and current state:

1. Read `docs/vision.md` — product vision, target users, core principles, non-goals
2. Read `docs/roadmap.md` — current phase, what's done, what's planned
3. Read `docs/architecture.md` — system boundaries, services, tech stack
4. Read `docs/brand-cn.md` (if exists) — terminology glossary, bilingual considerations
5. Read `CLAUDE.md` — project conventions, development patterns

### Step 3: Explore Codebase

Use Glob and Grep to understand the current implementation landscape:

1. **Schema:** Read `$SCHEMA_FILE` — existing tables, enums, section markers (`// ─── [Feature] ────`)
2. **Routes:** Read `$ROUTE_REG_FILE` — registered route blocks in the protected routes section
3. **Services:** Glob `$BE_SERVICES_DIR/*.ts` — existing service patterns, method signatures
4. **Pages:** Glob `$FE_PAGES_DIR/**/{page,layout}.tsx` — existing page directories and structure
5. **i18n:** Read `$I18N_BASE_FILE` — existing feature keys and namespace structure
6. **Types:** Read `$TYPES_FILE` — existing type sections and section markers
7. **Existing epics:** Glob `docs/epics/*.md` — prior epic patterns
8. **Existing plans:** Glob `docs/plans/*.md` — prior plan patterns

---

## Phase 2 — Research (3 parallel sub-agents)

### Step 4: Dispatch Research Agents

Launch three agents in parallel via the Task tool:

1. **Dispatch research-agent** (Task tool, model: haiku, max_turns: 15):
   ```
   prompt: |
     Research best practices, UX patterns, and competitor approaches for:
     [FEATURE DESCRIPTION]

     Search the web for:
     - Enterprise SaaS UX patterns for this type of feature
     - Competitor implementations (if applicable)
     - Known pitfalls and anti-patterns
     - Accessibility and i18n considerations

     Search the codebase for:
     - Existing related code, tests, and data models
     - Similar features already implemented
     - Shared components that could be reused

     Return findings as a structured list with source URLs.
   ```

2. **Dispatch sme-brainstormer-1** (Task tool, model: sonnet, max_turns: 15):
   ```
   prompt: |
     You are a product design expert. Brainstorm the user experience for:
     [FEATURE DESCRIPTION]

     Focus on:
     - What stories would delight the target personas?
     - What are the key user journeys end-to-end?
     - What is P0 (must-have MVP) vs P1 (should-have) vs P2 (nice-to-have)?
     - What should be EXPLICITLY excluded from scope and why?

     Product context:
     [PASTE VISION SUMMARY + ROADMAP SUMMARY]

     Return a prioritized story list with rationale for each priority level.
   ```

3. **Dispatch sme-brainstormer-2** (Task tool, model: sonnet, max_turns: 15):
   ```
   prompt: |
     You are a technical architect. Analyze risks and dependencies for:
     [FEATURE DESCRIPTION]

     Focus on:
     - What existing capabilities are prerequisites?
     - What shared files will need modification? (schema.ts, types.ts, i18n, index.ts)
     - What could block implementation? What has tight coupling?
     - What are the schema migration risks?
     - What state machines or complex flows are needed?

     Codebase context:
     [PASTE SCHEMA SUMMARY + ROUTES SUMMARY + SERVICES SUMMARY]

     Return a dependency map and risk assessment.
   ```

### Step 5: Synthesize Findings

Merge outputs from all three agents into a unified design brief:
- Prioritized story candidates
- Scope boundaries (in/out)
- Technical constraints and dependencies
- Risk mitigations
- Reusable components identified

---

## Phase 3 — Epic Definition

### Step 6: Define Epic

Based on synthesized research, define the epic with these sections:

| Section | Content |
|---------|---------|
| Business Context | Why this epic exists, what problem it solves (2-3 sentences) |
| Success Metrics | Measurable outcomes table (Metric / Current / Target / How to Measure) |
| Personas | Who benefits and how (from product vision, never generic "user") |
| Scope — In | Capabilities this epic delivers (bulleted) |
| Scope — Out | Explicitly excluded with rationale (bulleted) |
| Dependencies | What must exist before this epic can start (table) |
| Risks | Risk / Impact / Likelihood / Mitigation (table) |

### Step 7: Apply SLICE Decomposition

Decompose the feature into stories using the SLICE framework:

| Letter | Principle | Rule |
|--------|-----------|------|
| **S** | System boundary | BE+FE in one user action = 1 story |
| **L** | Lifecycle stage | Each CRUD operation = candidate story |
| **I** | Interaction type | List / detail / form / action = separate stories |
| **C** | Configuration vs operation | Admin workflows ≠ operator workflows = separate stories |
| **E** | Error surface | >3 distinct error modes = split error-handling story |

**Additional decomposition rules:**

- One schema migration = one story (never split a migration across stories)
- One state machine = one story (keep state logic atomic)
- List view ≠ detail view (always separate stories)
- Target S or M size stories — L is acceptable, XL must split
- Aim for 8-15 stories per epic (fewer = epic too small, more = split into multiple epics)
- Every story must be independently buildable via `/super-ralph:build-story`
- **Context budget split (see `context-budget.md`):** pre-estimate each story's build-time footprint — sum of BE/FE/INT body sizes it will need + LOC of existing files a build agent must read to understand patterns (schema file, nearest pattern service, nearest pattern route, nearest pattern page, i18n files). If that estimate exceeds **~90,000 tokens** (≈ 360,000 chars, ≈ ~9,000 LOC combined), the story MUST be split — even if its AI-hours size says "M". Common culprits: touching >2 existing tables, >3 existing services, or editing large pages (>500 LOC) in place.

**Output:** Ordered story list with: title, persona, action, outcome, priority (P0/P1/P2), size (S/M/L).

### Step 8: Write Epic Doc

1. Create `docs/epics/` directory if it does not exist
2. Write the epic document to `docs/epics/YYYY-MM-DD-<slug>.md` using the template from `${CLAUDE_PLUGIN_ROOT}/skills/product-design/references/epic-template.md`
3. **If `--local` is set**, insert `<!-- super-ralph: local-mode -->` as the second line of the file (right after the `# EPIC: <title>` heading). Downstream commands use this marker to discriminate local vs GitHub epics.
4. Include all stories with their Gherkin AC (written in Phase 4, but the epic doc structure is defined here)
5. Commit:
   ```bash
   if [ -n "$LOCAL_FLAG" ]; then
     git add docs/epics/<file>
     git commit -m "epic: [title] (local-mode draft)"
   else
     git add docs/epics/<file>
     git commit -m "epic: [title]"
   fi
   ```

---

## Phase 4 — Story Planning

See `story-planner-spec.md` for the full Phase 4 Step 9 sub-agent dispatch and output contracts.
See `execution-planning.md` for Steps 10, 10.5 (audit), and 11 (wave plan).

### Phase 4b: Brief Story Planning (only when `--brief` is set)

When `$BRIEF_FLAG = true`, replace the Phase 4 story-planner dispatch with the brief-story-planner dispatch below. Skip Steps 10.5 (context-budget audit) — brief bodies are trivially under budget. Step 11 (wave assignment) still runs normally.

**Brief story-planner sub-agent (parallel, 1 sonnet per story, max 4 concurrent):**

```
Task tool:
  model: sonnet
  max_turns: 15
  description: "Brief plan Story N: [Title]"
  prompt: |
    You are a brief-story-planner agent. Produce ONE brief story block for backlog grooming.

    ## Story
    - Title: [TITLE]
    - Persona: [PERSONA]
    - Action: [ACTION]
    - Outcome: [OUTCOME]
    - Priority: [P0|P1|P2]
    - Size: [S|M|L]

    ## Epic Scope
    - In scope: [LIST]
    - Out of scope: [LIST]

    ## Product context
    [Paste 200-word vision/persona summary from Phase 2 synthesis]

    ## Output format

    Write ONLY the markdown block below. No TDD, no shared contract, no implementation detail, no file paths, no code.

    ```
    ### Story [N]: [Title]

    **As a** [persona], **I want** [action], **So that** [outcome].

    **Persona:** [persona]   **Priority:** [P?]   **Size:** [S|M|L]   **Status:** PENDING
    <!-- PR: -->
    <!-- Branch: -->

    #### Acceptance Criteria (Outline)

    - `[HAPPY]` Given [precondition], when [action], then [observable outcome with concrete values].
    - `[EDGE]` Given [boundary condition], when [action], then [graceful handling].
    - `[SECURITY]` Given [unauthorized role], when [action], then [403 / denial message].
    ```

    Rules:
    - Exactly one bullet for each of `[HAPPY]`, `[EDGE]`, `[SECURITY]` (more allowed, but all three labels MUST appear).
    - Each bullet is one sentence combining Given/When/Then with concrete values.
    - Use the specific persona from the vision, never generic "user".
    - No implementation detail (no file paths, no code, no API shapes).
    - No `#### Shared Contract`, `#### Pre-Decided Implementation`, or `#### [BE/FE/INT]` subsections.

    Write output to:
      $(git rev-parse --show-toplevel)/.claude/runs/design-<EPIC_SLUG>/story-<N>-brief.md
      (fallback: /tmp/super-ralph-design-<EPIC_SLUG>/story-<N>-brief.md)

    NEVER ask for human input. Output must be ready to paste directly into the epic file.
```

**Orchestrator consolidation:** after all brief sub-agents complete, read `story-N-brief.md` files and use them as story block content for Step 11b (local mode) or Phase 5 (GitHub mode — see brief-mode branching).

### Skip Step 10.5 in brief mode

Step 10.5 (Context Budget Audit) is SKIPPED entirely when `$BRIEF_FLAG = true`. Brief bodies (typically 500-1000 chars) cannot red-line the budget. Write a minimal budget report to `.claude/runs/design-<slug>/context-budget.md`:

```markdown
# Context Budget Report (brief mode)

Brief design — no budget audit performed. Bodies are STORY-only, < 2 KB each.
Stories: N
```

---

## Local Mode Consolidation (Step 11b)

### Step 11b: Consolidate Story Plans into Epic File (only if `--local`)

When `--local` is set, SKIP Phase 5 entirely and instead consolidate the run-state plans into the epic file:

**Brief mode (`$BRIEF_FLAG = true`):** the source files are `story-N-brief.md` (not `story-N-plan.md`). Each file contains a single story block (no STORY/BE/FE/INT sections). Consolidation rules below:

1. For each story N in numerical order, read `.claude/runs/design-<EPIC_SLUG>/story-N-brief.md` and append its contents verbatim under the epic's `## Stories` section. Insert a `---` horizontal rule between stories.
2. Insert `<!-- super-ralph: brief -->` as line 3 of the epic file (after `# EPIC: <title>` and the existing `<!-- super-ralph: local-mode -->` marker):
   ```bash
   # POSIX sed — insert after line 2
   awk 'NR==2 { print; print "<!-- super-ralph: brief -->"; next } { print }' "$EPIC_FILE" > "$EPIC_FILE.tmp" && mv "$EPIC_FILE.tmp" "$EPIC_FILE"
   ```
3. Commit:
   ```bash
   git add docs/epics/<file>
   git commit -m "epic: populate brief stories into local epic <slug>"
   ```
4. SKIP Phase 5. Proceed directly to Phase 6.

**Full mode (`$BRIEF_FLAG = false`):** original steps below.

1. For each story N (in numerical order):
   - Read the run-state plan file: `.claude/runs/design-<EPIC_SLUG>/story-N-plan.md`
   - Extract the four sections (STORY Issue Body, BE Sub-Issue Body, FE Sub-Issue Body, INT Sub-Issue Body)
   - Append a block to the epic file under `## Stories` using this exact shape:

     ```markdown
     ### Story N: <Title>

     **Persona:** <X>   **Priority:** <P0|P1|P2>   **Size:** <S|M|L|XL>   **Status:** PENDING
     <!-- PR: -->
     <!-- Branch: -->

     #### [STORY] Story N

     <STORY body from run-state file, verbatim>

     #### [BE] Story N — Backend

     <BE body from run-state file, verbatim>

     #### [FE] Story N — Frontend

     <FE body from run-state file, verbatim>

     #### [INT] Story N — Integration & E2E

     <INT body from run-state file, verbatim>

     ---
     ```

2. Commit:
   ```bash
   git add docs/epics/<file>
   git commit -m "epic: populate stories into local epic <slug>"
   ```

3. SKIP Phase 5 entirely. Proceed directly to Phase 6 with the epic file path as the review target.

---

## Phase 5 — Issue Creation

**Skip this entire phase when `--local` is set.** The epic lives in the markdown file; no GitHub issues are created.

### Step 12: Create EPIC Parent Issue

**Brief mode:** when `$BRIEF_FLAG = true`, the `[EPIC]` issue is created with the `brief` label added to the label set, and the body section "Story Priority Table" lists stories without nested `[BE]/[FE]/[INT]` sub-issue placeholders. See "Step 13 (brief mode)" below for story creation.

1. **Find the active milestone:**
   ```bash
   gh api repos/$REPO/milestones --jq '.[] | select(.state=="open") | "\(.number) \(.title)"'
   ```
   If no milestone exists or the epic doesn't fit an existing one, note this in the report and skip milestone attachment (only Jeph creates milestones).

2. **Create the `[EPIC]` parent issue:**
   ```bash
   # When BRIEF_FLAG=true, append "brief" to the label list so /improve-design and /review-design can detect brief epics.
   gh issue create --title "[EPIC] <title>" \
     --label "area/<backend|frontend|fullstack>${BRIEF_FLAG:+,brief}" \
     --milestone "<active milestone>" \
     --body "$(cat <<'EOF'
   ## Goal
   [Business context — 1-2 sentences]

   ## PM Summary

   ### Story Priority Table
   | # | Story | Priority | Size | Can Ship Without? | Notes |
   |---|-------|----------|------|-------------------|-------|
   | 1 | [Title] | P0 | M | No | [rationale] |
   | 2 | [Title] | P1 | S | Yes — degraded UX | [rationale] |

   ### Success Metrics
   | Metric | Target | Measurement |
   |--------|--------|-------------|
   | [metric] | [target] | [how] |

   ### Parking Lot
   - [Deferred idea 1 — why deferred]
   - [Deferred idea 2 — why deferred]

   ### PM Decision Points
   - [Decision 1: what was decided and why]
   - [Decision 2: what was decided and why]

   ## Execution Plan

   ### AI-Hours Estimate
   | Story | BE | FE | INT | Total |
   |-------|-----|-----|-----|-------|
   | Story 1 | 2h | 1.5h | 1h | 4.5h |
   | **Total** | **Xh** | **Yh** | **Zh** | **Wh** |

   ### Dependency Graph
   ```
   Story 1 (schema) --> Story 2 (service)
                    \-> Story 3 (FE, parallel with mock)
   ```

   ### Wave Assignments
   | Wave | Stories | Parallel Slots | Estimated Hours |
   |------|---------|---------------|-----------------|
   | 1 | Story 1, Story 3 | 2 | Xh |
   | 2 | Story 2, Story 4 | 2 | Yh |

   ## Stories
   - [ ] #?? [STORY] Story 1
     - [ ] #?? [BE] Story 1 — Backend
     - [ ] #?? [FE] Story 1 — Frontend
     - [ ] #?? [INT] Story 1 — Integration & E2E
   - [ ] #?? [STORY] Story 2
     - [ ] #?? [BE] Story 2 — Backend
     - [ ] #?? [FE] Story 2 — Frontend
     - [ ] #?? [INT] Story 2 — Integration & E2E

   ## Epic Document
   docs/epics/YYYY-MM-DD-<slug>.md
   EOF
   )" --repo $REPO
   ```

3. **Add to Project #$PROJECT_NUM and set fields:**
   ```bash
   gh project item-add $PROJECT_NUM --owner $ORG --url <epic-issue-url>
   # Set Type=epic, Size, Priority via project field IDs
   ```

### Step 13: Create Story + Sub-Issues (4 issues per story)

For each story, create four issues in order:

**Brief mode (`$BRIEF_FLAG = true`):** SKIP steps (b), (c), (d). Only create the `[STORY]` issue per story — no `[BE]`, no `[FE]`, no `[INT]`. The story issue body is the brief block verbatim (title, user-story line, metadata, AC outline). The EPIC body's "Stories" section lists stories as:

```
- [ ] #<story-num> [STORY] Story 1
- [ ] #<story-num> [STORY] Story 2
```

(No nested sub-issue bullets.)

**a. [STORY] issue:**
```bash
gh issue create --title "[STORY] <Story title>" \
  --label "vertical-slice,area/<area>" \
  --body "$(cat <<'EOF'
**Parent:** #<epic-number>

[STORY ISSUE BODY FROM STEP 9, OUTPUT 1]
EOF
)" --repo $REPO
```

Add to Project #$PROJECT_NUM, set Type=story, Size, Priority.

**b. [BE] sub-issue:**
```bash
gh issue create --title "[BE] <Story title> — Backend" \
  --label "area/backend" \
  --body "$(cat <<'EOF'
**Parent:** #<story-number>

[BE SUB-ISSUE BODY FROM STEP 9, OUTPUT 2]
EOF
)" --repo $REPO
```

Add to Project #$PROJECT_NUM, set Type=chore, Size, Priority.

**c. [FE] sub-issue:**
```bash
gh issue create --title "[FE] <Story title> — Frontend" \
  --label "area/frontend" \
  --body "$(cat <<'EOF'
**Parent:** #<story-number>

[FE SUB-ISSUE BODY FROM STEP 9, OUTPUT 3]
EOF
)" --repo $REPO
```

Add to Project #$PROJECT_NUM, set Type=chore, Size, Priority.

**d. [INT] sub-issue:**
```bash
gh issue create --title "[INT] <Story title> — Integration & E2E" \
  --label "area/fullstack,integration" \
  --body "$(cat <<'EOF'
**Parent:** #<story-number>
**Depends on:** [BE] #<be-number>, [FE] #<fe-number>

[INT SUB-ISSUE BODY FROM STEP 9, OUTPUT 4]
EOF
)" --repo $REPO
```

Add to Project #$PROJECT_NUM, set Type=story, Size=S (typically), Priority inherited from STORY.

### Step 14: Update EPIC Body with Linked Issue Numbers

After all issues are created, update the EPIC body to replace `#??` placeholders with actual issue numbers:

```bash
gh issue edit <epic-number> --body "<updated body with real #N references>" --repo $REPO
```

---

## Phase 6 — Review

### Step 15: Invoke Design Review

Dispatch a design-reviewer sub-agent inline by invoking `/super-ralph:review-design`:

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

    Run all PM Gates, Developer Gates, and Cross-Issue Checks.
    Return a structured verdict: READY / CONDITIONAL / BLOCKED.
```

### Step 16: Fix Critical Findings

If the review returns Critical findings:
1. Parse each Critical finding
2. Fix the issue in the relevant GitHub issue body or epic doc
3. Re-validate the fix
4. Do NOT rewrite AC or TDD code for non-Critical findings

### Step 17: Report

Output the final report:

```markdown
# Design Complete: [Epic Title]

## Epic
- **Document:** docs/epics/YYYY-MM-DD-<slug>.md
- **EPIC Issue:** #<epic-number>
- **Milestone:** [milestone name or "none"]

## Stories Created
| # | Story | STORY | BE | FE | Priority | Size |
|---|-------|-------|-----|-----|----------|------|
| 1 | [Title] | #N | #N | #N | P0 | M |
| 2 | [Title] | #N | #N | #N | P1 | S |

## Execution Plan
| Wave | Stories | Parallel Slots | AI-Hours |
|------|---------|---------------|----------|
| 1 | Story 1, Story 3 | 2 | Xh |
| 2 | Story 2, Story 4 | 2 | Yh |

**Total AI-Hours:** Zh
**Critical Path:** Story 1 --> Story 2 --> Story 5

## Context Budget Audit
- **Budget report:** `.claude/runs/design-<slug>/context-budget.md`
- **Largest combined story:** Story N — ~Xk tok (target ≤ 90k, hard cap ≤ 120k)
- **Splits triggered during audit:** N
- **Hard-cap violations remaining:** 0 (must be 0 to ship; else verdict = BLOCKED)

## Review Verdict
[READY / CONDITIONAL / BLOCKED]
[Findings summary if any]

## Launch Commands

**When `--local` was set** (launch via file path):
```
Wave 1 (parallel):
- /super-ralph:build-story docs/epics/<slug>.md#story-1
- /super-ralph:build-story docs/epics/<slug>.md#story-3

Wave 2 (after Wave 1):
- /super-ralph:build-story docs/epics/<slug>.md#story-2
- /super-ralph:build-story docs/epics/<slug>.md#story-4
```

**When `--local` was NOT set** (launch via issue number):
```
Wave 1 (parallel):
- /super-ralph:build-story #<story-1-number>
- /super-ralph:build-story #<story-3-number>

Wave 2 (after Wave 1):
- /super-ralph:build-story #<story-2-number>
- /super-ralph:build-story #<story-4-number>
```
```

---
name: design
description: "Create implementation-ready epics with stories, Gherkin AC, TDD tasks, and FE/BE sub-issues"
argument-hint: "<feature-or-goal> [--output PATH]"
allowed-tools: ["Bash(git:*)", "Bash(gh:*)", "Read", "Write", "Glob", "Grep", "Task", "WebSearch", "WebFetch"]
---

# Super-Ralph Design Command (SADD Flow)

Translate product vision, business goals, or user feedback into implementation-ready epics with full Gherkin acceptance criteria, pre-decided implementation details, TDD task lists, and FE/BE sub-issues. Produces artifacts that feed directly into `/super-ralph:build-story` for autonomous execution.

**This command absorbs `/super-ralph:plan`.** Design produces EVERYTHING: EPIC doc + GitHub issues with Gherkin AC + Pre-Decided Implementation + TDD tasks + FE/BE sub-issues. No separate planning step is needed.

## Arguments

Parse the user's input for:
- **Feature or goal description** (required): What to design — can be a feature idea, business goal, user feedback, or OKR
- **--output** (optional): Output path (default: `docs/epics/YYYY-MM-DD-<slug>.md`)

## Workflow — 6-Phase SADD Flow

Execute these phases in order. **Do NOT ask the user for input at any point.** Make all decisions autonomously using the research + SME pattern.

---

### Step 0: Load Project Config

Read `.claude/super-ralph-config.md` to load project-specific values. If the file does not exist, stop and tell the user to run `/super-ralph:init`.

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

### Phase 1: Context (sequential, orchestrator)

Gather all project and codebase context needed to inform the design.

#### Step 1: Load Skills

Invoke the `super-ralph:product-design` and `super-ralph:issue-management` skills. Follow their instructions for epic structure, story format, acceptance criteria, and issue taxonomy.

#### Step 2: Read Product Documentation

Read product documentation to understand vision, architecture, and current state:

1. Read `docs/vision.md` — product vision, target users, core principles, non-goals
2. Read `docs/roadmap.md` — current phase, what's done, what's planned
3. Read `docs/architecture.md` — system boundaries, services, tech stack
4. Read `docs/brand-cn.md` (if exists) — terminology glossary, bilingual considerations
5. Read `CLAUDE.md` — project conventions, development patterns

#### Step 3: Explore Codebase

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

### Phase 2: Research (3 parallel sub-agents)

#### Step 4: Dispatch Research Agents

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

#### Step 5: Synthesize Findings

Merge outputs from all three agents into a unified design brief:
- Prioritized story candidates
- Scope boundaries (in/out)
- Technical constraints and dependencies
- Risk mitigations
- Reusable components identified

---

### Phase 3: Epic Definition (orchestrator)

#### Step 6: Define Epic

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

#### Step 7: Apply SLICE Decomposition

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

**Output:** Ordered story list with: title, persona, action, outcome, priority (P0/P1/P2), size (S/M/L).

#### Step 8: Write Epic Doc

1. Create `docs/epics/` directory if it does not exist
2. Write the epic document to `docs/epics/YYYY-MM-DD-<slug>.md` using the template from `${CLAUDE_PLUGIN_ROOT}/skills/product-design/references/epic-template.md`
3. Include all stories with their Gherkin AC (written in Phase 4, but the epic doc structure is defined here)
4. Commit:
   ```bash
   git add docs/epics/<file>
   git commit -m "epic: [title]"
   ```

---

### Phase 4: Story Planning (parallel, 1 Sonnet per story, max 4 concurrent)

#### Step 9: Dispatch Story-Planner Sub-Agents

For each story defined in Step 7, dispatch a story-planner sub-agent. Run up to 4 in parallel.

**Orchestrator pre-work per story:** Before dispatching each agent, identify 3-5 relevant existing file paths by Grep/Glob for related code (routes, services, components, tests).

**Each story-planner agent:**

```
Task tool:
  model: sonnet
  max_turns: 40
  description: "Plan Story N: [Title]"
  prompt: |
    You are a story-planner agent. Produce complete STORY, [BE], and [FE] sub-issue
    bodies for autonomous execution.

    ## Story
    - Title: [STORY TITLE]
    - Persona: [PERSONA]
    - Action: [ACTION]
    - Outcome: [OUTCOME]
    - Priority: [P0/P1/P2]
    - Size: [S/M/L]

    ## Gherkin AC Outline (from epic)
    [PASTE THE AC OUTLINE FROM STEP 7]

    ## Epic Scope Boundaries
    - In scope: [LIST]
    - Out of scope: [LIST]

    ## Project Conventions
    - Runtime: Bun (not Node.js)
    - Language: TypeScript
    - Package manager: bun install, bun run
    - Monorepo: $BE_DIR/ (backend), $FE_DIR/ (frontend)
    - DB: Drizzle ORM, PostgreSQL
    - Tests: bun:test with describe/test/expect
    - i18n: $I18N_BASE_FILE + $I18N_SECONDARY_FILE with feature namespace keys

    ## Shared File Protocol
    - $SCHEMA_FILE — append tables in section: // ─── [Feature] ────
    - $ROUTE_REG_FILE — append route registration at END of protected routes
    - $TYPES_FILE — append types in section: // ── [Feature] Types ────
    - $I18N_BASE_FILE + $I18N_SECONDARY_FILE — add top-level key per feature
    - $BE_DIR/src/db/test-helpers.ts — append imports and tables.set() at end
    - RULE: Always APPEND to END of section. Never insert in middle.

    ## Relevant Existing Files
    [3-5 FILE PATHS PRE-SELECTED BY ORCHESTRATOR]

    ## Instructions

    Use Read, Grep, Glob to explore the relevant files and understand existing patterns.
    Then produce THREE outputs:

    ### Output 1: STORY Issue Body

    Write the full GitHub issue body for a [STORY] issue:

    ```markdown
    **Parent:** #EPIC_NUMBER

    ## User Story
    **As a** [persona],
    **I want** [action],
    **So that** [outcome].

    ## Acceptance Criteria

    Write COMPLETE Gherkin for each criterion using this format:

    ### AC-N: [Criterion name]
    Feature: [Feature name]
      Background:
        Given [shared precondition]

      Scenario: [Happy path / error / edge case name]
        Given [specific precondition]
        When [user action]
        Then [expected result]
        And [additional assertion]

    Rules:
    - Minimum 3 scenarios per story: happy path + error + edge case
    - Use concrete values ("3 items", "within 2 seconds")
    - Use specific personas (never "user")
    - Every scenario must be automatable as an e2e test

    ## Shared Contract

    Define the TypeScript types that both FE and BE will use:

    ```typescript
    // Types shared between FE and BE for this story
    // These go in $TYPES_FILE AND inform BE route types

    export interface [EntityName] {
      id: string;
      // ... all fields with types
    }

    export type [ActionPayload] = {
      // ... request body type
    };

    export type [ActionResponse] = {
      // ... response body type
    };
    ```

    ## E2E Test Skeleton

    ```typescript
    // tests/e2e/[story-slug].test.ts
    import { describe, test, expect } from "bun:test";

    describe("[Story title]", () => {
      // Map each AC scenario to a test case
      test("[AC-1 scenario name]", async () => {
        // Given: [precondition]
        // When: [action]
        // Then: [assertion]
      });
      // ... one test per scenario
    });
    ```
    ```

    ### Output 2: [BE] Sub-Issue Body

    Write the full GitHub issue body for a [BE] sub-issue:

    ```markdown
    **Parent:** #STORY_NUMBER

    ## Backend Implementation

    ### Schema Changes
    File: `$SCHEMA_FILE`
    Section: `// ─── [Feature] ────`

    ```typescript
    // EXACT code to append — no placeholders
    export const [tableName] = pgTable("[table_name]", {
      id: text("id").primaryKey().$defaultFn(() => createId()),
      // ... all columns with types, constraints, defaults
    });
    ```

    ### Service
    File: `$BE_SERVICES_DIR/[feature].ts` (Create)

    ```typescript
    // EXACT service code — no placeholders, no "implement X here"
    import { db } from "../db";
    import { [table] } from "../db/schema";

    export const [featureName]Service = {
      async list(orgId: string) {
        // ... exact implementation
      },
      async create(orgId: string, data: [Type]) {
        // ... exact implementation
      },
      // ... all methods
    };
    ```

    ### Route
    File: `$BE_ROUTES_DIR/[feature].ts` (Create)

    ```typescript
    // EXACT route code
    import { Hono } from "hono";

    export const [feature]Routes = new Hono()
      .get("/", async (c) => {
        // ... exact implementation
      })
      .post("/", async (c) => {
        // ... exact implementation
      });
    ```

    ### Route Registration
    File: `$ROUTE_REG_FILE`
    Action: APPEND to end of protected routes section

    ```typescript
    app.route("/api/[feature]", [feature]Routes);
    ```

    ### Test Helpers
    File: `$BE_DIR/src/db/test-helpers.ts`
    Action: APPEND at end

    ```typescript
    import { [table] } from "./schema";
    tables.set("[table_name]", [table]);
    ```

    ### TDD Tasks

    #### Task 0: E2E Test Skeleton (Outer RED)
    ```bash
    # Create e2e test from AC
    cat > tests/e2e/[story-slug].test.ts << 'TESTEOF'
    [EXACT TEST CODE FROM STORY AC]
    TESTEOF

    # Run — expected: FAIL (nothing implemented yet)
    bun test tests/e2e/[story-slug].test.ts
    # Expected: FAIL — 0 passed, N failed

    git add tests/e2e/[story-slug].test.ts
    git commit -m "test: add e2e tests for [story] (outer red)"
    ```

    #### Task 1: Schema + Migration
    ```bash
    # Add schema to $SCHEMA_FILE
    # [EXACT code to append — shown above in Schema Changes]

    # Write unit test
    cat > $BE_SERVICES_DIR/__tests__/[feature].test.ts << 'TESTEOF'
    import { describe, test, expect } from "bun:test";
    import { db } from "../../db";
    import { [table] } from "../../db/schema";

    describe("[feature] schema", () => {
      test("table exists and accepts inserts", async () => {
        // [EXACT test code]
      });
    });
    TESTEOF

    # Run — expected: FAIL (schema not added yet)
    cd $BE_DIR && $BE_TEST_CMD src/services/__tests__/[feature].test.ts
    # Expected: FAIL

    # Implement — add schema code
    # Run — expected: PASS
    cd $BE_DIR && $BE_TEST_CMD src/services/__tests__/[feature].test.ts
    # Expected: PASS — 1 passed

    git add $SCHEMA_FILE $BE_SERVICES_DIR/__tests__/[feature].test.ts
    git commit -m "feat([feature]): add schema and migration"
    ```

    #### Task 2: Service Layer
    [Same TDD structure: test file, run FAIL, implement, run PASS, commit]

    #### Task 3: Route Layer
    [Same TDD structure]

    #### Task 4: Route Registration + Test Helpers
    [Same TDD structure]

    ### Completion Criteria
    - [ ] `cd $BE_DIR && $BE_TEST_CMD` — 0 failures
    - [ ] `bun test tests/e2e/[story-slug].test.ts` — BE scenarios pass
    ```

    ### Output 3: [FE] Sub-Issue Body

    Write the full GitHub issue body for a [FE] sub-issue:

    ```markdown
    **Parent:** #STORY_NUMBER

    ## Frontend Implementation

    ### Mock Data (for concurrent dev without BE)
    File: `$FE_DIR/src/lib/mock/[feature].ts` (Create)

    ```typescript
    // Mock data matching the Shared Contract types
    // FE dev can start immediately — no BE dependency
    import type { [EntityName] } from "../types";

    export const mock[Feature]List: [EntityName][] = [
      {
        id: "mock-1",
        // ... realistic mock data matching schema
      },
      {
        id: "mock-2",
        // ... second item for list rendering
      },
    ];

    export const mock[Feature]Empty: [EntityName][] = [];

    export const mock[Feature]Error = {
      message: "Failed to load [feature]",
      status: 500,
    };
    ```

    ### API Client
    File: `$API_CLIENT_DIR/[feature].ts` (Create)

    ```typescript
    // EXACT API client code
    import { apiClient } from "./client";
    import type { [EntityName], [ActionPayload], [ActionResponse] } from "../types";

    export const [feature]Api = {
      async list(): Promise<[EntityName][]> {
        const res = await apiClient.get("/api/[feature]");
        return res.json();
      },
      async create(data: [ActionPayload]): Promise<[ActionResponse]> {
        const res = await apiClient.post("/api/[feature]", { json: data });
        return res.json();
      },
      // ... all methods
    };
    ```

    ### Types
    File: `$TYPES_FILE`
    Section: `// ── [Feature] Types ────`
    Action: APPEND at end of section

    ```typescript
    // ── [Feature] Types ────
    export interface [EntityName] { /* from Shared Contract */ }
    export type [ActionPayload] = { /* from Shared Contract */ };
    export type [ActionResponse] = { /* from Shared Contract */ };
    ```

    ### i18n
    File: `$I18N_BASE_FILE` — add top-level key:
    ```typescript
    [feature]: {
      title: "[Feature Title]",
      description: "[Feature description]",
      // ... all user-facing strings
      errors: {
        loadFailed: "Failed to load [feature]",
        createFailed: "Failed to create [feature]",
        // ... all error messages
      },
    },
    ```

    File: `$I18N_SECONDARY_FILE` — add matching key:
    ```typescript
    [feature]: {
      title: "[Chinese title]",
      description: "[Chinese description]",
      // ... all user-facing strings in Chinese
      errors: {
        loadFailed: "[Chinese error]",
        createFailed: "[Chinese error]",
      },
    },
    ```

    ### Components
    File: `$FE_PAGES_DIR/[path]/page.tsx` (Create)

    ```typescript
    // EXACT page component code
    "use client";
    // ... imports, hooks, JSX — complete implementation
    ```

    File: `$FE_COMPONENTS_DIR/[feature]/[Component].tsx` (Create, if needed)
    ```typescript
    // EXACT component code
    ```

    ### TDD Tasks

    #### Task 0: E2E Test — FE Scenarios (Outer RED)
    ```bash
    # Extend e2e test with FE-specific scenarios
    # [EXACT test additions]

    bun test tests/e2e/[story-slug].test.ts
    # Expected: FAIL — FE not implemented yet

    git add tests/e2e/[story-slug].test.ts
    git commit -m "test: add FE e2e scenarios for [story] (outer red)"
    ```

    #### Task 1: Types + Mock Data
    ```bash
    # [EXACT code, test, run FAIL, implement, run PASS, commit]
    ```

    #### Task 2: API Client
    ```bash
    # [EXACT code, test, run FAIL, implement, run PASS, commit]
    ```

    #### Task 3: i18n (en + zh-CN)
    ```bash
    # [EXACT i18n entries for both languages, test, commit]
    ```

    #### Task 4: Page Component
    ```bash
    # [EXACT component code, test, commit]
    ```

    ### PM Checkpoints

    | Checkpoint | When | What to Verify |
    |-----------|------|----------------|
    | CP1: Mock renders | After Task 1-2 | Component renders with mock data, layout correct |
    | CP2: i18n complete | After Task 3 | All strings display in EN and zh-CN |
    | CP3: API integrated | After BE is ready | Real data flows, loading/error states work |
    | CP4: AC pass | After all tasks | All Gherkin scenarios pass as e2e tests |

    ### Completion Criteria
    - [ ] `cd $FE_DIR && $FE_TEST_CMD` — 0 failures
    - [ ] `bun test tests/e2e/[story-slug].test.ts` — FE scenarios pass
    - [ ] i18n: both $I18N_BASE_FILE and $I18N_SECONDARY_FILE have [feature] key
    - [ ] Mock data: `$FE_DIR/src/lib/mock/[feature].ts` exists
    ```

    ## File Output

    Write all three outputs to a temp file:
    `/tmp/super-ralph-design-[EPIC_SLUG]/story-N-plan.md`

    Format:
    ```markdown
    # Story N: [Title]

    ## STORY Issue Body
    [Output 1]

    ## BE Sub-Issue Body
    [Output 2]

    ## FE Sub-Issue Body
    [Output 3]
    ```

    NEVER ask for human input. Use Read/Grep/Glob to explore files.
    NEVER use placeholders like "implement X here" or "...".
    Every code block must be EXACT, copy-pasteable code.
```

#### Step 10: Collect and Build Dependency DAG

After all story-planner agents complete:

1. Read all temp files from `/tmp/super-ralph-design-[EPIC_SLUG]/story-N-plan.md`
2. Build a dependency DAG:
   - Schema stories before service stories
   - Service stories before route stories
   - BE stories can run in parallel with FE stories (FE uses mock data)
   - Stories modifying the same shared file section must be sequential
3. Detect cycles — if found, reorder to break them

#### Step 11: Compute Execution Plan

Calculate total effort and optimal execution order:

**AI-Hours per size:**

| Size | AI-Hours |
|------|----------|
| XS | 0.25 |
| S | 0.75 |
| M | 2 |
| L | 4.5 |
| XL | 9 |

**Compute:**

1. Sum AI-hours across all stories (STORY + BE + FE sub-issues)
2. Topological sort the dependency DAG
3. Assign stories to execution waves:
   - Wave 1: All P0 stories with no dependencies
   - Wave 2: P0 stories dependent on Wave 1 + independent P1 stories
   - Wave 3: Remaining P1 + P2 stories
4. Identify the critical path (longest chain of dependent stories)
5. Calculate parallel speedup (how many stories can run concurrently per wave)

---

### Phase 5: Issue Creation (sequential)

#### Step 12: Create EPIC Parent Issue

1. **Find the active milestone:**
   ```bash
   gh api repos/$REPO/milestones --jq '.[] | select(.state=="open") | "\(.number) \(.title)"'
   ```
   If no milestone exists or the epic doesn't fit an existing one, note this in the report and skip milestone attachment (only Jeph creates milestones).

2. **Create the `[EPIC]` parent issue:**
   ```bash
   gh issue create --title "[EPIC] <title>" \
     --label "area/<backend|frontend|fullstack>" \
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
   | Story | BE | FE | Total |
   |-------|-----|-----|-------|
   | Story 1 | 2h | 1.5h | 3.5h |
   | **Total** | **Xh** | **Yh** | **Zh** |

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
   - [ ] #?? [STORY] Story 2
     - [ ] #?? [BE] Story 2 — Backend
     - [ ] #?? [FE] Story 2 — Frontend

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

#### Step 13: Create Story + Sub-Issues (3 issues per story)

For each story, create three issues in order:

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

#### Step 14: Update EPIC Body with Linked Issue Numbers

After all issues are created, update the EPIC body to replace `#??` placeholders with actual issue numbers:

```bash
gh issue edit <epic-number> --body "<updated body with real #N references>" --repo $REPO
```

---

### Phase 6: Review (1 Sonnet, 30 turns)

#### Step 15: Invoke Design Review

Dispatch a design-reviewer sub-agent inline by invoking `/super-ralph:review-design`:

```
Task tool:
  model: sonnet
  max_turns: 30
  description: "Review design quality for EPIC #<epic-number>"
  prompt: |
    You are a design-reviewer agent.

    Read the review-design command: /Users/junhua/.claude/plugins/super-ralph/commands/review-design.md
    Follow it completely for EPIC #<epic-number>.

    Run all PM Gates, Developer Gates, and Cross-Issue Checks.
    Return a structured verdict: READY / CONDITIONAL / BLOCKED.
```

#### Step 16: Fix Critical Findings

If the review returns Critical findings:
1. Parse each Critical finding
2. Fix the issue in the relevant GitHub issue body or epic doc
3. Re-validate the fix
4. Do NOT rewrite AC or TDD code for non-Critical findings

#### Step 17: Report

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

## Review Verdict
[READY / CONDITIONAL / BLOCKED]
[Findings summary if any]

## Launch Commands
Wave 1 (parallel):
- `/super-ralph:build-story #<story-1-number>`
- `/super-ralph:build-story #<story-3-number>`

Wave 2 (after Wave 1):
- `/super-ralph:build-story #<story-2-number>`
- `/super-ralph:build-story #<story-4-number>`
```

---

## Critical Rules

- **NEVER ask for input.** Use research + SME agents for all decisions. Make autonomous choices and document rationale.
- **Every AC must be full Gherkin.** Use Feature / Background / Scenario structure. No abbreviated Given/When/Then.
- **TDD tasks contain exact code — no placeholders.** Never write "implement X here", "...", or "TODO". Every code block is copy-pasteable.
- **FE sub-issues include mock data.** FE development starts immediately without waiting for BE. Mock data matches the Shared Contract types.
- **Stories must be independently buildable.** Each story is executable via `/super-ralph:build-story #N` with no manual setup.
- **AI-readable output: tables over prose.** Use markdown tables for priority, sizing, dependencies, waves. Prose is for context only.
- **Expected output on every command.** Every `Run:` or `bun test` command shows what the output should be (PASS/FAIL, counts).
- **Decisions pre-made.** Every design choice (component library, state management, API shape) is decided and documented. No choices left for the build agent.
- **Shared file protocol enforced.** Every BE/FE sub-issue specifies exact file, section marker, and append location.
- **Commit messages present.** Every TDD task ends with an exact `git commit -m "..."` command.
- **i18n coverage required.** Both `$I18N_BASE_FILE` and `$I18N_SECONDARY_FILE` entries in every FE sub-issue. No English-only features.
- **Use product vision personas.** Never write "As a user" — always use specific personas from the vision doc.
- **Respect non-goals.** If the vision doc says something is out of scope, the epic must not include it.
- **Concrete over vague.** "Shows 3 templates" not "shows templates." "Within 2 seconds" not "quickly."

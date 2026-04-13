# Super-Ralph v0.6.0

Unified autonomous development workflow combining **ralph-planning**, **ralph-loop**, and **superpowers** into a single fire-and-forget system.

Hit enter. Walk away. Come back to results.

## What It Does

Super-ralph orchestrates the full development lifecycle autonomously:

1. **Design** -- Create epics and user stories with BDD acceptance criteria from vision, goals, or feedback
2. **Plan** -- Create implementation plans with e2e tests from stories, optimized for autonomous execution
3. **Build** -- Execute plans via ralph-loop with superpowers discipline (TDD, debugging, verification)
4. **Repair** -- Fast-track reactive fix for bugs, feature mods, or UI changes (skips design/plan)
5. **Review & Fix** -- Rebase to default branch, run multi-agent code review on branch diff, fix issues until clean, create PR
6. **Verify** -- Browser-verify Vercel preview deployments against acceptance criteria using claude-in-chrome
7. **Finalise** -- Merge PR, update plan/epic/roadmap status, clean up worktrees and branches
8. **Release** -- Comprehensive version sealing with parallel verification, release notes, git tag, and milestone closure

Every decision point that would normally pause for human input is resolved by dispatching **research + subject-matter-expert agents** instead.

## Pipelines

```
Proactive:   design --> plan --> build --> review-fix --> verify --> finalise
Reactive:    repair --> review-fix --> verify --> finalise
Composite:   build-story (one story, all phases, zero-touch)
Epic-wide:   e2e (design-to-release for an entire epic, parallel waves)
Release:     release (promotes staging --> main for a milestone)
```

## Prerequisites

These plugins must be installed:

| Plugin | Purpose |
|--------|---------|
| **ralph-loop** | Provides the while-true loop engine (Stop hook) |
| **superpowers** | Provides TDD, debugging, verification skills |
| **pr-review-toolkit** | Provides review agents (for review-fix command) |
| **claude-in-chrome** | Provides browser automation (for verify/release commands) |

## Commands

### `/super-ralph:design`

Create epics and user stories with BDD acceptance criteria.

```
/super-ralph:design "Guided agent builder for non-technical users"
/super-ralph:design "Operations inbox with approval workflows"
/super-ralph:design "Add connector setup wizard" --output docs/epics/connector-wizard.md
```

**What happens:** Reads product vision, roadmap, and architecture docs. Research agent finds UX patterns and competitor approaches. SME agents brainstorm scope, stories, and priorities. Writes structured epic with stories, Given/When/Then acceptance criteria, and e2e test skeletons. Validated by an SME agent before output.

### `/super-ralph:plan`

Create an implementation plan optimized for autonomous execution.

```
/super-ralph:plan "Add JWT authentication with login, refresh, and logout"
/super-ralph:plan "Refactor the notification service" --mode hybrid
/super-ralph:plan "Add rate limiting" --output docs/plans/rate-limiting.md
/super-ralph:plan "Implement knowledge search" --story docs/epics/knowledge.md#KI-1
```

**What happens:** Research agent searches for best practices, 2-3 SME agents brainstorm task decomposition and architecture, plan is written with complete TDD tasks, then validated by the plan-reviewer agent. When `--story` is provided, generates e2e tests from acceptance criteria as Task 0.

### `/super-ralph:build`

Execute a plan autonomously via ralph-loop.

```
/super-ralph:build docs/plans/2026-02-15-auth-api.md
/super-ralph:build docs/plans/2026-02-15-auth-api.md --max-iterations 30
/super-ralph:build docs/plans/2026-02-15-auth-api.md --mode hybrid
```

**What happens:** Creates an isolated git worktree, reads the plan, validates it, constructs an execution prompt with superpowers integration and the autonomous decision pattern, then starts the ralph-loop inside the worktree.

### `/super-ralph:repair`

Fast-track reactive fix for bugs, feature mods, or UI changes.

```
/super-ralph:repair #42
/super-ralph:repair "Login button doesn't respond on mobile"
/super-ralph:repair --screenshot /path/to/bug.png
/super-ralph:repair --url https://preview-abc.vercel.app/agents
```

**What happens:** Skips the full design/plan cycle. Accepts GitHub issues, text descriptions, screenshots, or URLs as input. Creates an isolated worktree, diagnoses the issue, implements the fix with TDD, and hands off to review-fix.

### `/super-ralph:review-fix`

Autonomously review, test, and fix code on a feature branch until clean, then create a PR.

```
/super-ralph:review-fix                           # Loop until clean, create PR
/super-ralph:review-fix --max-iterations 5        # Cap at 5 iterations
/super-ralph:review-fix --aspects errors tests    # Only specific aspects
/super-ralph:review-fix --no-pr                   # Skip PR creation
```

**What happens:** Creates an isolated git worktree, rebases to default branch each iteration, runs regression tests, dispatches review agents on the branch diff (`git diff`), fixes Critical/Important issues, loops until no blocking issues remain, then creates a PR.

### `/super-ralph:verify`

Browser-verify a PR's Vercel preview deployment against acceptance criteria.

```
/super-ralph:verify                               # Auto-detect PR and criteria
/super-ralph:verify --pr 45                       # Specific PR
/super-ralph:verify --url http://localhost:3000    # Local dev server
```

**What happens:** Dispatches the browser-verifier agent with claude-in-chrome to walk through Given/When/Then acceptance criteria on the live deployment. Captures GIF evidence, checks console errors and network failures. Reports pass/fail per criterion.

### `/super-ralph:finalise`

Merge a review-clean PR and close the development loop.

```
/super-ralph:finalise                               # Auto-detect PR, plan, story
/super-ralph:finalise --pr 45
/super-ralph:finalise --plan docs/plans/auth.md --story docs/epics/auth.md#story-1
/super-ralph:finalise --no-cleanup                  # Keep worktree/branch
```

**What happens:** Merges the PR, updates plan tasks to done, marks epic stories complete, syncs the roadmap, cleans up worktrees and branches, and suggests next steps. This is the "paperwork" transition from code-done to project-status-updated.

### `/super-ralph:release`

Comprehensive version sealing for a milestone.

```
/super-ralph:release                              # Auto-detect milestone
/super-ralph:release --milestone "v1.2"           # Specific milestone
/super-ralph:release --no-verify                  # Emergency patch (skip checks)
```

**What happens:** Runs pre-flight checks, dispatches parallel verification subagents (browser smoke tests, regression tests, contract checks, acceptance audit), generates release notes, creates git tag, closes the GitHub milestone, and cleans up.

### `/super-ralph:build-story`

Execute a single story end-to-end — plan → build → review-fix → verify → finalise — with each phase running as a dedicated sub-agent and temp files bridging state.

```
/super-ralph:build-story #42                        # From GitHub issue
/super-ralph:build-story docs/epics/auth.md#story-3 # From epic file
/super-ralph:build-story "Add JWT authentication"   # From description
/super-ralph:build-story #42 --skip-verify --skip-finalise
```

**What happens:** Each phase runs in a fresh context window via sub-agents so no single conversation holds the entire lifecycle. Temp files pass context between phases. Zero-touch from plan to merged PR.

### `/super-ralph:e2e`

Execute an entire epic from start to finish — all stories, in parallel waves, then release.

```
/super-ralph:e2e 36                                 # Epic issue #36
/super-ralph:e2e 36 --milestone "v1.2"
/super-ralph:e2e 36 --max-parallel 3
/super-ralph:e2e 36 --skip-release
```

**What happens:** Loads the epic from GitHub, plans story execution waves, dispatches parallel story executors (plan → build → review-fix → verify), finalises stories sequentially, then runs release to promote staging → main. Fire-and-forget epic-wide execution.

### `/super-ralph:help`

Show usage documentation.

## Execution Modes

| Mode | Best For | How It Works |
|------|----------|-------------|
| **Standard** | <6 tightly-coupled tasks | Claude executes tasks directly, invoking TDD/debugging/verification inline |
| **Hybrid** | 6+ independent tasks | Claude orchestrates by dispatching subagents per task with review stages |
| **Auto** (default) | Any | SME agents analyze task characteristics and pick the best mode |

## How Decisions Are Made

The core innovation: every human decision point is replaced by the **autonomous decision pattern**:

```
Decision needed?
  1. Dispatch research-agent (haiku) --> web + codebase references
  2. Dispatch 1-3 sme-brainstormer agents (sonnet) --> different angles
  3. Synthesize --> pick most rational option based on evidence
  4. Document briefly --> proceed immediately
```

This applies to: architecture choices, mode selection, error resolution, library selection, approach ambiguity, and any fork in the road.

## Verification Layers

```
Layer 1 (review-fix):  Code quality -- static analysis, unit/integration tests
Layer 2 (verify):      Running app -- browser verification against acceptance criteria
Layer 3 (release):     Version seal -- comprehensive smoke, contracts, acceptance audit
```

## Plugin Structure

```
super-ralph/
├── .claude-plugin/
│   └── plugin.json
├── agents/
│   ├── browser-verifier.md     # Browser-based verification (sonnet)
│   ├── issue-fixer.md          # Fixes review findings autonomously
│   ├── plan-reviewer.md        # Validates plans for execution readiness
│   ├── research-agent.md       # Web + codebase research (haiku)
│   └── sme-brainstormer.md     # Expert analysis from assigned angle (sonnet)
├── commands/
│   ├── build-story.md          # /super-ralph:build-story
│   ├── build.md                # /super-ralph:build
│   ├── design.md               # /super-ralph:design
│   ├── e2e.md                  # /super-ralph:e2e
│   ├── finalise.md             # /super-ralph:finalise
│   ├── help.md                 # /super-ralph:help
│   ├── plan.md                 # /super-ralph:plan
│   ├── release.md              # /super-ralph:release
│   ├── repair.md               # /super-ralph:repair
│   ├── review-fix.md           # /super-ralph:review-fix
│   └── verify.md               # /super-ralph:verify
├── skills/
│   ├── browser-verification/   # Browser testing with claude-in-chrome
│   ├── issue-management/       # GitHub Issues + Project #9 management
│   ├── product-design/         # Epics & stories with BDD criteria
│   ├── ralph-planning/         # Autonomous execution plans
│   ├── repair-domains/         # Domain detection + routing for repair
│   └── review-fix-loop/        # Code review + fix references (command-only)
├── scripts/
│   └── setup-ralph-loop.sh
└── README.md
```

## Worktree Isolation

The `build`, `repair`, and `review-fix` commands automatically create a git worktree before starting. This ensures:

- **No interference** with other Claude windows working in the same repo
- **Safe rollback** -- delete the worktree if things go wrong
- **Parallel execution** -- multiple ralph loops can run simultaneously on different features
- **Clean state** -- each loop gets its own `.claude/ralph-loop.local.md`

Worktree location is selected autonomously (never prompts the user):
1. Use `.worktrees/` if it exists
2. Use `worktrees/` if it exists
3. Default to `.worktrees/` (auto-added to `.gitignore`)

| Command | Worktree Branch | Example Path |
|---------|----------------|--------------|
| `build` | `super-ralph/<plan-slug>` | `.worktrees/auth-api/` |
| `repair` | `super-ralph/repair-<slug>` | `.worktrees/repair-login-button/` |
| `review-fix` | Current or PR branch | `.worktrees/review-fix-feature-auth/` |
| `design` | No worktree needed | -- |
| `plan` | No worktree needed | -- |

## Severity Rules (Review-Fix)

| Severity | Blocks Completion | Examples |
|----------|-------------------|---------|
| **Critical** | Yes | Bugs, security issues, data loss, crashes, NEW test failures |
| **Important** | Yes | Architecture problems, missing error handling, test gaps |
| **Minor** | No | Code style, optimizations |
| **Suggestions** | No | Documentation, nice-to-haves |

## Superpowers Compatibility

Only these superpowers skills work inside ralph-loop:

| Compatible | Not Compatible (requires human interaction) |
|-----------|---------------------------------------------|
| test-driven-development | brainstorming |
| systematic-debugging | writing-plans |
| verification-before-completion | executing-plans |
| dispatching-parallel-agents | subagent-driven-development |
| | using-git-worktrees |
| | finishing-a-development-branch |

See `skills/ralph-planning/references/superpowers-compatibility.md` for full details.

## License

MIT

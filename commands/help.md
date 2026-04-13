---
name: help
description: "Explain the super-ralph plugin, its philosophy, and usage"
allowed-tools: ["Read"]
---

# Super-Ralph Help

Display comprehensive help for the super-ralph plugin.

## Output the following help text:

```
# Super-Ralph v0.6.0 — Autonomous Development Workflow

Super-ralph combines ralph-planning, ralph-loop, and superpowers into a unified
fire-and-forget development workflow. Hit enter, walk away, come back to results.

## Philosophy

Every decision point that would normally pause for human input is instead resolved
by dispatching research + subject-matter-expert agents. This means:
- No confirmation prompts during execution
- No "which approach?" questions — AI agents decide autonomously
- No manual PR review cycles — automated review -> fix -> re-review
- No manual testing — browser verification against acceptance criteria
- No manual releases — QA + Codex review + merge + tag, all automated

## Branch Model

  feature branches ──PR──▶ staging (default branch, preview deploys)
                                │
                       /super-ralph:release
                                │
                                ▼
                           main (production: work.forth.ai)
                                │
                       /super-ralph:repair --hotfix
                                │
                           hotfix branch ──PR──▶ main ──cherry-pick──▶ staging

  - staging is the GitHub default branch. All feature PRs merge here.
  - main is the production branch. Only /release promotes staging → main.
  - Hotfix: /repair --hotfix branches from main, merges to main, backports to staging.
  - Vercel auto-deploys both: staging → preview URL, main → production domains.

## Pipelines

  Story:    build-story (plan → build → review-fix → verify → finalise)
  Epic:     e2e (parallel build-story per story, then release)
  Stepwise: design → plan → build → review-fix → verify → finalise
  Reactive: repair (fix → review-fix → verify → finalise — full pipeline)
  Hotfix:   repair --hotfix (fix → review-fix → verify → finalise on main → backport staging)
  Release:  release (QA staging → Codex review → merge staging→main → tag)

## Sub-Agent Architecture

  Super-ralph orchestrates work through layered sub-agents:

  Level 0 (orchestrator):  e2e / build-story — plans waves, monitors progress
  Level 1 (phase agents):  plan / build / review-fix / verify — one per phase
  Level 2 (worker agents): research / sme-brainstormer / code-reviewer /
                           issue-fixer / browser-verifier — dispatched by phases

  Temp files (/tmp/super-ralph-*/) bridge state between phases so each
  sub-agent gets a fresh context window without inheriting conversation bloat.

## Commands

### /super-ralph:design <feature-or-goal> [--output PATH]

  Create epics and user stories with BDD acceptance criteria from product vision,
  business goals, or user feedback. Creates [EPIC] GitHub issues with sub-issues,
  attaches to the active milestone, and adds all to Project #9.

  Example:
    /super-ralph:design "Guided agent builder for non-technical users"

### /super-ralph:plan <feature> [--mode auto|standard|hybrid] [--output PATH] [--story EPIC#STORY]

  Create an implementation plan optimized for autonomous execution.
  When --story is provided, generates e2e tests from acceptance criteria as Task 0.

  Example:
    /super-ralph:plan "Add JWT authentication with login, refresh, and logout"
    /super-ralph:plan --story docs/epics/gl.md#story-3

### /super-ralph:build <plan-path> [--max-iterations N] [--mode standard|hybrid]

  Execute a plan autonomously via ralph-loop. Creates isolated worktree, validates
  the plan, constructs execution prompt, and starts the loop.

  Example:
    /super-ralph:build docs/plans/2026-02-15-auth-api.md
    /super-ralph:build docs/plans/2026-02-15-auth-api.md --max-iterations 30

### /super-ralph:repair <#issue|description> [--screenshot PATH] [--url URL] [--hotfix] [--no-pipeline] [--skip-verify] [--skip-finalise]

  Fast-track reactive fix with domain-aware tooling and full pipeline.
  Detects domain (frontend, backend, security, devops, cloud-infra), loads
  the right skills and review agents, then chains: fix → review-fix → verify
  → finalise — all autonomously.

  Domain detection:
    - Label-based: reads area/frontend, area/backend, security labels
    - File-path: classifies by work-web/, work-agents/, .github/, etc.
    - Content: CSS/JSX = frontend, SQL/Hono = backend, JWT/CORS = security
    - Routes domain-specific review agents (e.g., silent-failure-hunter for
      backend, type-design-analyzer for frontend)

  Hotfix mode (--hotfix):
    Branches from main instead of staging. PR targets main for immediate
    production fix. After merge, auto-backports to staging via cherry-pick.
    Auto-detected from: priority/critical label, security label, production
    URLs, or "production"/"prod" in the problem statement.

    Regular: fix/dev/slug → staging → (wait for release)
    Hotfix:  hotfix/dev/slug → main → cherry-pick to staging

  Pipeline (default: enabled):
    Phase 1: Fix (TDD, domain-specific patterns)
    Phase 2: Review-fix (domain-selected agents, max 5 iterations)
    Phase 3: Verify (browser, auto-skipped for pure backend/devops)
    Phase 4: Finalise (merge PR, close issue, cleanup)
    Phase 5: Backport (hotfix only — cherry-pick to staging)

  Example:
    /super-ralph:repair #42
    /super-ralph:repair "Login button doesn't respond on mobile"
    /super-ralph:repair --screenshot /path/to/bug.png
    /super-ralph:repair #42 --hotfix
    /super-ralph:repair "API returns 500 on empty body" --skip-verify
    /super-ralph:repair #99 --no-pipeline

### /super-ralph:review-fix [--max-iterations N] [--aspects ASPECTS...] [--no-pr]

  Autonomously review, test, and fix code on a feature branch. Rebases to the
  default branch each iteration, runs regression tests, reviews branch diff, fixes
  Critical/Important issues, and repeats until clean. Creates a PR when done.

  Review agents dispatched IN PARALLEL: code-reviewer, silent-failure-hunter,
  pr-test-analyzer, comment-analyzer, type-design-analyzer, code-simplifier.

  Example:
    /super-ralph:review-fix                           # Loop until clean, create PR
    /super-ralph:review-fix --max-iterations 5        # Cap at 5 iterations
    /super-ralph:review-fix --aspects errors tests    # Only specific aspects

### /super-ralph:verify [--pr NUMBER] [--url URL] [--criteria PATH]

  Browser-verify a PR's Vercel preview deployment against acceptance criteria
  using claude-in-chrome. Walks through Given/When/Then criteria, captures GIF
  evidence, checks console errors and network failures.

  Example:
    /super-ralph:verify                               # Auto-detect PR and criteria
    /super-ralph:verify --pr 45                       # Specific PR
    /super-ralph:verify --url http://localhost:3000    # Local dev server

### /super-ralph:finalise [--pr NUMBER] [--plan PATH] [--story EPIC#STORY] [--no-cleanup]

  Merge a review-clean PR into staging and close the development loop. Updates
  plan tasks, epic stories, roadmap. Cleans up worktrees and branches.

  Example:
    /super-ralph:finalise                             # Auto-detect everything
    /super-ralph:finalise --pr 42                     # Specific PR

### /super-ralph:build-story <STORY> [--skip-verify] [--skip-finalise] [--mode auto|standard|hybrid]

  Execute a single story end-to-end in one fire-and-forget command:
  plan → build → review-fix → verify → finalise.

  Each phase runs as a dedicated sub-agent with fresh context. Temp files at
  /tmp/super-ralph-story-$ID/ bridge state between phases.

  Idempotent — re-run after failure to resume from the last completed phase.

  Internal parallelism per phase:
    Plan:       research + 2-3 SME brainstormers in parallel
    Build:      up to 3 independent tasks in parallel (hybrid mode)
    Review-fix: 6 review agents dispatched simultaneously
    Verify:     sequential (browser is single-threaded)
    Finalise:   sequential (merge safety)

  Input formats:
    /super-ralph:build-story #42                        # GitHub issue number
    /super-ralph:build-story docs/epics/gl.md#story-3   # Epic story reference
    /super-ralph:build-story "Add JWT auth endpoints"   # Description string

  Options:
    /super-ralph:build-story #42 --skip-verify          # Skip browser verification
    /super-ralph:build-story #42 --skip-finalise        # Stop at PR, don't merge
    /super-ralph:build-story #42 --mode hybrid          # Force hybrid execution

### /super-ralph:e2e EPIC_NUMBER [--milestone NAME] [--max-parallel N] [--skip-release] [--skip-verify]

  Execute an entire epic end-to-end. Loads the epic from GitHub, plans story
  execution waves (maximizing parallelism via SME dependency analysis), dispatches
  build-story executors per story, finalises PRs sequentially into staging, then
  runs release to promote staging → main.

  Wave execution model:
    Wave 1:  [Story A, Story B]   ← independent, run in parallel
    Wave 2:  [Story C]            ← depends on Story A, runs after Wave 1
    Wave 3:  [Story D, Story E]   ← depend on Wave 2, run in parallel
    Finalise: sequential per wave (merge safety for shared files)
    Release:  after all waves complete

  Uses temp files (/tmp/super-ralph-e2e-N/) as context bridges.
  Idempotent — re-run after failure to resume where it left off.

  Example:
    /super-ralph:e2e 50                               # Execute Epic #50
    /super-ralph:e2e 50 --max-parallel 4              # 4 stories in parallel
    /super-ralph:e2e 50 --skip-release                # Don't promote to production
    /super-ralph:e2e 50 --skip-verify                 # Skip browser verification

### /super-ralph:release [--milestone NAME] [--tag VERSION] [--no-verify] [--no-codex]

  Promote staging to production. The release promotion gate:

    1. Pre-flight: all issues closed, staging ahead of main, tag unused
    2. QA on staging: browser smoke, regression tests, contracts, acceptance audit
    3. Create staging → main PR with release notes
    4. Codex CLI review + fix loop (second-AI safety net)
    5. Merge to main (merge commit, preserves feature history)
    6. Seal: tag, close milestone, GitHub Release
    7. Sync: fast-forward staging to main

  Example:
    /super-ralph:release                              # Auto-detect milestone
    /super-ralph:release --milestone "v1.2"           # Specific milestone
    /super-ralph:release --no-verify                  # Emergency patch (skip QA)
    /super-ralph:release --no-codex                   # Skip Codex review

### /super-ralph:help

  Show this help text.

## Prerequisites

These plugins/tools must be installed:
- ralph-loop — provides the while-true loop engine
- superpowers — provides TDD, debugging, verification skills
- pr-review-toolkit — provides review agents for review-fix
- claude-in-chrome — provides browser automation for verify/release
- codex CLI (optional) — provides AI code review for release promotion

## Execution Modes

### Standard Mode
  Claude executes all tasks directly in the ralph-loop, invoking superpowers
  skills (TDD, debugging, verification) inline. Best for <6 tightly-coupled tasks.

### Hybrid Mode
  Claude orchestrates by dispatching fresh subagents per task, with spec compliance
  and code quality review stages. Best for 6+ independent, substantial tasks.

### Auto Mode (default for /plan and /build-story)
  Dispatches SME agents to analyze task characteristics and picks the best mode.

## How Decisions Are Made

When ambiguity arises (architecture, approach, error resolution, etc.):
1. research-agent searches web + codebase for references
2. 1-3 sme-brainstormer agents analyze options from different angles
3. Most rational option is chosen based on evidence + expert consensus
4. Execution continues. No waiting.

## Severity Rules (for review-fix)

- Critical (blocks): Bugs, security issues, data loss, broken functionality, NEW test failures
- Important (blocks): Architecture problems, missing error handling, test gaps
- Minor (logged): Code style, optimizations — does NOT block completion
- Suggestions (logged): Documentation, nice-to-haves — does NOT block completion

## Verification Layers

  Layer 1 (review-fix):  Code quality — static analysis, unit/integration tests
  Layer 2 (verify):      Running app — browser verification against acceptance criteria
  Layer 3 (release QA):  Version seal — smoke tests, contracts, acceptance audit
  Layer 4 (release PR):  Codex review — second-AI review of staging→main diff

## Temp File Protocol

  Sub-agents communicate via structured temp files, not conversation context.
  Each phase writes a result file; the next phase reads only what it needs.

  /tmp/super-ralph-story-$ID/       # build-story
  /tmp/super-ralph-e2e-$EPIC/       # e2e (per-story subdirectories)

  Files use key: value format for easy parsing by downstream phases.
  Progress files enable idempotent resume after failures.
```

---
name: help
description: "Explain the super-ralph plugin, its philosophy, and usage"
allowed-tools: ["Read"]
---

# Super-Ralph Help

Display comprehensive help for the super-ralph plugin.

## Output the following help text:

```
# Super-Ralph — Autonomous Development Workflow

Super-ralph combines ralph-planning, ralph-loop, and superpowers into a unified
fire-and-forget development workflow. Hit enter, walk away, come back to results.

## Philosophy

Every decision point that would normally pause for human input is instead resolved
by dispatching research + subject-matter-expert agents. This means:
- No confirmation prompts during execution
- No "which approach?" questions — AI agents decide autonomously
- No manual PR review cycles — automated review → fix → re-review

## The Full Pipeline

  /super-ralph:design → epics & stories → /super-ralph:plan → implementation plan → /super-ralph:launch → /super-ralph:review-fix → /super-ralph:update

  Stories have BDD acceptance criteria that become e2e tests in the implementation plan.
  The outer e2e test goes red first, TDD tasks make it green. Outside-in development.
  Review-fix runs regression tests, reviews code, fixes issues, and auto-merges the PR.
  Update closes the loop by marking plans/stories as complete.

## Commands

### /super-ralph:design <feature-or-goal> [--output PATH]

  Create epics and user stories with BDD acceptance criteria from product vision,
  business goals, or user feedback. Reads docs/vision.md, docs/roadmap.md, and
  docs/architecture.md for context. Dispatches research + SME agents for scope,
  stories, and priorities.

  Example:
    /super-ralph:design "Guided agent builder for non-technical users"
    /super-ralph:design "Operations inbox with approval workflows" --output docs/epics/ops-inbox.md

### /super-ralph:plan <feature-description> [--mode auto|standard|hybrid] [--output PATH] [--story EPIC_PATH#STORY]

  Create an implementation plan optimized for autonomous execution.
  When --story is provided, generates e2e tests from story acceptance criteria as Task 0.
  Dispatches research + SME agents to brainstorm, then writes a ralph-optimized
  plan with TDD tasks, superpowers integration, and machine-verifiable criteria.

  Example:
    /super-ralph:plan "Add JWT authentication with login, refresh, and logout endpoints"

### /super-ralph:launch <plan-path> [--max-iterations N] [--mode standard|hybrid]

  Launch a ralph-loop to execute a plan autonomously. Reads the plan, validates it,
  constructs the execution prompt with superpowers integration, and starts the loop.

  Example:
    /super-ralph:launch docs/plans/2026-02-15-auth-api.md
    /super-ralph:launch docs/plans/2026-02-15-auth-api.md --max-iterations 30

### /super-ralph:review-fix [--max-iterations N] [--aspects ASPECTS...] [--pr NUMBER] [--no-merge]

  Create a PR and autonomously review, test, and fix issues until no Critical or
  Important findings remain AND all regression tests pass. Runs functional,
  integration, and e2e tests every iteration. Auto-merges the PR on completion
  (unless --no-merge is set).

  Example:
    /super-ralph:review-fix                           # Loop until clean, then merge
    /super-ralph:review-fix --max-iterations 5        # Cap at 5 iterations
    /super-ralph:review-fix --aspects errors tests    # Only review specific aspects
    /super-ralph:review-fix --pr 42                   # Review existing PR
    /super-ralph:review-fix --no-merge                # Skip auto-merge

### /super-ralph:update [--plan PATH] [--story EPIC_PATH#STORY_ID] [--branch BRANCH] [--cleanup]

  Update project status after development. Marks plan tasks as done, updates epic
  stories to completed, generates a development summary, and optionally cleans up
  worktrees. Auto-detects the branch, plan, and story if not specified.

  Example:
    /super-ralph:update                                      # Auto-detect everything
    /super-ralph:update --plan docs/plans/2026-02-15-auth.md # Specific plan
    /super-ralph:update --cleanup                            # Also remove worktree

### /super-ralph:help

  Show this help text.

## Prerequisites

These plugins must be installed:
- ralph-loop (provides the while-true loop engine)
- superpowers (provides TDD, debugging, verification skills)
- pr-review-toolkit (provides review agents for review-fix command)

## Execution Modes

### Standard Mode
  Claude executes all tasks directly in the ralph-loop, invoking superpowers
  skills (TDD, debugging, verification) inline. Best for <6 tightly-coupled tasks.

### Hybrid Mode
  Claude orchestrates by dispatching fresh subagents per task, with spec compliance
  and code quality review stages. Best for 6+ independent, substantial tasks.

### Auto Mode (default for /plan)
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

## Completion Gate (for review-fix)

The loop completes when BOTH conditions are met:
1. No Critical or Important findings from code review
2. All regression tests pass (functional, integration, e2e)
Then the PR is auto-merged (squash) unless --no-merge is set.
```

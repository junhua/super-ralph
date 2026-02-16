# Super-Ralph

Unified autonomous development workflow combining **ralph-planning**, **ralph-loop**, and **superpowers** into a single fire-and-forget system.

Hit enter. Walk away. Come back to results.

## What It Does

Super-ralph orchestrates the full development lifecycle autonomously:

1. **Design** — Create epics and user stories with BDD acceptance criteria from vision, goals, or feedback
2. **Plan** — Create implementation plans with e2e tests from stories, optimized for autonomous execution
3. **Launch** — Execute plans via ralph-loop with superpowers discipline (TDD, debugging, verification)
4. **Review & Fix** — Create PRs, run multi-agent code review, fix issues automatically until clean

Every decision point that would normally pause for human input is resolved by dispatching **research + subject-matter-expert agents** instead.

## Prerequisites

These plugins must be installed:

| Plugin | Purpose |
|--------|---------|
| **ralph-loop** | Provides the while-true loop engine (Stop hook) |
| **superpowers** | Provides TDD, debugging, verification skills |
| **pr-review-toolkit** | Provides review agents (for review-fix command) |

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
```

**What happens:** Research agent searches for best practices, 2-3 SME agents brainstorm task decomposition and architecture, plan is written with complete TDD tasks, then validated by the plan-reviewer agent.

### `/super-ralph:launch`

Launch a ralph-loop to execute a plan.

```
/super-ralph:launch docs/plans/2026-02-15-auth-api.md
/super-ralph:launch docs/plans/2026-02-15-auth-api.md --max-iterations 30
/super-ralph:launch docs/plans/2026-02-15-auth-api.md --mode hybrid
```

**What happens:** Creates an isolated git worktree, reads the plan, validates it, constructs an execution prompt with superpowers integration and the autonomous decision pattern, then starts the ralph-loop inside the worktree.

### `/super-ralph:review-fix`

Create a PR and autonomously review and fix issues until clean.

```
/super-ralph:review-fix                           # Loop until clean
/super-ralph:review-fix --max-iterations 5        # Cap at 5 iterations
/super-ralph:review-fix --aspects errors tests    # Only specific aspects
/super-ralph:review-fix --pr 42                   # Review existing PR
```

**What happens:** Creates an isolated git worktree, creates PR (or uses existing), dispatches pr-review-toolkit agents, parses findings by severity, dispatches issue-fixer agent for Critical/Important issues, commits and pushes fixes, loops until no blocking issues remain.

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
  1. Dispatch research-agent (haiku) → web + codebase references
  2. Dispatch 1-3 sme-brainstormer agents (sonnet) → different angles
  3. Synthesize → pick most rational option based on evidence
  4. Document briefly → proceed immediately
```

This applies to: architecture choices, mode selection, error resolution, library selection, approach ambiguity, and any fork in the road.

## Plugin Structure

```
super-ralph/
├── .claude-plugin/
│   └── plugin.json
├── agents/
│   ├── research-agent.md      # Web + codebase research (haiku)
│   ├── sme-brainstormer.md    # Expert analysis from assigned angle (sonnet)
│   ├── plan-reviewer.md       # Validates plans for execution readiness
│   └── issue-fixer.md         # Fixes review findings autonomously
├── commands/
│   ├── design.md              # /super-ralph:design
│   ├── plan.md                # /super-ralph:plan
│   ├── launch.md              # /super-ralph:launch
│   ├── review-fix.md          # /super-ralph:review-fix
│   └── help.md                # /super-ralph:help
├── skills/
│   ├── product-design/
│   │   ├── SKILL.md
│   │   └── references/
│   │       ├── epic-template.md
│   │       ├── story-template.md
│   │       └── acceptance-criteria-guide.md
│   ├── ralph-planning/
│   │   ├── SKILL.md
│   │   └── references/
│   │       ├── plan-template.md
│   │       ├── prompt-standard.md
│   │       ├── prompt-hybrid.md
│   │       ├── autonomous-decision-pattern.md
│   │       └── superpowers-compatibility.md
│   └── review-fix-loop/
│       ├── SKILL.md
│       └── references/
│           ├── review-fix-prompt.md
│           └── severity-rules.md
├── scripts/
│   └── setup-ralph-loop.sh
└── README.md
```

## Worktree Isolation

Both `launch` and `review-fix` automatically create a git worktree before starting the ralph loop. This ensures:

- **No interference** with other Claude windows working in the same repo
- **Safe rollback** — delete the worktree if things go wrong
- **Parallel execution** — multiple ralph loops can run simultaneously on different features
- **Clean state** — each loop gets its own `.claude/ralph-loop.local.md`

Worktree location is selected autonomously (never prompts the user):
1. Use `.worktrees/` if it exists
2. Use `worktrees/` if it exists
3. Default to `.worktrees/` (auto-added to `.gitignore`)

| Command | Worktree Branch | Example Path |
|---------|----------------|--------------|
| `launch` | `super-ralph/<plan-slug>` | `.worktrees/auth-api/` |
| `review-fix` | Current or PR branch | `.worktrees/review-fix-feature-auth/` |
| `design` | No worktree needed | — |
| `plan` | No worktree needed | — |

## Severity Rules (Review-Fix)

| Severity | Blocks Completion | Examples |
|----------|-------------------|---------|
| **Critical** | Yes | Bugs, security issues, data loss, crashes |
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

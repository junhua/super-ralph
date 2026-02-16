# Superpowers Compatibility with Ralph Loop

Not all superpowers skills function correctly inside a ralph-loop. The key constraint: ralph-loop has NO conversation memory between iterations. The agent sees the same prompt every time and must discover progress from files and git history. Skills that require interactive discussion, human checkpoints, or persistent session state are incompatible.

## Compatible Skills

These skills work well inside ralph-loop and should be referenced in plan Skill Directives.

| Skill | Why It Works | Usage in Ralph |
|---|---|---|
| **superpowers:test-driven-development** | Purely mechanical TDD cycle. No human interaction needed. Progress is observable via test results and committed code. | Invoke for every task. The TDD cycle (write test, verify fail, implement, verify pass, commit) maps perfectly to ralph-loop's file-based progress tracking. |
| **superpowers:systematic-debugging** | Evidence-based debugging that reads code, forms hypotheses, tests them. All observable via files and command output. | Invoke when a test fails unexpectedly (not the planned RED failure). The debugging process is self-contained and leaves evidence in code changes. |
| **superpowers:verification-before-completion** | Runs commands and checks output. Purely mechanical verification. | Invoke before emitting the completion promise. Ensures the agent does not lie about completion status. Critical for ralph-loop integrity. |
| **superpowers:dispatching-parallel-agents** | Dispatches Task tool subagents that work independently. No session state dependency. | Use in hybrid mode to dispatch implementer subagents per task. Also useful in standard mode for parallel investigation when debugging. |

## NOT Compatible Skills

These skills should NEVER be referenced in ralph-loop plans. Including them will cause the agent to attempt workflows that cannot complete autonomously.

| Skill | Why It Fails | Alternative in Ralph |
|---|---|---|
| **superpowers:brainstorming** | Requires interactive discussion with the user. The brainstorming workflow asks questions, explores options collaboratively, and expects human feedback. Ralph has no human present. | Use the autonomous decision pattern instead: dispatch research-agent + sme-brainstormer agents. This achieves the same outcome (evaluating options) without human interaction. |
| **superpowers:writing-plans** | This is a meta-planning skill — it creates the plan that ralph executes. Using it inside ralph-loop creates a recursive loop (planning about planning). Plans should be written BEFORE entering ralph-loop. | Use super-ralph:ralph-planning to create the plan before launching the loop. The plan exists as a file that ralph reads. |
| **superpowers:executing-plans** | Designed for a different execution model: batch execution with human review checkpoints between batches. The skill explicitly says "stop and ask for help" when blocked, which is incompatible with autonomous execution. | Use the standard or hybrid execution prompt from ralph-planning instead. These prompts handle the same task execution but without human checkpoints. |
| **superpowers:subagent-driven-development** | Designed for interactive sessions where the orchestrator (user's session) dispatches subagents and reviews between tasks. Assumes a persistent orchestrator with conversation memory. In ralph-loop, the orchestrator resets every iteration. | Use hybrid mode execution prompt, which handles subagent dispatch within ralph-loop's constraints. The prompt includes progress discovery so the orchestrator can resume state each iteration. |
| **superpowers:using-git-worktrees** | Creates a worktree and switches to it. This setup state does not persist between ralph-loop iterations — the next iteration starts in the original directory. The worktree exists on disk, but the agent does not know to cd into it. | Work directly on a feature branch in the main worktree. Create the branch in the plan's first task: `git checkout -b feature/name`. Ralph-loop's stop hook runs in the project root, so the branch persists naturally. |
| **superpowers:finishing-a-development-branch** | Presents 4 options (merge, PR, keep, discard) and waits for human selection. Ralph has no human to select an option. | Handle branch completion in the plan's final task or as a post-ralph step. If a PR is desired, include `gh pr create` as the last task step. If merge is desired, include `git checkout main && git merge feature/name`. |

## Edge Cases

### requesting-code-review

**Partially compatible.** The skill dispatches a code-reviewer agent (which works autonomously), but then presents findings to the user for discussion. In ralph-loop, use the review-fix-loop skill instead, which handles review findings autonomously.

### using-superpowers

**Meta-skill — not directly invocable.** This skill describes how to use the superpowers system. It is reference documentation, not an executable workflow. No compatibility concern.

## Decision Matrix

When deciding whether to include a skill in a ralph plan's Skill Directives:

1. **Does the skill require human input at any point?** If yes, it is NOT compatible.
2. **Does the skill depend on conversation memory?** If yes, it is NOT compatible.
3. **Does the skill modify session state (working directory, environment variables)?** If yes, it is NOT compatible unless the state persists in files.
4. **Is the skill purely mechanical (read files, run commands, write files)?** If yes, it IS compatible.

When in doubt, the autonomous decision pattern can replace any interactive skill. Research + SME brainstormers can substitute for brainstorming. File-based progress tracking can substitute for conversation-based state.

# Using `/super-ralph:build` — Quick Reference

## What It Does

Executes an implementation plan autonomously in an isolated git worktree using ralph-loop + superpowers.

## How to Use

```bash
/super-ralph:build <plan-path> [--max-iterations N] [--mode standard|hybrid]
```

### Examples

```bash
# Execute plan with defaults from the plan file
/super-ralph:build docs/plans/2026-04-17-admin-module-activation.md

# Override iteration limit
/super-ralph:build docs/plans/my-feature.md --max-iterations 100

# Force hybrid mode (even if plan says standard)
/super-ralph:build docs/plans/my-feature.md --mode hybrid

# Both overrides
/super-ralph:build docs/plans/my-feature.md --max-iterations 100 --mode hybrid
```

## What Happens

1. **Worktree creation** — An isolated git worktree is created (`super-ralph/<feature>` branch)
2. **Plan reading** — The plan file is parsed to extract mode, iteration budget, and completion criteria
3. **Prompt construction** — An execution prompt is built (standard or hybrid mode)
4. **Ralph-loop launch** — The ralph-loop is initialized with the prompt
5. **Autonomous execution** — The orchestrator and implementers execute tasks until completion

## Plan File Format

Your plan file should have:

```markdown
# [Feature Name] — Implementation Plan

> **Executor:** super-ralph (autonomous)
> **Mode:** hybrid
> **Skills:** superpowers:test-driven-development, ...
> **Iteration Budget:** 65 max

## Completion Criteria

- [ ] Criterion 1
- [ ] Criterion 2
...
```

See `skills/ralph-planning/references/plan-template.md` for the full template.

## Troubleshooting

### Command doesn't execute

If the command prints the orchestrator prompt instead of starting the ralph-loop:
- Check that the skill is loaded: `/skill super-ralph:build` (if available)
- Verify plan file exists and is readable
- Check for syntax errors in plan file

### Iteration limit reached

If ralph-loop exits before completion:
- Increase `--max-iterations`: `/super-ralph:build <plan> --max-iterations 200`
- Check for BLOCKED.md file in repo root (explains what's blocking)
- Resume with `/super-ralph:build <plan>` — auto-detects progress and resumes

### Build hangs

If ralph-loop seems stuck:
- Wait 5 minutes (may be processing large tasks)
- Check git log for recent commits
- If no progress: press `Ctrl+C` and check BLOCKED.md

## After Completion

When the build completes:
1. All tasks are committed on the feature branch
2. Branch is pushed to origin
3. Review-fix cycle creates a PR (if not already open)
4. Verify phase tests the preview
5. Finalise phase merges to staging

The promise `ALL_TASKS_COMPLETE` indicates full success.

## See Also

- Plan creation: `/super-ralph:plan`
- Feature review: `/super-ralph:review-fix`
- Browser verification: `/super-ralph:verify`
- Release promotion: `/super-ralph:release`

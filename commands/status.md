---
name: status
description: "Show super-ralph runtime state — active ralph-loops, open worktrees, in-flight epics/stories, open PRs, stale runs"
argument-hint: "[--runs] [--worktrees] [--prs] [--epics] [--all]"
allowed-tools: ["Bash(git:*)", "Bash(gh:*)", "Bash(ls:*)", "Bash(cat:*)", "Bash(find:*)", "Read", "Glob", "Grep"]
---

# /super-ralph:status

Dashboard view of super-ralph runtime state. Answers:
- What's running right now?
- Which worktrees are active (and which are stale)?
- Which PRs are open and in what state (checks, reviews, mergeability)?
- Which epics/stories are in flight?
- Is there state in `/tmp/super-ralph-*` or `.claude/runs/` to resume?

## Arguments

- `--runs` — only show run state (temp dirs + ralph-loop state files)
- `--worktrees` — only show git worktrees
- `--prs` — only show open PRs on `super-ralph/*` branches
- `--epics` — only show in-flight EPICs and their sub-issue status
- `--all` — show everything (default if no flag given)

## Execution

### Step 0: Load Config

Read `.claude/super-ralph-config.md`. Extract `$REPO`, `$ORG`, `$PROJECT_NUM`, `$BE_DIR`, `$FE_DIR`.

### Step 1: Active Ralph-Loop State

Check for `.claude/ralph-loop.local.md` in:
- Current repo root
- All worktrees under `.claude/worktrees/`

For each found, extract: `active`, `max_iterations`, `completion_promise`, `iteration_count`.

```bash
for state in .claude/ralph-loop.local.md .claude/worktrees/*/.claude/ralph-loop.local.md; do
  [ -f "$state" ] || continue
  echo "=== $state ==="
  grep -E "^(active|max_iterations|completion_promise|iteration_count):" "$state"
done
```

### Step 2: Worktrees

```bash
git worktree list --porcelain
```

For each worktree:
- Branch name, path, HEAD commit
- Age (last commit timestamp)
- Uncommitted changes? (`git -C <path> status --porcelain | wc -l`)
- Stale? (no commit in >7 days OR no corresponding open PR)

### Step 3: Run State Directories

Check both old (`/tmp/`) and new (`.claude/runs/`) locations:
```bash
ls -dlt /tmp/super-ralph-* 2>/dev/null
ls -dlt .claude/runs/* 2>/dev/null
```

For each directory:
- Kind (design / story / e2e / repair)
- ID / slug
- Phase progress (read `progress.md`)
- Age

### Step 4: Open PRs on super-ralph/* Branches

```bash
gh pr list --repo $REPO --json number,title,headRefName,state,mergeable,statusCheckRollup,reviewDecision \
  --jq '[.[] | select(.headRefName | startswith("super-ralph/"))]'
```

For each:
- PR #, title, branch
- Checks: passing / failing / pending
- Review state: approved / changes requested / pending
- Mergeable: yes / conflicts / unknown

### Step 5: In-Flight Epics and Stories

```bash
# Open EPICs
gh issue list --repo $REPO --label "epic" --state open --json number,title,labels,milestone

# For each: count open sub-issues
gh issue list --repo $REPO --search "parent:#$EPIC_NUM is:open" --json number,title,state
```

Show: EPIC #, title, milestone, open/closed sub-issue counts, % complete.

### Step 6: Stale / Orphan Detection

Flag items that need cleanup:
- Worktrees with no commits in >14 days AND no open PR
- `/tmp/super-ralph-*` dirs older than 3 days with `status: FAILED` or no `progress.md`
- Branches pushed to remote but never opened as PR (>3 days)
- Closed issues with active worktrees (finalise didn't clean up)

### Step 7: Present Summary

Print a table-based dashboard:

```
┌─ Super-Ralph Status ─────────────────────────────────────────┐
│                                                              │
│ ACTIVE RUNS                                                  │
│   • ralph-loop: 3 (in build/review-fix/release phases)       │
│   • /tmp runs:  2                                            │
│                                                              │
│ WORKTREES (5)                                                │
│   ✓ super-ralph/admin-activation   feat-branch   2h  clean   │
│   ⚠ super-ralph/old-feature        (stale)      14d  +3 uncommitted │
│   ...                                                        │
│                                                              │
│ OPEN PRs (3)                                                 │
│   #512 admin-activation       CI ✓  review ⏳  mergeable     │
│   #515 test-suite-fix         CI ✗  review —   conflicts     │
│   ...                                                        │
│                                                              │
│ EPICS IN FLIGHT                                              │
│   #261 Finance & Accounting    4/7 shipped  milestone v0.8   │
│   #241 Sales/CRM               3/5 shipped  milestone v0.8   │
│                                                              │
│ ⚠ CLEANUP SUGGESTED                                          │
│   • 2 stale worktrees (>14d no commits)                      │
│   • 1 temp dir >7d with FAILED status                        │
│   • Run /super-ralph:cleanup to remove                       │
└──────────────────────────────────────────────────────────────┘
```

## Rules

- **Read-only.** `/status` never modifies state — no merges, no deletes.
- **Fast.** Use jq/grep over heavy Python. Aim for <5 seconds.
- **Clear cleanup hints.** Point to `/super-ralph:cleanup` (future command) or manual commands when stale state is found.
- **Use config.** All repo/org/paths come from `.claude/super-ralph-config.md`.
- **Resilient to missing data.** If `.claude/runs/` doesn't exist, show `/tmp/` only. If no open PRs, say "no PRs". Don't error.

## See Also

- `/super-ralph:init` — generate the config
- `/super-ralph:e2e` — orchestrate a full epic
- `/super-ralph:build-story` — single-story flow
- `/super-ralph:release` — promote staging to main

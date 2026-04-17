---
name: cleanup
description: "Prune stale super-ralph worktrees, run-state directories, and orphan branches"
argument-hint: "[--dry-run] [--age-days N] [--force]"
allowed-tools: ["Bash(git:*)", "Bash(gh:*)", "Bash(rm:*)", "Bash(ls:*)", "Bash(find:*)", "Read", "Glob"]
---

# /super-ralph:cleanup

Purge stale super-ralph state. Complements `/super-ralph:status` (which only reports).

## Arguments

- `--dry-run` — list what would be removed without deleting (default: off — **interactive mode** asks before each delete)
- `--age-days N` — only consider items older than N days (default: 7)
- `--force` — skip interactive prompts (requires `--age-days` for safety)

## What Gets Cleaned

### 1. Stale Run-State Directories

Directories under `.claude/runs/` and `/tmp/super-ralph-*/` that are:
- Older than `--age-days` (default: 7 days)
- Have `progress.md` showing all phases DONE (successful runs with no need to resume)
- OR have `progress.md` showing FAILED status with no updates in the age window

### 2. Stale Worktrees

Worktrees under `.claude/worktrees/super-ralph*/` or any git worktree with a branch prefixed `super-ralph/` that:
- Have no commits in the last `--age-days` days
- AND have no open PR
- OR have a closed/merged PR (cleanup after finalise)

### 3. Orphan Branches

Local and remote branches prefixed `super-ralph/` that:
- Are not checked out in any worktree
- Have no open PR
- Are fully merged into `staging` OR have been abandoned (no commits in `--age-days`)

## Execution

### Step 0: Load Config

Read `.claude/super-ralph-config.md`. Extract `$REPO`.

### Step 1: Enumerate Candidates

```bash
AGE_DAYS=${AGE_DAYS:-7}
AGE_SEC=$((AGE_DAYS * 86400))
NOW=$(date +%s)

# Run state dirs
for dir in .claude/runs/*/ /tmp/super-ralph-*/; do
  [ -d "$dir" ] || continue
  MTIME=$(stat -f %m "$dir" 2>/dev/null || stat -c %Y "$dir" 2>/dev/null)
  AGE=$((NOW - MTIME))
  if [ $AGE -gt $AGE_SEC ]; then
    echo "STALE_RUN: $dir (${AGE}s old)"
  fi
done

# Worktrees
git worktree list --porcelain | awk '/^worktree /{print $2}' | while read -r wt; do
  case "$wt" in
    */super-ralph*)
      # Check last commit
      LAST_COMMIT_TS=$(git -C "$wt" log -1 --format=%ct 2>/dev/null || echo 0)
      AGE=$((NOW - LAST_COMMIT_TS))
      if [ $AGE -gt $AGE_SEC ]; then
        echo "STALE_WORKTREE: $wt (last commit ${AGE}s ago)"
      fi
      ;;
  esac
done

# Orphan branches
git branch -a | grep -E "super-ralph/" | while read -r branch; do
  # Check open PR
  PR=$(gh pr list --repo "$REPO" --head "$branch" --state open --json number --jq '.[0].number' 2>/dev/null)
  if [ -z "$PR" ]; then
    # Check last activity
    LAST_TS=$(git log -1 --format=%ct "$branch" 2>/dev/null || echo 0)
    AGE=$((NOW - LAST_TS))
    if [ $AGE -gt $AGE_SEC ]; then
      echo "ORPHAN_BRANCH: $branch (last commit ${AGE}s ago, no open PR)"
    fi
  fi
done
```

### Step 2: Confirm (unless `--force`)

For each candidate, print what will happen and ask for confirmation (unless `--dry-run` or `--force`):

```
STALE_RUN: /tmp/super-ralph-story-42 (14 days old, status: FAILED)
Remove? [y/N]
```

If `--dry-run`: print candidates, do NOT delete.
If `--force`: delete without asking.

### Step 3: Delete

```bash
# Run state
rm -rf "$STALE_DIR"

# Worktree
git worktree remove --force "$STALE_WT"

# Branch (local and remote)
git branch -D "$ORPHAN_BRANCH"
gh api --method DELETE "repos/$REPO/git/refs/heads/$ORPHAN_BRANCH" 2>/dev/null
```

### Step 4: Report

```
Super-Ralph Cleanup Summary
  Run-state dirs removed: 3
  Worktrees removed:      2
  Branches removed:       1
  Skipped (too recent):   4
```

## Safety Rules

- **NEVER remove** a worktree/branch/dir with unmerged changes or an open PR.
- **NEVER delete** branches merged into `main` without a tag (they may be release history).
- **NEVER delete** the current branch or the current worktree.
- **Confirm interactively** unless `--force` + `--age-days` both set.
- **Dry-run is safe.** No network calls that modify state; no filesystem writes.

## See Also

- `/super-ralph:status` — see what's active without modifying
- `/super-ralph:finalise` — normal "single PR shipped" cleanup path
- `git worktree remove` — manual cleanup for one item

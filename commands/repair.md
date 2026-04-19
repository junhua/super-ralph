---
name: repair
description: "Fix bugs, improve features, or modify UI from GitHub issues, text, screenshots, or URLs"
argument-hint: "<#issue|description> [--screenshot PATH] [--url URL] [--hotfix] [--no-pipeline] [--skip-verify] [--skip-finalise]"
allowed-tools: ["Bash(git:*)", "Bash(gh:*)", "Bash(bun:*)", "Bash(mkdir:*)", "Bash(cat:*)", "Bash(rm:*)", "Bash(date:*)", "Bash(test:*)", "Read", "Write", "Edit", "Glob", "Grep", "Task", "WebSearch", "WebFetch"]
---

# Super-Ralph Repair Command

Fast-track reactive workflow for bug fixes, feature modifications, and UI changes. Skips the full design/plan cycle — goes straight from problem to implementation with TDD. After the fix, automatically chains through review-fix, verify, and finalise to merge.

**Two merge paths:**
- **Default:** fix → review-fix → verify → finalise (merge to **staging**)
- **Hotfix:** fix → review-fix → verify → finalise (merge to **main**) → backport to staging

## Arguments

- **#N** (optional): GitHub issue number — fetched with `gh issue view N --repo $REPO`.
- **Text description** (optional): Free-form problem statement used as codebase search query.
- **`--screenshot`** (optional): Path to image showing the visual issue.
- **`--url`** (optional): URL to inspect via claude-in-chrome.
- **`--hotfix`** (optional): Branch from `main`, PR targets `main`, auto-backport to `staging` after merge. Use for production-critical bugs and security fixes.
- **`--no-pipeline`** (optional): Skip review-fix/verify/finalise — only implement the fix and report.
- **`--skip-verify`** (optional): Skip browser verification in the pipeline.
- **`--skip-finalise`** (optional): Stop at PR creation, don't merge.

At least one of `#N` or text description must be provided.

## Workflow

Execute the 10-step repair procedure defined by the `super-ralph:repair-domains` skill. **NEVER ask the user for input** — use research + SME agents for all decisions.

### Step 0: Load Project Config & Skills

Read `.claude/super-ralph-config.md` to load every `$VARIABLE` used by the skill and its references (same set as `/super-ralph:build-story`, plus `$MAIN_BRANCH` / `$STAGING_BRANCH` for the hotfix path).

Invoke:
- **`super-ralph:repair-domains`** — domain detection (frontend / backend / devops / cloud-infra / security) + end-to-end repair flow
- **`super-ralph:story-execution`** — Phase 3 (review-fix) and Phase 4 (verify) patterns reused here
- **`super-ralph:release-flow`** — Flow A (per-PR finalise) used as the merge path

### Step 1: Execute the 10-Step Repair Flow

Follow `${CLAUDE_PLUGIN_ROOT}/skills/repair-domains/references/repair-flow.md`:

1. Parse input (issue / text / screenshot / URL) and gather context
2. Detect domain(s) and hotfix mode (see `domain-patterns.md` for signatures)
3. Research the problem with domain-specific search patterns
4. Create worktree (branch from `staging` by default, from `main` if `--hotfix`)
5. Implement fix with TDD (RED → GREEN → commit)
6. Pipeline — review-fix (delegates to review-fix command; see `../review-fix-loop/`)
7. Pipeline — verify (delegates to `browser-verification` skill; skipped if `--skip-verify`)
8. Pipeline — finalise (delegates to `release-flow` skill Flow A; skipped if `--skip-finalise`)
9. Hotfix backport (only if `--hotfix`) — see `hotfix-backport.md`
10. Report

### Step 2: Resume Detection

On re-invoke with the same arguments, the orchestrator detects prior run-state from `.claude/runs/repair-<slug>/progress.md` and resumes from the appropriate step. Full table: `${CLAUDE_PLUGIN_ROOT}/skills/repair-domains/references/repair-flow.md` § "Resume Detection".

## Critical Rules

- **Domain detection drives research.** Wrong domain → wrong files searched. Always run Step 2 domain detection before jumping to implementation.
- **Hotfix path is protected.** `--hotfix` branches from `main` and PRs into `main` — only use for production-critical fixes. Always backports to staging after merge.
- **Never force-push to main or staging.** The hotfix path MUST create a normal PR and squash-merge.
- **`--no-pipeline` is an escape hatch, not the default.** Skipping review/verify/finalise leaves the fix unmerged and uncleaned; use only when you intend to finish manually.
- **Repair reuses story-execution phases.** Don't re-implement review-fix or verify logic inline — always delegate through the skill references.
- **Screenshots + URLs are first-class inputs.** If the user provides either, they MUST be inspected in Step 1 before domain detection (UI issues often look like backend issues until you see the screen).

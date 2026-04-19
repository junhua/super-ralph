---
name: release-flow
description: "Handle per-story finalise (merge PR + cascade-close parents + worktree cleanup) and release promotion (staging → main with Codex review + version seal). Triggers when /super-ralph:finalise or /super-ralph:release is invoked, or when the user mentions 'finalise', 'finalize', 'merge and close', 'ship the story', 'release', 'promote to main', 'cut a release', 'version bump', 'tag and ship', 'staging to main', 'close epic on merge', 'cascade close', 'worktree cleanup'."
---

> **Config:** Project-specific values (paths, repo, team, main/staging branch names, deployment URLs) are loaded from `.claude/super-ralph-config.md`.

# Release Flow — Per-Story Finalise + Release Promotion

## Overview

Two distinct but related flows, unified in one skill because they share git/board/deployment mechanics:

| Flow | Command | Scope | When |
|------|---------|-------|------|
| **Per-story finalise** | `/super-ralph:finalise` | One PR → merged, board updated, parents cascade-closed, worktree cleaned | After a PR is approved + CI green |
| **Release promotion** | `/super-ralph:release` | Staging → main → tagged version | When a Milestone is feature-complete and UAT-approved |

**Announce at start (finalise):** "I'm using the release-flow skill to merge this PR, cascade-close parent issues, and clean up."
**Announce at start (release):** "I'm using the release-flow skill to promote staging to main with QA + Codex review + version seal."

**Core insight:** These are different *scopes* but share the same *mechanics*. Both need careful git hygiene (never force-push shared branches, never delete un-merged work), both need board consistency (status must reflect reality), and both need deployment verification (merge ≠ ship — the CD pipeline must actually succeed). Keeping them in one skill keeps those invariants consistent.

## Flow A: Per-Story Finalise

Use when a single story's PR is ready to land on staging. The full 8-step procedure lives in **`references/finalise-flow.md`**.

Outline:

1. **Identify context** — find the PR from branch or argument; extract linked issue numbers from the PR body (`Closes #N`).
2. **Merge PR** — squash-merge to staging via `gh pr merge --squash --delete-branch`. Never force-push.
3. **Verify deployment health** — poll Vercel CD status until success; if deploy fails, DO NOT mark issue shipped, report failure instead.
4. **Close related GitHub issues** — the linked `Closes #N` closes automatically; cascade-close the parent `[STORY]` when all `[BE]/[FE]/[INT]` children closed; cascade-close the `[EPIC]` when all `[STORY]` children closed.
5. **Update plan status** (for stories with a `docs/plans/` plan doc) — mark plan task as completed.
6. **Update epic story status** — in local mode, flip `**Status:** PENDING` → `**Status:** COMPLETED` in the epic file; in GitHub mode, the issue close handles this.
7. **Update roadmap** — bump milestone progress, update module status if all module epics shipped.
8. **Worktree & branch cleanup** — `git worktree remove` the worktree, delete the local feature branch, prune tracking refs.

After Step 8, emit a summary and suggest next steps (another story to build, a release to cut, etc.).

## Flow B: Release Promotion

Use when a milestone is UAT-approved and ready to ship to production. The full 10-phase procedure lives in **`references/release-flow.md`**.

### Branch Model

- **`staging`** — default branch, receives all feature PRs
- **`main`** — production branch, only staging gets promoted here

Promotion is a protected operation. It requires:
- All staging deployments healthy
- All open `[QA]` issues closed
- Codex-review PASS on the staging→main diff

### 10 phases (see `references/release-flow.md`)

1. **Identify release context** — current milestone, version bump type (major/minor/patch)
2. **Pre-flight checks** — dirty working tree? Uncommitted changes? Staging green?
3. **QA verification on staging** — browser smoke test, full regression tests, API contract check, AC audit across milestone stories
4. **Evaluate & fix** — if QA surfaces regressions, open `[FIX]` issues and halt; do not proceed with a red QA
5. **Release documentation** — CHANGELOG entry, release notes draft, version bump in `plugin.json` / `package.json` / VERSION
6. **Create staging → main PR** — with release notes in the body
7. **Codex review** — dispatch Codex review agent for a second opinion on the diff; BLOCK if Codex returns Critical findings
8. **Merge to main** — squash-merge after Codex clean; no force-push
9. **Verify production deployment** — poll CD until healthy; if RED, open an incident `[FIX]` and begin rollback procedure per the release reference
10. **Seal version** — create git tag, attach release notes, close the Milestone
11. **Sync staging** — rebase staging on main to keep them in lockstep
12. **Cleanup** — prune stale branches, archive run-state dirs

(Phase numbering in the reference uses 1–10, with 7b and 9 handling deployment health; the above list summarizes the conceptual flow.)

## Shared Mechanics

Both flows rely on the same primitives:

### Git mechanics (never destructive)

- `gh pr merge --squash --delete-branch` — merge with commit squash, auto-delete feature branch on success
- Never `git push --force` to shared branches (staging, main). A staging rewrite breaks every open worktree on the team.
- `git worktree remove <path>` — only after merge confirmed; do not `cd` into a worktree then remove it (kills the shell state).
- Delete tracking branches via `git branch -D` only when the branch is fully merged or the user explicitly asked.

### Board mechanics

- On merge, the `Closes #N` syntax auto-closes the referenced issue. The board hook moves the item to Shipped.
- **Cascade close:** when all `[BE]`/`[FE]`/`[INT]` children of a `[STORY]` are closed, close the `[STORY]`. When all `[STORY]` children of an `[EPIC]` are closed, close the `[EPIC]`.
- See `../issue-management/references/gh-invocation-patterns.md` § "Issue Lifecycle Transitions" for exact `gh` commands.

### Deployment health verification

- Poll Vercel (or equivalent CD) status after merge until success or 10-minute timeout.
- On failure: do NOT mark work as shipped. Report the failure with a link to the deployment logs, and open a `[FIX]` incident if the regression is serious.
- See `../deployment-verification/SKILL.md` for the canonical health-check procedure.

## Critical Rules

- **Never force-push to staging or main.** Full stop. A rewrite breaks every open worktree.
- **Merge success ≠ shipped.** Always verify CD health before marking issues Shipped.
- **Cascade close is automatic only for merge-linked issues.** `[STORY]`/`[EPIC]` closures require explicit cascade logic (Step 4 of finalise, Phase 10 of release).
- **Codex review is a hard gate on releases.** Never promote staging → main with Critical findings outstanding.
- **Version seal is the final step.** Tag creation + Milestone close + release notes must be atomic — if any fails, rollback to before the merge if possible.
- **Worktree cleanup is last.** Never `cd` into a worktree and then `git worktree remove` it — the shell state dies.
- **QA issues block releases.** Any open `[QA]` against the milestone blocks promotion. Close all or pull them out of the milestone.

## References

- `references/finalise-flow.md` — 8-step per-story finalise procedure (merge, cascade-close, epic Status update, roadmap, worktree/branch cleanup)
- `references/release-flow.md` — 10-phase staging → main promotion (pre-flight, QA, Codex review, merge, production verify, version seal, sync staging, cleanup)

### Sibling skills

- `../issue-management/SKILL.md` — Board mechanics, cascade-close rules
- `../issue-management/references/gh-invocation-patterns.md` — Exact `gh` commands for lifecycle transitions
- `../deployment-verification/SKILL.md` — CD health check procedure used in finalise Step 3 and release Phase 7b
- `../story-execution/SKILL.md` — The skill whose Phase 5 calls `/super-ralph:finalise`
- `../browser-verification/SKILL.md` — Backs QA verification in release Phase 2a

# Phase 5: Finalise Sub-Agent

> Canonical spec for Phase 5 of `/super-ralph:build-story` — merge the PR, update
> the project board, cascade-close parent `[STORY]`/`[EPIC]` when all children
> closed. Skipped when `--skip-finalise` is passed.
>
> The merge + deploy-verify + cascade-close + worktree-cleanup procedure is
> **owned by the `release-flow` skill's `finalise-flow.md` reference**. This
> file documents only the Phase-5-specific wrapper (inputs, result-file write,
> local-mode epic Status update, summary).

## Inputs

Phase 5 reads:
- `$STORY_DIR/context.md` — story identity
- `$STORY_DIR/review-result.md` — PR number, branch, iterations
- `$STORY_DIR/verify-result.md` (if Phase 4 ran) — verdict + criteria results

## Skip condition

If `--skip-finalise` is passed, write `$STORY_DIR/final-result.md` with `status: SKIPPED` and emit a note in the summary: "PR left open for manual finalise."

## Delegation

Execute the canonical 8-step per-story finalise flow from
`${CLAUDE_PLUGIN_ROOT}/skills/release-flow/references/finalise-flow.md`:

| Step | Purpose |
|------|---------|
| 1 | Identify context (PR, linked issues, plan file, story ref) |
| 2 | Merge PR (`gh pr merge --squash --delete-branch`) |
| 3 | Verify deployment health (delegates to `../../deployment-verification/SKILL.md`) |
| 4 | Cascade-close linked `[STORY]` → `[EPIC]` issues |
| 5 | Update plan file task status |
| 6 | Update epic story Status |
| 7 | Update roadmap |
| 8 | Worktree & branch cleanup |

## Phase-5 local-mode addendum

In local mode (`$MODE = local`), after Step 4's cascade-close equivalent, also flip the story block's `**Status:** PENDING` → `**Status:** COMPLETED` in `$EPIC_FILE`:

```bash
EPIC_FILE="${STORY_REF%%#*}"
${CLAUDE_PLUGIN_ROOT}/scripts/parse-local-epic.sh set-status "$EPIC_FILE" "$STORY_NUM" COMPLETED
git add "$EPIC_FILE"
git commit -m "epic: mark story-${STORY_NUM} COMPLETED"
```

## Write `final-result.md`

After the delegated flow completes, write `$STORY_DIR/final-result.md`:

```
phase: finalise
status: DONE | SKIPPED | FAILED
pr_number: <N>
merge_sha: <sha> | null
deploy_status: healthy | failed | skipped
deploy_url: <URL> | null
closed_issues: [#A, #B, ...]
cascade_closed: [story: #S, epic: #E] | []
epic_status_updated: true | false   # local mode only
```

## Summary (end-of-flow report template)

After Phase 5 completes, emit the final summary covering ALL five phases:

```markdown
## Story $STORY_ID: $STORY_TITLE

| Phase | Status | Notes |
|-------|--------|-------|
| Plan | DONE (mode: <embedded/standard/hybrid>) | task_count: <N> |
| Build | DONE | <X passed, Y failed> |
| Review-Fix | DONE | PR #<N>, <K> iterations |
| Verify | <DONE/SKIPPED/RED> | <verifier verdict or "skipped"> |
| Finalise | <DONE/SKIPPED/FAILED> | merged: <sha>, deploy: <healthy/failed> |

### Closed Issues
- Story: #<N> <title>
- Sub-issues: #<A> [BE], #<B> [FE], #<C> [INT]
- Parent epic: #<E> (closed, all stories shipped) | (still open, N stories remaining)

### Next
<suggestion: another story to build, a release to cut, etc.>
```

## Failure handling

| Failure | Handling |
|---------|----------|
| Merge conflict surfaced at step 2 | Do NOT force; report the conflict and leave the PR open |
| CD fails at step 3 | Do NOT cascade-close; open an incident `[FIX]` and write `final-result.md` with `status: FAILED` |
| Cascade-close fails at step 4 | Retry once; on second failure, report and continue (the linked `Closes #N` already ran) |
| Worktree cleanup fails at step 8 | Log and continue; do not block the summary (cleanup can be re-run via `/super-ralph:cleanup`) |

---
name: deployment-verification
description: Verify that a Vercel (or similar) CD deployment completed successfully and the deployed app is healthy. Use after merging to staging/main, promoting via /super-ralph:release, or after /super-ralph:finalise. Triggers on 'verify deployment', 'check deploy status', 'wait for CD', 'is staging live', 'deployment healthy', 'production deploy verify'. Prevents declaring a task done when the build or runtime is broken.
---

# Deployment Verification Skill

Wait for a Vercel (or similar) CD pipeline to complete and verify the deployed application is healthy.

**Announce at start:** "Verifying deployment via the deployment-verification skill."

## When to Use

- After merging a PR into **staging** (preview deploy)
- After promoting to **main** via `/super-ralph:release`
- After `/super-ralph:finalise` claims a branch is shipped
- Whenever a command needs to know: "is the deploy actually live and healthy?"

Merge success != deployment success. Never declare shipping complete without verifying the deploy.

## Inputs

- `REF` — git ref to check deployment for (usually `staging` or `main`)
- `URL` — the URL to health-check after deploy succeeds
- `TIMEOUT_SECONDS` — max wait time (default 360 = 6 minutes)
- `POLL_SECONDS` — poll interval (default 10)
- `REPO` — GitHub repo (e.g., `Forth-AI/work-ssot`)

## Verification Procedure

### 1. Poll GitHub Deployment Statuses

Every `POLL_SECONDS`, query the latest deployment for the given ref and read its state.

```bash
POLLS=$((TIMEOUT_SECONDS / POLL_SECONDS))
DEPLOY_STATE=""
for i in $(seq 1 $POLLS); do
  STATUS_URL=$(gh api repos/$REPO/deployments \
    --jq "[.[] | select(.ref==\"$REF\")] | first | .statuses_url" 2>/dev/null)
  if [ -n "$STATUS_URL" ] && [ "$STATUS_URL" != "null" ]; then
    STATE=$(gh api "$STATUS_URL" --jq '.[0].state' 2>/dev/null)
    case "$STATE" in
      success)         DEPLOY_STATE="HEALTHY"; break ;;
      error|failure)   DEPLOY_STATE="FAILED"; break ;;
    esac
  fi
  sleep $POLL_SECONDS
done
```

After the loop:
- If `DEPLOY_STATE=""` → `PENDING` (timed out)
- Report accordingly

### 2. HTTP Health Check

Only if `DEPLOY_STATE=HEALTHY`, also curl the URL:

```bash
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 15 "$URL")
case "$HTTP_STATUS" in
  2*|3*)  DEPLOY_STATE="HEALTHY" ;;
  *)      DEPLOY_STATE="UNHEALTHY_HTTP_$HTTP_STATUS" ;;
esac
```

### 3. Emit Status

Write (or return) a structured result:
```
deploy_ref: $REF
deploy_url: $URL
deploy_state: HEALTHY | FAILED | PENDING | UNHEALTHY_HTTP_<code>
polls_used: <N> of <POLLS>
final_state: <STATE>
http_status: <code>
```

## Failure Responses

- **FAILED** — CD pipeline reported `error` or `failure`. Read build logs (gh API or Vercel dashboard) and report the root cause. Do NOT mark the task as done.
- **PENDING** — timed out waiting. Warn the user and suggest manual verification. Do NOT mark as done.
- **UNHEALTHY_HTTP_*** — deploy built but app returns 5xx or unexpected 4xx. Investigate and report. Do NOT mark as done.
- **HEALTHY** — everything good. Proceed.

## Why This Is a Skill, Not Inline Bash

Four separate commands (`/finalise`, `/build-story`, `/e2e`, `/release`) each had a copy of a ~20-line bash poll loop. When the loop needed a fix (e.g., the `null` filter), we had to patch four places. This skill is the single source of truth. Commands now delegate:

```markdown
Delegate to the deployment-verification skill with:
  REF=staging
  URL=https://preview.forthai.work  # or $APP_URL from config
  TIMEOUT_SECONDS=360
```

## Rules

- **Never claim done on FAILED or PENDING.** The rule `.claude/rules/deployment-verification.md` is load-bearing.
- **Always health-check**, not just GitHub status. CD can report success while the runtime errors.
- **Report the specific state.** "Deploy failed" is useless. "Build step failed at `bun run build` step, exit code 1" is actionable.
- **Use `$REPO` from config.** Never hardcode `Forth-AI/work-ssot`.

## See Also

- `.claude/rules/deployment-verification.md` — the project rule this enforces
- `${CLAUDE_PLUGIN_ROOT}/commands/release.md` — production promotion that uses this
- `${CLAUDE_PLUGIN_ROOT}/commands/finalise.md` — staging finalise that uses this

### Sibling skills

- `../release-flow/SKILL.md` — `finalise-flow.md` Step 2a and `release-flow.md` Phase 7b both delegate to this skill
- `../story-execution/SKILL.md` — `phase-5-finalise.md` delegates to this skill via the release-flow procedure
- `../browser-verification/SKILL.md` — CD health and runtime health are complementary; both must pass

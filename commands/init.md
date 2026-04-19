---
name: init
description: "Auto-detect project structure and generate .claude/super-ralph-config.md for all super-ralph commands"
argument-hint: "[--force]"
allowed-tools: ["Bash(git:*)", "Bash(gh:*)", "Bash(ls:*)", "Bash(jq:*)", "Bash(cat:*)", "Bash(head:*)", "Bash(wc:*)", "Read", "Write", "Glob", "Grep"]
---

# Super-Ralph Init Command

Generate `.claude/super-ralph-config.md` by introspecting the current project. All other super-ralph commands depend on this config file. This command runs automatically on first use of any super-ralph command — you should not need to invoke it manually.

**This command is fully autonomous.** Do NOT ask the user for input at any point. Every value is detected or left blank; the user edits the config file to fill in anything the detector couldn't resolve.

## Arguments

- **`--force`**: Regenerate config even if it already exists (overwrites every value).

## Workflow

Invoke the `super-ralph:init-setup` skill and execute its 5-step workflow:

1. **Guard** — Refuse if `.claude/super-ralph-config.md` already exists and `--force` was NOT passed.
2. **Prereq check** — Confirm `gh auth status` succeeds. If unauthenticated, tell the user to run `gh auth login` and stop.
3. **Detect** — Follow `${CLAUDE_PLUGIN_ROOT}/skills/init-setup/references/detection-procedures.md` to populate every `$VARIABLE` (repo, runtime, project board, backend, frontend, app URL, team).
4. **Write** — Render `${CLAUDE_PLUGIN_ROOT}/skills/init-setup/references/config-template.md` with detected values and write to `.claude/super-ralph-config.md`.
5. **Report** — Emit a summary table of what was detected and what was left blank for manual review.

## Critical Rules

- **Never ask for input.** No `--interactive` mode. Blank values are fine — the user edits the file to fill in anything the detector couldn't resolve.
- **Empty over wrong.** Better to leave a field blank than to guess a path. Downstream commands treat blank as a signal to prompt the user at invocation time.
- **Use `none`, not blank, for "not applicable"** — project board, frontend, i18n can have `none` as a value. Downstream commands branch on `none` vs. `<path>`.
- **Non-destructive on failure.** If any detection step crashes, still write a partial config with blanks for the missed sections. Report which sections failed so the user can fill them in.

## Next Steps After Init

- `/super-ralph:design "[topic]"` — Create your first epic
- `/super-ralph:plan "[task]"` — Plan an ad-hoc fix or chore
- `/super-ralph:status` — Verify the config loads cleanly

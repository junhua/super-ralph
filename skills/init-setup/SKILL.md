---
name: init-setup
description: "Auto-detect project structure and generate .claude/super-ralph-config.md from introspection. Use when /super-ralph:init is invoked, or when user asks to 'set up super-ralph', 'generate config', 'initialize plugin config', 'bootstrap super-ralph', or when another super-ralph command detects missing config and dispatches init as a prerequisite."
---

# Init Setup Skill

Introspect a repository and generate `.claude/super-ralph-config.md` — the file that supplies every `$VARIABLE` used by the rest of the super-ralph plugin (`$REPO`, `$RUNTIME`, `$BE_DIR`, `$SCHEMA_FILE`, `$APP_URL`, `$PROJECT_NUM`, etc.).

**Announce at start:** "Using the init-setup skill to detect project structure and generate super-ralph config."

## When This Runs

- **Explicit:** `/super-ralph:init` or `/super-ralph:init --force`
- **Implicit:** another super-ralph command (e.g., `/design`, `/plan`) detected missing config and ran init as a prerequisite

## Invocation

```
/super-ralph:init [--force]
```

- Without `--force`: refuses if `.claude/super-ralph-config.md` already exists.
- With `--force`: regenerates, overwriting every value.

## Autonomy Contract

- **NEVER ask the user for input.** Every value is detected via file inspection, `gh` CLI, or convention. If a value cannot be detected, leave it blank — the user edits the config to fill it in later.
- **Write, don't preview.** Detected values go directly into the config file. No pause-for-confirmation. The command is fire-and-forget.

## Workflow

Execute these steps in order. Skip any step whose prerequisite isn't met (e.g., skip project-board detection if `gh` CLI isn't authenticated for the target org).

### 1. Guard

If `.claude/super-ralph-config.md` already exists and `--force` was NOT passed, report `Config already exists at .claude/super-ralph-config.md. Use /super-ralph:init --force to regenerate.` and stop.

### 2. Prerequisite Check

```bash
gh auth status
```

If unauthenticated, tell the user: `gh CLI not authenticated. Run \`gh auth login\` then re-run /super-ralph:init.` and stop. This is a tool-setup prompt, not an autonomy violation — we cannot detect GitHub state without auth.

### 3. Detect

Follow `references/detection-procedures.md` end-to-end. It specifies the exact `gh`, `glob`, `grep`, and `bash` invocations for each section:

1. Repository (`$REPO`, `$ORG`)
2. Runtime (`$RUNTIME`)
3. Project Board (`$PROJECT_NUM`, `$PROJECT_ID`, `$STATUS_*`)
4. Backend (`$BE_DIR`, `$SCHEMA_FILE`, `$ROUTE_REG_FILE`, `$BE_*_DIR`, `$BE_TEST_CMD`)
5. Frontend (`$FE_DIR`, `$TYPES_FILE`, `$API_CLIENT_DIR`, `$I18N_*_FILE`, `$FE_*_DIR`, `$FE_TEST_CMD`)
6. App URL (`$APP_URL`)
7. Team (`$PM_USER`, `$TECH_LEAD`, `$TESTERS`)

### 4. Write

Render `references/config-template.md` by substituting each `<detected>` placeholder with the corresponding detected value. Write to `.claude/super-ralph-config.md`.

### 5. Report

Emit a compact summary table:

```markdown
## Super-Ralph Init Complete

Config written to `.claude/super-ralph-config.md`.

| Section | Status |
|---------|--------|
| Repository | `$REPO` |
| Project Board | detected / none |
| Backend | `$BE_DIR` |
| Frontend | `$FE_DIR` or none |
| Runtime | `$RUNTIME` |

**Values left blank for manual review:**
- [list any fields with empty values]

Edit `.claude/super-ralph-config.md` to adjust. Regenerate with `/super-ralph:init --force`.
```

## Critical Rules

- **Autonomous writing.** No `--interactive` flag. No pause-for-review step. Detect → write → report.
- **Empty over wrong.** If detection is uncertain, leave the field blank (empty backticks `` ` ` ``). A wrong value is worse than a blank one because downstream commands will silently use the wrong path.
- **`none` for "not applicable".** Project-board and frontend fields use the literal string `none` when they don't apply, not empty strings — downstream commands check for `none` explicitly to branch logic.
- **One source of truth.** All detected values go into `.claude/super-ralph-config.md`. Do NOT write detected values into CLAUDE.md, `.env`, or elsewhere.
- **Non-destructive on failure.** If any detection step crashes, still write the partial config with blanks for the missed sections. Never leave the repo half-initialized.

## References

- `references/detection-procedures.md` — Step-by-step detection logic for every section (exact `gh` / `glob` / `grep` / `bash` invocations and the heuristic priority order).
- `references/config-template.md` — The authoritative markdown template for `.claude/super-ralph-config.md`.

### Sibling skills

- Every other super-ralph skill reads the generated config's `$VARIABLE`s. If a skill needs a new variable, add its detection to `references/detection-procedures.md` AND its slot to `references/config-template.md` at the same time — otherwise invocations will reference an undefined variable.

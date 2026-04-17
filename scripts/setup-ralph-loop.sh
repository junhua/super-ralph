#!/usr/bin/env bash
# setup-ralph-loop.sh — Create .claude/ralph-loop.local.md state file for ralph-loop
# This script bridges super-ralph commands to the ralph-loop plugin's Stop hook.
#
# Usage: setup-ralph-loop.sh "<PROMPT>" [--max-iterations N] [--completion-promise TEXT]

set -euo pipefail

# --- Parse arguments ---
PROMPT=""
MAX_ITERATIONS=0
COMPLETION_PROMISE="COMPLETE"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --max-iterations)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --max-iterations requires a value" >&2
        exit 1
      fi
      MAX_ITERATIONS="$2"
      shift 2
      ;;
    --completion-promise)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --completion-promise requires a value" >&2
        exit 1
      fi
      COMPLETION_PROMISE="$2"
      shift 2
      ;;
    *)
      if [[ -z "$PROMPT" ]]; then
        PROMPT="$1"
      else
        echo "Error: Unexpected argument: $1" >&2
        exit 1
      fi
      shift
      ;;
  esac
done

# --- Validate ---
if [[ -z "$PROMPT" ]]; then
  echo "Error: Prompt is required" >&2
  echo "Usage: setup-ralph-loop.sh \"<PROMPT>\" [--max-iterations N] [--completion-promise TEXT]" >&2
  exit 1
fi

if [[ "$MAX_ITERATIONS" != "0" ]] && ! [[ "$MAX_ITERATIONS" =~ ^[0-9]+$ ]]; then
  echo "Error: --max-iterations must be a non-negative integer" >&2
  exit 1
fi

# --- Create state directory ---
# Resolve to the current repo root if inside a git worktree; otherwise use CWD.
# This protects against the script being run from a stray directory and writing
# the state file to the wrong .claude/.
if command -v git >/dev/null 2>&1 && git rev-parse --show-toplevel >/dev/null 2>&1; then
  TARGET_DIR=$(git rev-parse --show-toplevel)
else
  TARGET_DIR="$PWD"
fi
mkdir -p "$TARGET_DIR/.claude"

# --- Write state file ---
STARTED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

TMPFILE=$(mktemp)
cat > "$TMPFILE" <<STATEFILE
---
active: true
iteration: 1
max_iterations: ${MAX_ITERATIONS}
completion_promise: "${COMPLETION_PROMISE}"
started_at: "${STARTED_AT}"
---

${PROMPT}
STATEFILE

mv "$TMPFILE" "$TARGET_DIR/.claude/ralph-loop.local.md"

echo "Ralph Loop configured:"
echo "  Completion promise: ${COMPLETION_PROMISE}"
echo "  Max iterations: ${MAX_ITERATIONS} (0 = unlimited)"
echo "  State file: $TARGET_DIR/.claude/ralph-loop.local.md"
echo ""
echo "The ralph-loop Stop hook will now intercept exit and feed the prompt back."

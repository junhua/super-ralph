#!/usr/bin/env bash
# Test harness for scripts/parse-local-epic.sh
set -euo pipefail

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/scripts/parse-local-epic.sh"
FIXTURE="$(cd "$(dirname "$0")" && pwd)/fixtures/sample-local-epic.md"

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }

# ─── detect-mode ──────────────────────────────────────────────────
MODE=$("$SCRIPT" detect-mode "#42")
[ "$MODE" = "github" ] || fail "detect-mode #42 → expected github got $MODE"
pass "detect-mode #42 → github"

MODE=$("$SCRIPT" detect-mode "42")
[ "$MODE" = "github" ] || fail "detect-mode 42 → expected github got $MODE"
pass "detect-mode 42 → github"

MODE=$("$SCRIPT" detect-mode "docs/epics/foo.md")
[ "$MODE" = "local" ] || fail "detect-mode docs/epics/foo.md → expected local got $MODE"
pass "detect-mode docs/epics/foo.md → local"

MODE=$("$SCRIPT" detect-mode "docs/epics/foo.md#story-3")
[ "$MODE" = "local" ] || fail "detect-mode fragment → expected local got $MODE"
pass "detect-mode with fragment → local"

MODE=$("$SCRIPT" detect-mode "Add JWT auth")
[ "$MODE" = "description" ] || fail "detect-mode description → expected description got $MODE"
pass "detect-mode free-text → description"

# ─── list-stories ─────────────────────────────────────────────────
COUNT=$("$SCRIPT" list-stories "$FIXTURE" | wc -l | tr -d ' ')
[ "$COUNT" = "3" ] || fail "list-stories → expected 3 got $COUNT"
pass "list-stories → 3 lines"

FIRST=$("$SCRIPT" list-stories "$FIXTURE" | head -1)
case "$FIRST" in
  story-1*"Foo listing"*PENDING*) pass "list-stories line 1 shape ok" ;;
  *) fail "list-stories line 1 malformed: $FIRST" ;;
esac

SECOND=$("$SCRIPT" list-stories "$FIXTURE" | sed -n 2p)
case "$SECOND" in
  story-2*"Foo detail"*IN_PROGRESS*) pass "list-stories line 2 shape ok" ;;
  *) fail "list-stories line 2 malformed: $SECOND" ;;
esac

# ─── extract-story ────────────────────────────────────────────────
OUT=$("$SCRIPT" extract-story "$FIXTURE" 1)
echo "$OUT" | head -1 | grep -q "^### Story 1: Foo listing$" || fail "extract-story 1 heading"
echo "$OUT" | grep -q "^### Story 2:" && fail "extract-story 1 leaked into Story 2"
echo "$OUT" | grep -q "^#### \[BE\] Story 1 — Backend$" || fail "extract-story 1 missing [BE]"
echo "$OUT" | grep -q "^#### \[INT\] Story 1 — Integration & E2E$" || fail "extract-story 1 missing [INT]"
pass "extract-story 1 bounded"

OUT=$("$SCRIPT" extract-story "$FIXTURE" 2)
echo "$OUT" | head -1 | grep -q "^### Story 2: Foo detail$" || fail "extract-story 2 heading"
echo "$OUT" | grep -q "^### Story 3:" && fail "extract-story 2 leaked into Story 3"
pass "extract-story 2 bounded"

OUT=$("$SCRIPT" extract-story "$FIXTURE" 3)
echo "$OUT" | head -1 | grep -q "^### Story 3: Foo search$" || fail "extract-story 3 heading"
echo "$OUT" | tail -5 | grep -q "INT green" || fail "extract-story 3 did not reach EOF"
pass "extract-story 3 to EOF"

set +e; "$SCRIPT" extract-story "$FIXTURE" 99 >/dev/null 2>&1; RC=$?; set -e
[ "$RC" != "0" ] || fail "extract-story missing should fail"
pass "extract-story missing → non-zero"

# ─── extract-substory ─────────────────────────────────────────────
OUT=$("$SCRIPT" extract-substory "$FIXTURE" 1 be)
echo "$OUT" | head -1 | grep -q "^#### \[BE\] Story 1 — Backend$" || fail "substory 1 be heading"
echo "$OUT" | grep -q "^#### \[FE\]" && fail "substory 1 be leaked into FE"
echo "$OUT" | grep -q "^### Story 2:" && fail "substory 1 be leaked into Story 2"
pass "extract-substory 1 be"

OUT=$("$SCRIPT" extract-substory "$FIXTURE" 1 story)
echo "$OUT" | head -1 | grep -q "^#### \[STORY\] Story 1$" || fail "substory 1 story heading"
echo "$OUT" | grep -q "^#### \[BE\]" && fail "substory 1 story leaked into BE"
pass "extract-substory 1 story"

OUT=$("$SCRIPT" extract-substory "$FIXTURE" 1 int)
echo "$OUT" | head -1 | grep -q "^#### \[INT\] Story 1 — Integration & E2E$" || fail "substory 1 int heading"
pass "extract-substory 1 int"

set +e; "$SCRIPT" extract-substory "$FIXTURE" 1 xxx >/dev/null 2>&1; RC=$?; set -e
[ "$RC" != "0" ] || fail "substory invalid kind should fail"
pass "extract-substory invalid kind fails"

# ─── get-status / set-status ──────────────────────────────────────
S=$("$SCRIPT" get-status "$FIXTURE" 1); [ "$S" = "PENDING" ]     || fail "get-status 1 → $S"
pass "get-status 1 → PENDING"
S=$("$SCRIPT" get-status "$FIXTURE" 2); [ "$S" = "IN_PROGRESS" ] || fail "get-status 2 → $S"
pass "get-status 2 → IN_PROGRESS"

TMP=$(mktemp); cp "$FIXTURE" "$TMP"
"$SCRIPT" set-status "$TMP" 1 COMPLETED
S=$("$SCRIPT" get-status "$TMP" 1); [ "$S" = "COMPLETED" ] || fail "set-status 1 → $S"
pass "set-status 1 COMPLETED"

S=$("$SCRIPT" get-status "$TMP" 2); [ "$S" = "IN_PROGRESS" ] || fail "set-status leaked, story 2 now $S"
pass "set-status isolates target"
rm -f "$TMP"

echo "--- All $(grep -c '^pass ' "$0") test assertions passed ---"

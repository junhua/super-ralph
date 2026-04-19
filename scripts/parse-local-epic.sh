#!/usr/bin/env bash
# parse-local-epic.sh — Shared parser for local-mode epic files.
#
# Subcommands:
#   detect-mode <arg>                 → echoes "local" | "github" | "description"
#   list-stories <epic-file>          → lines of "story-N <title> <STATUS>"
#   extract-story <epic-file> <N>     → story N block
#   extract-substory <epic-file> <N> <kind: story|be|fe|int>
#   get-status <epic-file> <N>        → PENDING | IN_PROGRESS | READY | COMPLETED
#   set-status <epic-file> <N> <new>  → rewrites file in place
#
# Compatible with POSIX awk (BSD awk on macOS). Uses 2-arg match() + substr().

set -euo pipefail

# Extract the number from a "### Story N: ..." heading line.
# Portable: no gawk match() captures.
_story_num() {
  awk '{
    s = $0
    sub(/^### Story /, "", s)
    n = s + 0
    print n
  }' <<< "$1"
}

# Extract the title from a "### Story N: Title" heading line.
_story_title() {
  awk '{
    s = $0
    sub(/^### Story [0-9]+: */, "", s)
    print s
  }' <<< "$1"
}

# Extract the status from a "**Status:** VALUE" line.
_status_value() {
  awk '{
    s = $0
    sub(/^.*\*\*Status:\*\*[[:space:]]*/, "", s)
    # Keep only the first run of uppercase/underscore chars
    if (match(s, /^[A-Z_]+/)) {
      print substr(s, RSTART, RLENGTH)
    }
  }' <<< "$1"
}

# Extract the [LABEL] from a "#### [LABEL] ..." sub-heading line.
_sub_label() {
  awk '{
    s = $0
    sub(/^#### \[/, "", s)
    i = index(s, "]")
    if (i > 0) print substr(s, 1, i - 1)
  }' <<< "$1"
}

export -f _story_num _story_title _status_value _sub_label

cmd="${1:-}"; shift || true

case "$cmd" in
  detect-mode)
    arg="${1:-}"
    case "$arg" in
      '#'[0-9]*)      echo "github" ;;
      [0-9]*)         echo "github" ;;
      *.md|*.md'#'*)  echo "local" ;;
      *)              echo "description" ;;
    esac
    ;;

  list-stories)
    file="${1:?epic file required}"
    awk '
      function story_num(line,   s, n) {
        s = line; sub(/^### Story /, "", s); n = s + 0; return n
      }
      function story_title(line,   s) {
        s = line; sub(/^### Story [0-9]+: */, "", s); return s
      }
      function status_val(line,   s) {
        s = line; sub(/^.*\*\*Status:\*\*[[:space:]]*/, "", s)
        if (match(s, /^[A-Z_]+/)) return substr(s, RSTART, RLENGTH)
        return ""
      }
      /^### Story [0-9]+:/ {
        cur_id = "story-" story_num($0)
        cur_title = story_title($0)
        cur_status = ""
        next
      }
      /\*\*Status:\*\*/ && cur_id != "" {
        cur_status = status_val($0)
        if (cur_status != "") {
          print cur_id " " cur_title " " cur_status
          cur_id = ""
        }
      }
    ' "$file"
    ;;

  extract-story)
    file="${1:?epic file required}"
    num="${2:?story number required}"
    awk -v n="$num" '
      function story_num(line,   s) {
        s = line; sub(/^### Story /, "", s); return s + 0
      }
      BEGIN { in_story=0; found=0 }
      /^### Story [0-9]+:/ {
        if (story_num($0) == n + 0) { in_story=1; found=1; print; next }
        if (in_story) { exit }
        in_story=0
        next
      }
      in_story { print }
      END { if (!found) exit 2 }
    ' "$file"
    ;;

  extract-substory)
    file="${1:?epic file required}"
    num="${2:?story number required}"
    kind="${3:?kind required}"
    case "$kind" in story|be|fe|int) ;; *) echo "invalid kind: $kind" >&2; exit 2 ;; esac
    label=$(echo "$kind" | tr '[:lower:]' '[:upper:]')
    awk -v n="$num" -v lbl="$label" '
      function story_num(line,   s) {
        s = line; sub(/^### Story /, "", s); return s + 0
      }
      function sub_label(line,   s, i) {
        s = line; sub(/^#### \[/, "", s); i = index(s, "]")
        if (i > 0) return substr(s, 1, i - 1)
        return ""
      }
      BEGIN { in_story=0; in_sub=0; found=0 }
      /^### Story [0-9]+:/ {
        in_story = (story_num($0) == n + 0) ? 1 : 0
        in_sub = 0
        next
      }
      in_story && /^#### \[/ {
        this_lbl = sub_label($0)
        if (this_lbl == lbl) { in_sub=1; found=1; print; next }
        if (in_sub) { exit }
        in_sub=0
        next
      }
      in_sub { print }
      END { if (!found) exit 2 }
    ' "$file"
    ;;

  get-status)
    file="${1:?epic file required}"
    num="${2:?story number required}"
    awk -v n="$num" '
      function story_num(line,   s) {
        s = line; sub(/^### Story /, "", s); return s + 0
      }
      function status_val(line,   s) {
        s = line; sub(/^.*\*\*Status:\*\*[[:space:]]*/, "", s)
        if (match(s, /^[A-Z_]+/)) return substr(s, RSTART, RLENGTH)
        return ""
      }
      /^### Story [0-9]+:/ {
        in_story = (story_num($0) == n + 0) ? 1 : 0
      }
      in_story && /\*\*Status:\*\*/ {
        v = status_val($0)
        if (v != "") { print v; exit }
      }
    ' "$file"
    ;;

  set-status)
    file="${1:?epic file required}"
    num="${2:?story number required}"
    new="${3:?new status required}"
    case "$new" in PENDING|IN_PROGRESS|READY|COMPLETED) ;;
      *) echo "invalid status: $new" >&2; exit 2 ;; esac
    tmp=$(mktemp)
    awk -v n="$num" -v new="$new" '
      function story_num(line,   s) {
        s = line; sub(/^### Story /, "", s); return s + 0
      }
      /^### Story [0-9]+:/ {
        in_story = (story_num($0) == n + 0) ? 1 : 0
      }
      in_story && /\*\*Status:\*\*/ {
        sub(/\*\*Status:\*\*[[:space:]]*[A-Z_]+/, "**Status:** " new)
        in_story = 0
      }
      { print }
    ' "$file" > "$tmp" && mv "$tmp" "$file"
    ;;

  detect-story-level)
    file="${1:?epic file required}"
    num="${2:?story number required}"
    if [ ! -f "$file" ]; then echo "missing"; exit 0; fi
    awk -v n="$num" '
      function story_num(line,   s) {
        s = line; sub(/^### Story /, "", s); return s + 0
      }
      BEGIN { in_story=0; found=0; has_sub=0 }
      /^### Story [0-9]+:/ {
        if (story_num($0) == n + 0) { in_story=1; found=1; next }
        if (in_story) { exit }
        in_story=0
        next
      }
      in_story && /^#### \[(BE|FE|INT)\] / { has_sub=1; exit }
      END {
        if (!found) { print "missing"; exit 0 }
        print (has_sub ? "full" : "brief")
      }
    ' "$file"
    ;;

  detect-design-level)
    file="${1:?epic file required}"
    if [ ! -f "$file" ]; then echo "not-an-epic"; exit 0; fi
    if ! grep -q '^# EPIC:' "$file"; then echo "not-an-epic"; exit 0; fi

    has_marker=0
    grep -q '^<!-- super-ralph: brief -->$' "$file" && has_marker=1

    all_brief=1
    all_full=1
    story_count=0

    # Iterate story numbers from list-stories output
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      story_count=$((story_count + 1))
      # "story-N Title STATUS" — take the "N" part
      sid=$(echo "$line" | awk '{print $1}')
      n=${sid#story-}
      level=$("$0" detect-story-level "$file" "$n" 2>/dev/null || echo "missing")
      [ "$level" = "full" ] && all_brief=0
      [ "$level" = "brief" ] && all_full=0
    done < <("$0" list-stories "$file" 2>/dev/null)

    if [ "$story_count" -eq 0 ]; then
      # Epic with no stories yet — treat as brief if marker, else full
      if [ "$has_marker" -eq 1 ]; then echo "brief"; else echo "full"; fi
      exit 0
    fi

    if [ "$has_marker" -eq 1 ] && [ "$all_brief" -eq 1 ]; then echo "brief"; exit 0; fi
    if [ "$has_marker" -eq 0 ] && [ "$all_full" -eq 1 ]; then echo "full"; exit 0; fi
    echo "mixed"
    ;;

  *)
    echo "Usage: $0 {detect-mode|list-stories|extract-story|extract-substory|get-status|set-status|detect-story-level|detect-design-level} ..." >&2
    exit 1
    ;;
esac

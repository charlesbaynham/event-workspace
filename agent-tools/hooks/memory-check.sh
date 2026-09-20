#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# SessionStart hook — report the state of memory/ so compaction is prompted by
# the repo rather than by a session happening to notice the log has grown.
#
# AGENTS.md tells sessions to compact past ~40 entries, but nothing counts the
# entries, so the trigger only fires if a session thinks to look. This does the
# looking. It reports, it never edits: compaction is a judgement call and stays
# the agent's (or the owner's) to make.
#
# Never fails a session — always exits 0.
# ---------------------------------------------------------------------------
set -uo pipefail

note() { printf 'memory hook: %s\n' "$1"; }

. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
cd "$ROOT" 2>/dev/null || exit 0

LOG=memory/log.md
DIGEST=memory/digest.md
THRESHOLD="${MEMORY_COMPACT_THRESHOLD:-40}"

[ -f "$LOG" ] || { note "no $LOG — memory system not installed here."; exit 0; }

# Count only dated entries, and only those added since the digest was last
# regenerated — the marker below. Without it the seeded log reads as permanently
# overdue, and a hook that always cries wolf gets ignored. A real compaction
# truncates the log and takes the marker with it, so the count resets on its own.
ENTRY_RE='^- \[[0-9]{4}-[0-9]{2}-[0-9]{2}\]'
BASELINE="$(grep -n '^<!-- compaction-baseline' "$LOG" 2>/dev/null | tail -1 | cut -d: -f1)"
if [ -n "$BASELINE" ]; then
  ENTRIES="$(tail -n +$((BASELINE + 1)) "$LOG" | grep -cE "$ENTRY_RE" || true)"
  SCOPE=" since the last digest regeneration"
else
  ENTRIES="$(grep -cE "$ENTRY_RE" "$LOG" || true)"
  SCOPE=""
fi

# Content = anything left once HTML comments, headings, blank lines and the
# "*(empty)*" placeholders are stripped. A digest of nothing but scaffolding
# has never been compacted, which is worth saying out loud.
digest_is_empty() {
  [ -f "$DIGEST" ] || return 0
  awk '
    /<!--/ { in_comment = 1 }
    !in_comment && !/^#/ && !/^[[:space:]]*$/ && !/^\*\(empty/ { found = 1 }
    /-->/  { in_comment = 0 }
    END    { exit found ? 1 : 0 }
  ' "$DIGEST"
}

if [ "$ENTRIES" -ge "$THRESHOLD" ]; then
  note "log.md has $ENTRIES entries$SCOPE (threshold $THRESHOLD) — run the memory-compact skill."
else
  note "log.md has $ENTRIES entries$SCOPE (compaction due at $THRESHOLD)."
fi

if digest_is_empty; then
  note "digest.md is still empty — no compaction has run yet, so continuity"
  note "for this session comes from the tail of log.md instead."
fi

exit 0

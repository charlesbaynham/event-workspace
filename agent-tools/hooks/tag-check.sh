#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# SessionStart hook — for workspaces pinned to a release (`agent_tools_track:
# tags`), say whether a newer release exists upstream, and offer it.
#
# `tags` means PINNED: update.sh installs the tag the workspace is already on
# and nothing moves on its own. That is the safe half of the bargain; this hook
# is the other half, so a pinned workspace hears about a release instead of
# quietly rotting. It only reports — updating is the owner's decision, and
# AGENTS.md ("Updating the engine") carries the four answers they can give.
#
# Two of those answers are remembered, as top-level keys in event.yaml:
#
#   agent_tools_tag_skip: v0.5.0, v0.6.0   — releases already declined
#   agent_tools_tag_check: off             — stop offering releases entirely
#
# Silent in the template and on any other track. Never fails a session — always
# exits 0.
# ---------------------------------------------------------------------------
set -uo pipefail

note() { printf 'tag hook: %s\n' "$1"; }

. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
cd "$ROOT" 2>/dev/null || exit 0

[ "$(event_cfg agent_tools_track main)" = tags ] || exit 0
case "$(event_cfg agent_tools_tag_check on)" in
  off|false|no) exit 0 ;;
esac

VERSION_FILE="$ROOT/agent-tools/VERSION"
[ -f "$VERSION_FILE" ] || exit 0
INSTALLED="v$(tr -d '[:space:]' < "$VERSION_FILE")"
UPSTREAM="$(event_cfg agent_tools_upstream https://github.com/charlesbaynham/event-workspace)"

TAGS="$(timeout 60 git ls-remote --tags --refs "$UPSTREAM" 'v*' 2>/dev/null | awk -F/ '{print $NF}' | sort -V)" || TAGS=""
if [ -z "$TAGS" ]; then
  note "pinned to $INSTALLED; could not reach $UPSTREAM to check for newer releases."
  exit 0
fi

# Declined releases, however the list was written: "v0.5.0, v0.6.0", a YAML
# flow list, or whitespace. Matched exactly — skipping one release never
# silences the next.
SKIP=" $(event_cfg agent_tools_tag_skip "" | tr -d '[]"'"'"'' | tr ',' ' ') "

# A workspace switched onto this track from `main` can be sitting on a VERSION
# that was never tagged. Say so: update.sh will refuse for the same reason.
case " $(printf '%s ' $TAGS)" in
  *" $INSTALLED "*) ;;
  *) note "pinned to $INSTALLED, but $UPSTREAM has no such tag — name a release"
     note "explicitly (agent-tools/update.sh vX.Y.Z) or update.sh will refuse to run." ;;
esac

newer_than() {  # newer_than A B → A > B
  [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -1)" = "$1" ]
}

CANDIDATE="" ; SKIPPED=""
for t in $TAGS; do
  newer_than "$t" "$INSTALLED" || continue
  case "$SKIP" in *" $t "*) SKIPPED="$t"; continue ;; esac
  CANDIDATE="$t"          # sorted ascending, so the last one standing is the newest
done

if [ -z "$CANDIDATE" ]; then
  if [ -n "$SKIPPED" ]; then
    note "pinned to $INSTALLED; newer releases upstream are all ones you declined."
  else
    note "pinned to $INSTALLED; no newer release upstream."
  fi
  exit 0
fi

note "a newer release is available: $CANDIDATE (this workspace is pinned to $INSTALLED)."
note "Offer it to the owner and act on their answer — AGENTS.md, \"Updating the engine\":"
note "  update now      → agent-tools/update.sh $CANDIDATE, review the diff, commit"
note "  not now         → change nothing; this fires again next session"
note "  not this one    → add $CANDIDATE to agent_tools_tag_skip in event.yaml"
note "  no more offers  → set agent_tools_tag_check: off in event.yaml"
note "Do not update without being asked to, and do not raise it twice in a session."
exit 0

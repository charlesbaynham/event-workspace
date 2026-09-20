#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# SessionStart hook — for pinned workspaces (`agent_tools_track: pinned`), say
# whether upstream has a newer version of the engine, quote the changelog for
# everything in between, and offer it.
#
# `pinned` means what it says: update.sh keeps the version in
# agent-tools/VERSION and nothing moves on its own. That is the safe half of
# the bargain; this hook is the other half, so a pinned workspace hears about a
# release instead of quietly rotting. The comparison is the TEXT of
# agent-tools/VERSION upstream against the text of the local one — no git tags
# are involved, so nothing has to be tagged for a release to be offered.
#
# It only reports — updating is the owner's decision, and AGENTS.md ("Updating
# the engine") carries the four answers they can give. Two are remembered, as
# top-level keys in event.yaml:
#
#   agent_tools_version_skip: 0.6.0, 0.7.0   — versions already declined
#   agent_tools_update_check: off            — stop offering versions entirely
#
# (0.5.0 spelled these agent_tools_tag_skip and agent_tools_tag_check, and
# named this hook tag-check.sh; both old keys are still honoured.)
#
# Silent in the template and on any other track. Never fails a session — always
# exits 0.
# ---------------------------------------------------------------------------
set -uo pipefail

note() { printf 'version hook: %s\n' "$1"; }

. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
cd "$ROOT" 2>/dev/null || exit 0

[ "$(update_track)" = pinned ] || exit 0
CHECK="$(event_cfg agent_tools_update_check "$(event_cfg agent_tools_tag_check on)")"
case "$CHECK" in
  off|false|no) exit 0 ;;
esac

VERSION_FILE="$ROOT/agent-tools/VERSION"
[ -f "$VERSION_FILE" ] || exit 0
INSTALLED="$(tr -d '[:space:]' < "$VERSION_FILE")"
UPSTREAM="$(upstream_url)"
REF="$(track_ref)"

TMP="$(mktemp -d)" || exit 0
trap 'rm -rf "$TMP"' EXIT
git -C "$TMP" init --quiet >/dev/null 2>&1
if ! timeout 60 git -C "$TMP" fetch --quiet --depth 1 "$UPSTREAM" "$REF" >/dev/null 2>&1; then
  note "pinned to $INSTALLED; could not reach $UPSTREAM to check for a newer version."
  exit 0
fi
UP_VERSION="$(git -C "$TMP" show "FETCH_HEAD:agent-tools/VERSION" 2>/dev/null | tr -d '[:space:]')"
[ -n "$UP_VERSION" ] || exit 0
git -C "$TMP" show "FETCH_HEAD:agent-tools/CHANGELOG.md" > "$TMP/CHANGELOG.md" 2>/dev/null

version_gt "$UP_VERSION" "$INSTALLED" || {
  note "pinned to $INSTALLED; nothing newer upstream."
  exit 0
}

# Declined versions, however the list was written: "0.6.0, 0.7.0", a YAML flow
# list, or whitespace; leading "v"s tolerated. Matched exactly, so declining
# one version never silences the next, and entries go inert once you are past
# them — nothing has to prune the list.
SKIP=" $(event_cfg agent_tools_version_skip "$(event_cfg agent_tools_tag_skip "")" \
         | tr -d '[]"'"'"'' | tr ',' ' ' | tr -d v) "
case "$SKIP" in
  *" $UP_VERSION "*)
    note "pinned to $INSTALLED; upstream is $UP_VERSION, which you declined."
    exit 0 ;;
esac

note "a newer engine is available: $UP_VERSION (this workspace is pinned to $INSTALLED)."
if [ -s "$TMP/CHANGELOG.md" ]; then
  CHANGES="$(changelog_since "$TMP/CHANGELOG.md" "$INSTALLED")"
  if [ -n "$CHANGES" ]; then
    note "what you do not have yet, from agent-tools/CHANGELOG.md:"
    printf '%s\n' "$CHANGES" | head -80 | sed 's/^/version hook: | /'
    # A long gap would otherwise fill the session's context with changelog.
    if [ "$(printf '%s\n' "$CHANGES" | wc -l)" -gt 80 ]; then
      note "| … the rest is printed in full by 'agent-tools/update.sh --check'."
    fi
  fi
fi
note "Offer it to the owner, changelog and all, and act on their answer —"
note "AGENTS.md, \"Updating the engine\":"
note "  update now      → agent-tools/update.sh --accept, review the diff, commit"
note "  not now         → change nothing; this fires again next session"
note "  not this one    → add $UP_VERSION to agent_tools_version_skip in event.yaml"
note "  no more offers  → set agent_tools_update_check: off in event.yaml"
note "Do not update without being asked to, and do not raise it twice in a session."
exit 0

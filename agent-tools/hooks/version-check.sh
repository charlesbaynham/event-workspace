#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# SessionStart hook — say whether upstream has something newer than the engine
# this workspace runs, quote the changelog for it, and offer it.
#
# What counts as "newer" depends on the track (`agent_tools_track`):
#
#   pinned           a newer *version*: the TEXT of upstream's agent-tools/VERSION
#                    against the local one. Nothing else is offered.
#   latest / branch  ANY difference between agent-tools/ here and upstream's tip,
#                    version bump or not — `latest` means the author's current
#                    tip, work in progress included.
#
# `pinned` means what it says: update.sh keeps the version in
# agent-tools/VERSION and nothing moves on its own. That is the safe half of
# the bargain; this hook is the other half, so a pinned workspace hears about a
# release instead of quietly rotting. No git tags are involved, so nothing has
# to be tagged for a release to be offered.
#
# It only reports — updating is the owner's decision, and AGENTS.md ("Updating
# the engine") carries the four answers they can give. Two are remembered, as
# top-level keys in event.yaml:
#
#   agent_tools_version_skip: 0.6.0, abc123def456
#                                            — already declined: versions on
#                                              pinned, 12-char upstream commit
#                                              ids on latest / a branch
#   agent_tools_update_check: off            — stop offering versions entirely
#
# Silent in the template. Never fails a session — always exits 0.
# ---------------------------------------------------------------------------
set -uo pipefail

note() { printf 'version hook: %s\n' "$1"; }

. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
cd "$ROOT" 2>/dev/null || exit 0

in_template && exit 0
TRACK="$(update_track)"
case "$(event_cfg agent_tools_update_check on)" in
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
  note "$TRACK at $INSTALLED; could not reach $UPSTREAM to check for a newer version."
  exit 0
fi
UP_VERSION="$(git -C "$TMP" show "FETCH_HEAD:agent-tools/VERSION" 2>/dev/null | tr -d '[:space:]')"
[ -n "$UP_VERSION" ] || exit 0
git -C "$TMP" show "FETCH_HEAD:agent-tools/CHANGELOG.md" > "$TMP/CHANGELOG.md" 2>/dev/null

if [ "$TRACK" = pinned ]; then
  version_gt "$UP_VERSION" "$INSTALLED" || {
    note "pinned to $INSTALLED; nothing newer upstream."
    exit 0
  }
  OFFER="$UP_VERSION"
else
  # Any change to the engine counts. update.sh's KEEP paths belong to the
  # workspace and are not compared.
  mkdir -p "$TMP/up"
  git -C "$TMP" archive FETCH_HEAD agent-tools 2>/dev/null | tar -x -C "$TMP/up" 2>/dev/null
  [ -s "$TMP/up/agent-tools/VERSION" ] || exit 0
  DIFF="$(diff -rq -x assets "$ROOT/agent-tools" "$TMP/up/agent-tools" 2>/dev/null \
    | sed -E "s#^Files $ROOT/agent-tools/(.*) and .*#changed: \1#; s#^Only in $ROOT/agent-tools/?(.*): (.*)#removed: \1/\2#; s#^Only in $TMP/up/agent-tools/?(.*): (.*)#new: \1/\2#; s#: /#: #")"
  [ -n "$DIFF" ] || {
    note "$TRACK at $INSTALLED; identical to upstream."
    exit 0
  }
  OFFER="$(git -C "$TMP" rev-parse --short=12 FETCH_HEAD)"
fi

# Declined offers, however the list was written: "0.6.0, 0.7.0", a YAML flow
# list, or whitespace; leading "v"s tolerated. Matched exactly, so declining
# one version never silences the next, and entries go inert once you are past
# them — nothing has to prune the list.
SKIP=" $(event_cfg agent_tools_version_skip "" | tr -d '[]"'"'"'' | tr ',' ' ' | tr -d v) "
case "$SKIP" in
  *" $OFFER "*)
    note "$TRACK at $INSTALLED; upstream is $OFFER, which you declined."
    exit 0 ;;
esac

if [ "$TRACK" = pinned ]; then
  note "a newer engine is available: $UP_VERSION (this workspace is pinned to $INSTALLED)."
else
  note "upstream has engine changes this workspace lacks: $OFFER (upstream VERSION $UP_VERSION, here $INSTALLED; track $TRACK)."
  note "files that differ:"
  printf '%s\n' "$DIFF" | head -40 | sed 's/^/version hook: | /'
  if [ "$(printf '%s\n' "$DIFF" | wc -l)" -gt 40 ]; then
    note "| … and more; 'git diff' after updating shows all."
  fi
fi
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
note "  not this one    → add $OFFER to agent_tools_version_skip in event.yaml"
note "  no more offers  → set agent_tools_update_check: off in event.yaml"
note "Do not update without being asked to, and do not raise it twice in a session."
exit 0

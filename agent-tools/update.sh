#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Pull the engine (agent-tools/) from the upstream event-workspace over this
# vendored copy, and reinstall the contract it ships (agent-tools/AGENTS.md)
# as this repository's root AGENTS.md.
#
#   agent-tools/update.sh            # what event.yaml's agent_tools_track says:
#                                    #   main (default) — the tip of the default branch
#                                    #   tags           — PINNED: the tag this workspace is
#                                    #                    already on (agent-tools/VERSION), so
#                                    #                    a release never arrives unasked
#   agent-tools/update.sh v0.2.0     # an explicit tag, branch or full sha — how a pinned
#                                    #   workspace moves to a new release
#   agent-tools/update.sh --check    # installed vs upstream VERSION, change nothing
#
# On the `tags` track, agent-tools/hooks/tag-check.sh is what tells you a newer
# release exists; AGENTS.md ("Updating the engine") says what to do about it.
#
# Everything under agent-tools/ is replaced except the paths in KEEP, which are
# per-event and never shipped upstream; the root AGENTS.md is replaced too.
# Local edits to either are overwritten — per-event behaviour belongs in
# event.yaml and EVENT.md, not here. Review `git diff` and commit afterwards;
# nothing is committed for you.
#
# Refuses to run in the template itself (no event.yaml): there the engine is
# edited in place, and the root AGENTS.md is the maintainer guide, not the
# contract.
# ---------------------------------------------------------------------------
set -euo pipefail

. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
if in_template; then
  echo "update: no event.yaml — this is the template, not a workspace; nothing to update here." >&2
  exit 1
fi
UPSTREAM="$(event_cfg agent_tools_upstream https://github.com/charlesbaynham/event-workspace)"
TRACK="$(event_cfg agent_tools_track main)"
KEEP=(skills/gsheets/assets)
DEST="$ROOT/agent-tools"

# `tags` is a pin, not a stream: it resolves to the tag matching the installed
# VERSION, so a bare update.sh reinstalls exactly what is already here. Moving
# to a release is always an explicit argument, prompted by tag-check.sh.
pinned_tag() {
  local want="v$(tr -d '[:space:]' < "$DEST/VERSION")"
  if [ -z "$(git ls-remote --tags --refs "$UPSTREAM" "$want" 2>/dev/null)" ]; then
    echo "update: track 'tags' pins this workspace to $want, but $UPSTREAM has no such tag." >&2
    echo "update: pass the release you want explicitly, e.g. agent-tools/update.sh v0.5.0" >&2
    exit 1
  fi
  printf '%s\n' "$want"
}

resolve_ref() {
  case "$TRACK" in
    tags) pinned_tag ;;
    *)    printf '%s\n' "$TRACK" ;;   # a branch name; "main" unless the consumer set otherwise
  esac
}

REF="${1:-}"; MODE=install
if [ "$REF" = "--check" ]; then MODE=check; REF=""; fi
[ -n "$REF" ] || REF="$(resolve_ref)"
[ -n "$REF" ] || { echo "update: nothing to fetch — track '$TRACK' resolved to no ref at $UPSTREAM" >&2; exit 1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
git -C "$TMP" init --quiet
git -C "$TMP" fetch --quiet --depth 1 "$UPSTREAM" "$REF"   # a tag, branch or full sha alike
git -C "$TMP" checkout --quiet FETCH_HEAD
UP_VERSION="$(cat "$TMP/agent-tools/VERSION")"

if [ "$MODE" = check ]; then
  echo "installed: $(cat "$DEST/VERSION")   upstream ($REF): $UP_VERSION   track: $TRACK   $UPSTREAM"
  if [ "$TRACK" = tags ]; then
    echo "track 'tags' is a pin: this stays on $REF until you name another release."
  fi
  exit 0
fi

# No rsync in the cloud containers this runs in, so: set the kept paths aside,
# replace the directory wholesale, put them back.
for k in "${KEEP[@]}"; do
  [ -e "$DEST/$k" ] || continue
  mkdir -p "$TMP/keep/$(dirname "$k")" && cp -a "$DEST/$k" "$TMP/keep/$k"
done
rm -rf "$DEST" && cp -a "$TMP/agent-tools" "$DEST"
for k in "${KEEP[@]}"; do
  [ -e "$TMP/keep/$k" ] || continue
  mkdir -p "$DEST/$(dirname "$k")" && cp -a "$TMP/keep/$k" "$DEST/$k"
done
cp "$DEST/AGENTS.md" "$ROOT/AGENTS.md"

echo "update: agent-tools is now $UP_VERSION ($REF) from $UPSTREAM"
echo "update: review with 'git status' and 'git diff', then commit."

# The hook lives in agent-tools/ and so arrives with every update, but the
# files that RUN it are per-event and were only ever written at birth — a
# workspace older than the hook has to be told once.
if [ "$TRACK" = tags ] \
   && ! grep -qs 'tag-check.sh' "$ROOT/.claude/settings.json" "$ROOT/.codex/hooks.json"; then
  echo "update: this workspace is on the 'tags' track but does not run"
  echo "update: agent-tools/hooks/tag-check.sh at SessionStart, so nothing will tell you"
  echo "update: when a release lands. Add it beside the other SessionStart hooks in"
  echo "update: .claude/settings.json (and .codex/hooks.json if you use Codex)."
fi

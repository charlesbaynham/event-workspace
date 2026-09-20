#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Pull the engine (agent-tools/) from the upstream event-workspace over this
# vendored copy, and reinstall the contract it ships (agent-tools/AGENTS.md)
# as this repository's root AGENTS.md.
#
#   agent-tools/update.sh            # what event.yaml's agent_tools_track says:
#                                    #   latest (default) — upstream's current tip
#                                    #   pinned           — the version in agent-tools/VERSION:
#                                    #                      refreshes it, but refuses to move to
#                                    #                      a different one without --accept
#   agent-tools/update.sh --accept   # take the version upstream has now — how a pinned
#                                    #   workspace moves, after being offered a release
#   agent-tools/update.sh v0.2.0     # an explicit tag, branch or full sha, whatever the track
#   agent-tools/update.sh --check    # installed vs upstream VERSION, change nothing
#
# Versions are the text of agent-tools/VERSION, not git tags: on the `pinned`
# track agent-tools/hooks/version-check.sh compares the two at SessionStart,
# quotes agent-tools/CHANGELOG.md for everything in between, and offers it.
# AGENTS.md ("Updating the engine") says what to do about that offer.
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
UPSTREAM="$(upstream_url)"
TRACK="$(update_track)"
KEEP=(skills/gsheets/assets)
DEST="$ROOT/agent-tools"
INSTALLED="$(tr -d '[:space:]' < "$DEST/VERSION")"

# A bare run follows the track. An explicit ref, or --accept, is the consent
# that lets a pinned workspace land on a different version.
MODE=install; REF=""; ACCEPT=0
case "${1:-}" in
  "")       ;;
  --check)  MODE=check ;;
  --accept) ACCEPT=1 ;;
  -*)       echo "update: unknown option '$1' — try --check, --accept, or a ref." >&2; exit 1 ;;
  *)        REF="$1"; ACCEPT=1 ;;
esac
[ -n "$REF" ] || REF="$(track_ref)"
[ -n "$REF" ] || { echo "update: nothing to fetch — track '$TRACK' resolved to no ref at $UPSTREAM" >&2; exit 1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
git -C "$TMP" init --quiet
git -C "$TMP" fetch --quiet --depth 1 "$UPSTREAM" "$REF"   # a branch, tag, sha or HEAD alike
git -C "$TMP" checkout --quiet FETCH_HEAD
UP_VERSION="$(tr -d '[:space:]' < "$TMP/agent-tools/VERSION")"

if [ "$MODE" = check ]; then
  echo "installed: $INSTALLED   upstream ($REF): $UP_VERSION   track: $TRACK   $UPSTREAM"
  if [ "$TRACK" = pinned ] && [ "$INSTALLED" != "$UP_VERSION" ]; then
    echo "track 'pinned' stays on $INSTALLED; take $UP_VERSION with 'agent-tools/update.sh --accept'."
    changelog_since "$TMP/agent-tools/CHANGELOG.md" "$INSTALLED"
  fi
  exit 0
fi

if [ "$TRACK" = pinned ] && [ "$ACCEPT" = 0 ] && [ "$INSTALLED" != "$UP_VERSION" ]; then
  echo "update: this workspace is pinned to $INSTALLED; upstream is now $UP_VERSION." >&2
  echo "update: a bare update keeps the pin. Take it with 'agent-tools/update.sh --accept'," >&2
  echo "update: or name a ref explicitly. What changed:" >&2
  changelog_since "$TMP/agent-tools/CHANGELOG.md" "$INSTALLED" >&2
  exit 1
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
if version_gt "$UP_VERSION" "$INSTALLED"; then
  changelog_since "$DEST/CHANGELOG.md" "$INSTALLED"
fi
echo "update: review with 'git status' and 'git diff', then commit."

# The hook lives in agent-tools/ and so arrives with every update, but the
# files that RUN it are per-event and were only ever written at birth — a
# workspace older than the hook has to be told once, and one that registered
# it under its 0.5.0 name (tag-check.sh) has to be repointed.
for f in "$ROOT/.claude/settings.json" "$ROOT/.codex/hooks.json"; do
  [ -f "$f" ] || continue
  grep -q 'tag-check\.sh' "$f" || continue
  sed 's/tag-check\.sh/version-check.sh/g' "$f" > "$TMP/hookfile" && cat "$TMP/hookfile" > "$f"
  echo "update: repointed the tag-check.sh SessionStart hook to version-check.sh in ${f#"$ROOT"/}"
done
if [ "$TRACK" = pinned ] \
   && ! grep -qs 'version-check\.sh' "$ROOT/.claude/settings.json" "$ROOT/.codex/hooks.json"; then
  echo "update: this workspace is pinned but does not run"
  echo "update: agent-tools/hooks/version-check.sh at SessionStart, so nothing will tell you"
  echo "update: when a new version lands. Add it beside the other SessionStart hooks in"
  echo "update: .claude/settings.json (and .codex/hooks.json if you use Codex)."
fi

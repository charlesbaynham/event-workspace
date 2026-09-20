#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Pull a release of agent-tools/ from the upstream event-workspace over this
# vendored copy. Usage:
#
#   agent-tools/update.sh            # latest tag
#   agent-tools/update.sh v0.2.0     # a specific tag, branch or sha
#   agent-tools/update.sh --check    # report the latest tag, change nothing
#
# Everything under agent-tools/ is replaced except the paths in KEEP, which are
# per-event and never shipped upstream. Local edits anywhere else are
# overwritten — per-event behaviour belongs in event.yaml and EVENT.md, not
# here. Review `git diff` and commit afterwards; nothing is committed for you.
# ---------------------------------------------------------------------------
set -euo pipefail

. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
UPSTREAM="$(event_cfg agent_tools_upstream https://github.com/charlesbaynham/event-workspace)"
KEEP=(skills/gsheets/assets/)
DEST="$ROOT/agent-tools"

latest_tag() {
  git ls-remote --tags --refs "$UPSTREAM" 'v*' | awk -F/ '{print $NF}' | sort -V | tail -1
}

REF="${1:-}"
if [ "$REF" = "--check" ]; then
  echo "installed: $(cat "$DEST/VERSION")   latest: $(latest_tag)   upstream: $UPSTREAM"
  exit 0
fi
[ -n "$REF" ] || REF="$(latest_tag)"
[ -n "$REF" ] || { echo "update: no release tag found at $UPSTREAM" >&2; exit 1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
git clone --quiet --depth 1 --branch "$REF" "$UPSTREAM" "$TMP/src"

EXCLUDES=(); for k in "${KEEP[@]}"; do EXCLUDES+=(--exclude "$k"); done
rsync -a --delete "${EXCLUDES[@]}" "$TMP/src/agent-tools/" "$DEST/"

echo "update: agent-tools is now $(cat "$DEST/VERSION") ($REF) from $UPSTREAM"
echo "update: review with 'git status' and 'git diff', then commit."

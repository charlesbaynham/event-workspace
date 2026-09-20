#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Commit everything and get it onto the default branch, safely, from a session that
# may be racing other sessions.
#
# Webhook-fired sessions are no longer rare and no longer serial: two guests
# texting at once means two containers editing memory/ and pushing to main
# within seconds of each other. Both append to memory/log.md, so both conflict.
# A session that hits "rejected — non-fast-forward" and gives up has recorded
# NOTHING, because its container is about to be destroyed.
#
# So: commit, then rebase onto whatever landed while we worked, then push;
# retry on the race. log.md conflicts are resolved by keeping BOTH sides —
# it is an append-only log, so every line is someone's real observation.
#
# Usage: agent-tools/sync-push.sh "commit message"
# ---------------------------------------------------------------------------
set -uo pipefail

MSG="${1:?usage: sync-push.sh \"commit message\"}"
ATTEMPTS=5

. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$ROOT" || exit 1

CURRENT="$(git symbolic-ref --quiet --short HEAD || echo '(detached)')"
if [ "$CURRENT" != "$BRANCH" ]; then
  echo "sync-push: on '$CURRENT', not '$BRANCH' — run agent-tools/hooks/git-sync.sh or 'git checkout $BRANCH' first" >&2
  exit 1
fi

git add -A
if git diff --cached --quiet; then
  git fetch -q origin "$BRANCH"
  if [ "$(git rev-list --count origin/$BRANCH..HEAD)" = "0" ]; then
    echo "sync-push: nothing to commit or push"
    exit 0
  fi
  echo "sync-push: nothing to commit, pushing existing local commits"
else
  git commit -q -m "$MSG" || exit 1
fi

for i in $(seq 1 "$ATTEMPTS"); do
  if git push -q -u origin "$BRANCH" 2>/dev/null; then
    echo "sync-push: pushed on attempt $i"
    exit 0
  fi

  echo "sync-push: push rejected, rebasing (attempt $i/$ATTEMPTS)" >&2
  git fetch -q origin "$BRANCH" || sleep $((i * 2))

  if ! git rebase -q origin/$BRANCH 2>/dev/null; then
    # Only memory/log.md is expected to conflict, and only ever because two
    # sessions appended different lines. Keep both, in time order.
    conflicts=$(git diff --name-only --diff-filter=U)
    if [ "$conflicts" = "memory/log.md" ]; then
      echo "sync-push: merging concurrent log.md appends" >&2
      # Drop the conflict markers, keeping both sides' lines.
      sed -i '/^<<<<<<< /d; /^=======$/d; /^>>>>>>> /d' memory/log.md
      git add memory/log.md
      GIT_EDITOR=true git rebase --continue >/dev/null 2>&1 || { git rebase --abort; exit 1; }
    else
      echo "sync-push: unexpected conflict in: $conflicts" >&2
      git rebase --abort
      exit 1
    fi
  fi
  sleep $((i * 2))
done

echo "sync-push: FAILED to push after $ATTEMPTS attempts — work is committed locally only" >&2
exit 1

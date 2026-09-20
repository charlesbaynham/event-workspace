#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# SessionStart hook — put the session on an up-to-date default branch
# (`default_branch` in event.yaml, `main` if unset).
#
# Three jobs, all of which a session otherwise gets wrong:
#
# 1. Repair the phantom divergence. The container's .git is a RESTORED
#    SNAPSHOT, not a fresh clone, refreshed only by a shallow --depth 50 fetch.
#    Once the repo has moved further than that, the new shallow boundary lands
#    NEWER than the frozen local ref, git can compute no merge base, and it
#    reports a stale ref as diverged ("ahead 17, behind 51"). Deepening first is
#    what makes the comparison honest — it is the only way to tell "stale" from
#    "genuinely diverged", which is exactly the distinction a session cannot
#    make and so guesses at, usually by inventing `git reset --hard`.
#
# 2. Put the session itself at the fetched main commit. Codex worktrees may
#    start detached, so updating refs/heads/$BRANCH alone does not update the files
#    the session sees.
#
# 3. Get off the harness's scaffolding branch, because AGENTS.md says work here
#    goes to the default branch whatever the session boilerplate checked out.
#    Skipped in the upstream template (no event.yaml), where branches and PRs
#    are the convention — jobs 1 and 2 still run there.
#
# Never destroys work: real divergence is reported and left alone. Never fails a
# session — always exits 0.
# ---------------------------------------------------------------------------
set -uo pipefail

note() { printf 'git-sync hook: %s\n' "$1"; }

. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
cd "$ROOT" 2>/dev/null || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

if [ -f "$(git rev-parse --git-path shallow)" ]; then
  timeout 120 git fetch --unshallow --quiet origin 2>/dev/null \
    || timeout 120 git fetch --deepen=1000 --quiet origin 2>/dev/null \
    || note "could not deepen the clone — the check below may be unreliable"
fi

timeout 60 git fetch --quiet origin "$BRANCH" 2>/dev/null \
  || note "could not fetch origin/$BRANCH — using what is already local"

git rev-parse --verify -q refs/remotes/origin/$BRANCH >/dev/null || {
  note "no origin/$BRANCH to compare against; nothing to do."
  exit 0
}

REMOTE="$(git rev-parse refs/remotes/origin/$BRANCH)"
HEAD_REF="$(git symbolic-ref --quiet --short HEAD || echo '(detached)')"

if ! LOCAL="$(git rev-parse --verify -q refs/heads/$BRANCH)"; then
  git branch "$BRANCH" origin/$BRANCH >/dev/null 2>&1 \
    && note "local $BRANCH was missing — created it at origin/$BRANCH."
  exit 0
fi

if [ "$LOCAL" = "$REMOTE" ]; then
  note "$BRANCH matches origin/$BRANCH ($(git rev-parse --short "$REMOTE"))."
elif git merge-base --is-ancestor "$LOCAL" "$REMOTE"; then
  BEHIND="$(git rev-list --count "$LOCAL".."$REMOTE")"
  if [ "$HEAD_REF" = "$BRANCH" ]; then
    if git merge --ff-only --quiet origin/$BRANCH 2>/dev/null; then
      note "fast-forwarded $BRANCH $BEHIND commit(s) to origin/$BRANCH."
    else
      note "$BRANCH is $BEHIND behind but the working tree blocks a fast-forward."
      note "Commit or stash, then: git merge --ff-only origin/$BRANCH"
    fi
  else
    git update-ref refs/heads/$BRANCH "$REMOTE" \
      && note "fast-forwarded $BRANCH $BEHIND commit(s) to origin/$BRANCH."
  fi
else
  AHEAD="$(git rev-list --count "$REMOTE".."$LOCAL")"
  note "WARNING: $BRANCH has $AHEAD commit(s) that are NOT on origin/$BRANCH."
  note "This is real divergence, not the usual stale-snapshot artifact —"
  note "left untouched. Inspect before resetting: git log origin/$BRANCH..$BRANCH"
fi

if in_template; then
  [ "$HEAD_REF" = "$BRANCH" ] || note "template repository (no event.yaml): branches are ordinary here — staying on '$HEAD_REF'."
  exit 0
fi

# Only claude/* is treated as scaffolding. A branch the owner named themselves is
# left alone, as is any branch carrying commits or uncommitted changes: a silent
# switch there would hide work, which is worse than the wrong branch.
case "$HEAD_REF" in
  "$BRANCH") ;;
  '(detached)')
    HEAD_COMMIT="$(git rev-parse HEAD)"
    if [ "$HEAD_COMMIT" = "$REMOTE" ]; then
      note "detached session matches origin/$BRANCH ($(git rev-parse --short "$REMOTE"))."
    elif git merge-base --is-ancestor "$HEAD_COMMIT" "$REMOTE"; then
      BEHIND="$(git rev-list --count "$HEAD_COMMIT".."$REMOTE")"
      if git checkout --detach --quiet "$REMOTE" 2>/dev/null; then
        note "updated detached session $BEHIND commit(s) to origin/$BRANCH."
      else
        note "could not update detached session to origin/$BRANCH; local work may"
        note "conflict with the fetched commit, so it was left untouched."
      fi
    else
      note "WARNING: detached HEAD has commits that are NOT on origin/$BRANCH."
      note "Left it untouched; inspect with: git log origin/$BRANCH..HEAD"
    fi
    ;;
  claude/*)
    if [ -n "${GIT_SYNC_KEEP_BRANCH:-}" ]; then
      note "on '$HEAD_REF'; GIT_SYNC_KEEP_BRANCH is set — staying put."
    elif [ -n "$(git status --porcelain)" ]; then
      note "on scaffolding branch '$HEAD_REF', but the tree has uncommitted"
      note "changes — not switching. AGENTS.md wants $BRANCH: commit or stash,"
      note "then: git checkout $BRANCH"
    elif [ "$(git rev-list --count refs/remotes/origin/$BRANCH..HEAD)" != "0" ]; then
      note "on '$HEAD_REF', which carries commits NOT on $BRANCH — not switching."
      note "Move them across before they are lost: git log origin/$BRANCH..HEAD"
    elif git checkout --quiet "$BRANCH" 2>/dev/null; then
      note "switched off scaffolding branch '$HEAD_REF' → $BRANCH (AGENTS.md)."
    else
      note "could not switch off '$HEAD_REF' — by hand: git checkout $BRANCH"
    fi
    ;;
  *) note "on branch '$HEAD_REF' — AGENTS.md says commit to $BRANCH in this repo." ;;
esac

exit 0

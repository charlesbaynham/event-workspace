#!/usr/bin/env bash
# Shared by the hooks and scripts. Source it; it sets ROOT and CONFIG and
# defines ws_cfg. Top-level scalars of workspace.yaml only — nested keys are
# for the skills, which read the file as prose.
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || ROOT="$PWD"

# The workspace's configuration. Before 1.0.0 it was event.yaml; a workspace
# whose engine is updated but whose 1.0.0 migration has not yet renamed it is
# still read from there, so the migration itself can run.
CONFIG="$ROOT/workspace.yaml"
[ -f "$CONFIG" ] || [ ! -f "$ROOT/event.yaml" ] || CONFIG="$ROOT/event.yaml"
export WORKSPACE_CONFIG="$CONFIG"

ws_cfg() {
  local key="$1" default="$2" value=""
  [ -f "$CONFIG" ] && value="$(sed -nE "s/^${key}:[[:space:]]*//p" "$CONFIG" | head -1 \
    | sed -E 's/[[:space:]]+#.*$//; s/^"(.*)"$/\1/; s/^'"'"'(.*)'"'"'$/\1/')"
  printf '%s\n' "${value:-$default}"
}

BRANCH="$(ws_cfg default_branch main)"

# The upstream template ships workspace.yaml.example only; every workspace born
# from it has workspace.yaml (or, before its 1.0.0 migration, event.yaml). Scripts that only make sense in a workspace use this
# to refuse, and git-sync uses it to leave branches alone.
in_template() { [ ! -f "$CONFIG" ]; }

# --- engine updates --------------------------------------------------------
# Where update.sh pulls from, and how closely it follows.
upstream_url() { ws_cfg agent_tools_upstream https://github.com/charlesbaynham/memory-workspace; }

# workspace.yaml's agent_tools_track:
#   latest — upstream's default branch, taken whenever you update
#   pinned — the version in agent-tools/VERSION; nothing moves unasked
#   <name> — any other value is a branch, followed like `latest` but on it
update_track() { ws_cfg agent_tools_track latest; }

# The ref a bare update fetches: upstream's default branch on both named
# tracks, the named branch otherwise.
track_ref() {
  local t; t="$(update_track)"
  case "$t" in
    latest|pinned) printf 'HEAD\n' ;;
    *)             printf '%s\n' "$t" ;;
  esac
}

# version_gt A B → A is a later release than B. Semver, leading "v" tolerated.
version_gt() {
  local a="${1#v}" b="${2#v}"
  [ "$a" != "$b" ] && [ "$(printf '%s\n%s\n' "$a" "$b" | sort -V | tail -1)" = "$a" ]
}

# changelog_since <CHANGELOG.md> <version> — every entry later than <version>,
# newest first, exactly as written. Silent if the file or the entries are
# missing; a changelog is documentation, never a gate on updating.
changelog_since() {
  local file="$1" since="${2#v}" ver
  [ -f "$file" ] || return 0
  while read -r ver; do
    [ -n "$ver" ] || continue
    version_gt "$ver" "$since" || continue
    awk -v v="$ver" '
      $0 ~ "^## +v?" v "([^0-9.]|$)" { on = 1; print; next }
      on && /^## / { exit }
      on { print }
    ' "$file"
  done < <(sed -nE 's/^## +v?([0-9]+\.[0-9]+\.[0-9]+).*/\1/p' "$file")
}

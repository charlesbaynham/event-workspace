#!/usr/bin/env bash
# Shared by the hooks and scripts. Source it; it sets ROOT and defines
# event_cfg. Top-level scalars of event.yaml only — nested keys are for the
# skills, which read the file as prose.
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || ROOT="$PWD"

event_cfg() {
  local key="$1" default="$2" value=""
  [ -f "$ROOT/event.yaml" ] && value="$(sed -nE "s/^${key}:[[:space:]]*//p" "$ROOT/event.yaml" | head -1 \
    | sed -E 's/[[:space:]]+#.*$//; s/^"(.*)"$/\1/; s/^'"'"'(.*)'"'"'$/\1/')"
  printf '%s\n' "${value:-$default}"
}

BRANCH="$(event_cfg default_branch main)"

# The upstream template ships event.yaml.example only; every workspace born
# from it has event.yaml. Scripts that only make sense in a workspace use this
# to refuse, and git-sync uses it to leave branches alone.
in_template() { [ ! -f "$ROOT/event.yaml" ]; }

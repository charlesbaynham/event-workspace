#!/usr/bin/env bash
# SessionStart hook — report whether the send-gate agent Claude Code loaded
# (.claude/agents/whatsapp-send-gate.md) is the shipped prompt plus this
# event's whatsapp.gate_rules, as agent-tools/agents/render.sh would build it.
# Reports only: agents are read at session start, so a fix made now applies
# from the next session.
set -uo pipefail

. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
in_template && exit 0
out="$("$ROOT/agent-tools/agents/render.sh" --check 2>&1)"; rc=$?
case $rc in
  0) : ;;
  3) printf 'gate hook: %s\n' "$out"
     printf 'gate hook: THIS session is running a send-gate that does not match event.yaml.\n'
     printf 'gate hook: run agent-tools/agents/render.sh and commit; it applies from the next session.\n' ;;
  *) printf 'gate hook: could not check the send-gate: %s\n' "$out" ;;
esac
exit 0

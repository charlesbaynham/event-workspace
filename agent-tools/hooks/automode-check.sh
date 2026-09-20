#!/usr/bin/env bash
# SessionStart hook — report whether the classifier rules in automode.json are
# what this environment actually loaded (~/.claude/settings.json), so drift is
# caught instead of silently assumed away. Reports only; the classifier reads
# its rules at startup, so nothing a hook writes now would apply.
set -uo pipefail

. "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
note() { printf 'automode hook: %s\n' "$1"; }
CANON="$ROOT/automode.json"
APPLIED="$HOME/.claude/settings.json"

[ -f "$CANON" ] || exit 0
command -v python3 >/dev/null 2>&1 || exit 0

fp() {
  python3 - "$1" <<'PY' 2>/dev/null
import hashlib, json, sys
try: block = json.load(open(sys.argv[1])).get("autoMode")
except Exception: print("UNREADABLE"); raise SystemExit
if not block: print("ABSENT"); raise SystemExit
print(hashlib.sha256(json.dumps(block, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()).hexdigest()[:12])
PY
}

WANT="$(fp "$CANON")"; HAVE="ABSENT"; [ -f "$APPLIED" ] && HAVE="$(fp "$APPLIED")"
case "$HAVE" in
  "$WANT") note "classifier rules ACTIVE and in sync with automode.json ($WANT)." ;;
  ABSENT|UNREADABLE)
    note "classifier rules from automode.json are NOT installed in this environment."
    note "They only take effect at session start: on the web, run agent-tools/automode/install.sh"
    note "from the environment setup script; locally, run it once by hand." ;;
  *) note "classifier rules ACTIVE but OUT OF SYNC with automode.json (env $HAVE, repo $WANT) —"
     note "re-run agent-tools/automode/install.sh where it was installed from; the live copy wins until then." ;;
esac
exit 0

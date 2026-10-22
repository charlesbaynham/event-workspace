#!/usr/bin/env python3
"""Memory helpers for the memory-compact skill and the SessionStart hook.

    memory.py index                 the note listing printed at SessionStart
    memory.py check                 validate notes, the digest and memory/; exit 1 on errors
    memory.py repo                  owner/repo of this workspace (from origin)
    memory.py state                 since / last_commit for the next filing pass
    memory.py state-set RUN SHA N   record a finished pass
    memory.py work RUNDIR           is there anything for the filer? (exit 0 yes, 1 no)
    memory.py log-snapshot          log entries since the baseline marker (what a pass files)
    memory.py trim-log SNAPSHOT     remove exactly those entries from memory/log.md
    memory.py sessions FILE... --since ISO
                                    filter saved list_sessions output to this repo's sessions
    memory.py transcript FILE... [--since ISO]
                                    condense saved list_events output into a readable transcript

Standard library only. Paths are relative to the repository root.
"""
import json
import re
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True,
                           text=True).stdout.strip() or ".")
MEM = ROOT / "memory"
NOTES = MEM / "notes"
LOG = MEM / "log.md"
DIGEST = MEM / "digest.md"
STATE = MEM / "filing-state.md"
ENTRY = re.compile(r"^- \[\d{4}-\d{2}-\d{2}\]")
BASELINE = re.compile(r"^<!-- compaction-baseline")
MAX_ALIASES = 8
DIGEST_WORDS = 500   # not counting the Tools & resources section
NOTE_WORDS = 1500
LOOKBACK_DAYS = 14  # a pass never reaches further back than this
FIRST_RUN_DAYS = 3  # window when neither the state file nor git history says when the last pass ran


def git(*args):
    return subprocess.run(["git", "-C", str(ROOT), *args], capture_output=True, text=True).stdout.strip()


def now_iso():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def parse_iso(s):
    return datetime.fromisoformat(s.replace("Z", "+00:00"))


# --- notes and frontmatter --------------------------------------------------

def frontmatter(path):
    """(dict or None, body). Flat `key: value` and `key: [a, b]` only."""
    text = path.read_text(encoding="utf-8", errors="replace")
    if not text.startswith("---\n"):
        return None, text
    end = text.find("\n---", 4)
    if end < 0:
        return None, text
    meta = {}
    for line in text[4:end].splitlines():
        m = re.match(r"^([A-Za-z_]+):\s*(.*)$", line)
        if not m:
            continue
        key, val = m.group(1), m.group(2).strip()
        if val.startswith("[") and val.endswith("]"):
            val = [v.strip().strip("'\"") for v in val[1:-1].split(",") if v.strip()]
        else:
            val = val.strip("'\"")
        meta[key] = val
    return meta, text[end + 4:].lstrip("\n")


def note_files():
    if not NOTES.is_dir():
        return []
    return sorted(p for p in NOTES.rglob("*.md")
                  if p.name not in ("AGENTS.md", "CLAUDE.md", "README.md"))


def first_line(body):
    for line in body.splitlines():
        line = line.strip()
        if line:
            return re.sub(r"^#+\s*", "", line)
    return ""


def cmd_index(_args):
    files = note_files()
    if not files:
        print("memory index: no notes under memory/notes/ yet.")
        return 0
    print("memory index — one line per note in memory/notes/. Read a note when its")
    print("description says it holds something this task needs; always read before")
    print("saying memory has nothing on a subject.")
    bare = 0
    for p in files:
        rel = p.relative_to(ROOT).as_posix()
        meta, body = frontmatter(p)
        if meta and meta.get("description"):
            aliases = meta.get("aliases") or []
            al = f" [aliases: {', '.join(aliases)}]" if aliases else ""
            if str(meta.get("sensitive", "")).lower() == "true":
                al += " [sensitive]"
            upd = meta.get("updated")
            print(f"{rel}{al} — {meta['description']}" + (f" [updated {upd}]" if upd else ""))
        else:
            bare += 1
            # No git date: in a shallow clone it is the clone boundary, not the last edit.
            print(f"{rel} — {first_line(body)[:120]}")
    if bare:
        print(f"({bare} note(s) have no frontmatter yet; the next filing pass adds it.)")
    return 0


def cmd_check(_args):
    errors, warnings = [], []
    names = {}
    for p in note_files():
        rel = p.relative_to(ROOT).as_posix()
        meta, body = frontmatter(p)
        if meta is None:
            warnings.append(f"{rel}: no frontmatter")
            continue
        for key in ("name", "description"):
            if not meta.get(key):
                errors.append(f"{rel}: frontmatter has no '{key}'")
        name = meta.get("name")
        if name:
            if name != p.stem:
                errors.append(f"{rel}: name '{name}' is not the file stem '{p.stem}'")
            if name in names:
                errors.append(f"{rel}: name '{name}' also used by {names[name]}")
            names[name] = rel
        words = len(body.split())
        if words > NOTE_WORDS:
            warnings.append(f"{rel}: {words} words (spin a subtopic out past {NOTE_WORDS})")
        aliases = meta.get("aliases") or []
        if isinstance(aliases, str):
            errors.append(f"{rel}: aliases must be a [list]")
        else:
            if len(aliases) > MAX_ALIASES:
                errors.append(f"{rel}: {len(aliases)} aliases (max {MAX_ALIASES})")
            for a in aliases:
                if re.search(r"#\s*\d|\b\d{4}-\d{2}-\d{2}\b|^\d+$|\b(trig|session|cse)_", a):
                    warnings.append(f"{rel}: alias '{a}' looks like a number, date or id; aliases are names")
    for p in sorted(MEM.rglob("*.md")) if MEM.is_dir() else []:
        if p.name == "CLAUDE.md":
            continue  # the deliberate subdirectory adapters
        for n, line in enumerate(p.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
            if re.match(r"^@\S", line):
                errors.append(f"{p.relative_to(ROOT).as_posix()}:{n}: '@' import line inside memory/")
    if DIGEST.exists():
        text = re.sub(r"<!--.*?-->", "", DIGEST.read_text(encoding="utf-8"), flags=re.S)
        text = re.sub(r"(?ms)^## Tools & resources.*?(?=^## |\Z)", "", text)
        words = len(text.split())
        if words > DIGEST_WORDS:
            warnings.append(f"memory/digest.md: {words} words outside Tools & resources "
                            f"(target {DIGEST_WORDS} or fewer)")
    for w in warnings:
        print(f"warning: {w}")
    for e in errors:
        print(f"error: {e}")
    if not errors and not warnings:
        print("memory check: clean")
    return 1 if errors else 0


# --- this workspace's identity ---------------------------------------------

def repo_slug():
    url = git("remote", "get-url", "origin")
    url = re.sub(r"\.git$", "", url.rstrip("/"))
    parts = re.split(r"[/:]", url)
    return "/".join(parts[-2:]).lower() if len(parts) >= 2 else ""


def cmd_repo(_args):
    print(repo_slug())
    return 0


def session_in_repo(sess, slug):
    for src in (sess.get("session_context") or {}).get("sources") or []:
        url = ((src.get("git_repository") or {}).get("url") or "").rstrip("/").lower()
        if re.sub(r"\.git$", "", url).endswith("/" + slug):
            return True
    return False


# --- filing state -----------------------------------------------------------

def read_state():
    state = {}
    if STATE.exists():
        for line in STATE.read_text(encoding="utf-8").splitlines():
            m = re.match(r"^(last_run|last_commit|last_sessions|retry|migrated):\s*(\S*)", line)
            if m:
                state[m.group(1)] = m.group(2)
    return state


def since_default():
    """When no pass has run: the last compaction, i.e. the last commit that moved the log's
    baseline marker (digest.md is edited in passing, so its date proves nothing). Never more
    than LOOKBACK_DAYS ago."""
    floor = datetime.now(timezone.utc) - timedelta(days=LOOKBACK_DAYS)
    found = (git("log", "-1", "--format=%H %cI", "-E", "--grep=^memory: (compact|nightly filing|filing pass)").split()
             or git("log", "-1", "--format=%H %cI", "-G", "compaction-baseline", "--", "memory/log.md").split())
    shallow = Path(git("rev-parse", "--git-path", "shallow"))
    if not shallow.is_absolute():
        shallow = ROOT / shallow
    boundary = set(shallow.read_text().split()) if shallow.exists() else set()
    # In a shallow clone the oldest commit "adds" the whole file, so a match there proves nothing.
    if len(found) == 2 and found[0] not in boundary:
        t = parse_iso(found[1]).astimezone(timezone.utc)
        if t > floor:
            return t.strftime("%Y-%m-%dT%H:%M:%SZ")
    fallback = datetime.now(timezone.utc) - timedelta(days=FIRST_RUN_DAYS)
    return max(fallback, floor).strftime("%Y-%m-%dT%H:%M:%SZ")


def filer_model():
    """event.yaml's memory_filer_model (top-level scalar); sonnet unless the owner chose otherwise."""
    cfg = ROOT / "event.yaml"
    if cfg.exists():
        for line in cfg.read_text(encoding="utf-8").splitlines():
            mm = re.match(r"^memory_filer_model:\s*['\"]?([A-Za-z0-9._-]+)", line)
            if mm:
                return mm.group(1)
    return "sonnet"


def cmd_state(_args):
    st = read_state()
    run = st.get("last_run", "never")
    since = run if run != "never" else since_default()
    floor = datetime.now(timezone.utc) - timedelta(days=LOOKBACK_DAYS)
    if parse_iso(since) < floor:
        since = floor.strftime("%Y-%m-%dT%H:%M:%SZ")
    commit = st.get("last_commit", "")
    if not commit or commit == "none" or not git("rev-parse", "--verify", "-q", commit + "^{commit}"):
        commit = git("rev-list", "-1", f"--before={since}", "HEAD") or git("rev-list", "--max-parents=0", "HEAD").split("\n")[0]
    print(f"last_run: {run}")
    print(f"since: {since}")
    print(f"last_commit: {commit}")
    print(f"head: {git('rev-parse', 'HEAD')}")
    print(f"retry: {st.get('retry', '')}")
    print(f"filer_model: {filer_model()}")
    print(f"repo: {repo_slug()}")
    print(f"started: {now_iso()}")
    return 0


def cmd_state_set(args):
    if len(args) not in (3, 4):
        print("usage: memory.py state-set <run-start ISO> <head sha> <sessions filed> [failed,ids]",
              file=sys.stderr)
        return 2
    run, sha, n = args[:3]
    retry = args[3] if len(args) == 4 else ""
    prev = read_state().get("last_run", "never")
    if prev not in ("", "never") and parse_iso(prev) >= parse_iso(run):
        # Passes can run as often as hourly; one that overran must not wind the state back.
        print(f"state-set: a later pass already recorded last_run {prev}; not recording {run}. "
              "Discard this pass's changes.", file=sys.stderr)
        return 3
    migrated = read_state().get("migrated", "")  # owned by the migrate skill; carried over
    text = STATE.read_text(encoding="utf-8") if STATE.exists() else (
        "# Memory filing state\n\n<!--\nWritten by the memory-compact skill's filing pass, and by "
        "nothing else.\n-->\n")
    header = text.split("\nlast_run:")[0].rstrip() if "last_run:" in text else text.rstrip()
    STATE.write_text(f"{header}\n\nlast_run: {run}\nlast_commit: {sha}\nlast_sessions: {n}\n"
                     f"retry: {retry}\nmigrated: {migrated}\n", encoding="utf-8")
    print(f"filing state: last_run {run}, last_commit {sha[:12]}, {n} session(s)"
          + (f", retry next pass: {retry}" if retry else ""))
    return 0


# --- the log ----------------------------------------------------------------

def log_lines():
    return LOG.read_text(encoding="utf-8").splitlines() if LOG.exists() else []


def cmd_log_snapshot(_args):
    lines = log_lines()
    start = max([i for i, l in enumerate(lines) if BASELINE.match(l)], default=-1) + 1
    for line in lines[start:]:
        if ENTRY.match(line):
            print(line)
    return 0


def cmd_trim_log(args):
    if len(args) != 1:
        print("usage: memory.py trim-log <snapshot file>", file=sys.stderr)
        return 2
    filed = {l for l in Path(args[0]).read_text(encoding="utf-8").splitlines() if ENTRY.match(l)}
    lines = log_lines()
    marker = f"<!-- compaction-baseline: filed {now_iso()} -->"
    # The marker goes where the filed block began, so every line still below it
    # (appended while the pass ran) is counted and filed next time. Nothing
    # filed: the old marker stays where it is.
    out, removed, placed = [], 0, False
    for line in lines:
        if BASELINE.match(line):
            if not filed:
                out.append(line)
                placed = True
            continue
        if line in filed:
            if not placed:
                out.append(marker)
                placed = True
            removed += 1
            continue
        out.append(line)
    if not placed:
        out.append(marker)
    LOG.write_text("\n".join(out).rstrip("\n") + "\n", encoding="utf-8")
    kept = sum(1 for l in out if ENTRY.match(l))
    print(f"trim-log: removed {removed} filed entr{'y' if removed == 1 else 'ies'}, {kept} newer kept")
    return 0


# --- saved tool output --------------------------------------------------------

def load_ccr(path):
    """The {"ccr": {...}} payload inside a saved tool result, wrapper text and all."""
    text = Path(path).read_text(encoding="utf-8", errors="replace")
    i = text.find('{"ccr"')
    if i < 0:
        i = text.find("{")
    obj, _ = json.JSONDecoder().raw_decode(text[i:])
    return obj.get("ccr", obj)


def flag(args, name, default=None):
    if name in args:
        i = args.index(name)
        val = args[i + 1]
        del args[i:i + 2]
        return val
    return default


def own_session_key():
    """The running session's id without its prefix: cse_X here is session_X in listings."""
    import os
    sid = os.environ.get("CLAUDE_CODE_REMOTE_SESSION_ID", "")
    return sid.split("_", 1)[1] if "_" in sid else ""


def cmd_sessions(args):
    since = flag(args, "--since")
    slug = flag(args, "--repo") or repo_slug()
    exclude = set(filter(None, (flag(args, "--exclude") or "").split(",")))
    if not args or not since:
        print("usage: memory.py sessions FILE... --since ISO [--repo owner/repo] [--exclude id,id]",
              file=sys.stderr)
        return 2
    since_t = parse_iso(since)
    own = own_session_key()
    oldest, more, last_id, seen = None, False, "", set()
    for f in args:
        page = load_ccr(f)
        rows = page.get("data", [])
        page_oldest = min((parse_iso(s["created_at"]) for s in rows), default=None)
        # Paging state comes from the oldest page given, whatever order the files came in.
        if page_oldest is not None and (oldest is None or page_oldest < oldest):
            oldest, more, last_id = page_oldest, page.get("has_more", False), page.get("last_id", "")
        for s in rows:
            if s["id"] in seen or s["id"] in exclude or not session_in_repo(s, slug):
                continue
            if own and s["id"].split("_", 1)[-1] == own:
                continue  # this pass's own session
            seen.add(s["id"])
            if parse_iso(s["updated_at"]) <= since_t:
                continue
            summ = (s.get("post_turn_summary") or {})
            summary = summ.get("recent_action") or summ.get("status_detail") or ""
            print("\t".join([s["id"], s["created_at"][:16], s["updated_at"][:16],
                             s.get("session_status", "").replace("SESSION_STATUS_", ""),
                             s.get("title", ""), summary.replace("\t", " ")]))
    keep_paging = more and oldest is not None and oldest > since_t - timedelta(days=LOOKBACK_DAYS)
    print(f"# oldest created_at on these pages: {oldest}; has_more: {more}; last_id: {last_id}")
    print("# " + (f"page on: list_sessions after_id={last_id}" if keep_paging
                  else "stop paging: nothing older can be in the window"))
    return 0


def cmd_work(args):
    """Anything for the filer? Findings in candidates/, or log entries in the snapshot."""
    if len(args) != 1:
        print("usage: memory.py work <run dir>", file=sys.stderr)
        return 2
    run = Path(args[0])
    findings = 0
    for c in sorted((run / "candidates").glob("*.md")):
        findings += sum(1 for l in c.read_text(encoding="utf-8").splitlines()
                        if re.match(r"^- \[", l))
    snap = run / "log-snapshot.md"
    entries = sum(1 for l in snap.read_text(encoding="utf-8").splitlines() if ENTRY.match(l)) \
        if snap.exists() else 0
    print(f"findings: {findings}; log entries: {entries}")
    print("file: yes" if findings or entries else "file: no — nothing durable; advance the state only")
    return 0 if findings or entries else 1


def text_of(content):
    if isinstance(content, str):
        return content
    parts = []
    for block in content or []:
        if block.get("type") == "text":
            parts.append(block.get("text", ""))
        elif block.get("type") == "image":
            parts.append("[image]")
    return "\n".join(parts)


def clip(s, n):
    s = " ".join(str(s).split())
    return s if len(s) <= n else s[:n] + f" …[+{len(s) - n} chars]"


def cmd_transcript(args):
    since = flag(args, "--since")
    if not args:
        print("usage: memory.py transcript FILE... [--since ISO]", file=sys.stderr)
        return 2
    since_t = parse_iso(since) if since else None
    events, seen, oldest, first_id, more = [], set(), None, "", False
    for f in args:
        page = load_ccr(f)
        rows = page.get("data", [])
        page_oldest = min((parse_iso(ev["created_at"]) for ev in rows), default=None)
        # Paging state comes from the oldest page given, whatever order the files came in.
        if page_oldest is not None and (oldest is None or page_oldest < oldest):
            oldest, more, first_id = page_oldest, page.get("has_more", False), page.get("first_id", "")
        for ev in rows:
            t = parse_iso(ev["created_at"])
            kind = "user" if "user" in ev else "assistant" if "assistant" in ev else None
            if not kind:
                continue
            inner = ev[kind].get("internal_anthropic_catchall") or {}
            uid = ev[kind].get("uuid")
            if uid in seen or (since_t and t <= since_t):
                continue
            seen.add(uid)
            events.append((t, kind, inner))
    events.sort(key=lambda e: e[0])
    for t, kind, inner in events:
        stamp = t.strftime("%Y-%m-%d %H:%M")
        msg = inner.get("message") or {}
        content = msg.get("content")
        if kind == "user":
            if inner.get("client_platform"):
                print(f"[{stamp}] HUMAN ({inner['client_platform']}): {text_of(content)}")
                continue
            if isinstance(content, str):
                print(f"[{stamp}] INJECTED: {clip(content, 300)}")
                continue
            for block in content or []:
                if block.get("type") == "tool_result":
                    res = block.get("content")
                    res = text_of(res) if not isinstance(res, str) else res
                    print(f"[{stamp}] TOOL RESULT{' (error)' if block.get('is_error') else ''}: {clip(res, 400)}")
                elif block.get("type") == "text":
                    print(f"[{stamp}] INJECTED: {clip(block.get('text', ''), 300)}")
        else:
            for block in content or []:
                if block.get("type") == "text" and block.get("text", "").strip():
                    print(f"[{stamp}] ASSISTANT: {block['text']}")
                elif block.get("type") == "tool_use":
                    inp = block.get("input") or {}
                    shown = inp.get("command") or inp.get("description") or json.dumps(inp, ensure_ascii=False)
                    print(f"[{stamp}] TOOL CALL {block.get('name')}: {clip(shown, 300)}")
    reached = not more or (since_t is not None and oldest is not None and oldest <= since_t)
    print(f"# {len(events)} events; oldest on these pages: {oldest}; first_id: {first_id}; has_more: {more}")
    print("# " + ("window covered" if reached else f"older events remain: list_events before_id={first_id}"))
    return 0


COMMANDS = {
    "index": cmd_index, "check": cmd_check, "repo": cmd_repo, "state": cmd_state,
    "state-set": cmd_state_set, "log-snapshot": cmd_log_snapshot, "trim-log": cmd_trim_log,
    "sessions": cmd_sessions, "transcript": cmd_transcript, "work": cmd_work,
}

if __name__ == "__main__":
    if len(sys.argv) < 2 or sys.argv[1] not in COMMANDS:
        print(__doc__)
        sys.exit(2)
    try:
        sys.exit(COMMANDS[sys.argv[1]](sys.argv[2:]))
    except BrokenPipeError:
        sys.exit(0)

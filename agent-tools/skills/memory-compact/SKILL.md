---
name: memory-compact
description: The memory filing pass — read the sessions launched with this event's repository in scope since the last pass, plus git history and memory/log.md, and file what is durable into memory/notes/ and the digest. Run nightly by a scheduled task (a Haiku session selects and dispatches, Haiku subagents review one session each, an Opus subagent files and commits). Also use when the owner asks to compact, refresh or update memory. (Creating or repairing the nightly task is the setup skill's job.)
---

# The memory filing pass

Working sessions don't stop to file what happens in a conversation; this pass
does it afterwards, with the whole exchange in view. It reads three things since
the last pass:

- **Session transcripts** — every cloud session on the owner's account that was
  launched with **this repository in scope**. Sessions without it are never
  read, however related their title looks: the owner runs many unrelated
  sessions, and none of them belong in this event's memory.
- **Git history** — covers the sessions the listing cannot show (scheduled
  tasks, webhook wakes), which commit their work and leave log lines.
- **`memory/log.md`** — what sessions logged because a transcript would not
  carry it.

Three roles, and the split is the point: **you select and dispatch** (this
file), **reviewers** read one session each and extract findings
([reviewer.md](reviewer.md)), **one filer** decides what is durable, edits the
notes and the digest, trims the log and commits ([filing.md](filing.md)). Do
not review or file yourself when you can dispatch — the judgement belongs to
the filer's model.

`memory.py` (beside this file) does the mechanical parts. Run it from the
repository root as `python3 agent-tools/skills/memory-compact/memory.py <cmd>`.

## Running the pass

1. **Start clean.** Switch to the default branch in `event.yaml` and
   `git pull --ff-only`. Make a run directory and keep its path:
   `RUN=$(mktemp -d)`; `mkdir $RUN/candidates`.

2. **Fix the window.** `memory.py state > $RUN/state.txt`. It prints `since`
   (read sessions and log entries after this), `last_commit` (read commits
   after this), `head`, `started`, `repo` (`owner/repo` of this workspace) and
   `retry` (sessions a failed review left for this pass). Then
   `memory.py log-snapshot > $RUN/log-snapshot.md` — exactly the log entries
   this pass will file; lines appended after this moment wait for the next one.

3. **Select the sessions.** You need `mcp__claude-code-remote__list_sessions`
   and `list_events`; load them with ToolSearch
   (`select:mcp__claude-code-remote__list_sessions,mcp__claude-code-remote__list_events`)
   if they are deferred. If they do not exist in this session, skip to step 5
   and say in your report that transcripts were not read.

   Call `list_sessions` with `mine: true`, `limit: 20`. **A session is in only
   if one of its `session_context.sources[].git_repository.url` values ends in
   `/<repo>`** (case-insensitive, `.git` ignored) **and its `updated_at` is
   after `since`.** Add every id on the `retry:` line whatever its date. Never
   add your own session.
   - When the tool saves the result to a file instead of showing it, run
     `memory.py sessions <file> [<file>…] --since <since>`: it applies the same
     rule and says whether to page on.
   - Page with `after_id` = the page's `last_id` while `has_more` is true and
     the page's oldest `created_at` is within 14 days before `since` (a session
     can be resumed long after it was created; older than that is not worth
     the pages).

   Write the result to `$RUN/sessions.tsv`, one line per session: id, title.
   Zero sessions is a normal night — go on to step 5.

4. **Review each session — Haiku subagents.** For each selected session, call
   the Agent tool with `subagent_type: "general-purpose"`, `model: "haiku"`,
   and this prompt, filled in:

   > Memory review of one session for the event workspace at `<repo root>`.
   > Read `<repo root>/agent-tools/skills/memory-compact/reviewer.md`
   > completely and follow it. Session: `<id>` — "`<title>`". Window: events
   > after `<since>`. Write your findings to `<RUN>/candidates/<id>.md` and
   > reply with one line: `<id>: <n> findings`.

   Up to five at once, in one message. A review that fails or writes no file
   gets one more try; after that, add its id to `$RUN/failed.txt` and move on.
   Failed ids are carried to the next pass, not lost.

5. **File — one Opus subagent.** Call the Agent tool with
   `subagent_type: "general-purpose"`, `model: "opus"`, and:

   > Memory filing pass for the event workspace at `<repo root>`. Read
   > `<repo root>/agent-tools/skills/memory-compact/filing.md` completely and
   > follow it. Run directory: `<RUN>` (state.txt, log-snapshot.md,
   > sessions.tsv, candidates/, failed.txt if present). End with the report
   > the procedure asks for.

   If it fails, call it once more with the same prompt. If that fails too,
   report the failure and stop: the filer is the only step that advances the
   state, so the next pass simply covers this window as well.

6. **Report.** The filer's report verbatim, then one line of your own:
   sessions selected, reviews failed, whether transcripts were read at all.

**Without the Agent tool** (Codex, or a session that lacks it), do the steps
yourself in the same order: reviewer.md once per session, then filing.md.
**Run by hand** — the owner asked to compact or refresh memory — it is the same
pass. Make sure anything durable from your own session is already in a note or
the log first, since your own transcript is not reviewed.

## Setting up the nightly task

The scheduled task that runs this pass is created, audited and repaired by the
**`setup` skill** (`agent-tools/skills/setup/SKILL.md`), together with the
workspace's other automations. Use that; don't create a task from here.

## When something is off

- `memory-check.sh` reports the last pass at SessionStart. Older than about
  36 hours means the task has stopped or is failing: say so to the owner once,
  then run the `setup` skill, which audits and repairs it.
- Co-users on their own Claude accounts, local CLI sessions and Codex are
  invisible to the listing. The contract tells those sessions to keep logging.

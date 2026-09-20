# Running agents in ephemeral cloud containers — things learned

Short, generic, and each one cost an afternoon somewhere.

## A bare background process is not a monitor

The container sleeps the moment the session goes idle. Every unmanaged process
in it freezes — a `run_in_background` polling loop, its `sleep` backstop, a
`tailscaled`. It resumes only when something else wakes the session, and then
reports as if nothing happened. The harness's `Monitor` tool is the exception:
it keeps the session alive across the wait. Use `Monitor` for anything that
must survive an idle turn. When ending the turn is preferable, use a wake from
*outside* the container — a scheduled routine, `send_later`, a PR subscription,
a webhook.

**Every monitor needs a backstop that fires even if the thing it's watching for
never happens.** A typo in the condition otherwise hangs the task silently.
Before starting one, know exactly what "done" looks like; pair the condition
with a maximum wait; and treat hitting the timeout as the prompt to work out
*why* (slow, wrong, or genuinely stuck), never as an answer in itself.

## `autoMode` in a repository's settings is ignored

Claude Code's auto-mode classifier reads `autoMode` from user, managed and
flag settings only. A block in `.claude/settings.json` or
`.claude/settings.local.json` is skipped with a logged warning — a repo must
not be able to grant itself allow rules. `permissions.allow/ask/deny` and hooks
in the repo *are* read. So: put tool allow-lists in `permissions.allow` (both
the `mcp__X__*` and `mcp__claude_ai_X__*` spellings — cloud and local sessions
see different prefixes), and put any note to the classifier in the routine
prompt, which is the one classifier-visible place a consumer controls.

## The checkout is a restored snapshot, not a fresh clone

A cloud session's `.git` can be a snapshot days old, refreshed by a shallow
`--depth 50` fetch. Once the repo has moved more than 50 commits, git reports
the local default branch as having *no common ancestor* with the remote
(`ahead 17, behind 51`). That divergence is an illusion. `git-sync.sh` deepens
the clone before comparing; never `reset --hard` to "fix" it.

## Concurrent sessions race on the default branch

Webhook-fired sessions run in parallel. Two of them appending to
`memory/log.md` and pushing within seconds conflict, and the one that gives up
on "non-fast-forward" has recorded nothing. `sync-push.sh` commits, rebases,
merges log appends by keeping both sides, and retries.

## Plugins and submodules, as of September 2026

A Claude Code plugin can ship skills, agents, hooks and MCP config, and its
hooks run in cloud sessions — but its `CLAUDE.md` is not loaded, whether an
`enabledPlugins` entry auto-installs in a fresh container is undocumented, and
git submodule initialisation in cloud sessions is undocumented. That is why
this engine is a vendored directory with an update script rather than either.

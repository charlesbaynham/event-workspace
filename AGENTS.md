# memory-workspace — the template, and how to maintain it

This repository is the **upstream template** for memory workspaces — agent
memory stores for one domain of work: an event, a project with a team, or
open-ended life admin. It holds the engine in `agent-tools/`, the contract
those workspaces run under, the example configuration, and the onboarding
procedure that turns a clone into someone's own repository. It is **not a
workspace itself** — there is no `workspace.yaml`, no `WORKSPACE.md`, nothing
to remember but its own development — and it does not run under the contract
it ships. A session here is maintaining a codebase and behaves like one.

Not sure which repository you are in? A workspace has `workspace.yaml`; the
template has only `workspace.yaml.example`, and its remote is
`charlesbaynham/memory-workspace`. `agent-tools/lib.sh` makes the same test
(`in_template`) for the scripts.

## Two contracts, one per job

| File | Loaded where | Job |
|---|---|---|
| `AGENTS.md` — this file | here, through `CLAUDE.md` and Codex | how to maintain the template |
| `agent-tools/AGENTS.md` | every workspace, as its root `AGENTS.md` | how a workspace session behaves |

`agent-tools/AGENTS.md` is installed over a workspace's root `AGENTS.md` by
`ONBOARDING.md` at birth and by `agent-tools/update.sh` on every update. It is
never loaded here and nothing in it applies here — in particular its "commit
straight to the default branch" rule, which is for a synchronisation
repository, not for this one.

Put text in the right file. Anything a workspace session must obey goes in
`agent-tools/AGENTS.md`; anything about maintaining this repository goes here.
Never write a template-only carve-out into the shipped contract — a workspace
session should never have to ask "does this apply to me?" — and never rely on
the shipped contract being in context here.

## Git here: a normal codebase

- Branch, commit, open a pull request. The harness's session instructions
  (develop on `claude/…`, open a PR) are the convention here, not scaffolding
  to escape from.
- `agent-tools/sync-push.sh` and `agent-tools/update.sh` refuse to run here.
  The engine is edited in place; nothing is vendored.
- The SessionStart hooks run here too, because every workspace inherits them
  and the template has to tolerate its own tooling: `git-sync.sh` fetches and
  fast-forwards the default branch but leaves the current branch alone;
  `memory-check.sh` counts this repository's own log.
- Owner register: Charles is technical. Say the number, name the file.

## What reaches a workspace, and when

- **`agent-tools/`** is the only part that propagates: `update.sh` replaces it
  wholesale in every consumer (except the paths in its `KEEP` list) and
  reinstalls `agent-tools/AGENTS.md` as the root `AGENTS.md`. **A behaviour
  change that has to reach existing workspaces goes in here.**
- Everything else reaches a workspace **once, by cloning, at birth**:
  `CLAUDE.md`, `.claude/`, `.codex/`, `.agents/`, the `.example` files,
  `memory/`, `docs/`. Changing them later changes nothing for a workspace
  that already exists.
- `ONBOARDING.md` is one-shot: the child deletes it in its first commit. It is
  also what makes a clone stop looking like the template — it installs
  `agent-tools/AGENTS.md` as the child's root `AGENTS.md`, trims `CLAUDE.md`,
  rewrites the README for the workspace, resets `memory/`, and drops
  `docs/spin-out-plan.md`. Change any of those files here and check whether
  `ONBOARDING.md` still says the right thing about them.
- `.claude/skills/*` and `.claude/agents/*` are symlinks into `agent-tools/`;
  `.agents/skills/*` (Codex) are stub files pointing at the same place. A new
  skill or agent needs its entry in both. A **template-only** skill
  (`bump-version`) is a real directory under `.claude/skills/` instead, and
  `ONBOARDING.md` deletes it at birth — a workspace never releases the engine.
- Per-workspace behaviour never goes in `agent-tools/` — it belongs in the
  `.example` files and, for the consumer, in `workspace.yaml`, `WORKSPACE.md` and
  `memory/`. Keep the `.example` files in step with the keys `lib.sh` and the
  skills actually read.
- **The engine is domain-neutral.** Events are a first-class use, but so are
  a team's project and open-ended life admin. Nothing in `agent-tools/` may
  assume an event (a date, guests, RSVPs) or WhatsApp: the bot is optional and
  every rule about it is conditional on a `whatsapp:` block. Event-flavoured
  wording belongs in examples, clearly marked as one case among several.

## Versioning

When a change to `agent-tools/` — the shipped contract included — alters
behaviour, bump `agent-tools/VERSION` and write the `agent-tools/CHANGELOG.md`
entry in the same commit. **Use the `bump-version` skill**: it carries the
semver rules, how to read what has changed since the last bump, and what a
consumer needs from the entry. Changes outside `agent-tools/` reach nobody
through `update.sh` and need no bump.

**A major version means a change to the structure of memory already stored in
consumer repositories** — note format, file layout, the state the tooling
reads, anything an existing workspace's `memory/` has to be rewritten to
match. Every major **ships a migration**,
`agent-tools/skills/migrate/<X.0.0>.md`, which the `migrate` skill runs. The
upgrade procedure invokes it: `update.sh` announces it, the shipped contract
("Updating the engine") requires it, and `memory-check.sh` reports memory not
yet migrated. A migration must be safe to re-run, must change only what the
workspace owns — `memory/`, the files the engine reads from it
(`workspace.yaml`, `WORKSPACE.md`, the imports in `CLAUDE.md`) and skill
registration — never `agent-tools/`, and must end by adding its version to
`migrated:` in `memory/filing-state.md`. Test it on a scratch copy of a real
consumer before release. Bump the template's own seed `migrated:` line too,
since a workspace born on a major already has that structure.

Other breaking changes (a `workspace.yaml` key renamed, a hook moved) are majors
too from `1.0.0` on, with a **To do by hand** section in the entry, or a
migration step when the migration can do it.

**Compatibility shims: one exception, and it expires.** By default keep none:
drop the old key, name or value and say what to edit. The exception is a file
or key the engine needs *in order to run the migration that renames it* — the
config file `in_template` tests, say. `update.sh` lands the new engine before
the migration runs, so without a fallback the workspace stops looking like
one. Such a fallback reads the old name only when the new one is missing, is
commented as belonging to that migration, is listed in the changelog entry,
and is removed in the next major. 1.0.0's is the one live example:
`event.yaml`/`EVENT.md` in `lib.sh`, `memory.py`, `render.sh` and
`load-memory.sh`, to be dropped in 2.0.0.

Consumers on `agent_tools_track: pinned` compare the text of
`agent-tools/VERSION` against upstream's copy at session start, so a bump on
`main` is the release: nothing has to be tagged, and the changelog entry is
what they are shown when deciding. Consumers on `latest` get every push, so
`main` should always be installable.

**Every version bump also gets a GitHub release, automatically.**
`.github/workflows/release.yml` runs on every push to `main`: when no `vX.Y.Z`
tag exists for the number in `agent-tools/VERSION`, it tags the commit that
last changed that file, uses the version's changelog entry as the notes (the
commit message if there is none), and attaches a zip of the repository at
that commit. Nothing in the update path reads releases; they are for people
browsing the repository. So a bump needs a changelog heading that matches
`VERSION` exactly, and once it merges, check `list_releases`: if the release
is missing, the workflow run says why. The workflow is template-only;
`ONBOARDING.md` deletes it at birth.

## Memory here

`memory/` here is this repository's own working memory. There is no nightly
filing pass here, so log template decisions and gotchas to `memory/log.md` as
they happen, and compact by hand when the hook says the log is long: follow
`agent-tools/skills/memory-compact/filing.md` from the log and git alone, but
commit on your branch instead of running `sync-push.sh`, which refuses here. It is also the seed every workspace starts from:
`ONBOARDING.md` resets `log.md`, `digest.md`, `user-edits.md` and
`filing-state.md` to their empty forms at birth, so nothing logged here leaks
into a workspace, and the headings and header comments are what a new workspace
inherits. Keep those stable; `memory.py` parses the log's entry format, the
baseline marker and the state file's keys.

## Checking a change before it ships

- `bash -n` every script you touched; run the hooks by hand from here
  (`agent-tools/hooks/git-sync.sh`, `memory-check.sh`) — they must exit 0
  and say something sensible in the template.
- Read the shipped contract as its reader would: a session with no memory of
  this conversation and no idea the template exists.
- The real test is a consumer. In a scratch directory, clone this repository
  at your branch, put it through `ONBOARDING.md`, or drop a `workspace.yaml` in
  and run `agent-tools/update.sh <branch>`, and read the `git diff` it leaves.

Design history in [docs/spin-out-plan.md](docs/spin-out-plan.md); what running
agents in cloud containers taught us in
[docs/agent-ops-notes.md](docs/agent-ops-notes.md).

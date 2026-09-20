# event-workspace — the template, and how to maintain it

This repository is the **upstream template** for event workspaces: the engine
in `agent-tools/`, the contract those workspaces run under, the example
configuration, and the onboarding procedure that turns a clone into someone's
own repository. It is **not an event workspace itself** — there is no
`event.yaml`, no `EVENT.md`, no event to remember — and it does not run under
the contract it ships. A session here is maintaining a codebase and behaves
like one.

Not sure which repository you are in? A workspace has `event.yaml`; the
template has only `event.yaml.example`, and its remote is
`charlesbaynham/event-workspace`. `agent-tools/lib.sh` makes the same test
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
- `ONBOARDING.md` is one-shot: the child deletes it in its first commit.
- `.claude/skills/*` and `.claude/agents/*` are symlinks into `agent-tools/`;
  `.agents/skills/*` (Codex) are stub files pointing at the same place. A new
  skill or agent needs its entry in both.
- Per-event behaviour never goes in `agent-tools/` — it belongs in the
  `.example` files and, for the consumer, in `event.yaml`, `EVENT.md` and
  `memory/`. Keep the `.example` files in step with the keys `lib.sh` and the
  skills actually read.

## Versioning

When a change to `agent-tools/` — the shipped contract included — alters
behaviour, bump `agent-tools/VERSION` in the same commit. Semantic versioning:
patch = fix, minor = feature or behaviour change, major = a consumer has to
act (an `event.yaml` key, the file layout, a skill's section numbers). Then
**remind Charles to consider tagging it `vX.Y.Z`** — consumers on
`agent_tools_track: tags` see nothing until a tag exists, and a tag is his to
push. Consumers on `main` get every push, so `main` should always be
installable.

## Memory here

`memory/` here is this repository's own working memory — log template
decisions and gotchas to `memory/log.md` as they happen, exactly as a
workspace session would, and compact when the hook says so. It is also the
seed every workspace starts from: `ONBOARDING.md` resets `log.md`,
`digest.md` and `user-edits.md` to their empty forms at birth, so nothing
logged here leaks into an event, and the headings and header comments are
what a new workspace inherits. Keep those stable.

## Checking a change before it ships

- `bash -n` every script you touched; run the hooks by hand from here
  (`agent-tools/hooks/git-sync.sh`, `memory-check.sh`) — they must exit 0
  and say something sensible in the template.
- Read the shipped contract as its reader would: a session with no memory of
  this conversation and no idea the template exists.
- The real test is a consumer. In a scratch directory, clone this repository
  at your branch, put it through `ONBOARDING.md`, or drop an `event.yaml` in
  and run `agent-tools/update.sh <branch>`, and read the `git diff` it leaves.

Design history in [docs/spin-out-plan.md](docs/spin-out-plan.md); what running
agents in cloud containers taught us in
[docs/agent-ops-notes.md](docs/agent-ops-notes.md).

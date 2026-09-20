---
name: bump-version
description: Release a new engine version from the event-workspace template — decide major/minor/patch from what changed under agent-tools/ since the last bump, write the CHANGELOG entry, and set VERSION in the same commit. Use when a change to agent-tools/ is ready to ship, when asked to bump/release/cut a version, or when a session is about to commit engine changes without touching VERSION.
---

# Bumping the engine version

`agent-tools/VERSION` is what every consumer compares itself against, and
`agent-tools/CHANGELOG.md` is the only description of a release they ever see:
a pinned workspace is shown every entry it does not yet have, at session start
and again when it updates. The version number tells them how much care the
update needs; the entry tells them what it is.

**Template only.** This is the upstream repository (no `event.yaml`; remote
`charlesbaynham/event-workspace`). A workspace never bumps the engine — it
receives it.

## 1. Find the last bump, and what has happened since

```bash
git log --oneline -1 -- agent-tools/VERSION        # the last bump commit
git log --oneline <that sha>..HEAD -- agent-tools/ # candidate changes
git diff <that sha>..HEAD -- agent-tools/          # read it, do not skim it
```

Include uncommitted work in the working tree. **Only `agent-tools/` counts** —
`README.md`, `ONBOARDING.md`, `docs/`, the template's own `AGENTS.md` and
`memory/` never reach a consumer through `update.sh`, so changes confined to
them need no bump at all. Say so and stop if that is the case.

## 2. Decide the number

Semantic versioning, read from the consumer's side:

| Bump | When | Examples |
|---|---|---|
| **major** | a consumer has to do something by hand, or something they rely on is gone | an `event.yaml` key renamed with no fallback, a file they registered themselves moved, a skill's section numbers renumbered (`AGENTS.md` cites them) |
| **minor** | new or changed behaviour that lands cleanly | a new hook or skill, a new `update.sh` mode, wording in the shipped contract that changes what a session does |
| **patch** | a fix with no behaviour change | a hook crashing on an empty file, a typo in the contract, a tightened regex |

Rules of thumb:

- **Take the highest bump any single change earns**, not the average.
- **Ask whether it can be made to land cleanly instead.** Keeping the old
  `event.yaml` key readable, or having `update.sh` repoint a renamed hook, turns
  a major into a minor — and is usually worth the few lines.
- Below `1.0.0` the same rules apply; do not use "it's pre-1.0" as a reason to
  skip a major.
- One bump per release, not one per commit. If `VERSION` was already raised
  since the last push, extend that entry instead of adding another.

State the number you have chosen and why in one line before writing anything.

## 3. Write the entry, then the version

New `## X.Y.Z — YYYY-MM-DD` section at the top of `agent-tools/CHANGELOG.md`,
under the existing preamble and comment. Keep the shape of the entries already
there: `### Changed`, `### Added`, `### Fixed`, `### Removed`, and
`### To do by hand` for anything the consumer must do themselves (a major
should always have one).

Write for the owner of a workspace who has never read this repository:

- What changed for **them** — the command they run, the key they write, the
  behaviour they will notice. Not the commit, not the file you edited.
- One line per change, in the order they would care about.
- Name old and new spellings when something is renamed, and say plainly when
  the old one still works.

Then `agent-tools/VERSION` — the bare number, no `v`, single line.

## 4. Commit both with the change

Same commit as the change itself wherever possible; if the change is already
committed, one follow-up commit carrying `VERSION` and `CHANGELOG.md` and
nothing else. Then tell Charles the new version and the headline of the entry.

Tagging is optional — nothing in the update path reads git tags any more.
A `vX.Y.Z` tag is a readable marker for a release you care about, and it is his
to push.

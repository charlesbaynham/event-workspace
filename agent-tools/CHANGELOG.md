# Changelog

Every released version of the engine (`agent-tools/`), newest first. The
version at the top is what `agent-tools/VERSION` holds.

Semantic versioning: **major** — a consumer has to do something by hand
(an `event.yaml` key, a moved file, renumbered sections); **minor** — new
behaviour you may want to read about, but nothing to do; **patch** — a fix
with no behaviour change. **Until 1.0.0, breaking changes ride in a minor and
keep no compatibility shims** — the entry says so, and lists what to edit under
**To do by hand**.

A workspace on the `pinned` track is shown every entry newer than the version
it runs, both by `agent-tools/hooks/version-check.sh` at session start and by
`agent-tools/update.sh`. Write each entry for that reader: what changed, and
what they have to do about it.

<!-- Maintainers: the bump-version skill (template only) writes this file and
     VERSION together, in the same commit as the change. One `## X.Y.Z — date`
     heading per version; headings are what the tooling parses. -->

## 0.6.0 — 2026-09-20

**Breaking, and nothing is carried over.** Before 1.0.0 this engine keeps no
compatibility shims: the old spellings below are simply gone, so a workspace
has to be edited once (see **To do by hand**).

### Changed

- The update tracks are now **`latest`** (follow upstream's default branch,
  what `main` used to mean) and **`pinned`** (stay put until you accept an
  offer, what `tags` used to mean). Any other value is still a branch name —
  and `tags` is now read as one, so a workspace left on it will fail to fetch.
- **Pinning no longer involves git tags.** The pin is the text of
  `agent-tools/VERSION`, compared against upstream's copy of the same file, so
  a release is offered as soon as it lands on upstream's default branch and
  nothing needs tagging.
- `agent-tools/hooks/tag-check.sh` is now `agent-tools/hooks/version-check.sh`.
- A pinned workspace moves with `agent-tools/update.sh --accept` (an explicit
  ref still works too). A bare `update.sh` keeps the pin, and says what it is
  declining to take.
- `event.yaml`: `agent_tools_tag_skip` → `agent_tools_version_skip` (bare
  versions, no `v`), `agent_tools_tag_check` → `agent_tools_update_check`.

### Added

- This changelog. Update offers quote every entry the workspace does not have
  yet, so the owner decides on the changes rather than on a version number.

### To do by hand

In `event.yaml`: `agent_tools_track: tags` → `pinned`, `main` → `latest`, and
rename `agent_tools_tag_skip` / `agent_tools_tag_check` (dropping any `v`
prefixes) if you have them. In `.claude/settings.json` and `.codex/hooks.json`,
point the `SessionStart` hook at `version-check.sh` instead of `tag-check.sh` —
those files are yours and no update writes to them, so until you do, nothing
will tell you an update has landed. `update.sh` says so when it notices.

## 0.5.0 — 2026-09-20

### Changed

- The `tags` track became a **pin**: a bare `update.sh` reinstalled the release
  the workspace was already on, and moving meant naming a release.

### Added

- `agent-tools/hooks/tag-check.sh`: checked upstream for newer tags at session
  start and offered them, with the answer remembered in `event.yaml`
  (`agent_tools_tag_skip`, `agent_tools_tag_check: off`).

### To do by hand

- Register the new hook beside the other `SessionStart` hooks in
  `.claude/settings.json` and `.codex/hooks.json` — those files are per-event
  and no update writes to them.

## 0.4.0 — 2026-09-20

### Changed

- The shipped contract split from the template's own maintainer guide:
  `agent-tools/AGENTS.md` travels with the engine, and `update.sh` installs it
  as the workspace's root `AGENTS.md`. Until 0.3.x, `update.sh` copied
  upstream's *root* `AGENTS.md`, which is now the maintainer guide.
- `lib.sh` gained `in_template`; `update.sh` and `sync-push.sh` refuse to run
  in the template, and `git-sync.sh` leaves its branches alone.

### To do by hand

- Upgrading from 0.3.x or earlier: copy upstream's `agent-tools/update.sh` over
  yours before running it, or you will get the wrong `AGENTS.md`.

## 0.3.0 — 2026-09-20

### Changed

- Tags became optional: `update.sh` followed `agent_tools_track` in
  `event.yaml` — the default branch by default, or semver tags.

## 0.2.0 — 2026-09-20

### Added

- Auto-mode classifier rules kept in the repository, installed by the setup
  script and drift-checked at session start.

## 0.1.0 — 2026-09-20

### Added

- The engine, scrubbed and generalised out of the first event workspace:
  hooks, skills, `update.sh`, `sync-push.sh`, and the contract.

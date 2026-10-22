---
name: migrate
description: Bring this workspace's stored memory into the structure a new major engine version expects, by running the migration for every major version crossed. Use straight after agent-tools/update.sh moves the engine across a major version (update.sh and the changelog say so), when memory-check or a session finds memory in an older shape than the engine expects, or when the owner asks to migrate.
---

# Migrating a workspace across major versions

A **major** engine version changes how memory is stored: file layout, note
format, the state the tooling reads. The engine can't do that on its own,
because the memory is this workspace's, not upstream's. So every major ships a
migration, `agent-tools/skills/migrate/<X.0.0>.md`, and an upgrade across it
isn't finished until the migration has run.

## 1. Work out which migrations apply

- **From**: the version this workspace ran before the update. That is
  `agent-tools/VERSION` in the commit before the engine update
  (`git log -2 --format=%h -- agent-tools/VERSION`, then
  `git show <older>:agent-tools/VERSION`), or what `update.sh` printed as
  installed.
- **To**: the current `agent-tools/VERSION`.
- Run, in ascending order, every `agent-tools/skills/migrate/<N>.0.0.md` where
  N is above From's major and no higher than To's. Skip any that
  `memory/filing-state.md`'s `migrated:` line already lists. Each migration
  adds its own version to that line when it finishes.

If none apply, say so and stop.

## 2. Before the first migration

- **The engine update must be committed already**, as its own commit (the
  contract's "Updating the engine"). A migration's commits change memory only,
  never `agent-tools/`.
- Be on the default branch, pulled. No uncommitted changes outside what you
  are about to do.
- Tell the owner in one line which migration(s) you're running and roughly
  what they change. A migration that needs a decision from them asks at the
  point it needs it.

## 3. Run each migration

Read the migration file completely and follow it. Each one ends by
recording itself in `memory/filing-state.md` and committing with
`agent-tools/sync-push.sh "migrate: <version> — <summary>"`. If a step fails,
stop there and report: a half-run migration is safer to resume than to paper
over, and each file says how to resume it.

## 4. Report

To the owner, in their register: what each migration changed (files, counts),
anything left for them to decide, and that the upgrade is complete.

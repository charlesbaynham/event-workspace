---
name: bump-version
description: Decide and apply an engine version bump in the event-workspace template — semver from what changed under agent-tools/, plus the CHANGELOG entry consumers are shown.
---

Read `.claude/skills/bump-version/SKILL.md` completely and follow it.
Resolve all relative resource paths from the repository root.

This skill is for the upstream template only (no `event.yaml`). A workspace
born from it does not bump the engine and should not carry this skill.

---
name: memory-compact
description: The memory filing pass — read the sessions launched with this workspace's repository in scope since the last pass, plus git history and memory/log.md, and file what is durable into memory/notes/ and the digest. Run by a scheduled task, nightly or as often as hourly (a Haiku session selects and dispatches, Haiku subagents review one session each, and only when there is something durable a filer subagent — Sonnet by default — files and commits). Also use when the owner asks to compact, refresh or update memory. (Creating or repairing the nightly task is the setup skill's job.)
---

Read `agent-tools/skills/memory-compact/SKILL.md` completely and follow it.
Resolve all relative resource paths from `agent-tools/skills/memory-compact/`.

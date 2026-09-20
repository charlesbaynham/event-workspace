# Claude Code adapter

The workspace contract is imported from `AGENTS.md`; the event's own rules and
the memory digest are imported separately so they are present from the first
turn.

@AGENTS.md
@EVENT.md
@memory/digest.md

## Maintaining the engine — applies only in `charlesbaynham/event-workspace` itself

When a change to `agent-tools/` or `AGENTS.md` alters behaviour, bump
`agent-tools/VERSION` (semantic versioning: patch = fix, minor = feature or
behaviour change, major = a consumer has to act) in the same commit, and
**remind Charles to consider tagging it `vX.Y.Z`** — consumers on
`agent_tools_track: tags` see nothing until a tag exists, and a tag is his to
push. Consumers on `main` get every push. In a consumer's copy of this file
this section is inert.

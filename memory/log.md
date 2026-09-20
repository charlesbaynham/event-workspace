# Memory log (append-only)

<!--
Sessions APPEND terse observations here as work happens — never edit or reorder
existing lines. The memory-compact skill folds this log into digest.md and
truncates it. Git history preserves everything.

Format, one observation per line:

- [YYYY-MM-DD] TYPE: observation

TYPE is one of:
  DECISION  — a choice was made (record the choice AND the reason)
  STATE     — something changed: built, fixed, broke, merged, deployed
  LEARNED   — a fact worth not re-discovering (gotcha, quirk, preference)
  OPEN      — a question raised or task deferred
  RESOURCE  — an ID, path, URL, or environment fact worth keeping
  CORRECTION— something previously believed/recorded is wrong

Rules for writers:
- One line each, written at the moment the thing happens — not batched at the end
  (sessions die without warning; unlogged observations are lost).
- Provenance matters: "User decided X" vs "I suggested X (not yet confirmed)".
  Never log your own suggestion as the user's decision.
- Never log secrets, tokens, or credentials.
- Hypotheticals stay marked as hypothetical.
-->

<!-- compaction-baseline: fresh workspace -->
- [2026-09-20] DECISION: setup moved out of the README into ONBOARDING.md — a doc the agent executes as a prompt; Charles wants the pasted prompt short and hand-edited by nobody, so it only clones and points at the doc.
- [2026-09-20] DECISION: onboarding is a document, not a skill — Charles's call; a skill would need triggering and would live in agent-tools/, which update.sh overwrites.
- [2026-09-20] STATE: ONBOARDING.md added (3-round interview → recap → detach .git → write event.yaml/EVENT.md/automode.json → seed memory → create repo → delete itself in the first commit → hand-off checklist); README setup block replaced with a 5-line prompt.
- [2026-09-20] LEARNED: .claude/settings.json ships permissions.allow for the example WhatsApp prefix (mcp__Event_Whatsapp__) — onboarding must replace it in both spellings (mcp__X__*, mcp__claude_ai_X__*) or remove it, or every consumer carries a dead allow rule.
- [2026-09-20] LEARNED: a feature cannot be switched off by deleting a skill — update.sh replaces agent-tools/ wholesale, so "off" means leaving it unconfigured; ONBOARDING.md says this out loud.
- [2026-09-20] OPEN: ONBOARDING.md is delivered only by cloning upstream, not by update.sh (consumers delete it after setup) — fine while it stays one-shot, revisit if it ever needs to re-run.

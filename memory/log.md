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

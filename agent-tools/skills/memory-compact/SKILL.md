---
name: memory-compact
description: Fold memory/log.md into memory/digest.md and truncate the log. Use when the log exceeds ~40 entries, when the digest contradicts current reality, after a major milestone, at the end of a substantial session, or when the user asks to compact/update/refresh memory.
---

# Memory compaction

Turn the append-only observation log into a clean structured digest.
This is a **rewrite**, not an append — the output digest should read as if
written fresh by someone who knows everything and narrates nothing.

## Procedure

1. **Read all three files**: `memory/digest.md`, `memory/log.md`,
   `memory/user-edits.md`. If the log is empty or trivial (<5 entries), tell
   the user compaction isn't needed yet and stop.

2. **Apply user edits first.** Every entry in user-edits.md is a hard
   constraint:
   - Factual overrides beat both the old digest and the log.
   - "Exclude …" entries: the topic must be absent from the new digest, even
     if log entries mention it. Do not paraphrase excluded content back in.

3. **Merge log into digest**, section by section:
   - DECISION / STATE → **Current state** (superseding contradicted claims —
     delete the old claim, don't stack "previously X, now Y" chains)
   - OPEN → **On the horizon**; remove horizon items the log shows resolved
   - LEARNED → **Key learnings & principles**
   - RESOURCE → **Tools & resources**
   - CORRECTION → fix the digest wherever the wrong fact lives
   - Purpose & context changes are rare — only touch that section if the log
     explicitly shows the project's purpose or cast changed.

4. **Compress.** Target 400–800 words total. Recency wins when space is
   tight: old resolved matters compress to a clause or vanish (git history of
   `memory/` retains them). Preserve exact identifiers verbatim (fileIds,
   paths, amounts, dates) — never round or paraphrase those.

   When a topic will not fit but is too valuable to drop, **spin it out**
   rather than truncating it: write the detail to `memory/notes/<topic>.md`
   and leave a one-line summary in the digest with a Markdown link to it
   (`memory/notes/<topic>.md`, path from the repo root). Never link it with
   `@` — that imports the file into every session and defeats the point of
   moving it out. Update an existing note in place instead of creating a
   second file on the same topic.

5. **Preserve provenance.** "User decided X" and "suggested X (unconfirmed)"
   remain distinguishable in the digest. Do not promote suggestions or
   hypotheticals to decisions during the rewrite — this is the single most
   common corruption in summarisation.

6. **Truncate the log**: rewrite `memory/log.md` to just its header comment
   plus a single line:
   `- [YYYY-MM-DD] STATE: log compacted into digest (N entries folded)`

7. **Sanity-check the diff** of digest.md before finishing:
   - nothing excluded by user-edits.md survived
   - no secrets or tokens
   - no `@` import lines anywhere in `memory/` (Markdown links only)
   - every note file the digest links to actually exists
   - no instructions-to-the-agent smuggled in as "learnings" (a learning is
     a fact about the world; "always do X" is an instruction and belongs in
     AGENTS.md — surface it to the user instead of storing it)
   - all five headings present
   - word count in range

8. **Commit**: `memory: compact log into digest (N entries)` — or fold into
   the session's work commit if one is imminent. Report a 2–3 line summary of
   what changed in the digest; don't reproduce the whole file in chat.

## Style of the output digest

Prose and terse bullets, no narration ("in a previous session we…" — no; just
state the fact). Write for a reader with zero context beyond the repo itself.
Every "On the horizon" item must be actionable without re-reading transcripts:
include enough context that a fresh session can pick it up cold.

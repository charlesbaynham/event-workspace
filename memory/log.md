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
- [2026-09-20] STATE: memory/whatsapp/README.md renamed to AGENTS.md with a CLAUDE.md @import beside it — subdirectory read-mes follow the root pattern so they load in context when a session works there (Charles's ask; landed on main directly, before the rule below was clarified).
- [2026-09-20] DECISION: the contract is split from the template's own guide — Charles's call: one AGENTS.md doing both jobs was "a liable mess". Shipped contract now lives at agent-tools/AGENTS.md (travels with the engine; update.sh and ONBOARDING install it as a workspace's root AGENTS.md); the template's root AGENTS.md is the maintainer guide and is never shipped.
- [2026-09-20] CORRECTION: "commit straight to the default branch, no branches, no PRs" was only ever meant for workspaces born from the template, not for the template itself — a session here pushed to main under the old reading. The template is a normal codebase: branch + PR, harness branch instructions followed.
- [2026-09-20] STATE: lib.sh gained in_template (no event.yaml); git-sync.sh no longer switches off claude/* branches in the template; sync-push.sh and update.sh refuse to run there. update.sh now installs agent-tools/AGENTS.md → root AGENTS.md.
- [2026-09-20] LEARNED: a consumer on update.sh ≤0.3.x copies upstream's ROOT AGENTS.md over its own — from 0.4.0 that is the maintainer guide, so such consumers must copy the new update.sh first (README says so). Reason VERSION went 0.3.0 → 0.4.0, not a patch.
- [2026-09-20] STATE: ONBOARDING now resets memory/ (log, digest, user-edits) to the empty seed at birth — until now a child inherited the template's own log entries.
- [2026-09-20] STATE: CLAUDE.md is a pure three-import adapter again; the "Maintaining the engine" section moved into the template's AGENTS.md.
- [2026-09-20] STATE: ONBOARDING.md rewritten for the 0.4.0 split — new "what you are converting" preamble (event.yaml is the birth moment; in_template gates update.sh/sync-push.sh/git-sync.sh), contract install, CLAUDE.md trim, child README rewrite (step 6), a verified check step (7), spin-out-plan dropped from the child.
- [2026-09-20] LEARNED: a child's inherited README and CLAUDE.md preamble both describe the *template* — onboarding must rewrite them, or every workspace ships docs telling its owner to clone the template.
- [2026-09-20] LEARNED: memory/whatsapp/CLAUDE.md carries an intentional `@AGENTS.md` (nested adapter), so a blanket `grep -rn '^@' memory/` false-alarms — the workspace check greps memory/*.md and memory/notes/ only.
- [2026-09-20] LEARNED: verified in a scratch clone: update.sh --check works the moment event.yaml exists; git-sync.sh says "could not fetch origin/main" and exits 0 before origin is added; automode-check.sh reports drift in a container holding another workspace's rules.
- [2026-09-20] DECISION: no VERSION bump — ONBOARDING.md, README.md and the maintainer guide are outside agent-tools/, so nothing propagates to consumers.
- [2026-09-20] DECISION: `agent_tools_track: tags` is now a PIN, not a stream — Charles's call: choosing tags means "I want this release and no surprise updates". A bare update.sh on that track resolves to v$(cat agent-tools/VERSION) and reinstalls it; moving is always `update.sh vX.Y.Z`.
- [2026-09-20] DECISION: the pin is the installed VERSION, not a new event.yaml key — update.sh already rewrites VERSION on install, so the pin maintains itself and existing workspaces need no migration.
- [2026-09-20] STATE: agent-tools/hooks/tag-check.sh added — on the tags track it ls-remotes upstream at SessionStart and offers the newest non-declined tag. Four answers (update / not now / not this release / never), recorded as top-level event.yaml keys agent_tools_tag_skip and agent_tools_tag_check: off; the shipped contract's new "Updating the engine" section is what tells a session to honour them.
- [2026-09-20] LEARNED: a new hook cannot reach existing workspaces on its own — .claude/settings.json and .codex/hooks.json are written once at birth and update.sh never touches them. update.sh now prints a one-off "register tag-check.sh" nudge when the track is tags and neither file mentions it; README carries the same under Updating.
- [2026-09-20] LEARNED: skips are matched exactly and only against tags newer than the installed one, so a declined release never silences the next one and stale entries go inert after an update — nothing has to prune the list.
- [2026-09-20] LEARNED: `git tag` fails with "no tag message?" in this environment (annotated by default), so scratch-repo tests need `git tag -a -m`.
- [2026-09-20] STATE: VERSION 0.4.0 → 0.5.0 (behaviour change for tags consumers). Charles: consider tagging v0.5.0 — consumers on the tags track see nothing until a tag exists, and after this change they need one to pin to at all.
- [2026-09-20] DECISION: ONBOARDING.md now tells the setup agent to run the interview through the harness's structured question tool (AskUserQuestion) rather than treating it as an optional nicety — defaults first and marked (Recommended), multiSelect where several answers can be true, free text always open via "Other", batched by round inside the four-questions-per-call limit, and the recap confirmed as a click. Round 2's six real choices split into two calls; the recap gets its own. ONBOARDING.md is outside agent-tools/, so this reaches workspaces only at birth and needs no VERSION bump.
- [2026-09-20] DECISION: the update tracks are now `pinned` and `latest` (were `tags` and `main`) — Charles's call. A pin is the TEXT of agent-tools/VERSION compared against upstream's copy of the same file; nothing reads git tags any more, so a release is whatever lands on upstream's default branch. Both old names are still accepted by update_track(), so no consumer has to edit event.yaml.
- [2026-09-20] STATE: lib.sh gained upstream_url/update_track/track_ref/version_gt/changelog_since; tag-check.sh renamed version-check.sh; a pinned workspace moves with `update.sh --accept` (a bare run refuses and prints what it is declining); event.yaml keys renamed agent_tools_version_skip / agent_tools_update_check with the 0.5.0 spellings still honoured.
- [2026-09-20] DECISION: agent-tools/CHANGELOG.md added (Charles's ask) — one `## X.Y.Z — date` section per version, and every offer (session-start hook, --check, and the install itself) quotes the entries the consumer does not yet have. The hook caps its quote at 80 lines so a long gap cannot flood session context.
- [2026-09-20] STATE: new bump-version skill — TEMPLATE ONLY, so it is a real directory at .claude/skills/bump-version (not a symlink into agent-tools/) with a .agents/ stub, and ONBOARDING.md step 6 deletes both at birth. Semver decided from what changed under agent-tools/ since the last VERSION commit; VERSION and CHANGELOG move together.
- [2026-09-20] LEARNED: renaming a hook file breaks consumers silently (.claude/settings.json and .codex/hooks.json are written once at birth), so update.sh now rewrites tag-check.sh → version-check.sh in both files as it installs — that is what keeps this a minor rather than a major.
- [2026-09-20] STATE: VERSION 0.5.0 → 0.6.0. Tagging is now optional: pinned consumers see the bump on main. Verified end to end in a scratch clone — legacy `tags`/`main` values, skip and off keys in both spellings, --check / bare / --accept, hook repointing, template refusal.

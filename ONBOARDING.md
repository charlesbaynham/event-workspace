# ONBOARDING — read this as your prompt, not as documentation

You are an agent turning a fresh clone of the
[`event-workspace`](https://github.com/charlesbaynham/event-workspace) template
into one person's own event workspace. This file is the whole procedure. Follow
it top to bottom; it ends with a repository pushed to GitHub and a short list
of things only the human can do.

It is a **one-shot** document. You delete it in step 8, so the new repository
never carries it. If it is ever needed again, it is in upstream.

## What you are converting, and into what

The clone you are standing in is the **template**: the engine, the example
configuration, and this procedure. A **workspace** is what it becomes — one
event's memory store, with real configuration and no template scaffolding. The
two are told apart by one file: **a workspace has `event.yaml`; the template has
only `event.yaml.example`.** `agent-tools/lib.sh` makes exactly that test as
`in_template`, and three things key off it:

- `agent-tools/update.sh` and `agent-tools/sync-push.sh` **refuse to run** until
  `event.yaml` exists. That is correct, not a fault — do not work around it, and
  do not reach for `sync-push.sh` for the birth commit in step 8.
- `agent-tools/hooks/git-sync.sh` leaves the current branch alone while there is
  no `event.yaml`, and starts moving sessions onto the default branch once there
  is one.

So `event.yaml` is the moment of birth. Everything before step 4 is a template
checkout; everything after it is a workspace.

**Two `AGENTS.md` files, and you install the right one.** The root `AGENTS.md`
you can see now is the *template's maintainer guide* — how to develop the
engine. The contract a workspace session runs under is `agent-tools/AGENTS.md`,
shipped inside the engine. Step 4 copies it over the root file, and
`update.sh` reinstalls it on every update. The maintainer guide must not
survive into the new repository.

**Before anything else, check you are in the right place.** If `git remote -v`
still points at `charlesbaynham/event-workspace` and nobody asked you to set up
a new workspace, you are standing in the template's own repository rather than a
clone of it — say so and stop, changing nothing. Ask if you cannot tell: a
fresh clone and the template itself look identical on disk.

## How to run the interview

The point of this document is that nobody hand-edits a prompt. **You ask, they
answer however they like.**

- Ask in the three rounds below, one message per round — not one question at a
  time, and not all fifteen at once.
- Prose answers, partial answers, "you decide", and answers to questions you
  did not ask are all valid. Take what they give you and carry on.
- Every question has a default. Offer it. If they skip a question, use the
  default and tell them so in the recap.
- If your harness has a structured question tool, use it for the
  multiple-choice rounds — but always accept free text as well.
- The person running setup is an **owner** in this workspace's terms:
  technical, terse, no emoji. Say the number, name the file.
- Do not touch the network or write a single file until they have confirmed the
  recap at the end of step 2. Reading the repository is fine and expected.

## 1. Orient yourself

Read, in this order: `agent-tools/AGENTS.md`, `event.yaml.example`,
`EVENT.md.example`, `README.md`, `docs/agent-ops-notes.md`. The contract comes
first because it is what every later session in the new repository is bound by —
you cannot configure a workspace sensibly without it. The README describes the
template to a newcomer; step 6 replaces it with one about the event.

The shape to keep in mind: `agent-tools/` is the **engine** — vendored,
overwritten wholesale by `update.sh`, contract included. Everything about *this
event* lives in `event.yaml` (facts the tooling reads), `EVENT.md` (standing
rules, who is who, stock answers) and `memory/`. You fill in the second set and
leave the first alone.

## 2. The interview

### Round 1 — the event and the people

1. **What is the event?** One line, the way they would say it: *"Ada & Ben's
   wedding, 12 June 2027"*, *"PyCon UK 2027"*. Goes in `event.yaml: name` and
   the digest.
2. **Owners** — whose word is authoritative. Technical register. Default: the
   person you are talking to, alone.
3. **Co-users** — anyone else who will use the workspace but is not technical.
   They get the warm register (plain language, no paths or git talk, emoji
   welcome). Default: none.
4. **Anyone else worth knowing about now?** A planner, a venue contact, a
   family member who always asks the same question. Optional; it seeds
   `EVENT.md`.
5. **Where do the facts live — the source of truth?** A Google Sheet is the
   common answer; "this repository" and "a Notion database" are both fine.
   A workspace *indexes* the source of truth and never replaces it, so if they
   say "here", say plainly that there will be no live data to read and that
   memory becomes the only record.

### Round 2 — features

Present this as a menu with the defaults marked, and say that "all the
defaults" is a complete answer.

| Feature | Question | Default |
|---|---|---|
| **Memory** | — not optional; it is the reason the repository exists | on |
| **Google Sheets** | Is the source of truth a Sheet you want the agent to read and write in place? Needs a one-off Google Cloud step from you. | on if they named a Sheet in round 1 |
| **WhatsApp guest bot** | A dedicated number guests text, answered by the workspace, with an isolated send-gate on every reply. Needs a spare phone number and a bridge you host. | later |
| **Auto-mode rules** | Classifier rules kept in the repo and installed into a cloud environment, so routine work runs unattended. Only meaningful for Claude Code on the web. | on if they use Claude Code on the web |
| **Agents** | Which coding agents will open this repository? Claude Code, Codex, both, something else that reads `AGENTS.md`. | both wired; costs nothing |
| **Upstream track** | How `update.sh` follows upstream: `main` = the author's current tip, work in progress included; `tags` = semver releases only. | `tags`; recommend it |
| **Default branch** | `main` unless they have a reason. | `main` |

Three things to be straight about when they ask:

- **WhatsApp is the one feature with real prerequisites**: a second phone
  number and handset, a bridge with an MCP surface and outbound webhooks
  (`agent-tools/skills/whatsapp/setup.md` names the one this was built
  against), and that bridge reachable from claude.ai as a connector. "Later"
  is the right answer for most people on day one, and nothing else depends on
  it.
- **Turning a feature "off" means leaving it unconfigured, not deleting it.**
  Everything under `agent-tools/` comes back on the next `update.sh`. An
  unconfigured skill is inert, which is the supported off switch. If they want
  a skill gone from their sessions anyway, say that it will return on update
  and let them decide.
- **The engine is not theirs to edit.** `agent-tools/` and the root `AGENTS.md`
  are overwritten on every update; per-event behaviour goes in `event.yaml`,
  `EVENT.md` and `memory/`. Say this once now — it is the mistake that costs a
  consumer real work later.

### Round 3 — where it lives

1. **GitHub repository** — owner/name. Default: private. The memory is
   deliberately readable by every session; it is not written to be public.
2. **How will you open it?** Claude Code on the web (a cloud environment, so
   the auto-mode installer needs to go in the environment's setup script),
   locally, or both.

### Recap, then stop

Write back everything you have as a filled-in summary — the event line, owners
and co-users, source of truth, each feature on/later/off, repository name and
visibility, track, default branch, and any defaults you applied because they
skipped a question. Ask one question: **is this right?**

Wait for the answer. Change what they correct. Only then write files.

## 3. Make it their repository, not a fork

```bash
rm -rf .git && git init -b main        # or their chosen default branch
```

This is the first thing you write. It stops a later `git push` going somewhere
surprising, and it is the honest signal that upstream is a template rather than
a parent — nothing is merged from it again; `update.sh` vendors the engine
instead. The clone directory should be named for the event; rename it if they
asked for a name and it does not match.

## 4. Write the configuration

```bash
cp event.yaml.example event.yaml
cp EVENT.md.example EVENT.md
cp automode.json.example automode.json     # only if auto-mode rules are on
cp agent-tools/AGENTS.md AGENTS.md         # the contract, over the template's maintainer guide
```

Keep the `.example` files. They are the reference for which keys `lib.sh` and
the skills actually read, and `update.sh` never touches them.

**`event.yaml`** — `name`, `default_branch` (match what you passed to
`git init`), `agent_tools_track`, `owners`, `co_users`, `source_of_truth`,
`sheets` (ids, not URLs). The `whatsapp` block: fill it in if the bot is on; if
it is "later", leave the example values and add a comment on the block saying it
is unused until the bot is set up, so no session mistakes an example prefix for
a real connector.

**`AGENTS.md`** — the copy above, unedited. It is the workspace's contract and
`update.sh` replaces it wholesale; an edit here is silently lost on the next
update. If something in it is wrong for this event, that belongs in `EVENT.md`.

**`EVENT.md`** — rewrite it for this event rather than editing the example's
names in place. Who is who, with each person's register. The source of truth and
its tabs. Anything from round 1 question 4. Drop the sections that do not apply
(there is no bot register if there is no bot) and keep the headings that are
empty but will fill up — stock answers, things that always go to the owner. Do
not invent facts: an empty section with a heading beats a plausible guess.

**`CLAUDE.md`** — it ships with a parenthetical about the template's maintainer
guide, which is now irrelevant here. Trim it to a line or two saying the
contract, the event's rules and the digest are imported so they are present from
the first turn. Leave the three `@` imports exactly as they are, and note what
they oblige: `AGENTS.md`, `EVENT.md` and `memory/digest.md` must all exist
before the first session, or the import fails.

**`.claude/settings.json`** — the `permissions.allow` list ships with the
example's WhatsApp prefix. If the bot is on, replace it with the real connector
name **in both spellings** (`mcp__<Name>__*` and `mcp__claude_ai_<Name>__*`):
cloud and local sessions see different prefixes, and granting only one is why
sends get denied. If the bot is not on, remove both entries — a stale allow rule
for a connector that does not exist is noise in every session. Leave the
`SessionStart` hooks alone.

**Agent wiring** — `.claude/` (settings, the skill symlinks, the send-gate
agent) serves Claude Code; `.codex/hooks.json` and `.agents/skills/` serve
Codex. Leave both unless they asked for one gone. If they named a third agent,
tell them what it must read at session start (`AGENTS.md`, `EVENT.md`,
`memory/digest.md`) rather than guessing at its hook format.

**Nothing secret goes in the repository.** Not now, not later. `sa.json` is
already gitignored; keys live in the agent environment.

## 5. Reset and seed the memory

`memory/` currently holds the **template's** own working memory. None of it is
about this event, and it must not be inherited.

- **Reset the three files to their empty forms**, keeping every heading and
  header comment exactly as shipped — a later compaction relies on them:
  `memory/log.md` down to its header comment plus the
  `<!-- compaction-baseline: fresh workspace -->` line; `memory/digest.md` to
  its five headings with `*(empty)*` under each; `memory/user-edits.md` to its
  header plus `1. *(none yet)*`. Leave `memory/notes/.gitkeep` and
  `memory/whatsapp/AGENTS.md` and `CLAUDE.md` in place; delete any note or
  thread file that is not one of those.
- **Then log this session**, one line each,
  `- [YYYY-MM-DD] TYPE: observation`: the feature choices as `DECISION` lines
  with their reasons, the repository URL and any spreadsheet ids as `RESOURCE`
  lines, every prerequisite still outstanding as an `OPEN` line. Provenance
  matters: their choice is a decision, your recommendation is a suggestion
  until they took it.
- **Fill in the digest's Purpose & context and Tools & resources** from the
  interview — a few lines each, no more. Leave the other three sections for the
  first real compaction.
- Never use `@` inside `memory/`. Imports recurse, and one `@` line would load
  the whole tree into every session — Markdown links from the repo root
  instead.

## 6. Rewrite the README for the event

The README you inherited sells the template to a newcomer and tells them to
clone it. Replace it with a short one for this repository: what this workspace
is and which event it serves, where the source of truth lives, which features
are on, how a session starts (the hooks, the imports), and how to update the
engine (`agent-tools/update.sh --check`, then `update.sh`, then commit the
diff). Link `docs/agent-ops-notes.md`, which the contract also cites.

`docs/spin-out-plan.md` is the template's own design history and nothing in a
workspace refers to it — delete it unless they want to keep it.

## 7. Check it actually looks like a workspace

Before the first commit, prove the conversion took. Every one of these has been
run through a real conversion, so the expected output is known:

```bash
test -f event.yaml && head -1 AGENTS.md      # "…a memory store and agent workspace for running
                                             #  an event" — the contract. If it says "the template,
                                             #  and how to maintain it", step 4's copy did not happen.
agent-tools/update.sh --check                # prints installed/upstream VERSION and the track;
                                             #  it refused before event.yaml existed
agent-tools/hooks/git-sync.sh                # "could not fetch origin/main" until step 8 adds
                                             #  origin — expected, and it exits 0
agent-tools/hooks/memory-check.sh            # a nearly empty log, digest empty: the fresh seed
agent-tools/hooks/automode-check.sh          # silent if auto-mode is off; a drift report is
                                             #  expected until install.sh runs from this repo
grep -rn '^@' memory/*.md memory/notes/      # nothing. (memory/whatsapp/CLAUDE.md is the one
                                             #  deliberate import and is not in that set)
ls -l .claude/skills .claude/agents          # symlinks, relative, resolving into agent-tools/
```

Fix anything that complains beyond those expected messages. A hook that fails
here fails in every session.

## 8. Delete this file, commit, push

Create the GitHub repository from their round 3 answer with whatever you have —
the `gh` CLI, a GitHub MCP tool, or asking them to create it in the browser and
paste the URL. Add it as `origin`. Then:

```bash
rm ONBOARDING.md
git add -A
git commit -m "New event workspace from event-workspace <contents of agent-tools/VERSION>"
git push -u origin main
```

One commit is right: this is the repository's birth, not a change to it. Plain
`git push` is right too — `sync-push.sh` is for later sessions, once there is an
upstream branch to rebase onto.

## 9. Hand over

Tell them what is left, listing only what their answers actually require:

- **Google Sheets**: run `agent-tools/skills/gsheets/scripts/bootstrap_gcp.sh`
  once in Google Cloud Shell, put the key it prints into the agent environment
  as `GOOGLE_SERVICE_ACCOUNT_KEY` (not into the repository), and share the Sheet
  with the service-account address it prints.
- **Claude Code on the web**: add `agent-tools/automode/install.sh` to the cloud
  environment's setup script. It has to run before the session starts —
  `docs/agent-ops-notes.md` explains why a repository cannot ship classifier
  rules itself. `install.sh --inline` prints a pasteable block if the setup
  script runs before the clone.
- **WhatsApp, now or later**: the prerequisites are in
  `agent-tools/skills/whatsapp/setup.md`. When they have them, open a session in
  the new repository and say "set up the WhatsApp routine"; the skill walks both
  parties through it.
- **Nothing, if none of the above** — say that too, and say what the first
  useful session looks like instead: open the repository and start telling it
  about the event.

Say in one line where the work went (the repository URL and the commit) and that
from here on sessions commit straight to the default branch, as the contract
requires. Then stop. Offer to carry on with actual event work, but do not start
it unasked.

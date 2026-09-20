# ONBOARDING — read this as your prompt, not as documentation

You are an agent turning a fresh clone of
[`event-workspace`](https://github.com/charlesbaynham/event-workspace) into
one person's working event workspace. This file is the whole procedure. Follow
it top to bottom; it ends with a repository pushed to GitHub and a short list
of things only the human can do.

It is a **one-shot** document. You delete it in step 7, so the new repository
never carries it. If you need it again, it is in upstream.

**Before anything else, check you are in the right place.** If `git remote -v`
still points at `charlesbaynham/event-workspace` *and* the person did not ask
you to set up a new workspace, you are standing in the template's own
repository — say so and stop, changing nothing. A fresh clone that is meant to
become someone's workspace is fine; step 3 detaches it.

## How to run the interview

The point of this document is that nobody hand-edits a prompt. **You ask, they
answer however they like.**

- Ask in the three rounds below, one message per round — not one question at a
  time, and not all fifteen at once.
- Prose answers, partial answers, "you decide", and answers to questions you
  did not ask are all valid. Take what they give you and carry on.
- Every question has a default. Offer it. If they skip a question, use the
  default and tell them you did, in the recap.
- If your harness has a structured question tool, use it for the
  multiple-choice rounds — but always accept free text as well.
- The person running setup is an **owner** in this workspace's terms:
  technical, terse, no emoji. Say the number, name the file.
- Do not touch the network or write a single file until they have confirmed the
  recap in step 2. Reading the repository is fine and expected.

## 1. Orient yourself

Read, in this order: `README.md`, `agent-tools/AGENTS.md`, `event.yaml.example`,
`EVENT.md.example`, `docs/agent-ops-notes.md`. `agent-tools/AGENTS.md` is the
contract every later session in the new repository is bound by — you cannot
configure the workspace sensibly without it. The root `AGENTS.md` you can see
now is the template's own maintainer guide; step 4 replaces it.

The shape to keep in mind: `agent-tools/` is the **engine**, vendored from
upstream and overwritten wholesale by `agent-tools/update.sh`, and the contract
ships inside it. Everything about *this* event lives in `event.yaml` (facts the
tooling reads), `EVENT.md` (standing rules, who is who, stock answers) and
`memory/`. You are filling in the second set and leaving the first alone.

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
   This repository *indexes* the source of truth and never replaces it, so if
   they say "here", say plainly that they will have no live data to read and
   that memory becomes the only record.

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
| **Upstream track** | How `agent-tools/update.sh` follows upstream: `main` = the author's current tip, work in progress included; `tags` = semver releases only. | `tags`; recommend it |
| **Default branch** | `main` unless they have a reason. | `main` |

Two things to be straight about when they ask:

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

### Round 3 — where it lives

1. **GitHub repository** — owner/name. Default: private. The memory is
   deliberately readable by every session; it is not written to be public.
2. **How will you open it?** Claude Code on the web (a cloud environment, so
   the auto-mode installer needs to go in the environment's setup script),
   locally, or both.

### Recap, then stop

Write back everything you have as a filled-in summary — the event line, owners
and co-users, source of truth, each feature on/later/off, repository name and
visibility, track, and any defaults you applied because they skipped a
question. Ask one question: **is this right?**

Wait for the answer. Change what they correct. Only then write files.

## 3. Make it their repository, not a fork

```bash
rm -rf .git && git init -b main        # or their chosen default branch
```

This is the first thing you write. It is what stops a later `git push` going
somewhere surprising, and it is the honest signal that upstream is a template
rather than a parent. The clone directory should be named for the event; rename
it if they asked for a name and it does not match.

## 4. Write the configuration

Copy the examples and fill them in. Leave the `.example` files in place — they
are the reference for the next person, and `update.sh` does not touch them.

```bash
cp event.yaml.example event.yaml
cp EVENT.md.example EVENT.md
cp automode.json.example automode.json     # only if auto-mode rules are on
cp agent-tools/AGENTS.md AGENTS.md         # the contract replaces the template's maintainer guide
```

**`event.yaml`** — `name`, `default_branch`, `agent_tools_track`, `owners`,
`co_users`, `source_of_truth`, `sheets` (ids, not URLs). The `whatsapp` block:
fill it in if the bot is on; if it is "later", leave the example values and add
a comment on the block saying it is unused until the bot is set up, so no
session mistakes an example prefix for a real connector.

**`EVENT.md`** — rewrite it for this event rather than editing the example's
names in place. Who is who, with each person's register. The source of truth
and its tabs. Anything they told you in round 1 question 4. Drop the sections
that do not apply (there is no bot register if there is no bot) and keep the
headings that are empty but will fill up — stock answers, things that always go
to the owner. Do not invent facts: an empty section with a heading is better
than a plausible guess.

**`.claude/settings.json`** — the `permissions.allow` list ships with the
example's WhatsApp prefix. If the bot is on, replace it with the real connector
name **in both spellings** (`mcp__<Name>__*` and `mcp__claude_ai_<Name>__*`);
cloud and local sessions see different prefixes and granting one is why sends
get denied. If the bot is not on, remove both entries — a stale allow rule for a
connector that does not exist is noise in every session.

**Agent wiring** — `.claude/` (settings, symlinked skills, the send-gate agent)
serves Claude Code; `.codex/hooks.json` and `.agents/skills/` serve Codex. Leave
both unless they asked for one gone. If they named a third agent, tell them what
it needs to read (`AGENTS.md`, `EVENT.md`, `memory/digest.md` at session start)
rather than guessing at its hook format.

**Nothing secret goes in the repository.** Not now, not later. `sa.json` is
already gitignored; keys live in the agent environment.

## 5. Seed the memory

The workspace's whole premise is that what a session learns gets written down.
This session learned the event exists.

- **First, reset `memory/` to a fresh seed.** What is there is the template's
  own working memory, not this event's. `memory/log.md` keeps only its header
  comment and the `<!-- compaction-baseline: fresh workspace -->` line;
  `memory/digest.md` keeps its five headings with `*(empty …)*` under each;
  `memory/user-edits.md` keeps its header and `1. *(none yet)*`.
- Append to `memory/log.md`, one line each, `- [YYYY-MM-DD] TYPE: observation`:
  the feature choices as `DECISION` lines with the reason, the repository URL
  and any spreadsheet ids as `RESOURCE` lines, and every prerequisite still
  outstanding as an `OPEN` line. Provenance matters: their choice is a
  decision, your recommendation is a suggestion until they took it.
- Fill in `memory/digest.md`'s **Purpose & context** and **Tools & resources**
  from the interview — a few lines each, no more. Leave the rest for the first
  real compaction. Never use `@` inside `memory/`; imports recurse and would
  load the whole tree into every session.
- Leave `memory/user-edits.md` alone unless they gave you a standing
  correction.

## 6. Create the GitHub repository

Create the private GitHub repository from their answer with whatever you have —
the `gh` CLI, a GitHub MCP tool, or asking them to create it in the browser and
paste the URL. Add it as `origin`.

## 7. Delete this file, commit, push

```bash
rm ONBOARDING.md
git add -A
git commit -m "New event workspace from event-workspace <contents of agent-tools/VERSION>"
git push -u origin main
```

One commit is right: this is the repository's birth, not a change to it.

## 8. Hand over

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

Then stop. Offer to keep going on actual event work if they want, but do not
start it unasked.

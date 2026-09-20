# event-workspace

A template for running an event — a wedding, a conference, a festival — with AI
agents that **remember across sessions** and **answer guests on WhatsApp**
without leaking anyone's private details. Extracted from a workspace that ran a
real wedding with ~90 guests, then scrubbed of everything about them.

It is not an app. It is a git repository shaped so that an ephemeral agent
session (Claude Code on the web, Codex, or anything that reads `AGENTS.md`)
starts with the right context, writes down what it learns, and leaves the next
session no worse off than itself.

## Set it up with your coding agent

Paste this into Claude Code, Codex or any coding agent, from your home directory
with nothing cloned. There is nothing to fill in — it asks you.

```text
Set up a new event workspace for me from the template at
https://github.com/charlesbaynham/event-workspace.

Clone it into a new folder in my home directory, then read ONBOARDING.md in
that folder and follow it as your prompt. It will interview me about the event
and configure the workspace from my answers — ask me its questions rather than
guessing.
```

[`ONBOARDING.md`](ONBOARDING.md) is the whole setup procedure, written to be
executed by an agent rather than read by you: three rounds of questions (the
event and the people, which features you want, where the repository lives) and a
recap you confirm, then it writes `event.yaml` and `EVENT.md`, installs the
shipped contract as your root `AGENTS.md`, reseeds `memory/` for your event,
replaces this README with one about the event, checks the hooks all run, creates
the private repo, pushes, and tells you the one or two things only you can do.
Answer in prose, skip what you do not care about, say "all the defaults" — it
takes what you give it. The document deletes itself in the first commit, so your
repository never carries it.

## What is in it

| Piece | What it does |
|---|---|
| **Memory** (`memory/`, `memory-compact` skill, hooks) | A digest injected into every session, an append-only log written during work, user corrections, and a compaction procedure that keeps the digest small. |
| **Session hygiene** (`agent-tools/hooks/git-sync.sh`, `agent-tools/sync-push.sh`) | Repairs the shallow-snapshot divergence cloud containers show, keeps sessions on the default branch, and pushes with rebase-and-retry so two concurrent sessions don't lose each other's work. |
| **WhatsApp** (`whatsapp` skill, `whatsapp-send-gate` agent) | A dedicated bot number answers guests. Every reply is drafted, recorded, then judged by an isolated subagent that sees only the transcript, the draft, and an identity check. Anything about another guest, anyone's money, or anything embarrassing waits for the owner. One thread file per guest is the durable record. Webhook-driven: each message wakes a fresh session. |
| **gsheets** skill | Read and write the event's Google Sheet in place via a service account. Ships no key. |
| **Two registers** | A technical owner and non-technical co-users get different voices, the same facts. |
| **Classifier rules** (`automode.json`, `agent-tools/automode/`) | Auto-mode rules kept in the repo, installed into the environment by a script the setup script calls, with a session-start drift check. A repo cannot ship these directly; see the ops notes. |
| **The contract** (`agent-tools/AGENTS.md`, installed as your root `AGENTS.md`) | The rules above, written for an agent to follow. Generic; updated from upstream. This repository's own root `AGENTS.md` is the maintainer guide for the template, not the contract. |

## Getting started by hand

`ONBOARDING.md` walks an agent through all of this. If you would rather do it
yourself:

1. **Use this template** (GitHub → *Use this template*) into a private repo.
2. Copy `event.yaml.example` → `event.yaml` and `EVENT.md.example` → `EVENT.md`;
   fill them in. Everything about *your* event goes in those two files and in
   `memory/`; never in `agent-tools/`. Then `cp agent-tools/AGENTS.md AGENTS.md`
   — the contract replaces the template's maintainer guide — and empty
   `memory/log.md` back to its header: what is there is the template's own
   history.
3. If the source of truth is a Google Sheet: run
   `agent-tools/skills/gsheets/scripts/bootstrap_gcp.sh` once in Cloud Shell,
   put the key it prints in the agent environment as
   `GOOGLE_SERVICE_ACCOUNT_KEY`, and share the Sheet with the service account.
4. For WhatsApp: stand up a bridge (see `agent-tools/skills/whatsapp/setup.md`
   for the prerequisites — a second phone number, the bridge, a connector), then
   open a session and say "set up the WhatsApp routine". The skill walks both of
   you through it.
5. Optional: copy `automode.json.example` → `automode.json` and call
   `agent-tools/automode/install.sh` from the cloud environment's setup script
   (see `docs/agent-ops-notes.md` for why it has to be there).
6. Open a session. The hooks put it on the default branch and tell it whether
   memory needs compacting; `CLAUDE.md` imports the contract, `EVENT.md` and the
   digest.

Codex users: `.codex/hooks.json` and `.agents/skills/` wire the same engine.

## Updating

The engine lives in `agent-tools/`, versioned by `agent-tools/VERSION`. It
includes the contract, `agent-tools/AGENTS.md`, which `update.sh` reinstalls
as your root `AGENTS.md`.

```bash
agent-tools/update.sh --check    # installed vs upstream, changes nothing
agent-tools/update.sh            # pull upstream over agent-tools/, reinstall AGENTS.md
git diff && git commit -am "agent-tools: 0.4.0"
```

What "upstream" means is your choice, recorded as `agent_tools_track` in
`event.yaml`:

- **`main`** (the default) — the tip of this repo's default branch: what the
  author runs day to day, including work in progress.
- **`tags`** — **a pin.** Your workspace stays on the release recorded in
  `agent-tools/VERSION`; a bare `update.sh` reinstalls that same release, and
  nothing arrives unasked. Instead, `agent-tools/hooks/tag-check.sh` checks
  upstream at session start, and when a newer release exists the agent offers
  it: update now, not now, not this release, or stop offering. The last two
  are remembered in `event.yaml` (`agent_tools_tag_skip`,
  `agent_tools_tag_check: off`) so you are asked once. Moving is always
  `update.sh vX.Y.Z` with the release named.

  Tags follow semantic versioning: a patch is a fix, a minor adds a feature or
  changes behaviour you may want to read about, a major changes something you
  have to act on (`event.yaml` keys, file layout, the skill's section
  numbers). Pick this track if you would rather not be surprised.

`update.sh <tag|branch|full sha>` overrides the track for one run. **Upgrading
to 0.5.0 on the `tags` track:** add `agent-tools/hooks/tag-check.sh` beside the
other `SessionStart` hooks in `.claude/settings.json` (and `.codex/hooks.json`
if you use Codex) — those files are yours and no update writes to them, so
until you do, nothing will tell you a release has landed. `update.sh` says so
when it notices. **Upgrading from 0.3.x or earlier: copy the current `agent-tools/update.sh` from upstream
over yours before running it.** Older versions only knew about tags (0.2.0 and
before) or copied the template's *root* `AGENTS.md` over yours (0.3.x) — and
since 0.4.0 that file is the template's maintainer guide, not the contract.
Local edits to `agent-tools/` and `AGENTS.md` are overwritten on update — that
is the point. Per-event behaviour belongs in `event.yaml`, `EVENT.md` and
`memory/`.

## Design notes

- [docs/spin-out-plan.md](docs/spin-out-plan.md) — what was extracted, from
  where, and why this shape rather than a plugin or a submodule.
- [docs/agent-ops-notes.md](docs/agent-ops-notes.md) — things learned running
  agents in ephemeral cloud containers: monitors, auto-mode, shallow clones.

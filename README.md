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
with nothing cloned. Fill in the bracketed answers first (or leave them and the
agent will ask).

```text
Set up a new event workspace for me from the template at
https://github.com/charlesbaynham/event-workspace. Work from my home directory.

My answers:
- Event name: [e.g. "Ada & Ben's wedding, 12 June 2027"]
- New GitHub repo (owner/name, private): [e.g. ada/wedding-workspace]
- Owners (technical users whose word is authoritative): [names]
- Co-users (non-technical users who get the warm register): [names, or none]
- Source of truth: [a Google Sheet URL/id, "this repo", or other]
- WhatsApp bot: [bot name + the MCP connector prefix, e.g. mcp__Event_Whatsapp__; or "skip for now"]
- Follow upstream updates from: [main | tags]  (main = the author's current
  tip; tags = only semver releases vX.Y.Z, the safer choice)
- Agent tools I use: [Claude Code | Codex | both | other]

Do this, asking me only for answers I left blank:
1. git clone --depth 1 https://github.com/charlesbaynham/event-workspace <name>,
   cd into it, delete its .git, and git init -b main. This is my repo now, not
   a fork.
2. Read README.md, AGENTS.md and docs/agent-ops-notes.md so you know how the
   workspace works before you touch it.
3. Copy event.yaml.example to event.yaml, EVENT.md.example to EVENT.md and
   automode.json.example to automode.json, and fill all three in from my
   answers: name, owners, co_users, source_of_truth and sheets, the whatsapp
   block (or leave it as the example with a note that it is unused),
   agent_tools_track set to my choice. Leave the .example files in place.
   Leave agent-tools/ and AGENTS.md exactly as they are — they are the engine
   and are overwritten by agent-tools/update.sh.
4. If my source of truth is a Google Sheet: tell me to run
   agent-tools/skills/gsheets/scripts/bootstrap_gcp.sh once in Google Cloud
   Shell, put the key it prints in my agent environment as
   GOOGLE_SERVICE_ACCOUNT_KEY, and share the Sheet with the service-account
   address it prints. Do not put the key in the repo.
5. Create the private GitHub repo from my answer with whatever you have
   (the gh CLI, a GitHub MCP tool, or ask me to create it in the browser and
   paste the URL), add it as origin, commit everything with the message
   "New event workspace from event-workspace <version in agent-tools/VERSION>",
   and push main.
6. Tell me what is left for me: sharing the Sheet and setting the key; adding
   agent-tools/automode/install.sh to my cloud environment's setup script if I
   use Claude Code on the web (docs/agent-ops-notes.md explains why it must be
   there); and, if I want the WhatsApp bot, opening a session in the new repo
   and saying "set up the WhatsApp routine" — agent-tools/skills/whatsapp/setup.md
   lists the prerequisites (a second phone number and a bridge).
```

## What is in it

| Piece | What it does |
|---|---|
| **Memory** (`memory/`, `memory-compact` skill, hooks) | A digest injected into every session, an append-only log written during work, user corrections, and a compaction procedure that keeps the digest small. |
| **Session hygiene** (`agent-tools/hooks/git-sync.sh`, `agent-tools/sync-push.sh`) | Repairs the shallow-snapshot divergence cloud containers show, keeps sessions on the default branch, and pushes with rebase-and-retry so two concurrent sessions don't lose each other's work. |
| **WhatsApp** (`whatsapp` skill, `whatsapp-send-gate` agent) | A dedicated bot number answers guests. Every reply is drafted, recorded, then judged by an isolated subagent that sees only the transcript, the draft, and an identity check. Anything about another guest, anyone's money, or anything embarrassing waits for the owner. One thread file per guest is the durable record. Webhook-driven: each message wakes a fresh session. |
| **gsheets** skill | Read and write the event's Google Sheet in place via a service account. Ships no key. |
| **Two registers** | A technical owner and non-technical co-users get different voices, the same facts. |
| **Classifier rules** (`automode.json`, `agent-tools/automode/`) | Auto-mode rules kept in the repo, installed into the environment by a script the setup script calls, with a session-start drift check. A repo cannot ship these directly; see the ops notes. |
| **The contract** (`AGENTS.md`) | The rules above, written for an agent to follow. Generic; updated from upstream. |

## Getting started by hand

The block above does all of this. If you would rather do it yourself:

1. **Use this template** (GitHub → *Use this template*) into a private repo.
2. Copy `event.yaml.example` → `event.yaml` and `EVENT.md.example` → `EVENT.md`;
   fill them in. Everything about *your* event goes in those two files and in
   `memory/`; never in `agent-tools/`.
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

The engine lives in `agent-tools/` plus the generic contract `AGENTS.md`,
versioned by `agent-tools/VERSION`.

```bash
agent-tools/update.sh --check    # installed vs upstream, changes nothing
agent-tools/update.sh            # pull upstream over agent-tools/ and AGENTS.md
git diff && git commit -am "agent-tools: 0.3.0"
```

What "upstream" means is your choice, recorded as `agent_tools_track` in
`event.yaml`:

- **`main`** (the default) — the tip of this repo's default branch: what the
  author runs day to day, including work in progress.
- **`tags`** — the newest semver tag `vX.Y.Z`. Tags here follow semantic
  versioning: a patch is a fix, a minor adds a feature or changes behaviour
  you may want to read about, a major changes something you have to act on
  (`event.yaml` keys, file layout, the skill's section numbers). Pick this if
  you would rather not be surprised.

`update.sh <tag|branch|full sha>` overrides the track for one run. Local edits
to `agent-tools/` and `AGENTS.md` are overwritten on update — that is the
point. Per-event behaviour belongs in `event.yaml`, `EVENT.md` and `memory/`.

## Design notes

- [docs/spin-out-plan.md](docs/spin-out-plan.md) — what was extracted, from
  where, and why this shape rather than a plugin or a submodule.
- [docs/agent-ops-notes.md](docs/agent-ops-notes.md) — things learned running
  agents in ephemeral cloud containers: monitors, auto-mode, shallow clones.

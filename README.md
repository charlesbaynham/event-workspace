# event-workspace

A template for running an event — a wedding, a conference, a festival — with AI
agents that **remember across sessions** and **answer guests on WhatsApp**
without leaking anyone's private details. Extracted from a workspace that ran a
real wedding with ~90 guests, then scrubbed of everything about them.

It is not an app. It is a git repository shaped so that an ephemeral agent
session (Claude Code on the web, Codex, or anything that reads `AGENTS.md`)
starts with the right context, writes down what it learns, and leaves the next
session no worse off than itself.

## What is in it

| Piece | What it does |
|---|---|
| **Memory** (`memory/`, `memory-compact` skill, hooks) | A digest injected into every session, an append-only log written during work, user corrections, and a compaction procedure that keeps the digest small. |
| **Session hygiene** (`agent-tools/hooks/git-sync.sh`, `agent-tools/sync-push.sh`) | Repairs the shallow-snapshot divergence cloud containers show, keeps sessions on the default branch, and pushes with rebase-and-retry so two concurrent sessions don't lose each other's work. |
| **WhatsApp** (`whatsapp` skill, `whatsapp-send-gate` agent) | A dedicated bot number answers guests. Every reply is drafted, recorded, then judged by an isolated subagent that sees only the transcript, the draft, and an identity check. Anything about another guest, anyone's money, or anything embarrassing waits for the owner. One thread file per guest is the durable record. Webhook-driven: each message wakes a fresh session. |
| **gsheets** skill | Read and write the event's Google Sheet in place via a service account. Ships no key. |
| **Two registers** | A technical owner and non-technical co-users get different voices, the same facts. |
| **The contract** (`AGENTS.md`) | The rules above, written for an agent to follow. Generic; updated from upstream. |

## Getting started

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
5. Open a session. The hooks put it on the default branch and tell it whether
   memory needs compacting; `CLAUDE.md` imports the contract, `EVENT.md` and the
   digest.

Codex users: `.codex/hooks.json` and `.agents/skills/` wire the same engine.

## Updating

The engine lives in `agent-tools/` plus the generic contract `AGENTS.md`,
versioned by `agent-tools/VERSION` and released as git tags here.

```bash
agent-tools/update.sh --check    # what's installed, what's latest
agent-tools/update.sh            # pull the latest tag over agent-tools/
git diff && git commit -am "agent-tools: v0.2.0"
```

Local edits to `agent-tools/` and `AGENTS.md` are overwritten on update — that
is the point. Per-event behaviour belongs in `event.yaml`, `EVENT.md` and
`memory/`. `update.sh <sha>` works too, for a commit that has no tag yet.

## Design notes

- [docs/spin-out-plan.md](docs/spin-out-plan.md) — what was extracted, from
  where, and why this shape rather than a plugin or a submodule.
- [docs/agent-ops-notes.md](docs/agent-ops-notes.md) — things learned running
  agents in ephemeral cloud containers: monitors, auto-mode, shallow clones.

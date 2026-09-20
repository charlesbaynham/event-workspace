# event-workspace — spin-out plan

**Status: proposal, 2026-09-20.** Two questions: *what* comes out of the wedding
workspace (and the House Absolute workspace) into a shareable repo, and *how*
it gets to other people — and back into the wedding workspace so we dogfood it.

## 1. What is worth spinning out

The wedding workspace has three layers that are today interleaved:

| Layer | What it is | Shareable? |
|---|---|---|
| **Engine** | Memory system, session hooks, sync-push, the WhatsApp procedure, the send-gate, gsheets tooling | Yes — this is the product |
| **Event contract** | AGENTS.md rules that are about *this* event: who the users are, which chat is read-only, which number is exempt, "spreadsheet is the source of truth", Spanish-call handling | Partly — as a **template** others fill in |
| **Event data** | `memory/`, thread files, FAQs, the Sheets key, every name and number | Never |

Everything in the *engine* row already lives under `agent-tools/` in the wedding
repo, wired into `.claude/` by symlinks and into `.agents/` (Codex) by shim
skills. That directory is 90% of the spin-out; the work is scrubbing it, adding a
config surface where wedding facts are hard-coded, and writing the template.

### 1.1 Features, ranked by value to someone else

1. **The memory system** (`memory/digest.md` + append-only `log.md` +
   `user-edits.md` + `notes/`; `memory-compact` skill; `memory-check.sh` hook;
   `load-memory.sh` for Codex; the `@digest` import in `CLAUDE.md`). Fully
   generic already. The AGENTS.md sections *Memory*, *Reading memory*, *Writing
   memory*, *Detail files*, *Safeguards* are the contract and are event-agnostic
   word for word.
2. **Session hygiene**: `git-sync.sh` (shallow-snapshot repair, fast-forward,
   step off `claude/*` scaffolding) and `sync-push.sh` (commit → rebase → push
   with retry, merging concurrent `log.md` appends). Generic once the branch
   name is a parameter — the HA copy hard-codes `master`, the wedding copy
   `main`. The "commit straight to main, session branch instructions don't
   count" AGENTS.md section goes with them; it is what makes an ephemeral
   container safe to use as a memory store.
3. **The WhatsApp channel**: the thread-file XML schema, the draft → record →
   gate → send/escalate loop, the supersede rule, the wake-as-fresh-session
   procedure (§10), the routine wiring (`setup.md`), the poll rule (§15), and
   the isolated `whatsapp-send-gate` subagent. This is what people are asking
   for. It is also the most wedding-entangled file: §13 (planner chat), §14
   (Gaby), the FAQs, the register ("Beep boop"), and every example are specific.
   The engine/config split for it is in §1.3.
4. **The gsheets skill** (`gs.py` CLI + library, recipes, `bootstrap_gcp.sh`).
   Generic and excellent — *minus its bundled service-account key* (§1.4).
5. **The two-register rule** (Charles vs Gaby): generalises to "the workspace
   has a technical owner and non-technical co-users; detect and match". Worth
   keeping as a template section with placeholders.
6. **Multi-agent support**: the `.claude/` symlink + `.agents/` shim pattern
   and `.codex/hooks.json`, so the same engine serves Claude Code and Codex.

From the HA workspace, three things transfer; the rest is lab-specific:

7. **"Document as you go / the docs are yours — fix errors on sight"**: a
   stronger statement of the memory contract's ownership rule.
8. **The monitor-backstop rule** ("every monitor needs a backstop that fires
   even if the thing never happens") and the cloud-session-monitors finding
   (a bare `run_in_background` loop freezes with the container). Short, generic,
   saves anyone an afternoon.
9. **Auto-mode facts**: `autoMode` in a repo's `.claude/settings.json` is
   *ignored* (only user/managed settings count). ⚠️ The wedding
   `.claude/settings.json` carries an `autoMode` block that therefore does
   nothing; the routine prompt's "note to the auto-classifier" is what actually
   works. The template should ship `permissions.allow` only, and document why.

Not transferring: `jobs/` cards and the job board (the wedding uses the Jobs
tab of the master sheet; a second tracker is the wrong default for an event),
every lab skill (tailscale, proxmox, secrets server, lab-ssh…), the `docs/infra`
corpus.

### 1.2 What "generic" costs: the config surface

Every place the engine names a wedding fact becomes a field in one file,
`event.yaml` at the repo root, read by the skills and hooks:

```yaml
name: "Charles & Gaby's wedding"
owners: [Charles]              # whose word is authoritative in-session
co_users: [Gaby]               # non-technical users; warm register, no mechanics
default_branch: main
source_of_truth: "Wedding Master File (Google Sheet)"   # or "this repo"
sheets:
  master: 1HsHuSfJ46Yo_...
  live_forms: [..]
whatsapp:
  mcp_prefix: mcp__Charlesbot_Whatsapp__     # the bot's server, never the personal one
  personal_prefix: mcp__Whatsapp__           # never used unattended
  bot_name: CharlesBot
  register: "knowingly a bot, short, dry; Spanish in, Spanish out"
  identity_roster: "Guests tab + Guest roster tab of the master file"
  gate_exempt: [447700900123]                # §14-style exemptions, each with provenance
  read_only_chats: ["Gaby and Charles wedding planning"]
  routine_name: "CharlesBot WhatsApp webhook"
```

The skill text then says "the roster named in `event.yaml`" instead of "the
Guests tab", and §13/§14 become generic rules ("chats listed under
`read_only_chats` are read-only; numbers under `gate_exempt` skip the gate")
with the wedding's entries living in the wedding repo's `event.yaml`. Anything
that cannot be expressed as data stays prose in a per-event `EVENT.md` the
template asks the owner to write (the FAQs file is the model: stock answers,
each with source and date).

### 1.3 The WhatsApp piece, honestly

What someone else needs to run it:

- A **WhatsApp bridge** with an MCP surface and outbound webhooks — Charles's
  fork of `whatsapp-mcp` (public), plus a second phone number and a device to
  pair it. The spin-out documents this as a prerequisite with a pointer, it does
  not bundle it.
- An **OAuth gate** if the bridge is published on the internet (mcp-auth is
  Charles's own; others can use any bearer-auth reverse proxy).
- A **Claude Code routine with an API trigger** (claude.ai/code/routines) —
  `setup.md` already describes this as a two-party job and generalises cleanly.

The engine that *is* shareable is the discipline around those: thread files as
the only durable record, the isolated gate with three inputs and fail-closed,
one pending proposal per thread, identity by number against an independently
held roster, the wake procedure. That is the interesting part and it is
platform-agnostic.

### 1.4 Things that must not cross over (scrub list)

- `agent-tools/skills/gsheets/assets/sa.json` — a live Google service-account
  private key, committed. The spin-out ships **no key**; `gs.py` already reads
  `$GOOGLE_SERVICE_ACCOUNT_KEY` / `~/.config/gsheets/sa.json` first, so only the
  bundled fallback goes. (Separately: the key should be rotated, and the wedding
  repo should never be forked or filter-branched into the public one — the key
  is in its history. Fresh history only.)
- Every phone number, name, JID, trigger id, subscription id, Sheet id, and
  every dated incident in `SKILL.md`, `gaby.md`, `FAQs.md`, the send-gate prompt
  ("your brother's group…"), and `.claude/settings.json`. The gate prompt's
  examples get neutral replacements; the "explain a guardrail by what it does,
  never by the episode" rule is itself the reason the incident stories stay
  behind.
- `memory/` wholesale. The template ships an empty `memory/` with the header
  comments and the compaction-baseline marker.

## 2. How to deploy it

Three candidate shapes, then a recommendation.

### A. Template repository (copy once)

`event-workspace` is marked a GitHub *template repository*; a user clicks *Use
this template*, fills in `event.yaml`/`EVENT.md`, shares their Sheet with their
own service account, wires their bridge. Zero moving parts.

- **For:** simplest possible; nothing to break; works for Claude and Codex
  alike; the wedding repo can adopt it by deleting its `agent-tools/` and
  vendoring the new one.
- **Against:** no update path. A fix to the gate prompt reaches nobody who has
  already copied. We would not be dogfooding a *package*, only a snapshot.

### B. Claude Code plugin

`event-workspace` publishes a plugin (skills, agents, hooks) via a marketplace
manifest; a consuming repo lists it in `.claude/settings.json`
(`extraKnownMarketplaces` + `enabledPlugins`). Updates propagate on plugin
update. The always-on memory contract would be delivered by the plugin's
`SessionStart` hook printing it as context, since a plugin cannot inject a
`CLAUDE.md`.

- **For:** the "real package" option; one-line install; versioned; the
  Claude-native channel people will look for.
- **Against:** Claude-only (Codex loses the skills and hooks unless duplicated);
  the memory contract delivered as hook output is weaker than a `CLAUDE.md` line
  people can read and edit; a plugin cannot own files in the consumer's repo
  (`memory/`, `event.yaml`), so a template is still needed for those.
- **Checked against the Claude Code docs (20 Sep 2026):** a plugin's own
  `CLAUDE.md` is explicitly *not* loaded; a `SessionStart` hook returning
  `additionalContext` is the only always-on channel. Plugin hooks do run in
  cloud sessions (user-level `~/.claude/settings.json` hooks do not). A
  marketplace entry can pin a git `ref`/`sha`. Whether an `enabledPlugins`
  entry in a project's settings auto-installs in a fresh ephemeral container is
  **not documented** — it would have to be tested before a webhook-spawned
  session could depend on it. Git submodule initialisation in cloud sessions is
  also undocumented, which rules out the submodule variant of option C.

### C. Vendored directory with a versioned update script

`event-workspace` is a template (A) whose engine lives entirely in
`agent-tools/`, and ships `agent-tools/update.sh` which pulls a tagged release
of that directory from the upstream repo over the vendored copy (`git subtree`
under the hood, or a plain fetch-and-copy; either is one command — not a
submodule, whose initialisation in cloud sessions is undocumented). Consumers
run it when they want updates; `git-sync.sh` can print "engine v0.3, v0.4
available" at session start so the agent offers to run it.

- **For:** works for any agent tool (Claude, Codex, anything that reads
  files); updates are a command, not a copy-paste; the consumer's repo stays a
  plain repo with no submodule or plugin state; the wedding repo dogfoods
  exactly what everyone else gets; a release is a git tag.
- **Against:** updates are pulled, not pushed; local edits to `agent-tools/`
  conflict with updates (the answer: local edits go in `event.yaml`/`EVENT.md`,
  never in `agent-tools/`, same rule as "never edit inside a cattle
  container").

### Recommendation: C now, B as an additional channel later

C is the smallest step from where the wedding repo already is: `agent-tools/`
is already the package directory, the symlinks and shims are already the
"install", and the only new artefacts are `event.yaml`, a version file, an
`update.sh`, and the scrubbed template. It keeps Codex support, which the
wedding repo has and uses. The wedding repo consumes it the same way anyone
would — that is the dogfooding.

B is worth adding once C is stable, because a plugin manifest over the same
`agent-tools/` tree is cheap and it is the channel Claude users will expect. It
does not replace the template: `memory/`, `event.yaml` and the AGENTS.md
contract still have to land in the consumer's repo.

A alone is what we would end up with if we did nothing beyond scrubbing; C is A
plus one script and one tag.

## 3. Proposed layout of event-workspace

```
event-workspace/
├── README.md                # what this is, who it is for, the prerequisites
├── AGENTS.md                # the contract — generic sections + "fill me in" sections
├── CLAUDE.md                # 3-line adapter: @AGENTS.md, @memory/digest.md
├── event.yaml.example       # the config surface (§1.2)
├── EVENT.md.example         # per-event prose: FAQs, register, who's who
├── agent-tools/
│   ├── VERSION
│   ├── update.sh            # pull a tagged release over this directory
│   ├── sync-push.sh
│   ├── hooks/{git-sync,memory-check,load-memory}.sh
│   ├── agents/whatsapp-send-gate.md
│   └── skills/{memory-compact,whatsapp,gsheets}/
├── .claude/{settings.json, skills→, agents→}     # symlinks into agent-tools
├── .agents/skills/                                # Codex shims
├── .codex/hooks.json
├── memory/{digest.md,log.md,user-edits.md,notes/,whatsapp/README.md}   # empty
└── docs/                    # this plan; the monitor-backstop and auto-mode notes
```

## 4. Order of work

1. Scrub and generalise `agent-tools/` into this repo (fresh history), with
   `event.yaml` wiring. Tag `v0.1`.
2. Template `AGENTS.md`/`README.md`; empty `memory/`; mark the repo a template.
3. Wedding repo: replace `agent-tools/` with the vendored `v0.1`, add its
   `event.yaml`/`EVENT.md` carrying everything scrubbed in step 1, confirm the
   webhook session still works end to end (a real CharlesBot text). This is the
   proof the split lost nothing.
4. Rotate the Sheets service-account key; put the new one in the wedding
   routine's environment, not the repo.
5. Later: plugin manifest over `agent-tools/` (B), if wanted.

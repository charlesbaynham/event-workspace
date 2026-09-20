---
name: gsheets
description: Read and write Google Sheets directly via the Sheets API using a service account — edit cells, append rows, pull ranges into pandas, push results back, format, and chart, all without downloading or re-uploading the file. Use this skill whenever the user mentions a Google Sheet or Google Spreadsheet, pastes a docs.google.com/spreadsheets URL, or asks to read, update, log to, analyse, or chart data that lives in a spreadsheet online. Also use it when they want analysis results written back to a sheet, or a sheet created and shared. Prefer this over downloading a sheet and editing it locally, since local edits can't be saved back in place.
---

# Google Sheets, live

Edit Google Sheets in place. No download, no re-upload, no version drift — the user
sees changes appear in the tab they already have open.

`scripts/gs.py` is the whole interface. It works as a CLI for quick things and as an
importable library when you need pandas or a request shape it doesn't wrap.

## Before anything else

Two things have to be true, and when they aren't, every call fails with a 403 that
doesn't explain itself:

1. A service-account key is available (see [Setup](#setup) below).
2. The target spreadsheet is **shared with the service account's email as an Editor**.

So when a user hands over a sheet URL for the first time, check access first rather
than discovering the problem three calls in:

```bash
python scripts/gs.py whoami                 # prints the address to share with
python scripts/gs.py info '<sheet-url>'     # 403 here means it isn't shared yet
```

If `info` fails, give the user the `whoami` address and ask them to add it as an
Editor via the sheet's Share button. That is the single most common failure and it
is a one-click fix, so name it precisely rather than reporting a generic API error.

## Setup

**No key ships with this skill.** A service-account key is a live credential and
never belongs in a repository — supply it through the environment:

- `$GOOGLE_SERVICE_ACCOUNT_KEY` — the JSON key as a string (the right choice for
  a cloud agent environment: set it in the environment's variables), or
- `$GOOGLE_APPLICATION_CREDENTIALS` — a path to the key file, or
- `~/.config/gsheets/sa.json` / `./sa.json` on a persistent machine, or
  `assets/sa.json` next to this skill — gitignored, and left alone by
  `agent-tools/update.sh`, but a committed key is a leak waiting to happen.

`gs.py` tries them in that order; verify with `python scripts/gs.py whoami`.

Starting from nothing? `scripts/bootstrap_gcp.sh` builds the whole thing — open
[Cloud Shell](https://shell.cloud.google.com), paste it, and keep the JSON it
prints somewhere outside the repo. Takes a minute, costs nothing, no billing
account required.

Dependencies, if the environment lacks them:

```bash
pip install google-api-python-client google-auth --break-system-packages -q
```

On some web-agent containers the distro `cryptography` is broken
(`ModuleNotFoundError: _cffi_backend`, surfacing as a pyo3 panic rather than a normal
traceback on the first auth call). Add `cffi cryptography` to that install line to
shadow it.

### Where this can run

The Sheets API must be reachable, which is not a given. Some sandboxed environments
allow package registries but block `*.googleapis.com` at an egress proxy — there,
every call dies with a `ProxyError`/`TransportError` on `oauth2.googleapis.com`
before authentication is even attempted. That is a network policy, not a broken key,
and there is no way around it from inside: run the skill somewhere with normal
outbound access instead. A quick check before committing to a plan:

```bash
curl -s -o /dev/null -w '%{http_code}\n' --max-time 8 https://oauth2.googleapis.com
```

`000` means blocked. Anything else means proceed.

## Reading

```bash
python scripts/gs.py info '<sheet>'                      # tab names, ids, sizes
python scripts/gs.py get '<sheet>' 'Data!A1:F200'        # JSON rows
python scripts/gs.py get '<sheet>' 'Data!A:F' --csv-out  # CSV to stdout
```

Start with `info` on an unfamiliar sheet. Tab names are rarely what you'd guess, and
a wrong name produces a confusing "Unable to parse range" rather than an empty result.

For anything analytical, use the library — piping CSV through the shell loses types:

```python
import sys; sys.path.insert(0, "scripts")
from gs import Sheets

gs = Sheets()
df = gs.read_df("<sheet>", "Data!A1:F200")
```

`read_df` pads short rows, because the API truncates trailing empty cells and a ragged
result otherwise blows up DataFrame construction.

## Writing

```bash
python scripts/gs.py set '<sheet>' 'Results!A1' --csv out.csv
python scripts/gs.py append '<sheet>' 'Log!A:D' --json '[["2026-08-17","run42",1.4,"ok"]]'
python scripts/gs.py clear '<sheet>' 'Scratch!A1:Z1000'
```

```python
gs.write_df("<sheet>", "Results!A1", df)      # NaN-safe
gs.append("<sheet>", "Log!A:D", [[t, name, value, status]])
```

`set` overwrites from the top-left cell of the range and touches nothing beyond the
data you send — so writing a 3-row block over a 10-row region leaves rows 4–10 as they
were. When replacing a table that may have shrunk, `clear` the old extent first.

`append` takes a whole-column range like `'Log!A:D'` and finds the first free row
itself. That makes it safe against a human editing the sheet at the same time, which
a computed `A57` is not.

Values are parsed as if typed, so `"=B2*C2"` becomes a live formula and `"2026-08-17"`
becomes a date. Pass `--raw` / `raw=True` to store strings verbatim — necessary for
things like sample IDs that look like dates or numbers with leading zeros, which
Sheets will otherwise quietly convert.

## Destructive edits

Overwrites are immediate and the user may have irreplaceable data in the sheet. Before
clearing or overwriting a populated range that the user didn't explicitly point you at,
read it first and say what you're about to replace. Sheets keeps version history, so
mistakes are recoverable via File → Version history — worth mentioning if something
does go wrong, rather than treating it as lost.

Writing results to a **new tab** rather than over the source data is usually the right
default: it's non-destructive, and it keeps the provenance of the original obvious.

```python
gs.add_tab("<sheet>", "analysis 2026-08-17")
```

## Formatting, charts, structure

Anything beyond values goes through `gs.batch_update(sheet, requests)` with raw API
request dicts. `references/recipes.md` has working shapes for header styling, freeze
panes, number formats (including scientific notation), conditional formatting, row
insertion, sorting, charts with error bars, and named ranges. Read it when you need
one rather than guessing at the schema — the `fields` masks in particular are easy to
get subtly wrong in ways that wipe other formatting.

```python
sid = gs.tab_id("<sheet>", "Data")
gs.batch_update("<sheet>", [
    {"updateSheetProperties": {
        "properties": {"sheetId": sid, "gridProperties": {"frozenRowCount": 1}},
        "fields": "gridProperties.frozenRowCount"}},
])
```

## Creating and sharing

```python
out = gs.create("Run log 2026")
gs.share(out["spreadsheetId"], "user@example.com")
```

A spreadsheet made this way is **owned by the service account**, so it will not show
up in the user's Drive at all until shared — always share it and hand back the URL,
or you've made a document only the robot can read.

⚠️ **`create` does not work with a bare service account** (verified 2026-08-17). One outside a Workspace domain has **zero Drive storage quota**, so it
cannot own files: `spreadsheets.create` returns a bare 403 "The caller does not have
permission", and the same call through the Drive API gives the honest version, "The
user's Drive storage quota has been exceeded". This is not fixable from here and is
not a sharing problem — don't chase it. Instead ask the owner to create the sheet in
their own Drive and share it with the service-account address as Editor; every other
operation in this skill then works normally.

## Batching

Quota is 300 requests/minute per project. Reading in a loop or writing cell-by-cell
will hit that on a few hundred rows and start returning 429s. Use `read_many()` for
several ranges in one round trip, one `write()` with a full 2D list instead of many
small ones, and one `batch_update()` carrying many request dicts.

## Interpreting errors

- **403** — not shared with the service account. Nearly always this. Run `whoami`,
  ask the user to add that address as Editor.
- **404** — wrong spreadsheet ID, or the sheet was deleted.
- **400 "Unable to parse range"** — tab name doesn't match. Run `info` and use the
  exact title, quoting it if it contains spaces: `'My Data'!A1:C10`.
- **429** — rate limited. Batch the calls rather than adding sleeps.

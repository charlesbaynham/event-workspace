#!/usr/bin/env python3
"""
gs.py -- Google Sheets read/write via a service account.

Usable two ways:

  1. CLI, for one-liners from bash:
       python gs.py whoami
       python gs.py info <sheet>
       python gs.py get <sheet> 'Data!A1:F200'
       python gs.py set <sheet> 'Data!A1' --csv new.csv
       python gs.py append <sheet> 'Log!A:D' --json '[["2026-08-17","run42",1.4,"ok"]]'

  2. Library, when you need pandas or anything non-trivial:
       from gs import Sheets
       gs = Sheets()
       df = gs.read_df("<sheet>", "Data!A1:F200")
       gs.write_df("<sheet>", "Results!A1", df)

`<sheet>` is either a full Google Sheets URL or the bare spreadsheet ID.

Auth resolution order (first hit wins):
  1. $GOOGLE_SERVICE_ACCOUNT_KEY   -- the JSON key as a string
  2. $GOOGLE_APPLICATION_CREDENTIALS -- path to the JSON key file
  3. ~/.config/gsheets/sa.json
  4. ./sa.json
  5. assets/sa.json next to this skill (gitignored; upstream ships none)

A service-account key is a live credential and does not belong in a
repository: prefer (1), set in the agent environment's variables.

Only deps: google-api-python-client, google-auth. pandas is optional and
imported lazily, so the CLI works without it.
"""

from __future__ import annotations

import argparse
import csv
import io
import json
import os
import re
import sys
from pathlib import Path
from typing import Any, Iterable, Sequence

SCOPES = [
    "https://www.googleapis.com/auth/spreadsheets",
    "https://www.googleapis.com/auth/drive",
]

_ID_RE = re.compile(r"/spreadsheets/d/([a-zA-Z0-9-_]+)")

_HERE = Path(__file__).resolve().parent

DEFAULT_KEY_PATHS = [
    Path.home() / ".config" / "gsheets" / "sa.json",
    Path("sa.json"),
    _HERE.parent / "assets" / "sa.json",  # a consumer's own key; never shipped
]


class AuthError(RuntimeError):
    """Raised when no usable service-account key can be found or parsed."""


def sheet_id(ref: str) -> str:
    """Accept a full Sheets URL or a bare ID and return the bare ID.

    Being liberal here matters because a URL pasted from a browser is the
    most natural thing to hand over, and it always carries tracking cruft
    (#gid=, ?usp=sharing) that would otherwise poison the API call.
    """
    if not ref or not ref.strip():
        raise ValueError("empty spreadsheet reference")
    ref = ref.strip()
    m = _ID_RE.search(ref)
    if m:
        return m.group(1)
    if ref.startswith("http"):
        raise ValueError(f"looks like a URL but has no /spreadsheets/d/<id> part: {ref}")
    return ref


def load_credentials():
    """Find and build service-account credentials, or explain what's missing."""
    from google.oauth2 import service_account

    raw = os.environ.get("GOOGLE_SERVICE_ACCOUNT_KEY")
    if raw:
        try:
            info = json.loads(raw)
        except json.JSONDecodeError as e:
            raise AuthError(
                f"$GOOGLE_SERVICE_ACCOUNT_KEY is set but is not valid JSON: {e}"
            ) from e
        return service_account.Credentials.from_service_account_info(info, scopes=SCOPES)

    candidates: list[Path] = []
    env_path = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS")
    if env_path:
        candidates.append(Path(env_path))
    candidates.extend(DEFAULT_KEY_PATHS)

    for path in candidates:
        if path.is_file():
            return service_account.Credentials.from_service_account_file(
                str(path), scopes=SCOPES
            )

    raise AuthError(
        "No service-account key found. Set $GOOGLE_SERVICE_ACCOUNT_KEY to the JSON "
        "key contents, or $GOOGLE_APPLICATION_CREDENTIALS to its path, or drop it at "
        "~/.config/gsheets/sa.json. Tried: "
        + ", ".join(str(p) for p in candidates)
    )


def service_account_email() -> str:
    """The address a spreadsheet must be shared with before anything works."""
    creds = load_credentials()
    return getattr(creds, "service_account_email", "<unknown>")


class Sheets:
    """Thin wrapper over the Sheets v4 API.

    Deliberately thin: the raw API is well documented and occasionally you
    will want a request shape this class doesn't cover. `self.svc` is public
    so you can drop down to it without fighting the abstraction.
    """

    def __init__(self, credentials=None):
        from googleapiclient.discovery import build

        self.creds = credentials or load_credentials()
        self.svc = build(
            "sheets", "v4", credentials=self.creds, cache_discovery=False
        )

    # ---------- reading ----------

    def info(self, ref: str) -> dict:
        """Spreadsheet title plus each tab's name, id, and dimensions."""
        meta = (
            self.svc.spreadsheets()
            .get(spreadsheetId=sheet_id(ref), includeGridData=False)
            .execute()
        )
        return {
            "title": meta["properties"]["title"],
            "spreadsheetId": meta["spreadsheetId"],
            "url": meta.get("spreadsheetUrl", ""),
            "sheets": [
                {
                    "title": s["properties"]["title"],
                    "sheetId": s["properties"]["sheetId"],
                    "rows": s["properties"].get("gridProperties", {}).get("rowCount"),
                    "cols": s["properties"].get("gridProperties", {}).get("columnCount"),
                }
                for s in meta.get("sheets", [])
            ],
        }

    def tab_id(self, ref: str, tab_name: str) -> int:
        """Numeric sheetId for a tab, which batch_update needs (names won't do)."""
        for s in self.info(ref)["sheets"]:
            if s["title"] == tab_name:
                return s["sheetId"]
        raise KeyError(f"no tab named {tab_name!r} in this spreadsheet")

    def read(self, ref: str, rng: str, formulas: bool = False) -> list[list[Any]]:
        """Values in an A1 range. Ragged rows are returned as the API gives them.

        Set formulas=True to get `=SUM(A1:A9)` back instead of the computed
        value -- useful when copying a sheet's logic rather than its results.
        """
        resp = (
            self.svc.spreadsheets()
            .values()
            .get(
                spreadsheetId=sheet_id(ref),
                range=rng,
                valueRenderOption="FORMULA" if formulas else "UNFORMATTED_VALUE",
            )
            .execute()
        )
        return resp.get("values", [])

    def read_many(self, ref: str, ranges: Sequence[str]) -> dict[str, list[list[Any]]]:
        """Several ranges in one round trip. Prefer this in a loop over read()."""
        resp = (
            self.svc.spreadsheets()
            .values()
            .batchGet(
                spreadsheetId=sheet_id(ref),
                ranges=list(ranges),
                valueRenderOption="UNFORMATTED_VALUE",
            )
            .execute()
        )
        return {
            vr.get("range", rng): vr.get("values", [])
            for rng, vr in zip(ranges, resp.get("valueRanges", []))
        }

    def read_df(self, ref: str, rng: str, header: bool = True):
        """Range as a pandas DataFrame.

        Pads short rows so the frame is rectangular -- the API truncates
        trailing empty cells, which otherwise causes a length mismatch.
        """
        import pandas as pd

        rows = self.read(ref, rng)
        if not rows:
            return pd.DataFrame()
        width = max(len(r) for r in rows)
        rows = [list(r) + [None] * (width - len(r)) for r in rows]
        if header:
            return pd.DataFrame(rows[1:], columns=rows[0])
        return pd.DataFrame(rows)

    # ---------- writing ----------

    def write(
        self,
        ref: str,
        rng: str,
        values: Iterable[Sequence[Any]],
        raw: bool = False,
    ) -> dict:
        """Overwrite a range starting at its top-left cell.

        raw=False (the default) means Sheets parses what you send, so "=A1+B1"
        becomes a live formula and "2026-08-17" becomes a date. Pass raw=True
        when you want strings stored verbatim -- e.g. sample IDs that look
        like dates, which Sheets will otherwise silently mangle.
        """
        body = {"values": [list(r) for r in values]}
        return (
            self.svc.spreadsheets()
            .values()
            .update(
                spreadsheetId=sheet_id(ref),
                range=rng,
                valueInputOption="RAW" if raw else "USER_ENTERED",
                body=body,
            )
            .execute()
        )

    def write_df(self, ref: str, rng: str, df, header: bool = True, raw: bool = False):
        """Write a DataFrame, NaN-safe.

        JSON has no NaN, so unconverted NaNs make the API reject the request
        with an opaque error. Converting to None up front avoids that.
        """
        values = [list(df.columns)] if header else []
        for row in df.itertuples(index=False, name=None):
            values.append([None if _is_nan(v) else _jsonable(v) for v in row])
        return self.write(ref, rng, values, raw=raw)

    def append(
        self, ref: str, rng: str, values: Iterable[Sequence[Any]], raw: bool = False
    ) -> dict:
        """Add rows below the existing data in a range -- the log-file pattern.

        Give a whole-column range like 'Log!A:D'; Sheets finds the first free
        row itself, so concurrent appends don't clobber each other.
        """
        body = {"values": [list(r) for r in values]}
        return (
            self.svc.spreadsheets()
            .values()
            .append(
                spreadsheetId=sheet_id(ref),
                range=rng,
                valueInputOption="RAW" if raw else "USER_ENTERED",
                insertDataOption="INSERT_ROWS",
                body=body,
            )
            .execute()
        )

    def clear(self, ref: str, rng: str) -> dict:
        """Empty a range's values, leaving formatting intact."""
        return (
            self.svc.spreadsheets()
            .values()
            .clear(spreadsheetId=sheet_id(ref), range=rng, body={})
            .execute()
        )

    # ---------- structure and formatting ----------

    def batch_update(self, ref: str, requests: list[dict]) -> dict:
        """Escape hatch to the full batchUpdate API.

        Everything the values endpoints can't do -- formatting, charts,
        conditional rules, freezing, row insertion -- goes through here.
        See references/recipes.md for ready-made request shapes.
        """
        return (
            self.svc.spreadsheets()
            .batchUpdate(spreadsheetId=sheet_id(ref), body={"requests": requests})
            .execute()
        )

    def add_tab(self, ref: str, title: str, rows: int = 1000, cols: int = 26) -> int:
        """Create a tab and return its sheetId."""
        resp = self.batch_update(
            ref,
            [
                {
                    "addSheet": {
                        "properties": {
                            "title": title,
                            "gridProperties": {"rowCount": rows, "columnCount": cols},
                        }
                    }
                }
            ],
        )
        return resp["replies"][0]["addSheet"]["properties"]["sheetId"]

    def create(self, title: str, tabs: Sequence[str] = ("Sheet1",)) -> dict:
        """Make a new spreadsheet owned by the service account.

        The service account owns it, so it won't appear in your Drive until
        you're given access -- call share() straight after, or you'll have a
        spreadsheet only the robot can see.
        """
        body = {
            "properties": {"title": title},
            "sheets": [{"properties": {"title": t}} for t in tabs],
        }
        meta = self.svc.spreadsheets().create(body=body).execute()
        return {"spreadsheetId": meta["spreadsheetId"], "url": meta["spreadsheetUrl"]}

    def share(self, ref: str, email: str, role: str = "writer") -> dict:
        """Grant a human access to a service-account-owned spreadsheet."""
        from googleapiclient.discovery import build

        drive = build("drive", "v3", credentials=self.creds, cache_discovery=False)
        return (
            drive.permissions()
            .create(
                fileId=sheet_id(ref),
                body={"type": "user", "role": role, "emailAddress": email},
                sendNotificationEmail=False,
            )
            .execute()
        )


# ---------- small helpers ----------


def _is_nan(v: Any) -> bool:
    return isinstance(v, float) and v != v


def _jsonable(v: Any) -> Any:
    """Coerce numpy/pandas scalars to plain Python so json can encode them."""
    if hasattr(v, "item") and not isinstance(v, (str, bytes)):
        try:
            return v.item()
        except (ValueError, AttributeError):
            pass
    if isinstance(v, (str, int, float, bool)) or v is None:
        return v
    return str(v)


def _rows_from_args(args) -> list[list[Any]]:
    if args.csv:
        text = sys.stdin.read() if args.csv == "-" else Path(args.csv).read_text()
        return [row for row in csv.reader(io.StringIO(text))]
    if args.json:
        text = sys.stdin.read() if args.json == "-" else args.json
        data = json.loads(text)
        if not isinstance(data, list):
            raise ValueError("--json must be a list of rows")
        return [r if isinstance(r, list) else [r] for r in data]
    raise ValueError("need --csv or --json to know what to write")


def _print_rows(rows: list[list[Any]], as_csv: bool) -> None:
    if as_csv:
        w = csv.writer(sys.stdout)
        for r in rows:
            w.writerow(r)
    else:
        print(json.dumps(rows, indent=2, default=str))


# ---------- CLI ----------


def main(argv: Sequence[str] | None = None) -> int:
    p = argparse.ArgumentParser(prog="gs.py", description=__doc__.split("\n")[1])
    sub = p.add_subparsers(dest="cmd", required=True)

    sub.add_parser("whoami", help="print the service account email")

    g = sub.add_parser("info", help="list tabs and dimensions")
    g.add_argument("sheet")

    g = sub.add_parser("get", help="read a range")
    g.add_argument("sheet")
    g.add_argument("range")
    g.add_argument("--csv-out", action="store_true", help="emit CSV instead of JSON")
    g.add_argument("--formulas", action="store_true", help="return formulas not values")

    g = sub.add_parser("set", help="overwrite a range")
    g.add_argument("sheet")
    g.add_argument("range")
    g.add_argument("--csv", help="CSV file to write, or - for stdin")
    g.add_argument("--json", help="JSON list-of-rows, or - for stdin")
    g.add_argument("--raw", action="store_true", help="store verbatim, no parsing")

    g = sub.add_parser("append", help="add rows below existing data")
    g.add_argument("sheet")
    g.add_argument("range")
    g.add_argument("--csv", help="CSV file to append, or - for stdin")
    g.add_argument("--json", help="JSON list-of-rows, or - for stdin")
    g.add_argument("--raw", action="store_true")

    g = sub.add_parser("clear", help="empty a range")
    g.add_argument("sheet")
    g.add_argument("range")

    g = sub.add_parser("create", help="make a new spreadsheet")
    g.add_argument("title")
    g.add_argument("--share", help="email to grant writer access")

    g = sub.add_parser("share", help="grant a human access")
    g.add_argument("sheet")
    g.add_argument("email")
    g.add_argument("--role", default="writer", choices=["reader", "commenter", "writer"])

    args = p.parse_args(argv)

    try:
        if args.cmd == "whoami":
            print(service_account_email())
            return 0

        gs = Sheets()

        if args.cmd == "info":
            print(json.dumps(gs.info(args.sheet), indent=2))
        elif args.cmd == "get":
            _print_rows(gs.read(args.sheet, args.range, formulas=args.formulas),
                        args.csv_out)
        elif args.cmd == "set":
            r = gs.write(args.sheet, args.range, _rows_from_args(args), raw=args.raw)
            print(f"updated {r.get('updatedCells', 0)} cells in {r.get('updatedRange')}")
        elif args.cmd == "append":
            r = gs.append(args.sheet, args.range, _rows_from_args(args), raw=args.raw)
            upd = r.get("updates", {})
            print(f"appended {upd.get('updatedRows', 0)} rows to {upd.get('updatedRange')}")
        elif args.cmd == "clear":
            r = gs.clear(args.sheet, args.range)
            print(f"cleared {r.get('clearedRange')}")
        elif args.cmd == "create":
            out = gs.create(args.title)
            if args.share:
                gs.share(out["spreadsheetId"], args.share)
            print(json.dumps(out, indent=2))
        elif args.cmd == "share":
            gs.share(args.sheet, args.email, role=args.role)
            print(f"shared with {args.email} as {args.role}")

    except AuthError as e:
        print(f"auth: {e}", file=sys.stderr)
        return 2
    except Exception as e:  # noqa: BLE001 -- CLI boundary, show a clean message
        print(f"{type(e).__name__}: {e}", file=sys.stderr)
        if "403" in str(e):
            print(
                "\nA 403 almost always means the spreadsheet isn't shared with the "
                "service account. Run `python gs.py whoami` and share the sheet with "
                "that address as an Editor.",
                file=sys.stderr,
            )
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

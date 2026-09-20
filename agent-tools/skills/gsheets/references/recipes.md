# batchUpdate recipes

Everything the `values` endpoints can't do goes through `gs.batch_update(sheet, requests)`.
Each request below is one dict in that list; send several at once and they apply atomically.

All of them need a numeric `sheetId`, not a tab name — get it with `gs.tab_id(sheet, "Data")`.

Ranges here are half-open and **zero-indexed**, unlike A1 notation. `startRowIndex: 0,
endRowIndex: 1` is the first row only. Omitting an end index means "to the end of the
sheet", which is usually what you want for whole-column operations.

## Contents

- [Header row](#header-row)
- [Freeze panes](#freeze-panes)
- [Number formats](#number-formats)
- [Column widths](#column-widths)
- [Conditional formatting](#conditional-formatting)
- [Insert and delete rows](#insert-and-delete-rows)
- [Sort](#sort)
- [Charts](#charts)
- [Rename, duplicate, delete tabs](#rename-duplicate-delete-tabs)
- [Named ranges](#named-ranges)

## Header row

```python
{"repeatCell": {
    "range": {"sheetId": sid, "startRowIndex": 0, "endRowIndex": 1},
    "cell": {"userEnteredFormat": {
        "backgroundColor": {"red": 0.92, "green": 0.92, "blue": 0.92},
        "textFormat": {"bold": True},
        "horizontalAlignment": "CENTER"}},
    "fields": "userEnteredFormat(backgroundColor,textFormat,horizontalAlignment)"}}
```

`fields` is a mask naming exactly what to overwrite. Anything not listed is left alone,
so a too-broad mask like `"userEnteredFormat"` will silently wipe borders and number
formats you set earlier.

## Freeze panes

```python
{"updateSheetProperties": {
    "properties": {"sheetId": sid, "gridProperties": {"frozenRowCount": 1}},
    "fields": "gridProperties.frozenRowCount"}}
```

## Number formats

```python
{"repeatCell": {
    "range": {"sheetId": sid, "startRowIndex": 1, "startColumnIndex": 2,
              "endColumnIndex": 3},
    "cell": {"userEnteredFormat": {
        "numberFormat": {"type": "NUMBER", "pattern": "0.000E+00"}}},
    "fields": "userEnteredFormat.numberFormat"}}
```

Patterns follow the same syntax as the Sheets UI. Useful ones for lab data:
`0.000E+00` scientific, `0.00%` percent, `yyyy-mm-dd hh:mm:ss` timestamps,
`#,##0.00` thousands. Type is one of `NUMBER`, `PERCENT`, `CURRENCY`, `DATE`,
`TIME`, `DATE_TIME`, `SCIENTIFIC`.

## Column widths

```python
{"updateDimensionProperties": {
    "range": {"sheetId": sid, "dimension": "COLUMNS",
              "startIndex": 0, "endIndex": 6},
    "properties": {"pixelSize": 140},
    "fields": "pixelSize"}}
```

To size to content instead: `{"autoResizeDimensions": {"dimensions": {...same range...}}}`.

## Conditional formatting

Flag out-of-range measurements — the common case for a monitoring sheet.

```python
{"addConditionalFormatRule": {
    "index": 0,
    "rule": {
        "ranges": [{"sheetId": sid, "startRowIndex": 1, "startColumnIndex": 3,
                    "endColumnIndex": 4}],
        "booleanRule": {
            "condition": {"type": "NUMBER_GREATER",
                          "values": [{"userEnteredValue": "1.5"}]},
            "format": {"backgroundColor": {"red": 1, "green": 0.8, "blue": 0.8}}}}}}
```

For a gradient instead of a threshold, swap `booleanRule` for `gradientRule` with
`minpoint`/`maxpoint` entries. Condition types include `NUMBER_BETWEEN`,
`TEXT_CONTAINS`, `CUSTOM_FORMULA` (put the formula in `values`).

## Insert and delete rows

```python
{"insertDimension": {
    "range": {"sheetId": sid, "dimension": "ROWS", "startIndex": 5, "endIndex": 8},
    "inheritFromBefore": True}}

{"deleteDimension": {
    "range": {"sheetId": sid, "dimension": "ROWS", "startIndex": 5, "endIndex": 8}}}
```

Deleting shifts every later index up, so when removing several disjoint blocks in one
batch, order the requests bottom-to-top or the second one will hit the wrong rows.

## Sort

```python
{"sortRange": {
    "range": {"sheetId": sid, "startRowIndex": 1},
    "sortSpecs": [{"dimensionIndex": 0, "sortOrder": "ASCENDING"}]}}
```

Start at row index 1 to keep the header out of the sort.

## Charts

```python
{"addChart": {"chart": {
    "spec": {
        "title": "Ion count vs time",
        "basicChart": {
            "chartType": "LINE",          # or SCATTER, COLUMN, BAR, AREA
            "legendPosition": "RIGHT_LEGEND",
            "axis": [{"position": "BOTTOM_AXIS", "title": "t (s)"},
                     {"position": "LEFT_AXIS", "title": "counts"}],
            "domains": [{"domain": {"sourceRange": {"sources": [
                {"sheetId": sid, "startRowIndex": 0, "startColumnIndex": 0,
                 "endColumnIndex": 1}]}}}],
            "series": [{"series": {"sourceRange": {"sources": [
                {"sheetId": sid, "startRowIndex": 0, "startColumnIndex": 1,
                 "endColumnIndex": 2}]}},
                "targetAxis": "LEFT_AXIS"}],
            "headerCount": 1}},
    "position": {"overlayPosition": {"anchorCell": {
        "sheetId": sid, "rowIndex": 1, "columnIndex": 7}}}}}}
```

Include the header row in the source ranges and set `headerCount: 1` — that is what
gives the series its name in the legend.

For error bars, add to the series dict:
`"errorBars": {"type": "PERCENT", "value": 5}` (or `CONSTANT`, `STANDARD_DEVIATION`).

## Rename, duplicate, delete tabs

```python
{"updateSheetProperties": {"properties": {"sheetId": sid, "title": "Run 42"},
                           "fields": "title"}}
{"duplicateSheet": {"sourceSheetId": sid, "newSheetName": "Run 42 (copy)"}}
{"deleteSheet": {"sheetId": sid}}
```

## Named ranges

Worth doing for anything a human will reference by hand, since a named range survives
row insertion where a hardcoded A1 string doesn't.

```python
{"addNamedRange": {"namedRange": {
    "name": "calibration",
    "range": {"sheetId": sid, "startRowIndex": 0, "endRowIndex": 10,
              "startColumnIndex": 0, "endColumnIndex": 2}}}}
```

Then read it by name: `gs.read(sheet, "calibration")`.

## Rate limits

The quota is 300 requests per minute per project, 60 per user. Batching is the fix:
`read_many()` for reads, one `batch_update()` with many request dicts for writes. A
loop that writes cell-by-cell will hit the limit on a few hundred rows and start
returning 429s; the same data as a single `write()` of a 2D list is one request.

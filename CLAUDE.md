# Since

macOS menu bar app that answers "when did I last do X?" (haircut, Brita filter, contacts). Each tracked item is a menu row showing time since last done; clicking a row resets its timer. Local-only, no network. Also a Go learning project for Matt.

## Stack

- Go, module `github.com/mattsafaii/since`, binary `since`
- `fyne.io/systray` for the menu bar icon + dropdown
- Native macOS dialogs by shelling out to `osascript` (add/remove) — no Go GUI framework
- No other dependencies

## Data contract

`~/.config/since/items.json` — a list of `{name, lastDone}` (name string, lastDone ISO 8601). Created on first run if absent. Human-readable and hand-editable; this file is the contract for any future UI. The menu rebuilds from the file every time it opens, so hand-edits show up without a restart.

## UI

Everything lives in the dropdown — no windows:

- Item rows: `name — <coarse relative> (<date>)`, e.g. "Haircut — 3 weeks ago (May 12)". Click resets `lastDone` to now and writes the file.
- "Add item…": osascript text-input dialog → new item with `lastDone = now`
- "Remove ▸": submenu of items, osascript confirm before delete
- "Quit"
- Empty state: just "Add item…" and "Quit"

Time labels are coarse, rounded to the largest sensible unit: today / yesterday / N days ago / N weeks ago / N months ago, plus the calendar date in parens.

## No-gos (v1)

- No cadence / target intervals, no overdue states or color-coding
- No notifications
- No history view or contribution graph
- No settings window, no Fyne/Wails windows
- No sync, accounts, or network of any kind

## Basecamp

- Account 6191443 (Safaii Studio), project **Since** id `47572591`
- PRD doc: https://app.basecamp.com/6191443/buckets/47572591/documents/9961623833
- Build todolist id `9961626562` (15 todos: setup → build → verify)
- Pitch card in Lab Ideas board: https://app.basecamp.com/6191443/buckets/46824335/card_tables/cards/9956025654

# Since

macOS menu bar app that answers "when did I last do X?" (haircut, Brita filter, contacts). Each tracked item is a menu row showing time since last done; clicking a row resets its timer. Local-only, no network. Also a Go learning project for Matt.

## Stack

- Go, module `github.com/mattsafaii/since`, binary `since`
- `fyne.io/systray` for the menu bar icon + dropdown
- Native macOS dialogs by shelling out to `osascript` (add/remove) — no Go GUI framework
- No other dependencies

## Data contract

`~/.config/since/items.json` — a list of items. Created on first run if absent. Human-readable and hand-editable; this file is the contract for any future UI and the only settings surface. The menu rebuilds from the file every time it opens, so hand-edits show up without a restart.

Item fields:

- `name` (string), `lastDone` (ISO 8601), `history` (prior lastDone values, appended on each reset)
- `kind` (optional) — `"streak"` for things being avoided (longer = better); omitted means chore (things to do again)
- `every` (optional, chores only) — target interval, integer + `d`/`w`/`m` (e.g. `"6w"`)
- Unknown `kind` / unparseable `every` are treated as absent — v1 files and hand-edit typos never break the app

## UI

Everything lives in the dropdown — no windows:

- Two sections, separator between: **chores** on top (most-overdue-first, then longest-since; overdue rows get a ⚠ suffix), **streaks** below (longest-first, read as records — never overdue)
- Item rows: `name — <coarse relative> (<date>)`, e.g. "Haircut — 3 weeks ago (May 12)". Chore click resets instantly; streak click confirms first, naming the streak length ("End 4-month streak?"). Both undoable via "Undo reset of <name>".
- "Add item…": osascript dialog, buttons Cancel / Streak / Chore set the kind; rejects duplicate names
- "Rename ▸": submenu, keeps lastDone + history
- "Remove ▸": submenu of items, osascript confirm before delete
- "Quit"
- Empty state: just "Add item…" and "Quit"

Time labels are coarse, rounded to the largest sensible unit: today / yesterday / N days ago / N weeks ago / N months ago, plus the calendar date in parens. Overdue = elapsed > `every`, binary.

## No-gos

- No notifications — the glance is the product
- No menu bar icon changes (⧗ stays ⧗ even when something's overdue)
- No "due soon" intermediate state — binary overdue only
- No interval-editing UI — items.json is the settings surface
- No history/stats views, no contribution graph
- No color coding beyond the ⚠ character
- No settings window, no Fyne/Wails windows
- No sync, accounts, or network of any kind

## Current cycle: v2 — kinds + intervals

- PRD doc: https://app.basecamp.com/6191443/buckets/47572591/documents/9966288025
- Build todolist id `9966288907` (13 todos: 5 build, 8 verify)
- Pitch + PRD card: https://app.basecamp.com/6191443/buckets/46824335/card_tables/cards/9962250900

## Dev Log

Dev logs live in Basecamp as messages in the Since project — not in this file.

## Basecamp

- Account 6191443 (Safaii Studio), project **Since** id `47572591`
- PRD doc: https://app.basecamp.com/6191443/buckets/47572591/documents/9961623833
- Build todolist id `9961626562` (15 todos: setup → build → verify)
- Pitch card in Lab Ideas board: https://app.basecamp.com/6191443/buckets/46824335/card_tables/cards/9956025654

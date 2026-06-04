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

## Dev Log

### 2026-06-03

**Build (v1 complete)**
- Built the whole v1 in one session: storage, time labels, menu, and dialogs, working through the 15-todo Basecamp build list from PRD to verified app.
- Storage is a plain `loadItems`/`saveItems` pair over `~/.config/since/items.json`, created empty on first run, because the JSON file is the data contract for any future UI.
- Time labels count calendar days (not 24-hour spans) so something done at 11pm reads "yesterday" the next morning; rounding is coarse on purpose — days under a week, weeks under a month, then months.
- The dropdown rebuilds wholesale from the file on every open via systray's `TrayOpenedCh` — the fyne fork exposes exactly the hook the PRD's "rebuild on open" needed, so hand-edits to items.json show up with no polling and no restart.
- Each rebuild closes a generation channel so stale menu-item click listeners exit instead of leaking goroutines across rebuilds.
- Add/remove use `osascript` dialogs instead of a Go GUI framework to keep the binary dependency-light; AppleScript strings are escaped since item names are user input.
- Click-to-reset and remove match items by name. Known limitation: duplicate names only ever hit the first match — surfaced during verification when the test file had "Alcohol" twice.
- Verification caught a real win for the error path: a hand-edit typo (`-011:00` timezone) made parsing fail, and the menu degraded to a disabled "Couldn't read items.json" row instead of crashing.

## Basecamp

- Account 6191443 (Safaii Studio), project **Since** id `47572591`
- PRD doc: https://app.basecamp.com/6191443/buckets/47572591/documents/9961623833
- Build todolist id `9961626562` (15 todos: setup → build → verify)
- Pitch card in Lab Ideas board: https://app.basecamp.com/6191443/buckets/46824335/card_tables/cards/9956025654

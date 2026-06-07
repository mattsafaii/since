# Since

macOS menu bar app that answers "when did I last do X?" (haircut, Brita filter, contacts). Each tracked item is a menu row showing time since last done; clicking a row resets its timer. Local-only, no network.

## Current cycle: Swift rewrite

Feature-parity port from Go to Swift/AppKit — every UX wall in the Go version was the cross-platform systray abstraction (positioning fork, NSMenu rebuild corruption, osascript dialogs, no ⌥-click alternates). Cutover is done: Swift replaced Go on master, items.json carried over untouched, and the last Go commit is tagged `go-final`. Remaining work is the Verify todos (Matt's hand-testing).

- PRD doc: https://app.basecamp.com/6191443/buckets/47572591/documents/9970247376
- Build todolist id `9970265495` (17 todos: 2 setup, 6 build, 8 verify, 1 dev log)
- Pitch + PRD card: https://app.basecamp.com/6191443/buckets/46824335/card_tables/cards/9970163011

## Stack

- Swift + AppKit: `NSStatusItem` + `NSMenu` (menu rebuilt in `NSMenuDelegate.menuNeedsUpdate`), `NSAlert` dialogs with text-field accessories
- SPM executable target — no Xcode project, no SwiftUI, no MenuBarExtra
- XCTest; the Go table-driven tests ported over as the parity suite, plus a round-trip test against a Go-written items.json fixture
- Makefile assembles Since.app from `swift build -c release` (targets: app/install/login/uninstall/icon/clean), ad-hoc codesign
- No dependencies

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
- "Add item…": NSAlert with a text field, buttons Cancel / Streak / Chore set the kind; rejects duplicate names
- "Edit ▸": submenu of items; clicking a name opens one dialog (name pre-filled, buttons Cancel / Remove / Rename). Rename keeps lastDone + history and rejects duplicates; Remove confirms before deleting
- "Open items.json": opens the file in the default editor — the closest thing to a settings screen
- "Quit"
- Empty state: just "Add item…" and "Quit"

Time labels are coarse, rounded to the largest sensible unit: today / yesterday / N days ago / N weeks ago / N months ago / N years ago, plus the calendar date in parens (with the year when it's not the current year). Overdue = elapsed > `every`, binary.

## No-gos

- No notifications — the glance is the product
- No menu bar icon changes (⧗ stays ⧗ even when something's overdue)
- No "due soon" intermediate state — binary overdue only
- No interval-editing UI — items.json is the settings surface
- No history/stats views, no contribution graph
- No color coding beyond the ⚠ character
- No settings window, no Fyne/Wails windows
- No sync, accounts, or network of any kind

## Shipped cycles

v1 (todolist `9961626562`), v2 kinds + intervals (todolist `9966288907`), polish batch (todolist `9969595703`), Edit menu (todolist `9970120602`) — all Go.

## Dev Log

Dev logs live in Basecamp as messages in the Since project — not in this file.

## Basecamp

- Account 6191443 (Safaii Studio), project **Since** id `47572591`
- PRD doc: https://app.basecamp.com/6191443/buckets/47572591/documents/9961623833
- Build todolist id `9961626562` (15 todos: setup → build → verify)
- Pitch card in Lab Ideas board: https://app.basecamp.com/6191443/buckets/46824335/card_tables/cards/9956025654

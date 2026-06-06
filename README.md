# Since ⧗

macOS menu bar app that answers "when did I last do X?" — haircut, Brita filter, last drink. Each tracked item is a menu row showing the time since it was last done; clicking a row resets its timer. Local-only, no network.

<img src="assets/icon_1024.png" width="128" alt="Since icon">

## How it works

Items come in two kinds:

- **Chores** — things to do again (Haircut, Brita filter). Optionally take a target interval (`"every": "6w"`); rows past their target show a ⚠. Sorted most-overdue-first, so the top of the menu is the "needs attention" zone. Click to reset instantly.
- **Streaks** — things being avoided (Smoked, Alcohol). Longer is better; sorted longest-first and shown below a separator so they read as records, not neglect. Clicking asks for confirmation first ("End your 4 months streak?") — a misclick shouldn't kill the trophy.

Both kinds are undoable after a reset via "Undo reset of …". Labels are coarse on purpose: today / yesterday / N days / N weeks / N months / N years ago, plus the date (with the year once it's not this year's).

## Data

Everything lives in `~/.config/since/items.json` — human-readable, hand-editable, created on first run:

```json
[
  { "name": "Haircut", "lastDone": "2026-05-12T10:00:00-07:00", "every": "6w" },
  { "name": "Alcohol", "lastDone": "2026-06-03T22:59:36-07:00", "kind": "streak" }
]
```

- `kind`: `"streak"`, or omit for a chore
- `every`: chore target interval — integer + `d`/`w`/`m` (e.g. `"10d"`, `"6w"`, `"3m"`)
- `history`: prior `lastDone` values, appended automatically on each reset

The menu rebuilds from the file every time it opens, so hand-edits show up without a restart. Typos never break anything — an unparseable interval just means no target.

This file is the only settings surface. There is no settings window — "Edit items…" in the menu opens it in your default editor.

## Install

Requires Go and macOS.

```bash
make install   # build Since.app and copy it to /Applications
make login     # also start at login (installs a LaunchAgent)
```

Other targets: `make app` (build the bundle into `dist/`), `make icon` (regenerate the icns from the Swift drawing script), `make uninstall` (remove the app and LaunchAgent).

## Stack

- Go + [fyne.io/systray](https://github.com/fyne-io/systray) for the menu bar icon and dropdown
  - currently pinned to [a fork](https://github.com/mattsafaii/systray/tree/fix-macos-menu-position) until [fyne-io/systray#119](https://github.com/fyne-io/systray/pull/119) lands (menu opened behind the macOS menu bar)
- Native dialogs by shelling out to `osascript` — no GUI framework
- No other dependencies

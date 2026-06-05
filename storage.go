package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strconv"
	"time"
)

// Item is one tracked thing: its name and when it was last done.
// History holds prior lastDone values, oldest first — appended on every
// reset so undo (and any future stats) have data to work with.
//
// Kind and Every are optional; v1 files omit both. Unknown kinds and
// unparseable intervals are treated as absent so a hand-edit typo never
// breaks the app.
type Item struct {
	Name     string      `json:"name"`
	LastDone time.Time   `json:"lastDone"`
	History  []time.Time `json:"history,omitempty"`
	Kind     string      `json:"kind,omitempty"`  // "streak" = avoiding it, longer is better; else chore
	Every    string      `json:"every,omitempty"` // chore target interval, e.g. "6w" (d/w/m)
}

// IsStreak reports whether this item tracks something being avoided.
func (it Item) IsStreak() bool {
	return it.Kind == "streak"
}

// TargetDays returns the chore's target interval in days. ok is false
// for streaks and for absent or unparseable Every values.
func (it Item) TargetDays() (days int, ok bool) {
	if it.IsStreak() || len(it.Every) < 2 {
		return 0, false
	}
	n, err := strconv.Atoi(it.Every[:len(it.Every)-1])
	if err != nil || n <= 0 {
		return 0, false
	}
	switch it.Every[len(it.Every)-1] {
	case 'd':
		return n, true
	case 'w':
		return n * 7, true
	case 'm':
		return n * 30, true
	}
	return 0, false
}

// Overdue reports whether a chore is past its target interval.
// Streaks are never overdue.
func (it Item) Overdue(now time.Time) bool {
	days, ok := it.TargetDays()
	return ok && daysBetween(it.LastDone, now) > days
}

// itemsPath returns ~/.config/since/items.json.
func itemsPath() (string, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(home, ".config", "since", "items.json"), nil
}

// loadItems reads items.json, creating an empty file on first run.
func loadItems() ([]Item, error) {
	path, err := itemsPath()
	if err != nil {
		return nil, err
	}
	data, err := os.ReadFile(path)
	if os.IsNotExist(err) {
		if err := saveItems([]Item{}); err != nil {
			return nil, err
		}
		return []Item{}, nil
	}
	if err != nil {
		return nil, err
	}
	var items []Item
	if err := json.Unmarshal(data, &items); err != nil {
		return nil, err
	}
	return items, nil
}

// saveItems writes items.json, creating the directory if needed.
func saveItems(items []Item) error {
	path, err := itemsPath()
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	data, err := json.MarshalIndent(items, "", "  ")
	if err != nil {
		return err
	}
	// Write to a temp file and rename so a crash mid-write can't
	// corrupt items.json — it's the single source of truth.
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, data, 0o644); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}

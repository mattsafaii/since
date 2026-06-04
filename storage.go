package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"time"
)

// Item is one tracked thing: its name and when it was last done.
type Item struct {
	Name     string    `json:"name"`
	LastDone time.Time `json:"lastDone"`
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

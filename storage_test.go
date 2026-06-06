package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestTargetDays(t *testing.T) {
	tests := []struct {
		name     string
		item     Item
		wantDays int
		wantOK   bool
	}{
		{"days", Item{Every: "2d"}, 2, true},
		{"weeks", Item{Every: "6w"}, 42, true},
		{"months", Item{Every: "3m"}, 90, true},
		{"absent", Item{}, 0, false},
		{"bad unit", Item{Every: "2x"}, 0, false},
		{"zero", Item{Every: "0d"}, 0, false},
		{"negative", Item{Every: "-1d"}, 0, false},
		{"no number", Item{Every: "w"}, 0, false},
		{"not a number", Item{Every: "ad"}, 0, false},
		{"streaks have no target", Item{Kind: "streak", Every: "6w"}, 0, false},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			days, ok := tt.item.TargetDays()
			if days != tt.wantDays || ok != tt.wantOK {
				t.Errorf("TargetDays() = (%d, %v), want (%d, %v)", days, ok, tt.wantDays, tt.wantOK)
			}
		})
	}
}

func TestOverdue(t *testing.T) {
	now := time.Date(2026, time.June, 6, 12, 0, 0, 0, time.Local)
	tests := []struct {
		name string
		item Item
		want bool
	}{
		{"past target", Item{Every: "6w", LastDone: now.AddDate(0, 0, -43)}, true},
		{"at target", Item{Every: "6w", LastDone: now.AddDate(0, 0, -42)}, false},
		{"no target", Item{LastDone: now.AddDate(0, 0, -100)}, false},
		{"unparseable target", Item{Every: "2x", LastDone: now.AddDate(0, 0, -100)}, false},
		{"streaks never overdue", Item{Kind: "streak", Every: "1d", LastDone: now.AddDate(0, 0, -100)}, false},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := tt.item.Overdue(now); got != tt.want {
				t.Errorf("Overdue() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestSaveLoadRoundTrip(t *testing.T) {
	t.Setenv("HOME", t.TempDir())

	want := []Item{
		{Name: "Haircut", LastDone: time.Now().Round(time.Second), Every: "6w"},
		{Name: "Alcohol", LastDone: time.Now().AddDate(0, -1, 0).Round(time.Second), Kind: "streak",
			History: []time.Time{time.Now().AddDate(0, -3, 0).Round(time.Second)}},
	}
	if err := saveItems(want); err != nil {
		t.Fatalf("saveItems: %v", err)
	}
	got, err := loadItems()
	if err != nil {
		t.Fatalf("loadItems: %v", err)
	}
	if len(got) != len(want) {
		t.Fatalf("loaded %d items, want %d", len(got), len(want))
	}
	for i := range want {
		if got[i].Name != want[i].Name || !got[i].LastDone.Equal(want[i].LastDone) ||
			got[i].Kind != want[i].Kind || got[i].Every != want[i].Every ||
			len(got[i].History) != len(want[i].History) {
			t.Errorf("item %d = %+v, want %+v", i, got[i], want[i])
		}
	}
}

func TestLoadItemsCreatesFileOnFirstRun(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)

	items, err := loadItems()
	if err != nil {
		t.Fatalf("loadItems: %v", err)
	}
	if len(items) != 0 {
		t.Errorf("first run loaded %d items, want 0", len(items))
	}
	if _, err := os.Stat(filepath.Join(home, ".config", "since", "items.json")); err != nil {
		t.Errorf("items.json not created on first run: %v", err)
	}
}

// v1 files have only name, lastDone, and history. They must load as
// chores with no target — and unknown kinds must not break anything.
func TestV1FileTolerance(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)

	v1 := `[
	  {"name": "Haircut", "lastDone": "2026-05-12T10:00:00-07:00"},
	  {"name": "Mystery", "lastDone": "2026-05-12T10:00:00-07:00", "kind": "habit", "every": "soon"}
	]`
	dir := filepath.Join(home, ".config", "since")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "items.json"), []byte(v1), 0o644); err != nil {
		t.Fatal(err)
	}

	items, err := loadItems()
	if err != nil {
		t.Fatalf("loadItems: %v", err)
	}
	now := time.Date(2026, time.June, 6, 12, 0, 0, 0, time.Local)
	for _, it := range items {
		if it.IsStreak() {
			t.Errorf("%s treated as streak", it.Name)
		}
		if _, ok := it.TargetDays(); ok {
			t.Errorf("%s has a target interval", it.Name)
		}
		if it.Overdue(now) {
			t.Errorf("%s overdue without a valid target", it.Name)
		}
	}
}

// Optional fields must be omitted from the file when empty — hand-editors
// shouldn't see "history": null or "kind": "" noise.
func TestOptionalFieldsOmittedWhenEmpty(t *testing.T) {
	data, err := json.Marshal(Item{Name: "Haircut", LastDone: time.Now()})
	if err != nil {
		t.Fatal(err)
	}
	for _, field := range []string{`"history"`, `"kind"`, `"every"`} {
		if strings.Contains(string(data), field) {
			t.Errorf("empty %s serialized: %s", field, data)
		}
	}
}

package main

import (
	"testing"
	"time"
)

func TestDisplayOrder(t *testing.T) {
	now := time.Date(2026, time.June, 6, 12, 0, 0, 0, time.Local)
	items := []Item{
		{Name: "Fresh chore", LastDone: now.AddDate(0, 0, -1), Every: "6w"},
		{Name: "Young streak", LastDone: now.AddDate(0, 0, -3), Kind: "streak"},
		{Name: "Overdue chore", LastDone: now.AddDate(0, 0, -50), Every: "6w"},
		{Name: "Old streak", LastDone: now.AddDate(0, -4, 0), Kind: "streak"},
		{Name: "Very overdue chore", LastDone: now.AddDate(0, 0, -90), Every: "6w"},
		{Name: "No-target chore", LastDone: now.AddDate(0, 0, -200)},
	}

	chores, streaks := displayOrder(items, now)

	wantChores := []string{"Very overdue chore", "Overdue chore", "No-target chore", "Fresh chore"}
	if len(chores) != len(wantChores) {
		t.Fatalf("got %d chores, want %d", len(chores), len(wantChores))
	}
	for i, want := range wantChores {
		if chores[i].Name != want {
			t.Errorf("chores[%d] = %q, want %q", i, chores[i].Name, want)
		}
	}

	wantStreaks := []string{"Old streak", "Young streak"}
	if len(streaks) != len(wantStreaks) {
		t.Fatalf("got %d streaks, want %d", len(streaks), len(wantStreaks))
	}
	for i, want := range wantStreaks {
		if streaks[i].Name != want {
			t.Errorf("streaks[%d] = %q, want %q", i, streaks[i].Name, want)
		}
	}
}

func TestRowLabel(t *testing.T) {
	now := time.Date(2026, time.June, 6, 12, 0, 0, 0, time.Local)
	tests := []struct {
		name string
		item Item
		want string
	}{
		{
			"chore within target",
			Item{Name: "Haircut", LastDone: now.AddDate(0, 0, -21), Every: "6w"},
			"Haircut — 3 weeks ago (May 16)",
		},
		{
			"overdue chore gets warning",
			Item{Name: "Haircut", LastDone: now.AddDate(0, 0, -50), Every: "6w"},
			"Haircut — 1 month ago (Apr 17) ⚠",
		},
		{
			"streak never gets warning",
			Item{Name: "Alcohol", LastDone: now.AddDate(0, 0, -50), Kind: "streak", Every: "1d"},
			"Alcohol — 1 month ago (Apr 17)",
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := rowLabel(tt.item, now); got != tt.want {
				t.Errorf("rowLabel() = %q, want %q", got, tt.want)
			}
		})
	}
}

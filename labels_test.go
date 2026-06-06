package main

import (
	"testing"
	"time"
)

// day returns midnight local time on the given date.
func day(year int, month time.Month, d int) time.Time {
	return time.Date(year, month, d, 0, 0, 0, 0, time.Local)
}

func TestRelative(t *testing.T) {
	now := time.Date(2026, time.June, 6, 12, 0, 0, 0, time.Local)
	tests := []struct {
		name     string
		lastDone time.Time
		want     string
	}{
		{"same moment", now, "today"},
		{"earlier today", now.Add(-2 * time.Hour), "today"},
		{"yesterday", day(2026, time.June, 5), "yesterday"},
		{"two days", day(2026, time.June, 4), "2 days ago"},
		{"six days", day(2026, time.May, 31), "6 days ago"},
		{"seven days is a week", day(2026, time.May, 30), "1 week ago"},
		{"thirteen days is one week", day(2026, time.May, 24), "1 week ago"},
		{"two weeks", day(2026, time.May, 23), "2 weeks ago"},
		{"29 days is four weeks", now.AddDate(0, 0, -29), "4 weeks ago"},
		{"30 days is a month", now.AddDate(0, 0, -30), "1 month ago"},
		{"60 days is two months", now.AddDate(0, 0, -60), "2 months ago"},
		{"364 days is twelve months", now.AddDate(0, 0, -364), "12 months ago"},
		{"365 days is a year", now.AddDate(0, 0, -365), "1 year ago"},
		{"729 days is one year", now.AddDate(0, 0, -729), "1 year ago"},
		{"730 days is two years", now.AddDate(0, 0, -730), "2 years ago"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := relative(tt.lastDone, now); got != tt.want {
				t.Errorf("relative(%v) = %q, want %q", tt.lastDone, got, tt.want)
			}
		})
	}
}

func TestDaysBetweenCountsCalendarDays(t *testing.T) {
	// 11pm yesterday → 1am today is 2 hours but one calendar day.
	a := time.Date(2026, time.June, 5, 23, 0, 0, 0, time.Local)
	b := time.Date(2026, time.June, 6, 1, 0, 0, 0, time.Local)
	if got := daysBetween(a, b); got != 1 {
		t.Errorf("daysBetween(11pm yesterday, 1am today) = %d, want 1", got)
	}
	if got := relative(a, b); got != "yesterday" {
		t.Errorf("relative(11pm yesterday, 1am today) = %q, want %q", got, "yesterday")
	}
}

func TestSinceLabel(t *testing.T) {
	now := day(2026, time.June, 6)
	tests := []struct {
		name     string
		lastDone time.Time
		want     string
	}{
		{"same year omits year", day(2026, time.May, 12), "3 weeks ago (May 12)"},
		{"other year includes year", day(2025, time.February, 1), "1 year ago (Feb 1, 2025)"},
		{"recent but last year includes year", day(2025, time.December, 30), "5 months ago (Dec 30, 2025)"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := sinceLabel(tt.lastDone, now); got != tt.want {
				t.Errorf("sinceLabel(%v) = %q, want %q", tt.lastDone, got, tt.want)
			}
		})
	}
}

package main

import (
	"fmt"
	"time"
)

// sinceLabel renders a coarse relative label plus the calendar date,
// e.g. "today (Jun 3)", "yesterday (Jun 2)", "3 weeks ago (May 12)".
func sinceLabel(lastDone, now time.Time) string {
	return fmt.Sprintf("%s (%s)", relative(lastDone, now), lastDone.Format("Jan 2"))
}

// relative rounds the elapsed time to the largest sensible unit,
// counting calendar days so "yesterday" means yesterday, not 24 hours ago.
func relative(lastDone, now time.Time) string {
	days := daysBetween(lastDone, now)
	switch {
	case days <= 0:
		return "today"
	case days == 1:
		return "yesterday"
	case days < 7:
		return fmt.Sprintf("%d days ago", days)
	case days < 30:
		weeks := days / 7
		if weeks == 1 {
			return "1 week ago"
		}
		return fmt.Sprintf("%d weeks ago", weeks)
	default:
		months := days / 30
		if months == 1 {
			return "1 month ago"
		}
		return fmt.Sprintf("%d months ago", months)
	}
}

// daysBetween counts calendar days from a to b in local time.
func daysBetween(a, b time.Time) int {
	a = a.Local()
	b = b.Local()
	aDay := time.Date(a.Year(), a.Month(), a.Day(), 0, 0, 0, 0, time.Local)
	bDay := time.Date(b.Year(), b.Month(), b.Day(), 0, 0, 0, 0, time.Local)
	return int(bDay.Sub(aDay).Hours() / 24)
}

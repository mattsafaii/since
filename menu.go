package main

import (
	"fmt"
	"log"
	"os/exec"
	"sort"
	"strings"
	"sync"
	"time"

	"fyne.io/systray"
)

var (
	menuMu        sync.Mutex
	menuGen       chan struct{}       // closed on each rebuild so stale click listeners exit
	menuRows      []*systray.MenuItem // current item rows, parallel to rowNames
	rowNames      []string            // item names the menu was last built from
	lastResetName string              // most recent reset, undoable until the next action
)

func onReady() {
	systray.SetTitle("⧗")
	systray.SetTooltip("Since")
	rebuildMenu()
	go func() {
		for range systray.TrayOpenedCh {
			refreshMenu()
		}
	}()
}

// refreshMenu updates row labels in place when the menu opens. A full
// ResetMenu while the menu is displaying breaks NSMenu's height math
// (phantom scroll arrows, menu creeping downward), so we only rebuild
// when the item set actually changed — e.g. a hand-edit to items.json —
// and otherwise just SetTitle, which is safe on an open menu.
func refreshMenu() {
	menuMu.Lock()
	defer menuMu.Unlock()

	items, err := loadItems()
	if err != nil {
		log.Printf("loading items: %v", err)
		rebuildMenuLocked()
		return
	}
	now := time.Now()
	chores, streaks := displayOrder(items, now)
	ordered := append(chores, streaks...)

	same := len(ordered) == len(rowNames)
	if same {
		for i := range ordered {
			if ordered[i].Name != rowNames[i] {
				same = false
				break
			}
		}
	}
	if !same {
		rebuildMenuLocked()
		return
	}

	for i, it := range ordered {
		menuRows[i].SetTitle(rowLabel(it, now))
	}
}

// rebuildMenu redraws the whole dropdown from items.json.
func rebuildMenu() {
	menuMu.Lock()
	defer menuMu.Unlock()
	rebuildMenuLocked()
}

func rebuildMenuLocked() {
	if menuGen != nil {
		close(menuGen)
	}
	menuGen = make(chan struct{})
	gen := menuGen

	systray.ResetMenu()
	menuRows = nil
	rowNames = nil

	items, err := loadItems()
	if err != nil {
		log.Printf("loading items: %v", err)
		broken := systray.AddMenuItem("Couldn't read items.json", "")
		broken.Disable()
	}
	now := time.Now()
	chores, streaks := displayOrder(items, now)

	addRow := func(it Item) {
		tooltip := "Click to reset to today"
		if it.IsStreak() {
			tooltip = "Click to end this streak"
		}
		row := systray.AddMenuItem(rowLabel(it, now), tooltip)
		menuRows = append(menuRows, row)
		rowNames = append(rowNames, it.Name)
		name := it.Name
		streak := it.IsStreak()
		go func() {
			select {
			case <-row.ClickedCh:
				if streak {
					endStreak(name)
				} else {
					resetItem(name)
				}
			case <-gen:
			}
		}()
	}

	for _, it := range chores {
		addRow(it)
	}
	if len(chores) > 0 && len(streaks) > 0 {
		systray.AddSeparator()
	}
	for _, it := range streaks {
		addRow(it)
	}
	if len(items) > 0 {
		systray.AddSeparator()
	}

	add := systray.AddMenuItem("Add item…", "")
	go func() {
		select {
		case <-add.ClickedCh:
			addItem()
		case <-gen:
		}
	}()

	if len(items) > 0 {
		ordered := append(chores, streaks...)
		edit := systray.AddMenuItem("Edit", "")
		for _, it := range ordered {
			sub := edit.AddSubMenuItem(it.Name, "")
			name := it.Name
			go func() {
				select {
				case <-sub.ClickedCh:
					editItem(name)
				case <-gen:
				}
			}()
		}

		open := systray.AddMenuItem("Open items.json", "Open items.json in your editor")
		go func() {
			select {
			case <-open.ClickedCh:
				openItemsFile()
			case <-gen:
			}
		}()
	}

	if lastResetName != "" {
		undo := systray.AddMenuItem(fmt.Sprintf("Undo reset of %s", lastResetName), "")
		go func() {
			select {
			case <-undo.ClickedCh:
				undoReset()
			case <-gen:
			}
		}()
	}

	quit := systray.AddMenuItem("Quit", "")
	go func() {
		select {
		case <-quit.ClickedCh:
			systray.Quit()
		case <-gen:
		}
	}()
}

// rowLabel renders one menu row: name, coarse relative, date, and a
// ⚠ suffix when a chore is past its target interval.
func rowLabel(it Item, now time.Time) string {
	label := fmt.Sprintf("%s — %s", it.Name, sinceLabel(it.LastDone, now))
	if it.Overdue(now) {
		label += " ⚠"
	}
	return label
}

// displayOrder splits items into menu sections: chores (overdue before
// not, longest-since within each) and streaks (longest first, read as
// records). Display only — items.json keeps its own order.
func displayOrder(items []Item, now time.Time) (chores, streaks []Item) {
	for _, it := range items {
		if it.IsStreak() {
			streaks = append(streaks, it)
		} else {
			chores = append(chores, it)
		}
	}
	sort.SliceStable(chores, func(i, j int) bool {
		oi, oj := chores[i].Overdue(now), chores[j].Overdue(now)
		if oi != oj {
			return oi
		}
		return chores[i].LastDone.Before(chores[j].LastDone)
	})
	sort.SliceStable(streaks, func(i, j int) bool {
		return streaks[i].LastDone.Before(streaks[j].LastDone)
	})
	return chores, streaks
}

// undoReset restores the previous lastDone of the most recent reset.
func undoReset() {
	menuMu.Lock()
	name := lastResetName
	lastResetName = ""
	menuMu.Unlock()
	if name == "" {
		return
	}
	items, err := loadItems()
	if err != nil {
		log.Printf("loading items: %v", err)
		return
	}
	for i := range items {
		if items[i].Name == name && len(items[i].History) > 0 {
			last := len(items[i].History) - 1
			items[i].LastDone = items[i].History[last]
			items[i].History = items[i].History[:last]
			if len(items[i].History) == 0 {
				items[i].History = nil
			}
			break
		}
	}
	if err := saveItems(items); err != nil {
		log.Printf("saving items: %v", err)
	}
	rebuildMenu()
}

// openItemsFile opens items.json in the default editor — it's the only
// settings surface, so this is the closest thing to a settings screen.
func openItemsFile() {
	path, err := itemsPath()
	if err != nil {
		log.Printf("finding items.json: %v", err)
		return
	}
	if err := exec.Command("open", path).Start(); err != nil {
		log.Printf("opening items.json: %v", err)
	}
}

// addItem prompts for a name and kind, then appends a new item with
// lastDone = now.
func addItem() {
	name, streak, ok := promptForName()
	if !ok {
		return
	}
	items, err := loadItems()
	if err != nil {
		log.Printf("loading items: %v", err)
		return
	}
	// Names are how reset and remove find items, so duplicates would
	// always hit the first match. Reject instead.
	for _, it := range items {
		if it.Name == name {
			alertDuplicate(name)
			return
		}
	}
	kind := ""
	if streak {
		kind = "streak"
	}
	items = append(items, Item{Name: name, LastDone: time.Now(), Kind: kind})
	if err := saveItems(items); err != nil {
		log.Printf("saving items: %v", err)
	}
	rebuildMenu()
}

// editItem shows the edit dialog and routes the chosen action:
// Remove confirms then deletes; Rename keeps lastDone and history.
func editItem(name string) {
	newName, button, ok := promptForEdit(name)
	if !ok {
		return
	}
	if button == "Remove" {
		removeItem(name)
		return
	}
	renameItem(name, newName)
}

// renameItem renames an item, keeping lastDone and history.
func renameItem(oldName, newName string) {
	if newName == "" || newName == oldName {
		return
	}
	items, err := loadItems()
	if err != nil {
		log.Printf("loading items: %v", err)
		return
	}
	for _, it := range items {
		if it.Name == newName {
			alertDuplicate(newName)
			return
		}
	}
	for i := range items {
		if items[i].Name == oldName {
			items[i].Name = newName
			break
		}
	}
	if err := saveItems(items); err != nil {
		log.Printf("saving items: %v", err)
	}
	menuMu.Lock()
	if lastResetName == oldName {
		lastResetName = newName
	}
	menuMu.Unlock()
	rebuildMenu()
}

// removeItem confirms, then deletes the item and redraws.
func removeItem(name string) {
	if !confirmRemove(name) {
		return
	}
	items, err := loadItems()
	if err != nil {
		log.Printf("loading items: %v", err)
		return
	}
	kept := items[:0]
	for _, it := range items {
		if it.Name != name {
			kept = append(kept, it)
		}
	}
	if err := saveItems(kept); err != nil {
		log.Printf("saving items: %v", err)
	}
	rebuildMenu()
}

// endStreak confirms (naming the current streak length), then resets.
func endStreak(name string) {
	items, err := loadItems()
	if err != nil {
		log.Printf("loading items: %v", err)
		return
	}
	length := ""
	for _, it := range items {
		if it.Name == name {
			rel := relative(it.LastDone, time.Now())
			if cut, found := strings.CutSuffix(rel, " ago"); found {
				length = cut // "4 months ago" → "4 months"
			}
			break
		}
	}
	if !confirmEndStreak(name, length) {
		return
	}
	resetItem(name)
}

// resetItem sets an item's lastDone to now, writes the file, and redraws.
func resetItem(name string) {
	items, err := loadItems()
	if err != nil {
		log.Printf("loading items: %v", err)
		return
	}
	for i := range items {
		if items[i].Name == name {
			items[i].History = append(items[i].History, items[i].LastDone)
			items[i].LastDone = time.Now()
			break
		}
	}
	if err := saveItems(items); err != nil {
		log.Printf("saving items: %v", err)
	}
	menuMu.Lock()
	lastResetName = name
	menuMu.Unlock()
	rebuildMenu()
}

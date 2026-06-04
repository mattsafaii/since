package main

import (
	"fmt"
	"log"
	"sync"
	"time"

	"fyne.io/systray"
)

var (
	menuMu   sync.Mutex
	menuGen  chan struct{}       // closed on each rebuild so stale click listeners exit
	menuRows []*systray.MenuItem // current item rows, parallel to rowNames
	rowNames []string            // item names the menu was last built from
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

	same := len(items) == len(rowNames)
	if same {
		for i := range items {
			if items[i].Name != rowNames[i] {
				same = false
				break
			}
		}
	}
	if !same {
		rebuildMenuLocked()
		return
	}

	now := time.Now()
	for i, it := range items {
		menuRows[i].SetTitle(fmt.Sprintf("%s — %s", it.Name, sinceLabel(it.LastDone, now)))
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
	for _, it := range items {
		row := systray.AddMenuItem(fmt.Sprintf("%s — %s", it.Name, sinceLabel(it.LastDone, now)), "Click to reset to today")
		menuRows = append(menuRows, row)
		rowNames = append(rowNames, it.Name)
		name := it.Name
		go func() {
			select {
			case <-row.ClickedCh:
				resetItem(name)
			case <-gen:
			}
		}()
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
		remove := systray.AddMenuItem("Remove", "")
		for _, it := range items {
			sub := remove.AddSubMenuItem(it.Name, "")
			name := it.Name
			go func() {
				select {
				case <-sub.ClickedCh:
					removeItem(name)
				case <-gen:
				}
			}()
		}
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

// addItem prompts for a name and appends a new item with lastDone = now.
func addItem() {
	name, ok := promptForName()
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
	items = append(items, Item{Name: name, LastDone: time.Now()})
	if err := saveItems(items); err != nil {
		log.Printf("saving items: %v", err)
	}
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
	rebuildMenu()
}

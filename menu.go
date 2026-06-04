package main

import (
	"fmt"
	"log"
	"sync"
	"time"

	"fyne.io/systray"
)

var (
	menuMu  sync.Mutex
	menuGen chan struct{} // closed on each rebuild so stale click listeners exit
)

func onReady() {
	systray.SetTitle("⧗")
	systray.SetTooltip("Since")
	rebuildMenu()
	go func() {
		for range systray.TrayOpenedCh {
			rebuildMenu()
		}
	}()
}

// rebuildMenu redraws the whole dropdown from items.json, so hand-edits
// show up every time the menu opens.
func rebuildMenu() {
	menuMu.Lock()
	defer menuMu.Unlock()

	if menuGen != nil {
		close(menuGen)
	}
	menuGen = make(chan struct{})
	gen := menuGen

	systray.ResetMenu()

	items, err := loadItems()
	if err != nil {
		log.Printf("loading items: %v", err)
		broken := systray.AddMenuItem("Couldn't read items.json", "")
		broken.Disable()
	}

	now := time.Now()
	for _, it := range items {
		row := systray.AddMenuItem(fmt.Sprintf("%s — %s", it.Name, sinceLabel(it.LastDone, now)), "Click to reset to today")
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

	quit := systray.AddMenuItem("Quit", "")
	go func() {
		select {
		case <-quit.ClickedCh:
			systray.Quit()
		case <-gen:
		}
	}()
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
			items[i].LastDone = time.Now()
			break
		}
	}
	if err := saveItems(items); err != nil {
		log.Printf("saving items: %v", err)
	}
	rebuildMenu()
}

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
		systray.AddMenuItem(fmt.Sprintf("%s — %s", it.Name, sinceLabel(it.LastDone, now)), "")
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

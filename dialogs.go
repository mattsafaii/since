package main

import (
	"os/exec"
	"strings"
)

// promptForName shows a native text-input dialog and returns the entered
// name. ok is false when the dialog is cancelled or the input is empty.
func promptForName() (name string, ok bool) {
	out, err := exec.Command("osascript", "-e",
		`text returned of (display dialog "What do you want to track?" default answer "" with title "Since" buttons {"Cancel", "Add"} default button "Add")`,
	).Output()
	if err != nil { // cancelled
		return "", false
	}
	name = strings.TrimSpace(string(out))
	return name, name != ""
}

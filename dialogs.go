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

// promptForRename shows a text-input dialog pre-filled with the current
// name. ok is false when cancelled, empty, or unchanged.
func promptForRename(current string) (name string, ok bool) {
	out, err := exec.Command("osascript", "-e",
		`text returned of (display dialog "Rename “`+escapeAppleScript(current)+`” to:" default answer "`+escapeAppleScript(current)+`" with title "Since" buttons {"Cancel", "Rename"} default button "Rename")`,
	).Output()
	if err != nil { // cancelled
		return "", false
	}
	name = strings.TrimSpace(string(out))
	return name, name != "" && name != current
}

// alertDuplicate tells the user an item with this name already exists.
func alertDuplicate(name string) {
	exec.Command("osascript", "-e",
		`display alert "“`+escapeAppleScript(name)+`” already exists" message "Item names must be unique." as warning`,
	).Run()
}

// confirmRemove shows a native confirm dialog; true means delete it.
func confirmRemove(name string) bool {
	err := exec.Command("osascript", "-e",
		`display dialog "Remove “`+escapeAppleScript(name)+`”?" with title "Since" buttons {"Cancel", "Remove"} default button "Cancel"`,
	).Run()
	return err == nil // cancelled dialogs exit non-zero
}

// escapeAppleScript escapes a value for use inside an AppleScript string literal.
func escapeAppleScript(s string) string {
	s = strings.ReplaceAll(s, `\`, `\\`)
	return strings.ReplaceAll(s, `"`, `\"`)
}

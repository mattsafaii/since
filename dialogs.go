package main

import (
	"os/exec"
	"strings"
)

// promptForName shows a native text-input dialog. The button picks the
// kind: Chore for things to do again, Streak for things being avoided.
// ok is false when the dialog is cancelled or the input is empty.
func promptForName() (name string, streak, ok bool) {
	// The input is a single line, so a linefeed can't appear in the
	// name and safely separates it from the button choice.
	out, err := exec.Command("osascript", "-e",
		`set d to display dialog "What do you want to track?" default answer "" with title "Since" buttons {"Cancel", "Streak", "Chore"} default button "Chore"`,
		"-e", `(text returned of d) & linefeed & (button returned of d)`,
	).Output()
	if err != nil { // cancelled
		return "", false, false
	}
	text, button, found := strings.Cut(strings.TrimRight(string(out), "\n"), "\n")
	if !found {
		return "", false, false
	}
	name = strings.TrimSpace(text)
	return name, button == "Streak", name != ""
}

// promptForEdit shows one dialog for an item: its name in a text field,
// with Remove and Rename as the actions. button is "Remove" or "Rename";
// ok is false when cancelled.
func promptForEdit(current string) (name, button string, ok bool) {
	out, err := exec.Command("osascript", "-e",
		`set d to display dialog "Edit “`+escapeAppleScript(current)+`”:" default answer "`+escapeAppleScript(current)+`" with title "Since" buttons {"Cancel", "Remove", "Rename"} default button "Rename"`,
		"-e", `(text returned of d) & linefeed & (button returned of d)`,
	).Output()
	if err != nil { // cancelled
		return "", "", false
	}
	text, button, found := strings.Cut(strings.TrimRight(string(out), "\n"), "\n")
	if !found {
		return "", "", false
	}
	return strings.TrimSpace(text), button, true
}

// alertDuplicate tells the user an item with this name already exists.
func alertDuplicate(name string) {
	exec.Command("osascript", "-e",
		`display alert "“`+escapeAppleScript(name)+`” already exists" message "Item names must be unique." as warning`,
	).Run()
}

// confirmEndStreak asks before resetting a streak — a misclick would
// kill the trophy. length is the current streak ("4 months"), or ""
// when it's too young to phrase that way.
func confirmEndStreak(name, length string) bool {
	msg := `End “` + escapeAppleScript(name) + `” streak?`
	if length != "" {
		msg = `End your ` + escapeAppleScript(length) + ` “` + escapeAppleScript(name) + `” streak?`
	}
	err := exec.Command("osascript", "-e",
		`display dialog "`+msg+`" with title "Since" buttons {"Cancel", "End Streak"} default button "Cancel"`,
	).Run()
	return err == nil // cancelled dialogs exit non-zero
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

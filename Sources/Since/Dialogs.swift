import AppKit

/// Which action the edit dialog chose.
enum EditAction {
    case rename
    case remove
}

/// Shows a text-input alert for a new item. The button picks the kind:
/// Chore for things to do again, Streak for things being avoided.
/// Returns nil when cancelled or the input is empty.
func promptForName() -> (name: String, isStreak: Bool)? {
    let alert = NSAlert()
    alert.messageText = "What do you want to track?"
    alert.addButton(withTitle: "Chore")
    alert.addButton(withTitle: "Streak")
    alert.addButton(withTitle: "Cancel")
    let field = textField()
    alert.accessoryView = field
    alert.window.initialFirstResponder = field

    let response = run(alert)
    let name = field.stringValue.trimmingCharacters(in: .whitespaces)
    if name.isEmpty {
        return nil
    }
    switch response {
    case .alertFirstButtonReturn: return (name, false)
    case .alertSecondButtonReturn: return (name, true)
    default: return nil
    }
}

/// Shows one alert for an item: its name in a text field, with Remove and
/// Rename as the actions. Returns nil when cancelled.
func promptForEdit(_ current: String) -> (name: String, action: EditAction)? {
    let alert = NSAlert()
    alert.messageText = "Edit “\(current)”:"
    alert.addButton(withTitle: "Rename")
    alert.addButton(withTitle: "Remove")
    alert.addButton(withTitle: "Cancel")
    let field = textField()
    field.stringValue = current
    alert.accessoryView = field
    alert.window.initialFirstResponder = field

    let response = run(alert)
    let name = field.stringValue.trimmingCharacters(in: .whitespaces)
    switch response {
    case .alertFirstButtonReturn: return (name, .rename)
    case .alertSecondButtonReturn: return (name, .remove)
    default: return nil
    }
}

/// Tells the user an item with this name already exists.
func alertDuplicate(_ name: String) {
    let alert = NSAlert()
    alert.alertStyle = .warning
    alert.messageText = "“\(name)” already exists"
    alert.informativeText = "Item names must be unique."
    _ = run(alert)
}

/// Asks before resetting a streak — a misclick would kill the trophy.
/// length is the current streak ("4 months"), or "" when it's too young
/// to phrase that way. Cancel is the default; true means end it.
func confirmEndStreak(_ name: String, length: String) -> Bool {
    let alert = NSAlert()
    alert.messageText = length.isEmpty
        ? "End “\(name)” streak?"
        : "End your \(length) “\(name)” streak?"
    alert.addButton(withTitle: "Cancel")
    alert.addButton(withTitle: "End Streak")
    return run(alert) == .alertSecondButtonReturn
}

/// Confirm dialog for deletion; Cancel is the default. True means delete it.
func confirmRemove(_ name: String) -> Bool {
    let alert = NSAlert()
    alert.messageText = "Remove “\(name)”?"
    alert.addButton(withTitle: "Cancel")
    alert.addButton(withTitle: "Remove")
    return run(alert) == .alertSecondButtonReturn
}

private func textField() -> NSTextField {
    NSTextField(frame: NSRect(x: 0, y: 0, width: 230, height: 24))
}

/// Brings the app forward (it's an accessory app with no windows) and
/// runs the alert modally.
private func run(_ alert: NSAlert) -> NSApplication.ModalResponse {
    NSApp.activate(ignoringOtherApps: true)
    return alert.runModal()
}

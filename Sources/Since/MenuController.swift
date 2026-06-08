import AppKit

/// Owns the status item and rebuilds its dropdown from items.json every
/// time the menu opens (menuNeedsUpdate), so hand-edits show up without
/// a restart.
final class MenuController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let storage: Storage
    private var lastResetName: String?  // most recent reset, undoable until the next action

    init(storage: Storage = Storage()) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.storage = storage
        super.init()

        statusItem.button?.title = "⧗"
        statusItem.button?.toolTip = "Since"
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    // MARK: - Building

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        var items: [Item] = []
        do {
            items = try storage.load()
        } catch {
            NSLog("loading items: \(error)")
            menu.addItem(NSMenuItem(title: "Couldn't read items.json", action: nil, keyEquivalent: ""))
        }
        let now = Date()
        let (chores, streaks) = displayOrder(items, now: now)

        // One shared column layout for every row, so names/dates/times align
        // and the elapsed times keep a common trailing edge across sections.
        let metrics = ItemRowView.metrics(
            for: (chores + streaks).map { content(for: $0, now: now) })

        for item in chores {
            menu.addItem(row(for: item, now: now, metrics: metrics))
        }
        if !chores.isEmpty && !streaks.isEmpty {
            menu.addItem(.separator())
        }
        for item in streaks {
            menu.addItem(row(for: item, now: now, metrics: metrics))
        }
        if !items.isEmpty {
            menu.addItem(.separator())
        }

        let add = NSMenuItem(title: "Add item…", action: #selector(addClicked), keyEquivalent: "")
        add.target = self
        menu.addItem(add)

        if !items.isEmpty {
            let edit = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
            let submenu = NSMenu()
            for item in chores + streaks {
                let entry = NSMenuItem(title: item.name, action: #selector(editClicked(_:)), keyEquivalent: "")
                entry.target = self
                submenu.addItem(entry)
            }
            edit.submenu = submenu
            menu.addItem(edit)

            let open = NSMenuItem(title: "Open items.json", action: #selector(openClicked), keyEquivalent: "")
            open.target = self
            open.toolTip = "Open items.json in your editor"
            menu.addItem(open)
        }

        if let name = lastResetName {
            let undo = NSMenuItem(title: "Undo reset of \(name)", action: #selector(undoClicked), keyEquivalent: "")
            undo.target = self
            menu.addItem(undo)
        }

        let quit = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        menu.addItem(quit)
    }

    private func row(for item: Item, now: Date, metrics: RowMetrics) -> NSMenuItem {
        let row = NSMenuItem(title: rowLabel(item, now: now), action: #selector(rowClicked(_:)), keyEquivalent: "")
        row.target = self
        row.representedObject = item.name
        row.toolTip = item.isStreak ? "Click to end this streak" : "Click to reset to today"
        row.view = ItemRowView(content: content(for: item, now: now), metrics: metrics)
        return row
    }

    /// Splits the item's labels into the pieces a row draws: name (⚠ when
    /// overdue), demoted date, hero elapsed time, and the dot status.
    private func content(for item: Item, now: Date) -> RowContent {
        let overdue = item.isOverdue(now: now)
        return RowContent(
            name: item.name + (overdue ? " ⚠" : ""),
            date: dateLabel(item.lastDone, now: now),
            time: relative(item.lastDone, now: now),
            status: status(for: item, now: now),
            accessibility: rowLabel(item, now: now))
    }

    // MARK: - Actions

    @objc private func rowClicked(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        guard let items = loadLogged() else { return }
        guard let item = items.first(where: { $0.name == name }) else { return }
        if item.isStreak {
            endStreak(item)
        } else {
            reset(name)
        }
    }

    @objc private func addClicked() {
        guard let (name, isStreak) = promptForName() else { return }
        guard let items = loadLogged() else { return }
        // Names are how reset and remove find items, so duplicates would
        // always hit the first match. Reject instead.
        if items.contains(where: { $0.name == name }) {
            alertDuplicate(name)
            return
        }
        var added = items
        added.append(Item(name: name, lastDone: Date(), kind: isStreak ? "streak" : ""))
        saveLogged(added)
    }

    /// Shows the edit dialog and routes the chosen action: Remove confirms
    /// then deletes; Rename keeps lastDone and history.
    @objc private func editClicked(_ sender: NSMenuItem) {
        let name = sender.title
        guard let (newName, action) = promptForEdit(name) else { return }
        if action == .remove {
            remove(name)
            return
        }
        rename(name, to: newName)
    }

    @objc private func openClicked() {
        // items.json is the only settings surface, so opening it in the
        // default editor is the closest thing to a settings screen.
        NSWorkspace.shared.open(storage.path)
    }

    /// Restores the previous lastDone of the most recent reset.
    @objc private func undoClicked() {
        guard let name = lastResetName else { return }
        lastResetName = nil
        guard var items = loadLogged() else { return }
        if let i = items.firstIndex(where: { $0.name == name && !$0.history.isEmpty }) {
            items[i].lastDone = items[i].history.removeLast()
        }
        saveLogged(items)
    }

    // MARK: - Mutations

    /// Confirms (naming the current streak length), then resets.
    private func endStreak(_ item: Item) {
        let rel = relative(item.lastDone, now: Date())
        let length = rel.hasSuffix(" ago") ? String(rel.dropLast(" ago".count)) : ""  // "4 months ago" → "4 months"
        guard confirmEndStreak(item.name, length: length) else { return }
        reset(item.name)
    }

    /// Sets an item's lastDone to now and writes the file.
    private func reset(_ name: String) {
        guard var items = loadLogged() else { return }
        if let i = items.firstIndex(where: { $0.name == name }) {
            items[i].history.append(items[i].lastDone)
            items[i].lastDone = Date()
        }
        saveLogged(items)
        lastResetName = name
    }

    /// Renames an item, keeping lastDone and history.
    private func rename(_ oldName: String, to newName: String) {
        if newName.isEmpty || newName == oldName { return }
        guard var items = loadLogged() else { return }
        if items.contains(where: { $0.name == newName }) {
            alertDuplicate(newName)
            return
        }
        if let i = items.firstIndex(where: { $0.name == oldName }) {
            items[i].name = newName
        }
        saveLogged(items)
        if lastResetName == oldName {
            lastResetName = newName
        }
    }

    /// Confirms, then deletes the item.
    private func remove(_ name: String) {
        guard confirmRemove(name) else { return }
        guard let items = loadLogged() else { return }
        saveLogged(items.filter { $0.name != name })
    }

    // MARK: - Storage

    private func loadLogged() -> [Item]? {
        do {
            return try storage.load()
        } catch {
            NSLog("loading items: \(error)")
            return nil
        }
    }

    private func saveLogged(_ items: [Item]) {
        do {
            try storage.save(items)
        } catch {
            NSLog("saving items: \(error)")
        }
    }
}

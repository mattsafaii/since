import Foundation

/// Renders one menu row: name, coarse relative, date, and a ⚠ suffix when
/// a chore is past its target interval. Used as the accessibility/tooltip
/// text now that rows render as custom views.
func rowLabel(_ item: Item, now: Date) -> String {
    var label = "\(item.name) — \(sinceLabel(item.lastDone, now: now))"
    if item.isOverdue(now: now) {
        label += " ⚠"
    }
    return label
}

/// The one semantic color channel for a row's status dot. Amber and green
/// are filled; neutral is hollow — filled/hollow is a redundant cue.
enum RowStatus {
    case overdue   // a chore past its target interval — amber, filled
    case record    // a streak longer than any prior — green, filled
    case neutral   // everything else — gray, hollow
}

/// Maps an item to its dot status: overdue chores are amber, record-territory
/// streaks are green, everything else is neutral. Read-only.
func status(for item: Item, now: Date) -> RowStatus {
    if !item.isStreak && item.isOverdue(now: now) {
        return .overdue
    }
    if item.isStreak && item.isRecord(now: now) {
        return .record
    }
    return .neutral
}

/// Splits items into menu sections: chores (overdue before not, longest-since
/// within each) and streaks (longest first, read as records). Display only —
/// items.json keeps its own order.
func displayOrder(_ items: [Item], now: Date) -> (chores: [Item], streaks: [Item]) {
    let chores = stableSorted(items.filter { !$0.isStreak }) { a, b in
        let overdueA = a.isOverdue(now: now)
        let overdueB = b.isOverdue(now: now)
        if overdueA != overdueB {
            return overdueA
        }
        return a.lastDone < b.lastDone
    }
    let streaks = stableSorted(items.filter(\.isStreak)) { $0.lastDone < $1.lastDone }
    return (chores, streaks)
}

/// Sort that keeps file order for equal elements — Swift's sort doesn't
/// document stability, and ties here mean "leave them as the user wrote them".
private func stableSorted(_ items: [Item], by areInIncreasingOrder: (Item, Item) -> Bool) -> [Item] {
    items.enumerated()
        .sorted { a, b in
            if areInIncreasingOrder(a.element, b.element) { return true }
            if areInIncreasingOrder(b.element, a.element) { return false }
            return a.offset < b.offset
        }
        .map(\.element)
}

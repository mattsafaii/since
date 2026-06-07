import Foundation

/// Renders one menu row: name, coarse relative, date, and a ⚠ suffix when
/// a chore is past its target interval.
func rowLabel(_ item: Item, now: Date) -> String {
    var label = "\(item.name) — \(sinceLabel(item.lastDone, now: now))"
    if item.isOverdue(now: now) {
        label += " ⚠"
    }
    return label
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

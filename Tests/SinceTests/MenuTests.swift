import XCTest
@testable import Since

final class MenuTests: XCTestCase {
    func testDisplayOrder() {
        let now = date(2026, 6, 6, hour: 12)
        let items = [
            Item(name: "Fresh chore", lastDone: daysAgo(1, from: now), every: "6w"),
            Item(name: "Young streak", lastDone: daysAgo(3, from: now), kind: "streak"),
            Item(name: "Overdue chore", lastDone: daysAgo(50, from: now), every: "6w"),
            Item(name: "Old streak", lastDone: monthsAgo(4, from: now), kind: "streak"),
            Item(name: "Very overdue chore", lastDone: daysAgo(90, from: now), every: "6w"),
            Item(name: "No-target chore", lastDone: daysAgo(200, from: now)),
        ]

        let (chores, streaks) = displayOrder(items, now: now)

        XCTAssertEqual(chores.map(\.name),
                       ["Very overdue chore", "Overdue chore", "No-target chore", "Fresh chore"])
        XCTAssertEqual(streaks.map(\.name), ["Old streak", "Young streak"])
    }

    func testRowLabel() {
        let now = date(2026, 6, 6, hour: 12)
        let tests: [(name: String, item: Item, want: String)] = [
            ("chore within target",
             Item(name: "Haircut", lastDone: daysAgo(21, from: now), every: "6w"),
             "Haircut — 3 weeks ago (May 16)"),
            ("overdue chore gets warning",
             Item(name: "Haircut", lastDone: daysAgo(50, from: now), every: "6w"),
             "Haircut — 1 month ago (Apr 17) ⚠"),
            ("streak never gets warning",
             Item(name: "Alcohol", lastDone: daysAgo(50, from: now), kind: "streak", every: "1d"),
             "Alcohol — 1 month ago (Apr 17)"),
        ]
        for tt in tests {
            XCTAssertEqual(rowLabel(tt.item, now: now), tt.want, tt.name)
        }
    }
}

/// The same wall-clock moment n calendar months before `from` (Go's AddDate).
func monthsAgo(_ n: Int, from: Date) -> Date {
    Calendar.current.date(byAdding: .month, value: -n, to: from)!
}

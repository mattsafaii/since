import XCTest
@testable import Since

final class ItemTests: XCTestCase {
    func testIsRecord() {
        let now = date(2026, 6, 6, hour: 12)
        let tests: [(name: String, item: Item, want: Bool)] = [
            ("empty history is never a record",
             Item(name: "Streak", lastDone: daysAgo(200, from: now), kind: "streak"),
             false),
            ("current interval beats every prior gap",
             Item(name: "Streak",
                  lastDone: daysAgo(60, from: now),
                  history: [daysAgo(100, from: now), daysAgo(80, from: now)],
                  kind: "streak"),
             true),  // prior gaps 20d + 20d; current 60d
            ("current interval shorter than longest prior gap",
             Item(name: "Streak",
                  lastDone: daysAgo(40, from: now),
                  history: [daysAgo(100, from: now)],
                  kind: "streak"),
             false),  // prior gap 60d; current 40d
            ("ties don't count — must exceed",
             Item(name: "Streak",
                  lastDone: daysAgo(30, from: now),
                  history: [daysAgo(60, from: now)],
                  kind: "streak"),
             false),  // prior gap 30d; current 30d
        ]
        for tt in tests {
            XCTAssertEqual(tt.item.isRecord(now: now), tt.want, tt.name)
        }
    }
}

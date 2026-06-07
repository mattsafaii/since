import XCTest
@testable import Since

/// Midnight local time on the given date, plus an optional hour.
func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    return Calendar.current.date(from: components)!
}

/// The same wall-clock moment n calendar days before `from` (Go's AddDate).
func daysAgo(_ n: Int, from: Date) -> Date {
    Calendar.current.date(byAdding: .day, value: -n, to: from)!
}

final class LabelsTests: XCTestCase {
    func testRelative() {
        let now = date(2026, 6, 6, hour: 12)
        let tests: [(name: String, lastDone: Date, want: String)] = [
            ("same moment", now, "today"),
            ("earlier today", now.addingTimeInterval(-2 * 3600), "today"),
            ("yesterday", date(2026, 6, 5), "yesterday"),
            ("two days", date(2026, 6, 4), "2 days ago"),
            ("six days", date(2026, 5, 31), "6 days ago"),
            ("seven days is a week", date(2026, 5, 30), "1 week ago"),
            ("thirteen days is one week", date(2026, 5, 24), "1 week ago"),
            ("two weeks", date(2026, 5, 23), "2 weeks ago"),
            ("29 days is four weeks", daysAgo(29, from: now), "4 weeks ago"),
            ("30 days is a month", daysAgo(30, from: now), "1 month ago"),
            ("60 days is two months", daysAgo(60, from: now), "2 months ago"),
            ("364 days is twelve months", daysAgo(364, from: now), "12 months ago"),
            ("365 days is a year", daysAgo(365, from: now), "1 year ago"),
            ("729 days is one year", daysAgo(729, from: now), "1 year ago"),
            ("730 days is two years", daysAgo(730, from: now), "2 years ago"),
        ]
        for tt in tests {
            XCTAssertEqual(relative(tt.lastDone, now: now), tt.want, tt.name)
        }
    }

    func testDaysBetweenCountsCalendarDays() {
        // 11pm yesterday → 1am today is 2 hours but one calendar day.
        let a = date(2026, 6, 5, hour: 23)
        let b = date(2026, 6, 6, hour: 1)
        XCTAssertEqual(daysBetween(a, b), 1)
        XCTAssertEqual(relative(a, now: b), "yesterday")
    }

    func testSinceLabel() {
        let now = date(2026, 6, 6)
        let tests: [(name: String, lastDone: Date, want: String)] = [
            ("same year omits year", date(2026, 5, 12), "3 weeks ago (May 12)"),
            ("other year includes year", date(2025, 2, 1), "1 year ago (Feb 1, 2025)"),
            ("recent but last year includes year", date(2025, 12, 30), "5 months ago (Dec 30, 2025)"),
        ]
        for tt in tests {
            XCTAssertEqual(sinceLabel(tt.lastDone, now: now), tt.want, tt.name)
        }
    }
}

import XCTest
@testable import Since

/// Round-trip parity against Fixtures/go-items.json — a file written by the
/// Go app's json.MarshalIndent (mixed fractional-second precision, mixed
/// PST/PDT offsets). The expected labels and order below are the Go app's
/// actual output for this file at noon local on 2026-06-07, captured with a
/// one-off Go test before the cutover.
final class GoParityTests: XCTestCase {
    private var fixture: URL {
        Bundle.module.url(forResource: "go-items", withExtension: "json", subdirectory: "Fixtures")!
    }

    private func loadFixture() throws -> (storage: Storage, items: [Item]) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("since-parity-\(UUID().uuidString)")
        let path = dir.appendingPathComponent("items.json")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: fixture, to: path)
        let storage = Storage(path: path)
        return (storage, try storage.load())
    }

    func testGoFileLoads() throws {
        let (_, items) = try loadFixture()
        XCTAssertEqual(items.map(\.name), ["Haircut", "Brita filter", "Dentist", "Alcohol"])
        XCTAssertEqual(items.map(\.kind), ["", "", "", "streak"])
        XCTAssertEqual(items.map(\.every), ["6w", "2m", "", ""])
        XCTAssertEqual(items.map(\.history.count), [1, 0, 0, 2])
    }

    func testLabelsMatchGoApp() throws {
        let (_, items) = try loadFixture()
        let now = date(2026, 6, 7, hour: 12)
        let want = [
            "Haircut — 1 month ago (Apr 25) ⚠",
            "Brita filter — 2 weeks ago (May 20)",
            "Dentist — 1 year ago (Nov 12, 2024)",
            "Alcohol — 4 months ago (Feb 1)",
        ]
        XCTAssertEqual(items.map { rowLabel($0, now: now) }, want)
    }

    func testDisplayOrderMatchesGoApp() throws {
        let (_, items) = try loadFixture()
        let now = date(2026, 6, 7, hour: 12)
        let (chores, streaks) = displayOrder(items, now: now)
        XCTAssertEqual((chores + streaks).map(\.name),
                       ["Haircut", "Dentist", "Brita filter", "Alcohol"])
    }

    func testSaveLoadRoundTripOnGoFile() throws {
        let (storage, first) = try loadFixture()
        try storage.save(first)
        let second = try storage.load()

        XCTAssertEqual(second.map(\.name), first.map(\.name))
        XCTAssertEqual(second.map(\.kind), first.map(\.kind))
        XCTAssertEqual(second.map(\.every), first.map(\.every))
        for (a, b) in zip(first, second) {
            XCTAssertEqual(a.lastDone.timeIntervalSince1970,
                           b.lastDone.timeIntervalSince1970, accuracy: 0.001, a.name)
            XCTAssertEqual(a.history.count, b.history.count, a.name)
            for (ha, hb) in zip(a.history, b.history) {
                XCTAssertEqual(ha.timeIntervalSince1970, hb.timeIntervalSince1970,
                               accuracy: 0.001, a.name)
            }
        }
        // A second write must be byte-identical — the file shouldn't churn.
        XCTAssertEqual(Storage.serialize(first), Storage.serialize(second))
    }
}

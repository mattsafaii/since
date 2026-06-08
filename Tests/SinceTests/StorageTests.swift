import XCTest
@testable import Since

final class StorageTests: XCTestCase {
    /// A Storage pointed at a fresh temp directory.
    private func tempStorage() -> Storage {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("since-tests-\(UUID().uuidString)")
        return Storage(path: dir.appendingPathComponent(".config/since/items.json"))
    }

    func testTargetDays() {
        let tests: [(name: String, item: Item, want: Int?)] = [
            ("days", Item(name: "", lastDone: Date(), every: "2d"), 2),
            ("weeks", Item(name: "", lastDone: Date(), every: "6w"), 42),
            ("months", Item(name: "", lastDone: Date(), every: "3m"), 90),
            ("absent", Item(name: "", lastDone: Date()), nil),
            ("bad unit", Item(name: "", lastDone: Date(), every: "2x"), nil),
            ("zero", Item(name: "", lastDone: Date(), every: "0d"), nil),
            ("negative", Item(name: "", lastDone: Date(), every: "-1d"), nil),
            ("no number", Item(name: "", lastDone: Date(), every: "w"), nil),
            ("not a number", Item(name: "", lastDone: Date(), every: "ad"), nil),
            ("streaks have no target", Item(name: "", lastDone: Date(), kind: "streak", every: "6w"), nil),
        ]
        for tt in tests {
            XCTAssertEqual(tt.item.targetDays, tt.want, tt.name)
        }
    }

    func testOverdue() {
        let now = date(2026, 6, 6, hour: 12)
        let tests: [(name: String, item: Item, want: Bool)] = [
            ("past target", Item(name: "", lastDone: daysAgo(43, from: now), every: "6w"), true),
            ("at target", Item(name: "", lastDone: daysAgo(42, from: now), every: "6w"), false),
            ("no target", Item(name: "", lastDone: daysAgo(100, from: now)), false),
            ("unparseable target", Item(name: "", lastDone: daysAgo(100, from: now), every: "2x"), false),
            ("streaks never overdue", Item(name: "", lastDone: daysAgo(100, from: now), kind: "streak", every: "1d"), false),
        ]
        for tt in tests {
            XCTAssertEqual(tt.item.isOverdue(now: now), tt.want, tt.name)
        }
    }

    func testSaveLoadRoundTrip() throws {
        let storage = tempStorage()
        let now = Date(timeIntervalSince1970: Date().timeIntervalSince1970.rounded())
        let want = [
            Item(name: "Haircut", lastDone: now, every: "6w"),
            Item(name: "Alcohol", lastDone: daysAgo(30, from: now),
                 history: [daysAgo(90, from: now)], kind: "streak"),
        ]
        try storage.save(want)
        let got = try storage.load()
        XCTAssertEqual(got, want)
    }

    // Opening the menu loads items.json and must never rewrite it — a glance
    // shouldn't reformat or reorder a hand-edited file. Loading an existing
    // file leaves its bytes untouched.
    func testLoadLeavesExistingFileUnchanged() throws {
        let storage = tempStorage()
        let original = """
        [
          {"name": "Haircut", "lastDone": "2026-05-12T10:00:00-07:00", "history": ["2026-03-01T09:00:00-07:00"], "kind": "streak", "every": "6w"}
        ]
        """
        try FileManager.default.createDirectory(
            at: storage.path.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(original.utf8).write(to: storage.path)

        _ = try storage.load()

        let after = try String(contentsOf: storage.path, encoding: .utf8)
        XCTAssertEqual(after, original, "load rewrote items.json")
    }

    func testLoadCreatesFileOnFirstRun() throws {
        let storage = tempStorage()
        let items = try storage.load()
        XCTAssertEqual(items.count, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: storage.path.path),
                      "items.json not created on first run")
    }

    // v1 files have only name, lastDone, and history. They must load as
    // chores with no target — and unknown kinds must not break anything.
    func testV1FileTolerance() throws {
        let storage = tempStorage()
        let v1 = """
        [
          {"name": "Haircut", "lastDone": "2026-05-12T10:00:00-07:00"},
          {"name": "Mystery", "lastDone": "2026-05-12T10:00:00-07:00", "kind": "habit", "every": "soon"}
        ]
        """
        try FileManager.default.createDirectory(
            at: storage.path.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(v1.utf8).write(to: storage.path)

        let items = try storage.load()
        XCTAssertEqual(items.count, 2)
        let now = date(2026, 6, 6, hour: 12)
        for it in items {
            XCTAssertFalse(it.isStreak, "\(it.name) treated as streak")
            XCTAssertNil(it.targetDays, "\(it.name) has a target interval")
            XCTAssertFalse(it.isOverdue(now: now), "\(it.name) overdue without a valid target")
        }
    }

    // The Go app wrote fractional seconds (time.Now() has nanoseconds);
    // hand-edits tend to be plain. Both must decode.
    func testParsesGoWrittenDates() {
        XCTAssertNotNil(Storage.parseDate("2026-06-06T23:21:53.871731-07:00"), "Go fractional")
        XCTAssertNotNil(Storage.parseDate("2026-06-06T23:21:53-07:00"), "plain seconds")
        XCTAssertNotNil(Storage.parseDate("2026-06-06T23:21:53.871Z"), "UTC fractional")
        XCTAssertNil(Storage.parseDate("yesterday-ish"), "garbage")
    }

    // Optional fields must be omitted from the file when empty — hand-editors
    // shouldn't see "history": null or "kind": "" noise.
    func testOptionalFieldsOmittedWhenEmpty() {
        let data = Storage.serialize([Item(name: "Haircut", lastDone: Date())])
        let text = String(decoding: data, as: UTF8.self)
        for field in ["\"history\"", "\"kind\"", "\"every\""] {
            XCTAssertFalse(text.contains(field), "empty \(field) serialized: \(text)")
        }
    }

    func testSerializeEmptyListIsEmptyArray() {
        XCTAssertEqual(String(decoding: Storage.serialize([]), as: UTF8.self), "[]")
    }
}

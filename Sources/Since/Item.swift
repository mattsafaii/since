import Foundation

/// One tracked thing: its name and when it was last done.
/// History holds prior lastDone values, oldest first — appended on every
/// reset so undo (and any future stats) have data to work with.
///
/// Kind and every are optional; v1 files omit both. Unknown kinds and
/// unparseable intervals are treated as absent so a hand-edit typo never
/// breaks the app.
struct Item: Equatable {
    var name: String
    var lastDone: Date
    var history: [Date] = []
    var kind: String = ""  // "streak" = avoiding it, longer is better; else chore
    var every: String = ""  // chore target interval, e.g. "6w" (d/w/m)

    /// Whether this item tracks something being avoided.
    var isStreak: Bool {
        kind == "streak"
    }

    /// The chore's target interval in days, or nil for streaks and for
    /// absent or unparseable every values.
    var targetDays: Int? {
        if isStreak || every.count < 2 {
            return nil
        }
        guard let n = Int(every.dropLast()), n > 0 else {
            return nil
        }
        switch every.last {
        case "d": return n
        case "w": return n * 7
        case "m": return n * 30
        default: return nil
        }
    }

    /// Whether a chore is past its target interval. Streaks are never overdue.
    func isOverdue(now: Date) -> Bool {
        guard let days = targetDays else { return false }
        return daysBetween(lastDone, now) > days
    }

    /// Whether the current ongoing interval (now − lastDone) is longer than
    /// every prior interval — i.e. this streak is in record territory.
    /// Read-only: reconstructed live from history, nothing is written.
    ///
    /// The done-markers in time order are history (oldest first) followed by
    /// lastDone; the gaps between consecutive markers are the prior intervals.
    /// With empty history there are no prior intervals, so a streak in its
    /// first-ever interval is never a record.
    func isRecord(now: Date) -> Bool {
        guard !history.isEmpty else { return false }
        let markers = history + [lastDone]
        var longestPrior: TimeInterval = 0
        for i in 1..<markers.count {
            longestPrior = max(longestPrior, markers[i].timeIntervalSince(markers[i - 1]))
        }
        return now.timeIntervalSince(lastDone) > longestPrior
    }
}

// Writing goes through Storage.serialize, which omits empty optionals the
// way Go's omitempty did — so Item only needs to decode.
extension Item: Decodable {
    enum CodingKeys: String, CodingKey {
        case name, lastDone, history, kind, every
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        lastDone = try c.decode(Date.self, forKey: .lastDone)
        history = try c.decodeIfPresent([Date].self, forKey: .history) ?? []
        kind = try c.decodeIfPresent(String.self, forKey: .kind) ?? ""
        every = try c.decodeIfPresent(String.self, forKey: .every) ?? ""
    }
}

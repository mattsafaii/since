import Foundation

/// Reads and writes items.json. The default path is ~/.config/since/items.json;
/// tests inject a temp path instead.
struct Storage {
    let path: URL

    init(path: URL = Storage.defaultPath()) {
        self.path = path
    }

    static func defaultPath() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/since/items.json")
    }

    /// Loads items.json, creating an empty file on first run.
    func load() throws -> [Item] {
        let data: Data
        do {
            data = try Data(contentsOf: path)
        } catch let error as NSError
            where error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError {
            try save([])
            return []
        }
        return try Storage.decoder.decode([Item].self, from: data)
    }

    /// Writes items.json, creating the directory if needed.
    func save(_ items: [Item]) throws {
        try FileManager.default.createDirectory(
            at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
        // Atomic write (temp + rename) so a crash mid-write can't corrupt
        // items.json — it's the single source of truth.
        try Storage.serialize(items).write(to: path, options: .atomic)
    }

    // MARK: - Writing

    /// Renders items the way Go's json.MarshalIndent did: two-space indent,
    /// fields in declaration order, empty optionals omitted. The file is the
    /// settings surface, so its shape is part of the contract.
    static func serialize(_ items: [Item]) -> Data {
        if items.isEmpty {
            return Data("[]".utf8)
        }
        var out = "[\n"
        out += items.map { item in
            var fields = [
                "    \"name\": \(jsonString(item.name))",
                "    \"lastDone\": \(jsonString(dateString(item.lastDone)))",
            ]
            if !item.history.isEmpty {
                let dates = item.history
                    .map { "      \(jsonString(dateString($0)))" }
                    .joined(separator: ",\n")
                fields.append("    \"history\": [\n\(dates)\n    ]")
            }
            if !item.kind.isEmpty {
                fields.append("    \"kind\": \(jsonString(item.kind))")
            }
            if !item.every.isEmpty {
                fields.append("    \"every\": \(jsonString(item.every))")
            }
            return "  {\n" + fields.joined(separator: ",\n") + "\n  }"
        }.joined(separator: ",\n")
        out += "\n]"
        return Data(out.utf8)
    }

    private static func jsonString(_ s: String) -> String {
        var out = "\""
        for scalar in s.unicodeScalars {
            switch scalar {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            default:
                if scalar.value < 0x20 {
                    out += String(format: "\\u%04x", scalar.value)
                } else {
                    out.unicodeScalars.append(scalar)
                }
            }
        }
        return out + "\""
    }

    // MARK: - Dates

    // The Go app wrote RFC 3339 with fractional seconds and a local UTC
    // offset; decode both fractional and plain, and keep writing the same
    // shape so the file stays familiar across the rewrite.
    private static let fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let localFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        f.timeZone = TimeZone.current
        return f
    }()

    static func parseDate(_ s: String) -> Date? {
        fractional.date(from: s) ?? plain.date(from: s)
    }

    static func dateString(_ date: Date) -> String {
        localFractional.string(from: date)
    }

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let s = try decoder.singleValueContainer().decode(String.self)
            guard let date = parseDate(s) else {
                throw DecodingError.dataCorrupted(DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "unparseable date: \(s)"))
            }
            return date
        }
        return d
    }()
}

import Foundation

public enum DayFormat {
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let timestampFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.timeZone = .current
        return f
    }()

    public static func day(_ date: Date) -> String { dayFormatter.string(from: date) }
    public static func timestamp(_ date: Date) -> String { timestampFormatter.string(from: date) }
    public static func parseTimestamp(_ string: String) -> Date? { timestampFormatter.date(from: string) }
}

/// CSV file with one row per day: `date,status,source,updated_at,note`.
/// The file is re-read on every access, so manual edits are picked up.
public struct CSVStore {
    static let header = "date,status,source,updated_at,note"

    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    public func load() throws -> [DayRecord] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        return try String(contentsOf: url, encoding: .utf8)
            .split(whereSeparator: \.isNewline)
            .dropFirst()
            .compactMap(Self.parse)
    }

    public func record(for date: String) throws -> DayRecord? {
        try load().first { $0.date == date }
    }

    public func upsert(_ record: DayRecord) throws {
        var records = try load().filter { $0.date != record.date }
        records.append(record)
        try save(records)
    }

    private func save(_ records: [DayRecord]) throws {
        let rows = records.sorted { $0.date < $1.date }.map(Self.format)
        let text = ([Self.header] + rows).joined(separator: "\n") + "\n"
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        // Atomic so a reader (Numbers, Excel) never sees a half-written file.
        try Data(text.utf8).write(to: url, options: .atomic)
    }

    /// Accepts rows written before the note column existed (4 fields).
    private static func parse(_ line: Substring) -> DayRecord? {
        let fields = fields(line)
        guard fields.count == 4 || fields.count == 5,
              let status = Workplace(rawValue: fields[1]),
              let source = Source(rawValue: fields[2]),
              let updatedAt = DayFormat.parseTimestamp(fields[3])
        else { return nil }
        return DayRecord(date: fields[0], status: status, source: source, note: fields.count == 5 ? fields[4] : "", updatedAt: updatedAt)
    }

    private static func format(_ r: DayRecord) -> String {
        [r.date, r.status.rawValue, r.source.rawValue, DayFormat.timestamp(r.updatedAt), r.note]
            .map(escape)
            .joined(separator: ",")
    }

    /// RFC 4180 quoting. Rows stay on one line, so newlines become spaces.
    private static func escape(_ field: String) -> String {
        let field = field.replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
        guard field.contains(where: { $0 == "," || $0 == "\"" }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    private static func fields(_ line: Substring) -> [String] {
        var fields: [String] = []
        var field = ""
        var inQuotes = false
        var i = line.startIndex
        while i < line.endIndex {
            let c = line[i]
            let next = line.index(after: i)
            if c == "\"" {
                if inQuotes, next < line.endIndex, line[next] == "\"" {
                    field.append(c)
                    i = next
                } else {
                    inQuotes.toggle()
                }
            } else if c == ",", !inQuotes {
                fields.append(field)
                field = ""
            } else {
                field.append(c)
            }
            i = line.index(after: i)
        }
        fields.append(field)
        return fields
    }
}

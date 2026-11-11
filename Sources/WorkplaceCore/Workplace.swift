import Foundation

public enum Workplace: String, CaseIterable {
    case office, home
}

public enum Source: String {
    case auto, manual
}

/// One CSV row: where I worked on a given (local) day.
public struct DayRecord: Equatable {
    public var date: String
    public var status: Workplace
    public var source: Source
    public var note: String
    public var updatedAt: Date

    public init(date: String, status: Workplace, source: Source, note: String = "", updatedAt: Date) {
        self.date = date
        self.status = status
        self.source = source
        self.note = note
        self.updatedAt = updatedAt
    }

    public init(status: Workplace, source: Source, note: String = "", at now: Date) {
        self.init(date: DayFormat.day(now), status: status, source: source, note: note, updatedAt: now)
    }
}

public enum Resolver {
    /// The workplace implied by the current Wi-Fi, nil when not connected.
    public static func detect(ssid: String?, officeSSID: String) -> Workplace? {
        ssid.map { $0 == officeSSID ? .office : .home }
    }

    /// Returns the record to save for today, or nil when today's record should stay as it is.
    ///
    /// - A manual override is never replaced.
    /// - Nothing detected (no Wi-Fi) means nothing is recorded.
    /// - Office wins: once the office network is seen, the day stays `office`.
    /// - The note is always kept.
    public static func resolve(current: DayRecord?, detected: Workplace?, now: Date) -> DayRecord? {
        guard current?.source != .manual, let detected else { return nil }
        if let current, current.status == .office || current.status == detected { return nil }
        return DayRecord(status: detected, source: .auto, note: current?.note ?? "", at: now)
    }
}

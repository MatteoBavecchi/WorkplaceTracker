import Foundation

/// How the monthly office target is going.
public enum Pace: Equatable {
    case onTrack
    /// At most one home day to spare.
    case tight
    /// Not enough workdays left to reach the target.
    case behind
    case done
}

/// A weekday cell in the month grid.
public struct CalendarDay: Equatable {
    public let day: Int
    public let status: Workplace?
    public let isToday: Bool
    public let isFuture: Bool
}

/// Office days this month against the target, plus the Mon–Fri grid of the month.
public struct MonthSummary: Equatable {
    public let target: Int
    public let done: Int
    /// Weekdays after today until the end of the month.
    public let workdaysLeft: Int
    /// Mon–Fri rows; nil for days outside the month.
    public let weeks: [[CalendarDay?]]

    public var remaining: Int { max(target - done, 0) }

    public var pace: Pace {
        let spare = workdaysLeft - remaining
        if remaining == 0 { return .done }
        if spare < 0 { return .behind }
        return spare <= 1 ? .tight : .onTrack
    }

    public init(records: [DayRecord], target: Int, now: Date, calendar: Calendar = .current) {
        let today = DayFormat.day(now)
        let statusByDate = Dictionary(records.map { ($0.date, $0.status) }, uniquingKeysWith: { first, _ in first })
        let month = calendar.dateInterval(of: .month, for: now)!

        var weeks: [[CalendarDay?]] = []
        var date = month.start
        while date < month.end {
            // Calendar weekdays: 1 = Sunday … 7 = Saturday.
            let weekday = calendar.component(.weekday, from: date)
            if (2...6).contains(weekday) {
                if weeks.isEmpty || weekday == 2 { weeks.append(Array(repeating: nil, count: 5)) }
                let key = DayFormat.day(date)
                weeks[weeks.count - 1][weekday - 2] = CalendarDay(
                    day: calendar.component(.day, from: date),
                    status: statusByDate[key],
                    isToday: key == today,
                    isFuture: key > today
                )
            }
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }

        let monthPrefix = today.prefix(7)
        self.target = target
        self.done = records.filter { $0.status == .office && $0.date.hasPrefix(monthPrefix) }.count
        self.workdaysLeft = weeks.joined().compactMap { $0 }.filter(\.isFuture).count
        self.weeks = weeks
    }
}

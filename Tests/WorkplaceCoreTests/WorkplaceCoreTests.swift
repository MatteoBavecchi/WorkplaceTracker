import Foundation
import Testing
@testable import WorkplaceCore

private let now = Date()

private func resolve(_ current: DayRecord?, _ detected: Workplace?) -> DayRecord? {
    Resolver.resolve(current: current, detected: detected, now: now)
}

@Suite struct ResolverTests {
    @Test func detectsOfficeAndHome() {
        #expect(Resolver.detect(ssid: "Office-WiFi", officeSSID: "Office-WiFi") == .office)
        #expect(Resolver.detect(ssid: "Home-5G", officeSSID: "Office-WiFi") == .home)
        #expect(Resolver.detect(ssid: nil, officeSSID: "Office-WiFi") == nil)
    }

    @Test func newDayIsRecorded() {
        #expect(resolve(nil, .office)?.status == .office)
        #expect(resolve(nil, .home)?.status == .home)
    }

    @Test func noWiFiRecordsNothing() {
        #expect(resolve(nil, nil) == nil)
    }

    @Test func officeWinsForTheDay() {
        let atOffice = DayRecord(status: .office, source: .auto, at: now)
        #expect(resolve(atOffice, .home) == nil)
    }

    @Test func homeUpgradesToOffice() {
        let atHome = DayRecord(status: .home, source: .auto, at: now)
        #expect(resolve(atHome, .office)?.status == .office)
    }

    @Test func unchangedStatusIsNotRewritten() {
        let atHome = DayRecord(status: .home, source: .auto, at: now)
        #expect(resolve(atHome, .home) == nil)
    }

    @Test func manualOverrideIsKept() {
        let manual = DayRecord(status: .home, source: .manual, at: now)
        #expect(resolve(manual, .office) == nil)
    }

    @Test func noteSurvivesStatusChange() {
        let atHome = DayRecord(status: .home, source: .auto, note: "dentist", at: now)
        #expect(resolve(atHome, .office)?.note == "dentist")
    }

    @Test func newDayStartsWithEmptyNote() {
        #expect(resolve(nil, .office)?.note == "")
    }
}

@Suite struct CSVStoreTests {
    private let store = CSVStore(url: FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathComponent("workplace.csv"))

    // Timestamps are stored with second precision.
    private let date = Date(timeIntervalSince1970: 1_762_850_000)

    @Test func missingFileIsEmpty() throws {
        #expect(try store.load().isEmpty)
    }

    @Test func upsertReplacesTheSameDay() throws {
        try store.upsert(DayRecord(date: "2026-11-11", status: .home, source: .auto, updatedAt: date))
        try store.upsert(DayRecord(date: "2026-11-10", status: .office, source: .auto, updatedAt: date))
        try store.upsert(DayRecord(date: "2026-11-11", status: .office, source: .manual, updatedAt: date))

        let records = try store.load()
        #expect(records.map(\.date) == ["2026-11-10", "2026-11-11"])
        #expect(records.last == DayRecord(date: "2026-11-11", status: .office, source: .manual, updatedAt: date))
        #expect(try String(contentsOf: store.url, encoding: .utf8).hasPrefix(CSVStore.header + "\n"))
    }

    @Test func notesWithCommasAndQuotesRoundTrip() throws {
        let record = DayRecord(date: "2026-11-11", status: .home, source: .manual,
                               note: #"call with "ACME", then gym"#, updatedAt: date)
        try store.upsert(record)
        #expect(try store.load() == [record])
    }

    @Test func newlinesInNotesBecomeSpaces() throws {
        try store.upsert(DayRecord(date: "2026-11-11", status: .home, source: .auto, note: "a\nb", updatedAt: date))
        #expect(try store.load().first?.note == "a b")
    }

    @Test func readsRowsWithoutNoteColumn() throws {
        try FileManager.default.createDirectory(at: store.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let legacy = "date,status,source,updated_at\n2026-11-11,office,auto,\(DayFormat.timestamp(date))\n"
        try Data(legacy.utf8).write(to: store.url)

        let record = try #require(try store.load().first)
        #expect(record.status == .office)
        #expect(record.note == "")
    }
}

@Suite struct ConfigTests {
    @Test func missingKeysUseDefaults() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).json")
        try Data(#"{"csvPath": "/tmp/x.csv"}"#.utf8).write(to: url)
        let config = Config.load(from: url)
        #expect(config.officeSSID == nil)
        #expect(config.monthlyTarget == 12)
        #expect(config.csvURL.path == "/tmp/x.csv")
    }
}

@Suite struct MonthSummaryTests {
    /// November 2026 starts on a Sunday and has 21 weekdays.
    private func date(_ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: day, hour: 12))!
    }

    private func records(_ office: [Int], home: [Int] = []) -> [DayRecord] {
        office.map { DayRecord(status: .office, source: .auto, at: date($0)) }
            + home.map { DayRecord(status: .home, source: .auto, at: date($0)) }
    }

    private func summary(_ records: [DayRecord], today: Int) -> MonthSummary {
        MonthSummary(records: records, target: 12, now: date(today))
    }

    @Test func gridHasWeekdaysOnly() {
        let weeks = summary([], today: 18).weeks
        #expect(weeks.count == 5)
        #expect(weeks[0].map { $0?.day } == [2, 3, 4, 5, 6])
        #expect(weeks[4].map { $0?.day } == [30, nil, nil, nil, nil])
    }

    @Test func countsOfficeDaysAndWorkdaysAfterToday() {
        // A fully remote second week, back at the office on Wednesday the 18th.
        let month = summary(records([2, 4, 5, 16, 18], home: [3, 6, 9, 10, 11, 12, 13, 17]), today: 18)
        #expect(month.done == 5)
        #expect(month.remaining == 7)
        #expect(month.workdaysLeft == 8)
        #expect(month.pace == .tight)
        #expect(month.weeks[2][2] == CalendarDay(day: 18, status: .office, isToday: true, isFuture: false))
    }

    @Test func paceFollowsSpareHomeDays() {
        #expect(summary(records([2, 3, 4]), today: 6).pace == .onTrack)
        #expect(summary(records([2]), today: 20).pace == .behind)
        #expect(summary(records(Array(2...13)), today: 13).pace == .done)
    }

    @Test func ignoresOtherMonths() {
        let october = DayRecord(date: "2026-10-30", status: .office, source: .auto, updatedAt: date(1))
        #expect(summary([october], today: 18).done == 0)
    }
}

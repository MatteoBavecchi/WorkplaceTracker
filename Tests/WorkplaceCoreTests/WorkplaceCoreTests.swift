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

        let record = try #require(try store.record(for: "2026-11-11"))
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
        #expect(config.csvURL.path == "/tmp/x.csv")
    }
}

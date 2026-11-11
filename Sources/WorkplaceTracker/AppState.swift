import AppKit
import ServiceManagement
import WorkplaceCore

@MainActor
final class AppState: ObservableObject {
    /// Every CSV row; today and the month summary are derived from it.
    @Published private(set) var records: [DayRecord] = []
    @Published private(set) var error: String?
    @Published private(set) var needsLocation = false
    @Published private(set) var launchAtLogin = SMAppService.mainApp.status == .enabled

    let config = Config.load()
    private let store: CSVStore
    private var monitor: WiFiMonitor!
    private var timer: Timer?

    init() {
        store = CSVStore(url: config.csvURL)
        monitor = WiFiMonitor { [weak self] in self?.refresh() }
        monitor.requestAuthorization()

        // Safety net for missed Wi-Fi events, sleep/wake and day rollover.
        timer = Timer.scheduledTimer(withTimeInterval: 15 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        refresh()
    }

    var today: DayRecord? {
        let date = DayFormat.day(Date())
        return records.first { $0.date == date }
    }

    var month: MonthSummary {
        MonthSummary(records: records, target: config.monthlyTarget, now: Date())
    }

    /// The manual choice for today, nil when detection is automatic.
    var override: Workplace? {
        today?.source == .manual ? today?.status : nil
    }

    /// Nil when not on Wi-Fi or when no office SSID is configured.
    private var detected: Workplace? {
        config.officeSSID.flatMap { Resolver.detect(ssid: monitor.ssid, officeSSID: $0) }
    }

    func refresh() {
        attempt {
            records = try store.load()
            if let updated = Resolver.resolve(current: today, detected: detected, now: Date()) {
                records = try store.upsert(updated)
            }
        }
        needsLocation = !monitor.isAuthorized
        if config.officeSSID == nil {
            error = "Set officeSSID in \(Config.fileURL.displayPath)"
        }
    }

    /// Pass nil to go back to automatic detection; without Wi-Fi the current status is kept.
    func setOverride(_ manual: Workplace?) {
        save(status: manual ?? detected ?? today?.status, source: manual == nil ? .auto : .manual, note: today?.note ?? "")
    }

    func setNote(_ note: String) {
        let note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let today, note != today.note else { return }
        save(status: today.status, source: today.source, note: note)
    }

    private func save(status: Workplace?, source: Source, note: String) {
        guard let status else { return }
        attempt { records = try store.upsert(DayRecord(status: status, source: source, note: note, at: Date())) }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        attempt {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    private func attempt(_ body: () throws -> Void) {
        do {
            try body()
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}

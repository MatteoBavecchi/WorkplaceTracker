import AppKit
import ServiceManagement
import WorkplaceCore

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var today: DayRecord?
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
            let now = Date()
            today = try store.record(for: DayFormat.day(now))
            if let updated = Resolver.resolve(current: today, detected: detected, now: now) {
                try store.upsert(updated)
                today = updated
            }
        }
        needsLocation = !monitor.isAuthorized
        if config.officeSSID == nil {
            error = "Set officeSSID in \((Config.fileURL.path as NSString).abbreviatingWithTildeInPath)"
        }
    }

    /// Pass nil to go back to automatic detection; without Wi-Fi the current status is kept.
    func setOverride(_ manual: Workplace?) {
        save(status: manual ?? detected ?? today?.status, source: manual == nil ? .auto : .manual, note: today?.note ?? "")
    }

    func setNote(_ note: String) {
        guard let today else { return }
        save(status: today.status, source: today.source, note: note.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func save(status: Workplace?, source: Source, note: String) {
        guard let status else { return }
        if attempt({ try store.upsert(DayRecord(status: status, source: source, note: note, at: Date())) }) {
            refresh()
        }
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

    @discardableResult
    private func attempt(_ body: () throws -> Void) -> Bool {
        do {
            try body()
            error = nil
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}

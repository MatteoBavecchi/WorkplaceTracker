import SwiftUI
import WorkplaceCore

@main
struct WorkplaceTrackerApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        MenuBarExtra {
            PanelView(state: state)
        } label: {
            Image(nsImage: icon)
        }
        .menuBarExtraStyle(.window)

        Window("Settings", id: SettingsView.windowID) {
            SettingsView(state: state)
        }
        .windowResizability(.contentSize)
    }

    /// Today's workplace, colored by how the monthly target is going.
    private var icon: NSImage {
        if state.error != nil { return .menuBarSymbol("exclamationmark.triangle", tint: nil) }
        return .menuBarSymbol(state.today?.status.symbol ?? "questionmark.circle", tint: state.month.pace.tint)
    }
}

/// Progress, calendar and today. Everything else lives in Settings.
private struct PanelView: View {
    @ObservedObject var state: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            MonthView(month: state.month)

            Divider()

            HStack {
                Text(today)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    openWindow(id: SettingsView.windowID)
                    // Menu bar apps aren't frontmost; without this the window opens behind others.
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.borderless)
                .keyboardShortcut(",")
                .help("Settings")
            }

            // Shown only when something needs fixing.
            if state.needsLocation {
                Button("Grant location access to detect your Wi-Fi") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices")!)
                }
                .buttonStyle(.link)
                .font(.callout)
            }
            if let error = state.error {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(.red)
            }
        }
        .padding(14)
        .frame(width: 300)
        // The panel stays alive between openings: refresh whenever it's shown.
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            state.refresh()
        }
    }

    private var today: String {
        let date = Date().formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().locale(english))
        guard let status = state.today?.status else { return "Today, \(date)" }
        return "Today, \(date) · \(status.label)"
    }
}

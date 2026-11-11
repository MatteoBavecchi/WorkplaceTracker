import SwiftUI
import WorkplaceCore

@main
struct WorkplaceTrackerApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuView(state: state)
        } label: {
            Image(systemName: state.error != nil ? "exclamationmark.triangle" : state.today?.status.symbol ?? "questionmark.circle")
        }
    }
}

private struct MenuView: View {
    @ObservedObject var state: AppState

    var body: some View {
        Text(summary)
        if let note = state.today?.note, !note.isEmpty {
            Text("Note: \(note)")
        }
        if let error = state.error {
            Text("⚠️ \(error)")
        }
        if state.needsLocation {
            Button("Grant Location Access…") {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices")!)
            }
        }
        Divider()
        Picker("Today", selection: Binding(get: { state.override }, set: state.setOverride)) {
            Text("🔄 Automatic").tag(Workplace?.none)
            ForEach(Workplace.allCases, id: \.self) { Text($0.label).tag(Optional($0)) }
        }
        .pickerStyle(.inline)
        Button("Edit Note…") {
            // Let the menu close before showing a modal dialog.
            DispatchQueue.main.async(execute: editNote)
        }
        .disabled(state.today == nil)
        Divider()
        Button("Open CSV") { NSWorkspace.shared.open(state.config.csvURL) }
        Toggle("Launch at Login", isOn: Binding(get: { state.launchAtLogin }, set: state.setLaunchAtLogin))
        Divider()
        Button("Quit") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    private func editNote() {
        let field = NSTextField(string: state.today?.note ?? "")
        field.frame = NSRect(x: 0, y: 0, width: 300, height: 24)
        field.placeholderString = "e.g. client visit"

        let alert = NSAlert()
        alert.messageText = "Note for Today"
        alert.informativeText = "Leave empty to clear the note."
        alert.accessoryView = field
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field

        // Menu bar apps are not frontmost by default; without this the dialog opens behind other windows.
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            state.setNote(field.stringValue)
        }
    }

    private var summary: String {
        guard let today = state.today else { return "Today: no data (Wi-Fi not detected)" }
        let source = today.source == .manual ? "manual" : "auto"
        let time = today.updatedAt.formatted(date: .omitted, time: .shortened)
        return "Today: \(today.status.label) · \(source) · saved at \(time)"
    }
}

private extension Workplace {
    var label: String {
        switch self {
        case .office: "🏢 Office"
        case .home: "🏠 Home"
        }
    }

    var symbol: String {
        switch self {
        case .office: "building.2"
        case .home: "house"
        }
    }
}

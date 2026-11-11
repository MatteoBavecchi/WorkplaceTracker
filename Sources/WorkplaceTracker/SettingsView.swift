import SwiftUI
import WorkplaceCore

struct SettingsView: View {
    static let windowID = "settings"

    @ObservedObject var state: AppState
    @State private var note = ""

    var body: some View {
        Form {
            Section("Today") {
                Picker("Workplace", selection: Binding(get: { state.override }, set: state.setOverride)) {
                    Text("🔄 Auto").tag(Workplace?.none)
                    ForEach(Workplace.allCases, id: \.self) { Text($0.label).tag(Optional($0)) }
                }
                .pickerStyle(.segmented)
                TextField("Note", text: $note, prompt: Text("Add a note"))
                    .disabled(state.today == nil)
                    .onSubmit { state.setNote(note) }
            }
            Section {
                Toggle("Launch at login", isOn: Binding(get: { state.launchAtLogin }, set: state.setLaunchAtLogin))
                FileRow(title: "CSV file", url: state.config.csvURL, button: "Open") {
                    NSWorkspace.shared.open(state.config.csvURL)
                }
                FileRow(title: "Config file", url: Config.fileURL, button: "Show in Finder") {
                    showInFinder(Config.fileURL)
                }
            } header: {
                Text("General")
            } footer: {
                Text("Restart the app to apply config changes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                Button("Quit WorkplaceTracker") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            }
        }
        .formStyle(.grouped)
        .frame(width: 400)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { note = state.today?.note ?? "" }
        // Closing the window or clicking elsewhere saves the note too.
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in
            state.setNote(note)
        }
    }

    /// Selects the file in Finder, or opens its folder when the file doesn't exist yet.
    private func showInFinder(_ url: URL) {
        if FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            let folder = url.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            NSWorkspace.shared.open(folder)
        }
    }
}

private struct FileRow: View {
    let title: String
    let url: URL
    let button: String
    let action: () -> Void

    var body: some View {
        LabeledContent(title) {
            HStack {
                Text(url.displayPath)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Button(button, action: action)
            }
        }
    }
}

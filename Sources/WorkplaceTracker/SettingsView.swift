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
            Section("General") {
                Toggle("Launch at login", isOn: Binding(get: { state.launchAtLogin }, set: state.setLaunchAtLogin))
                LabeledContent("CSV file") {
                    HStack {
                        Text(state.config.csvURL.displayPath)
                            .foregroundStyle(.secondary)
                            .truncationMode(.middle)
                        Button("Open") { NSWorkspace.shared.open(state.config.csvURL) }
                    }
                }
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
}

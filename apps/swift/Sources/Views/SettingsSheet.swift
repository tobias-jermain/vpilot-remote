import SwiftUI

struct SettingsSheet: View {
    @AppStorage(SettingsKeys.host) private var host: String = ""
    @AppStorage(SettingsKeys.port) private var port: Int = 9001

    @Environment(\.dismiss) private var dismiss
    var onSave: (String, Int) -> Void

    @State private var draftHost: String = ""
    @State private var draftPort: String = "9001"

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("PC's LAN IP (e.g. 192.168.1.100)", text: $draftHost)
                        #if os(iOS)
                        .keyboardType(.numbersAndPunctuation)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        #endif
                    TextField("Port", text: $draftPort)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                } header: {
                    Text("Plugin server")
                } footer: {
                    Text("Both devices must be on the same LAN. Find the PC's IP with ipconfig on Windows.")
                }
            }
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(draftHost.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .onAppear {
            draftHost = host
            draftPort = String(port)
        }
        #if os(macOS)
        .frame(minWidth: 380, minHeight: 200)
        #endif
    }

    private func save() {
        let trimmedHost = draftHost.trimmingCharacters(in: .whitespaces)
        let resolvedPort = Int(draftPort) ?? 9001
        host = trimmedHost
        port = resolvedPort
        dismiss()
        onSave(trimmedHost, resolvedPort)
    }
}

enum SettingsKeys {
    static let host = "serverHost"
    static let port = "serverPort"
}

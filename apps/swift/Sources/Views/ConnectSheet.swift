import SwiftUI

struct ConnectSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onConnect: (String, String, String) -> Void

    @State private var cid: String = ""
    @State private var password: String = ""
    @State private var typeCode: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("CID", text: $cid)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                    SecureField("Password", text: $password)
                    TextField("Aircraft type (e.g. B738)", text: $typeCode)
                        #if os(iOS)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                        #endif
                } footer: {
                    Text("Sent to the plugin over your LAN, which passes it to vPilot's own connect method. This is plaintext on ws:// — see ARCHITECTURE.md's security model before using this off your LAN.")
                }
            }
            .navigationTitle("Connect to VATSIM")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Connect") {
                        onConnect(cid.trimmingCharacters(in: .whitespaces), password, typeCode.trimmingCharacters(in: .whitespaces))
                        dismiss()
                    }
                    .disabled(cid.isEmpty || password.isEmpty || typeCode.isEmpty)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 380, minHeight: 260)
        #endif
    }
}

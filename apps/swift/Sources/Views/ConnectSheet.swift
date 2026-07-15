import SwiftUI

struct ConnectSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onConnect: (String, String, String?) -> Void

    @State private var callsign: String = ""
    @State private var typeCode: String = ""
    @State private var selcal: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Callsign (e.g. BAW123)", text: $callsign)
                        #if os(iOS)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                        #endif
                    TextField("Aircraft type (e.g. B738)", text: $typeCode)
                        #if os(iOS)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                        #endif
                    TextField("SELCAL (optional)", text: $selcal)
                        #if os(iOS)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                        #endif
                } footer: {
                    Text("You must already be signed in to vPilot with your CID/password — this only asks vPilot to go online with this callsign. No credentials cross the network.")
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
                        let trimmedSelcal = selcal.trimmingCharacters(in: .whitespaces)
                        onConnect(
                            callsign.trimmingCharacters(in: .whitespaces),
                            typeCode.trimmingCharacters(in: .whitespaces),
                            trimmedSelcal.isEmpty ? nil : trimmedSelcal
                        )
                        dismiss()
                    }
                    .disabled(callsign.isEmpty || typeCode.isEmpty)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 380, minHeight: 260)
        #endif
    }
}

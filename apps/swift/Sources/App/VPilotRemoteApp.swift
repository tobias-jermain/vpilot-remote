import SwiftUI

@main
struct VPilotRemoteApp: App {
    @StateObject private var client = VPilotRemoteClient()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(client)
                .onAppear {
                    NotificationManager.shared.requestAuthorization()
                }
        }
        #if os(macOS)
        .defaultSize(width: 420, height: 600)
        #endif
    }
}

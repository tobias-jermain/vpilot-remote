import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var client: VPilotRemoteClient
    @AppStorage(SettingsKeys.host) private var host: String = ""
    @AppStorage(SettingsKeys.port) private var port: Int = 9001

    @State private var showingSettings = false
    @State private var showingConnectSheet = false

    var body: some View {
        NavigationStack {
            Group {
                if client.feed.isEmpty {
                    emptyState
                } else {
                    List(client.feed) { item in
                        FeedRow(item: item)
                    }
                    #if os(iOS)
                    .listStyle(.plain)
                    #endif
                }
            }
            .navigationTitle("vPilot Remote")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        if client.vatsimConnected {
                            client.sendDisconnectCommand()
                        } else {
                            showingConnectSheet = true
                        }
                    } label: {
                        Image(systemName: client.vatsimConnected ? "bolt.slash" : "bolt")
                    }
                    .disabled(client.socketState != .connected)
                    .help(client.vatsimConnected ? "Disconnect from VATSIM" : "Connect to VATSIM")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .help("Server settings")
                }
            }
            .safeAreaInset(edge: .top) {
                statusBar
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsSheet { newHost, newPort in
                client.connect(host: newHost, port: newPort)
            }
        }
        .sheet(isPresented: $showingConnectSheet) {
            ConnectSheet { cid, password, typeCode in
                client.sendConnectCommand(cid: cid, password: password, typeCode: typeCode)
            }
        }
        .onAppear {
            if !host.isEmpty {
                client.connect(host: host, port: port)
            } else {
                showingSettings = true
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableCompat(
            title: "No events yet",
            message: statusMessage,
            systemImage: "airplane.circle"
        )
    }

    private var statusMessage: String {
        switch client.socketState {
        case .disconnected: return "Not connected to the plugin. Open Settings to enter your PC's LAN IP."
        case .connecting: return "Connecting to \(host):\(port)…"
        case .connected: return "Connected — waiting for vPilot events."
        case .reconnecting(let attempt): return "Connection dropped, retrying (attempt \(attempt))…"
        }
    }

    private var statusBar: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            if !client.callsign.isEmpty {
                Text(client.callsign)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(.bar)
    }

    private var statusColor: Color {
        switch client.socketState {
        case .connected: return client.vatsimConnected ? .green : .yellow
        case .connecting, .reconnecting: return .orange
        case .disconnected: return .red
        }
    }

    private var statusText: String {
        switch client.socketState {
        case .disconnected: return "Not connected"
        case .connecting: return "Connecting…"
        case .reconnecting(let attempt): return "Reconnecting (\(attempt))…"
        case .connected: return client.vatsimConnected ? "vPilot connected" : "Plugin connected — vPilot offline"
        }
    }
}

/// `ContentUnavailableView` requires iOS 17/macOS 14; this app targets a
/// slightly lower floor, so a minimal stand-in avoids bumping the deployment
/// target just for an empty-state view.
private struct ContentUnavailableCompat: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

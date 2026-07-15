import Foundation

/// WebSocket layer shared by the Mac and iOS targets (see CONTRIBUTING.md —
/// "keep protocol-handling code here rather than duplicating it per-platform").
///
/// Two connection states matter and are easy to conflate:
///  - `socketState`: whether *this app* has a live WebSocket to the plugin.
///  - `vatsimConnected`: whether *vPilot* is connected to the VATSIM network,
///    as reported by the plugin's `state_change` events.
final class VPilotRemoteClient: NSObject, ObservableObject {
    enum SocketState: Equatable {
        case disconnected
        case connecting
        case connected
        case reconnecting(attempt: Int)
    }

    @Published private(set) var socketState: SocketState = .disconnected
    @Published private(set) var vatsimConnected = false
    @Published private(set) var callsign = ""
    @Published private(set) var feed: [FeedItem] = []
    @Published var lastError: String?

    private var session: URLSession!
    private var task: URLSessionWebSocketTask?
    private var host = ""
    private var port = 9001
    private var shouldReconnect = false
    private var reconnectWorkItem: DispatchWorkItem?
    private let notificationManager: NotificationManaging

    private static let maxFeedItems = 200
    private static let maxReconnectDelay: TimeInterval = 30

    init(notificationManager: NotificationManaging = NotificationManager.shared) {
        self.notificationManager = notificationManager
        super.init()
        self.session = URLSession(configuration: .default, delegate: nil, delegateQueue: nil)
    }

    // MARK: - Connection lifecycle

    func connect(host: String, port: Int) {
        self.host = host
        self.port = port
        shouldReconnect = true
        reconnectWorkItem?.cancel()
        openSocket(attempt: 0)
    }

    /// Closes the app's own socket to the plugin. Does not touch vPilot's
    /// VATSIM connection — for that, use `sendDisconnectCommand()`.
    func disconnectSocket() {
        shouldReconnect = false
        reconnectWorkItem?.cancel()
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        socketState = .disconnected
    }

    private func openSocket(attempt: Int) {
        guard !host.isEmpty, let url = URL(string: "ws://\(host):\(port)") else {
            DispatchQueue.main.async {
                self.socketState = .disconnected
                self.lastError = "Invalid server address"
            }
            return
        }

        DispatchQueue.main.async {
            self.socketState = attempt == 0 ? .connecting : .reconnecting(attempt: attempt)
        }

        let task = session.webSocketTask(with: url)
        self.task = task
        task.resume()

        DispatchQueue.main.async {
            self.socketState = .connected
            self.lastError = nil
        }

        listen()
    }

    private func listen() {
        task?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                DispatchQueue.main.async { self.lastError = error.localizedDescription }
                self.handleDrop()
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handle(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handle(text)
                    }
                @unknown default:
                    break
                }
                self.listen()
            }
        }
    }

    private func handleDrop() {
        task = nil
        guard shouldReconnect else {
            DispatchQueue.main.async { self.socketState = .disconnected }
            return
        }
        scheduleReconnect(attempt: 1)
    }

    private func scheduleReconnect(attempt: Int) {
        reconnectWorkItem?.cancel()
        let delay = min(pow(2.0, Double(attempt)), Self.maxReconnectDelay)

        DispatchQueue.main.async {
            self.socketState = .reconnecting(attempt: attempt)
        }

        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.shouldReconnect else { return }
            self.openSocketRetry(attempt: attempt)
        }
        reconnectWorkItem = workItem
        DispatchQueue.global().asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    /// Like `openSocket`, but on failure schedules the *next* backoff step
    /// instead of resetting to attempt 0 (which `connect(host:port:)` does).
    private func openSocketRetry(attempt: Int) {
        guard let url = URL(string: "ws://\(host):\(port)") else { return }

        let task = session.webSocketTask(with: url)
        self.task = task
        task.resume()

        DispatchQueue.main.async { self.socketState = .connected }
        listen()
    }

    // MARK: - Outbound commands

    func sendConnectCommand(cid: String, password: String, typeCode: String) {
        send(ConnectCommand(cid: cid, password: password, typeCode: typeCode))
    }

    func sendDisconnectCommand() {
        send(DisconnectCommand())
    }

    private func send<T: Encodable>(_ command: T) {
        guard let data = try? ProtocolDateFormat.encoder.encode(command),
              let text = String(data: data, encoding: .utf8) else { return }
        task?.send(.string(text)) { [weak self] error in
            if let error {
                DispatchQueue.main.async { self?.lastError = error.localizedDescription }
            }
        }
    }

    // MARK: - Inbound parsing

    private func handle(_ text: String) {
        guard let data = text.data(using: .utf8),
              let envelope = try? ProtocolDateFormat.decoder.decode(InboundEnvelope.self, from: data) else { return }

        switch envelope.type {
        case .stateChange:
            guard let event = try? ProtocolDateFormat.decoder.decode(StateChangeEvent.self, from: data) else { return }
            DispatchQueue.main.async {
                self.vatsimConnected = event.isConnected
                self.callsign = event.callsign
                self.pushToFeed(.stateChange(event))
            }

        case .radioMessage:
            guard let event = try? ProtocolDateFormat.decoder.decode(RadioMessageEvent.self, from: data) else { return }
            DispatchQueue.main.async { self.pushToFeed(.radioMessage(event)) }
            notificationManager.notify(title: event.from, body: event.message)

        case .privateMessage:
            guard let event = try? ProtocolDateFormat.decoder.decode(PrivateMessageEvent.self, from: data) else { return }
            DispatchQueue.main.async { self.pushToFeed(.privateMessage(event)) }
            notificationManager.notify(title: "Message from \(event.from)", body: event.message)

        case .airspaceAlert:
            guard let event = try? ProtocolDateFormat.decoder.decode(AirspaceAlertEvent.self, from: data) else { return }
            DispatchQueue.main.async { self.pushToFeed(.airspaceAlert(event)) }
            let etaText = String(format: "%.1f min", event.timeToIntercept)
            notificationManager.notify(
                title: "Approaching \(event.controller)",
                body: "\(event.frequency) — ETA \(etaText), \(String(format: "%.0f", event.distance)) nm"
            )
        }
    }

    private func pushToFeed(_ item: FeedItem) {
        feed.insert(item, at: 0)
        if feed.count > Self.maxFeedItems {
            feed.removeLast(feed.count - Self.maxFeedItems)
        }
    }
}

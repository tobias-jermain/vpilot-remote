import Foundation

/// Mirrors the JSON message shapes documented in ARCHITECTURE.md → "Message protocol".
/// Keep this in sync with `plugin/RemoteControlPlugin.cs` — there is no schema
/// versioning safety net beyond the `v` field, so a protocol change must land in
/// both places in the same PR (see CONTRIBUTING.md).
enum ProtocolVersion {
    static let current = 1
}

enum EventType: String, Decodable {
    case stateChange = "state_change"
    case radioMessage = "radio_message"
    case privateMessage = "private_message"
    case airspaceAlert = "airspace_alert"
}

/// A single event received from the plugin, decoded generically first (to read
/// `type`) and then re-decoded into its specific payload.
struct InboundEnvelope: Decodable {
    let v: Int?
    let type: EventType
}

struct StateChangeEvent: Decodable, Identifiable {
    let id = UUID()
    let isConnected: Bool
    let callsign: String
    let timestamp: Date

    enum CodingKeys: String, CodingKey {
        case isConnected, callsign, timestamp
    }
}

struct RadioMessageEvent: Decodable, Identifiable {
    let id = UUID()
    let from: String
    let message: String
    let frequencies: [Int]
    let timestamp: Date

    enum CodingKeys: String, CodingKey {
        case from, message, frequencies, timestamp
    }
}

struct PrivateMessageEvent: Decodable, Identifiable {
    let id = UUID()
    let from: String
    let message: String
    let timestamp: Date

    enum CodingKeys: String, CodingKey {
        case from, message, timestamp
    }
}

struct AirspaceAlertEvent: Decodable, Identifiable {
    let id = UUID()
    let controller: String
    let frequency: String
    let timeToIntercept: Double
    let distance: Double
    let timestamp: Date

    enum CodingKeys: String, CodingKey {
        case controller, frequency, timeToIntercept, distance, timestamp
    }
}

/// Union of everything that can show up in the app's event feed, newest first.
enum FeedItem: Identifiable {
    case stateChange(StateChangeEvent)
    case radioMessage(RadioMessageEvent)
    case privateMessage(PrivateMessageEvent)
    case airspaceAlert(AirspaceAlertEvent)

    var id: UUID {
        switch self {
        case .stateChange(let e): return e.id
        case .radioMessage(let e): return e.id
        case .privateMessage(let e): return e.id
        case .airspaceAlert(let e): return e.id
        }
    }

    var timestamp: Date {
        switch self {
        case .stateChange(let e): return e.timestamp
        case .radioMessage(let e): return e.timestamp
        case .privateMessage(let e): return e.timestamp
        case .airspaceAlert(let e): return e.timestamp
        }
    }
}

// MARK: - Outbound (app -> plugin)

struct ConnectCommand: Encodable {
    let action = "connect"
    let cid: String
    let password: String
    let typeCode: String
}

struct DisconnectCommand: Encodable {
    let action = "disconnect"
}

enum ProtocolDateFormat {
    /// The plugin serializes `DateTime.UtcNow` via `System.Text.Json`, which
    /// produces round-trip ("O") format, e.g. 2026-07-15T12:34:56.7890123Z.
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: raw) {
                return date
            }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: raw) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unrecognized timestamp: \(raw)")
        }
        return decoder
    }()

    static let encoder: JSONEncoder = JSONEncoder()
}

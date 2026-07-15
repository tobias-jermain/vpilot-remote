import SwiftUI

struct FeedRow: View {
    let item: FeedItem

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(item.timestamp, style: .time)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private var iconName: String {
        switch item {
        case .stateChange(let e): return e.isConnected ? "checkmark.circle" : "xmark.circle"
        case .radioMessage: return "antenna.radiowaves.left.and.right"
        case .privateMessage: return "message"
        case .airspaceAlert: return "exclamationmark.triangle"
        }
    }

    private var iconColor: Color {
        switch item {
        case .stateChange(let e): return e.isConnected ? .green : .secondary
        case .radioMessage: return .blue
        case .privateMessage: return .indigo
        case .airspaceAlert: return .orange
        }
    }

    private var title: String {
        switch item {
        case .stateChange(let e): return e.isConnected ? "Connected as \(e.callsign)" : "Disconnected"
        case .radioMessage(let e): return e.from
        case .privateMessage(let e): return "From \(e.from)"
        case .airspaceAlert(let e): return "Approaching \(e.controller)"
        }
    }

    private var subtitle: String {
        switch item {
        case .stateChange: return ""
        case .radioMessage(let e): return e.message
        case .privateMessage(let e): return e.message
        case .airspaceAlert(let e):
            let eta = String(format: "%.1f min", e.timeToIntercept)
            let dist = String(format: "%.0f nm", e.distance)
            return "\(e.frequency) — ETA \(eta), \(dist)"
        }
    }
}

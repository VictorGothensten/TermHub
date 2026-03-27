import Foundation

struct ActivityEvent: Identifiable {
    let id = UUID()
    let timestamp: Date
    let sessionId: UUID
    let sessionTitle: String
    let eventType: EventType

    enum EventType {
        case created
        case wentIdle
        case resumed
        case exited(code: Int32?)
        case titleChanged(newTitle: String)
        case archived

        var icon: String {
            switch self {
            case .created: return "plus.circle"
            case .wentIdle: return "moon.fill"
            case .resumed: return "play.circle"
            case .exited: return "xmark.circle"
            case .titleChanged: return "pencil"
            case .archived: return "archivebox"
            }
        }

        var label: String {
            switch self {
            case .created: return "started"
            case .wentIdle: return "idle"
            case .resumed: return "active"
            case .exited(let code): return code.map { "exited (\($0))" } ?? "exited"
            case .titleChanged(let t): return "renamed to \(t)"
            case .archived: return "archived"
            }
        }
    }

    var relativeTime: String {
        let seconds = Int(Date().timeIntervalSince(timestamp))
        if seconds < 5 { return "just now" }
        if seconds < 60 { return "\(seconds)s ago" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        return "\(hours)h ago"
    }
}

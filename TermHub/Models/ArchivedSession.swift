import Foundation

struct ArchivedSession: Identifiable, Codable {
    let id: UUID
    let title: String
    let bufferText: String
    let workingDirectory: String?
    let customEnvVars: [String: String]
    let archivedAt: Date
    let workspaceId: UUID

    /// Preview text: last few non-empty lines of the buffer
    var preview: String {
        let lines = bufferText.components(separatedBy: "\n")
            .reversed()
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .prefix(3)
            .reversed()
        return lines.joined(separator: "\n")
    }

    var formattedDate: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: archivedAt)
    }
}

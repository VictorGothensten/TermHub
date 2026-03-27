import Foundation

struct TemplateSession: Codable {
    var title: String
    var command: String?
    var workingDirectory: String?
}

struct SessionTemplate: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var sessions: [TemplateSession]
}

class TemplateStore: ObservableObject {
    @Published var templates: [SessionTemplate] = []

    private let saveURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("TermHub", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("templates.json")
    }()

    init() { load() }

    func saveTemplate(name: String, from workspace: Workspace) {
        let templateSessions = workspace.sessions.map { session in
            TemplateSession(
                title: session.title,
                command: nil,
                workingDirectory: session.lastWorkingDirectory
            )
        }
        templates.append(SessionTemplate(name: name, sessions: templateSessions))
        save()
    }

    func delete(_ template: SessionTemplate) {
        templates.removeAll { $0.id == template.id }
        save()
    }

    func save() {
        if let data = try? JSONEncoder().encode(templates) {
            try? data.write(to: saveURL, options: .atomic)
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: saveURL),
              let decoded = try? JSONDecoder().decode([SessionTemplate].self, from: data) else { return }
        templates = decoded
    }
}

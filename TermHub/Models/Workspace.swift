import Foundation

class Workspace: Identifiable, ObservableObject {
    let id: UUID
    @Published var name: String
    @Published var sessions: [TerminalSession]
    @Published var archives: [ArchivedSession]

    init(id: UUID = UUID(), name: String, sessions: [TerminalSession] = [], archives: [ArchivedSession] = []) {
        self.id = id
        self.name = name
        self.sessions = sessions
        self.archives = archives
    }

    func addSession() {
        sessions.append(TerminalSession())
    }

    func removeSession(_ session: TerminalSession) {
        sessions.removeAll { $0.id == session.id }
    }

    func archiveSession(_ session: TerminalSession) {
        let archived = session.archive(workspaceId: id)
        archives.insert(archived, at: 0) // newest first
        removeSession(session)
    }

    func reopenArchive(_ archive: ArchivedSession) -> TerminalSession {
        let session = TerminalSession()
        session.title = archive.title
        session.userRenamed = true
        session.restoreFromArchive(archive)
        sessions.append(session)
        return session
    }

    func deleteArchive(_ archive: ArchivedSession) {
        archives.removeAll { $0.id == archive.id }
    }
}

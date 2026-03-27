import Foundation

class Workspace: Identifiable, ObservableObject {
    let id: UUID
    @Published var name: String
    @Published var sessions: [TerminalSession]
    @Published var archives: [ArchivedSession]
    @Published var activityLog: [ActivityEvent] = []

    init(id: UUID = UUID(), name: String, sessions: [TerminalSession] = [], archives: [ArchivedSession] = []) {
        self.id = id
        self.name = name
        self.sessions = sessions
        self.archives = archives
    }

    func addSession() {
        let session = TerminalSession()
        session.workspaceId = id
        sessions.append(session)
        logEvent(.created, session: session)
    }

    func logEvent(_ type: ActivityEvent.EventType, session: TerminalSession) {
        let event = ActivityEvent(timestamp: Date(), sessionId: session.id, sessionTitle: session.title, eventType: type)
        activityLog.append(event)
        if activityLog.count > 100 { activityLog.removeFirst() }
    }

    func removeSession(_ session: TerminalSession) {
        sessions.removeAll { $0.id == session.id }
    }

    func moveSession(fromId: UUID, toId: UUID) {
        guard let fromIdx = sessions.firstIndex(where: { $0.id == fromId }),
              let toIdx = sessions.firstIndex(where: { $0.id == toId }),
              fromIdx != toIdx else { return }
        let session = sessions.remove(at: fromIdx)
        sessions.insert(session, at: toIdx)
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

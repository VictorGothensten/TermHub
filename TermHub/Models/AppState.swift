import Foundation
import SwiftUI

class AppState: ObservableObject {
    @Published var workspaces: [Workspace] = []
    @Published var selectedWorkspaceIndex: Int = 0
    @Published var zoomedSession: TerminalSession? = nil
    @Published var showNewWorkspacePrompt: Bool = false
    @Published var showArchives: Bool = false

    var selectedWorkspace: Workspace? {
        guard workspaces.indices.contains(selectedWorkspaceIndex) else { return nil }
        return workspaces[selectedWorkspaceIndex]
    }

    private static let appSupportDir: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("TermHub", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private let saveURL = AppState.appSupportDir.appendingPathComponent("state.json")
    private let archivesURL = AppState.appSupportDir.appendingPathComponent("archives.json")

    init() {
        load()
        if workspaces.isEmpty {
            let ws = Workspace(name: "Default")
            ws.addSession()
            workspaces.append(ws)
        }

        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.save()
        }
    }

    func addWorkspace(name: String) {
        let ws = Workspace(name: name)
        ws.addSession()
        workspaces.append(ws)
        selectedWorkspaceIndex = workspaces.count - 1
    }

    func removeWorkspace(at index: Int) {
        guard workspaces.count > 1, workspaces.indices.contains(index) else { return }
        workspaces.remove(at: index)
        if selectedWorkspaceIndex >= workspaces.count {
            selectedWorkspaceIndex = workspaces.count - 1
        }
    }

    func selectWorkspace(at index: Int) {
        guard workspaces.indices.contains(index) else { return }
        selectedWorkspaceIndex = index
        zoomedSession = nil
        showArchives = false
    }

    // MARK: - Archive Actions

    func archiveSession(_ session: TerminalSession, in workspace: Workspace) {
        if zoomedSession?.id == session.id {
            zoomedSession = nil
        }
        workspace.archiveSession(session)
        saveArchives()
        objectWillChange.send()
    }

    func reopenArchive(_ archive: ArchivedSession, in workspace: Workspace) {
        _ = workspace.reopenArchive(archive)
        saveArchives()
        showArchives = false
        objectWillChange.send()
    }

    func deleteArchive(_ archive: ArchivedSession, from workspace: Workspace) {
        workspace.deleteArchive(archive)
        saveArchives()
        objectWillChange.send()
    }

    // MARK: - Persistence

    private struct SavedState: Codable {
        struct SavedWorkspace: Codable {
            let id: String
            let name: String
            let sessionCount: Int
        }
        let workspaces: [SavedWorkspace]
        let selectedIndex: Int
    }

    func save() {
        let state = SavedState(
            workspaces: workspaces.map {
                SavedState.SavedWorkspace(id: $0.id.uuidString, name: $0.name, sessionCount: $0.sessions.count)
            },
            selectedIndex: selectedWorkspaceIndex
        )
        if let data = try? JSONEncoder().encode(state) {
            try? data.write(to: saveURL, options: .atomic)
        }
        saveArchives()
    }

    private func load() {
        guard let data = try? Data(contentsOf: saveURL),
              let state = try? JSONDecoder().decode(SavedState.self, from: data) else { return }

        let allArchives = loadArchives()

        workspaces = state.workspaces.map { saved in
            let wsId = UUID(uuidString: saved.id) ?? UUID()
            let wsArchives = allArchives.filter { $0.workspaceId == wsId }
            let ws = Workspace(id: wsId, name: saved.name, archives: wsArchives)
            for _ in 0..<max(1, saved.sessionCount) {
                ws.addSession()
            }
            return ws
        }
        selectedWorkspaceIndex = min(state.selectedIndex, max(0, workspaces.count - 1))
    }

    private func saveArchives() {
        let allArchives = workspaces.flatMap { $0.archives }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(allArchives) {
            try? data.write(to: archivesURL, options: .atomic)
        }
    }

    private func loadArchives() -> [ArchivedSession] {
        guard let data = try? Data(contentsOf: archivesURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([ArchivedSession].self, from: data)) ?? []
    }
}

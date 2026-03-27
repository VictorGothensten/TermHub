import Foundation
import AppKit
import SwiftTerm

class TerminalSession: NSObject, Identifiable, ObservableObject, LocalProcessTerminalViewDelegate {
    let id: UUID
    let terminalView: LocalProcessTerminalView
    @Published var title: String
    @Published var isAlive: Bool = true
    @Published var showArchiveContext: Bool = false

    /// When true, auto-title from the shell is ignored
    var userRenamed: Bool = false

    /// Last known working directory (updated via OSC 7)
    var lastWorkingDirectory: String?

    /// Tracks whether this session was restored from an archive
    var restoredFrom: ArchivedSession?

    init(id: UUID = UUID()) {
        self.id = id
        self.title = "Terminal"

        let frame = NSRect(x: 0, y: 0, width: 800, height: 600)
        self.terminalView = LocalProcessTerminalView(frame: frame)

        super.init()

        // Appearance
        terminalView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        terminalView.nativeForegroundColor = .white
        terminalView.nativeBackgroundColor = NSColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1.0)

        // Delegate for title updates
        terminalView.processDelegate = self

        // Environment — inherit current env, override TERM
        var env: [String] = []
        for (key, value) in ProcessInfo.processInfo.environment where key != "TERM" {
            env.append("\(key)=\(value)")
        }
        env.append("TERM=xterm-256color")

        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let shellName = (shell as NSString).lastPathComponent

        terminalView.startProcess(
            executable: shell,
            args: [],
            environment: env,
            execName: "-\(shellName)"
        )
    }

    func rename(_ newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        title = trimmed
        userRenamed = true
    }

    // MARK: - Buffer Extraction

    func extractBufferText() -> String {
        let terminal = terminalView.getTerminal()
        var lines: [String] = []
        var row = 0
        while let line = terminal.getScrollInvariantLine(row: row) {
            lines.append(line.translateToString(trimRight: true))
            row += 1
        }
        while let last = lines.last, last.isEmpty {
            lines.removeLast()
        }
        return lines.joined(separator: "\n")
    }

    func archive(workspaceId: UUID) -> ArchivedSession {
        // Clean directory: strip file:// URL scheme if present
        let cleanDir = cleanDirectoryPath(lastWorkingDirectory)
        return ArchivedSession(
            id: UUID(),
            title: title,
            bufferText: extractBufferText(),
            workingDirectory: cleanDir,
            customEnvVars: [:],
            archivedAt: Date(),
            workspaceId: workspaceId
        )
    }

    /// Restore: just cd to the directory, show context via the UI (not terminal feed)
    func restoreFromArchive(_ archive: ArchivedSession) {
        restoredFrom = archive
        showArchiveContext = false

        if let dir = archive.workingDirectory {
            let escaped = dir.replacingOccurrences(of: "'", with: "'\\''")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                let terminal = self?.terminalView.getTerminal()
                let cdCommand = Array("cd '\(escaped)'\n".utf8)
                terminal?.sendResponse(cdCommand)
            }
        }
    }

    private func cleanDirectoryPath(_ path: String?) -> String? {
        guard let path = path else { return nil }
        if path.hasPrefix("file://") {
            return URL(string: path)?.path ?? path.replacingOccurrences(of: "file://", with: "")
        }
        return path
    }

    // MARK: - LocalProcessTerminalViewDelegate

    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
        guard !userRenamed, !title.isEmpty else { return }
        DispatchQueue.main.async { [weak self] in
            self?.title = title
        }
    }

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
        lastWorkingDirectory = cleanDirectoryPath(directory)
    }

    func processTerminated(source: TerminalView, exitCode: Int32?) {
        DispatchQueue.main.async { [weak self] in
            self?.isAlive = false
        }
    }
}

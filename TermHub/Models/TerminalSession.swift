import Foundation
import AppKit
import SwiftTerm

class TerminalSession: NSObject, Identifiable, ObservableObject, LocalProcessTerminalViewDelegate {
    let id: UUID
    let terminalView: LocalProcessTerminalView
    @Published var title: String
    @Published var isAlive: Bool = true
    @Published var showArchiveContext: Bool = false
    @Published var isIdle: Bool = false
    @Published var notifyOnIdle: Bool = false

    /// When true, auto-title from the shell is ignored
    var userRenamed: Bool = false

    /// Which workspace this session belongs to (for notifications)
    var workspaceId: UUID?

    /// Last known working directory (updated via OSC 7)
    var lastWorkingDirectory: String?

    /// Tracks whether this session was restored from an archive
    var restoredFrom: ArchivedSession?

    // Idle detection
    private var lastBufferFingerprint: String = ""
    private var lastChangeTime: Date = Date()
    private var idleTimer: Timer?
    private static let idleThreshold: TimeInterval = 3.0

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

        startIdleDetection()
    }

    deinit {
        idleTimer?.invalidate()
    }

    func rename(_ newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        title = trimmed
        userRenamed = true
    }

    // MARK: - Idle Detection

    private func startIdleDetection() {
        idleTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkIdleState()
        }
    }

    private func checkIdleState() {
        guard isAlive else {
            if !isIdle { isIdle = true }
            return
        }

        let fingerprint = currentBufferFingerprint()

        if fingerprint != lastBufferFingerprint {
            // Buffer changed — activity detected
            lastBufferFingerprint = fingerprint
            lastChangeTime = Date()
            if isIdle {
                isIdle = false
            }
        } else {
            // Buffer unchanged — check if enough time has passed
            let elapsed = Date().timeIntervalSince(lastChangeTime)
            let shouldBeIdle = elapsed >= Self.idleThreshold
            if shouldBeIdle && !isIdle {
                isIdle = true
                // Send notification if enabled
                if notifyOnIdle, let wsId = workspaceId {
                    let lastLine = currentBufferFingerprint()
                        .components(separatedBy: "\n")
                        .last(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) ?? ""
                    NotificationManager.shared.sendCompletionNotification(
                        sessionTitle: title,
                        lastLine: String(lastLine.prefix(100)),
                        sessionId: id,
                        workspaceId: wsId
                    )
                }
            } else if !shouldBeIdle && isIdle {
                isIdle = false
            }
        }
    }

    /// Snapshot of the last few visible lines — cheap fingerprint
    private func currentBufferFingerprint() -> String {
        let terminal = terminalView.getTerminal()
        let rows = terminal.rows
        var lines: [String] = []
        // Check last 3 visible lines for changes
        for r in max(0, rows - 3)..<rows {
            if let line = terminal.getLine(row: r) {
                lines.append(line.translateToString(trimRight: true))
            }
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Browser Preview

    func openPreviewInBrowser() {
        // Try to find a URL from the terminal output first
        if let url = detectServerURL() {
            openInChrome(url)
            return
        }

        // Fallback: check listening ports via lsof
        if let url = detectListeningPort() {
            openInChrome(url)
            return
        }

        // Nothing found — beep
        NSSound.beep()
    }

    /// Scan terminal buffer for URLs like localhost:3000, http://127.0.0.1:8080, etc.
    private func detectServerURL() -> URL? {
        let buffer = extractBufferText()

        // Match common dev server URL patterns (search from bottom — most recent output first)
        let patterns = [
            // Explicit URLs: http://localhost:3000, http://127.0.0.1:8080, http://0.0.0.0:5173
            "https?://(?:localhost|127\\.0\\.0\\.1|0\\.0\\.0\\.0):\\d{2,5}[/\\w.-]*",
            // "Local:" lines from Vite, Next.js, etc.: "Local:   http://localhost:5173/"
            "https?://localhost:\\d{2,5}[/\\w.-]*",
        ]

        let lines = buffer.components(separatedBy: "\n").reversed()
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
            for line in lines {
                let range = NSRange(line.startIndex..., in: line)
                if let match = regex.firstMatch(in: line, range: range),
                   let matchRange = Range(match.range, in: line) {
                    var urlString = String(line[matchRange])
                    // Replace 0.0.0.0 with localhost (0.0.0.0 doesn't open in browser)
                    urlString = urlString.replacingOccurrences(of: "0.0.0.0", with: "localhost")
                    if let url = URL(string: urlString) {
                        return url
                    }
                }
            }
        }
        return nil
    }

    /// Use lsof to find ports the shell's child processes are listening on
    private func detectListeningPort() -> URL? {
        // Get the shell's PID from the process
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        // Find TCP LISTEN ports for processes in our terminal's process group
        process.arguments = ["-c", "lsof -iTCP -sTCP:LISTEN -P -n 2>/dev/null | grep -v '^COMMAND' | awk '{print $9}' | grep -oE ':\\d+$' | tr -d ':' | sort -n | head -1"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              let port = Int(output), port > 0 else { return nil }

        return URL(string: "http://localhost:\(port)")
    }

    private func openInChrome(_ url: URL) {
        let chromeURL = URL(fileURLWithPath: "/Applications/Google Chrome.app")
        if FileManager.default.fileExists(atPath: chromeURL.path) {
            NSWorkspace.shared.open(
                [url],
                withApplicationAt: chromeURL,
                configuration: NSWorkspace.OpenConfiguration()
            )
        } else {
            NSWorkspace.shared.open(url)
        }
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

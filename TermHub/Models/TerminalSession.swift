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
        let bufferText = extractBufferText()
        let escapedTitle = title
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
        let escapedContent = bufferText
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")

        let cwd = lastWorkingDirectory ?? "~"
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short)

        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <title>\(escapedTitle) — TermHub Preview</title>
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                body {
                    background: #1a1a1e;
                    color: #e0e0e0;
                    font-family: 'SF Mono', 'Menlo', 'Monaco', 'Courier New', monospace;
                    font-size: 13px;
                    line-height: 1.5;
                    padding: 0;
                }
                .header {
                    background: #25252a;
                    border-bottom: 1px solid #333;
                    padding: 12px 20px;
                    display: flex;
                    align-items: center;
                    gap: 16px;
                    position: sticky;
                    top: 0;
                    z-index: 10;
                }
                .header .dot {
                    width: 10px; height: 10px;
                    border-radius: 50%;
                    background: \(isAlive ? (isIdle ? "#d9a633" : "#4caf50") : "#f44336");
                }
                .header .title {
                    font-size: 14px;
                    font-weight: 600;
                    color: #fff;
                }
                .header .meta {
                    font-size: 11px;
                    color: #888;
                    margin-left: auto;
                }
                .header .cwd {
                    font-size: 11px;
                    color: #4fc3f7;
                }
                .content {
                    padding: 16px 20px;
                    white-space: pre-wrap;
                    word-wrap: break-word;
                    tab-size: 8;
                }
                .footer {
                    background: #25252a;
                    border-top: 1px solid #333;
                    padding: 8px 20px;
                    font-size: 10px;
                    color: #555;
                    text-align: center;
                    position: sticky;
                    bottom: 0;
                }
                ::selection { background: #4fc3f7; color: #000; }
            </style>
        </head>
        <body>
            <div class="header">
                <div class="dot"></div>
                <span class="title">\(escapedTitle)</span>
                <span class="cwd">\(cwd)</span>
                <span class="meta">\(timestamp)</span>
            </div>
            <div class="content">\(escapedContent)</div>
            <div class="footer">TermHub Preview — \(bufferText.components(separatedBy: "\n").count) lines</div>
            <script>window.scrollTo(0, document.body.scrollHeight);</script>
        </body>
        </html>
        """

        // Write to temp file and open in Chrome
        let tmpDir = FileManager.default.temporaryDirectory
        let fileName = "termhub-preview-\(id.uuidString.prefix(8)).html"
        let fileURL = tmpDir.appendingPathComponent(fileName)
        try? html.write(to: fileURL, atomically: true, encoding: .utf8)

        // Try Chrome first, fall back to default browser
        let chromeURL = URL(fileURLWithPath: "/Applications/Google Chrome.app")
        if FileManager.default.fileExists(atPath: chromeURL.path) {
            NSWorkspace.shared.open(
                [fileURL],
                withApplicationAt: chromeURL,
                configuration: NSWorkspace.OpenConfiguration()
            )
        } else {
            NSWorkspace.shared.open(fileURL)
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

import Foundation
import AppKit

class AppUpdater: ObservableObject {
    enum State: Equatable {
        case idle
        case checking
        case updateAvailable(commits: String)
        case downloading
        case building
        case ready
        case upToDate
        case failed(String)
    }

    @Published var state: State = .idle

    private let repoURL = "https://github.com/VictorGothensten/TermHub.git"

    /// Find the project directory — check multiple locations
    private var projectDir: URL? {
        // 1. Check relative to running binary (.build/debug/TermHub or .build/release/TermHub)
        if let execPath = Bundle.main.executablePath {
            let components = URL(fileURLWithPath: execPath).pathComponents
            if let buildIdx = components.lastIndex(of: ".build"), buildIdx >= 1 {
                let projectPath = "/" + components[1..<buildIdx].joined(separator: "/")
                let dir = URL(fileURLWithPath: projectPath)
                if isTermHubProject(dir) { return dir }
            }
        }

        // 2. Check well-known locations
        let home = NSHomeDirectory()
        let candidates = [
            "\(home)/Projects/TermHub",
            "\(home)/Developer/TermHub",
            "\(home)/src/TermHub",
            "\(home)/Code/TermHub",
            "\(home)/TermHub",
        ]
        for path in candidates {
            let dir = URL(fileURLWithPath: path)
            if isTermHubProject(dir) { return dir }
        }

        return nil
    }

    private func isTermHubProject(_ dir: URL) -> Bool {
        let fm = FileManager.default
        return fm.fileExists(atPath: dir.appendingPathComponent("Package.swift").path)
            && fm.fileExists(atPath: dir.appendingPathComponent(".git").path)
    }

    func checkForUpdates() {
        state = .checking

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            if let dir = self.projectDir {
                self.updateFromExistingRepo(dir)
            } else {
                self.updateFromFreshClone()
            }
        }
    }

    // MARK: - Update from existing local repo

    private func updateFromExistingRepo(_ dir: URL) {
        let path = dir.path

        let fetchResult = shell("cd '\(path)' && git fetch origin main 2>&1")
        if fetchResult.status != 0 {
            setState(.failed("Failed to fetch: \(fetchResult.output)"))
            return
        }

        let diffResult = shell("cd '\(path)' && git log HEAD..origin/main --oneline 2>&1")
        if diffResult.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            setState(.upToDate)
            return
        }

        let commits = diffResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
        setState(.updateAvailable(commits: commits))

        setState(.downloading)
        let pullResult = shell("cd '\(path)' && git pull origin main 2>&1")
        if pullResult.status != 0 {
            setState(.failed("Failed to pull: \(pullResult.output)"))
            return
        }

        setState(.building)
        let buildResult = shell("cd '\(path)' && swift build 2>&1")
        if buildResult.status != 0 {
            setState(.failed("Build failed:\n\(String(buildResult.output.suffix(500)))"))
            return
        }

        // Copy built binary over the currently running one (if installed to /usr/local/bin)
        installBuiltBinary(from: dir)

        setState(.ready)
    }

    // MARK: - Update from fresh clone (no local repo found)

    private func updateFromFreshClone() {
        setState(.downloading)

        let tmpDir = NSTemporaryDirectory() + "TermHub-update-\(UUID().uuidString.prefix(8))"

        let cloneResult = shell("git clone --depth 1 '\(repoURL)' '\(tmpDir)' 2>&1")
        if cloneResult.status != 0 {
            setState(.failed("Failed to clone: \(cloneResult.output)"))
            return
        }

        setState(.building)
        let buildResult = shell("cd '\(tmpDir)' && swift build 2>&1")
        if buildResult.status != 0 {
            shell("rm -rf '\(tmpDir)'")
            setState(.failed("Build failed:\n\(String(buildResult.output.suffix(500)))"))
            return
        }

        // Install the built binary
        let builtBinary = "\(tmpDir)/.build/debug/TermHub"
        installBinary(from: builtBinary)

        // Cleanup
        shell("rm -rf '\(tmpDir)'")

        setState(.ready)
    }

    // MARK: - Install binary

    private func installBuiltBinary(from projectDir: URL) {
        let debugBinary = projectDir.appendingPathComponent(".build/debug/TermHub").path
        let releaseBinary = projectDir.appendingPathComponent(".build/release/TermHub").path
        let binary = FileManager.default.fileExists(atPath: releaseBinary) ? releaseBinary : debugBinary
        installBinary(from: binary)
    }

    private func installBinary(from builtPath: String) {
        guard let execPath = Bundle.main.executablePath else { return }
        let fm = FileManager.default

        // If running from .build/ (dev mode), no need to copy
        if execPath.contains(".build/") { return }

        // If running from /usr/local/bin or /Applications, copy the new binary
        if fm.isWritableFile(atPath: execPath) {
            shell("cp '\(builtPath)' '\(execPath)'")
        } else {
            // Need sudo — copy via osascript for privilege escalation
            shell("osascript -e 'do shell script \"cp \\\"\(builtPath)\\\" \\\"\(execPath)\\\"\" with administrator privileges' 2>&1")
        }

        // Also update /Applications bundle if it exists
        let appBinary = "/Applications/TermHub.app/Contents/MacOS/TermHub"
        if fm.fileExists(atPath: appBinary) && appBinary != execPath {
            if fm.isWritableFile(atPath: appBinary) {
                shell("cp '\(builtPath)' '\(appBinary)'")
            }
        }
    }

    func relaunch() {
        guard let execPath = Bundle.main.executablePath else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: execPath)
        process.arguments = []
        try? process.run()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NSApplication.shared.terminate(nil)
        }
    }

    private func setState(_ newState: State) {
        DispatchQueue.main.async { [weak self] in
            self?.state = newState
        }
    }

    @discardableResult
    private func shell(_ command: String) -> (output: String, status: Int32) {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        process.standardOutput = pipe
        process.standardError = pipe
        try? process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        return (output, process.terminationStatus)
    }
}

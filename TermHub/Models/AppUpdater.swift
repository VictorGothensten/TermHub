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

    /// Infer the project source directory from the running binary's path
    private var projectDir: URL? {
        guard let execPath = Bundle.main.executablePath else { return nil }
        let url = URL(fileURLWithPath: execPath)
        // If running from .build/debug/TermHub or .build/release/TermHub
        let components = url.pathComponents
        if let buildIdx = components.lastIndex(of: ".build"),
           buildIdx >= 1 {
            let projectPath = "/" + components[1..<buildIdx].joined(separator: "/")
            let dir = URL(fileURLWithPath: projectPath)
            // Verify it's actually a TermHub project
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("Package.swift").path) {
                return dir
            }
        }
        return nil
    }

    func checkForUpdates() {
        guard let dir = projectDir else {
            state = .failed("Can't find project directory. Reinstall from source.")
            return
        }

        state = .checking

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.performUpdate(in: dir)
        }
    }

    private func performUpdate(in dir: URL) {
        let path = dir.path

        // Fetch latest
        let fetchResult = shell("cd '\(path)' && git fetch origin main 2>&1")
        if fetchResult.status != 0 {
            setState(.failed("Failed to fetch updates: \(fetchResult.output)"))
            return
        }

        // Check if there are new commits
        let diffResult = shell("cd '\(path)' && git log HEAD..origin/main --oneline 2>&1")
        if diffResult.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            setState(.upToDate)
            return
        }

        let commits = diffResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
        setState(.updateAvailable(commits: commits))

        // Pull
        setState(.downloading)
        let pullResult = shell("cd '\(path)' && git pull origin main 2>&1")
        if pullResult.status != 0 {
            setState(.failed("Failed to pull: \(pullResult.output)"))
            return
        }

        // Build
        setState(.building)
        let buildResult = shell("cd '\(path)' && swift build 2>&1")
        if buildResult.status != 0 {
            setState(.failed("Build failed:\n\(buildResult.output.suffix(500))"))
            return
        }

        setState(.ready)
    }

    func relaunch() {
        guard let execPath = Bundle.main.executablePath else { return }

        // Launch new instance
        let process = Process()
        process.executableURL = URL(fileURLWithPath: execPath)
        process.arguments = []
        try? process.run()

        // Quit current
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NSApplication.shared.terminate(nil)
        }
    }

    private func setState(_ newState: State) {
        DispatchQueue.main.async { [weak self] in
            self?.state = newState
        }
    }

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

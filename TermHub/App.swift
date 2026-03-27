import SwiftUI
import AppKit

@main
struct TermHubApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    @StateObject private var updater = AppUpdater()
    @State private var showUpdateSheet = false

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.applicationIconImage = AppIcon.generate(size: 512)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 800, minHeight: 600)
                .onAppear {
                    appDelegate.appState = appState
                }
                .sheet(isPresented: $showUpdateSheet) {
                    UpdateView(updater: updater)
                }
        }
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Terminal") {
                    if let ws = appState.selectedWorkspace {
                        ws.addSession()
                        appState.objectWillChange.send()
                    }
                }
                .keyboardShortcut("t", modifiers: .command)

                Button("New Workspace") {
                    appState.showNewWorkspacePrompt = true
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])
            }

            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") {
                    updater.state = .idle
                    showUpdateSheet = true
                }
                .keyboardShortcut("u", modifiers: [.command, .shift])
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var appState: AppState?

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let appState = appState else { return .terminateNow }

        let activeSessions = appState.workspaces.flatMap { $0.sessions }.filter { $0.isAlive }
        guard !activeSessions.isEmpty else { return .terminateNow }

        let count = activeSessions.count
        let alert = NSAlert()
        alert.messageText = "Quit TermHub?"
        alert.informativeText = "You have \(count) active terminal session\(count == 1 ? "" : "s"). Any unsaved work will be lost.\n\nTip: Archive sessions to preserve their history before quitting."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Quit")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            appState.save()
            return .terminateNow
        }
        return .terminateCancel
    }
}

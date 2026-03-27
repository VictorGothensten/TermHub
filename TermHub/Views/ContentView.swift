import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var newWorkspaceName = ""

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Divider()

            if let workspace = appState.selectedWorkspace {
                if appState.showArchives {
                    ArchiveListView(
                        workspace: workspace,
                        onReopen: { archive in
                            appState.reopenArchive(archive, in: workspace)
                        },
                        onDelete: { archive in
                            appState.deleteArchive(archive, from: workspace)
                        },
                        onDismiss: {
                            appState.showArchives = false
                        }
                    )
                } else {
                    workspaceView(workspace: workspace)
                }
            } else {
                Text("No workspace")
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(nsColor: NSColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1.0)))
        .overlay {
            if appState.showQuickSwitcher {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture { appState.showQuickSwitcher = false }
                    QuickSwitcherView()
                        .environmentObject(appState)
                        .padding(.bottom, 200)
                }
            }
            if appState.showSnippets {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture { appState.showSnippets = false }
                    SnippetPaletteView(store: appState.snippetStore)
                        .environmentObject(appState)
                        .padding(.bottom, 200)
                }
            }
            if appState.showTemplates, appState.selectedWorkspace != nil {
                HStack {
                    Spacer()
                    TemplateView(
                        store: appState.templateStore,
                        onLaunch: { appState.launchTemplate($0) },
                        onDismiss: { appState.showTemplates = false }
                    )
                    .environmentObject(appState)
                }
            }
        }
        .sheet(isPresented: $appState.showNewWorkspacePrompt) {
            newWorkspaceSheet
        }
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Array(appState.workspaces.enumerated()), id: \.element.id) { index, workspace in
                tabButton(workspace: workspace, index: index)
            }

            Button(action: { appState.showNewWorkspacePrompt = true }) {
                Image(systemName: "plus")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(nsColor: NSColor(red: 0.15, green: 0.15, blue: 0.17, alpha: 1.0)))
    }

    private func tabButton(workspace: Workspace, index: Int) -> some View {
        WorkspaceTab(
            workspace: workspace,
            isSelected: index == appState.selectedWorkspaceIndex,
            canClose: appState.workspaces.count > 1,
            onSelect: { appState.selectWorkspace(at: index) },
            onClose: { appState.removeWorkspace(at: index) }
        )
    }

    // MARK: - Workspace View

    private func workspaceView(workspace: Workspace) -> some View {
        VStack(spacing: 0) {
            // Search bar
            if appState.showSearch {
                SearchBarView()
                    .environmentObject(appState)
                Divider()
            }

            // Broadcast indicator
            if appState.broadcastMode {
                HStack(spacing: 6) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 10))
                    Text("BROADCAST MODE — input sent to all terminals")
                        .font(.system(size: 10, weight: .medium))
                    Spacer()
                    Button("Stop") { appState.broadcastMode = false }
                        .font(.system(size: 10))
                        .buttonStyle(.plain)
                }
                .foregroundColor(.red)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.1))
            }

            // Zoom header
            if appState.zoomedSession != nil {
                HStack {
                    Button(action: { appState.zoomedSession = nil }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back to grid")
                        }
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.escape, modifiers: [])
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(nsColor: NSColor(red: 0.15, green: 0.15, blue: 0.17, alpha: 1.0)))
                Divider()
            }

            // Main content: grid + optional timeline sidebar
            HStack(spacing: 0) {
                TileGridView(
                    sessions: workspace.sessions,
                    zoomedSession: appState.zoomedSession,
                    onZoom: { session in
                        appState.zoomedSession = session
                    },
                    onUnzoom: {
                        appState.zoomedSession = nil
                    },
                    onClose: { session in
                        if appState.zoomedSession?.id == session.id {
                            appState.zoomedSession = nil
                        }
                        workspace.logEvent(.exited(code: nil), session: session)
                        workspace.removeSession(session)
                        appState.objectWillChange.send()
                    },
                    onArchive: { session in
                        workspace.logEvent(.archived, session: session)
                        appState.archiveSession(session, in: workspace)
                    },
                    onReorder: { fromId, toId in
                        workspace.moveSession(fromId: fromId, toId: toId)
                        appState.objectWillChange.send()
                    }
                )

                if appState.showTimeline {
                    Divider()
                    ActivityTimelineView(
                        events: workspace.activityLog,
                        onDismiss: { appState.showTimeline = false },
                        onJump: { sessionId in
                            if let session = workspace.sessions.first(where: { $0.id == sessionId }) {
                                appState.zoomedSession = session
                            }
                        }
                    )
                }
            }

            // Bottom bar
            if appState.zoomedSession == nil {
                HStack(spacing: 10) {
                    Button(action: {
                        workspace.addSession()
                        appState.objectWillChange.send()
                    }) {
                        Label("New Terminal", systemImage: "plus.rectangle")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.gray)

                    Spacer()

                    // Broadcast toggle
                    Button(action: { appState.broadcastMode.toggle() }) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(appState.broadcastMode ? .red : .gray.opacity(0.4))
                    .help("Broadcast mode")

                    // Timeline toggle
                    Button(action: { appState.showTimeline.toggle() }) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(appState.showTimeline ? .white : .gray.opacity(0.4))
                    .help("Activity timeline")

                    // Archives
                    Button(action: { appState.showArchives = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "archivebox")
                            if !workspace.archives.isEmpty {
                                Text("\(workspace.archives.count)")
                            }
                        }
                        .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(workspace.archives.isEmpty ? .gray.opacity(0.4) : .orange.opacity(0.7))
                    .help("View archived sessions")

                    Text("·")
                        .foregroundColor(.gray.opacity(0.3))

                    Text("\(workspace.sessions.count) terminal\(workspace.sessions.count == 1 ? "" : "s")")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(nsColor: NSColor(red: 0.15, green: 0.15, blue: 0.17, alpha: 1.0)))
            }
        }
    }

    // MARK: - New Workspace Sheet

    private var newWorkspaceSheet: some View {
        VStack(spacing: 16) {
            Text("New Workspace")
                .font(.headline)

            TextField("Name", text: $newWorkspaceName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 250)
                .onSubmit { createWorkspace() }

            HStack {
                Button("Cancel") {
                    appState.showNewWorkspacePrompt = false
                    newWorkspaceName = ""
                }
                Button("Create") { createWorkspace() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(newWorkspaceName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
    }

    private func createWorkspace() {
        let name = newWorkspaceName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        appState.addWorkspace(name: name)
        appState.showNewWorkspacePrompt = false
        newWorkspaceName = ""
    }
}

struct WorkspaceTab: View {
    @ObservedObject var workspace: Workspace
    let isSelected: Bool
    let canClose: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isEditing = false
    @State private var editText = ""

    var body: some View {
        HStack(spacing: 4) {
            if isEditing {
                TextField("Name", text: $editText, onCommit: {
                    let trimmed = editText.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty {
                        workspace.name = trimmed
                    }
                    isEditing = false
                })
                .textFieldStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .frame(minWidth: 40, maxWidth: 150)
                .onExitCommand { isEditing = false }
            } else {
                Text(workspace.name)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : .gray)
                    .onTapGesture(count: 2) {
                        editText = workspace.name
                        isEditing = true
                    }
                    .onTapGesture(count: 1) {
                        onSelect()
                    }
            }

            if canClose {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8))
                        .foregroundColor(.gray.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.white.opacity(0.1) : Color.clear)
        )
    }
}

import SwiftUI

struct QuickSwitcherView: View {
    @EnvironmentObject var appState: AppState
    @State private var query = ""
    @State private var selectedIndex = 0

    var matches: [(workspace: Workspace, workspaceIndex: Int, session: TerminalSession)] {
        let q = query.lowercased()
        var results: [(Workspace, Int, TerminalSession)] = []
        for (wi, ws) in appState.workspaces.enumerated() {
            for session in ws.sessions {
                if q.isEmpty || session.title.lowercased().contains(q) || ws.name.lowercased().contains(q) {
                    results.append((ws, wi, session))
                }
            }
        }
        return results
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Jump to terminal...", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .onSubmit { selectCurrent() }
            }
            .padding(12)
            .background(Color(nsColor: NSColor(red: 0.18, green: 0.18, blue: 0.20, alpha: 1.0)))

            Divider()

            // Results
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(matches.enumerated()), id: \.element.session.id) { index, match in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(dotColor(for: match.session))
                                .frame(width: 8, height: 8)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(match.session.title)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                                    .lineLimit(1)

                                Text(match.workspace.name)
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                            }

                            Spacer()

                            if match.session.isIdle {
                                Text("idle")
                                    .font(.system(size: 9))
                                    .foregroundColor(Color(red: 0.85, green: 0.65, blue: 0.2))
                            } else if !match.session.isAlive {
                                Text("exited")
                                    .font(.system(size: 9))
                                    .foregroundColor(.red.opacity(0.7))
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(index == selectedIndex ? Color.white.opacity(0.08) : Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture { jumpTo(match: match) }
                    }
                }
            }
            .frame(maxHeight: 300)

            if matches.isEmpty && !query.isEmpty {
                Text("No matching terminals")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .padding(16)
            }
        }
        .frame(width: 400)
        .background(Color(nsColor: NSColor(red: 0.14, green: 0.14, blue: 0.16, alpha: 1.0)))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 20)
        .onExitCommand { appState.showQuickSwitcher = false }
        .onChange(of: query) { _ in selectedIndex = 0 }
    }

    private func dotColor(for session: TerminalSession) -> Color {
        if !session.isAlive { return .red.opacity(0.7) }
        if session.isIdle { return Color(red: 0.85, green: 0.65, blue: 0.2) }
        return .green.opacity(0.7)
    }

    private func selectCurrent() {
        guard matches.indices.contains(selectedIndex) else { return }
        jumpTo(match: matches[selectedIndex])
    }

    private func jumpTo(match: (workspace: Workspace, workspaceIndex: Int, session: TerminalSession)) {
        appState.selectWorkspace(at: match.workspaceIndex)
        appState.zoomedSession = match.session
        appState.showQuickSwitcher = false
    }
}

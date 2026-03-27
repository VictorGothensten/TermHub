import SwiftUI

struct SnippetPaletteView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var store: SnippetStore
    @State private var query = ""
    @State private var isAdding = false
    @State private var newName = ""
    @State private var newCommand = ""

    var filtered: [Snippet] {
        if query.isEmpty { return store.snippets }
        let q = query.lowercased()
        return store.snippets.filter {
            $0.name.lowercased().contains(q) || $0.command.lowercased().contains(q)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search
            HStack(spacing: 8) {
                Image(systemName: "text.page")
                    .foregroundColor(.gray)
                TextField("Search snippets...", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .foregroundColor(.white)

                Button(action: { isAdding.toggle() }) {
                    Image(systemName: "plus")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(Color(nsColor: NSColor(red: 0.18, green: 0.18, blue: 0.20, alpha: 1.0)))

            Divider()

            if isAdding {
                addSnippetForm
                Divider()
            }

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filtered) { snippet in
                        snippetRow(snippet)
                    }
                }
            }
            .frame(maxHeight: 300)

            if filtered.isEmpty && !isAdding {
                Text(store.snippets.isEmpty ? "No snippets yet — click + to add" : "No matches")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .padding(16)
            }
        }
        .frame(width: 420)
        .background(Color(nsColor: NSColor(red: 0.14, green: 0.14, blue: 0.16, alpha: 1.0)))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 20)
        .onExitCommand { appState.showSnippets = false }
    }

    private func snippetRow(_ snippet: Snippet) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(snippet.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)

                Text(snippet.command)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }

            Spacer()

            Button("Run") { runSnippet(snippet) }
                .font(.system(size: 10))
                .buttonStyle(.plain)
                .foregroundColor(.blue)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.blue.opacity(0.15))
                .cornerRadius(4)

            Button(action: { store.delete(snippet) }) {
                Image(systemName: "trash")
                    .font(.system(size: 9))
                    .foregroundColor(.red.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture { runSnippet(snippet) }
    }

    private var addSnippetForm: some View {
        VStack(spacing: 8) {
            TextField("Name", text: $newName)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundColor(.white)
            TextField("Command", text: $newCommand)
                .textFieldStyle(.plain)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white)
            HStack {
                Spacer()
                Button("Cancel") { isAdding = false; newName = ""; newCommand = "" }
                    .font(.system(size: 11))
                    .buttonStyle(.plain)
                    .foregroundColor(.gray)
                Button("Save") {
                    guard !newName.isEmpty, !newCommand.isEmpty else { return }
                    store.add(name: newName, command: newCommand)
                    newName = ""; newCommand = ""; isAdding = false
                }
                .font(.system(size: 11))
                .buttonStyle(.plain)
                .foregroundColor(.blue)
            }
        }
        .padding(12)
        .background(Color(nsColor: NSColor(red: 0.16, green: 0.16, blue: 0.18, alpha: 1.0)))
    }

    private func runSnippet(_ snippet: Snippet) {
        guard let ws = appState.selectedWorkspace else { return }
        // Send to the zoomed session or the first session
        let target = appState.zoomedSession ?? ws.sessions.first
        if let session = target {
            let bytes = Array((snippet.command + "\n").utf8)
            session.terminalView.getTerminal().sendResponse(bytes)
        }
        appState.showSnippets = false
    }
}

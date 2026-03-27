import SwiftUI

struct SearchMatch: Identifiable {
    let id = UUID()
    let sessionTitle: String
    let sessionId: UUID
    let lineNumber: Int
    let lineText: String
    let matchRange: Range<String.Index>
}

struct SearchBarView: View {
    @EnvironmentObject var appState: AppState
    @State private var query = ""
    @State private var results: [SearchMatch] = []

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search across all terminals...", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                    .onSubmit { performSearch() }

                if !query.isEmpty {
                    Text("\(results.count) match\(results.count == 1 ? "" : "es")")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)

                    Button(action: { query = ""; results = [] }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                }

                Button(action: { appState.showSearch = false }) {
                    Text("Done")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
            .padding(10)
            .background(Color(nsColor: NSColor(red: 0.16, green: 0.16, blue: 0.18, alpha: 1.0)))

            if !results.isEmpty {
                Divider()
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(results) { match in
                            HStack(spacing: 8) {
                                Text(match.sessionTitle)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.blue.opacity(0.7))
                                    .frame(width: 100, alignment: .trailing)
                                    .lineLimit(1)

                                Text(":\(match.lineNumber)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.gray)

                                Text(match.lineText.trimmingCharacters(in: .whitespaces))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.8))
                                    .lineLimit(1)

                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                jumpToMatch(match)
                            }
                        }
                    }
                }
                .frame(maxHeight: 150)
                .background(Color(nsColor: NSColor(red: 0.13, green: 0.13, blue: 0.15, alpha: 1.0)))
            }
        }
    }

    private func performSearch() {
        guard !query.isEmpty, let workspace = appState.selectedWorkspace else {
            results = []
            return
        }

        var matches: [SearchMatch] = []
        for session in workspace.sessions {
            let buffer = session.extractBufferText()
            let lines = buffer.components(separatedBy: "\n")
            for (lineIdx, line) in lines.enumerated() {
                if let range = line.range(of: query, options: .caseInsensitive) {
                    matches.append(SearchMatch(
                        sessionTitle: session.title,
                        sessionId: session.id,
                        lineNumber: lineIdx + 1,
                        lineText: String(line.prefix(200)),
                        matchRange: range
                    ))
                }
                if matches.count >= 100 { break }
            }
            if matches.count >= 100 { break }
        }
        results = matches
    }

    private func jumpToMatch(_ match: SearchMatch) {
        if let session = appState.selectedWorkspace?.sessions.first(where: { $0.id == match.sessionId }) {
            appState.zoomedSession = session
        }
    }
}

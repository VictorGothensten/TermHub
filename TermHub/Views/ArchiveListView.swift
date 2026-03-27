import SwiftUI

struct ArchiveListView: View {
    let workspace: Workspace
    let onReopen: (ArchivedSession) -> Void
    let onDelete: (ArchivedSession) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onDismiss) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back to terminals")
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                }
                .buttonStyle(.plain)

                Spacer()

                Text("Archives")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))

                Spacer()

                Text("\(workspace.archives.count) archived")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: NSColor(red: 0.15, green: 0.15, blue: 0.17, alpha: 1.0)))

            Divider()

            if workspace.archives.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "archivebox")
                        .font(.system(size: 32))
                        .foregroundColor(.gray.opacity(0.4))
                    Text("No archived sessions")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                    Text("Archive a terminal to save its history here")
                        .font(.system(size: 11))
                        .foregroundColor(.gray.opacity(0.6))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(workspace.archives) { archive in
                            ArchiveRow(
                                archive: archive,
                                onReopen: { onReopen(archive) },
                                onDelete: { onDelete(archive) }
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .background(Color(nsColor: NSColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1.0)))
    }
}

struct ArchiveRow: View {
    let archive: ArchivedSession
    let onReopen: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row
            HStack(alignment: .top, spacing: 10) {
                // Icon
                Image(systemName: "archivebox.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.orange.opacity(0.7))
                    .frame(width: 20)

                // Info
                VStack(alignment: .leading, spacing: 3) {
                    Text(archive.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text(archive.formattedDate)
                            .font(.system(size: 10))
                            .foregroundColor(.gray)

                        if let dir = archive.workingDirectory {
                            Text(shortenPath(dir))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.gray.opacity(0.7))
                                .lineLimit(1)
                        }
                    }

                    // Preview
                    if !archive.preview.isEmpty {
                        Text(archive.preview)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.gray.opacity(0.5))
                            .lineLimit(isExpanded ? 20 : 2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Spacer()

                // Actions
                if isHovering {
                    HStack(spacing: 6) {
                        Button(action: onReopen) {
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.uturn.left")
                                Text("Reopen")
                            }
                            .font(.system(size: 10))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.15))
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)

                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.system(size: 10))
                                .foregroundColor(.red.opacity(0.7))
                                .padding(4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .onTapGesture { isExpanded.toggle() }
            .onHover { isHovering = $0 }
            .background(isHovering ? Color.white.opacity(0.03) : Color.clear)
        }
    }

    private func shortenPath(_ path: String) -> String {
        let home = NSHomeDirectory()
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
}

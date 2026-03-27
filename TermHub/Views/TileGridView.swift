import SwiftUI

struct TileGridView: View {
    let sessions: [TerminalSession]
    let zoomedSession: TerminalSession?
    let onZoom: (TerminalSession) -> Void
    let onUnzoom: () -> Void
    let onClose: (TerminalSession) -> Void
    let onArchive: (TerminalSession) -> Void
    var onReorder: ((UUID, UUID) -> Void)? = nil

    private let gap: CGFloat = 2

    var body: some View {
        GeometryReader { geo in
            let frames = tileFrames(count: sessions.count, in: geo.size)

            ZStack(alignment: .topLeading) {
                ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                    if index < frames.count {
                        let isZoomed = session.id == zoomedSession?.id
                        let isAnyZoomed = zoomedSession != nil

                        TileView(
                            session: session,
                            index: index,
                            isZoomed: isZoomed,
                            onZoom: { isZoomed ? onUnzoom() : onZoom(session) },
                            onClose: { onClose(session) },
                            onArchive: { onArchive(session) }
                        )
                        .frame(
                            width: isZoomed ? geo.size.width : frames[index].width,
                            height: isZoomed ? geo.size.height : frames[index].height
                        )
                        .offset(
                            x: isZoomed ? 0 : frames[index].origin.x,
                            y: isZoomed ? 0 : frames[index].origin.y
                        )
                        .zIndex(isZoomed ? 1 : 0)
                        .opacity(isZoomed || !isAnyZoomed ? 1 : 0)
                        .allowsHitTesting(isZoomed || !isAnyZoomed)
                        .draggable(session.id.uuidString) {
                            Text(session.title)
                                .font(.system(size: 11))
                                .padding(6)
                                .background(Color(nsColor: NSColor(red: 0.2, green: 0.2, blue: 0.22, alpha: 0.9)))
                                .cornerRadius(4)
                        }
                        .dropDestination(for: String.self) { items, _ in
                            guard let draggedId = items.first,
                                  let fromId = UUID(uuidString: draggedId) else { return false }
                            onReorder?(fromId, session.id)
                            return true
                        }
                    }
                }
            }
        }
    }

    private func tileFrames(count: Int, in size: CGSize) -> [CGRect] {
        guard count > 0 else { return [] }

        let cols = Int(ceil(sqrt(Double(count))))
        let rows = Int(ceil(Double(count) / Double(cols)))

        let tileW = (size.width - gap * CGFloat(cols - 1)) / CGFloat(cols)
        let tileH = (size.height - gap * CGFloat(rows - 1)) / CGFloat(rows)

        var frames: [CGRect] = []
        for i in 0..<count {
            let col = i % cols
            let row = i / cols
            let x = CGFloat(col) * (tileW + gap)
            let y = CGFloat(row) * (tileH + gap)
            frames.append(CGRect(x: x, y: y, width: tileW, height: tileH))
        }
        return frames
    }
}

struct TileView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var session: TerminalSession
    let index: Int
    let isZoomed: Bool
    let onZoom: () -> Void
    let onClose: () -> Void
    let onArchive: () -> Void

    @State private var isHovering = false
    @State private var isEditingTitle = false
    @State private var editText = ""

    var body: some View {
        VStack(spacing: 0) {
            // Restore banner
            if let archive = session.restoredFrom {
                restoreBanner(archive: archive)
            }

            // Header bar
            HStack(spacing: 6) {
                Circle()
                    .fill(statusDotColor)
                    .frame(width: 8, height: 8)

                if isEditingTitle {
                    TextField("Name", text: $editText, onCommit: {
                        session.rename(editText)
                        isEditingTitle = false
                    })
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: 200)
                    .onExitCommand {
                        isEditingTitle = false
                    }
                } else {
                    Text(session.title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .onTapGesture(count: 2) {
                            editText = session.title
                            isEditingTitle = true
                        }
                }

                Spacer()

                if isHovering || isZoomed {
                    Button(action: onZoom) {
                        Image(systemName: isZoomed
                              ? "arrow.down.right.and.arrow.up.left"
                              : "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                    .help(isZoomed ? "Back to grid" : "Zoom terminal")
                }

                if isHovering {
                    Button(action: { session.notifyOnIdle.toggle(); if session.notifyOnIdle { NotificationManager.shared.requestPermission() } }) {
                        Image(systemName: session.notifyOnIdle ? "bell.fill" : "bell")
                            .font(.system(size: 10))
                            .foregroundColor(session.notifyOnIdle ? .yellow : .gray)
                    }
                    .buttonStyle(.plain)
                    .help(session.notifyOnIdle ? "Disable notifications" : "Notify when idle")

                    Button(action: onArchive) {
                        Image(systemName: "archivebox")
                            .font(.system(size: 10))
                            .foregroundColor(.orange.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .help("Archive session")

                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                    .help("Close terminal")
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) { onZoom() }
            .background(Color(nsColor: NSColor(red: 0.18, green: 0.18, blue: 0.20, alpha: 1.0)))

            // Archive context viewer (collapsible, above terminal)
            if session.showArchiveContext, let archive = session.restoredFrom {
                archiveContextView(archive: archive)
            }

            // Terminal
            TerminalViewWrapper(session: session)
        }
        .clipShape(RoundedRectangle(cornerRadius: isZoomed ? 0 : 4))
        .overlay(
            RoundedRectangle(cornerRadius: isZoomed ? 0 : 4)
                .stroke(tileBorderColor, lineWidth: session.isIdle && !isZoomed ? 1.5 : 1)
        )
        .animation(.easeInOut(duration: 0.4), value: session.isIdle)
        .onHover { isHovering = $0 }
    }

    private var statusDotColor: Color {
        if !session.isAlive { return Color.red.opacity(0.7) }
        if session.isIdle { return Color(red: 0.85, green: 0.65, blue: 0.2).opacity(0.9) } // golden
        return Color.green.opacity(0.7)
    }

    private var tileBorderColor: Color {
        if isZoomed { return .clear }
        if appState.broadcastMode { return Color.red.opacity(0.5) }
        if session.isIdle && session.isAlive {
            return Color(red: 0.85, green: 0.65, blue: 0.2).opacity(0.6) // golden
        }
        if isHovering { return Color.white.opacity(0.2) }
        return Color.white.opacity(0.05)
    }

    private func restoreBanner(archive: ArchivedSession) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.uturn.left.circle.fill")
                .font(.system(size: 11))
                .foregroundColor(.blue.opacity(0.7))

            Text("Restored from \(archive.formattedDate)")
                .font(.system(size: 10))
                .foregroundColor(.gray)

            if let dir = archive.workingDirectory {
                Text("·")
                    .foregroundColor(.gray.opacity(0.4))
                Text(shortenPath(dir))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.gray.opacity(0.6))
                    .lineLimit(1)
            }

            Spacer()

            Button(action: {
                session.showArchiveContext.toggle()
            }) {
                HStack(spacing: 3) {
                    Image(systemName: session.showArchiveContext ? "eye.slash" : "eye")
                    Text(session.showArchiveContext ? "Hide history" : "Show history")
                }
                .font(.system(size: 9))
                .foregroundColor(.blue.opacity(0.6))
            }
            .buttonStyle(.plain)

            Button(action: {
                session.restoredFrom = nil
                session.showArchiveContext = false
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 8))
                    .foregroundColor(.gray.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color.blue.opacity(0.08))
    }

    private func archiveContextView(archive: ArchivedSession) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                Text(archive.bufferText)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 200)
            .background(Color(nsColor: NSColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1.0)))

            Divider()
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

import SwiftUI

struct ActivityTimelineView: View {
    let events: [ActivityEvent]
    let onDismiss: () -> Void
    let onJump: (UUID) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Activity")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(nsColor: NSColor(red: 0.15, green: 0.15, blue: 0.17, alpha: 1.0)))

            Divider()

            if events.isEmpty {
                Text("No activity yet")
                    .font(.system(size: 11))
                    .foregroundColor(.gray.opacity(0.5))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(events.reversed()) { event in
                                eventRow(event)
                                    .id(event.id)
                            }
                        }
                    }
                    .onChange(of: events.count) { _ in
                        if let last = events.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .frame(width: 240)
        .background(Color(nsColor: NSColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1.0)))
    }

    private func eventRow(_ event: ActivityEvent) -> some View {
        HStack(spacing: 6) {
            Image(systemName: event.eventType.icon)
                .font(.system(size: 9))
                .foregroundColor(iconColor(for: event.eventType))
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 1) {
                Text(event.sessionTitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)

                Text(event.eventType.label)
                    .font(.system(size: 9))
                    .foregroundColor(.gray)
            }

            Spacer()

            Text(event.relativeTime)
                .font(.system(size: 9))
                .foregroundColor(.gray.opacity(0.5))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .onTapGesture { onJump(event.sessionId) }
    }

    private func iconColor(for type: ActivityEvent.EventType) -> Color {
        switch type {
        case .created: return .green.opacity(0.7)
        case .wentIdle: return Color(red: 0.85, green: 0.65, blue: 0.2)
        case .resumed: return .green.opacity(0.7)
        case .exited: return .red.opacity(0.7)
        case .titleChanged: return .blue.opacity(0.7)
        case .archived: return .orange.opacity(0.7)
        }
    }
}

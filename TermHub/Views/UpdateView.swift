import SwiftUI

struct UpdateView: View {
    @ObservedObject var updater: AppUpdater
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            switch updater.state {
            case .idle, .checking:
                ProgressView()
                    .scaleEffect(0.8)
                Text("Checking for updates...")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)

            case .updateAvailable(let commits):
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.blue)
                Text("Update available")
                    .font(.system(size: 14, weight: .semibold))
                Text(commits)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.gray)
                    .frame(maxWidth: 350)
                    .lineLimit(8)

            case .downloading:
                ProgressView()
                    .scaleEffect(0.8)
                Text("Pulling latest changes...")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)

            case .building:
                ProgressView()
                    .scaleEffect(0.8)
                Text("Building...")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                Text("This may take a moment")
                    .font(.system(size: 11))
                    .foregroundColor(.gray.opacity(0.6))

            case .ready:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.green)
                Text("Update installed!")
                    .font(.system(size: 14, weight: .semibold))
                Text("Restart TermHub to use the new version.")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)

                Button("Restart Now") {
                    updater.relaunch()
                }
                .keyboardShortcut(.defaultAction)

            case .upToDate:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.green)
                Text("You're up to date!")
                    .font(.system(size: 14, weight: .semibold))

                Button("OK") { dismiss() }
                    .keyboardShortcut(.defaultAction)

            case .failed(let message):
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.orange)
                Text("Update failed")
                    .font(.system(size: 14, weight: .semibold))
                Text(message)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.gray)
                    .frame(maxWidth: 350)
                    .lineLimit(10)

                Button("Dismiss") { dismiss() }
            }
        }
        .padding(30)
        .frame(minWidth: 300)
        .onAppear {
            if updater.state == .idle {
                updater.checkForUpdates()
            }
        }
    }
}

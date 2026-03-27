import SwiftUI

struct TemplateView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var store: TemplateStore
    let onLaunch: (SessionTemplate) -> Void
    let onDismiss: () -> Void

    @State private var isSaving = false
    @State private var templateName = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Templates")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Button(action: { isSaving.toggle() }) {
                    Label("Save Current", systemImage: "square.and.arrow.down")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundColor(.blue.opacity(0.7))

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: NSColor(red: 0.15, green: 0.15, blue: 0.17, alpha: 1.0)))

            if isSaving {
                HStack {
                    TextField("Template name", text: $templateName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                    Button("Save") {
                        guard !templateName.isEmpty, let ws = appState.selectedWorkspace else { return }
                        store.saveTemplate(name: templateName, from: ws)
                        templateName = ""; isSaving = false
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
                }
                .padding(10)
                .background(Color(nsColor: NSColor(red: 0.16, green: 0.16, blue: 0.18, alpha: 1.0)))
            }

            Divider()

            if store.templates.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 24))
                        .foregroundColor(.gray.opacity(0.3))
                    Text("No templates yet")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(20)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(store.templates) { template in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(template.name)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white)
                                    Text("\(template.sessions.count) terminal\(template.sessions.count == 1 ? "" : "s")")
                                        .font(.system(size: 10))
                                        .foregroundColor(.gray)
                                }

                                Spacer()

                                Button("Launch") { onLaunch(template) }
                                    .font(.system(size: 10))
                                    .buttonStyle(.plain)
                                    .foregroundColor(.green.opacity(0.8))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.green.opacity(0.12))
                                    .cornerRadius(4)

                                Button(action: { store.delete(template) }) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 9))
                                        .foregroundColor(.red.opacity(0.5))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
        }
        .frame(width: 350)
        .background(Color(nsColor: NSColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1.0)))
    }
}

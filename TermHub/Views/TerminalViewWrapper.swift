import SwiftUI
import AppKit
import SwiftTerm

struct TerminalViewWrapper: NSViewRepresentable {
    let session: TerminalSession

    func makeNSView(context: Context) -> NSView {
        let container = NSView(frame: .zero)
        attachTerminalView(to: container)
        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        let termView = session.terminalView
        if termView.superview !== nsView {
            attachTerminalView(to: nsView)
        }
        // Always ensure a redraw after layout changes
        DispatchQueue.main.async {
            termView.needsDisplay = true
            termView.needsLayout = true
        }
    }

    private func attachTerminalView(to container: NSView) {
        let termView = session.terminalView

        // Remove from old parent
        container.subviews.forEach { $0.removeFromSuperview() }
        termView.removeFromSuperview()

        // Remove any stale constraints on the terminal view
        termView.translatesAutoresizingMaskIntoConstraints = false
        for constraint in termView.constraints {
            if constraint.firstItem === termView && constraint.secondItem != nil {
                constraint.isActive = false
            }
        }

        container.addSubview(termView)

        NSLayoutConstraint.activate([
            termView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            termView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            termView.topAnchor.constraint(equalTo: container.topAnchor),
            termView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        // Force layout + display and grab focus
        DispatchQueue.main.async {
            termView.needsLayout = true
            termView.needsDisplay = true
            termView.layoutSubtreeIfNeeded()
            termView.window?.makeFirstResponder(termView)
        }
    }
}

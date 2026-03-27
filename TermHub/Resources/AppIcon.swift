import AppKit
import CoreGraphics

enum AppIcon {
    static func generate(size: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        guard let ctx = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return image
        }

        let s = size
        let rect = CGRect(x: 0, y: 0, width: s, height: s)

        // --- Background: dark rounded squircle with subtle gradient ---
        let cornerRadius = s * 0.22
        let bgPath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)

        // Gradient: slightly lighter center
        let bgColors = [
            CGColor(red: 0.14, green: 0.14, blue: 0.17, alpha: 1.0),
            CGColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 1.0),
        ]
        ctx.saveGState()
        bgPath.addClip()
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                     colors: bgColors as CFArray,
                                     locations: [0.0, 1.0]) {
            ctx.drawRadialGradient(gradient,
                                   startCenter: CGPoint(x: s * 0.5, y: s * 0.55),
                                   startRadius: 0,
                                   endCenter: CGPoint(x: s * 0.5, y: s * 0.5),
                                   endRadius: s * 0.7,
                                   options: .drawsAfterEndLocation)
        }
        ctx.restoreGState()

        // --- Tile grid: 2x2 with gap ---
        let margin = s * 0.18
        let gap = s * 0.04
        let gridSize = s - margin * 2
        let tileSize = (gridSize - gap) / 2
        let tileRadius = s * 0.05

        let teal = NSColor(red: 0.31, green: 0.76, blue: 0.97, alpha: 1.0) // #4FC3F7

        let positions: [(CGFloat, CGFloat)] = [
            (margin, margin + tileSize + gap),               // top-left
            (margin + tileSize + gap, margin + tileSize + gap), // top-right
            (margin, margin),                                 // bottom-left
            (margin + tileSize + gap, margin),                // bottom-right
        ]

        for (x, y) in positions {
            let tileRect = CGRect(x: x, y: y, width: tileSize, height: tileSize)

            // Tile background
            let tileBg = NSColor(red: 0.16, green: 0.16, blue: 0.19, alpha: 1.0)
            tileBg.setFill()
            let tilePath = NSBezierPath(roundedRect: tileRect, xRadius: tileRadius, yRadius: tileRadius)
            tilePath.fill()

            // Tile border (subtle)
            teal.withAlphaComponent(0.3).setStroke()
            tilePath.lineWidth = s * 0.004
            tilePath.stroke()

            // ">_" prompt text
            let fontSize = tileSize * 0.32
            let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .bold)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: teal,
            ]
            let prompt = ">_"
            let textSize = prompt.size(withAttributes: attrs)
            let textX = tileRect.midX - textSize.width / 2
            let textY = tileRect.midY - textSize.height / 2
            prompt.draw(at: NSPoint(x: textX, y: textY), withAttributes: attrs)
        }

        // --- Subtle outer glow/border ---
        teal.withAlphaComponent(0.15).setStroke()
        bgPath.lineWidth = s * 0.008
        bgPath.stroke()

        image.unlockFocus()
        return image
    }
}

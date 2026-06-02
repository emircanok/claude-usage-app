import SwiftUI

/// Threshold colors for a utilization percentage (0-100).
enum UsageColor {
    static func color(for utilization: Double) -> Color {
        switch utilization {
        case ..<70:
            return .green
        case 70 ..< 90:
            return .orange
        default:
            return .red
        }
    }
}

/// Renders the menu bar label. `MenuBarExtra` treats SF Symbols and plain Text
/// as template images (monochrome, system-tinted), so to keep our own color we
/// render a SwiftUI view into a non-template NSImage.
@MainActor
enum LabelRenderer {
    static func image(text: String, color: Color) -> NSImage {
        let content = Text(text)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 2)

        let renderer = ImageRenderer(content: content)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2.0

        let image = renderer.nsImage ?? NSImage()
        image.isTemplate = false // keep our color; don't let the system tint it
        return image
    }
}

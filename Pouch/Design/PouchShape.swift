import SwiftUI

/// The shelf's silhouette: snug top corners, deep rounded bottom, like a pouch.
struct PouchShape: Shape {
    func path(in rect: CGRect) -> Path {
        UnevenRoundedRectangle(
            topLeadingRadius: 16,
            bottomLeadingRadius: 34,
            bottomTrailingRadius: 34,
            topTrailingRadius: 16,
            style: .continuous
        )
        .path(in: rect)
    }
}

/// The dashed "stitching" under the header. It lights up while something is
/// being dragged over the shelf.
struct SeamLine: View {
    var isActive: Bool
    @Environment(\.theme) private var theme

    var body: some View {
        HorizontalLine()
            .stroke(
                theme.accent.opacity(isActive ? 1 : 0.45),
                style: StrokeStyle(lineWidth: isActive ? 2 : 1.5, lineCap: .round, dash: [5, 4])
            )
            .frame(height: 2)
            .shadow(color: isActive ? theme.accent.opacity(0.8) : .clear, radius: 4)
            .padding(.horizontal, 14)
            .accessibilityHidden(true)
    }
}

private struct HorizontalLine: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        }
    }
}

/// The material behind the shelf. Uses Liquid Glass on macOS 26+, and a
/// behind-window `NSVisualEffectView` before that.
struct PouchBackground: View {
    @Environment(\.theme) private var theme

    var body: some View {
        if #available(macOS 26.0, *) {
            Color.clear
                .glassEffect(.regular.tint(theme.accent.opacity(0.10)), in: PouchShape())
        } else {
            VisualEffectBackground()
                .overlay(theme.accent.opacity(0.06))
                .clipShape(PouchShape())
        }
    }
}

private struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        // Our panel is rarely the key window; without `.active` the material
        // would render in its flat "inactive window" look most of the time.
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

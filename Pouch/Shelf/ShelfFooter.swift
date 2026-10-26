import SwiftUI

/// The bottom of the pouch: a woven brand label, how many things are inside,
/// and the one action that empties it.
struct ShelfFooter: View {
    var count: Int
    var onEmpty: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            // The seam along the bottom of the pouch.
            Line()
                .stroke(Palette.ink.opacity(0.16), style: .stitch(width: 1))
                .frame(height: 1)
                .padding(.horizontal, 16)
                .opacity(count > 0 ? 1 : 0)
            content
        }
    }

    private var content: some View {
        HStack(spacing: 8) {
            WovenLabel()
            Text(summary)
                .font(.system(size: 11))
                .foregroundStyle(Palette.inkSecondary)
                .contentTransition(.numericText())
                .animation(.pouchLand, value: count)
                .allowsHitTesting(false)
            Spacer(minLength: 0)
            if count > 0 {
                Button("Empty", action: onEmpty)
                    .buttonStyle(TextActionStyle())
                    .help("Shake everything out. Your files stay where they are.")
                    .transition(.opacity)
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 18)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    private var summary: String {
        switch count {
        case 0: "empty"
        case 1: "1 thing"
        default: "\(count) things"
        }
    }
}

private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        }
    }
}

/// Like the label sewn into a bag's seam.
private struct WovenLabel: View {
    @Environment(\.theme) private var theme

    var body: some View {
        Text("POUCH")
            .font(.system(size: 7, weight: .heavy))
            .tracking(1.4)
            .foregroundStyle(theme.thread)
            .padding(.horizontal, 5)
            .padding(.vertical, 2.5)
            .background(theme.flap)
            .overlay(Rectangle().strokeBorder(theme.thread.opacity(0.5), style: StrokeStyle(lineWidth: 0.6, dash: [1.4, 1.2])).padding(1.2))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// A plain text button in the accent color; it only shows a background
/// while pressed.
private struct TextActionStyle: ButtonStyle {
    @Environment(\.theme) private var theme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(theme.accent)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(theme.accent.opacity(configuration.isPressed ? 0.14 : 0), in: RoundedRectangle(cornerRadius: 4))
            .contentShape(Rectangle())
    }
}

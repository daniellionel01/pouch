import SwiftUI

/// The bottom of the pouch: how many items are inside and a way to clear
/// them. Only shown when there's something to count.
struct ShelfFooter: View {
    var count: Int
    var onClear: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // The seam along the bottom of the pouch.
            Line()
                .stroke(Palette.ink.opacity(0.16), style: .stitch(width: 1))
                .frame(height: 1)
                .padding(.horizontal, 16)
            HStack {
                Text(count == 1 ? "1 item" : "\(count) items")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.inkSecondary)
                    .contentTransition(.numericText())
                    .animation(.pouchLand, value: count)
                    .allowsHitTesting(false)
                Spacer(minLength: 0)
                Button("Clear all", action: onClear)
                    .buttonStyle(TextActionStyle())
                    .help("Removes everything from Pouch. The files themselves aren't touched.")
            }
            .padding(.leading, 18)
            .padding(.trailing, 14)
            .padding(.top, 8)
            .padding(.bottom, 14)
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

import PouchCore
import SwiftUI

/// What's left on screen while the shelf is tucked away: a stitched leather
/// tongue sticking out from the screen edge. It's a handle, not a face; the
/// character lives in the pouch. Its one detail is the number of items,
/// pressed into the leather. Life comes from motion: it leans out when you
/// hover and knocks against the edge when something arrives.
struct TuckedTab: View {
    static let size = CGSize(width: ShelfPanel.tuckedWidth - ShelfPanel.margin, height: ShelfPanel.tuckedHeight - ShelfPanel.margin * 2)

    var count: Int
    var side: DockSide
    var isHovered: Bool
    /// Bumped when something arrives while tucked.
    var knocks: Int

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Rounded on the side facing the screen, square where it goes into
        // the edge.
        let radius: CGFloat = 12
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: side == .right ? radius : 0,
            bottomLeadingRadius: side == .right ? radius : 0,
            bottomTrailingRadius: side == .left ? radius : 0,
            topTrailingRadius: side == .left ? radius : 0,
            style: .continuous
        )
        // Out from the screen edge is -x on the right, +x on the left.
        let outward: CGFloat = side == .right ? -1 : 1
        let hoverLean: CGFloat = isHovered && !reduceMotion ? 3 : 0
        let reduceMotion = reduceMotion

        KeyframeAnimator(initialValue: 0.0, trigger: knocks) { knock in
            ZStack {
                shape
                    .fill(theme.flap)
                    .leatherGrain()
                    .clipShape(shape)
                // Burnished edge, like the flap.
                shape
                    .stroke(.black.opacity(0.32), lineWidth: 2)
                    .clipShape(shape)
                shape
                    .inset(by: 4.5)
                    .stroke(theme.thread.opacity(0.9), style: .stitch(width: 1.3))
                if count > 0 {
                    Debossed(text: count > 99 ? "99+" : "\(count)")
                        .contentTransition(.numericText())
                        .animation(.pouchLand, value: count)
                }
            }
            .frame(width: Self.size.width, height: Self.size.height)
            .offset(x: outward * (hoverLean + (reduceMotion ? 0 : knock)))
        } keyframes: { _ in
            // A knock: out, back past rest against the edge, settle.
            KeyframeTrack {
                CubicKeyframe(4, duration: 0.09)
                CubicKeyframe(-0.5, duration: 0.12)
                SpringKeyframe(0, duration: 0.25, spring: .snappy)
            }
        }
        .animation(.pouchCharacter, value: isHovered)
        .accessibilityElement()
        .accessibilityLabel(count == 0 ? "Pouch, empty" : "Pouch, \(count) items")
        .accessibilityHint("Hover or click to open the shelf")
    }
}

/// Text stamped into leather: darker than the surface, with a thin catch of
/// light on the lower edge where the impression ends.
private struct Debossed: View {
    var text: String

    var body: some View {
        let label = Text(text)
            .font(.system(size: 13, weight: .bold, design: .serif))
            .minimumScaleFactor(0.6)
            .lineLimit(1)
        ZStack {
            label
                .foregroundStyle(.white.opacity(0.16))
                .offset(y: 0.7)
            label
                .foregroundStyle(.black.opacity(0.48))
        }
        .padding(.horizontal, 4)
        .accessibilityHidden(true)
    }
}

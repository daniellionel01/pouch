import PouchCore
import SwiftUI

/// What's left on screen while the shelf is tucked away: a stitched leather
/// tongue sticking out from the screen edge, with one eye. It shares the
/// shelf's character, so the eye follows the cursor, blinks and sleeps.
struct TuckedTab: View {
    static let size = CGSize(width: ShelfPanel.tuckedWidth - ShelfPanel.margin, height: ShelfPanel.tuckedHeight - ShelfPanel.margin * 2)

    var character: Character
    var side: DockSide
    /// The cursor is resting on the tab: it leans out a little, as
    /// anticipation before the shelf slides out.
    var isHovered: Bool

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
            EyeView(
                side: .left,
                expression: character.expression,
                isBlinking: character.isBlinking,
                look: character.look,
                lidColor: theme.flap
            )
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .offset(x: isHovered && !reduceMotion ? (side == .right ? -3 : 3) : 0)
        .animation(.pouchCharacter, value: isHovered)
        .accessibilityElement()
        .accessibilityLabel("Pouch")
        .accessibilityHint("Hover or click to open the shelf")
    }
}

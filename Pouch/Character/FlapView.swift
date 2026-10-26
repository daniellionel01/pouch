import SwiftUI

/// The top of the pouch: a stitched leather flap with the face on it. The
/// flap's tip is the pouch's mouth: it lifts while something hovers over the
/// shelf. There are no controls on it; it's all character.
struct FlapView: View {
    static let height: CGFloat = 66

    /// How far the face slides toward the visible edge while tucked: far
    /// enough that one eye sits in the strip left on screen.
    static let peekDistance: CGFloat = 80

    var character: Character
    var isOpen: Bool
    var peekOffset: CGFloat = 0

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let lift: CGFloat = isOpen && !reduceMotion ? 1 : 0
        KeyframeAnimator(initialValue: 0.0, trigger: character.sighs) { sigh in
            let flap = FlapShape(lift: lift + sigh)
            ZStack(alignment: .top) {
                // The inside of the pouch, exposed when the flap lifts.
                FlapShape(lift: 0)
                    .fill(Palette.lining)
                flap
                    .fill(theme.flap)
                    .leatherGrain()
                    .clipShape(flap)
                    // The flap's thickness, as a soft shadow on the body.
                    .shadow(color: .black.opacity(0.28), radius: 1.6, y: 1.2)
                // Burnished edge: leather edges are sealed darker than the face.
                flap
                    .stroke(.black.opacity(0.32), lineWidth: 2)
                    .clipShape(flap)
                // Saddle stitching, set in from the edge.
                FlapShape(lift: lift + sigh, inset: 6)
                    .stroke(theme.thread.opacity(0.9), style: .stitch(width: 1.4))
                // The face rides up a little as the flap lifts.
                FaceView(character: character, lidColor: theme.flap)
                    .offset(x: peekOffset, y: 14 - (lift + sigh) * 4)
            }
        } keyframes: { _ in
            // A sleepy sigh: the flap rises a hair and settles back.
            KeyframeTrack {
                CubicKeyframe(0.12, duration: 1.1)
                CubicKeyframe(0, duration: 1.4)
            }
        }
        .frame(height: Self.height)
        .animation(.pouchCharacter, value: isOpen)
        .animation(.pouchCharacter, value: peekOffset)
        // Clicks on the leather go through to the window-drag background:
        // the flap is the natural handle.
        .allowsHitTesting(false)
    }
}

import SwiftUI

/// The top of the pouch: a stitched fabric flap with the face on it and a
/// press-stud snap at the tip. The flap lifts while something hovers over
/// the shelf, and clicking the snap closes the pouch.
struct FlapView: View {
    static let height: CGFloat = 66

    var character: Character
    var isOpen: Bool
    var onSnap: () -> Void

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let lift: CGFloat = isOpen && !reduceMotion ? 1 : 0
        KeyframeAnimator(initialValue: 0.0, trigger: character.sighs) { sigh in
            ZStack(alignment: .top) {
                Group {
                    // The inside of the pouch, exposed when the flap lifts.
                    FlapShape(lift: 0)
                        .fill(Palette.lining)
                FlapShape(lift: lift + sigh)
                    .fill(theme.flap)
                    .fabricGrain(0.09)
                    .clipShape(FlapShape(lift: lift + sigh))
                    // A thin shadow where the flap overlaps the body.
                    .shadow(color: .black.opacity(0.22), radius: 1.2, y: 1)
                FlapShape(lift: lift + sigh, inset: 5)
                    .stroke(theme.thread.opacity(0.85), style: .stitch())
                // The face rides up with the flap so the snap never runs into it.
                FaceView(character: character, lidColor: theme.flap)
                    .offset(y: 12 - (lift + sigh) * 4)
                }
                // Clicks on the fabric go through to the window-drag
                // background: the flap is the natural handle.
                .allowsHitTesting(false)
                // The snap sits just above the tip and follows it.
                SnapButton(action: onSnap)
                    .offset(y: Self.height - 16 - (lift + sigh) * FlapShape.maxLift)
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
    }
}

/// A press stud. It's the "close" control, so it gets a hover state.
private struct SnapButton: View {
    var action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(Palette.metalRim)
                Circle().fill(Palette.metal).padding(1.5)
                Circle().strokeBorder(Palette.metalRim.opacity(0.7), lineWidth: 1).padding(4)
            }
            .frame(width: 13, height: 13)
            .shadow(color: .black.opacity(0.25), radius: 0.8, y: 0.8)
            .scaleEffect(isHovered ? 1.15 : 1)
            .contentShape(Circle().inset(by: -6))
        }
        .buttonStyle(SnapPressStyle())
        .onHover { isHovered = $0 }
        .animation(.pouchHover, value: isHovered)
        .help("Close the pouch (⌥⌘P)")
        .accessibilityLabel("Close the pouch")
    }
}

private struct SnapPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.82 : 1)
            .animation(.spring(response: 0.15, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

import SwiftUI

/// The top of the pouch: a stitched fabric flap with the face on it. The
/// flap's tip is the pouch's mouth: it lifts while something hovers over the
/// shelf. Nothing else sits under the eyes, so nothing competes with it.
/// Closing is a pull tab sewn into the top edge.
struct FlapView: View {
    static let height: CGFloat = 66

    var character: Character
    var isOpen: Bool
    var onClose: () -> Void

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
                // The face rides up a little as the flap lifts.
                FaceView(character: character, lidColor: theme.flap)
                    .offset(y: 14 - (lift + sigh) * 4)
                }
                // Clicks on the fabric go through to the window-drag
                // background: the flap is the natural handle.
                .allowsHitTesting(false)
                PullTab(action: onClose)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 26)
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

/// A ribbon loop sewn into the top seam, with a grommet at the end. It's
/// the "close" control: hovering sets it swinging, clicking tugs it.
private struct PullTab: View {
    var action: () -> Void
    @State private var swings = 0
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            KeyframeAnimator(initialValue: 0.0, trigger: swings) { angle in
                ribbon
                    .rotationEffect(.degrees(reduceMotion ? 0 : angle), anchor: .top)
            } keyframes: { _ in
                // A damped pendulum.
                KeyframeTrack {
                    CubicKeyframe(10, duration: 0.14)
                    CubicKeyframe(-6.5, duration: 0.2)
                    CubicKeyframe(3.5, duration: 0.2)
                    CubicKeyframe(-1.5, duration: 0.2)
                    CubicKeyframe(0, duration: 0.22)
                }
            }
            .contentShape(Rectangle().inset(by: -5))
        }
        .buttonStyle(TugStyle())
        .onHover { inside in
            if inside { swings += 1 }
        }
        .help("Close the pouch (⌥⌘P)")
        .accessibilityLabel("Close the pouch")
    }

    private var ribbon: some View {
        VStack(spacing: 0) {
            // Bar tack: where the ribbon is sewn into the seam.
            Rectangle()
                .fill(theme.flap.opacity(0.55))
                .frame(width: 8, height: 1.2)
                .padding(.top, 3)
            Spacer(minLength: 0)
            // Grommet.
            Circle()
                .fill(Palette.lining)
                .frame(width: 3.5, height: 3.5)
                .padding(1.6)
                .background(Circle().fill(Palette.metal))
                .overlay(Circle().strokeBorder(Palette.metalRim.opacity(0.8), lineWidth: 0.6))
                .padding(.bottom, 3)
        }
        .frame(width: 11, height: 25)
        .background {
            UnevenRoundedRectangle(bottomLeadingRadius: 5.5, bottomTrailingRadius: 5.5, style: .continuous)
                .fill(theme.thread)
                .fabricGrain(0.12)
                .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 5.5, bottomTrailingRadius: 5.5, style: .continuous))
                .shadow(color: .black.opacity(0.28), radius: 0.8, y: 1)
        }
    }
}

/// Pressing pulls the tab down a little, like a real tug.
private struct TugStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(x: configuration.isPressed ? 0.94 : 1, y: configuration.isPressed ? 1.16 : 1, anchor: .top)
            .animation(.spring(response: 0.16, dampingFraction: 0.55), value: configuration.isPressed)
    }
}

import SwiftUI

/// A small, still pouch, for places like the Settings header.
struct PouchPortrait: View {
    @State private var character = Character(mood: .awake, look: CGVector(dx: 0.35, dy: 0.4))
    @Environment(\.theme) private var theme

    var body: some View {
        ZStack(alignment: .top) {
            BodyShape().fill(Palette.canvas).fabricGrain()
            BodyShape().stroke(Palette.hairline, lineWidth: 0.5)
            FlapShape().fill(theme.flap).leatherGrain().clipShape(FlapShape())
            FlapShape().stroke(.black.opacity(0.32), lineWidth: 2).clipShape(FlapShape())
            FlapShape(inset: 5).stroke(theme.thread.opacity(0.9), style: .stitch(width: 1.2))
            FaceView(character: character, lidColor: theme.flap)
                .offset(y: 16)
        }
        .frame(width: 92, height: 96)
        .compositingGroup()
        .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
    }
}

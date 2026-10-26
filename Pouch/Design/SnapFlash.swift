import SwiftUI

/// A camera flash and a little "snap!" sticker on a freshly captured screenshot.
struct SnapFlash: View {
    @State private var flashOpacity = 0.9
    @State private var stickerShown = false
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.white)
                .opacity(reduceMotion ? 0 : flashOpacity)
            Text("snap!")
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(theme.accent, in: Capsule())
                .rotationEffect(.degrees(12))
                .scaleEffect(stickerShown ? 1 : 0.2)
                .opacity(stickerShown ? 1 : 0)
                .offset(x: 6, y: -6)
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeOut(duration: 0.7)) { flashOpacity = 0 }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.45).delay(0.1)) { stickerShown = true }
        }
    }
}

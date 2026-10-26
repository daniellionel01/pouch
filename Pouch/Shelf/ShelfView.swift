import PouchCore
import SwiftUI

/// Root view of the floating shelf.
struct ShelfView: View {
    var store: ShelfStore
    var settings: AppSettings
    var ui: ShelfUIState

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let theme = Theme.named(settings.theme)
        // Captured as a constant: the keyframe closure below is Sendable and
        // can't read main-actor view state directly.
        let reduceMotion = reduceMotion
        VStack(spacing: 0) {
            ShelfHeader(count: store.items.count)
            SeamLine(isActive: ui.isDropTargeted)
            if store.isEmpty {
                EmptyStateView(isAwake: ui.isDropTargeted)
                    .transition(.opacity)
            } else {
                ShelfGrid(store: store, ui: ui)
                    .transition(.opacity)
            }
        }
        .frame(width: ShelfPanel.contentWidth)
        .frame(maxHeight: .infinity)
        .background {
            ZStack {
                PouchBackground()
                WindowDragArea()
            }
        }
        .overlay {
            PouchShape()
                .stroke(theme.accent.opacity(ui.isDropTargeted ? 0.9 : 0), lineWidth: 3)
        }
        .clipShape(PouchShape())
        // The "mouth opens" bounce while something hovers over the shelf…
        .scaleEffect(ui.isDropTargeted && !reduceMotion ? 1.02 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.55), value: ui.isDropTargeted)
        // …and the "gulp" squash when it lands.
        .keyframeAnimator(initialValue: Squash(), trigger: ui.gulpCount) { content, squash in
            content.scaleEffect(x: reduceMotion ? 1 : squash.x, y: reduceMotion ? 1 : squash.y, anchor: .bottom)
        } keyframes: { _ in
            KeyframeTrack(\.y) {
                CubicKeyframe(0.94, duration: 0.09)
                SpringKeyframe(1.0, duration: 0.4, spring: .bouncy)
            }
            KeyframeTrack(\.x) {
                CubicKeyframe(1.03, duration: 0.09)
                SpringKeyframe(1.0, duration: 0.4, spring: .bouncy)
            }
        }
        .padding(ShelfPanel.margin)
        .environment(\.theme, theme)
        .tint(theme.accent)
    }
}

private struct ShelfHeader: View {
    var count: Int
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 6) {
            PullTab()
            HStack(spacing: 6) {
                Text("pouch")
                    .font(.system(.headline, design: .rounded).weight(.heavy))
                    .foregroundStyle(theme.accent)
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(theme.accent, in: Capsule())
                        .contentTransition(.numericText())
                        .transition(.scale.combined(with: .opacity))
                }
                Spacer()
            }
            .allowsHitTesting(false)
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 8)
    }
}

/// The little zipper-pull at the top. Purely decorative; the whole background
/// drags the window.
private struct PullTab: View {
    var body: some View {
        Capsule()
            .fill(.secondary.opacity(0.5))
            .frame(width: 34, height: 5)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

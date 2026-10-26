import PouchCore
import SwiftUI

/// Root view of the floating shelf.
struct ShelfView: View {
    var store: ShelfStore
    var settings: AppSettings
    var ui: ShelfUIState
    var interactions: ShelfInteractions

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let theme = Theme.named(settings.theme)
        // Captured as a constant: the keyframe closure below is Sendable and
        // can't read main-actor view state directly.
        let reduceMotion = reduceMotion
        VStack(spacing: 0) {
            ShelfHeader(count: store.items.count, onClear: interactions.clearAll)
            SeamLine(isActive: ui.isDropTargeted)
            if store.isEmpty {
                EmptyStateView(isAwake: ui.isDropTargeted)
                    .transition(.opacity)
            } else {
                ShelfGrid(store: store, ui: ui, interactions: interactions)
                    .transition(.opacity)
            }
        }
        .frame(width: ShelfPanel.contentWidth)
        .frame(maxHeight: .infinity)
        .background {
            ZStack {
                PouchBackground()
                WindowDragArea(onClick: interactions.clearSelection)
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
        // …and a quick shake on "clear all".
        .keyframeAnimator(initialValue: 0.0, trigger: ui.shakeCount) { content, angle in
            content.rotationEffect(.degrees(reduceMotion ? 0 : angle), anchor: .top)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(-4, duration: 0.07)
                CubicKeyframe(4, duration: 0.1)
                CubicKeyframe(-3, duration: 0.1)
                CubicKeyframe(2, duration: 0.1)
                SpringKeyframe(0, duration: 0.3, spring: .bouncy)
            }
        }
        .padding(ShelfPanel.margin)
        .environment(\.theme, theme)
        .tint(theme.accent)
    }
}

private struct ShelfHeader: View {
    var count: Int
    var onClear: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 6) {
            PullTab()
            HStack(spacing: 6) {
                Text("pouch")
                    .font(.system(.headline, design: .rounded).weight(.heavy))
                    .foregroundStyle(theme.accent)
                    .allowsHitTesting(false)
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
                        .allowsHitTesting(false)
                }
                Spacer()
                if count > 0 {
                    Button("Clear", action: onClear)
                        .buttonStyle(PillButtonStyle())
                        .help("Shake everything out of the pouch. Your files stay where they are.")
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 8)
    }
}

private struct PillButtonStyle: ButtonStyle {
    @Environment(\.theme) private var theme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(theme.accent)
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(theme.accent.opacity(configuration.isPressed ? 0.3 : 0.15), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.pouchHover, value: configuration.isPressed)
            .contentShape(Capsule())
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

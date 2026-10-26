import PouchCore
import SwiftUI

/// Root view of the floating shelf: the pouch itself.
struct ShelfView: View {
    var store: ShelfStore
    var settings: AppSettings
    var ui: ShelfUIState
    var interactions: ShelfInteractions
    var character: Character

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let theme = Theme.named(settings.theme)
        // Captured as a constant: the keyframe closures below are Sendable
        // and can't read main-actor view state directly.
        let reduceMotion = reduceMotion

        KeyframeAnimator(initialValue: Swallow(), trigger: ui.gulpCount + ui.snapCount) { swallow in
            let silhouette = BodyShape(
                bulgePosition: swallow.position,
                bulgeAmount: reduceMotion ? 0 : swallow.amount
            )
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    // The flap overlaps the top of the body.
                    Color.clear.frame(height: FlapView.height - FlapShape.tipDepth)
                    if store.isEmpty {
                        EmptyNote(isDropTargeted: ui.isDropTargeted)
                            .transition(.opacity)
                    } else {
                        ShelfMasonry(store: store, ui: ui, interactions: interactions)
                            .transition(.opacity)
                    }
                    ShelfFooter(count: store.items.count, onEmpty: interactions.clearAll)
                }
                FlapView(character: character, isOpen: ui.isDropTargeted, onClose: interactions.collapse)
            }
            .frame(width: ShelfPanel.contentWidth)
            .frame(maxHeight: .infinity)
            .background {
                ZStack {
                    silhouette.fill(Palette.canvas).fabricGrain()
                    WindowDragArea(onClick: interactions.clearSelection)
                }
            }
            .clipShape(silhouette)
        } keyframes: { _ in
            // The lump travels from the opening to the bottom.
            KeyframeTrack(\.position) {
                LinearKeyframe(0.02, duration: 0.01)
                CubicKeyframe(1, duration: 0.55)
            }
            KeyframeTrack(\.amount) {
                CubicKeyframe(3.4, duration: 0.12)
                LinearKeyframe(2.6, duration: 0.3)
                CubicKeyframe(0, duration: 0.18)
            }
        }
        // A hard sideways shake when it's emptied. Sideways because a
        // rotation would swing the bottom out of the window.
        .keyframeAnimator(initialValue: 0.0, trigger: ui.shakeCount) { content, x in
            content.offset(x: reduceMotion ? 0 : x)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(-2, duration: 0.06)
                CubicKeyframe(5, duration: 0.07)
                CubicKeyframe(-5, duration: 0.08)
                CubicKeyframe(4.5, duration: 0.08)
                CubicKeyframe(-3.5, duration: 0.08)
                CubicKeyframe(2, duration: 0.08)
                SpringKeyframe(0, duration: 0.3, spring: .snappy)
            }
        }
        .padding(ShelfPanel.margin)
        .environment(\.theme, theme)
        .tint(theme.controlTint)
    }
}

import PouchCore
import SwiftUI

/// Root view of the floating shelf.
struct ShelfView: View {
    var settings: AppSettings
    var ui: ShelfUIState

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let theme = Theme.named(settings.theme)
        VStack(spacing: 0) {
            ShelfHeader()
            SeamLine(isActive: ui.isDropTargeted)
            EmptyStateView(isAwake: ui.isDropTargeted)
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
        // The "mouth opens" bounce while something hovers over the shelf.
        .scaleEffect(ui.isDropTargeted && !reduceMotion ? 1.02 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.55), value: ui.isDropTargeted)
        .padding(ShelfPanel.margin)
        .environment(\.theme, theme)
        .tint(theme.accent)
    }
}

private struct ShelfHeader: View {
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 6) {
            PullTab()
            HStack {
                Text("pouch")
                    .font(.system(.headline, design: .rounded).weight(.heavy))
                    .foregroundStyle(theme.accent)
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

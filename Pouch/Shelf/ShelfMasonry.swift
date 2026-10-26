import PouchCore
import SwiftUI

/// The things in the pouch, in two staggered columns.
struct ShelfMasonry: View {
    var store: ShelfStore
    var ui: ShelfUIState
    var interactions: ShelfInteractions

    var body: some View {
        GeometryReader { viewport in
            ScrollView(.vertical) {
                MasonryLayout(columns: 2, spacing: 10) {
                    ForEach(Array(store.items.enumerated()), id: \.element.id) { index, item in
                        ItemView(
                            item: item,
                            fileURL: store.fileURL(for: item.id),
                            isMissing: store.isMissing(item.id),
                            isHovered: ui.hoveredID == item.id,
                            isSelected: ui.selection.contains(item.id),
                            isDragging: ui.draggingIDs.contains(item.id),
                            isFlashing: ui.flashingIDs.contains(item.id)
                        )
                        // Clicks, hover and drag-out are handled in AppKit.
                        .overlay(ItemInteractionView(id: item.id, name: item.displayName, interactions: interactions))
                        .modifier(Tumble(isTumbling: ui.isTumbling, index: index, seed: item.id))
                        .transition(.pouchEnter)
                    }
                }
                .padding(.horizontal, 11)
                .padding(.top, 10)
                .padding(.bottom, 8)
                // Fill at least the visible area so the background below
                // catches clicks anywhere between and below the items.
                .frame(maxWidth: .infinity, minHeight: viewport.size.height, alignment: .top)
                // Clicking between items deselects (and drags the window).
                .background(WindowDragArea(onClick: interactions.clearSelection))
            }
            .scrollIndicators(.never)
            .animation(.pouchLand, value: store.items.map(\.id))
        }
    }
}

/// "Empty": everything falls out of the bottom of the pouch, one after
/// another, turning a little as it goes.
private struct Tumble: ViewModifier {
    var isTumbling: Bool
    var index: Int
    var seed: UUID

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(isTumbling ? spin : 0))
            .offset(y: isTumbling ? 460 : 0)
            .animation(
                isTumbling ? .easeIn(duration: 0.42).delay(0.12 + Double(min(index, 12)) * 0.028) : nil,
                value: isTumbling
            )
    }

    private var spin: Double {
        Double(Int(seed.uuid.1) % 41 - 20)
    }
}

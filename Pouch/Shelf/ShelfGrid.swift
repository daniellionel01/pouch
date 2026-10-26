import PouchCore
import SwiftUI

/// The two-column grid of item cards.
struct ShelfGrid: View {
    var store: ShelfStore
    var ui: ShelfUIState
    var interactions: ShelfInteractions

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .top), count: 2)

    var body: some View {
        GeometryReader { viewport in
            ScrollView(.vertical) {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Array(store.items.enumerated()), id: \.element.id) { index, item in
                        ItemCardView(
                            item: item,
                            fileURL: store.fileURL(for: item.id),
                            isMissing: store.isMissing(item.id),
                            isHovered: ui.hoveredID == item.id,
                            isSelected: ui.selection.contains(item.id),
                            isDragging: ui.draggingIDs.contains(item.id),
                            isFlashing: ui.flashingIDs.contains(item.id)
                        )
                        // Clicks, hover and drag-out are handled in AppKit.
                        .overlay(ItemInteractionView(id: item.id, interactions: interactions))
                        .modifier(Tumble(isTumbling: ui.isTumbling, index: index, seed: item.id))
                        .transition(.pouchDropIn)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                // Fill at least the visible area so the background below
                // catches clicks anywhere between and below the cards.
                .frame(maxWidth: .infinity, minHeight: viewport.size.height, alignment: .top)
                // Clicking between cards deselects (and drags the window).
                .background(WindowDragArea(onClick: interactions.clearSelection))
            }
            .scrollIndicators(.never)
        }
    }
}

/// "Clear all": each card falls out of the pouch with a spin, one after another.
private struct Tumble: ViewModifier {
    var isTumbling: Bool
    var index: Int
    var seed: UUID

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(isTumbling ? spin : 0))
            .offset(y: isTumbling ? 420 : 0)
            .opacity(isTumbling ? 0 : 1)
            .animation(
                isTumbling ? .easeIn(duration: 0.45).delay(Double(min(index, 12)) * 0.03) : nil,
                value: isTumbling
            )
    }

    private var spin: Double {
        Double(Int(seed.uuid.1) % 61 - 30)
    }
}

import PouchCore
import SwiftUI

/// The two-column grid of item cards.
struct ShelfGrid: View {
    var store: ShelfStore
    var ui: ShelfUIState

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .top), count: 2)

    var body: some View {
        ScrollView(.vertical) {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(store.items) { item in
                    ItemCardView(
                        item: item,
                        fileURL: store.fileURL(for: item.id),
                        isMissing: store.isMissing(item.id),
                        isHovered: ui.hoveredID == item.id
                    )
                    .onHover { inside in
                        if inside {
                            ui.hoveredID = item.id
                        } else if ui.hoveredID == item.id {
                            ui.hoveredID = nil
                        }
                    }
                    .transition(.pouchDropIn)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .scrollIndicators(.never)
    }
}

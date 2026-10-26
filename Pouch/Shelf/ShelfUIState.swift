import Observation
import SwiftUI

/// Transient, view-only state for the shelf (hover, selection, effects).
/// Anything that should survive a relaunch belongs in `ShelfStore` instead.
@MainActor
@Observable
final class ShelfUIState {
    var isDropTargeted = false
    var hoveredID: UUID?
    var selection: Set<UUID> = []
    /// Items currently being dragged out; their cards fade while in flight.
    var draggingIDs: Set<UUID> = []
    /// Freshly captured screenshots, flashed briefly.
    var flashingIDs: Set<UUID> = []
    /// Bumped whenever something lands in the pouch; drives the gulp squash.
    var gulpCount = 0

    /// Shows the snap flash on `ids` for a moment.
    func flash(_ ids: [UUID]) {
        flashingIDs.formUnion(ids)
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation(.easeOut(duration: 0.3)) { flashingIDs.subtract(ids) }
        }
    }
}

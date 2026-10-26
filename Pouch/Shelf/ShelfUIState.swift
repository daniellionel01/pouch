import Foundation
import Observation

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
    /// Bumped whenever something lands in the pouch; drives the gulp squash.
    var gulpCount = 0
}

import Foundation
import Observation

/// Transient, view-only state for the shelf (hover, selection, effects).
/// Anything that should survive a relaunch belongs in `ShelfStore` instead.
@MainActor
@Observable
final class ShelfUIState {
    var isDropTargeted = false
    var hoveredID: UUID?
    /// Bumped whenever something lands in the pouch; drives the gulp squash.
    var gulpCount = 0
}

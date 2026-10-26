import Foundation
import Observation

/// Transient, view-only state for the shelf (hover, selection, effects).
/// Anything that should survive a relaunch belongs in `ShelfStore` instead.
@MainActor
@Observable
final class ShelfUIState {
    var isDropTargeted = false
}

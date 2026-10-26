import Observation
import PouchCore
import SwiftUI

/// Transient, view-only state for the shelf (hover, selection, effects).
/// Anything that should survive a relaunch belongs in `ShelfStore` instead.
@MainActor
@Observable
final class ShelfUIState {
    /// True while the shelf is tucked against the screen edge.
    var isTucked = true
    /// The cursor is resting on the tucked tab.
    var isTabHovered = false
    var dockSide: DockSide = .right
    var isDropTargeted = false
    var hoveredID: UUID?
    var selection: Set<UUID> = []
    /// Items currently being dragged out; their cards fade while in flight.
    var draggingIDs: Set<UUID> = []
    /// Freshly captured screenshots, flashed briefly.
    var flashingIDs: Set<UUID> = []
    /// Bumped whenever something is dropped in; drives the swallow.
    var gulpCount = 0
    /// Bumped when a screenshot arrives; a double take, then a swallow.
    var snapCount = 0
    /// Bumped after a successful drag out.
    var dragOutCount = 0
    /// Bumped on "clear all"; drives the shake.
    var shakeCount = 0
    /// True while cards tumble out during "clear all".
    var isTumbling = false

    /// Shows the camera flash on `ids` for a moment.
    func flash(_ ids: [UUID]) {
        flashingIDs.formUnion(ids)
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation(.easeOut(duration: 0.3)) { flashingIDs.subtract(ids) }
        }
    }
}

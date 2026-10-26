import CoreGraphics
import Foundation

/// Which screen edge the shelf lives on.
public enum DockSide: String, Codable, Sendable {
    case left
    case right
}

/// Where the docked shelf sits: the edge, how far down from the top of the
/// usable screen area, how tall it is, and on which display.
///
/// The offset is measured from the top (not stored as an absolute y) so the
/// shelf keeps its place relative to the menu bar when the screen changes.
public struct DockPlacement: Codable, Equatable, Sendable {
    public var side: DockSide
    public var topOffset: CGFloat
    public var height: CGFloat
    /// `CGDirectDisplayID` of the screen, if known.
    public var screenID: UInt32?

    public init(side: DockSide = .right, topOffset: CGFloat = 60, height: CGFloat = 380, screenID: UInt32? = nil) {
        self.side = side
        self.topOffset = topOffset
        self.height = height
        self.screenID = screenID
    }

    static let defaultsKey = "dockPlacement"

    public static func load(from defaults: UserDefaults = .standard) -> DockPlacement {
        guard let data = defaults.data(forKey: defaultsKey),
              let placement = try? JSONDecoder().decode(DockPlacement.self, from: data) else { return DockPlacement() }
        return placement
    }

    public func save(to defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) {
            defaults.set(data, forKey: Self.defaultsKey)
        }
    }
}

/// Frame math for the docked shelf. Pure geometry, so it's unit tested.
///
/// When tucked, the window shrinks to a thin strip at the edge instead of
/// sliding off-screen: off-screen parts would show up on a neighbouring
/// display, and an invisible full-size window would swallow drops meant for
/// whatever is underneath.
public struct DockGeometry: Equatable, Sendable {
    /// Window width when the shelf is out.
    public var fullWidth: CGFloat
    /// Window width when it's tucked: just the strip that stays visible.
    public var tuckedWidth: CGFloat
    public var minHeight: CGFloat

    public init(fullWidth: CGFloat, tuckedWidth: CGFloat, minHeight: CGFloat) {
        self.fullWidth = fullWidth
        self.tuckedWidth = tuckedWidth
        self.minHeight = minHeight
    }

    /// The window frame for a placement on a screen's usable area.
    public func frame(for placement: DockPlacement, in visible: CGRect, tucked: Bool) -> CGRect {
        let height = min(max(placement.height, minHeight), visible.height)
        let width = tucked ? tuckedWidth : fullWidth
        let x = placement.side == .right ? visible.maxX - width : visible.minX
        // Keep the whole shelf on screen vertically.
        let top = min(max(visible.maxY - placement.topOffset, visible.minY + height), visible.maxY)
        return CGRect(x: x, y: top - height, width: width, height: height)
    }

    /// Where a shelf the user just dragged to `frame` should dock: the nearer
    /// side edge, at the height it was dropped.
    public func placement(afterMovingTo frame: CGRect, in visible: CGRect, screenID: UInt32?) -> DockPlacement {
        let side: DockSide = frame.midX >= visible.midX ? .right : .left
        let height = min(max(frame.height, minHeight), visible.height)
        let topOffset = min(max(visible.maxY - frame.maxY, 0), visible.height - height)
        return DockPlacement(side: side, topOffset: topOffset, height: height, screenID: screenID)
    }
}

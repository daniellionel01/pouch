import XCTest
@testable import PouchCore

final class DockGeometryTests: XCTestCase {
    private let geometry = DockGeometry(fullWidth: 232, tuckedWidth: 32, tuckedHeight: 76, minHeight: 240)
    /// A 1440×875 usable area starting at the origin, like a laptop screen
    /// under the menu bar.
    private let visible = CGRect(x: 0, y: 0, width: 1440, height: 875)

    func testRightDockRevealedAndTucked() {
        let placement = DockPlacement(side: .right, topOffset: 60, height: 380)
        let revealed = geometry.frame(for: placement, in: visible, tucked: false)
        let tucked = geometry.frame(for: placement, in: visible, tucked: true)

        XCTAssertEqual(revealed, CGRect(x: 1440 - 232, y: 875 - 60 - 380, width: 232, height: 380))
        XCTAssertEqual(tucked.maxX, visible.maxX, "flush with the right edge")
        XCTAssertEqual(tucked.size, CGSize(width: 32, height: 76))
        XCTAssertEqual(tucked.maxY, revealed.maxY, "the tab shares the shelf's top")
    }

    func testLeftDockStaysOnTheLeftEdge() {
        let placement = DockPlacement(side: .left, topOffset: 100, height: 300)
        XCTAssertEqual(geometry.frame(for: placement, in: visible, tucked: true).minX, 0)
        XCTAssertEqual(geometry.frame(for: placement, in: visible, tucked: false).minX, 0)
    }

    func testFrameIsClampedOntoTheScreen() {
        let tooLow = DockPlacement(side: .right, topOffset: 2000, height: 380)
        let tooTall = DockPlacement(side: .right, topOffset: 0, height: 5000)
        let tiny = DockPlacement(side: .right, topOffset: 0, height: 10)

        XCTAssertEqual(geometry.frame(for: tooLow, in: visible, tucked: false).minY, visible.minY)
        // Tucked, the tab still sits where the (clamped) shelf's top would be.
        XCTAssertEqual(geometry.frame(for: tooLow, in: visible, tucked: true).maxY, visible.minY + 380)
        XCTAssertEqual(geometry.frame(for: tooTall, in: visible, tucked: false).height, visible.height)
        XCTAssertEqual(geometry.frame(for: tiny, in: visible, tucked: false).height, 240)
    }

    func testPlacementSnapsToTheNearerEdge() {
        let nearLeft = CGRect(x: 300, y: 400, width: 232, height: 380)
        let nearRight = CGRect(x: 1000, y: 400, width: 232, height: 380)

        let left = geometry.placement(afterMovingTo: nearLeft, in: visible, screenID: 7)
        XCTAssertEqual(left.side, .left)
        XCTAssertEqual(left.topOffset, 875 - 780)
        XCTAssertEqual(left.screenID, 7)
        XCTAssertEqual(geometry.placement(afterMovingTo: nearRight, in: visible, screenID: nil).side, .right)
    }

    func testPlacementOnASecondaryScreen() {
        let secondary = CGRect(x: 1440, y: -200, width: 1920, height: 1050)
        let dropped = CGRect(x: 3000, y: 300, width: 232, height: 380)
        let placement = geometry.placement(afterMovingTo: dropped, in: secondary, screenID: 2)
        let frame = geometry.frame(for: placement, in: secondary, tucked: true)

        XCTAssertEqual(placement.side, .right)
        XCTAssertEqual(frame.maxX, secondary.maxX)
        XCTAssertEqual(frame.maxY, dropped.maxY)
        XCTAssertEqual(frame.height, 76)
    }
}

final class DockPlacementTests: XCTestCase {
    func testRoundTripAndDefault() {
        let suiteName = "PouchTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        addTeardownBlock { UserDefaults().removePersistentDomain(forName: suiteName) }

        XCTAssertEqual(DockPlacement.load(from: defaults), DockPlacement())
        let placement = DockPlacement(side: .left, topOffset: 123, height: 456, screenID: 9)
        placement.save(to: defaults)
        XCTAssertEqual(DockPlacement.load(from: defaults), placement)
    }
}

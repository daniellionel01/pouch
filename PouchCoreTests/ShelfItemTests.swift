import XCTest
@testable import PouchCore

final class ShelfItemTests: XCTestCase {
    func testCodableRoundTripForEveryContentKind() throws {
        let items = [
            ShelfItem(content: .file(bookmark: Data([1, 2, 3]), lastKnownPath: "/tmp/a.png"), source: .screenshot),
            ShelfItem(content: .url(URL(string: "https://example.com/page")!)),
            ShelfItem(content: .text("hello\nworld")),
        ]
        let data = try JSONEncoder().encode(items)
        let decoded = try JSONDecoder().decode([ShelfItem].self, from: data)
        XCTAssertEqual(decoded, items)
    }

    func testDisplayNames() {
        XCTAssertEqual(ShelfItem(content: .file(bookmark: Data(), lastKnownPath: "/x/Screenshot 1.png")).displayName, "Screenshot 1.png")
        XCTAssertEqual(ShelfItem(content: .url(URL(string: "https://example.com/a/b")!)).displayName, "example.com")
        XCTAssertEqual(ShelfItem(content: .text("  first line \nsecond")).displayName, "first line")
        let long = String(repeating: "a", count: 60)
        XCTAssertEqual(ShelfItem(content: .text(long)).displayName, String(repeating: "a", count: 40) + "…")
    }
}

import XCTest
@testable import PouchCore

final class ShelfPersistenceTests: XCTestCase {
    func testMissingFileLoadsEmpty() throws {
        let dir = try makeTemporaryDirectory()
        let persistence = ShelfPersistence(fileURL: dir.appendingPathComponent("shelf.json"))
        XCTAssertEqual(try persistence.load(), [])
    }

    func testRoundTrip() throws {
        let dir = try makeTemporaryDirectory()
        let persistence = ShelfPersistence(fileURL: dir.appendingPathComponent("nested/shelf.json"))
        let file = try makeFile(named: "a.png", in: dir)
        let items = [
            ShelfItem(content: .file(bookmark: try BookmarkResolver.makeBookmark(for: file), lastKnownPath: file.path), source: .screenshot),
            ShelfItem(content: .url(URL(string: "https://example.com")!)),
            ShelfItem(content: .text("note")),
        ]
        try persistence.save(items)
        XCTAssertEqual(try persistence.load(), items)
    }

    func testCorruptFileThrowsAndCanBeQuarantined() throws {
        let dir = try makeTemporaryDirectory()
        let url = dir.appendingPathComponent("shelf.json")
        try Data("{ nope".utf8).write(to: url)
        let persistence = ShelfPersistence(fileURL: url)

        XCTAssertThrowsError(try persistence.load())
        persistence.quarantineCorruptFile()
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        XCTAssertTrue(leftovers.contains { $0.hasPrefix("shelf.corrupt-") }, "the bad file should be kept aside, not deleted")
    }

    func testNewerFormatVersionIsRejected() throws {
        let dir = try makeTemporaryDirectory()
        let url = dir.appendingPathComponent("shelf.json")
        try Data(#"{"version": 99, "items": []}"#.utf8).write(to: url)
        XCTAssertThrowsError(try ShelfPersistence(fileURL: url).load())
    }
}

import XCTest
@testable import PouchCore

final class BookmarkResolverTests: XCTestCase {
    func testResolvesUnmovedFile() throws {
        let dir = try makeTemporaryDirectory()
        let file = try makeFile(named: "a.txt", in: dir)
        let bookmark = try BookmarkResolver.makeBookmark(for: file)

        let resolution = BookmarkResolver.resolve(bookmark: bookmark, lastKnownPath: file.path)
        XCTAssertEqual(resolution.availability, .available(file))
    }

    func testFollowsRenameAndMove() throws {
        let dir = try makeTemporaryDirectory()
        let file = try makeFile(named: "before.txt", in: dir)
        let bookmark = try BookmarkResolver.makeBookmark(for: file)

        let subfolder = dir.appendingPathComponent("moved", isDirectory: true)
        try FileManager.default.createDirectory(at: subfolder, withIntermediateDirectories: true)
        let moved = subfolder.appendingPathComponent("after.txt")
        try FileManager.default.moveItem(at: file, to: moved)

        let resolution = BookmarkResolver.resolve(bookmark: bookmark, lastKnownPath: file.path)
        XCTAssertEqual(resolution.availability, .available(moved))
    }

    func testDeletedFileIsMissing() throws {
        let dir = try makeTemporaryDirectory()
        let file = try makeFile(named: "gone.txt", in: dir)
        let bookmark = try BookmarkResolver.makeBookmark(for: file)
        try FileManager.default.removeItem(at: file)

        let resolution = BookmarkResolver.resolve(bookmark: bookmark, lastKnownPath: file.path)
        XCTAssertEqual(resolution.availability, .missing)
        XCTAssertNil(resolution.refreshedBookmark)
    }

    func testFileMovedIntoATrashFolderIsMissing() throws {
        let dir = try makeTemporaryDirectory()
        let file = try makeFile(named: "trashed.txt", in: dir)
        let bookmark = try BookmarkResolver.makeBookmark(for: file)
        // Simulate the Trash without touching the user's real one.
        let trash = dir.appendingPathComponent(".Trash", isDirectory: true)
        try FileManager.default.createDirectory(at: trash, withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: file, to: trash.appendingPathComponent("trashed.txt"))

        let resolution = BookmarkResolver.resolve(bookmark: bookmark, lastKnownPath: file.path)
        XCTAssertEqual(resolution.availability, .missing)
    }

    func testFallsBackToLastKnownPathWhenBookmarkIsUnusable() throws {
        let dir = try makeTemporaryDirectory()
        let file = try makeFile(named: "plain.txt", in: dir)

        for bookmark in [Data(), Data("not a bookmark".utf8)] {
            let resolution = BookmarkResolver.resolve(bookmark: bookmark, lastKnownPath: file.path)
            XCTAssertEqual(resolution.availability, .available(file))
            XCTAssertNotNil(resolution.refreshedBookmark, "should offer a real bookmark to store")
        }
    }

    func testUnusableBookmarkAndNoFileIsMissing() {
        let resolution = BookmarkResolver.resolve(bookmark: Data(), lastKnownPath: "/nonexistent/\(UUID().uuidString)")
        XCTAssertEqual(resolution.availability, .missing)
    }
}

import XCTest
@testable import PouchCore

final class DropInboxTests: XCTestCase {
    func testWritesUniqueFiles() throws {
        let inbox = DropInbox(directory: try makeTemporaryDirectory().appendingPathComponent("Drops"))
        let date = Date(timeIntervalSince1970: 0)
        let first = try inbox.write(Data([1]), baseName: "Image", fileExtension: "png", date: date)
        let second = try inbox.write(Data([2]), baseName: "Image", fileExtension: "png", date: date)

        XCTAssertNotEqual(first, second)
        XCTAssertTrue(second.lastPathComponent.hasSuffix("(2).png"))
        XCTAssertTrue(inbox.contains(first))
    }

    func testDeletesOnlyOwnedFiles() throws {
        let dir = try makeTemporaryDirectory()
        let inbox = DropInbox(directory: dir.appendingPathComponent("Drops"))
        let owned = try inbox.write(Data([1]), baseName: "Image", fileExtension: "png")
        let outside = try makeFile(named: "keep.txt", in: dir)

        inbox.deleteOwnedFile(at: outside)
        inbox.deleteOwnedFile(at: owned)

        XCTAssertTrue(FileManager.default.fileExists(atPath: outside.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: owned.path))
    }

    func testDeletingLastFileInSubdirectoryRemovesIt() throws {
        let inbox = DropInbox(directory: try makeTemporaryDirectory().appendingPathComponent("Drops"))
        let subdirectory = try inbox.makeUniqueSubdirectory()
        let file = try makeFile(named: "promised.pdf", in: subdirectory)

        inbox.deleteOwnedFile(at: file)
        XCTAssertFalse(FileManager.default.fileExists(atPath: subdirectory.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: inbox.directory.path))
    }
}

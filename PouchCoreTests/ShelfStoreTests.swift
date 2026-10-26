import XCTest
@testable import PouchCore

@MainActor
final class ShelfStoreTests: XCTestCase {
    private func makeStore(in dir: URL) -> ShelfStore {
        ShelfStore(
            persistence: ShelfPersistence(fileURL: dir.appendingPathComponent("shelf.json")),
            inbox: DropInbox(directory: dir.appendingPathComponent("Drops"))
        )
    }

    func testAddFilesPutsNewestFirstAndKeepsDropOrder() throws {
        let dir = try makeTemporaryDirectory()
        let store = makeStore(in: dir)
        let a = try makeFile(named: "a.txt", in: dir)
        let b = try makeFile(named: "b.txt", in: dir)
        let c = try makeFile(named: "c.txt", in: dir)

        store.addFiles([a])
        store.addFiles([b, c])

        XCTAssertEqual(store.items.map(\.displayName), ["b.txt", "c.txt", "a.txt"])
        XCTAssertEqual(store.fileURL(for: store.items[0].id), b)
    }

    func testAddingSameFileTwiceMovesItToTop() throws {
        let dir = try makeTemporaryDirectory()
        let store = makeStore(in: dir)
        let a = try makeFile(named: "a.txt", in: dir)
        let b = try makeFile(named: "b.txt", in: dir)

        store.addFiles([a])
        let firstID = store.items[0].id
        store.addFiles([b])
        store.addFiles([a])

        XCTAssertEqual(store.items.count, 2)
        XCTAssertEqual(store.items[0].id, firstID)
    }

    func testTextAndURLValues() throws {
        let store = makeStore(in: try makeTemporaryDirectory())
        let url = URL(string: "https://example.com")!

        store.addURL(url)
        XCTAssertNil(store.addText("   \n "))
        store.addText("hello")
        store.addURL(url)

        XCTAssertEqual(store.items.map(\.content), [.url(url), .text("hello")])
    }

    func testRemoveNeverDeletesUserFiles() throws {
        let dir = try makeTemporaryDirectory()
        let store = makeStore(in: dir)
        let file = try makeFile(named: "precious.txt", in: dir)
        store.addFiles([file])

        store.remove([store.items[0].id])

        XCTAssertTrue(store.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
    }

    func testRemoveDeletesPouchOwnedInboxFiles() throws {
        let dir = try makeTemporaryDirectory()
        let store = makeStore(in: dir)
        let owned = try DropInbox(directory: dir.appendingPathComponent("Drops"))
            .write(Data([1]), baseName: "Image", fileExtension: "png")
        store.addFiles([owned])

        store.clear()

        XCTAssertFalse(FileManager.default.fileExists(atPath: owned.path))
    }

    func testPersistsAcrossInstances() throws {
        let dir = try makeTemporaryDirectory()
        let file = try makeFile(named: "a.txt", in: dir)
        let store = makeStore(in: dir)
        store.addFiles([file], source: .screenshot)
        store.addText("note")

        let reloaded = makeStore(in: dir)
        reloaded.load()

        XCTAssertEqual(reloaded.items, store.items)
        XCTAssertEqual(reloaded.fileURL(for: reloaded.items[1].id), file)
    }

    func testRefreshPicksUpRenamesAndMissingFiles() throws {
        let dir = try makeTemporaryDirectory()
        let store = makeStore(in: dir)
        let renamed = try makeFile(named: "old.txt", in: dir)
        let deleted = try makeFile(named: "doomed.txt", in: dir)
        store.addFiles([renamed, deleted])
        let renamedID = store.items[0].id
        let deletedID = store.items[1].id

        let newURL = dir.appendingPathComponent("new.txt")
        try FileManager.default.moveItem(at: renamed, to: newURL)
        try FileManager.default.removeItem(at: deleted)
        store.refreshAvailability()

        XCTAssertEqual(store.fileURL(for: renamedID), newURL)
        XCTAssertEqual(store.item(withID: renamedID)?.displayName, "new.txt")
        XCTAssertTrue(store.isMissing(deletedID))

        store.removeMissing()
        XCTAssertEqual(store.items.map(\.id), [renamedID])
    }

    func testCorruptSaveFileStartsEmpty() throws {
        let dir = try makeTemporaryDirectory()
        try Data("garbage".utf8).write(to: dir.appendingPathComponent("shelf.json"))
        let store = makeStore(in: dir)
        store.load()
        XCTAssertTrue(store.isEmpty)
    }
}

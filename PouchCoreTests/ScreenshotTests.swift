import XCTest
@testable import PouchCore

/// Marks a file the way `screencapture` does.
private func markAsScreenshot(_ url: URL, value: Bool = true) throws {
    let data = try PropertyListSerialization.data(fromPropertyList: value, format: .binary, options: 0)
    let result = url.withUnsafeFileSystemRepresentation { path in
        data.withUnsafeBytes { setxattr(path, ScreenshotDetector.attributeName, $0.baseAddress, data.count, 0, 0) }
    }
    XCTAssertEqual(result, 0)
}

final class ScreenshotDetectorTests: XCTestCase {
    func testDetectsScreenCaptureAttribute() throws {
        let dir = try makeTemporaryDirectory()
        let plain = try makeFile(named: "Screenshot lookalike.png", in: dir)
        let real = try makeFile(named: "whatever.png", in: dir)
        let falseFlag = try makeFile(named: "false.png", in: dir)
        try markAsScreenshot(real)
        try markAsScreenshot(falseFlag, value: false)

        XCTAssertFalse(ScreenshotDetector.isScreenCapture(plain), "names alone don't count")
        XCTAssertTrue(ScreenshotDetector.isScreenCapture(real))
        XCTAssertFalse(ScreenshotDetector.isScreenCapture(falseFlag))
    }
}

final class ScreenshotLocationTests: XCTestCase {
    private func makeDefaults(location: String?) -> UserDefaults {
        let suiteName = "PouchTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        if let location { defaults.set(location, forKey: "location") }
        addTeardownBlock { UserDefaults().removePersistentDomain(forName: suiteName) }
        return defaults
    }

    func testDefaultsToDesktop() throws {
        let home = try makeTemporaryDirectory()
        XCTAssertEqual(ScreenshotLocation.current(defaults: makeDefaults(location: nil), home: home).path, home.appendingPathComponent("Desktop").path)
    }

    func testExpandsTilde() throws {
        let home = try makeTemporaryDirectory()
        try FileManager.default.createDirectory(at: home.appendingPathComponent("Pictures/Shots"), withIntermediateDirectories: true)
        let url = ScreenshotLocation.current(defaults: makeDefaults(location: "~/Pictures/Shots"), home: home)
        XCTAssertEqual(url.path, home.appendingPathComponent("Pictures/Shots").path)
    }

    func testAbsolutePathAndMissingFolderFallback() throws {
        let home = try makeTemporaryDirectory()
        let custom = try makeTemporaryDirectory()
        XCTAssertEqual(ScreenshotLocation.current(defaults: makeDefaults(location: custom.path), home: home).path, custom.path)
        XCTAssertEqual(
            ScreenshotLocation.current(defaults: makeDefaults(location: "/Volumes/Gone/Shots"), home: home).path,
            home.appendingPathComponent("Desktop").path
        )
    }
}

@MainActor
final class ScreenshotWatcherTests: XCTestCase {
    func testFolderWatcherReportsNewScreenshotsOnce() async throws {
        let dir = try makeTemporaryDirectory()
        let before = try makeFile(named: "old.png", in: dir)
        try markAsScreenshot(before)
        // Backdate it so it predates the watcher (and its 2 s of slack).
        try FileManager.default.setAttributes([.creationDate: Date().addingTimeInterval(-60)], ofItemAtPath: before.path)

        let watcher = ScreenshotWatcher(useSpotlight: false, folder: { dir })
        var reported: [URL] = []
        let arrived = expectation(description: "screenshot reported")
        watcher.onScreenshot = { url in
            reported.append(url)
            arrived.fulfill()
        }
        watcher.start()
        defer { watcher.stop() }

        _ = try makeFile(named: "not a screenshot.png", in: dir)
        // Write the way screencapture does: hidden temp file, then rename.
        let temp = try makeFile(named: ".tmp-shot.png", in: dir)
        try markAsScreenshot(temp)
        let shot = dir.appendingPathComponent("Screenshot 2026-10-26 at 12.00.00.png")
        try FileManager.default.moveItem(at: temp, to: shot)

        await fulfillment(of: [arrived], timeout: 5)
        // Give the delayed rescan a chance to (wrongly) report it again.
        try await Task.sleep(for: .seconds(1.5))
        XCTAssertEqual(reported.map(\.lastPathComponent), [shot.lastPathComponent])
    }

    func testStopsReportingAfterStop() async throws {
        let dir = try makeTemporaryDirectory()
        let watcher = ScreenshotWatcher(useSpotlight: false, folder: { dir })
        var count = 0
        watcher.onScreenshot = { _ in count += 1 }
        watcher.start()
        watcher.stop()

        let shot = try makeFile(named: "shot.png", in: dir)
        try markAsScreenshot(shot)
        try await Task.sleep(for: .seconds(1.5))
        XCTAssertEqual(count, 0)
    }
}

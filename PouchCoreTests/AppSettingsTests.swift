import XCTest
@testable import PouchCore

@MainActor
final class AppSettingsTests: XCTestCase {
    /// A throwaway defaults domain, removed when the test finishes.
    private func makeDefaults() -> UserDefaults {
        let suiteName = "PouchTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        addTeardownBlock { UserDefaults().removePersistentDomain(forName: suiteName) }
        return defaults
    }

    func testDefaults() {
        let defaults = makeDefaults()
        let settings = AppSettings(defaults: defaults)
        XCTAssertTrue(settings.collectScreenshots)
        XCTAssertTrue(settings.showOnNewScreenshot)
        XCTAssertFalse(settings.removeAfterDragOut)
        XCTAssertFalse(settings.soundsEnabled)
        XCTAssertEqual(settings.theme, .kangaroo)
    }

    func testChangesPersist() {
        let defaults = makeDefaults()
        let settings = AppSettings(defaults: defaults)
        settings.collectScreenshots = false
        settings.removeAfterDragOut = true
        settings.soundsEnabled = true
        settings.theme = .grape

        let reloaded = AppSettings(defaults: defaults)
        XCTAssertFalse(reloaded.collectScreenshots)
        XCTAssertTrue(reloaded.removeAfterDragOut)
        XCTAssertTrue(reloaded.soundsEnabled)
        XCTAssertEqual(reloaded.theme, .grape)
    }

    func testUnknownThemeFallsBackToDefault() {
        let defaults = makeDefaults()
        defaults.set("plaid", forKey: AppSettings.Key.theme)
        XCTAssertEqual(AppSettings(defaults: defaults).theme, .kangaroo)
    }
}

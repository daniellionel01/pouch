import Foundation
import Observation

/// Pouch's colorways. The actual colors live in the app target; this is just
/// the persisted identifier.
public enum ThemeID: String, CaseIterable, Codable, Sendable {
    case kangaroo
    case mint
    case grape
    case graphite
}

/// User preferences, backed by `UserDefaults`.
///
/// The global hotkey is stored by KeyboardShortcuts and launch-at-login by
/// `SMAppService`, so neither lives here.
@MainActor
@Observable
public final class AppSettings {
    enum Key {
        static let collectScreenshots = "collectScreenshots"
        static let showOnNewScreenshot = "showOnNewScreenshot"
        static let removeAfterDragOut = "removeAfterDragOut"
        static let soundsEnabled = "soundsEnabled"
        static let theme = "theme"
    }

    @ObservationIgnored private let defaults: UserDefaults

    public var collectScreenshots: Bool {
        didSet { defaults.set(collectScreenshots, forKey: Key.collectScreenshots) }
    }
    public var showOnNewScreenshot: Bool {
        didSet { defaults.set(showOnNewScreenshot, forKey: Key.showOnNewScreenshot) }
    }
    public var removeAfterDragOut: Bool {
        didSet { defaults.set(removeAfterDragOut, forKey: Key.removeAfterDragOut) }
    }
    public var soundsEnabled: Bool {
        didSet { defaults.set(soundsEnabled, forKey: Key.soundsEnabled) }
    }
    public var theme: ThemeID {
        didSet { defaults.set(theme.rawValue, forKey: Key.theme) }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.collectScreenshots: true,
            Key.showOnNewScreenshot: true,
            Key.removeAfterDragOut: false,
            Key.soundsEnabled: false,
            Key.theme: ThemeID.kangaroo.rawValue,
        ])
        collectScreenshots = defaults.bool(forKey: Key.collectScreenshots)
        showOnNewScreenshot = defaults.bool(forKey: Key.showOnNewScreenshot)
        removeAfterDragOut = defaults.bool(forKey: Key.removeAfterDragOut)
        soundsEnabled = defaults.bool(forKey: Key.soundsEnabled)
        theme = defaults.string(forKey: Key.theme).flatMap(ThemeID.init(rawValue:)) ?? .kangaroo
    }
}

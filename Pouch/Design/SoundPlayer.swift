import AppKit
import PouchCore

/// Optional sound effects using the built-in system sounds, so nothing needs
/// to be bundled. Off by default.
@MainActor
final class SoundPlayer {
    enum Effect: String {
        case gulp = "Pop"
        case snap = "Tink"
        case poof = "Bottle"
        case shakeOut = "Frog"
    }

    private let settings: AppSettings
    private var sounds: [Effect: NSSound] = [:]

    init(settings: AppSettings) {
        self.settings = settings
    }

    func play(_ effect: Effect) {
        guard settings.soundsEnabled else { return }
        let sound = sounds[effect] ?? NSSound(named: effect.rawValue)
        guard let sound else { return }
        sounds[effect] = sound
        sound.volume = 0.35
        // Restart rather than overlap when things land in quick succession.
        sound.stop()
        sound.play()
    }
}

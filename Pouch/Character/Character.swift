import CoreGraphics
import Observation

/// The pouch's face: what it's feeling and where it's looking.
///
/// This is just state. `CharacterDirector` decides when it changes (blinks,
/// glances, dozing off, reactions), and `FaceView` draws it.
@MainActor
@Observable
final class Character {
    enum Mood: Equatable {
        case asleep
        /// Idle for a while: heavy eyelids, slow blinks.
        case drowsy
        case awake
        /// Something is being dragged over it or out of it.
        case curious
        /// Just got fed.
        case delighted
        /// A screenshot appeared out of nowhere.
        case startled
        /// Being shaken empty.
        case squeeze
    }

    /// The resting mood, derived from what's going on.
    var mood: Mood = .asleep
    /// A short-lived reaction that overrides the resting mood.
    var reaction: Mood?
    var isBlinking = false
    /// Where the eyes point, each axis in -1...1 (y grows downward).
    var look = CGVector.zero
    /// Bumped for a sleepy sigh (the flap rises and settles).
    var sighs = 0

    var expression: Mood { reaction ?? mood }

    init(mood: Mood = .asleep, look: CGVector = .zero) {
        self.mood = mood
        self.look = look
    }
}

extension Character.Mood {
    /// How far the upper lids are down, 0 (open) to 1 (shut).
    var lid: CGFloat {
        switch self {
        case .asleep, .delighted, .squeeze: 1
        case .drowsy: 0.55
        case .awake: 0.05
        case .curious, .startled: 0
        }
    }

    /// Pupil size relative to normal.
    var pupilScale: CGFloat {
        switch self {
        case .curious: 1.25
        case .startled: 0.62
        default: 1
        }
    }

    /// Vertical stretch of the eyes.
    var eyeStretch: CGFloat {
        switch self {
        case .curious: 1.08
        case .startled: 1.22
        default: 1
        }
    }
}

import SwiftUI

// Two kinds of motion, on purpose:
// - The interface (items, layout, selection) settles without overshoot.
//   Things shouldn't wobble when you're trying to grab them.
// - The character (flap, eyes, body) is elastic, with anticipation and
//   overshoot. It's the one thing on screen that's allowed to be alive.

extension Animation {
    /// Items landing, leaving and reflowing. Near-critically damped.
    static let pouchLand = Animation.spring(response: 0.34, dampingFraction: 0.92)
    /// Hover and selection feedback.
    static let pouchHover = Animation.spring(response: 0.2, dampingFraction: 0.9)
    /// The flap and the character's expressions: springy.
    static let pouchCharacter = Animation.spring(response: 0.3, dampingFraction: 0.52)
}

extension AnyTransition {
    /// New items come in through the opening at the top.
    // Computed rather than stored: `AnyTransition` isn't Sendable, so Swift 6
    // won't allow it in a static stored property.
    static var pouchEnter: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .opacity.combined(with: .scale(scale: 0.94))
        )
    }
}

/// Parameters for the swallow that travels down the body after a drop.
struct Swallow {
    var position: CGFloat = 0
    var amount: CGFloat = 0
}

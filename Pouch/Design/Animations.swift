import SwiftUI

extension Animation {
    /// Items landing in (or leaving) the pouch: quick with a little bounce.
    static let pouchLand = Animation.spring(response: 0.38, dampingFraction: 0.62)
    /// Hover and selection feedback on cards.
    static let pouchHover = Animation.spring(response: 0.25, dampingFraction: 0.6)
}

extension AnyTransition {
    /// New cards drop in from above, shrinking into place.
    // Computed rather than stored: `AnyTransition` isn't Sendable, so Swift 6
    // won't allow it in a static stored property.
    static var pouchDropIn: AnyTransition {
        .asymmetric(
            insertion: .offset(y: -40).combined(with: .scale(scale: 0.5, anchor: .top)).combined(with: .opacity),
            removal: .scale(scale: 1.25).combined(with: .opacity)
        )
    }
}

/// Horizontal/vertical scale used for the pouch's "gulp" squash.
struct Squash {
    var x = 1.0
    var y = 1.0
}

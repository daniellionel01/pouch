import Observation

/// Calls `onChange` every time the observable state read by `value` changes.
///
/// `withObservationTracking` only fires once, so this re-registers after each
/// change. It's the AppKit-side equivalent of SwiftUI's `.onChange`.
@MainActor
func observeChanges<Value>(_ value: @escaping @MainActor () -> Value, onChange: @escaping @MainActor (Value) -> Void) {
    withObservationTracking {
        _ = value()
    } onChange: {
        // Fires *before* the change is applied; hop to read the new value.
        Task { @MainActor in
            onChange(value())
            observeChanges(value, onChange: onChange)
        }
    }
}

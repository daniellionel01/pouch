import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Show/hide the shelf from anywhere. ⌥⌘P by default; change it in Settings.
    static let toggleShelf = Self("toggleShelf", default: .init(.p, modifiers: [.command, .option]))
}

/// Registers the global hotkey. KeyboardShortcuts uses Carbon's
/// `RegisterEventHotKey`, which (unlike an `NSEvent` global monitor) needs
/// no Accessibility permission, and it stores the user's choice for us.
@MainActor
final class HotkeyController {
    init(onToggle: @escaping @MainActor () -> Void) {
        KeyboardShortcuts.onKeyDown(for: .toggleShelf) {
            onToggle()
        }
    }
}

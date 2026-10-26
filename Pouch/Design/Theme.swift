import AppKit
import PouchCore
import SwiftUI

/// One colorway: the flap's leather and the thread it's stitched with.
struct Theme: Equatable {
    let id: ThemeID
    let name: String
    /// The flap leather.
    let flap: Color
    /// Stitching on the flap and the label's lettering.
    let thread: Color
    /// The flap color tuned for legibility as text or outlines on the canvas.
    let accent: Color
    /// A fixed mid-tone for system controls (switches and the like), which
    /// don't pick up light/dark dynamic colors as a tint.
    let controlTint: Color

    static func named(_ id: ThemeID) -> Theme {
        switch id {
        case .cognac:
            Theme(id: id, name: "Cognac", flap: Color(light: 0xAE5E2C, dark: 0x9A5227),
                  thread: Color(light: 0xF1DFC0, dark: 0xE9D5B2), accent: Color(light: 0x8A4520, dark: 0xD9925E),
                  controlTint: Color(nsColor: NSColor(hex: 0xAE5E2C)))
        case .oxblood:
            Theme(id: id, name: "Oxblood", flap: Color(light: 0x6B2024, dark: 0x5E1C20),
                  thread: Color(light: 0xE8CFB0, dark: 0xDFC4A3), accent: Color(light: 0x7A262A, dark: 0xD68A84),
                  controlTint: Color(nsColor: NSColor(hex: 0x7A262A)))
        case .olive:
            Theme(id: id, name: "Olive", flap: Color(light: 0x5A5F33, dark: 0x4E532C),
                  thread: Color(light: 0xE7DEBD, dark: 0xDDD3AF), accent: Color(light: 0x51562D, dark: 0xB4BA82),
                  controlTint: Color(nsColor: NSColor(hex: 0x5F6536)))
        case .navy:
            Theme(id: id, name: "Navy", flap: Color(light: 0x263449, dark: 0x222F42),
                  thread: Color(light: 0xDCC59B, dark: 0xD3BB90), accent: Color(light: 0x2C3C55, dark: 0x9DB0CE),
                  controlTint: Color(nsColor: NSColor(hex: 0x34486A)))
        }
    }
}

extension EnvironmentValues {
    @Entry var theme = Theme.named(.cognac)
}

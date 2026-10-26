import AppKit
import PouchCore
import SwiftUI

/// One colorway: the flap's fabric and the thread it's stitched with.
struct Theme: Equatable {
    let id: ThemeID
    let name: String
    /// The flap fabric, also used for the woven label.
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
        case .tomato:
            Theme(id: id, name: "Tomato", flap: Color(light: 0xD04A27, dark: 0xB8432A),
                  thread: Color(light: 0xF6DCC2, dark: 0xF0D2B6), accent: Color(light: 0xB43D1D, dark: 0xF08460),
                  controlTint: Color(nsColor: NSColor(hex: 0xC9482A)))
        case .moss:
            Theme(id: id, name: "Moss", flap: Color(light: 0x55703C, dark: 0x4C6436),
                  thread: Color(light: 0xE6E4C4, dark: 0xDCDBB8), accent: Color(light: 0x4A6334, dark: 0xA3BD84),
                  controlTint: Color(nsColor: NSColor(hex: 0x587540)))
        case .denim:
            Theme(id: id, name: "Denim", flap: Color(light: 0x2F4B7A, dark: 0x2D4672),
                  thread: Color(light: 0xE8CF9E, dark: 0xE2C894), accent: Color(light: 0x2F4B7A, dark: 0x93ACDD),
                  controlTint: Color(nsColor: NSColor(hex: 0x3A5A8F)))
        case .mustard:
            Theme(id: id, name: "Mustard", flap: Color(light: 0xD49D24, dark: 0xBA8920),
                  thread: Color(light: 0x4A3311, dark: 0x3E2B0E), accent: Color(light: 0x8E6411, dark: 0xE4B64C),
                  controlTint: Color(nsColor: NSColor(hex: 0xC69220)))
        }
    }
}

extension EnvironmentValues {
    @Entry var theme = Theme.named(.tomato)
}

import AppKit
import SwiftUI

/// Pouch's fixed colors. Everything is a flat, slightly warm tone: no pure
/// black or white, and no gradients. The pouch is meant to read as an object
/// made of canvas and thread, not as a translucent panel.
enum Palette {
    /// The pouch body.
    static let canvas = Color(light: 0xF1EADD, dark: 0x2B2723)
    /// The inside of the pouch, seen when the flap lifts.
    static let lining = Color(light: 0x3B2F27, dark: 0x120F0D)
    /// Paper slips (text items).
    static let paper = Color(light: 0xFCF9F3, dark: 0x3B3631)
    static let paperRule = Color(light: 0xE5DDCF, dark: 0x4A443E)
    /// Luggage tags (link items).
    static let manila = Color(light: 0xE8D7B0, dark: 0x5B4F3B)

    static let ink = Color(light: 0x241F1B, dark: 0xEEE7DB)
    static let inkSecondary = Color(light: 0x7A6F64, dark: 0xA69C8F)
    static let hairline = Color(light: 0x241F1B, dark: 0xEEE7DB).opacity(0.14)

    static let eyeWhite = Color(light: 0xFBF7EF, dark: 0xF4EEE3)
    static let pupil = Color(light: 0x1E1915, dark: 0x1A1512)
    /// The grommet on the pull tab.
    static let metal = Color(light: 0xCFC7BA, dark: 0xA59C8E)
    static let metalRim = Color(light: 0x8F877B, dark: 0x6D655A)
}

extension Color {
    /// A color with separate light- and dark-mode values, given as 0xRRGGBB.
    init(light: UInt32, dark: UInt32) {
        let lightColor = NSColor(hex: light)
        let darkColor = NSColor(hex: dark)
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? darkColor : lightColor
        })
    }
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

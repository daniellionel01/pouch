import AppKit
import SwiftUI

/// A faint woven grain laid over the canvas and the flap, so they read as
/// fabric rather than flat fills. Generated once from a fixed seed: fine
/// noise plus slightly stronger warp and weft threads.
enum FabricTexture {
    @MainActor static let image: NSImage = makeImage(size: 96)

    private static func makeImage(size: Int) -> NSImage {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 1,
            hasAlpha: false, isPlanar: false, colorSpaceName: .deviceWhite, bytesPerRow: size, bitsPerPixel: 8
        ), let pixels = rep.bitmapData else { return NSImage() }

        var random = SplitMix64(seed: 0x5EED_CAFE)
        for y in 0..<size {
            for x in 0..<size {
                var value = 0.5 + (random.nextUnit() - 0.5) * 0.35
                // Weave: alternate light/dark threads in both directions.
                if y % 2 == 0 { value -= 0.06 }
                if x % 2 == 0 { value -= 0.04 }
                pixels[y * size + x] = UInt8(max(0, min(1, value)) * 255)
            }
        }
        let image = NSImage(size: NSSize(width: size / 2, height: size / 2))
        image.addRepresentation(rep)
        return image
    }
}

/// Tiny deterministic PRNG so the grain looks the same on every launch.
private struct SplitMix64 {
    var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func nextUnit() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }
}

extension View {
    /// Overlays the fabric grain. `strength` is the grain's opacity.
    func fabricGrain(_ strength: Double = 0.07) -> some View {
        overlay {
            Image(nsImage: FabricTexture.image)
                .resizable(resizingMode: .tile)
                .blendMode(.overlay)
                .opacity(strength)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

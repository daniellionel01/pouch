import AppKit
import SwiftUI

/// A faint woven grain laid over the canvas body, so it reads as fabric
/// rather than a flat fill. Generated once from a fixed seed: fine noise plus
/// slightly stronger warp and weft threads.
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

/// Pebbled leather grain for the flap: lots of small, irregular bumps,
/// each lit from above (a light cap and a darker underside). Bumps near the
/// edge are drawn again on the opposite side so the tile repeats seamlessly.
enum LeatherTexture {
    @MainActor static let image: NSImage = makeImage(size: 128)

    private static func makeImage(size: Int) -> NSImage {
        guard let context = CGContext(
            data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return NSImage() }

        context.setFillColor(gray: 0.5, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: size, height: size))

        var random = SplitMix64(seed: 0x1EA7_4E12)
        let side = CGFloat(size)
        for _ in 0..<520 {
            let x = CGFloat(random.nextUnit()) * side
            let y = CGFloat(random.nextUnit()) * side
            let radius = 1.2 + CGFloat(random.nextUnit()) * 2.3
            let squash = 0.75 + CGFloat(random.nextUnit()) * 0.5
            for dx in [-side, 0, side] {
                for dy in [-side, 0, side] {
                    let center = CGPoint(x: x + dx, y: y + dy)
                    guard center.x > -radius * 2, center.x < side + radius * 2,
                          center.y > -radius * 2, center.y < side + radius * 2 else { continue }
                    let bump = CGRect(x: center.x - radius, y: center.y - radius * squash, width: radius * 2, height: radius * 2 * squash)
                    // Shadow side (AppKit's y is up, so "below" is -y).
                    context.setFillColor(gray: 0.38, alpha: 0.55)
                    context.fillEllipse(in: bump.offsetBy(dx: 0.3, dy: -0.6))
                    // Lit cap.
                    context.setFillColor(gray: 0.6, alpha: 0.7)
                    context.fillEllipse(in: bump.insetBy(dx: radius * 0.18, dy: radius * 0.18 * squash).offsetBy(dx: -0.2, dy: 0.3))
                }
            }
        }
        guard let cgImage = context.makeImage() else { return NSImage() }
        return NSImage(cgImage: cgImage, size: NSSize(width: size / 2, height: size / 2))
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
    /// Overlays the canvas weave. `strength` is the grain's opacity.
    func fabricGrain(_ strength: Double = 0.07) -> some View {
        texture(FabricTexture.image, strength: strength)
    }

    /// Overlays pebbled leather grain.
    func leatherGrain(_ strength: Double = 0.32) -> some View {
        texture(LeatherTexture.image, strength: strength)
    }

    private func texture(_ image: NSImage, strength: Double) -> some View {
        overlay {
            Image(nsImage: image)
                .resizable(resizingMode: .tile)
                .blendMode(.overlay)
                .opacity(strength)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

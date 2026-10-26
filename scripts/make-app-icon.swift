#!/usr/bin/env swift
// Draws Pouch's app icon and writes the AppIcon.appiconset.
//
//   swift scripts/make-app-icon.swift Pouch/Resources/Assets.xcassets/AppIcon.appiconset
//
// Everything is drawn on a 1024-pt canvas following the macOS icon grid
// (an 824-pt rounded tile with room for the shadow) and scaled per size.

import AppKit

// Flat colors only, matching the app (see Pouch/Design/Palette.swift and Theme.swift).
let canvas = NSColor(srgbRed: 0.945, green: 0.918, blue: 0.867, alpha: 1)   // #F1EADD
let leather = NSColor(srgbRed: 0.682, green: 0.369, blue: 0.173, alpha: 1)  // #AE5E2C (Cognac)
let thread = NSColor(srgbRed: 0.945, green: 0.875, blue: 0.753, alpha: 1)   // #F1DFC0
let eyeWhite = NSColor(srgbRed: 0.984, green: 0.969, blue: 0.937, alpha: 1) // #FBF7EF
let pupil = NSColor(srgbRed: 0.118, green: 0.098, blue: 0.082, alpha: 1)    // #1E1915
let sky = NSColor(srgbRed: 0.612, green: 0.765, blue: 0.902, alpha: 1)
let hill = NSColor(srgbRed: 0.498, green: 0.639, blue: 0.357, alpha: 1)

/// The flap: square top, sides that meet in a soft point (AppKit's y is up).
func flapPath(inset: CGFloat) -> NSBezierPath {
    let left = 100 + inset, right = 924 - inset, top = 924 - inset
    let side: CGFloat = 575 + inset * 0.6
    let tip = NSPoint(x: 512, y: 470 + inset)
    let path = NSBezierPath()
    path.move(to: NSPoint(x: left, y: side))
    path.line(to: NSPoint(x: left, y: top))
    path.line(to: NSPoint(x: right, y: top))
    path.line(to: NSPoint(x: right, y: side))
    path.curve(to: tip, controlPoint1: NSPoint(x: right - 180, y: side - 8), controlPoint2: NSPoint(x: tip.x + 150, y: tip.y))
    path.curve(to: NSPoint(x: left, y: side), controlPoint1: NSPoint(x: tip.x - 150, y: tip.y), controlPoint2: NSPoint(x: left + 180, y: side - 8))
    path.close()
    return path
}

func withShadow(_ alpha: CGFloat, blur: CGFloat, y: CGFloat, _ draw: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(alpha)
    shadow.shadowBlurRadius = blur
    shadow.shadowOffset = NSSize(width: 0, height: y)
    shadow.set()
    draw()
    NSGraphicsContext.restoreGraphicsState()
}

func drawIcon() {
    // The tile is the pouch body.
    let tile = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 185, yRadius: 185)
    withShadow(0.28, blur: 28, y: -12) {
        canvas.setFill()
        tile.fill()
    }

    NSGraphicsContext.saveGraphicsState()
    tile.addClip()

    // A photo tucked under the flap.
    NSGraphicsContext.saveGraphicsState()
    let transform = NSAffineTransform()
    transform.translateX(by: 640, yBy: 430)
    transform.rotate(byDegrees: -9)
    transform.concat()
    withShadow(0.16, blur: 10, y: -4) {
        NSColor.white.setFill()
        NSBezierPath(rect: NSRect(x: -150, y: -170, width: 300, height: 330)).fill()
    }
    sky.setFill()
    NSBezierPath(rect: NSRect(x: -132, y: -110, width: 264, height: 252)).fill()
    let hillPath = NSBezierPath()
    hillPath.move(to: NSPoint(x: -132, y: -110))
    hillPath.line(to: NSPoint(x: -132, y: -20))
    hillPath.curve(to: NSPoint(x: 132, y: -40), controlPoint1: NSPoint(x: -40, y: 50), controlPoint2: NSPoint(x: 60, y: 30))
    hillPath.line(to: NSPoint(x: 132, y: -110))
    hillPath.close()
    hill.setFill()
    hillPath.fill()
    NSGraphicsContext.restoreGraphicsState()

    // The flap, with its shadow on the body and its stitching.
    withShadow(0.25, blur: 14, y: -8) {
        leather.setFill()
        flapPath(inset: 0).fill()
    }
    // Burnished edge.
    NSGraphicsContext.saveGraphicsState()
    flapPath(inset: 0).addClip()
    let edge = flapPath(inset: 0)
    edge.lineWidth = 14
    NSColor.black.withAlphaComponent(0.3).setStroke()
    edge.stroke()
    NSGraphicsContext.restoreGraphicsState()
    let stitch = flapPath(inset: 46)
    stitch.lineWidth = 13
    stitch.lineCapStyle = .round
    stitch.setLineDash([30, 26], count: 2, phase: 0)
    thread.setStroke()
    stitch.stroke()
    NSGraphicsContext.restoreGraphicsState()

    // Eyes, glancing down at what's inside.
    for centerX in [432.0, 592.0] {
        eyeWhite.setFill()
        NSBezierPath(ovalIn: NSRect(x: centerX - 54, y: 630, width: 108, height: 126)).fill()
        let pupilCenter = NSPoint(x: centerX + 10, y: 672)
        pupil.setFill()
        NSBezierPath(ovalIn: NSRect(x: pupilCenter.x - 31, y: pupilCenter.y - 31, width: 62, height: 62)).fill()
        eyeWhite.setFill()
        NSBezierPath(ovalIn: NSRect(x: pupilCenter.x - 18, y: pupilCenter.y + 6, width: 18, height: 18)).fill()
    }

}

func png(pixels: Int) -> Data? {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { return nil }
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let scale = NSAffineTransform()
    scale.scale(by: CGFloat(pixels) / 1024)
    scale.concat()
    drawIcon()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

guard CommandLine.arguments.count == 2 else {
    print("usage: make-app-icon.swift <path/to/AppIcon.appiconset>")
    exit(1)
}
let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

var images: [[String: String]] = []
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        guard let data = png(pixels: points * scale) else { fatalError("Couldn't render \(name)") }
        try data.write(to: output.appendingPathComponent(name))
        images.append(["idiom": "mac", "size": "\(points)x\(points)", "scale": "\(scale)x", "filename": name])
    }
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    .write(to: output.appendingPathComponent("Contents.json"))
print("Wrote \(images.count) icons to \(output.path)")

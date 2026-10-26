#!/usr/bin/env swift
// Draws Pouch's app icon and writes the AppIcon.appiconset.
//
//   swift scripts/make-app-icon.swift Pouch/Resources/Assets.xcassets/AppIcon.appiconset
//
// Everything is drawn on a 1024-pt canvas following the macOS icon grid
// (an 824-pt rounded tile with room for the shadow) and scaled per size.

import AppKit

let kangaroo = NSColor(srgbRed: 0.91, green: 0.55, blue: 0.27, alpha: 1)
let cream = NSColor(srgbRed: 1.0, green: 0.97, blue: 0.93, alpha: 1)
let cocoa = NSColor(srgbRed: 0.38, green: 0.22, blue: 0.12, alpha: 1)

func roundedPath(_ rect: NSRect, top: CGFloat, bottom: CGFloat) -> NSBezierPath {
    // AppKit's origin is bottom-left, so "bottom" corners are at minY.
    let path = NSBezierPath()
    path.move(to: NSPoint(x: rect.minX + bottom, y: rect.minY))
    path.line(to: NSPoint(x: rect.maxX - bottom, y: rect.minY))
    path.appendArc(withCenter: NSPoint(x: rect.maxX - bottom, y: rect.minY + bottom), radius: bottom, startAngle: 270, endAngle: 360)
    path.line(to: NSPoint(x: rect.maxX, y: rect.maxY - top))
    path.appendArc(withCenter: NSPoint(x: rect.maxX - top, y: rect.maxY - top), radius: top, startAngle: 0, endAngle: 90)
    path.line(to: NSPoint(x: rect.minX + top, y: rect.maxY))
    path.appendArc(withCenter: NSPoint(x: rect.minX + top, y: rect.maxY - top), radius: top, startAngle: 90, endAngle: 180)
    path.line(to: NSPoint(x: rect.minX, y: rect.minY + bottom))
    path.appendArc(withCenter: NSPoint(x: rect.minX + bottom, y: rect.minY + bottom), radius: bottom, startAngle: 180, endAngle: 270)
    path.close()
    return path
}

func drawIcon() {
    // Tile with a soft shadow.
    let tile = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 185, yRadius: 185)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
    shadow.shadowBlurRadius = 28
    shadow.shadowOffset = NSSize(width: 0, height: -12)
    shadow.set()
    kangaroo.setFill()
    tile.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(colors: [NSColor(srgbRed: 1.0, green: 0.74, blue: 0.45, alpha: 1), NSColor(srgbRed: 0.87, green: 0.45, blue: 0.20, alpha: 1)])?
        .draw(in: tile, angle: -90)

    // A screenshot polaroid peeking out of the pouch.
    NSGraphicsContext.saveGraphicsState()
    let transform = NSAffineTransform()
    transform.translateX(by: 470, yBy: 620)
    transform.rotate(byDegrees: 12)
    transform.concat()
    let card = NSBezierPath(roundedRect: NSRect(x: -150, y: -130, width: 300, height: 280), xRadius: 22, yRadius: 22)
    NSColor.white.setFill()
    card.fill()
    let photo = NSBezierPath(roundedRect: NSRect(x: -126, y: -60, width: 252, height: 186), xRadius: 12, yRadius: 12)
    NSGradient(colors: [NSColor(srgbRed: 0.45, green: 0.62, blue: 1.0, alpha: 1), NSColor(srgbRed: 0.62, green: 0.42, blue: 0.96, alpha: 1)])?
        .draw(in: photo, angle: -60)
    NSGraphicsContext.restoreGraphicsState()

    // The pouch.
    let pouchRect = NSRect(x: 252, y: 190, width: 520, height: 440)
    let pouch = roundedPath(pouchRect, top: 70, bottom: 210)
    NSGraphicsContext.saveGraphicsState()
    let pouchShadow = NSShadow()
    pouchShadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
    pouchShadow.shadowBlurRadius = 18
    pouchShadow.shadowOffset = NSSize(width: 0, height: -8)
    pouchShadow.set()
    cream.setFill()
    pouch.fill()
    NSGraphicsContext.restoreGraphicsState()

    // Stitching.
    let stitch = roundedPath(pouchRect.insetBy(dx: 36, dy: 36), top: 40, bottom: 176)
    stitch.lineWidth = 14
    stitch.lineCapStyle = .round
    stitch.setLineDash([26, 24], count: 2, phase: 0)
    kangaroo.withAlphaComponent(0.55).setStroke()
    stitch.stroke()

    // Sleepy face.
    cocoa.setStroke()
    for centerX in [432.0, 592.0] {
        let eye = NSBezierPath()
        eye.appendArc(withCenter: NSPoint(x: centerX, y: 440), radius: 38, startAngle: 200, endAngle: 340)
        eye.lineWidth = 20
        eye.lineCapStyle = .round
        eye.stroke()
    }
    cocoa.setFill()
    NSBezierPath(roundedRect: NSRect(x: 482, y: 336, width: 60, height: 22), xRadius: 11, yRadius: 11).fill()
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

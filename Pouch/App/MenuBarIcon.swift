import AppKit

/// The menu bar icon: a tiny pouch, drawn in code as a template image so it
/// follows the menu bar's light/dark appearance. The flap is solid with the
/// eyes punched out of it; the body is a lighter fill. (An outlined, hollow
/// body read as a wide-open mouth under the eyes.)
enum MenuBarIcon {
    enum Expression {
        case awake
        /// Happy squint, shown briefly when a screenshot comes in.
        case delighted
    }

    static func image(_ expression: Expression = .awake) -> NSImage {
        // flipped: y grows downward, which makes the drawing easier to read.
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
            NSColor.black.set()

            // Body: snug top corners, deep rounded bottom. Template images
            // keep their alpha, so this shows as a lighter shade of the
            // menu bar's icon color.
            NSColor.black.withAlphaComponent(0.42).set()
            pouchPath(in: NSRect(x: 2.4, y: 2.2, width: 13.2, height: 13.6), top: 2.4, bottom: 5.4).fill()
            NSColor.black.set()

            // Flap: square top, sides meeting in a soft point.
            let flap = NSBezierPath()
            flap.move(to: NSPoint(x: 2.6, y: 4.6))
            flap.appendArc(withCenter: NSPoint(x: 4.8, y: 4.6), radius: 2.2, startAngle: 180, endAngle: 270)
            flap.line(to: NSPoint(x: 13.2, y: 2.4))
            flap.appendArc(withCenter: NSPoint(x: 13.2, y: 4.6), radius: 2.2, startAngle: 270, endAngle: 360)
            flap.line(to: NSPoint(x: 15.4, y: 8.4))
            flap.curve(to: NSPoint(x: 9, y: 10.8), controlPoint1: NSPoint(x: 13.2, y: 8.6), controlPoint2: NSPoint(x: 10.6, y: 10.8))
            flap.curve(to: NSPoint(x: 2.6, y: 8.4), controlPoint1: NSPoint(x: 7.4, y: 10.8), controlPoint2: NSPoint(x: 4.8, y: 8.6))
            flap.close()
            flap.fill()

            // Eyes, punched out of the flap.
            NSGraphicsContext.current?.compositingOperation = .clear
            switch expression {
            case .awake:
                for x in [6.1, 10.1] {
                    NSBezierPath(ovalIn: NSRect(x: x, y: 4.5, width: 1.8, height: 2.3)).fill()
                }
            case .delighted:
                for x in [6.0, 10.0] {
                    let arc = NSBezierPath()
                    arc.move(to: NSPoint(x: x, y: 6.5))
                    arc.curve(to: NSPoint(x: x + 2, y: 6.5), controlPoint1: NSPoint(x: x + 0.4, y: 4.7), controlPoint2: NSPoint(x: x + 1.6, y: 4.7))
                    arc.lineWidth = 1.1
                    arc.lineCapStyle = .round
                    arc.stroke()
                }
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Pouch"
        return image
    }

    private static func pouchPath(in rect: NSRect, top: CGFloat, bottom: CGFloat) -> NSBezierPath {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: rect.minX + top, y: rect.minY))
        path.line(to: NSPoint(x: rect.maxX - top, y: rect.minY))
        path.appendArc(withCenter: NSPoint(x: rect.maxX - top, y: rect.minY + top), radius: top, startAngle: 270, endAngle: 360)
        path.line(to: NSPoint(x: rect.maxX, y: rect.maxY - bottom))
        path.appendArc(withCenter: NSPoint(x: rect.maxX - bottom, y: rect.maxY - bottom), radius: bottom, startAngle: 0, endAngle: 90)
        path.line(to: NSPoint(x: rect.minX + bottom, y: rect.maxY))
        path.appendArc(withCenter: NSPoint(x: rect.minX + bottom, y: rect.maxY - bottom), radius: bottom, startAngle: 90, endAngle: 180)
        path.line(to: NSPoint(x: rect.minX, y: rect.minY + top))
        path.appendArc(withCenter: NSPoint(x: rect.minX + top, y: rect.minY + top), radius: top, startAngle: 180, endAngle: 270)
        path.close()
        return path
    }
}

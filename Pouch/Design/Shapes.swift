import SwiftUI

/// The pouch's silhouette: snug top corners, deep rounded bottom.
///
/// `bulgePosition`/`bulgeAmount` push the sides outward around one height,
/// which is how the "swallow" travels down the body after a drop.
struct BodyShape: Shape {
    static let topRadius: CGFloat = 16
    static let bottomRadius: CGFloat = 30

    var bulgePosition: CGFloat = 0
    var bulgeAmount: CGFloat = 0

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(bulgePosition, bulgeAmount) }
        set { (bulgePosition, bulgeAmount) = (newValue.first, newValue.second) }
    }

    func path(in rect: CGRect) -> Path {
        let top = Self.topRadius
        let bottom = Self.bottomRadius
        let sideTop = rect.minY + top
        let sideBottom = rect.maxY - bottom
        let bulgeY = sideTop + (sideBottom - sideTop) * bulgePosition

        var path = Path()
        path.move(to: CGPoint(x: rect.minX + top, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - top, y: rect.minY))
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: sideTop), radius: top)
        addSide(to: &path, x: rect.maxX, from: sideTop, to: sideBottom, bulgeY: bulgeY, outward: 1)
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY), tangent2End: CGPoint(x: rect.maxX - bottom, y: rect.maxY), radius: bottom)
        path.addLine(to: CGPoint(x: rect.minX + bottom, y: rect.maxY))
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: sideBottom), radius: bottom)
        addSide(to: &path, x: rect.minX, from: sideBottom, to: sideTop, bulgeY: bulgeY, outward: -1)
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY), tangent2End: CGPoint(x: rect.minX + top, y: rect.minY), radius: top)
        path.closeSubpath()
        return path
    }

    private func addSide(to path: inout Path, x: CGFloat, from start: CGFloat, to end: CGFloat, bulgeY: CGFloat, outward: CGFloat) {
        guard bulgeAmount > 0.05 else {
            path.addLine(to: CGPoint(x: x, y: end))
            return
        }
        let span: CGFloat = 38
        let direction: CGFloat = end > start ? 1 : -1
        let low = min(start, end)
        let high = max(start, end)
        let before = min(max(bulgeY - span * direction, low), high)
        let after = min(max(bulgeY + span * direction, low), high)
        path.addLine(to: CGPoint(x: x, y: before))
        // A quadratic's peak is half its control offset, hence the 2×.
        path.addQuadCurve(to: CGPoint(x: x, y: after), control: CGPoint(x: x + outward * bulgeAmount * 2, y: bulgeY))
        path.addLine(to: CGPoint(x: x, y: end))
    }
}

/// The flap over the pouch's opening: square top, sides that run down and
/// meet in a soft point where the snap sits. `lift` raises that point, which
/// is the pouch opening its mouth.
struct FlapShape: Shape {
    /// How high the tip lifts when fully open.
    static let maxLift: CGFloat = 10
    /// How much shorter the sides are than the tip.
    static let tipDepth: CGFloat = 16

    var lift: CGFloat = 0
    /// Insets the outline, for the stitching that runs just inside the edge.
    var inset: CGFloat = 0

    var animatableData: CGFloat {
        get { lift }
        set { lift = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: inset, dy: inset)
        let corner = max(BodyShape.topRadius - inset, 2)
        let sideBottom = r.maxY - Self.tipDepth
        let tip = CGPoint(x: r.midX, y: r.maxY - lift * Self.maxLift)
        // Lifting also pulls the sides up a little, like fabric folding back.
        let side = sideBottom - lift * Self.maxLift * 0.35

        var path = Path()
        path.move(to: CGPoint(x: r.minX, y: side))
        path.addLine(to: CGPoint(x: r.minX, y: r.minY + corner))
        path.addArc(tangent1End: CGPoint(x: r.minX, y: r.minY), tangent2End: CGPoint(x: r.minX + corner, y: r.minY), radius: corner)
        path.addLine(to: CGPoint(x: r.maxX - corner, y: r.minY))
        path.addArc(tangent1End: CGPoint(x: r.maxX, y: r.minY), tangent2End: CGPoint(x: r.maxX, y: r.minY + corner), radius: corner)
        path.addLine(to: CGPoint(x: r.maxX, y: side))
        path.addCurve(
            to: tip,
            control1: CGPoint(x: r.maxX - r.width * 0.22, y: side + 2),
            control2: CGPoint(x: tip.x + 30, y: tip.y)
        )
        path.addCurve(
            to: CGPoint(x: r.minX, y: side),
            control1: CGPoint(x: tip.x - 30, y: tip.y),
            control2: CGPoint(x: r.minX + r.width * 0.22, y: side + 2)
        )
        return path
    }
}

/// A rectangle whose bottom edge is cut with pinking shears.
struct PinkedSlipShape: Shape {
    var toothWidth: CGFloat = 6
    var toothDepth: CGFloat = 3

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - toothDepth))
        let teeth = max(1, Int((rect.width / toothWidth).rounded()))
        let step = rect.width / CGFloat(teeth)
        for index in 0..<teeth {
            let x = rect.maxX - CGFloat(index) * step
            path.addLine(to: CGPoint(x: x - step / 2, y: rect.maxY))
            path.addLine(to: CGPoint(x: x - step, y: rect.maxY - toothDepth))
        }
        path.closeSubpath()
        return path
    }
}

/// A luggage tag: clipped corners on the left and a punched hole.
struct TagShape: Shape {
    func path(in rect: CGRect) -> Path {
        let clip = min(10, rect.height * 0.3)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + clip, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - 3, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + 3), control: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - 3))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - 3, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + clip, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - clip))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + clip))
        path.closeSubpath()
        // The hole, cut out with the even-odd rule.
        path.addEllipse(in: CGRect(x: rect.minX + 7, y: rect.midY - 3, width: 6, height: 6))
        return path
    }
}

/// Stitching: short dashes with rounded ends, like a running stitch.
extension StrokeStyle {
    static func stitch(width: CGFloat = 1.3) -> StrokeStyle {
        StrokeStyle(lineWidth: width, lineCap: .round, dash: [3.2, 3])
    }
}

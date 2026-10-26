import SwiftUI

/// Two eyes, drawn from `Character` state.
struct FaceView: View {
    var character: Character
    /// The fabric around the eyes; eyelids are made of it.
    var lidColor: Color
    var spacing: CGFloat = 11

    var body: some View {
        let expression = character.expression
        HStack(spacing: spacing) {
            EyeView(side: .left, expression: expression, isBlinking: character.isBlinking, look: character.look, lidColor: lidColor)
            EyeView(side: .right, expression: expression, isBlinking: character.isBlinking, look: character.look, lidColor: lidColor)
        }
        .accessibilityHidden(true)
    }
}

struct EyeView: View {
    enum Side { case left, right }

    static let size = CGSize(width: 18, height: 21)

    var side: Side
    var expression: Character.Mood
    var isBlinking: Bool
    var look: CGVector
    var lidColor: Color

    var body: some View {
        ZStack {
            switch expression {
            case .asleep:
                // Closed and relaxed: a downward curve.
                EyeArc(curve: .down)
                    .stroke(Palette.eyeWhite, style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                    .frame(width: 14, height: 5)
                    .offset(y: 4)
            case .delighted:
                // Happy squint: an upward curve.
                EyeArc(curve: .up)
                    .stroke(Palette.eyeWhite, style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
                    .frame(width: 14, height: 6)
            case .squeeze:
                // Screwed shut: > <
                Chevron(pointsRight: side == .left)
                    .stroke(Palette.eyeWhite, style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
                    .frame(width: 9, height: 11)
            default:
                openEye
            }
        }
        .frame(width: Self.size.width, height: Self.size.height * 1.22)
        .animation(.pouchCharacter, value: expression)
    }

    private var openEye: some View {
        let lid = isBlinking ? 1 : expression.lid
        let pupil = 8.5 * expression.pupilScale
        let travel = CGSize(width: (Self.size.width - pupil) / 2 - 1, height: (Self.size.height - pupil) / 2 - 1)
        return ZStack(alignment: .top) {
            Ellipse().fill(Palette.eyeWhite)
            Circle()
                .fill(Palette.pupil)
                .frame(width: pupil, height: pupil)
                .overlay(alignment: .topLeading) {
                    // A catchlight makes the eye read as wet and alive.
                    Circle()
                        .fill(Palette.eyeWhite)
                        .frame(width: pupil * 0.3, height: pupil * 0.3)
                        .offset(x: pupil * 0.18, y: pupil * 0.16)
                }
                .offset(x: look.dx * travel.width, y: look.dy * travel.height)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            // The upper lid comes down from the top.
            Rectangle()
                .fill(lidColor)
                .frame(height: Self.size.height * lid)
                .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .clipShape(Ellipse())
        .scaleEffect(x: 1, y: expression.eyeStretch, anchor: .bottom)
        .animation(isBlinking ? .easeIn(duration: 0.06) : .easeOut(duration: 0.1), value: isBlinking)
    }
}

private struct EyeArc: Shape {
    enum Curve { case up, down }
    var curve: Curve

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let edgeY = curve == .up ? rect.maxY : rect.minY
        let controlY = curve == .up ? rect.minY - rect.height : rect.maxY + rect.height
        path.move(to: CGPoint(x: rect.minX, y: edgeY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: edgeY), control: CGPoint(x: rect.midX, y: controlY))
        return path
    }
}

private struct Chevron: Shape {
    var pointsRight: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let tipX = pointsRight ? rect.maxX : rect.minX
        let backX = pointsRight ? rect.minX : rect.maxX
        path.move(to: CGPoint(x: backX, y: rect.minY))
        path.addLine(to: CGPoint(x: tipX, y: rect.midY))
        path.addLine(to: CGPoint(x: backX, y: rect.maxY))
        return path
    }
}

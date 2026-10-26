import SwiftUI

/// Shown when the shelf is empty: a sleepy little pouch that wakes up when
/// something is dragged over it.
struct EmptyStateView: View {
    var isAwake: Bool

    var body: some View {
        VStack(spacing: 14) {
            PouchCharacter(isAwake: isAwake)
                .frame(width: 84, height: 74)
            VStack(spacing: 4) {
                Text(isAwake ? Quips.hungry : Quips.ofTheDay())
                    .font(.system(.callout, design: .rounded).weight(.semibold))
                    .contentTransition(.opacity)
                Text("Drop files here, or take a screenshot")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Decoration only: let clicks fall through to the window-drag background.
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
    }
}

/// The pouch mascot. Also used in the Settings header.
struct PouchCharacter: View {
    var isAwake: Bool
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ZStack {
                PouchShape()
                    .fill(theme.accent.gradient)
                PouchShape()
                    .stroke(.white.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                    .padding(5)
                face
                    .offset(y: 4)
            }
            .scaleEffect(isAwake && !reduceMotion ? 1.08 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: isAwake)

            if !isAwake {
                Snores(animated: !reduceMotion)
                    .offset(x: 14, y: -14)
            }
        }
    }

    private var face: some View {
        VStack(spacing: 6) {
            HStack(spacing: 18) {
                Eye(isOpen: isAwake)
                Eye(isOpen: isAwake)
            }
            Capsule()
                .fill(.white.opacity(0.9))
                .frame(width: isAwake ? 12 : 8, height: isAwake ? 10 : 2.5)
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isAwake)
    }
}

private struct Eye: View {
    var isOpen: Bool

    var body: some View {
        Group {
            if isOpen {
                Circle()
                    .fill(.white)
                    .frame(width: 9, height: 9)
            } else {
                // A closed eye is just a little downward arc.
                Path { path in
                    path.addArc(center: CGPoint(x: 5, y: 1), radius: 5, startAngle: .degrees(20), endAngle: .degrees(160), clockwise: false)
                }
                .stroke(.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: 10, height: 6)
            }
        }
        .frame(width: 10, height: 9)
    }
}

/// "z z z" drifting up from the sleeping pouch.
private struct Snores: View {
    var animated: Bool

    var body: some View {
        if animated {
            // 20 fps is plenty for slow-drifting letters and keeps an always-on
            // panel cheap.
            TimelineView(.animation(minimumInterval: 1 / 20)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                ZStack {
                    ForEach(0..<3, id: \.self) { index in
                        snore(index: index, phase: (t / 2.4 + Double(index) / 3).truncatingRemainder(dividingBy: 1))
                    }
                }
            }
        } else {
            Text("z").font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(.secondary)
        }
    }

    private func snore(index: Int, phase: Double) -> some View {
        Text("z")
            .font(.system(size: 8 + phase * 6, weight: .bold, design: .rounded))
            .foregroundStyle(.secondary)
            .offset(x: phase * 10, y: -phase * 18)
            .opacity(phase < 0.15 ? phase / 0.15 : 1 - (phase - 0.15) / 0.85)
    }
}

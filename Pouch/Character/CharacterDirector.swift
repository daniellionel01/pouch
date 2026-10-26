import AppKit
import PouchCore
import SwiftUI

/// Brings the character to life: follows the cursor, blinks and glances at
/// irregular intervals, dozes off when nothing happens, and reacts to what
/// happens on the shelf.
///
/// Motion is layered, the way character rigs usually are: the resting mood,
/// short reactions on top of it, and an independent blink/glance loop. All
/// timing is randomized so it never looks like a loop.
@MainActor
final class CharacterDirector {
    let character = Character()

    private let store: ShelfStore
    private let ui: ShelfUIState
    /// The point between the eyes, in screen coordinates.
    var faceCenter: () -> CGPoint? = { nil }
    /// The shelf's frame, for "is the cursor close?"
    var panelFrame: () -> NSRect? = { nil }

    private var mouseMonitors: [Any] = []
    private var lifeLoop: Task<Void, Never>?
    private var reactionTask: Task<Void, Never>?
    private var lastCursorPoint = NSPoint.zero
    private var lastCursorMove = Date.distantPast
    private var lastLookUpdate = Date.distantPast

    /// No mouse movement for this long and the pouch starts to doze.
    private static let drowsyAfter: TimeInterval = 75
    /// An empty pouch wakes when the cursor comes this close.
    private static let wakeDistance: CGFloat = 90

    init(store: ShelfStore, ui: ShelfUIState) {
        self.store = store
        self.ui = ui
        observeReactions()
    }

    // MARK: - Lifecycle (only runs while the shelf is on screen)

    func start() {
        guard lifeLoop == nil else { return }
        installMouseMonitors()
        // Showing the shelf isn't the same as someone coming near: an empty
        // pouch stays asleep unless the cursor is actually close.
        lastCursorPoint = NSEvent.mouseLocation
        lastCursorMove = store.isEmpty && !cursorIsNear ? .distantPast : .now
        updateMood()
        lifeLoop = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Double.random(in: 1.8...5.2)))
                guard !Task.isCancelled else { return }
                await self?.liveALittle()
            }
        }
    }

    func stop() {
        lifeLoop?.cancel()
        lifeLoop = nil
        mouseMonitors.forEach(NSEvent.removeMonitor)
        mouseMonitors = []
    }

    // MARK: - Reactions

    /// Shows `mood` for a moment, then returns to the resting mood.
    func react(_ mood: Character.Mood, for duration: Duration) {
        reactionTask?.cancel()
        withAnimation(.pouchCharacter) { character.reaction = mood }
        reactionTask = Task { [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled, let self else { return }
            withAnimation(.pouchCharacter) { self.character.reaction = nil }
        }
    }

    /// Screenshots get a double take: a startle, then delight.
    private func doubleTake() {
        reactionTask?.cancel()
        withAnimation(.spring(response: 0.18, dampingFraction: 0.45)) { character.reaction = .startled }
        reactionTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(0.32))
            guard !Task.isCancelled, let self else { return }
            self.react(.delighted, for: .seconds(0.7))
        }
    }

    /// Shut eyes right before the shelf is put away.
    func closeEyes() {
        reactionTask?.cancel()
        withAnimation(.easeIn(duration: 0.1)) { character.reaction = .asleep }
    }

    func clearReaction() {
        reactionTask?.cancel()
        character.reaction = nil
    }

    private func observeReactions() {
        observeChanges({ [ui] in ui.gulpCount }) { [weak self] _ in
            guard self?.character.reaction != .startled else { return }
            self?.react(.delighted, for: .seconds(0.75))
        }
        observeChanges({ [ui] in ui.snapCount }) { [weak self] _ in self?.doubleTake() }
        observeChanges({ [ui] in ui.shakeCount }) { [weak self] _ in self?.react(.squeeze, for: .seconds(0.9)) }
        observeChanges({ [ui] in ui.dragOutCount }) { [weak self] _ in self?.react(.delighted, for: .seconds(0.55)) }
        observeChanges({ [ui, store] in (ui.isDropTargeted, ui.draggingIDs.isEmpty, store.isEmpty) }) { [weak self] _ in
            self?.updateMood()
        }
    }

    // MARK: - Looking

    /// Feed cursor positions (screen coordinates) from anywhere: mouse
    /// monitors, drags over the shelf, drags out of it.
    func cursorMoved(to point: NSPoint) {
        let now = Date.now
        if hypot(point.x - lastCursorPoint.x, point.y - lastCursorPoint.y) > 2 {
            lastCursorMove = now
        }
        lastCursorPoint = point
        // ~40 updates a second is plenty for eyes; mice report far more often.
        guard now.timeIntervalSince(lastLookUpdate) > 0.025 else { return }
        lastLookUpdate = now
        updateMood()
        guard character.expression != .asleep, let center = faceCenter() else { return }
        let target = lookVector(from: center, to: point)
        withAnimation(.spring(response: 0.16, dampingFraction: 0.78)) { character.look = target }
    }

    private func lookVector(from center: CGPoint, to point: NSPoint) -> CGVector {
        // Screen y grows upward, view y downward.
        let dx = point.x - center.x
        let dy = center.y - point.y
        let distance = hypot(dx, dy)
        guard distance > 1 else { return .zero }
        // Close by, the eyes swing fully toward the cursor; far away, they
        // only lean that way.
        let reach = min(1, distance / 160)
        return CGVector(dx: dx / distance * reach, dy: dy / distance * reach)
    }

    private func installMouseMonitors() {
        let events: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged]
        // Global monitors see movement over other apps. Mouse-movement
        // monitoring needs no Accessibility permission (key events would).
        if let global = NSEvent.addGlobalMonitorForEvents(matching: events, handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.cursorMoved(to: NSEvent.mouseLocation) }
        }) {
            mouseMonitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: events, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.cursorMoved(to: NSEvent.mouseLocation) }
            return event
        }) {
            mouseMonitors.append(local)
        }
    }

    // MARK: - Resting mood

    private func updateMood() {
        let mood = restingMood()
        guard mood != character.mood else { return }
        withAnimation(.pouchCharacter) { character.mood = mood }
        if mood == .asleep {
            withAnimation(.easeInOut(duration: 0.8)) { character.look = .zero }
        }
    }

    private func restingMood() -> Character.Mood {
        if ui.isDropTargeted || !ui.draggingIDs.isEmpty { return .curious }
        let idle = Date.now.timeIntervalSince(lastCursorMove)
        if store.isEmpty {
            // Nothing to guard: it naps, and stirs when you come near.
            return cursorIsNear && idle < 4 ? .awake : .asleep
        }
        return idle > Self.drowsyAfter ? .drowsy : .awake
    }

    private var cursorIsNear: Bool {
        guard let frame = panelFrame() else { return false }
        return frame.insetBy(dx: -Self.wakeDistance, dy: -Self.wakeDistance).contains(lastCursorPoint)
    }

    // MARK: - Idle life

    /// One beat of idle behavior: blink, glance, or sigh in its sleep.
    private func liveALittle() async {
        updateMood()
        switch character.expression {
        case .asleep:
            if Double.random(in: 0...1) < 0.35 { character.sighs += 1 }
        case .awake, .drowsy, .curious:
            await blink(slow: character.expression == .drowsy)
            if Double.random(in: 0...1) < 0.18 {
                try? await Task.sleep(for: .seconds(0.16))
                await blink(slow: false)
            }
            glanceIfIdle()
        default:
            break
        }
    }

    private func blink(slow: Bool) async {
        character.isBlinking = true
        try? await Task.sleep(for: .seconds(slow ? 0.24 : 0.1))
        character.isBlinking = false
    }

    /// With the cursor still for a while, the eyes wander on their own
    /// instead of staring at the same spot.
    private func glanceIfIdle() {
        guard Date.now.timeIntervalSince(lastCursorMove) > 5 else { return }
        let target = Double.random(in: 0...1) < 0.4
            ? CGVector.zero
            : CGVector(dx: Double.random(in: -0.8...0.8), dy: Double.random(in: -0.3...0.7))
        withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) { character.look = target }
    }
}

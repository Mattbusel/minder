import CoreGraphics
import Foundation

/// Decides what the eyes feel and where they look, one frame at a time.
/// Deliberately not observable: the Canvas pulls from it every frame, and
/// nothing in SwiftUI needs to re-render because a brow moved.
final class Brain {
    enum Mode { case idle, work }

    private(set) var mode: Mode = .idle
    private(set) var face = SpringVector(Expression.neutral.face.values)
    private var gaze = SpringVector([0, 0])
    private var bob = SpringVector([0])

    private var base: Expression = .neutral
    private var flash: Expression?
    private var flashUntil: Double = 0

    private var gazeTarget = CGPoint.zero
    private var nextGazeAt: Double = 0
    private var gazeHoldUntil: Double = 0
    private var nextSaccadeAt: Double = 0
    private var saccade = CGPoint.zero

    private var blinkStart: Double = -10
    private var nextBlinkAt: Double = 2
    private var doubleBlinkPending = false

    private var nextMoodAt: Double = 25
    private var lastInteraction: Double = 0
    private var workStart: Double = 0
    private var lastChime: Double = 0

    private var faceSeenAt: Double = -100
    private var facePoint = CGPoint.zero
    private var searching = false
    private var lastTime: Double?
    var cameraOn = false

    /// Frozen expression for store screenshots.
    var pinned: Expression?

    var chimeInterval: Double = 25 * 60
    var onChime: (() -> Void)?

    // MARK: events

    func engage(at t: Double) {
        mode = .work
        workStart = t; lastChime = t; faceSeenAt = t; searching = false
        react(.surprised, for: 0.45, at: t)
        base = .attentive
        schedule(.happy, after: 0.5, for: 1.4, at: t)
        nodBob(-14)
        nextMoodAt = t + 30
        gazeTarget = .zero; gazeHoldUntil = t + 3
    }

    func disengage(at t: Double) {
        let worked = t - workStart
        mode = .idle
        base = .neutral
        react(worked > 300 ? .proud : .curious, for: 2.4, at: t)
        nodBob(worked > 300 ? -18 : 0)
        lastInteraction = t
    }

    func touched(at point: CGPoint, t: Double) {
        lastInteraction = t
        gazeTarget = point; gazeHoldUntil = t + 1.6
        if mode == .work {
            react(.suspicious, for: 1.8, at: t)
        } else if base == .sleepy || base == .asleep {
            base = .neutral
            react(.surprised, for: 0.6, at: t)
            blinkStart = t + 0.6
        } else {
            react(.happy, for: 1.3, at: t)
            nodBob(-8)
        }
    }

    func phoneMoved(at t: Double) {
        guard mode == .work, t > flashUntil - 0.5 || flash != .suspicious else { return }
        react(.surprised, for: 0.35, at: t)
        schedule(.suspicious, after: 0.35, for: 3.5, at: t)
        gazeTarget = CGPoint(x: 0, y: 0.8); gazeHoldUntil = t + 2
    }

    func sawFace(_ p: CGPoint, at t: Double) {
        let wasGone = t - faceSeenAt > 12
        faceSeenAt = t
        facePoint = p
        if wasGone && searching {
            searching = false
            react(.happy, for: 2.2, at: t)
            nodBob(-12)
        }
    }

    // MARK: frame

    private var scheduled: [(at: Double, e: Expression, dur: Double)] = []

    private func react(_ e: Expression, for d: Double, at t: Double) {
        flash = e; flashUntil = t + d
    }
    private func schedule(_ e: Expression, after: Double, for d: Double, at t: Double) {
        scheduled.append((t + after, e, d))
    }
    private func nodBob(_ amount: CGFloat) { bob.v[0] += amount * 18 }

    struct Frame {
        var face: Face
        var gaze: CGPoint
        var blink: CGFloat
        var bob: CGFloat
    }

    func step(at t: Double) -> Frame {
        if lastTime == nil { lastInteraction = t; nextBlinkAt = t + 2; nextMoodAt = t + 25 }
        let dt = CGFloat(min(max(t - (lastTime ?? t), 0), 1.0 / 20))
        lastTime = t

        for s in scheduled where s.at <= t { react(s.e, for: s.dur, at: s.at) }
        scheduled.removeAll { $0.at <= t }
        if flash != nil && t > flashUntil { flash = nil }

        think(t)

        let expr = pinned ?? flash ?? base
        face.step(toward: expr.face.values, dt: dt, stiffness: 190, damping: 0.62)

        // Gaze: face tracking beats everything but a deliberate glance.
        var target = gazeTarget
        if t > gazeHoldUntil, cameraOn, t - faceSeenAt < 1.2 { target = facePoint }
        if t > nextSaccadeAt {
            saccade = CGPoint(x: .random(in: -0.05...0.05), y: .random(in: -0.04...0.04))
            nextSaccadeAt = t + .random(in: 0.25...0.9)
        }
        if pinned != nil { target = pinnedGaze(pinned!) }
        gaze.step(toward: [target.x + saccade.x, target.y + saccade.y], dt: dt, stiffness: 420, damping: 0.8)
        bob.step(toward: [0], dt: dt, stiffness: 140, damping: 0.38)

        return Frame(face: Face(values: face.x),
                     gaze: CGPoint(x: gaze.x[0], y: gaze.x[1]),
                     blink: blinkAmount(t),
                     bob: bob.x[0])
    }

    private func pinnedGaze(_ e: Expression) -> CGPoint {
        switch e {
        case .suspicious: return CGPoint(x: -0.55, y: 0.1)
        case .sleepy: return CGPoint(x: 0.1, y: 0.45)
        case .curious: return CGPoint(x: 0.45, y: -0.25)
        default: return CGPoint(x: 0.08, y: 0.05)
        }
    }

    private func blinkAmount(_ t: Double) -> CGFloat {
        if pinned == nil, t >= nextBlinkAt {
            blinkStart = t
            if doubleBlinkPending {
                doubleBlinkPending = false
                nextBlinkAt = t + .random(in: 2.5...6.5)
            } else if Double.random(in: 0...1) < 0.18 {
                doubleBlinkPending = true
                nextBlinkAt = t + 0.24
            } else {
                let sleepy = base == .sleepy
                nextBlinkAt = t + (sleepy ? .random(in: 1.4...3) : .random(in: 2.2...6.5))
            }
        }
        let slow = base == .sleepy ? 2.2 : 1
        let e = (t - blinkStart) / slow
        if e < 0 { return 0 }
        if e < 0.07 { return CGFloat(e / 0.07) }
        if e < 0.17 { return CGFloat(1 - (e - 0.07) / 0.1) }
        return 0
    }

    /// The slow layer: moods that change over seconds and minutes.
    private func think(_ t: Double) {
        switch mode {
        case .idle:
            let quiet = t - lastInteraction
            if quiet > 150 { base = .asleep } else if quiet > 70 { base = .sleepy } else if base == .sleepy || base == .asleep { base = .neutral }
            if t > nextGazeAt && t > gazeHoldUntil && base != .asleep {
                let r = base == .sleepy ? 0.35 : 0.85
                gazeTarget = CGPoint(x: .random(in: -r...r), y: .random(in: -r * 0.6...r * 0.7))
                if Double.random(in: 0...1) < 0.35 { gazeTarget = .zero }
                nextGazeAt = t + .random(in: 1.2...4.2)
            }
            if base == .asleep { gazeTarget = CGPoint(x: 0, y: 0.5) }

        case .work:
            let gone = cameraOn ? t - faceSeenAt : 0
            if cameraOn && gone > 14 {
                if !searching { searching = true; react(.curious, for: 1.5, at: t) }
                base = gone > 50 ? .sad : .attentive
                if t > nextGazeAt {
                    gazeTarget = CGPoint(x: gazeTarget.x > 0 ? -0.9 : 0.9, y: .random(in: -0.2...0.2))
                    nextGazeAt = t + .random(in: 1.1...1.8)
                }
                return
            }
            base = (t - workStart) > 90 ? .focused : .attentive

            if t > nextGazeAt && t > gazeHoldUntil {
                // Mostly on you. Now and then a glance away, like it heard something.
                if Double.random(in: 0...1) < 0.22 {
                    gazeTarget = CGPoint(x: .random(in: -0.8...0.8), y: .random(in: -0.5...0.3))
                    gazeHoldUntil = t + .random(in: 0.7...1.4)
                } else {
                    gazeTarget = CGPoint(x: .random(in: -0.08...0.08), y: .random(in: 0.05...0.2))
                }
                nextGazeAt = t + .random(in: 2...5)
            }

            if t > nextMoodAt && flash == nil {
                let pick: [(Expression, Double)] = [(.happy, 1.6), (.curious, 2.2), (.proud, 1.8), (.attentive, 2), (.suspicious, 1.6)]
                let (e, d) = pick.randomElement()!
                react(e, for: d, at: t)
                if e == .happy || e == .proud { nodBob(-9) }
                nextMoodAt = t + .random(in: 28...75)
            }

            if chimeInterval > 0, t - lastChime >= chimeInterval {
                lastChime = t
                react(.proud, for: 3.5, at: t)
                nodBob(-20)
                onChime?()
            }
        }
    }
}

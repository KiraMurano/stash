import CoreGraphics
import Foundation

/// SwiftUI's timing curves evaluated by hand: `UnitCurve` needs macOS 14 and Stash runs on 13.
enum SceneCurve: Sendable {
    case linear
    case easeIn
    case easeOut
    case easeInOut

    func callAsFunction(_ progress: Double) -> Double {
        let x = min(max(progress, 0), 1)
        switch self {
        case .linear: return x
        case .easeIn: return Self.bezier(x, 0.42, 0, 1, 1)
        case .easeOut: return Self.bezier(x, 0, 0, 0.58, 1)
        case .easeInOut: return Self.bezier(x, 0.42, 0, 0.58, 1)
        }
    }

    /// y of the cubic Bézier (0,0)–(x1,y1)–(x2,y2)–(1,1) at x; its parameter is found by bisection.
    private static func bezier(_ x: Double, _ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> Double {
        func coordinate(_ t: Double, _ a: Double, _ b: Double) -> Double {
            let u = 1 - t
            return 3 * u * u * t * a + 3 * u * t * t * b + t * t * t
        }
        var low = 0.0
        var high = 1.0
        for _ in 0..<32 {
            let mid = (low + high) / 2
            if coordinate(mid, x1, x2) < x { low = mid } else { high = mid }
        }
        return coordinate((low + high) / 2, y1, y2)
    }
}

/// Something a scene animates. Continuous values glide; discrete ones (flags, indices) switch.
protocol SceneValue: Sendable {
    static var isDiscrete: Bool { get }
    static func interpolate(_ from: Self, _ to: Self, _ progress: Double) -> Self
}

extension SceneValue {
    static var isDiscrete: Bool { false }
}

extension Double: SceneValue {
    static func interpolate(_ from: Double, _ to: Double, _ progress: Double) -> Double {
        from + (to - from) * progress
    }
}

extension CGFloat: SceneValue {
    static func interpolate(_ from: CGFloat, _ to: CGFloat, _ progress: Double) -> CGFloat {
        from + (to - from) * CGFloat(progress)
    }
}

extension CGPoint: SceneValue {
    static func interpolate(_ from: CGPoint, _ to: CGPoint, _ progress: Double) -> CGPoint {
        CGPoint(x: CGFloat.interpolate(from.x, to.x, progress), y: CGFloat.interpolate(from.y, to.y, progress))
    }
}

extension Bool: SceneValue {
    static var isDiscrete: Bool { true }

    static func interpolate(_ from: Bool, _ to: Bool, _ progress: Double) -> Bool {
        progress >= 1 ? to : from
    }
}

extension Int: SceneValue {
    static var isDiscrete: Bool { true }

    static func interpolate(_ from: Int, _ to: Int, _ progress: Double) -> Int {
        progress >= 1 ? to : from
    }
}

extension String: SceneValue {
    static var isDiscrete: Bool { true }

    static func interpolate(_ from: String, _ to: String, _ progress: Double) -> String {
        progress >= 1 ? to : from
    }
}

extension Optional: SceneValue where Wrapped: SceneValue {
    static var isDiscrete: Bool { true }

    static func interpolate(_ from: Wrapped?, _ to: Wrapped?, _ progress: Double) -> Wrapped? {
        progress >= 1 ? to : from
    }
}

/// Where a scene is: `t` seconds into it, and how far a loop has got back to its first frame.
struct SceneTime: Equatable, Sendable {
    var t: Double
    /// 0 while the scene plays, 0…1 while it returns to its first frame, 1 during the pause.
    var rewind: Double

    /// The stop frame: the scene has played out and holds.
    static func end(of duration: Double) -> SceneTime {
        SceneTime(t: duration, rewind: 0)
    }
}

/// The loop from mrbooker's welcome scenes: play, glide back to the first frame, pause, again.
enum SceneLoop {
    static let returnTime = 0.5
    static let pauseTime = 0.25

    static func time(elapsed: Double, duration: Double, loops: Bool) -> SceneTime {
        let elapsed = max(elapsed, 0)
        guard loops else { return SceneTime(t: min(elapsed, duration), rewind: 0) }
        let cycle = duration + returnTime + pauseTime
        let local = elapsed.truncatingRemainder(dividingBy: cycle)
        if local <= duration { return SceneTime(t: local, rewind: 0) }
        return SceneTime(t: duration, rewind: min((local - duration) / returnTime, 1))
    }
}

/// A value over scene time, built from moves: it holds, glides to a new value between two
/// moments along a curve, and holds again.
struct Track<Value: SceneValue>: Sendable {
    private struct Move: Sendable {
        let start: Double
        let end: Double
        let from: Value
        let to: Value
        let curve: SceneCurve
    }

    let initial: Value
    private let moves: [Move]

    init(_ initial: Value) {
        self.init(initial: initial, moves: [])
    }

    private init(initial: Value, moves: [Move]) {
        self.initial = initial
        self.moves = moves
    }

    /// The value the track ends on.
    var final: Value {
        moves.last?.to ?? initial
    }

    /// Glides to `value` between `start` and `end`. Moves must come in time order.
    func to(_ value: Value, at start: Double, until end: Double, _ curve: SceneCurve = .easeInOut) -> Track {
        precondition(start >= (moves.last?.end ?? 0) && end >= start, "moves must come in time order")
        return Track(initial: initial, moves: moves + [Move(start: start, end: end, from: final, to: value, curve: curve)])
    }

    /// Switches to `value` at `time`.
    func set(_ value: Value, at time: Double) -> Track {
        to(value, at: time, until: time, .linear)
    }

    func value(at t: Double) -> Value {
        var current = initial
        for move in moves {
            if t < move.start { return current }
            if t < move.end {
                return Value.interpolate(move.from, move.to, move.curve((t - move.start) / (move.end - move.start)))
            }
            current = move.to
        }
        return current
    }

    /// While a loop returns to its first frame, continuous values glide back and discrete ones
    /// switch back at once, so the app's own views animate them the way the journal does.
    func value(at time: SceneTime) -> Value {
        guard time.rewind > 0 else { return value(at: time.t) }
        if Value.isDiscrete { return initial }
        return Value.interpolate(final, initial, SceneCurve.easeInOut(time.rewind))
    }
}

/// The arrow in a scene: where its tip is, how visible it is, how squeezed by a click.
struct CursorState: Equatable, Sendable {
    var tip: CGPoint
    var opacity: Double
    /// 0 at rest, 1 fully pressed.
    var press: Double
}

/// The orange wave a click sends out from under the arrow.
struct ClickRipple: Equatable, Sendable {
    var center: CGPoint
    /// 0…1 over `CursorTrack.rippleTime`.
    var progress: Double
}

/// The arrow's path, fade and clicks. On the way back to the first frame it fades where it
/// stands and travels unseen, instead of flying back across the scene.
struct CursorTrack: Sendable {
    static let pressDown = 0.08
    static let pressUp = 0.12
    static let rippleTime = 0.35

    let tip: Track<CGPoint>
    let opacity: Track<Double>
    let clicks: [Double]

    func state(at time: SceneTime) -> CursorState {
        if time.rewind > 0 {
            let fade = min(time.rewind * 2, 1)
            let travel = max(time.rewind * 2 - 1, 0)
            return CursorState(
                tip: CGPoint.interpolate(tip.final, tip.initial, SceneCurve.easeInOut(travel)),
                opacity: opacity.final * (1 - fade),
                press: 0
            )
        }
        return CursorState(tip: tip.value(at: time.t), opacity: opacity.value(at: time.t), press: press(at: time.t))
    }

    func ripple(at time: SceneTime) -> ClickRipple? {
        guard time.rewind == 0 else { return nil }
        for click in clicks where time.t >= click && time.t < click + Self.rippleTime {
            return ClickRipple(center: tip.value(at: click), progress: (time.t - click) / Self.rippleTime)
        }
        return nil
    }

    private func press(at t: Double) -> Double {
        for click in clicks {
            if t >= click, t < click + Self.pressDown {
                return (t - click) / Self.pressDown
            }
            if t >= click + Self.pressDown, t < click + Self.pressDown + Self.pressUp {
                return 1 - (t - click - Self.pressDown) / Self.pressUp
            }
        }
        return 0
    }
}

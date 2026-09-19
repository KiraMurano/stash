import CoreGraphics
import Testing
@testable import BufferJournal

struct SceneEngineTests {
    @Test func curvesStartAndEndInPlace() {
        for curve in [SceneCurve.linear, .easeIn, .easeOut, .easeInOut] {
            #expect(abs(curve(0)) < 0.0001)
            #expect(abs(curve(1) - 1) < 0.0001)
        }
        #expect(abs(SceneCurve.easeInOut(0.5) - 0.5) < 0.001)
        #expect(SceneCurve.easeOut(0.25) > 0.25)
        #expect(SceneCurve.easeIn(0.25) < 0.25)
    }

    @Test func aTrackHoldsGlidesAndHolds() {
        let track = Track(0.0).to(10, at: 1, until: 2, .linear).set(3, at: 3)
        #expect(track.value(at: 0.5) == 0)
        #expect(track.value(at: 1.5) == 5)
        #expect(track.value(at: 2.5) == 10)
        #expect(track.value(at: 3) == 3)
        #expect(track.final == 3)
    }

    @Test func onTheWayBackContinuousValuesGlideAndFlagsSwitch() {
        let offset = Track(0.0).to(10, at: 0, until: 1, .linear)
        let flag = Track(false).set(true, at: 0.5)
        let halfway = SceneTime(t: 1, rewind: 0.5)
        #expect(abs(offset.value(at: halfway) - 5) < 0.0001)
        #expect(flag.value(at: halfway) == false)
        #expect(flag.value(at: SceneTime.end(of: 1)) == true)
    }

    @Test func aLoopPlaysReturnsAndPauses() {
        #expect(SceneLoop.time(elapsed: 1, duration: 2, loops: true) == SceneTime(t: 1, rewind: 0))
        #expect(SceneLoop.time(elapsed: 2.25, duration: 2, loops: true) == SceneTime(t: 2, rewind: 0.5))
        #expect(SceneLoop.time(elapsed: 2.6, duration: 2, loops: true) == SceneTime(t: 2, rewind: 1))
        // A cycle is 2 + 0.5 + 0.25 s; then it starts over.
        #expect(abs(SceneLoop.time(elapsed: 3.0, duration: 2, loops: true).t - 0.25) < 0.0001)
    }

    @Test func aSceneThatPlaysOnceStaysAtItsEnd() {
        #expect(SceneLoop.time(elapsed: 9, duration: 2, loops: false) == SceneTime.end(of: 2))
    }

    @Test func aClickSqueezesTheArrowAndSendsAWave() {
        let tip = Track(CGPoint(x: 0, y: 0)).to(CGPoint(x: 100, y: 50), at: 0, until: 1)
        let cursor = CursorTrack(tip: tip, opacity: Track(1.0), clicks: [1.5])
        #expect(cursor.state(at: SceneTime(t: 1.4, rewind: 0)).press == 0)
        #expect(abs(cursor.state(at: SceneTime(t: 1.58, rewind: 0)).press - 1) < 0.001)
        #expect(cursor.state(at: SceneTime(t: 1.8, rewind: 0)).press == 0)
        #expect(cursor.ripple(at: SceneTime(t: 1.6, rewind: 0))?.center == CGPoint(x: 100, y: 50))
        #expect(cursor.ripple(at: SceneTime(t: 2, rewind: 0)) == nil)
    }

    @Test func theArrowFadesInPlaceBeforeGoingBack() {
        let tip = Track(CGPoint(x: 0, y: 0)).to(CGPoint(x: 100, y: 0), at: 0, until: 1)
        let cursor = CursorTrack(tip: tip, opacity: Track(1.0), clicks: [])
        let fading = cursor.state(at: SceneTime(t: 1, rewind: 0.25))
        #expect(fading.tip == CGPoint(x: 100, y: 0))
        #expect(abs(fading.opacity - 0.5) < 0.0001)
        let travelling = cursor.state(at: SceneTime(t: 1, rewind: 0.75))
        #expect(travelling.opacity == 0)
        #expect(abs(travelling.tip.x - 50) < 0.0001)
    }
}

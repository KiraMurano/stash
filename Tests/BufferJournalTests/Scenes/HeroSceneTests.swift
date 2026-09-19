import CoreGraphics
import Testing
@testable import BufferJournal

/// The stop frame from the spec's "Сцены" section and the moments that lead to it.
@MainActor
struct HeroSceneTests {
    @Test func heroEndsAssembledAndStill() {
        let end = HeroScene.state(at: .end(of: HeroScene.duration))
        #expect(end.iconOpacity == 1)
        #expect(end.iconScaleX == 1 && end.iconScaleY == 1)
        #expect(end.flash == 0 && end.shake == 0)
        #expect(end.wordOpacity == 1)
        #expect(end.wordShift == 0)
        #expect(end.tiles.allSatisfy { $0 == nil })
    }

    @Test func tilesFlyThenHitTheIcon() {
        let flying = HeroScene.state(at: SceneTime(t: 0.55, rewind: 0))
        #expect(flying.tiles[0] != nil)
        #expect(flying.wordOpacity == 0)
        // Just after the first hit the icon is squashed: wider and lower.
        let hit = HeroScene.state(at: SceneTime(t: HeroScene.hits[0] + 0.06, rewind: 0))
        #expect(hit.iconScaleX > 1 && hit.iconScaleY < 1)
        // The last hit shakes the lockup.
        let last = HeroScene.state(at: SceneTime(t: HeroScene.hits[2] + 0.1, rewind: 0))
        #expect(last.shake != 0)
        #expect(HeroScene.state(at: SceneTime(t: HeroScene.hits[0] + 0.02, rewind: 0)).flash > 0)
    }

    @Test func eachFlightEndsInTheIcon() {
        let icon = CGPoint(x: 200, y: 150)
        for flight in HeroScene.flights(in: CGSize(width: 600, height: 300), to: icon) {
            #expect(flight.point(at: 1) == icon)
        }
    }
}

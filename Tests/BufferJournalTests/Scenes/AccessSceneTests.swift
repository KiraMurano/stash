import CoreGraphics
import Testing
@testable import BufferJournal

/// The stop frame from the spec's "Сцены" section and the moments that lead to it.
@MainActor
struct AccessSceneTests {
    @Test func accessEndsSwitchedOn() {
        #expect(AccessScene.state(at: .end(of: AccessScene.duration)).isOn)
        #expect(!AccessScene.state(at: SceneTime(t: 1, rewind: 0)).isOn)
    }

    @Test func theArrowClicksTheSwitchInTheSettingsWindow() {
        let ripple = AccessScene.state(at: SceneTime(t: AccessScene.click + 0.01, rewind: 0)).ripple
        #expect(ripple?.center == AccessScene.toggle)
        // The switch belongs to the Stash row in the right-hand pane, not to the sidebar.
        #expect(AccessScene.window.contains(AccessScene.toggle))
        #expect(AccessScene.toggle.x > AccessScene.window.minX + AccessScene.sidebarWidth)
    }

    @Test func theWindowFillsItsCanvas() {
        // No card around the screen and no button inside it, so the window takes the whole canvas
        // bar the margin its shadow needs.
        let margin = AccessScene.size.height - AccessScene.window.maxY
        #expect(margin == AccessScene.window.minY)
        #expect(margin <= 12)
        #expect(AccessScene.size.width - AccessScene.window.maxX == AccessScene.window.minX)
    }
}

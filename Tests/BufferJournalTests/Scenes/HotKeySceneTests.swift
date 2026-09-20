import CoreGraphics
import Testing
@testable import BufferJournal

/// The stop frame from the spec's "Сцены" section and the moments that lead to it.
@MainActor
struct HotKeySceneTests {
    @Test func hotKeyEndsWithTheJournalOpenAndKeysUp() {
        let end = HotKeyScene.state(at: .end(of: HotKeyScene.duration))
        #expect(end.journal == 1)
        #expect(!end.optionDown && !end.vDown)
        let pressed = HotKeyScene.state(at: SceneTime(t: 0.55, rewind: 0))
        #expect(pressed.optionDown && pressed.vDown)
    }

    @Test func theJournalOpensOverTheWindow() {
        // The slide only says the keys open the journal, so it sits in the middle of the window
        // in front rather than repeating the app's caret placement.
        #expect(HotKeyScene.journalFrame.midX == HotKeyScene.window.midX)
        #expect(HotKeyScene.journalFrame.midY == HotKeyScene.window.midY)
        #expect(HotKeyScene.journalFrame.minX >= HotKeyScene.window.minX)
        #expect(HotKeyScene.journalFrame.maxY <= HotKeyScene.window.maxY)
    }
}

import CoreGraphics
import Testing
@testable import BufferJournal

/// The stop frame from the spec's "Сцены" section and the moments that lead to it.
@MainActor
struct HotKeySceneTests {
    @Test func hotKeyEndsWithTheJournalUnderTheCaretAndKeysUp() {
        let end = HotKeyScene.state(at: .end(of: HotKeyScene.duration))
        #expect(end.journal == 1)
        #expect(!end.optionDown && !end.vDown)
        let pressed = HotKeyScene.state(at: SceneTime(t: 0.55, rewind: 0))
        #expect(pressed.optionDown && pressed.vDown)
    }

    @Test func theJournalOpensUnderTheCaretWithTheAppsOwnGap() {
        // The scene places the journal the way PanelPlacement does on screen: left edge at the
        // caret, top edge a gap below the line it stands on.
        #expect(HotKeyScene.journalFrame.minX == HotKeyScene.caret.minX)
        #expect(HotKeyScene.journalFrame.minY == HotKeyScene.caret.maxY + PanelPlacement.gap)
        #expect(HotKeyScene.journalFrame.maxX <= HotKeyScene.size.width)
        #expect(HotKeyScene.journalFrame.maxY <= HotKeyScene.size.height)
    }
}

import CoreGraphics
import Testing
@testable import BufferJournal

/// The stop frame from the spec's "Сцены" section and the moments that lead to it.
@MainActor
struct PasteSceneTests {
    @Test func pasteEndsWithTheClipInTheLetterAndTheJournalGone() {
        let end = PasteScene.state(at: .end(of: PasteScene.duration))
        #expect(end.selectedRow == 1)
        #expect(end.hoveredRow == 1)
        #expect(end.pasted == 1)
        // Close After Selection is on by default: the journal dissolves after the click.
        #expect(end.journal == 0)
        #expect(end.cursor.tip == PasteScene.returnButton)
        #expect(end.cursor.opacity == 1)
        let beforeClick = PasteScene.state(at: SceneTime(t: 1.4, rewind: 0))
        #expect(beforeClick.selectedRow == nil)
        #expect(beforeClick.journal == 1)
        #expect(beforeClick.pasted == 0)
    }
}

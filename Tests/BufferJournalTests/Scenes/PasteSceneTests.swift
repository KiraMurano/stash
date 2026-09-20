import CoreGraphics
import Testing
@testable import BufferJournal

/// The stop frame from the spec's "Сцены" section and the moments that lead to it.
@MainActor
struct PasteSceneTests {
    @Test func pasteEndsWithAllThreeClipsInTheLetterAndTheJournalGone() {
        let end = PasteScene.state(at: .end(of: PasteScene.duration))
        #expect(end.pastedText == 1)
        #expect(end.pastedImage == 1)
        #expect(end.pastedFile == 1)
        #expect(end.journal == 0)
        #expect(end.selectedRow == PasteScene.fileRow)
        #expect(!end.returnPressed)
    }

    @Test func theTextClipGoesInByItsOrangeButton() {
        let hovering = PasteScene.state(at: SceneTime(t: 1.0, rewind: 0))
        #expect(hovering.hoveredRow == PasteScene.textRow)
        #expect(hovering.selectedRow == nil)
        #expect(hovering.pastedText == 0)

        let ripple = PasteScene.state(at: SceneTime(t: PasteScene.buttonClick + 0.01, rewind: 0)).ripple
        #expect(ripple?.center == PasteScene.returnButton(of: PasteScene.textRow))

        let after = PasteScene.state(at: SceneTime(t: 1.9, rewind: 0))
        #expect(after.selectedRow == PasteScene.textRow)
        #expect(after.pastedText == 1)
        // The other two are still to come, and the journal has not gone anywhere.
        #expect(after.pastedImage == 0 && after.pastedFile == 0)
        #expect(after.journal == 1)
    }

    @Test func theImageGoesInOnADoubleClick() {
        // Two clicks in a row, close enough to read as one double-click.
        #expect(PasteScene.doubleClick.count == 2)
        #expect(PasteScene.doubleClick[1] - PasteScene.doubleClick[0] <= 0.25)
        for click in PasteScene.doubleClick {
            let ripple = PasteScene.state(at: SceneTime(t: click + 0.01, rewind: 0)).ripple
            #expect(ripple.map { abs($0.center.y - PasteScene.returnButton(of: PasteScene.imageRow).y) < 1 } == true)
        }

        let after = PasteScene.state(at: SceneTime(t: 3.3, rewind: 0))
        #expect(after.selectedRow == PasteScene.imageRow)
        #expect(after.pastedImage == 1)
        #expect(after.pastedFile == 0)
    }

    @Test func theFileIsSelectedByAClickAndPastedByReturn() {
        // The click only selects it: nothing lands until ⏎ goes down.
        let selected = PasteScene.state(at: SceneTime(t: PasteScene.returnPress - 0.1, rewind: 0))
        #expect(selected.selectedRow == PasteScene.fileRow)
        #expect(selected.pastedFile == 0)
        #expect(!selected.returnPressed)

        #expect(PasteScene.state(at: SceneTime(t: PasteScene.returnPress + 0.05, rewind: 0)).returnPressed)
        #expect(PasteScene.state(at: SceneTime(t: PasteScene.returnPress + 0.5, rewind: 0)).pastedFile == 1)
    }

    @Test func theJournalLeavesOnlyAfterTheLastPaste() {
        // Close After Selection is on, but the scene shows all three ways first.
        let beforeLast = PasteScene.state(at: SceneTime(t: PasteScene.returnPress, rewind: 0))
        #expect(beforeLast.journal == 1)
        #expect(PasteScene.state(at: SceneTime(t: 5.2, rewind: 0)).journal < 1)
    }
}

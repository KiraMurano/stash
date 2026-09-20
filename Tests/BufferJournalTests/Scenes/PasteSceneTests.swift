import CoreGraphics
import Testing
@testable import BufferJournal

/// The stop frame from the spec's "Сцены" section and the moments that lead to it.
@MainActor
struct PasteSceneTests {
    @Test func pasteEndsWithBothClipsInTheLetterAndTheJournalGone() {
        let end = PasteScene.state(at: .end(of: PasteScene.duration))
        #expect(end.pastedText == 1)
        #expect(end.pastedImage == 1)
        #expect(end.journal == 0)
        #expect(end.selectedRow == PasteScene.imageRow)
    }

    @Test func theTextClipGoesInByItsOrangeButton() {
        let hovering = PasteScene.state(at: SceneTime(t: 1.0, rewind: 0))
        #expect(hovering.hoveredRow == PasteScene.textRow)
        #expect(hovering.selectedRow == nil)
        #expect(hovering.pastedText == 0)

        let ripple = PasteScene.state(at: SceneTime(t: PasteScene.buttonClick + 0.01, rewind: 0)).ripple
        #expect(ripple?.center == PasteScene.pasteButton(of: PasteScene.textRow))

        let after = PasteScene.state(at: SceneTime(t: 1.9, rewind: 0))
        #expect(after.selectedRow == PasteScene.textRow)
        #expect(after.pastedText == 1)
        // The image is still to come, and the journal has not gone anywhere.
        #expect(after.pastedImage == 0)
        #expect(after.journal == 1)
    }

    /// The paste button is the leftmost of the row's three, as in the journal.
    @Test func thePasteButtonIsTheLeftmostOfTheRowsButtons() {
        let paste = PasteScene.pasteButton(of: PasteScene.textRow)
        // Two more buttons of 26 pt, 4 pt apart, fit between it and the row's trailing edge at 252.
        let trailingEdge: CGFloat = paste.x + 13 + 2 * (26 + 4)
        #expect(abs(trailingEdge - 252) < 0.001)
        #expect(paste.y == PasteScene.rowCenterY(PasteScene.textRow))
    }

    @Test func theImageGoesInOnADoubleClick() {
        // Two clicks in a row, close enough to read as one double-click.
        #expect(PasteScene.doubleClick.count == 2)
        #expect(PasteScene.doubleClick[1] - PasteScene.doubleClick[0] <= 0.25)
        for click in PasteScene.doubleClick {
            let ripple = PasteScene.state(at: SceneTime(t: click + 0.01, rewind: 0)).ripple
            // On the row itself, not on a button.
            #expect(ripple.map { abs($0.center.y - PasteScene.pasteButton(of: PasteScene.imageRow).y) < 1 } == true)
            #expect(ripple.map { $0.center.x < PasteScene.pasteButton(of: PasteScene.imageRow).x } == true)
        }

        let after = PasteScene.state(at: SceneTime(t: 3.3, rewind: 0))
        #expect(after.selectedRow == PasteScene.imageRow)
        #expect(after.pastedImage == 1)
    }

    @Test func theJournalLeavesOnlyAfterTheSecondPaste() {
        // Close After Selection is on, but the scene shows both mouse ways first.
        #expect(PasteScene.state(at: SceneTime(t: 3.3, rewind: 0)).journal == 1)
        #expect(PasteScene.state(at: SceneTime(t: 3.6, rewind: 0)).journal < 1)
    }
}

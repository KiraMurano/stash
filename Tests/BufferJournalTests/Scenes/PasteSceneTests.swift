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

    /// The row turns orange the moment the first click lands, so both waves of a double click
    /// play over orange and the scene draws them white.
    @Test func aClickSelectsItsRowRightAway() {
        for (clicks, row) in [(PasteScene.textDoubleClick, PasteScene.textRow), (PasteScene.imageDoubleClick, PasteScene.imageRow)] {
            #expect(PasteScene.state(at: SceneTime(t: clicks[0] + 0.1, rewind: 0)).selectedRow == row)
        }
    }

    @Test func bothClipsGoInOnADoubleClick() {
        for clicks in [PasteScene.textDoubleClick, PasteScene.imageDoubleClick] {
            // Two clicks in a row, close enough to read as one double-click.
            #expect(clicks.count == 2)
            #expect(clicks[1] - clicks[0] <= 0.25)
        }

        let hovering = PasteScene.state(at: SceneTime(t: 0.9, rewind: 0))
        #expect(hovering.hoveredRow == PasteScene.textRow)
        #expect(hovering.selectedRow == nil)
        #expect(hovering.pastedText == 0)

        // The clicks land on the rows themselves, not on a button at their trailing edge.
        for click in PasteScene.textDoubleClick {
            let ripple = PasteScene.state(at: SceneTime(t: click + 0.01, rewind: 0)).ripple
            #expect(ripple.map { abs($0.center.y - PasteScene.rowCenterY(PasteScene.textRow)) < 1 } == true)
            #expect(ripple.map { $0.center.x < 200 } == true)
        }

        let afterText = PasteScene.state(at: SceneTime(t: 1.85, rewind: 0))
        #expect(afterText.selectedRow == PasteScene.textRow)
        #expect(afterText.pastedText == 1)
        // The image is still to come, and the journal has not gone anywhere.
        #expect(afterText.pastedImage == 0)
        #expect(afterText.journal == 1)

        for click in PasteScene.imageDoubleClick {
            let ripple = PasteScene.state(at: SceneTime(t: click + 0.01, rewind: 0)).ripple
            #expect(ripple.map { abs($0.center.y - PasteScene.rowCenterY(PasteScene.imageRow)) < 1 } == true)
        }

        let afterImage = PasteScene.state(at: SceneTime(t: 3.2, rewind: 0))
        #expect(afterImage.selectedRow == PasteScene.imageRow)
        #expect(afterImage.pastedImage == 1)
    }

    @Test func theJournalLeavesOnlyAfterTheSecondPaste() {
        // Close After Selection is on, but the scene shows both clips first.
        #expect(PasteScene.state(at: SceneTime(t: 3.4, rewind: 0)).journal == 1)
        #expect(PasteScene.state(at: SceneTime(t: 3.6, rewind: 0)).journal < 1)
    }
}

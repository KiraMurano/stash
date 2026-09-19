import AppKit
import Testing
@testable import BufferJournal

struct PanelPlacementTests {
    /// A 1512 × 900 screen with the menu bar, as on a laptop.
    private let screen = NSRect(x: 0, y: 0, width: 1512, height: 862)
    private let panel = NSSize(width: 644, height: 444)

    @Test func sitsUnderTheCaretWhenThereIsRoom() {
        let caret = CGRect(x: 300, y: 700, width: 1, height: 16)
        let origin = PanelPlacement.origin(anchor: caret, panelSize: panel, visibleFrame: screen)
        // Top of the panel is a gap below the caret, left edge follows it.
        #expect(origin == NSPoint(x: 300, y: caret.minY - PanelPlacement.gap - panel.height))
    }

    @Test func movesAboveTheCaretWithoutRoomBelow() {
        let caret = CGRect(x: 300, y: 200, width: 1, height: 16)
        let origin = PanelPlacement.origin(anchor: caret, panelSize: panel, visibleFrame: screen)
        #expect(origin == NSPoint(x: 300, y: caret.maxY + PanelPlacement.gap))
    }

    @Test func aTransparentBottomEdgeKeepsTheGapEven() throws {
        let caret = CGRect(x: 300, y: 200, width: 1, height: 16)
        // The panel carries a 4 pt transparent strip under it, so it sits 4 pt lower and the
        // visible gap above the caret matches the one below it.
        let origin = try #require(
            PanelPlacement.origin(anchor: caret, panelSize: panel, visibleFrame: screen, bottomInset: 4)
        )
        #expect(origin.y == caret.maxY + PanelPlacement.gap - 4)
    }

    @Test func givesUpWhenItFitsNeitherWay() {
        let caret = CGRect(x: 300, y: 430, width: 1, height: 16)
        #expect(PanelPlacement.origin(anchor: caret, panelSize: panel, visibleFrame: screen) == nil)
    }

    @Test func staysOnScreenNearTheEdges() throws {
        let atRight = try #require(
            PanelPlacement.origin(anchor: CGRect(x: 1500, y: 700, width: 1, height: 16), panelSize: panel, visibleFrame: screen)
        )
        #expect(atRight.x == screen.maxX - panel.width - PanelPlacement.margin)

        let offLeft = try #require(
            PanelPlacement.origin(anchor: CGRect(x: -40, y: 700, width: 1, height: 16), panelSize: panel, visibleFrame: screen)
        )
        #expect(offLeft.x == PanelPlacement.margin)
    }

    @Test func countsTheDockOut() throws {
        let caret = CGRect(x: 100, y: 520, width: 1, height: 16)

        // Without the Dock the panel just fits below the caret.
        let onFullScreen = try #require(PanelPlacement.origin(anchor: caret, panelSize: panel, visibleFrame: screen))
        #expect(onFullScreen.y == caret.minY - PanelPlacement.gap - panel.height)

        // The Dock takes the bottom 80 pt, and now the panel fits neither way: the caller falls
        // back to the panel's saved place.
        let withDock = NSRect(x: 0, y: 80, width: 1512, height: 782)
        #expect(PanelPlacement.origin(anchor: caret, panelSize: panel, visibleFrame: withDock) == nil)
    }
}

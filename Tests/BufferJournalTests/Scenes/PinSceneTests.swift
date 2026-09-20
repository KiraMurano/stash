import CoreGraphics
import Testing
@testable import BufferJournal

/// The stop frame from the spec's "Сцены" section and the moments that lead to it.
@MainActor
struct PinSceneTests {
    @Test func pinEndsWithTheAddressPinnedAndTwoNewClips() {
        let end = PinScene.state(at: .end(of: PinScene.duration))
        #expect(end.isPinned)
        #expect(end.hovered == nil)
        #expect(PinScene.layout(end) == ["header-pinned", "pin-address", "header-today", "pin-order", "pin-promo"])
        let start = PinScene.state(at: SceneTime(t: 0, rewind: 0))
        #expect(PinScene.layout(start) == ["header-today", "pin-link", "pin-address", "pin-photo"])
    }

    /// The pin is the first of the row's two buttons, so the arrow has to reach that far and
    /// no further — the row's trailing edge is at 252.
    @Test func theArrowClicksThePinButtonOfTheAddressRow() {
        let ripple = PinScene.state(at: SceneTime(t: PinScene.click + 0.01, rewind: 0)).ripple
        #expect(ripple?.center == PinScene.pinButton)
        let trailingEdge: CGFloat = PinScene.pinButton.x + 13 + (26 + 4)
        #expect(abs(trailingEdge - 252) < 0.001)
    }
}

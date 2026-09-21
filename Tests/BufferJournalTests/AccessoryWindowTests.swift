import AppKit
import SwiftUI
import Testing
@testable import BufferJournal

@MainActor
struct AccessoryWindowTests {
    /// Потолок — вся полезная высота экрана без зазора сверху и поля снизу.
    @Test func theCapIsTheScreenLessTheGapAndTheMargin() {
        let screen = NSRect(x: 0, y: 0, width: 1440, height: 876)
        let cap = AccessoryWindow<EmptyView>.heightCap(visibleFrame: screen)

        #expect(cap == 876 - StatusItemAnchor.topGap - StatusItemAnchor.bottomMargin)
    }

    /// На крошечном экране потолок не уходит в ноль и не становится отрицательным.
    @Test func theCapNeverFallsBelowAFloor() {
        let tiny = NSRect(x: 0, y: 0, width: 800, height: 40)
        #expect(AccessoryWindow<EmptyView>.heightCap(visibleFrame: tiny) == 120)
    }
}

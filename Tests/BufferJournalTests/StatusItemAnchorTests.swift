import AppKit
import Testing
@testable import BufferJournal

struct StatusItemAnchorTests {
    /// Экран 1440 × 900 с 24-точечной строкой меню сверху.
    private let screen = NSRect(x: 0, y: 0, width: 1440, height: 876)
    private let size = NSSize(width: 400, height: 300)

    @Test func theWindowHangsFromTheRightEdgeOfTheIcon() {
        let item = NSRect(x: 1000, y: 876, width: 24, height: 24)
        let origin = StatusItemAnchor.origin(itemFrame: item, windowSize: size, visibleFrame: screen)

        #expect(origin.x + size.width == item.maxX + StatusItemAnchor.rightInset)
    }

    @Test func theTopEdgeSitsUnderTheMenuBar() {
        let item = NSRect(x: 1000, y: 876, width: 24, height: 24)
        let origin = StatusItemAnchor.origin(itemFrame: item, windowSize: size, visibleFrame: screen)

        #expect(origin.y + size.height == screen.maxY - StatusItemAnchor.topGap)
    }

    /// Значок у самого правого края: окно не вылезает за экран.
    @Test func theWindowStopsAtTheRightEdgeOfTheScreen() {
        let item = NSRect(x: 1430, y: 876, width: 10, height: 24)
        let origin = StatusItemAnchor.origin(itemFrame: item, windowSize: size, visibleFrame: screen)

        #expect(origin.x + size.width == screen.maxX - StatusItemAnchor.screenMargin)
    }

    /// Окно шире экрана прижимается к левому краю, а не уезжает за него.
    @Test func theWindowStopsAtTheLeftEdgeOfTheScreen() {
        let item = NSRect(x: 100, y: 876, width: 24, height: 24)
        let wide = NSSize(width: 1600, height: 300)
        let origin = StatusItemAnchor.origin(itemFrame: item, windowSize: wide, visibleFrame: screen)

        #expect(origin.x == screen.minX + StatusItemAnchor.screenMargin)
    }

    /// Второй экран слева от главного: координаты отрицательные, привязка та же.
    @Test func itWorksOnAScreenWithNegativeCoordinates() {
        let left = NSRect(x: -1680, y: 0, width: 1680, height: 1050)
        let item = NSRect(x: -400, y: 1050, width: 24, height: 24)
        let origin = StatusItemAnchor.origin(itemFrame: item, windowSize: size, visibleFrame: left)

        #expect(origin.x + size.width == item.maxX + StatusItemAnchor.rightInset)
        #expect(origin.y + size.height == left.maxY - StatusItemAnchor.topGap)
    }
}

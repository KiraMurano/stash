import AppKit
import Testing
@testable import BufferJournal

@MainActor
struct StatusItemBadgeTests {
    private let bounds = CGRect(x: 0, y: 0, width: 26, height: 22)
    private let glyph = CGSize(width: 14, height: 18)

    @Test func theGlyphSitsInTheMiddleOfTheButton() {
        let rect = StatusItemBadge.glyphRect(in: bounds, imageSize: glyph)
        #expect(rect == CGRect(x: 6, y: 2, width: 14, height: 18))
    }

    @Test func theDotHangsOnTheTopRightCorner() {
        // Концепт, раунд 2, вариант 2.1.2: перекрытие 3×3, за правым краем 2.
        let rect = StatusItemBadge.dotRect(glyph: StatusItemBadge.glyphRect(in: bounds, imageSize: glyph))
        #expect(rect.width == 5 && rect.height == 5)
        #expect(rect.maxX == 22)   // 20 — правый край значка, плюс 2 наружу
        #expect(rect.maxY == 22)   // 20 — верх значка, плюс 2 наружу
    }

    @Test func theOverlapIsThreeByThree() {
        let glyphRect = StatusItemBadge.glyphRect(in: bounds, imageSize: glyph)
        let dot = StatusItemBadge.dotRect(glyph: glyphRect)
        #expect(dot.intersection(glyphRect).size == CGSize(width: 3, height: 3))
    }

    @Test func aWiderButtonKeepsTheDotOnTheGlyph() {
        let wide = CGRect(x: 0, y: 0, width: 40, height: 22)
        let glyphRect = StatusItemBadge.glyphRect(in: wide, imageSize: glyph)
        let dot = StatusItemBadge.dotRect(glyph: glyphRect)
        #expect(dot.intersection(glyphRect).size == CGSize(width: 3, height: 3))
        #expect(dot.maxX == glyphRect.maxX + 2)
    }

    @Test func theDotIsHiddenUntilItIsAskedFor() throws {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        defer { NSStatusBar.system.removeStatusItem(item) }
        let button = try #require(item.button)

        let badge = StatusItemBadge(button: button)
        #expect(!badge.isVisible)
        badge.isVisible = true
        #expect(badge.isVisible)
    }
}

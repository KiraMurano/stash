import AppKit
import Testing
@testable import BufferJournal

struct WordmarkFontTests {
    @Test func aSetAsksTheFontForItsOpenTypeFeature() {
        let features = WordmarkFont.featureSettings(set: 3)
        let tag = features.first?[NSFontDescriptor.FeatureKey(rawValue: kCTFontOpenTypeFeatureTag as String)] as? String

        #expect(features.count == 1)
        #expect(tag == "ss03")
    }

    @Test func theFontsOwnFormAsksForNothing() {
        #expect(WordmarkFont.featureSettings(set: 0).isEmpty)
    }

    /// Without the bundle there is no font, and the screen must still draw the line.
    @Test func everyLetterIsMeasuredInEverySet() {
        let letters = WordmarkStoryboard.letters
        let widths = WordmarkFont.widths(of: letters, size: 56)

        #expect(widths.count == letters.count)
        #expect(widths.allSatisfy { $0.count == 7 })
        #expect(widths.allSatisfy { $0.allSatisfy { $0 > 0 } })
    }
}

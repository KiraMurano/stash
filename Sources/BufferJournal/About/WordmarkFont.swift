import AppKit

/// Booker Display, one stylistic set at a time.
///
/// SwiftUI has no way to ask for an OpenType feature, so the set is put on an `NSFont` through a
/// descriptor. A descriptor's features cover a whole run of text — that is why the wordmark is
/// drawn letter by letter, each `Text` with a font of its own.
enum WordmarkFont {
    /// The font's PostScript name. It is registered by `ATSApplicationFontsPath` in Info.plist,
    /// so a build run straight from SwiftPM — without a bundle — does not have it.
    static let name = "BookerDisplay-Regular"

    private static let tagKey = NSFontDescriptor.FeatureKey(rawValue: kCTFontOpenTypeFeatureTag as String)
    private static let valueKey = NSFontDescriptor.FeatureKey(rawValue: kCTFontOpenTypeFeatureValue as String)

    static var isAvailable: Bool {
        NSFont(name: name, size: 12) != nil
    }

    /// Set 0 is the font's own form and asks for no feature at all.
    static func featureSettings(set: Int) -> [[NSFontDescriptor.FeatureKey: Any]] {
        guard set > 0 else { return [] }
        return [[tagKey: String(format: "ss%02d", set), valueKey: 1]]
    }

    static func font(size: CGFloat, set: Int) -> NSFont? {
        guard let base = NSFont(name: name, size: size) else { return nil }
        let settings = featureSettings(set: set)
        guard !settings.isEmpty else { return base }

        let descriptor = base.fontDescriptor.addingAttributes([.featureSettings: settings])
        return NSFont(descriptor: descriptor, size: size)
    }

    /// The width of every letter in every set, measured once. The storyboard adds these up
    /// instead of laying the line out again on every frame.
    static func widths(of letters: [WordmarkLetter], size: CGFloat) -> [[Double]] {
        letters.map { letter in
            (0...6).map { set in
                let font = font(size: size, set: letter.hasAlternates ? set : 0)
                    ?? .systemFont(ofSize: size, weight: .semibold)
                let text = NSAttributedString(string: String(letter.character), attributes: [.font: font])
                return Double(text.size().width)
            }
        }
    }
}

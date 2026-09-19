import CoreGraphics
import Testing
@testable import BufferJournal

@MainActor
struct DemoClipsTests {
    @Test func aDemoClipKeepsItsIdentityFromFrameToFrame() {
        let l10n = L10n(language: .russian)
        let first = DemoClips.text("same", Localized(en: "a", ru: "а"), l10n, at: 9, 0)
        let second = DemoClips.text("same", Localized(en: "a", ru: "а"), l10n, at: 9, 0)
        #expect(first.entry.id == second.entry.id)
    }

    @Test func demoImagesAreLabelledLikeTheJournal() {
        let l10n = L10n(language: .russian)
        let clip = DemoClips.image("photo", .mountains, pixelSize: CGSize(width: 1600, height: 1000), at: 14, 2)
        #expect(ClipLabels.rowTitle(clip.entry, l10n) == "Изображение")
        #expect(ClipLabels.rowSubtitle(clip.entry, pixelSize: clip.pixelSize, l10n).hasPrefix("1600×1000 · "))
        #expect(clip.thumbnail != nil)
    }
}

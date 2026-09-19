import CoreGraphics
import Foundation
import Testing
@testable import BufferJournal

struct ClipLabelsTests {
    private let ru = L10n(language: .russian)
    private let en = L10n(language: .english)
    private let now = Calendar.current.date(bySettingHour: 15, minute: 0, second: 0, of: Date())!

    private func entry(_ payload: ClipboardPayload, minutesAgo: Double = 30) -> ClipboardEntry {
        ClipboardEntry(
            id: UUID(),
            payload: payload,
            createdAt: now.addingTimeInterval(-minutesAgo * 60),
            fingerprint: "test"
        )
    }

    @Test func imageRowIsTitledByKindAndSubtitledBySizeAndTime() {
        let image = entry(.image(filename: "x.png"))
        let time = DateFormatter.entryTime.string(from: image.createdAt)
        #expect(ClipLabels.rowTitle(image, ru) == "Изображение")
        #expect(ClipLabels.rowSubtitle(image, pixelSize: CGSize(width: 1600, height: 1000), ru, now: now) == "1600×1000 · \(time)")
    }

    @Test func textRowCollapsesWhitespaceAndShowsOnlyTime() {
        let text = entry(.text("  Счёт\n\nза   сентябрь "))
        #expect(ClipLabels.rowTitle(text, ru) == "Счёт за сентябрь")
        #expect(ClipLabels.rowSubtitle(text, pixelSize: nil, ru, now: now) == DateFormatter.entryTime.string(from: text.createdAt))
    }

    @Test func fileRowShowsNameThenSizeAndTime() {
        let file = entry(.file(storedFilename: "a", originalName: "Договор.pdf", byteCount: 1_200_000))
        let time = DateFormatter.entryTime.string(from: file.createdAt)
        #expect(ClipLabels.rowTitle(file, ru) == "Договор.pdf")
        #expect(ClipLabels.rowSubtitle(file, pixelSize: nil, ru, now: now) == "\(file.subtitle(ru)) · \(time)")
    }

    @Test func yesterdayIsSpelledOut() {
        let old = entry(.text("x"), minutesAgo: 24 * 60)
        #expect(ClipLabels.timeTitle(old.createdAt, en, now: now).hasPrefix("yesterday, "))
    }
}

import CoreGraphics
import Foundation

/// How journal rows are titled. The journal and the tutorial scenes both use it, so a scene's
/// rows read exactly like the real ones.
enum ClipLabels {
    static func kindTitle(_ entry: ClipboardEntry, _ l10n: L10n) -> String {
        switch entry.payload {
        case .text: return l10n("Text", "Текст")
        case .image: return l10n("Image", "Изображение")
        case .file: return l10n("File", "Файл")
        }
    }

    static func rowTitle(_ entry: ClipboardEntry, _ l10n: L10n) -> String {
        switch entry.payload {
        case let .text(text):
            // Collapse whitespace so two lines show real content, not blank lines.
            let collapsed = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            return collapsed.isEmpty ? l10n("Empty text", "Пустой текст") : collapsed
        case .image:
            return kindTitle(entry, l10n)
        case .file:
            return entry.title(l10n)
        }
    }

    /// `pixelSize` comes from the store for real clips and from the scene for demo ones.
    static func rowSubtitle(_ entry: ClipboardEntry, pixelSize: CGSize?, _ l10n: L10n, now: Date = Date()) -> String {
        let time = timeTitle(entry.createdAt, l10n, now: now)
        switch entry.payload {
        case .text:
            return time
        case .image:
            return [pixelSize.map(pixelSizeTitle), time].compactMap { $0 }.joined(separator: " · ")
        case .file:
            return "\(entry.subtitle(l10n)) · \(time)"
        }
    }

    static func pixelSizeTitle(_ size: CGSize) -> String {
        "\(Int(size.width))×\(Int(size.height))"
    }

    /// `now` is today for the journal; tests pass their own so the day boundary is not the clock's.
    static func timeTitle(_ date: Date, _ l10n: L10n, now: Date = Date()) -> String {
        let calendar = Calendar.current
        if calendar.isDate(date, inSameDayAs: now) {
            return DateFormatter.entryTime.string(from: date)
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) {
            return l10n("yesterday", "вчера") + ", " + DateFormatter.entryTime.string(from: date)
        }
        let locale = Locale(identifier: l10n.language == .russian ? "ru_RU" : "en_US")
        return date.formatted(.dateTime.day().month(.abbreviated).locale(locale))
    }
}

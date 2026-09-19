import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// A made-up clip for the scenes: an entry plus what the store would give for it.
struct DemoClip: Identifiable {
    let id: String
    var entry: ClipboardEntry
    var thumbnail: NSImage?
    var fileIcon: NSImage?
    var pixelSize: CGSize?

    func pinned(_ isPinned: Bool = true) -> DemoClip {
        var copy = self
        copy.entry.isPinned = isPinned
        return copy
    }
}

/// Builds demo clips. They never reach the history or the disk.
@MainActor
enum DemoClips {
    static func text(_ id: String, _ text: Localized, _ l10n: L10n, at hour: Int, _ minute: Int) -> DemoClip {
        DemoClip(id: id, entry: entry(id, .text(text(l10n)), hour, minute))
    }

    static func image(_ id: String, _ style: PhotoArt.Style, pixelSize: CGSize, at hour: Int, _ minute: Int) -> DemoClip {
        DemoClip(id: id, entry: entry(id, .image(filename: "\(id).png"), hour, minute), thumbnail: DemoImages.thumbnail(style), pixelSize: pixelSize)
    }

    static func file(_ id: String, _ name: Localized, bytes: Int64, _ l10n: L10n, at hour: Int, _ minute: Int) -> DemoClip {
        let payload = ClipboardPayload.file(storedFilename: id, originalName: name(l10n), byteCount: bytes)
        return DemoClip(id: id, entry: entry(id, payload, hour, minute), fileIcon: DemoImages.pdfIcon)
    }

    private static func entry(_ id: String, _ payload: ClipboardPayload, _ hour: Int, _ minute: Int) -> ClipboardEntry {
        let date = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
        return ClipboardEntry(id: uuid(id), payload: payload, createdAt: date, fingerprint: id)
    }

    /// The same identity for the same demo clip, frame after frame.
    private static func uuid(_ id: String) -> UUID {
        let bits = UInt64(UInt(bitPattern: id.hashValue)) & 0xFFFF_FFFF_FFFF
        return UUID(uuidString: String(format: "00000000-0000-4000-8000-%012llx", bits)) ?? UUID()
    }
}

/// Pictures for demo clips, drawn once.
@MainActor
enum DemoImages {
    static let pdfIcon = NSWorkspace.shared.icon(for: .pdf)
    private static var thumbnails: [PhotoArt.Style: NSImage] = [:]

    static func thumbnail(_ style: PhotoArt.Style) -> NSImage {
        if let image = thumbnails[style] {
            return image
        }
        let size = style == .mountains ? CGSize(width: 160, height: 100) : CGSize(width: 90, height: 120)
        let renderer = ImageRenderer(content: PhotoArt(style: style).frame(width: size.width, height: size.height))
        renderer.scale = 2
        let image = renderer.nsImage ?? NSImage(size: size)
        thumbnails[style] = image
        return image
    }
}

/// A journal row for a demo clip, titled exactly as the journal titles it.
struct DemoRow: View {
    let clip: DemoClip
    var isSelected = false
    var isHovered = false
    let palette: ThemePalette

    @Environment(\.l10n) private var l10n

    var body: some View {
        EntryRow(
            entry: clip.entry,
            thumbnail: clip.thumbnail,
            fileIcon: clip.fileIcon,
            title: ClipLabels.rowTitle(clip.entry, l10n),
            subtitle: ClipLabels.rowSubtitle(clip.entry, pixelSize: clip.pixelSize, l10n),
            isSelected: isSelected,
            isCurrent: false,
            palette: palette,
            onQuickPaste: {},
            onExpand: clip.entry.isText ? nil : {},
            onTogglePin: {},
            onDelete: {},
            hoverOverride: isHovered
        )
    }
}

/// How the journal inserts and removes rows (JournalView's list).
extension AnyTransition {
    static var journalRow: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .offset(y: -10)),
            removal: .opacity.combined(with: .scale(scale: 0.96))
        )
    }
}

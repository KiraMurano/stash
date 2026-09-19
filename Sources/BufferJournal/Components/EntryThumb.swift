import AppKit
import SwiftUI

/// The 42 pt tile at the start of a row: an image thumbnail, a file icon or the text's first letter.
struct EntryThumb: View {
    let entry: ClipboardEntry
    let thumbnail: NSImage?
    let fileIcon: NSImage?
    let palette: ThemePalette

    var body: some View {
        content
            .frame(width: 42, height: 42)
            .background(palette.placeholderBackground)
            .background(palette.sidebarTint)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .shadow(color: palette.controlShadow, radius: ThemePalette.controlShadowRadius, y: 1)
    }

    @ViewBuilder
    private var content: some View {
        switch entry.payload {
        case .image:
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .interpolation(.medium)
                    .scaledToFill()
            }
        case .file:
            if let fileIcon {
                Image(nsImage: fileIcon)
                    .resizable()
                    .padding(4)
            } else {
                Image(systemName: "doc")
                    .font(.system(size: 16))
                    .foregroundStyle(palette.textSecondary)
            }
        case let .text(text):
            Text(String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1)))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(palette.textSecondary)
        }
    }
}

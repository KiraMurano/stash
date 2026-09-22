import AppKit
import SwiftUI

/// The 42 pt tile at the start of a row: an image thumbnail, a file icon, or a mark for text and links.
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
        case .text:
            if entry.isLink {
                Image(systemName: "link")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(palette.textSecondary)
            } else {
                // The system's "Aa" text mark, so text and links read apart at a glance.
                Image(systemName: "textformat")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.textSecondary)
            }
        }
    }
}

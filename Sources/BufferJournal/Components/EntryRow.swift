import AppKit
import SwiftUI

struct EntryRow: View {
    let entry: ClipboardEntry
    let thumbnail: NSImage?
    let fileIcon: NSImage?
    let title: String
    let subtitle: String
    let isSelected: Bool
    let isCurrent: Bool
    let palette: ThemePalette
    let onQuickPaste: () -> Void
    let onExpand: (() -> Void)?
    let onTogglePin: () -> Void
    let onDelete: () -> Void

    @Environment(\.l10n) private var l10n
    @State private var isHovered = false

    private static let actionSize: CGFloat = 26
    private static let actionSpacing: CGFloat = 4
    /// Space the pin/clipboard column and its HStack spacing take right of the text column.
    private static let trailingColumnWidth: CGFloat = 20

    private var actionsWidth: CGFloat {
        let count = CGFloat(onExpand == nil ? 3 : 4)
        return count * Self.actionSize + (count - 1) * Self.actionSpacing
    }

    var body: some View {
        HStack(spacing: 10) {
            thumb
                .frame(width: 42, height: 42)
                .background(palette.placeholderBackground)
                .background(palette.sidebarTint)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .shadow(color: palette.controlShadow, radius: ThemePalette.controlShadowRadius, y: 1)

            Group {
                if entry.isText {
                    // Short text keeps its date line; text that needs two lines uses both for content.
                    ViewThatFits(in: .horizontal) {
                        VStack(alignment: .leading, spacing: 2) {
                            titleText.fixedSize(horizontal: true, vertical: false)
                            subtitleText
                        }
                        titleText.lineLimit(2)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        titleText.lineLimit(entry.isImage ? 1 : 2)
                        subtitleText
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // Under the hover actions the text fades out instead of reflowing. Only the text
            // column is masked so the thumbnail's shadow is not clipped.
            .mask {
                HStack(spacing: 0) {
                    Color.black
                    LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: isHovered ? 24 : 0)
                    Color.clear
                        .frame(width: isHovered ? max(actionsWidth - Self.trailingColumnWidth, 0) : 0)
                }
            }

            VStack(spacing: 6) {
                if entry.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(isSelected ? palette.onAccentSecondary : palette.textTertiary)
                }
                if isCurrent {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(isSelected && palette.solid ? .white : palette.accentText)
                }
            }
            .opacity(isHovered ? 0 : 1)
        }
        .padding(.horizontal, 8)
        // Fixed height: variable rows made the list re-measure while scrolling and jump.
        .frame(height: JournalView.Layout.rowHeight - 2)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? palette.accentFill : (isHovered ? palette.controlHoverBackground : .clear))
        }
        // The 1 pt gap between highlights stays visual only: the hover area covers it.
        .padding(.vertical, 1)
        .contentShape(Rectangle())
        .overlay(alignment: .leading) {
            if isSelected {
                Capsule()
                    .fill(ThemePalette.orange)
                    .frame(width: 3)
                    .padding(.vertical, 10)
                    .offset(x: -6)
            }
        }
        .overlay(alignment: .trailing) {
            // Floats over the row so hovering never reflows the title.
            if isHovered {
                HStack(spacing: Self.actionSpacing) {
                    if let onExpand {
                        rowAction("arrow.up.left.and.arrow.down.right", help: entry.isImage ? l10n("Open in Preview", "Открыть в Просмотре") : l10n("Open", "Открыть"), action: onExpand)
                    }
                    rowAction(
                        entry.isPinned ? "pin.fill" : "pin",
                        tone: entry.isPinned ? accentTone : .neutral,
                        help: entry.isPinned ? l10n("Unpin clip", "Открепить") : l10n("Pin clip", "Закрепить"),
                        action: onTogglePin
                    )
                    rowAction("trash", tone: .destructive, help: l10n("Delete clip", "Удалить"), action: onDelete)
                    rowAction("return", tone: accentTone, help: l10n("Paste", "Вставить"), action: onQuickPaste)
                }
                .padding(.trailing, 8)
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .onHover { isHovered = $0 }
    }

    private var accentTone: TranslucentButtonStyle.Tone {
        isSelected ? .accentOnAccent : .accent
    }

    private func rowAction(
        _ systemName: String,
        tone: TranslucentButtonStyle.Tone = .neutral,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .bold))
                .frame(width: Self.actionSize, height: Self.actionSize)
        }
        .buttonStyle(TranslucentButtonStyle(tone: tone, cornerRadius: 7))
        .help(help)
    }

    private var titleText: some View {
        Text(title)
            .font(.system(size: 13, weight: entry.isText ? .regular : .semibold))
            .foregroundStyle(isSelected ? palette.onAccent : palette.textPrimary)
    }

    private var subtitleText: some View {
        Text(subtitle)
            .font(.system(size: 11))
            .foregroundStyle(isSelected ? palette.onAccentSecondary : palette.textTertiary)
            .lineLimit(1)
    }

    @ViewBuilder
    private var thumb: some View {
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

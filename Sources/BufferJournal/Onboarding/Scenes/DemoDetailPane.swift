import SwiftUI

/// The journal's preview pane for a demo clip: kind and time on top, the clip itself, and the
/// action bar with the orange "Paste" button. Built from the same parts as JournalView's `detail`.
struct DemoDetailPane: View {
    let clip: DemoClip
    /// The photo drawn large for image clips.
    var photo: PhotoArt.Style = .mountains
    let palette: ThemePalette

    @Environment(\.l10n) private var l10n

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text(ClipLabels.kindTitle(clip.entry, l10n))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)
                Text("· \(ClipLabels.timeTitle(clip.entry.createdAt, l10n))")
                    .font(.system(size: 11))
                    .foregroundStyle(palette.textTertiary)
                Spacer(minLength: 0)
                GlassIconButton(systemName: "xmark", help: l10n("Close", "Закрыть"), action: {})
            }
            .padding(.leading, 16)
            .padding(.trailing, 10)
            .padding(.top, 10)
            .padding(.bottom, 4)

            stage
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: 6) {
                if clip.entry.isImage {
                    GlassIconButton(systemName: "arrow.up.left.and.arrow.down.right", help: "", action: {})
                } else {
                    GlassIconButton(systemName: "pencil", help: "", action: {})
                }
                GlassIconButton(systemName: clip.entry.isPinned ? "pin.fill" : "pin", help: "", action: {})
                GlassIconButton(systemName: "trash", isDestructive: true, help: "", action: {})
                Spacer(minLength: 0)
                Button(action: {}) {
                    HStack(spacing: 6) {
                        Text(l10n("Paste", "Вставить"))
                        Image(systemName: "return")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 12)
                    .frame(height: 28)
                }
                .buttonStyle(TranslucentButtonStyle(tone: .accent, cornerRadius: 8))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .overlay(alignment: .top) {
                palette.separator.frame(height: 1)
            }
        }
    }

    @ViewBuilder
    private var stage: some View {
        switch clip.entry.payload {
        case let .text(text):
            Text(text)
                .font(.system(size: 13))
                .lineSpacing(3)
                .foregroundStyle(palette.textPrimary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        case .image:
            PhotoArt(style: photo)
                .aspectRatio(clip.pixelSize.map { $0.width / $0.height } ?? 1.6, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .shadow(color: palette.shadow(0.18), radius: 10, y: 4)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        case .file:
            Image(nsImage: clip.fileIcon ?? DemoImages.pdfIcon)
                .resizable()
                .frame(width: 72, height: 72)
        }
    }
}

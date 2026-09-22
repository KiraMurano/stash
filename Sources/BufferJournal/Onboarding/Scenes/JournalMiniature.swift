import AppKit
import SwiftUI

/// The whole journal at its default 640 × 440, built from the journal's own parts, for scenes to
/// shrink. Opaque: there is no glass inside a scene to show through.
struct JournalMiniature: View {
    let palette: ThemePalette
    /// The clip the list has picked, and the one the pane on the right shows.
    var selected: Int = 0

    @Environment(\.l10n) private var l10n

    var body: some View {
        let clips = [
            DemoClips.text("mini-address", Localized(en: "Office address: 12 Main St, entrance 3", ru: "Адрес офиса: Тверская, 12, подъезд 3"), l10n, at: 14, 20),
            DemoClips.image("mini-photo", .mountains, pixelSize: CGSize(width: 1600, height: 1000), at: 14, 2),
            DemoClips.file("mini-contract", Localized(en: "Contract.pdf", ru: "Договор.pdf"), bytes: 1_240_000, l10n, at: 12, 10),
            DemoClips.text("mini-promo", Localized(en: "Promo code AUTUMN25", ru: "Промокод AUTUMN25"), l10n, at: 9, 12),
        ]
        let shape = RoundedRectangle(cornerRadius: JournalView.Layout.cornerRadius, style: .continuous)

        HStack(spacing: 0) {
            VStack(spacing: 0) {
                HStack(spacing: 2) {
                    Image(nsImage: NSApplication.shared.applicationIconImage)
                        .resizable()
                        .frame(width: 32, height: 32)
                    Text("Stash")
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundStyle(palette.textPrimary)
                    Spacer(minLength: 0)
                    Text("\(clips.count)/20")
                        .font(.system(size: 11, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(palette.textTertiary)
                        .padding(.trailing, 6)
                    GlassIconButton(systemName: "trash", isDestructive: true, help: "", action: {})
                }
                .padding(.leading, 14)
                .padding(.trailing, 10)
                .padding(.top, 12)
                .padding(.bottom, 10)

                TypeSegmentedControl(
                    titles: [l10n("All", "Все"), l10n("Text", "Текст"), l10n("Images", "Картинки"), l10n("Files", "Файлы")],
                    selectedIndex: 0,
                    palette: palette,
                    onSelect: { _ in }
                )
                .padding(.horizontal, 10)
                .padding(.bottom, 8)

                VStack(spacing: 0) {
                    SectionHeader(title: l10n("Today", "Сегодня"), palette: palette)
                    ForEach(Array(clips.enumerated()), id: \.element.id) { index, clip in
                        DemoRow(clip: clip, isSelected: index == selected, palette: palette)
                    }
                }
                .padding(.horizontal, 10)
                Spacer(minLength: 0)
            }
            .frame(width: JournalView.Layout.sidebarWidth)
            .background(palette.listSurface)
            .overlay(alignment: .trailing) {
                palette.separator.frame(width: 1)
            }

            DemoDetailPane(clip: clips[selected], palette: palette)
                .background(palette.detailSurface)
        }
        .frame(width: JournalView.Layout.width, height: JournalView.Layout.height)
        .clipShape(shape)
        .overlay(shape.strokeBorder(palette.border, lineWidth: 1))
    }
}

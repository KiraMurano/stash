import SwiftUI

/// КАРТИНКИ: a piece of the journal at full size. The arrow picks "Images" in the type filter,
/// the list keeps the two images and shows the first; a click on it opens Preview.
struct ImagesScene: View {
    static let duration = 4.2
    /// A piece of the journal at full size: the list pane, wide enough for the whole filter, and
    /// the preview pane.
    static let size = CGSize(width: 520, height: 240)
    static let listWidth: CGFloat = 270

    struct State: Equatable {
        var cursor: CursorState
        var ripple: ClickRipple?
        /// Index in the type filter: 0 all, 2 images.
        var filter: Int
        /// 0…1: the Preview window opening.
        var preview: Double
    }

    /// Centre of the "Images" segment: filter x 10…260, four segments of 61.5 pt after a 2 pt inset.
    static let imagesSegment = CGPoint(x: 166, y: 24)
    /// The picture in the preview pane, which runs from x 270 to 520.
    static let picture = CGPoint(x: 395, y: 112)

    private static let cursor = CursorTrack(
        tip: Track(CGPoint(x: 300, y: 236))
            .to(imagesSegment, at: 0.3, until: 0.85)
            .to(picture, at: 1.5, until: 2.05),
        opacity: Track(0.0).to(1, at: 0.15, until: 0.35),
        clicks: [1.0, 2.3]
    )
    private static let filter = Track(0).set(2, at: 1.04)
    private static let preview = Track(0.0).to(1, at: 2.35, until: 2.6, .easeOut)

    static func state(at time: SceneTime) -> State {
        State(
            cursor: cursor.state(at: time),
            ripple: cursor.ripple(at: time),
            filter: filter.value(at: time),
            preview: preview.value(at: time)
        )
    }

    let time: SceneTime

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.l10n) private var l10n

    var body: some View {
        let state = Self.state(at: time)
        let palette = ThemePalette.scene(colorScheme)
        let all = clips
        let visible = state.filter == 2 ? all.filter(\.entry.isImage) : all
        let selected = visible[0]

        ZStack(alignment: .topLeading) {
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    TypeSegmentedControl(
                        titles: [l10n("All", "Все"), l10n("Text", "Текст"), l10n("Images", "Картинки"), l10n("Files", "Файлы")],
                        selectedIndex: state.filter,
                        palette: palette,
                        onSelect: { _ in }
                    )
                    .padding(.horizontal, 10)
                    .padding(.top, 10)
                    .padding(.bottom, 6)

                    VStack(spacing: 0) {
                        SectionHeader(title: l10n("Today", "Сегодня"), palette: palette)
                        ForEach(visible) { clip in
                            DemoRow(clip: clip, isSelected: clip.id == selected.id, palette: palette)
                                .transition(.journalRow)
                        }
                    }
                    .padding(.horizontal, 10)
                    Spacer(minLength: 0)
                }
                .frame(width: Self.listWidth)
                .background(palette.listSurface)
                .overlay(alignment: .trailing) {
                    palette.separator.frame(width: 1)
                }

                DemoDetailPane(clip: selected, photo: selected.id == "images-sunset" ? .sunset : .mountains, palette: palette)
                    .id(selected.id)
                    .transition(.opacity)
                    .background(palette.detailSurface)
            }
            .animation(.easeOut(duration: 0.22), value: state.filter)

            SceneWindow(title: l10n("Preview", "Просмотр"), palette: palette) {
                PhotoArt(style: .mountains)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .padding(8)
            }
            .frame(width: 340, height: 212)
            .scaleEffect(0.96 + 0.04 * state.preview)
            .opacity(state.preview)
            .offset(x: 90, y: 14)

            SceneRipple(ripple: state.ripple)
            SceneCursor(state: state.cursor)
        }
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
        .clipped()
    }

    private var clips: [DemoClip] {
        [
            DemoClips.text("images-meeting", Localized(en: "Meeting at 3 pm, room 3", ru: "Встреча в 15:00, переговорка 3"), l10n, at: 14, 20),
            DemoClips.image("images-mountains", .mountains, pixelSize: CGSize(width: 1600, height: 1000), at: 14, 2),
            DemoClips.file("images-contract", Localized(en: "Contract.pdf", ru: "Договор.pdf"), bytes: 1_240_000, l10n, at: 12, 10),
            DemoClips.image("images-sunset", .sunset, pixelSize: CGSize(width: 900, height: 1200), at: 11, 48),
        ]
    }
}

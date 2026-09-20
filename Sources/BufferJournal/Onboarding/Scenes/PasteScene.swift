import SwiftUI

/// ВСТАВКА: two ways with the mouse to put a clip into the letter next to the list — the orange
/// button of a text clip, and a double click on an image. Then the journal goes away, because
/// Close After Selection is on by default. ⏎ belongs to the slide about the keys.
struct PasteScene: View {
    static let duration = 4.0
    /// The list, and the letter to its right.
    static let size = CGSize(width: 470, height: 236)

    struct State: Equatable {
        var cursor: CursorState
        var ripple: ClickRipple?
        var hoveredRow: Int?
        var selectedRow: Int?
        /// 1 while the journal is there, 0 once it has dissolved.
        var journal: Double
        /// 0…1 each: the text and the image appearing in the letter.
        var pastedText: Double
        var pastedImage: Double
    }

    // MARK: Geometry, in canvas coordinates

    /// The list: rows 58 pt tall under a 26 pt heading, starting 4 pt down.
    static let listWidth: CGFloat = 270
    private static let rowHeight: CGFloat = 58
    private static let firstRowTop: CGFloat = 30

    private static func rowCenter(_ index: Int) -> CGPoint {
        CGPoint(x: 150, y: rowCenterY(index))
    }

    static func rowCenterY(_ index: Int) -> CGFloat {
        firstRowTop + (CGFloat(index) + 0.5) * rowHeight
    }

    /// Tip of the arrow over the orange paste button of a row: the first of the three, counted
    /// back from the row's trailing edge (list 10…260, buttons 26 wide, 4 apart, 8 from the edge).
    static func pasteButton(of index: Int) -> CGPoint {
        CGPoint(x: 260 - 8 - 3 * 26 - 2 * 4 + 13, y: rowCenter(index).y)
    }

    /// The rows, in the order the scene works through them.
    static let textRow = 1
    static let imageRow = 0

    // MARK: Time

    /// The orange button of the text clip.
    static let buttonClick = 1.35
    /// Two clicks in a row on the image.
    static let doubleClick = [2.55, 2.72]

    private static let cursor = CursorTrack(
        tip: Track(CGPoint(x: 230, y: 240))
            .to(rowCenter(textRow), at: 0.3, until: 0.8)
            .to(pasteButton(of: textRow), at: 0.9, until: 1.2)
            .to(rowCenter(imageRow), at: 1.95, until: 2.35),
        opacity: Track(0.0).to(1, at: 0.15, until: 0.35),
        clicks: [buttonClick] + doubleClick
    )
    private static let hovered = Track<Int?>(nil)
        .set(textRow, at: 0.62)
        .set(imageRow, at: 2.1)
    private static let selected = Track<Int?>(nil)
        .set(textRow, at: buttonClick + 0.04)
        .set(imageRow, at: doubleClick[1] + 0.04)
    // The panel's own fade is 0.13 s — too quick to follow; the spec gives the scene 0.2 s.
    private static let journal = Track(1.0).to(0, at: 3.5, until: 3.7, .easeOut)
    private static let pastedText = Track(0.0).to(1, at: 1.5, until: 1.8, .easeOut)
    private static let pastedImage = Track(0.0).to(1, at: 2.9, until: 3.2, .easeOut)

    static func state(at time: SceneTime) -> State {
        State(
            cursor: cursor.state(at: time),
            ripple: cursor.ripple(at: time),
            hoveredRow: hovered.value(at: time),
            selectedRow: selected.value(at: time),
            journal: journal.value(at: time),
            pastedText: pastedText.value(at: time),
            pastedImage: pastedImage.value(at: time)
        )
    }

    static let invoice = Localized(en: "Invoice for September #1042", ru: "Счёт за сентябрь № 1042")
    static let contract = Localized(en: "Contract.pdf", ru: "Договор.pdf")

    let time: SceneTime

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.l10n) private var l10n

    var body: some View {
        let state = Self.state(at: time)
        let palette = ThemePalette.scene(colorScheme)
        let clips = [
            DemoClips.image("paste-photo", .mountains, pixelSize: CGSize(width: 1600, height: 1000), at: 14, 2),
            DemoClips.text("paste-invoice", Self.invoice, l10n, at: 13, 47),
            DemoClips.file("paste-contract", Self.contract, bytes: 1_240_000, l10n, at: 12, 10),
        ]

        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                SectionHeader(title: l10n("Today", "Сегодня"), palette: palette)
                ForEach(Array(clips.enumerated()), id: \.element.id) { index, clip in
                    DemoRow(clip: clip, isSelected: state.selectedRow == index, isHovered: state.hoveredRow == index, palette: palette)
                }
            }
            .padding(.horizontal, 10)
            .frame(width: Self.listWidth)
            .padding(.top, 4)
            .opacity(state.journal)

            SceneWindow(title: l10n("Letter", "Письмо"), palette: palette) {
                letter(state, palette: palette)
            }
            .frame(width: 186, height: 212)
            .offset(x: 274, y: 10)

            SceneRipple(ripple: state.ripple)
            SceneCursor(state: state.cursor)
        }
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
    }

    /// The letter fills up clip by clip: the invoice, then the photo.
    private func letter(_ state: State, palette: ThemePalette) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            SceneTextLine(width: 120, palette: palette)
            SceneTextLine(width: 150, palette: palette)

            if state.pastedText > 0 {
                Text(Self.invoice(l10n))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(palette.textPrimary)
                    .lineLimit(1)
                    .modifier(Landing(progress: state.pastedText))
            }

            if state.pastedImage > 0 {
                PhotoArt(style: .mountains)
                    .frame(width: 104, height: 65)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .modifier(Landing(progress: state.pastedImage))
            }

            SceneCaret(height: 13, visible: SceneCaret.isVisible(at: time, duration: Self.duration))
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// A pasted clip fades in and settles, the way text does when it lands.
    private struct Landing: ViewModifier {
        let progress: Double

        func body(content: Content) -> some View {
            content
                .opacity(progress)
                .offset(y: (1 - progress) * 4)
        }
    }
}

import SwiftUI

/// ВСТАВКА: a double click puts a clip into the letter next to the list — first a text clip,
/// then an image. Then the journal goes away, because Close After Selection is on by default.
/// ⏎ belongs to the slide about the keys.
struct PasteScene: View {
    static let duration = 4.0
    /// The list, and the letter to its right.
    static let size = CGSize(width: 470, height: 236)

    struct State: Equatable {
        var cursor: CursorState
        var ripple: ClickRipple?
        var hoveredRow: Int?
        var selectedRow: Int?
        /// The wave of a click that lands on the row the first click has already selected.
        var isRippleLight: Bool
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

    /// The rows, in the order the scene works through them.
    static let textRow = 1
    static let imageRow = 0

    // MARK: Time

    /// Two clicks in a row on the text clip, then two on the image.
    static let textDoubleClick = [1.1, 1.27]
    static let imageDoubleClick = [2.5, 2.67]

    /// A double click selects the row on its first click, so the second wave would be orange on
    /// orange. It goes white instead.
    private static func isRippleLight(at time: SceneTime) -> Bool {
        guard time.rewind == 0 else { return false }
        return [textDoubleClick[1], imageDoubleClick[1]].contains {
            time.t >= $0 && time.t < $0 + CursorTrack.rippleTime
        }
    }

    private static let cursor = CursorTrack(
        tip: Track(CGPoint(x: 230, y: 240))
            .to(rowCenter(textRow), at: 0.3, until: 0.8)
            .to(rowCenter(imageRow), at: 1.9, until: 2.3),
        opacity: Track(0.0).to(1, at: 0.15, until: 0.35),
        clicks: textDoubleClick + imageDoubleClick
    )
    private static let hovered = Track<Int?>(nil)
        .set(textRow, at: 0.62)
        .set(imageRow, at: 2.05)
    // The first click of the pair selects the row, as a single click does in the journal; the
    // second one pastes it.
    private static let selected = Track<Int?>(nil)
        .set(textRow, at: textDoubleClick[0] + 0.04)
        .set(imageRow, at: imageDoubleClick[0] + 0.04)
    // The panel's own fade is 0.13 s — too quick to follow; the spec gives the scene 0.2 s.
    private static let journal = Track(1.0).to(0, at: 3.45, until: 3.65, .easeOut)
    private static let pastedText = Track(0.0).to(1, at: 1.45, until: 1.75, .easeOut)
    private static let pastedImage = Track(0.0).to(1, at: 2.85, until: 3.15, .easeOut)

    static func state(at time: SceneTime) -> State {
        State(
            cursor: cursor.state(at: time),
            ripple: cursor.ripple(at: time),
            hoveredRow: hovered.value(at: time),
            selectedRow: selected.value(at: time),
            isRippleLight: isRippleLight(at: time),
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

            SceneRipple(ripple: state.ripple, isLight: state.isRippleLight)
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

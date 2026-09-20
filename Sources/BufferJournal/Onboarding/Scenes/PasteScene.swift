import SwiftUI

/// ВСТАВКА: three ways to put a clip into the letter next to the list. The arrow clicks a text
/// clip's orange button, double-clicks an image, and selects a file to paste it with ⏎. Then the
/// journal goes away — Close After Selection is on by default.
struct PasteScene: View {
    static let duration = 5.6
    /// The list with its ⏎ key, and the letter to its right.
    static let size = CGSize(width: 470, height: 286)

    struct State: Equatable {
        var cursor: CursorState
        var ripple: ClickRipple?
        var hoveredRow: Int?
        var selectedRow: Int?
        var returnPressed: Bool
        /// 1 while the journal is there, 0 once it has dissolved.
        var journal: Double
        /// 0…1 each: the text, the image and the file appearing in the letter.
        var pastedText: Double
        var pastedImage: Double
        var pastedFile: Double
    }

    // MARK: Geometry, in canvas coordinates

    /// The list: rows 58 pt tall under a 26 pt heading, starting 4 pt down.
    static let listWidth: CGFloat = 270
    private static let rowHeight: CGFloat = 58
    private static let firstRowTop: CGFloat = 30

    private static func rowCenter(_ index: Int) -> CGPoint {
        CGPoint(x: 150, y: firstRowTop + (CGFloat(index) + 0.5) * rowHeight)
    }

    /// Tip of the arrow over the orange return button of a row.
    static func returnButton(of index: Int) -> CGPoint {
        CGPoint(x: 239, y: rowCenter(index).y)
    }

    /// The rows, in the order the scene works through them.
    static let textRow = 1
    static let imageRow = 0
    static let fileRow = 2

    // MARK: Time

    /// The orange button of the text clip.
    static let buttonClick = 1.35
    /// Two clicks in a row on the image.
    static let doubleClick = [2.55, 2.72]
    /// The click that only selects the file; ⏎ is what pastes it.
    static let selectClick = 3.95
    static let returnPress = 4.5

    private static let cursor = CursorTrack(
        tip: Track(CGPoint(x: 230, y: 290))
            .to(rowCenter(textRow), at: 0.3, until: 0.8)
            .to(returnButton(of: textRow), at: 0.9, until: 1.2)
            .to(rowCenter(imageRow), at: 1.95, until: 2.35)
            .to(rowCenter(fileRow), at: 3.35, until: 3.75),
        opacity: Track(0.0).to(1, at: 0.15, until: 0.35),
        clicks: [buttonClick] + doubleClick + [selectClick]
    )
    private static let hovered = Track<Int?>(nil)
        .set(textRow, at: 0.62)
        .set(imageRow, at: 2.1)
        .set(fileRow, at: 3.5)
    private static let selected = Track<Int?>(nil)
        .set(textRow, at: buttonClick + 0.04)
        .set(imageRow, at: doubleClick[1] + 0.04)
        .set(fileRow, at: selectClick + 0.04)
    private static let returnPressed = Track(false).set(true, at: returnPress).set(false, at: returnPress + 0.12)
    // The panel's own fade is 0.13 s — too quick to follow; the spec gives the scene 0.2 s.
    private static let journal = Track(1.0).to(0, at: 5.1, until: 5.3, .easeOut)
    private static let pastedText = Track(0.0).to(1, at: 1.5, until: 1.8, .easeOut)
    private static let pastedImage = Track(0.0).to(1, at: 2.9, until: 3.2, .easeOut)
    private static let pastedFile = Track(0.0).to(1, at: returnPress + 0.15, until: returnPress + 0.45, .easeOut)

    static func state(at time: SceneTime) -> State {
        State(
            cursor: cursor.state(at: time),
            ripple: cursor.ripple(at: time),
            hoveredRow: hovered.value(at: time),
            selectedRow: selected.value(at: time),
            returnPressed: returnPressed.value(at: time),
            journal: journal.value(at: time),
            pastedText: pastedText.value(at: time),
            pastedImage: pastedImage.value(at: time),
            pastedFile: pastedFile.value(at: time)
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

            // The key that pastes the selected file, as in the journal.
            SceneKeycap(label: "⏎", size: 46, pressed: state.returnPressed)
                .opacity(state.journal)
                .offset(x: 112, y: 218)

            SceneWindow(title: l10n("Letter", "Письмо"), palette: palette) {
                letter(state, palette: palette)
            }
            .frame(width: 186, height: 262)
            .offset(x: 274, y: 10)

            SceneRipple(ripple: state.ripple)
            SceneCursor(state: state.cursor)
        }
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
    }

    /// The letter fills up clip by clip: the invoice, the photo, the contract.
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

            HStack(spacing: 4) {
                if state.pastedFile > 0 {
                    Image(nsImage: DemoImages.pdfIcon)
                        .resizable()
                        .frame(width: 14, height: 14)
                        .modifier(Landing(progress: state.pastedFile))
                    Text(Self.contract(l10n))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(palette.textPrimary)
                        .lineLimit(1)
                        .modifier(Landing(progress: state.pastedFile))
                }
                SceneCaret(height: 13, visible: SceneCaret.isVisible(at: time, duration: Self.duration))
            }
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

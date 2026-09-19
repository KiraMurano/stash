import SwiftUI

/// ВСТАВКА: the arrow hovers a text clip and clicks its orange arrow; the row is selected, the
/// clip's text lands at the insertion point of a letter next to the list, and the journal goes
/// away — Close After Selection is on by default.
struct PasteScene: View {
    static let duration = 3.6
    /// The list, and the letter to its right.
    static let size = CGSize(width: 470, height: 236)

    struct State: Equatable {
        var cursor: CursorState
        var ripple: ClickRipple?
        var hoveredRow: Int?
        var selectedRow: Int?
        /// 1 while the journal is there, 0 once it has dissolved.
        var journal: Double
        /// 0…1: the pasted text appearing in the letter.
        var pasted: Double
    }

    /// Tip of the arrow over the orange return button of the second row (list x 10…260, row y 88…146).
    static let returnButton = CGPoint(x: 239, y: 117)
    private static let click = 1.5

    private static let cursor = CursorTrack(
        tip: Track(CGPoint(x: 230, y: 240))
            .to(CGPoint(x: 150, y: 117), at: 0.3, until: 0.8)
            .to(returnButton, at: 0.95, until: 1.35),
        opacity: Track(0.0).to(1, at: 0.15, until: 0.35),
        clicks: [click]
    )
    private static let hovered = Track<Int?>(nil).set(1, at: 0.62)
    private static let selected = Track<Int?>(nil).set(1, at: click + 0.04)
    // The panel's own fade is 0.13 s — too quick to follow; the spec gives the scene 0.2 s.
    private static let journal = Track(1.0).to(0, at: 1.7, until: 1.9, .easeOut)
    private static let pasted = Track(0.0).to(1, at: 1.75, until: 2.05, .easeOut)

    static func state(at time: SceneTime) -> State {
        State(
            cursor: cursor.state(at: time),
            ripple: cursor.ripple(at: time),
            hoveredRow: hovered.value(at: time),
            selectedRow: selected.value(at: time),
            journal: journal.value(at: time),
            pasted: pasted.value(at: time)
        )
    }

    static let invoice = Localized(en: "Invoice for September #1042", ru: "Счёт за сентябрь № 1042")

    let time: SceneTime

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.l10n) private var l10n

    var body: some View {
        let state = Self.state(at: time)
        let palette = ThemePalette.scene(colorScheme)
        let clips = [
            DemoClips.image("paste-photo", .mountains, pixelSize: CGSize(width: 1600, height: 1000), at: 14, 2),
            DemoClips.text("paste-invoice", Self.invoice, l10n, at: 13, 47),
            DemoClips.file("paste-contract", Localized(en: "Contract.pdf", ru: "Договор.pdf"), bytes: 1_240_000, l10n, at: 12, 10),
        ]

        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                SectionHeader(title: l10n("Today", "Сегодня"), palette: palette)
                ForEach(Array(clips.enumerated()), id: \.element.id) { index, clip in
                    DemoRow(clip: clip, isSelected: state.selectedRow == index, isHovered: state.hoveredRow == index, palette: palette)
                }
            }
            .padding(.horizontal, 10)
            .frame(width: 270)
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

    private func letter(_ state: State, palette: ThemePalette) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            SceneTextLine(width: 120, palette: palette)
            SceneTextLine(width: 150, palette: palette)
            SceneTextLine(width: 96, palette: palette)
            SceneTextLine(width: 138, palette: palette)
            HStack(spacing: 1) {
                if state.pasted > 0 {
                    Text(Self.invoice(l10n))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(palette.textPrimary)
                        .lineLimit(1)
                        .opacity(state.pasted)
                        .offset(y: (1 - state.pasted) * 4)
                }
                SceneCaret(height: 13, visible: SceneCaret.isVisible(at: time, duration: Self.duration))
            }
        }
        .padding(14)
    }
}

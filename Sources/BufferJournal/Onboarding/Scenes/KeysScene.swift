import SwiftUI

/// КЛАВИШИ: no pointer. The journal is open next to a document, and the letters still go to the
/// document. ↓ and ↓ move the selection, ⏎ pastes the third clip behind the typed word and the
/// journal goes away.
struct KeysScene: View {
    static let duration = 4.2
    /// The document with its keys, and the journal's rows to its right.
    static let size = CGSize(width: 470, height: 236)

    struct State: Equatable {
        /// Letters of the word typed so far.
        var typed: Int
        var downPressed: Bool
        var returnPressed: Bool
        /// Which row the journal's keys have landed on.
        var selectedRow: Int
        /// 1 while the journal is there, 0 once it has dissolved.
        var journal: Double
        /// 0…1: the pasted clip appearing in the document.
        var pasted: Double
    }

    /// The word being typed while the journal is open.
    static let word = Localized(en: "typ", ru: "нап")
    static let letters = 3

    // Typing starts at 0.4 s and a letter lands every 0.2 s; the word stands by 1.0 s.
    private static let typed = Track(0).set(1, at: 0.4).set(2, at: 0.6).set(3, at: 0.8)
    private static let down = Track(false)
        .set(true, at: 1.6).set(false, at: 1.72)
        .set(true, at: 2.0).set(false, at: 2.12)
    private static let selected = Track(0).set(1, at: 1.64).set(2, at: 2.04)
    private static let enter = Track(false).set(true, at: 2.6).set(false, at: 2.72)
    // The panel's own fade is 0.13 s — too quick to follow; the spec gives the scene 0.2 s.
    private static let journal = Track(1.0).to(0, at: 2.7, until: 2.9, .easeOut)
    private static let pasted = Track(0.0).to(1, at: 2.68, until: 2.98, .easeOut)

    static func state(at time: SceneTime) -> State {
        State(
            typed: typed.value(at: time),
            downPressed: down.value(at: time),
            returnPressed: enter.value(at: time),
            selectedRow: selected.value(at: time),
            journal: journal.value(at: time),
            pasted: pasted.value(at: time)
        )
    }

    // MARK: Geometry, in canvas coordinates

    /// The document the person keeps typing in.
    private static let window = CGRect(x: 8, y: 6, width: 178, height: 152)
    /// The keys pressed under it: ↓ and ⏎, centred on the window.
    private static let keySize: CGFloat = 52
    private static let keysTop: CGFloat = 172
    /// The journal's rows, at their real width, to the right of the window.
    private static let listLeft: CGFloat = 192
    private static let listWidth: CGFloat = 270

    let time: SceneTime

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.l10n) private var l10n

    var body: some View {
        let state = Self.state(at: time)
        let palette = ThemePalette.scene(colorScheme)
        let clips = self.clips

        ZStack(alignment: .topLeading) {
            SceneWindow(title: l10n("Document", "Документ"), palette: palette) {
                document(state, palette: palette)
            }
            .frame(width: Self.window.width, height: Self.window.height)
            .offset(x: Self.window.minX, y: Self.window.minY)

            SceneKeycap(label: "↓", size: Self.keySize, pressed: state.downPressed)
                .offset(x: 34, y: Self.keysTop)
            SceneKeycap(label: "⏎", size: Self.keySize, pressed: state.returnPressed)
                .offset(x: 102, y: Self.keysTop)

            VStack(spacing: 0) {
                SectionHeader(title: l10n("Today", "Сегодня"), palette: palette)
                ForEach(Array(clips.enumerated()), id: \.element.id) { index, clip in
                    DemoRow(clip: clip, isSelected: state.selectedRow == index, palette: palette)
                }
            }
            .padding(.horizontal, 10)
            .frame(width: Self.listWidth)
            .opacity(state.journal)
            .offset(x: Self.listLeft, y: 6)
        }
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
    }

    /// Two grey lines and the line being typed: the word, then the pasted clip, then the caret.
    private func document(_ state: State, palette: ThemePalette) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            SceneTextLine(width: 110, palette: palette)
            SceneTextLine(width: 130, palette: palette)
            HStack(spacing: 1) {
                if state.typed > 0 {
                    Text(String(Self.word(l10n).prefix(state.typed)))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(palette.textPrimary)
                }
                if state.pasted > 0 {
                    Text(Self.promo(l10n))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(palette.textPrimary)
                        .lineLimit(1)
                        .opacity(state.pasted)
                        .offset(y: (1 - state.pasted) * 4)
                }
                SceneCaret(height: 13, visible: SceneCaret.isVisible(at: time, duration: Self.duration))
            }
        }
        .padding(.leading, 14)
        .padding(.top, 12)
    }

    /// The clip ⏎ pastes: the third row of the list.
    private static let promo = Localized(en: "Promo code AUTUMN25", ru: "Промокод AUTUMN25")

    private var clips: [DemoClip] {
        [
            DemoClips.image("keys-photo", .mountains, pixelSize: CGSize(width: 1600, height: 1000), at: 14, 2),
            DemoClips.file("keys-contract", Localized(en: "Contract.pdf", ru: "Договор.pdf"), bytes: 1_240_000, l10n, at: 12, 10),
            DemoClips.text("keys-promo", Self.promo, l10n, at: 9, 12),
        ]
    }
}

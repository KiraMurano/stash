import SwiftUI

/// ВЫЗОВ: ⌥ and V go down on a Mac keyboard, and the journal opens over the window in front.
/// Where exactly it lands is not the point here — that it answers these two keys is.
struct HotKeyScene: View {
    static let duration = 2.6
    /// Another app's window with the journal over it, and the two keys under it.
    static let size = CGSize(width: 470, height: 240)

    struct State: Equatable {
        var optionDown: Bool
        var vDown: Bool
        /// 0…1: the journal appearing over the window.
        var journal: Double
    }

    private static let option = Track(false).set(true, at: 0.3).set(false, at: 1.0)
    private static let v = Track(false).set(true, at: 0.5).set(false, at: 1.02)
    private static let journal = Track(0.0).to(1, at: 0.6, until: 0.9, .easeOut)

    static func state(at time: SceneTime) -> State {
        State(optionDown: option.value(at: time), vDown: v.value(at: time), journal: journal.value(at: time))
    }

    /// The journal is shown at this share of its real size: as large as the window holding it.
    static let miniatureScale: CGFloat = 0.3

    // MARK: Geometry, in canvas coordinates

    /// The other app's window with the document text, in the middle of the canvas.
    static let window = CGRect(x: (size.width - 312) / 2, y: 6, width: 312, height: 150)
    /// SceneWindow draws a 24 pt title bar above its content.
    private static let titleBar: CGFloat = 24
    private static let textInset = CGSize(width: 14, height: 12)
    /// Grey lines of the document; the caret stands at the end of the second one.
    private static let lines: [CGFloat] = [190, 64, 168, 212, 140]
    private static let lineHeight: CGFloat = 6
    private static let lineSpacing: CGFloat = 9
    private static let caretLine = 1
    private static let caretHeight: CGFloat = 13

    /// The insertion point: at the end of its line, centred on it.
    static let caret = CGRect(
        x: window.minX + textInset.width + lines[caretLine] + 4,
        y: window.minY + titleBar + textInset.height
            + CGFloat(caretLine) * (lineHeight + lineSpacing) + lineHeight / 2 - caretHeight / 2,
        width: 1.5,
        height: caretHeight
    )

    /// The journal opens over the window, in the middle of it.
    static let journalFrame: CGRect = {
        let size = CGSize(
            width: JournalView.Layout.width * miniatureScale,
            height: JournalView.Layout.height * miniatureScale
        )
        return CGRect(
            x: window.midX - size.width / 2,
            y: window.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }()

    /// The keys sit under the window, side by side and centred on it.
    static let keySize: CGFloat = 60
    private static let keyGap: CGFloat = 8
    private static let keysTop = window.maxY + 16
    private static let keysLeft = window.midX - keySize - keyGap / 2

    /// Where the two keys are drawn, for the tests.
    static var keyFrames: [CGRect] {
        [0, 1].map { index in
            CGRect(
                x: keysLeft + CGFloat(index) * (keySize + keyGap),
                y: keysTop,
                width: keySize,
                height: keySize
            )
        }
    }

    let time: SceneTime

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.l10n) private var l10n

    var body: some View {
        let state = Self.state(at: time)
        let palette = ThemePalette.scene(colorScheme)

        ZStack(alignment: .topLeading) {
            SceneKeycap(label: "⌥", caption: "option", size: Self.keySize, pressed: state.optionDown)
                .offset(x: Self.keysLeft, y: Self.keysTop)
            // On a Russian keyboard V also carries "М"; the shortcut works by key, in any layout.
            SceneKeycap(label: "V", secondary: l10n.language == .russian ? "М" : nil, size: Self.keySize, pressed: state.vDown)
                .offset(x: Self.keysLeft + Self.keySize + Self.keyGap, y: Self.keysTop)

            SceneWindow(title: l10n("Document", "Документ"), palette: palette) {
                VStack(alignment: .leading, spacing: Self.lineSpacing) {
                    ForEach(Array(Self.lines.enumerated()), id: \.offset) { _, width in
                        SceneTextLine(width: width, palette: palette)
                    }
                }
                .padding(.leading, Self.textInset.width)
                .padding(.top, Self.textInset.height)
            }
            .frame(width: Self.window.width, height: Self.window.height)
            .offset(x: Self.window.minX, y: Self.window.minY)

            // Drawn over the window at the canvas's own coordinates, like the journal above it.
            SceneCaret(height: Self.caret.height, visible: SceneCaret.isVisible(at: time, duration: Self.duration))
                .offset(x: Self.caret.minX, y: Self.caret.minY)

            JournalMiniature(palette: palette)
                .scaleEffect(Self.miniatureScale)
                .frame(width: Self.journalFrame.width, height: Self.journalFrame.height)
                .shadow(color: palette.shadow(0.3), radius: 14, y: 8)
                .scaleEffect(0.96 + 0.04 * state.journal)
                .opacity(state.journal)
                .offset(x: Self.journalFrame.minX, y: Self.journalFrame.minY)
        }
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
    }
}

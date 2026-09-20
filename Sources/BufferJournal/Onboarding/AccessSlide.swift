import AppKit
import SwiftUI

/// Texts of the ДОСТУП slide, word for word from the access screen it replaces.
enum AccessSlide {
    /// The title reads "Stash needs Accessibility access"; "Stash" is drawn in the icon's orange.
    static func titleTail(_ l10n: L10n) -> String {
        l10n(" needs Accessibility access", " нужен Универсальный доступ")
    }

    static func line(_ l10n: L10n) -> String {
        l10n(
            "Stash pastes a clip by simulating a ⌘V key press. macOS won't allow that without Accessibility access.",
            "Stash вставляет клип, имитируя нажатия клавиш ⌘V. Без Универсального доступа macOS этого не разрешит."
        )
    }

    static func hint(_ l10n: L10n) -> String {
        l10n(
            "Stash is already in the list and switched on, but you still see this screen? Try removing it from the list of apps with “−” and clicking Open Settings again.",
            "Stash уже в списке и включён, а вы всё ещё видите этот экран? Попробуйте удалить его из списка приложений кнопкой «−» и снова нажать «Открыть настройки»."
        )
    }

    static func buttonTitle(_ l10n: L10n) -> String {
        l10n("Open Settings", "Открыть настройки")
    }

}

/// Under the card in both views of the slide: the title with the app icon, the ⌘V line and the
/// footnote about a stale entry in the Accessibility list.
struct AccessPrompt: View {
    let palette: ThemePalette
    let l10n: L10n

    /// The app icon before "Stash" keeps the proportions of the journal header's logo (icon 32 : font 28).
    private enum Title {
        static let fontSize: CGFloat = 18
        static let iconFrame: CGFloat = 21
        static let capHeight = NSFont.systemFont(ofSize: fontSize, weight: .semibold).capHeight
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 2) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: Title.iconFrame, height: Title.iconFrame)
                    .accessibilityHidden(true)

                (Text("Stash").foregroundColor(palette.accentText)
                    + Text(AccessSlide.titleTail(l10n)))
                    .font(.system(size: Title.fontSize, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)
                    // Center on the capitals, not on the line box, so the icon lines up with "S".
                    .alignmentGuide(VerticalAlignment.center) { $0[.firstTextBaseline] - Title.capHeight / 2 }
                    .accessibilityAddTraits(.isHeader)
            }

            Text(AccessSlide.line(l10n))
                .font(.system(size: 13))
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)

            // A side note: left-aligned under a grey bar, like a footnote. On the access screen the
            // button stood between the two; here it sits in the card, so the note comes closer.
            HStack(alignment: .top, spacing: 10) {
                Capsule()
                    .fill(palette.iconOpacity(0.22))
                    .frame(width: 3)

                Text(AccessSlide.hint(l10n))
                    .font(.system(size: 11))
                    .foregroundStyle(palette.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            // The bar takes the height of the text.
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

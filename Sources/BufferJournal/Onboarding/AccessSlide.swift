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
            "Stash pastes by pressing ⌘V for you. macOS won't allow it without Accessibility access.",
            "Stash вставляет клип, нажимая ⌘V за вас. Без Универсального доступа macOS этого не разрешит."
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

    static func grantedTitle(_ l10n: L10n) -> String {
        l10n("Access granted", "Доступ включён")
    }

    /// In the tutorial the card carries the button; alone, the main button at the bottom asks.
    static func showsCardButton(isAccessOnly: Bool) -> Bool {
        !isAccessOnly
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

/// The one thing inside a card that can be pressed: it asks for access and opens System Settings.
/// Once access is granted it dissolves into a note and the scene holds its stop frame.
struct AccessRequestButton: View {
    let hasAccess: Bool
    let palette: ThemePalette
    let l10n: L10n

    /// The frame hands down the same action its own button runs (Task 9).
    @Environment(\.onboardingOpenSettings) private var openSettings

    var body: some View {
        ZStack {
            if hasAccess {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ThemePalette.orange)
                    Text(AccessSlide.grantedTitle(l10n))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.textPrimary)
                }
                .frame(height: 32)
                .transition(.opacity)
            } else {
                Button {
                    openSettings()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "accessibility")
                            .font(.system(size: 15, weight: .semibold))
                        Text(AccessSlide.buttonTitle(l10n))
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 32)
                }
                .buttonStyle(TranslucentButtonStyle(tone: .accent, cornerRadius: 8))
                .transition(.opacity)
            }
        }
        // Inside a card everything keeps the Stash look, whatever theme is picked.
        .environment(\.solidAccents, true)
        .animation(.easeOut(duration: 0.2), value: hasAccess)
    }
}

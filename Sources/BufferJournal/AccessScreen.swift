import SwiftUI

/// Shown in the panel instead of the journal while Stash has no Accessibility access: pasting
/// presses ⌘V for the user, and macOS allows that only with access.
struct AccessScreen: View {
    let palette: ThemePalette
    let onOpenSettings: () -> Void
    let onClose: () -> Void

    @Environment(\.l10n) private var l10n

    /// The app icon before "Stash" keeps the proportions of the journal header's logo (icon 32 : font 28).
    private enum Title {
        static let fontSize: CGFloat = 18
        static let iconFrame: CGFloat = 21
        static let capHeight = NSFont.systemFont(ofSize: fontSize, weight: .semibold).capHeight
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                GlassIconButton(systemName: "xmark", help: l10n("Close", "Закрыть"), action: onClose)
            }
            .padding(.top, 10)
            .padding(.trailing, 10)

            Spacer(minLength: 0)

            VStack(spacing: 0) {
                HStack(spacing: 2) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: Title.iconFrame, height: Title.iconFrame)
                        .accessibilityHidden(true)

                    (Text("Stash").foregroundColor(palette.accentText)
                        + Text(l10n(" needs Accessibility access", " нужен Универсальный доступ")))
                        .font(.system(size: Title.fontSize, weight: .semibold))
                        .foregroundStyle(palette.textPrimary)
                        .multilineTextAlignment(.center)
                        // Center on the capitals, not on the line box, so the icon lines up with "S".
                        .alignmentGuide(VerticalAlignment.center) { $0[.firstTextBaseline] - Title.capHeight / 2 }
                        .accessibilityAddTraits(.isHeader)
                }

                Text(l10n(
                    "Stash pastes by pressing ⌘V for you. macOS won't allow it without Accessibility access.",
                    "Stash вставляет клип, нажимая ⌘V за вас. Без Универсального доступа macOS этого не разрешит."
                ))
                .font(.system(size: 13))
                .foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)

                Button(action: onOpenSettings) {
                    HStack(spacing: 6) {
                        Image(systemName: "accessibility")
                            .font(.system(size: 15, weight: .semibold))
                        Text(l10n("Open Settings", "Открыть настройки"))
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 32)
                }
                .buttonStyle(TranslucentButtonStyle(tone: .accent, cornerRadius: 8))
                .padding(.top, 16)

                // A side note: left-aligned under a grey bar, like a footnote to the button above.
                HStack(alignment: .top, spacing: 10) {
                    Capsule()
                        .fill(palette.iconOpacity(0.22))
                        .frame(width: 3)

                    Text(l10n(
                        "Stash is already in the list and switched on, but you still see this screen? Try removing it from the list of apps with “−” and clicking Open Settings again.",
                        "Stash уже в списке и включён, а вы всё ещё видите этот экран? Попробуйте удалить его из списка приложений кнопкой «−» и снова нажать «Открыть настройки»."
                    ))
                    .font(.system(size: 11))
                    .foregroundStyle(palette.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                // The bar takes the height of the text.
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)
            }
            .frame(maxWidth: 360)
            .padding(.horizontal, 24)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // The empty area moves the window, like the journal's header.
        .background(WindowDragHandle())
        .background(palette.sidebarTint)
    }
}

import SwiftUI

/// Shown in the panel instead of the journal while Stash has no Accessibility access: pasting
/// presses ⌘V for the user, and macOS allows that only with access.
struct AccessScreen: View {
    let palette: ThemePalette
    let onOpenSettings: () -> Void
    let onClose: () -> Void

    @Environment(\.l10n) private var l10n

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
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(palette.accentFill)
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: "accessibility")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(palette.onAccent)
                    }
                    .accessibilityHidden(true)

                Text(l10n("Stash needs Accessibility access", "Stash нужен Универсальный доступ"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, 14)

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
                    Text(l10n("Open Settings", "Открыть настройки"))
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 16)
                        .frame(height: 32)
                }
                .buttonStyle(TranslucentButtonStyle(tone: .accent, cornerRadius: 8))
                .padding(.top, 16)

                Text(l10n(
                    "Stash is already in the list and switched on, but this screen stays? After an update macOS treats Stash as a new app. Remove it from the list with “−” and click Open Settings again.",
                    "Stash уже в списке и включён, а экран не уходит? После обновления macOS считает Stash новым приложением. Удалите его из списка кнопкой «−» и снова нажмите «Открыть настройки»."
                ))
                .font(.system(size: 11))
                .foregroundStyle(palette.textTertiary)
                .multilineTextAlignment(.center)
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

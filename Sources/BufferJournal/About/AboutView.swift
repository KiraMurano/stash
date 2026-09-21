import AppKit
import SwiftUI

/// The About screen, in a window of its own that hangs from the status item. Its head is the
/// update screen's, to the pixel; the middle is bare field with the studio's wordmark on it. The
/// footer is one link and no button: the screen has no main action and no longer pretends to
/// (`.concepts/2026-09-21-separate-windows-round1.html`, variant 4.2 without the button).
struct AboutView: View {
    @ObservedObject var controller: AboutController
    let l10n: L10n
    /// Closes the window. The screen holds no state about being on screen; the window does.
    let onClose: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private enum Metrics {
        static let top: CGFloat = 12
        static let side: CGFloat = 20
        static let bottom: CGFloat = 16
        static let gap: CGFloat = 10
        static let headHeight: CGFloat = 28
        static let buttonHeight: CGFloat = 36
        static let textSize: CGFloat = 13
        static let titleSize: CGFloat = 18
        static let iconFrame: CGFloat = 21
        /// The window is 400 pt wide, so the column under the wordmark is 360: the widest
        /// setting at 56 pt needs 384 and would not fit.
        static let wordmarkSize: CGFloat = 38
        /// Between "Made in" and the wordmark under it.
        static let madeInGap: CGFloat = 12
    }

    private var colors: OnboardingColors {
        OnboardingColors(isDark: colorScheme == .dark)
    }

    /// Everything on the screen is drawn in the Stash style, whatever theme is picked.
    private var palette: ThemePalette {
        ThemePalette(colorScheme: colorScheme, solid: true)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            colors.field

            // Insets belong to each piece, as on the update screen: the window itself holds none.
            VStack(spacing: Metrics.gap) {
                head
                    .padding(.top, Metrics.top)
                    .padding(.horizontal, Metrics.side)

                studio
                    .padding(.horizontal, Metrics.side)

                footer
                    .padding(.horizontal, Metrics.side)
                    .padding(.bottom, Metrics.bottom)
            }
        }
        .environment(\.solidAccents, true)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(l10n("About Stash", "О приложении Stash"))
        .accessibilityAddTraits(.isModal)
    }

    // MARK: Head

    private var head: some View {
        HStack(spacing: 12) {
            lockup
            Spacer(minLength: 0)
            closeButton
        }
        .frame(height: Metrics.headHeight)
    }

    private var lockup: some View {
        let capHeight = NSFont.systemFont(ofSize: Metrics.titleSize, weight: .semibold).capHeight
        let version = controller.currentVersion.map { " \($0)" } ?? ""

        return HStack(spacing: 2) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: Metrics.iconFrame, height: Metrics.iconFrame)
                .accessibilityHidden(true)

            (Text("Stash").foregroundColor(palette.accentText) + Text(version))
                .font(.system(size: Metrics.titleSize, weight: .semibold))
                .foregroundStyle(palette.textPrimary)
                .alignmentGuide(VerticalAlignment.center) { $0[.firstTextBaseline] - capHeight / 2 }
                .accessibilityAddTraits(.isHeader)
        }
    }

    /// The journal's own close button, so every window of Stash closes with the same one.
    private var closeButton: some View {
        GlassIconButton(systemName: "xmark", help: l10n("Close", "Закрыть"), action: onClose)
    }

    // MARK: Middle

    private var studio: some View {
        VStack(spacing: Metrics.madeInGap) {
            Text(l10n.aboutMadeIn)
                .font(.system(size: Metrics.textSize))
                .foregroundStyle(palette.textSecondary)

            Wordmark(size: Metrics.wordmarkSize, color: palette.textPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Footer

    private var footer: some View {
        Button {
            controller.openRepository()
        } label: {
            Text(Self.repositoryLabel)
                .font(.system(size: Metrics.textSize))
                .foregroundStyle(palette.textSecondary)
                .underline(true, color: palette.textTertiary)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, minHeight: Metrics.buttonHeight)
    }

    /// The address without its scheme: "github.com/KiraMurano/stash" reads as a place, while
    /// "https://" only takes room.
    private static var repositoryLabel: String {
        let url = AboutController.repository
        return (url.host ?? "") + url.path
    }
}

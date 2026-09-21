import AppKit
import SwiftUI

/// The About screen over the journal panel. Its head and footer are the update screen's, to the
/// pixel; the middle is bare field, as on an update check that found nothing — one thing, the
/// one the screen was opened for, standing on the window's own background (concept 1.2).
struct AboutView: View {
    @ObservedObject var controller: AboutController
    let l10n: L10n

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
        /// The wordmark: 56 pt takes 384 pt of the 600 pt column at its widest setting, so it
        /// still fits the smallest panel (concept round 1).
        static let wordmarkSize: CGFloat = 56
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

            VStack(spacing: 0) {
                head
                studio
                footer
                    .padding(.top, Metrics.gap)
            }
            .padding(.top, Metrics.top)
            .padding(.horizontal, Metrics.side)
            .padding(.bottom, Metrics.bottom)
        }
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
        // The head row moves the panel, like the journal's header and the update screen's.
        .background(WindowDragHandle())
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

    private var closeButton: some View {
        Button {
            controller.close()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(OnboardingCloseButtonStyle(color: colors.close))
        .help(l10n("Close", "Закрыть"))
        .accessibilityLabel(l10n("Close", "Закрыть"))
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
        HStack(alignment: .center, spacing: 16) {
            Button {
                controller.openRepository()
            } label: {
                Text(Self.repositoryLabel)
                    .font(.system(size: Metrics.textSize))
                    .foregroundStyle(palette.textSecondary)
                    .underline(true, color: palette.textTertiary)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                controller.openFeedback()
            } label: {
                Text(l10n.aboutFeedback)
                    .font(.system(size: Metrics.textSize, weight: .semibold))
                    .padding(.horizontal, 16)
                    .frame(minWidth: 150, minHeight: Metrics.buttonHeight, maxHeight: Metrics.buttonHeight)
            }
            .buttonStyle(OnboardingPrimaryButtonStyle(colors: colors))
        }
    }

    /// The address without its scheme: "github.com/KiraMurano/stash" reads as a place, while
    /// "https://" only takes room.
    private static var repositoryLabel: String {
        let url = AboutController.repository
        return (url.host ?? "") + url.path
    }
}

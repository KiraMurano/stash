import AppKit
import SwiftUI

/// The update screen over the journal panel. It is built like the tutorial — same field, same
/// card, same orange button — with the version in the head row, the release notes in the card
/// and only the actions at the bottom (concept round 1, variant 1.2).
struct UpdateView: View {
    @ObservedObject var controller: UpdateController
    let l10n: L10n
    /// Off only for the snapshots: ImageRenderer draws a ScrollView as an empty box, and a
    /// snapshot of an empty card says nothing about the screen.
    var scrolls = true

    @Environment(\.colorScheme) private var colorScheme

    /// The tutorial's metrics, so the two screens line up to the pixel.
    private enum Metrics {
        static let top: CGFloat = 12
        static let side: CGFloat = 20
        static let bottom: CGFloat = 16
        static let gap: CGFloat = 10
        static let headHeight: CGFloat = 28
        static let cardRadius: CGFloat = 20
        static let buttonHeight: CGFloat = 36
        static let progressWidth: CGFloat = 220
        static let textSize: CGFloat = 13
        /// The lone answer on the field carries the screen, so it is larger than body text.
        static let answerSize: CGFloat = 17
        static let notesPadding: CGFloat = 18
        static let notesSpacing: CGFloat = 8
        /// The marker's column and the 12×3 bar inside it (concept round 3, variant 1.2.1.2).
        static let markColumn: CGFloat = 14
        static let markWidth: CGFloat = 12
        static let markHeight: CGFloat = 3
        /// One line of 13 pt text at line height 1.4.
        static let lineHeight: CGFloat = 18
        /// The title lockup, as on the access slide: a 21 pt icon before 18 pt semibold.
        static let titleSize: CGFloat = 18
        static let iconFrame: CGFloat = 21
    }

    private var colors: OnboardingColors {
        OnboardingColors(isDark: colorScheme == .dark)
    }

    /// Everything inside the card is drawn in the Stash style, whatever theme is picked.
    private var palette: ThemePalette {
        ThemePalette(colorScheme: colorScheme, solid: true)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            colors.field

            VStack(spacing: 0) {
                head
                // The card is there to hold the release notes. Without them — while the check
                // runs, when there is nothing new, when the check failed — it would be a large
                // empty box around one line, so the answer stands on the field instead.
                if controller.release != nil {
                    card
                        .padding(.top, Metrics.gap)
                } else {
                    answer
                        .padding(.top, Metrics.gap)
                }
                footer
                    .padding(.top, Metrics.gap)
            }
            .padding(.top, Metrics.top)
            .padding(.horizontal, Metrics.side)
            .padding(.bottom, Metrics.bottom)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(l10n("Stash update", "Обновление Stash"))
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
        // The head row moves the panel, like the journal's header and the tutorial's bars.
        .background(WindowDragHandle())
    }

    private var lockup: some View {
        let capHeight = NSFont.systemFont(ofSize: Metrics.titleSize, weight: .semibold).capHeight
        // Without a release the head names the version that is installed.
        let shown = controller.release?.version ?? controller.currentVersion
        let version = shown.map { " \($0)" } ?? ""

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

    // MARK: Card

    private var card: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)

        return shape
            .fill(palette.windowBackground)
            .overlay(shape.fill(palette.sidebarTint))
            .overlay(shape.strokeBorder(palette.border, lineWidth: 1))
            .shadow(color: colors.cardShadow, radius: 16, y: 6)
            .overlay(notes.clipShape(shape))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// The answer to a check that brought no release: "checking", "nothing new" or what failed.
    private var answer: some View {
        Text(message)
            .font(.system(size: Metrics.answerSize))
            .foregroundStyle(palette.textPrimary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Metrics.side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var message: String {
        switch controller.state {
        case .checking: l10n.updateChecking
        case .failed(let error): l10n.updateFailure(error)
        default: l10n.updateUpToDate
        }
    }

    private var notes: some View {
        scrollIfNeeded {
            VStack(alignment: .leading, spacing: Metrics.notesSpacing) {
                ForEach(ReleaseNotes.parse(controller.release?.notes ?? "")) { note in
                    switch note.kind {
                    case .item: item(note.text)
                    case .paragraph: paragraph(note.text)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Metrics.notesPadding)
        }
    }

    @ViewBuilder
    private func scrollIfNeeded<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        if scrolls {
            ScrollView { content() }
        } else {
            content().frame(maxHeight: .infinity, alignment: .top)
        }
    }

    private func item(_ text: String) -> some View {
        HStack(alignment: .top, spacing: Metrics.notesSpacing) {
            Capsule()
                .fill(ThemePalette.orange)
                .frame(width: Metrics.markWidth, height: Metrics.markHeight)
                .frame(width: Metrics.markColumn, height: Metrics.lineHeight, alignment: .leading)
                .accessibilityHidden(true)

            Text(Self.markdown(text))
                .font(.system(size: Metrics.textSize))
                .foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func paragraph(_ text: String) -> some View {
        Text(Self.markdown(text))
            .font(.system(size: Metrics.textSize, weight: .semibold))
            .foregroundStyle(palette.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
    }

    /// Bold, italics and links inside a line; the list itself was cut by ReleaseNotes.
    private static func markdown(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text)) ?? AttributedString(text)
    }

    // MARK: Footer

    private var footer: some View {
        HStack(alignment: .center, spacing: 16) {
            meta
            actions
        }
    }

    private var meta: some View {
        Text(current)
            .font(.system(size: Metrics.textSize))
            .foregroundStyle(palette.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Only a release has a size and a version to compare against; without one the head already
    /// names the installed version, and repeating it in the footer says nothing.
    private var current: String {
        guard let version = controller.currentVersion, let release = controller.release else { return "" }
        return l10n.updateCurrent(version.description, bytes: release.size)
    }

    @ViewBuilder
    private var actions: some View {
        switch controller.state {
        case .downloading(let progress):
            bar(l10n.updateDownloading(progress), fill: progress)
        case .installing:
            bar(l10n.updateInstalling, fill: 1)
        case .failed:
            primary(l10n.updateOpenReleases) { controller.openReleasesPage() }
        case .available:
            // The style paints its hover tint straight behind the label, so the padding and the
            // height belong to the label. Outside the style they push the button around and leave
            // the tint clinging to the word.
            Button {
                controller.close()
            } label: {
                Text(l10n.updateLater)
                    .font(.system(size: Metrics.textSize, weight: .semibold))
                    .padding(.horizontal, 12)
                    .frame(height: Metrics.buttonHeight)
            }
            .buttonStyle(OnboardingCloseButtonStyle(color: colors.close))

            primary(l10n.updateNow) { controller.install() }
        default:
            // Checking, and nothing new: there is nothing to do but close the screen.
            primary(l10n.updateClose) { controller.close() }
        }
    }

    /// The unfilled part of the bar: a tint of the same orange. The Stash themes paint their
    /// accents solid, so `palette.segmentThumb` would give the fill's own colour and hide it.
    private var progressTrack: Color {
        ThemePalette.orange.opacity(colorScheme == .dark ? 0.28 : 0.18)
    }

    private func primary(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: Metrics.textSize, weight: .semibold))
                .padding(.horizontal, 16)
                .frame(minWidth: 150, minHeight: Metrics.buttonHeight, maxHeight: Metrics.buttonHeight)
        }
        .buttonStyle(OnboardingPrimaryButtonStyle(colors: colors))
    }

    /// The label sits in the middle of the bar, so part of it lies on the orange fill and part on
    /// the track. White would vanish on the track, so it is the ordinary text colour: it reads on
    /// the pale track and on the orange alike, in both themes.
    private func bar(_ title: String, fill: Double) -> some View {
        let shape = Capsule()

        return shape
            .fill(progressTrack)
            .overlay(alignment: .leading) {
                shape
                    .fill(ThemePalette.orange)
                    .frame(width: Metrics.progressWidth * min(max(fill, 0), 1))
            }
            .clipShape(shape)
            .overlay {
                Text(title)
                    .font(.system(size: Metrics.textSize, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)
            }
            .frame(width: Metrics.progressWidth, height: Metrics.buttonHeight)
            .accessibilityLabel(title)
    }
}

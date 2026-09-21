import AppKit
import SwiftUI

/// The update screen, in a window of its own that hangs from the status item. The release notes
/// stand on the bare field — the window is the card now — the download runs as a 3 pt line above
/// the footer, and the footer carries nothing but the actions
/// (`.concepts/2026-09-21-separate-windows.html`, variants 1.1, 2.1, 1.1.1).
struct UpdateView: View {
    @ObservedObject var controller: UpdateController
    let l10n: L10n
    /// Closes the window. The screen holds no state about being on screen; the window does.
    let onClose: () -> Void
    /// Off only for the snapshots: ImageRenderer draws a ScrollView as an empty box, and a
    /// snapshot of an empty list says nothing about the screen.
    var scrolls = true

    @Environment(\.colorScheme) private var colorScheme

    @State private var notesEdges = ScrollEdges()

    /// The tutorial's metrics, so the two screens line up to the pixel.
    private enum Metrics {
        static let top: CGFloat = 12
        static let side: CGFloat = 20
        static let bottom: CGFloat = 16
        static let gap: CGFloat = 10
        static let headHeight: CGFloat = 28
        static let buttonHeight: CGFloat = 36
        static let textSize: CGFloat = 13
        /// The lone answer on the field carries the screen, so it is larger than body text.
        static let answerSize: CGFloat = 17
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
        /// The download line above the footer.
        static let bar: CGFloat = 3
        /// The lane the scroller gets on the right, so it never lies on the text.
        static let scrollerLane: CGFloat = 6
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

            // Every piece carries its own insets. A window-wide inset would have to be undone
            // by whatever runs edge to edge — the list and the download line — and a negative
            // inset clips the shadows and the scroller of what it is undone for.
            VStack(spacing: Metrics.gap) {
                head
                    .padding(.top, Metrics.top)
                    .padding(.horizontal, Metrics.side)

                // The notes stand on the field: the window's own edge does what the card did.
                // Without a release — while the check runs, when there is nothing new, when the
                // check failed — one line stands there instead.
                if controller.release != nil {
                    notes
                } else {
                    answer
                }

                if let fill = progressFill {
                    progressBar(fill)
                }

                footer
                    .padding(.horizontal, Metrics.side)
                    .padding(.bottom, Metrics.bottom)
            }
        }
        .environment(\.solidAccents, true)
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

    /// The journal's own close button, so every window of Stash closes with the same one.
    private var closeButton: some View {
        GlassIconButton(systemName: "xmark", help: l10n("Close", "Закрыть"), action: onClose)
    }

    // MARK: Middle

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

    /// The window takes the height the list asks for, so this scrolls only when the list is
    /// longer than the screen. The list runs edge to edge and keeps its insets inside, so the
    /// scroller gets a lane of its own on the right instead of lying on the words — the journal's
    /// preview pane is built the same way.
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
            .padding(.leading, Metrics.side)
            .padding(.trailing, Metrics.side + Metrics.scrollerLane)
        }
        // An edge with more behind it gets a shadow, as in the journal.
        .overlay(alignment: .top) {
            EdgeShadow(palette: palette, edge: .top)
                .opacity(notesEdges.isScrolled ? 1 : 0)
        }
        .overlay(alignment: .bottom) {
            EdgeShadow(palette: palette, edge: .bottom)
                .opacity(notesEdges.hasMoreBelow ? 1 : 0)
        }
        .animation(.easeOut(duration: 0.15), value: notesEdges)
    }

    @ViewBuilder
    private func scrollIfNeeded<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        if scrolls {
            ScrollView {
                content().background(ScrollBarAppearanceSetter(colorScheme: colorScheme))
            }
            .background(ScrollOffsetObserver { notesEdges = $0 })
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

    // MARK: Progress

    /// How far the bar is filled, or nil when nothing is being downloaded or installed.
    private var progressFill: Double? {
        switch controller.state {
        case .downloading(let progress): min(max(progress, 0), 1)
        case .installing: 1
        default: nil
        }
    }

    /// A 3 pt line across the whole window, where the bottom of the card used to be. The side
    /// padding is undone so it runs edge to edge; the percentage is said in words in the footer.
    private func progressBar(_ fill: Double) -> some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(progressTrack)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(ThemePalette.orange)
                        .frame(width: geometry.size.width * fill)
                }
        }
        .frame(height: Metrics.bar)
        .accessibilityHidden(true)
    }

    /// The unfilled part of the bar: a tint of the same orange. The Stash themes paint their
    /// accents solid, so `palette.segmentThumb` would give the fill's own colour and hide it.
    private var progressTrack: Color {
        ThemePalette.orange.opacity(colorScheme == .dark ? 0.28 : 0.18)
    }

    // MARK: Footer

    private var footer: some View {
        HStack(alignment: .center, spacing: 16) {
            // The left of the footer is used only while something is happening. "Now 1.26 ·
            // 4.2 MB" used to stand here and broke into three lines at 400 pt; the head already
            // names the version, and the weight of the image said nothing anyone acts on
            // (concept round 2, variant 1.1.1).
            if let status = statusLine {
                Text(status)
                    .font(.system(size: Metrics.textSize))
                    .foregroundStyle(palette.textSecondary)
            }
            Spacer(minLength: 0)
            actions
        }
        .frame(minHeight: Metrics.buttonHeight)
    }

    private var statusLine: String? {
        switch controller.state {
        case .downloading(let progress): l10n.updateDownloading(progress)
        case .installing: l10n.updateInstalling
        default: nil
        }
    }

    @ViewBuilder
    private var actions: some View {
        switch controller.state {
        case .downloading, .installing:
            // The line above says what is happening; there is nothing to press.
            EmptyView()
        case .failed:
            primary(l10n.updateOpenReleases) { controller.openReleasesPage() }
        case .available:
            // The style paints its hover tint straight behind the label, so the padding and the
            // height belong to the label. Outside the style they push the button around and leave
            // the tint clinging to the word.
            Button(action: onClose) {
                Text(l10n.updateLater)
                    .font(.system(size: Metrics.textSize, weight: .semibold))
                    .padding(.horizontal, 16)
                    .frame(minWidth: 100, minHeight: Metrics.buttonHeight, maxHeight: Metrics.buttonHeight)
            }
            .buttonStyle(TranslucentButtonStyle(tone: .neutral, cornerRadius: OnboardingPrimaryButtonStyle.cornerRadius))

            primary(l10n.updateNow) { controller.install() }
        default:
            // Checking, and nothing new: there is nothing to do but close the window.
            primary(l10n.updateClose, action: onClose)
        }
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
}

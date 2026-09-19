import AppKit
import SwiftUI

/// The tutorial: stories over the whole journal panel. Progress bars and the close cross on top,
/// the first slide's big title under them, the scene in a card that hugs it, and the text beside
/// the main button at the bottom. The same view shows the access slide on its own, without the
/// bars and with "Open Settings" as its main button.
struct OnboardingView: View {
    @ObservedObject var controller: OnboardingController
    /// Watched so the access slide goes to its stop frame the moment access is granted.
    @ObservedObject var access: AccessGate
    let l10n: L10n
    /// Asks for access, opens System Settings and lowers the panel (`JournalPanelController`).
    let onOpenSettings: () -> Void
    /// Closes the panel: the single access screen has no journal to fall back to.
    let onClosePanel: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Metrics {
        static let top: CGFloat = 12
        static let side: CGFloat = 20
        static let bottom: CGFloat = 16
        static let gap: CGFloat = 10
        /// The bars share a row with the 28 pt close cross.
        static let headHeight: CGFloat = 28
        static let bar: CGFloat = 3
        static let cardRadius: CGFloat = 20
        static let buttonWidth: CGFloat = 150
        static let buttonHeight: CGFloat = 36
        static let textSize: CGFloat = 13
        /// Line height 1.4 of the 13 pt system font, whose own line is about 1.19 of its size.
        static let lineSpacing: CGFloat = 2.7
        /// Share of the panel width the "back" zone takes.
        static let backZone: CGFloat = 0.3
    }

    private var colors: OnboardingColors {
        OnboardingColors(isDark: colorScheme == .dark)
    }

    /// Everything inside the card is drawn in the Stash style, whatever theme is picked.
    private var palette: ThemePalette {
        ThemePalette(colorScheme: colorScheme, solid: true)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                colors.field

                if !controller.isAccessOnly {
                    zones(width: geometry.size.width, top: Metrics.top + Metrics.headHeight)
                }

                VStack(spacing: 0) {
                    head
                    if controller.slide.kind == .hero {
                        title(rowWidth: geometry.size.width - 2 * Metrics.side, panelHeight: geometry.size.height)
                            .padding(.top, Metrics.gap)
                            .transition(.opacity)
                    }
                    stage
                        .padding(.top, Metrics.gap)
                    footer
                        .padding(.top, Metrics.gap)
                }
                .animation(reduceMotion ? nil : .easeOut(duration: 0.26), value: controller.slide.kind == .hero)
                .padding(.top, Metrics.top)
                .padding(.horizontal, Metrics.side)
                .padding(.bottom, Metrics.bottom)
            }
        }
        .environment(\.onboardingOpenSettings, onOpenSettings)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(controller.isAccessOnly
            ? l10n("Stash needs Accessibility access", "Stash нужен Универсальный доступ")
            : l10n("Stash tour", "Знакомство со Stash"))
        .accessibilityAddTraits(.isModal)
        .onChange(of: controller.index) { index in
            announce(index)
        }
    }

    // MARK: Head

    private var head: some View {
        HStack(spacing: 12) {
            // Nothing to page through on the single access screen, so it shows no bars.
            if controller.isAccessOnly {
                Spacer(minLength: 0)
            } else {
                bars
            }
            closeButton
        }
        .frame(height: Metrics.headHeight)
        // The bars' row moves the panel, like the journal's header.
        .background(WindowDragHandle())
    }

    private var bars: some View {
        HStack(spacing: 4) {
            ForEach(Array(controller.slides.enumerated()), id: \.element.id) { offset, slide in
                OnboardingProgressBar(phase: phase(of: offset), colors: colors, animated: !reduceMotion)
                    // A new identity each time the slide is entered refills the current bar.
                    .id(offset == controller.index ? "\(slide.kind.rawValue)-\(controller.run)" : slide.kind.rawValue)
            }
        }
        .frame(height: Metrics.bar)
    }

    private func phase(of offset: Int) -> OnboardingProgressBar.Phase {
        if offset < controller.index { return .done }
        return offset == controller.index ? .current : .upcoming
    }

    /// Closes the tutorial and leaves the journal under it; on the single access screen there is
    /// no journal to show, so it closes the panel.
    private var closeButton: some View {
        Button {
            if controller.isAccessOnly {
                onClosePanel()
            } else {
                controller.close()
            }
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(OnboardingCloseButtonStyle(color: colors.close))
        .help(l10n("Close", "Закрыть"))
        .accessibilityLabel(l10n("Close", "Закрыть"))
    }

    /// "HELLO, THIS IS" on the first slide: big, orange, in the top left corner, as the slides'
    /// words once were, and no taller than 10 % of the panel.
    private func title(rowWidth: CGFloat, panelHeight: CGFloat) -> some View {
        let text = controller.slide.word(l10n)
        let size = OnboardingLayout.titleFontSize(
            widthAt100: HeavyTextMetrics.width(text, size: 100, tracking: -2),
            rowWidth: rowWidth,
            panelHeight: panelHeight
        )
        let height = (size * 0.95).rounded()
        return Text(text)
            .font(.system(size: size, weight: .heavy))
            .tracking(-0.02 * size)
            .foregroundStyle(colors.title)
            .lineLimit(1)
            .fixedSize()
            .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .leading)
            // The card's heading already says it to VoiceOver.
            .accessibilityHidden(true)
    }

    // MARK: Stage

    /// The room between the bars and the text. The card hugs the slide's scene and sits in the
    /// middle; between slides it grows or shrinks to the next scene.
    private var stage: some View {
        GeometryReader { geometry in
            let kind = controller.slide.kind
            let scene = OnboardingSceneView.size(of: kind)
            let card = scene.map { OnboardingLayout.cardSize(for: $0, in: geometry.size) } ?? geometry.size

            self.card(size: card, hasSurface: scene != nil)
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    private func card(size: CGSize, hasSurface: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)

        return ZStack {
            // An opaque copy of the panel: the window background under the list pane's tint.
            shape
                .fill(palette.windowBackground)
                .overlay(shape.fill(palette.sidebarTint))
                .overlay(shape.strokeBorder(palette.border, lineWidth: 1))
                .shadow(color: colors.cardShadow, radius: 16, y: 6)
                .opacity(hasSurface ? 1 : 0)
                .allowsHitTesting(false)

            // The first slide has no card, so nothing clips its flying tiles.
            OnboardingSceneView(slide: controller.slide, still: isStill)
                .clipShape(hasSurface ? AnyShape(shape) : AnyShape(Rectangle().inset(by: -200)))
                .id(controller.run)
                .transition(.opacity)

            // In the tutorial the access slide carries a real button under its scene; shown alone,
            // the slide has none and the main button at the bottom asks instead.
            if controller.slide.kind == .access, AccessSlide.showsCardButton(isAccessOnly: controller.isAccessOnly) {
                AccessRequestButton(hasAccess: access.isGranted, palette: palette, l10n: l10n)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 10)
            }
        }
        .frame(width: size.width, height: size.height)
        .animation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.86), value: controller.index)
        .animation(.easeOut(duration: 0.26), value: hasSurface)
        .animation(.easeOut(duration: 0.2), value: controller.run)
        // The slide's name, for VoiceOver: the scene itself says nothing to it.
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Self.spoken(controller.slide.word(l10n)))
        .accessibilityAddTraits(.isHeader)
    }

    private var isStill: Bool {
        reduceMotion || (controller.slide.kind == .access && access.isGranted)
    }

    // MARK: Footer

    private var footer: some View {
        HStack(alignment: .center, spacing: 16) {
            if controller.slide.kind == .access {
                // The slide's own text, with the title over it and the footnote under it.
                AccessPrompt(palette: palette, l10n: l10n)
            } else {
                texts
            }
            Button {
                if controller.isAccessOnly {
                    onOpenSettings()
                } else {
                    controller.primaryAction()
                }
            } label: {
                Text(primaryTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 16)
                    // 150 pt wide for "Next" and "Start"; "Открыть настройки" is allowed to grow.
                    .frame(minWidth: Metrics.buttonWidth, minHeight: Metrics.buttonHeight, maxHeight: Metrics.buttonHeight)
            }
            .buttonStyle(OnboardingPrimaryButtonStyle(colors: colors))
        }
    }

    private var primaryTitle: String {
        if controller.isAccessOnly {
            return l10n("Open Settings", "Открыть настройки")
        }
        return controller.isLast ? l10n("Start", "Начать") : l10n("Next", "Дальше")
    }

    /// Every slide's text lies in the same spot, the current one visible: the block is as tall
    /// as the longest text, hidden slides included, so the button never jumps.
    private var texts: some View {
        ZStack(alignment: .topLeading) {
            ForEach(OnboardingSlides.all) { slide in
                let isCurrent = slide.kind == controller.slide.kind
                Text(slide.text(l10n))
                    .font(.system(size: Metrics.textSize))
                    .lineSpacing(Metrics.lineSpacing)
                    .foregroundStyle(colors.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .opacity(isCurrent ? 1 : 0)
                    .offset(y: isCurrent || reduceMotion ? 0 : 6)
                    .accessibilityHidden(!isCurrent)
            }
        }
        .animation(.easeOut(duration: 0.26), value: controller.index)
        .allowsHitTesting(false)
    }

    // MARK: Navigation

    /// Clicks below the bars: the left 30 % of the panel goes back, the rest goes on.
    private func zones(width: CGFloat, top: CGFloat) -> some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: width * Metrics.backZone)
                .contentShape(Rectangle())
                .onTapGesture { controller.back() }
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { controller.next() }
        }
        .padding(.top, top)
        .accessibilityHidden(true)
    }

    /// "ПРИВЕТ, ЭТО" read as "Привет, это": capitals only where a sentence has them.
    static func spoken(_ word: String) -> String {
        let lower = word.lowercased()
        return lower.prefix(1).uppercased() + lower.dropFirst()
    }

    private func announce(_ index: Int) {
        // One slide on its own is not a story: nothing to count.
        guard !controller.isAccessOnly else { return }
        let count = controller.slides.count
        let message = l10n("Slide \(index + 1) of \(count)", "Слайд \(index + 1) из \(count)")
        NSAccessibility.post(
            element: NSApplication.shared,
            notification: .announcementRequested,
            userInfo: [
                .announcement: message,
                .priority: NSAccessibilityPriorityLevel.high.rawValue,
            ]
        )
    }
}

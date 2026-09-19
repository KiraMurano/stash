import SwiftUI

/// Colours of the tutorial's frame: a light grey field in light, black in dark, orange accents.
struct OnboardingColors {
    let isDark: Bool

    /// The window's own light grey, or black.
    var field: Color { isDark ? .black : ThemePalette(colorScheme: .light).windowBackground }
    var close: Color { isDark ? Color.white.opacity(0.9) : Color.black.opacity(0.8) }
    var text: Color { isDark ? Color.white.opacity(0.68) : Color.black.opacity(0.68) }
    var barFill: Color { ThemePalette.orange }
    var barTrack: Color { isDark ? Color.white.opacity(0.16) : Color.black.opacity(0.1) }
    var cardShadow: Color { isDark ? .clear : Color.black.opacity(0.1) }
    /// "Stash" on the first slide, in the icon's orange. It is a logo, so no contrast minimum applies.
    var wordmark: Color { ThemePalette.orange }
    /// The first slide's big title.
    var title: Color { ThemePalette.orange }

    /// The main button, orange in both looks; `level` is 0 at rest, 1 hovered, 2 pressed.
    func button(_ level: Int) -> Color {
        ThemePalette.darken(ThemePalette.orange, by: 0.08 * Double(min(max(level, 0), 2)))
    }
}

/// "Next" / "Start" / "Open Settings": an orange capsule that darkens on hover and press, like
/// the journal's buttons.
struct OnboardingPrimaryButtonStyle: ButtonStyle {
    let colors: OnboardingColors

    func makeBody(configuration: Configuration) -> some View {
        PrimaryBody(configuration: configuration, colors: colors)
    }

    private struct PrimaryBody: View {
        let configuration: ButtonStyleConfiguration
        let colors: OnboardingColors
        @State private var isHovered = false

        var body: some View {
            configuration.label
                .foregroundStyle(Color.white)
                .background(Capsule().fill(colors.button(configuration.isPressed ? 2 : (isHovered ? 1 : 0))))
                .contentShape(Capsule())
                .onHover { isHovered = $0 }
                .animation(.easeOut(duration: 0.12), value: isHovered)
        }
    }
}

/// The close cross: a plate of its own colour at 10 % on hover and 16 % when pressed.
struct OnboardingCloseButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        CloseBody(configuration: configuration, color: color)
    }

    private struct CloseBody: View {
        let configuration: ButtonStyleConfiguration
        let color: Color
        @State private var isHovered = false

        var body: some View {
            configuration.label
                .foregroundStyle(color)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(color.opacity(configuration.isPressed ? 0.16 : (isHovered ? 0.10 : 0)))
                )
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .onHover { isHovered = $0 }
                .animation(.easeOut(duration: 0.12), value: isHovered)
        }
    }
}

/// One progress bar per slide: done ones full, later ones empty, the current one fills in
/// 0.3 s when entered and stays full. It is not a timer.
struct OnboardingProgressBar: View {
    enum Phase {
        case done
        case current
        case upcoming
    }

    let phase: Phase
    let colors: OnboardingColors
    let animated: Bool

    @State private var filled = false

    var body: some View {
        Capsule()
            .fill(colors.barTrack)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(colors.barFill)
                    .scaleEffect(x: fill, y: 1, anchor: .leading)
            }
            .clipShape(Capsule())
            .onAppear {
                guard phase == .current else { return }
                withAnimation(animated ? .easeOut(duration: 0.3) : nil) {
                    filled = true
                }
            }
    }

    private var fill: CGFloat {
        switch phase {
        case .done: 1
        case .upcoming: 0
        case .current: filled ? 1 : 0
        }
    }
}

private struct OpenSettingsKey: EnvironmentKey {
    // Computed: a stored closure would be shared mutable state under strict concurrency.
    static var defaultValue: () -> Void { {} }
}

extension EnvironmentValues {
    /// Asks for Accessibility access, opens System Settings and lowers the panel. The access
    /// slide's own button inside the card and the single view's bottom button share it.
    var onboardingOpenSettings: () -> Void {
        get { self[OpenSettingsKey.self] }
        set { self[OpenSettingsKey.self] = newValue }
    }
}

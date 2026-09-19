import AppKit
import SwiftUI

/// ДОСТУП: System Settings open on Privacy & Security → Accessibility; the arrow switches Stash on.
/// The bottom of the canvas stays free for the card's real "Open Settings" button; in the single
/// view of the slide there is no button and the strip is just air.
struct AccessScene: View {
    static let duration = 3.0
    /// The System Settings window, and room under it for the card's button.
    static let size = CGSize(width: 460, height: 236)

    struct State: Equatable {
        var cursor: CursorState
        var ripple: ClickRipple?
        var isOn: Bool
    }

    /// The window and the pane inside it: the sidebar on the left, the app list on the right.
    static let window = CGRect(x: 10, y: 10, width: 440, height: 174)
    static let sidebarWidth: CGFloat = 150
    /// The Stash switch: the list row sits under the title and the explanation, the switch at its
    /// trailing edge.
    static let toggle = CGPoint(x: 418, y: 96)
    static let click = 1.2

    private static let cursor = CursorTrack(
        tip: Track(CGPoint(x: 390, y: 232)).to(toggle, at: 0.3, until: 1.0),
        opacity: Track(0.0).to(1, at: 0.15, until: 0.35),
        clicks: [click]
    )
    private static let isOn = Track(false).set(true, at: click + 0.04)

    static func state(at time: SceneTime) -> State {
        State(cursor: cursor.state(at: time), ripple: cursor.ripple(at: time), isOn: isOn.value(at: time))
    }

    let time: SceneTime

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.l10n) private var l10n

    var body: some View {
        let state = Self.state(at: time)
        let palette = ThemePalette.scene(colorScheme)
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)

        ZStack(alignment: .topLeading) {
            HStack(spacing: 0) {
                sidebar(palette: palette)
                    .frame(width: Self.sidebarWidth)
                    .background(palette.listSurface)
                content(state, palette: palette)
                    .background(palette.modalBackground)
            }
            .frame(width: Self.window.width, height: Self.window.height)
            .clipShape(shape)
            .overlay(shape.strokeBorder(palette.border, lineWidth: 1))
            .shadow(color: palette.shadow(0.18), radius: 16, y: 8)
            .offset(x: Self.window.minX, y: Self.window.minY)

            SceneRipple(ripple: state.ripple)
            SceneCursor(state: state.cursor)
        }
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
    }

    private func sidebar(palette: ThemePalette) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            TrafficLights()
                .padding(.bottom, 8)
            settingsItem("wifi", l10n("Wi\u{2011}Fi", "Wi\u{2011}Fi"), color: .blue, selected: false, palette: palette)
            settingsItem("network", l10n("Network", "Сеть"), color: .blue, selected: false, palette: palette)
            settingsItem("gearshape.fill", l10n("General", "Основные"), color: .gray, selected: false, palette: palette)
            settingsItem("hand.raised.fill", l10n("Privacy & Security", "Конфиденциальность и безопасность"), color: .blue, selected: true, palette: palette)
            Spacer(minLength: 0)
        }
        .padding(10)
    }

    private func settingsItem(_ symbol: String, _ title: String, color: Color, selected: Bool, palette: ThemePalette) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(width: 18, height: 18)
                .background(color, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            Text(title)
                .font(.system(size: 11))
                .lineLimit(1)
                .foregroundStyle(selected ? Color.white : palette.textPrimary)
        }
        .padding(.horizontal, 5)
        .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(selected ? Color(nsColor: .controlAccentColor) : .clear)
        )
    }

    private func content(_ state: State, palette: ThemePalette) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.textTertiary)
                Text(l10n("Accessibility", "Универсальный доступ"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)
            }
            .padding(.bottom, 4)
            Text(l10n("Allow the applications below to control your computer.", "Разрешить приложениям ниже управлять компьютером."))
                .font(.system(size: 11))
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 22, height: 22)
                Text("Stash")
                    .font(.system(size: 13))
                    .foregroundStyle(palette.textPrimary)
                Spacer(minLength: 0)
                SceneSwitch(isOn: state.isOn)
            }
            .padding(.horizontal, 10)
            .frame(height: 38)
            .background(palette.placeholderBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            // The buttons the footnote under the card talks about.
            HStack(spacing: 10) {
                Image(systemName: "plus")
                Image(systemName: "minus")
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(palette.textTertiary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
    }
}

/// A macOS switch: the knob slides and the track takes the system accent when on.
struct SceneSwitch: View {
    let isOn: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Capsule()
            .fill(isOn ? Color(nsColor: .controlAccentColor) : (colorScheme == .dark ? Color(white: 0.32) : Color(white: 0.84)))
            .frame(width: 32, height: 19)
            .overlay(alignment: isOn ? .trailing : .leading) {
                Circle()
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.25), radius: 1, y: 0.5)
                    .padding(2)
            }
            .animation(.easeOut(duration: 0.2), value: isOn)
    }
}

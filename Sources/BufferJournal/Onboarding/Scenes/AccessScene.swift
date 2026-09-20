import AppKit
import SwiftUI

/// ДОСТУП: System Settings open on Privacy & Security → Accessibility; the arrow switches Stash on.
/// The window fills the canvas: the screen has no card around it and no button inside it.
struct AccessScene: View {
    static let duration = 3.0
    /// The System Settings window with a margin for its shadow.
    static let size = CGSize(width: 460, height: 250)

    struct State: Equatable {
        var cursor: CursorState
        var ripple: ClickRipple?
        var isOn: Bool
    }

    /// The window and the pane inside it: the sidebar on the left, the app list on the right.
    static let window = CGRect(x: 10, y: 10, width: 440, height: 230)
    static let sidebarWidth: CGFloat = 150

    /// The pane's own layout, fixed so the arrow can be aimed at the switch by the same numbers
    /// the view is drawn with.
    private static let paneInset = CGSize(width: 16, height: 14)
    private static let headingHeight: CGFloat = 20
    private static let noteHeight: CGFloat = 30
    private static let rowSpacing: CGFloat = 8
    private static let appRowHeight: CGFloat = 38
    /// The app row's own padding, and the switch at its trailing edge.
    private static let appRowInset: CGFloat = 10
    private static let switchSize = CGSize(width: 32, height: 19)

    private static var appRow: CGRect {
        CGRect(
            x: window.minX + sidebarWidth,
            y: window.minY + paneInset.height + headingHeight + rowSpacing + noteHeight + rowSpacing,
            width: window.width - sidebarWidth,
            height: appRowHeight
        )
    }

    /// The Stash switch, dead centre — that is where the arrow clicks.
    static var toggle: CGPoint {
        CGPoint(
            x: appRow.maxX - paneInset.width - appRowInset - switchSize.width / 2,
            y: appRow.midY
        )
    }

    static let click = 1.2

    private static let cursor = CursorTrack(
        tip: Track(CGPoint(x: 400, y: 246)).to(toggle, at: 0.3, until: 1.0),
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
        VStack(alignment: .leading, spacing: Self.rowSpacing) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.textTertiary)
                Text(l10n("Accessibility", "Универсальный доступ"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)
            }
            .frame(height: Self.headingHeight, alignment: .leading)
            Text(l10n("Allow the applications below to control your computer.", "Разрешить приложениям ниже управлять компьютером."))
                .font(.system(size: 11))
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(height: Self.noteHeight, alignment: .top)
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
                    .frame(width: Self.switchSize.width, height: Self.switchSize.height)
            }
            .padding(.horizontal, Self.appRowInset)
            .frame(height: Self.appRowHeight)
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
        .padding(.horizontal, Self.paneInset.width)
        .padding(.top, Self.paneInset.height)
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

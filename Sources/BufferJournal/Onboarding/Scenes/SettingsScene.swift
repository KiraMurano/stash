import AppKit
import SwiftUI

/// НАСТРОЙКИ: the menu bar tray. The arrow clicks the Stash icon, then the three switches one
/// after another — each blinks and loses its check — and finally opens Theme and picks Dark.
/// The menu stays open throughout.
struct SettingsScene: View {
    static let duration = 4.7
    /// The tray end of the menu bar, the menu under the Stash icon and the theme submenu beside it.
    static let size = CGSize(width: 380, height: 280)

    enum Item: CaseIterable, Equatable, Sendable {
        case openStash, tutorial, closeAfterSelection, interceptKeys, openAtCaret, theme, language, clearHistory, quit
    }

    struct State: Equatable {
        var cursor: CursorState
        var ripple: ClickRipple?
        var iconHighlighted: Bool
        var menuOpen: Bool
        var highlighted: Item?
        /// The three switches, each still checked until its own click turns it off.
        var closeAfterSelectionChecked: Bool
        var interceptKeysChecked: Bool
        var openAtCaretChecked: Bool
        /// The theme submenu, open from the moment the arrow reaches Theme.
        var submenuOpen: Bool
        /// The theme row under the arrow inside the submenu.
        var submenuHighlighted: ThemeMode?
        /// Dark has been picked; until then the check stands on Stash Auto.
        var darkPicked: Bool
    }

    // Geometry, in scene points. The Stash icon opens the tray; a real menu hangs from its status
    // item's left edge, and a submenu opens to the right when there is room.
    static let statusIcon = CGPoint(x: 25, y: 12)
    static let menuOrigin = CGPoint(x: 8, y: 26)
    static let menuWidth: CGFloat = 210
    static let submenuWidth: CGFloat = 150
    static let rowHeight: CGFloat = 20
    static let separatorHeight: CGFloat = 8
    static let menuPadding: CGFloat = 4

    /// Menu rows top to bottom, as in the app's menu; nil is a separator.
    static let rows: [Item?] = [
        .openStash, .tutorial, nil,
        .closeAfterSelection, .interceptKeys, .openAtCaret, .theme, .language, nil,
        .clearHistory, .quit,
    ]

    /// Where each item sits in the menu, for the highlight to follow the arrow.
    static func frame(of item: Item) -> CGRect {
        var y = menuOrigin.y + menuPadding
        for row in rows {
            if row == item {
                return CGRect(x: menuOrigin.x, y: y, width: menuWidth, height: rowHeight)
            }
            y += row == nil ? separatorHeight : rowHeight
        }
        return .zero
    }

    /// The submenu's top-left corner: just over the menu's right edge, its first item level with Theme.
    static var submenuOrigin: CGPoint {
        CGPoint(x: menuOrigin.x + menuWidth - 4, y: frame(of: .theme).minY - menuPadding)
    }

    /// The theme rows of the submenu, in the app's own order; nil is the separator.
    static let themeRows: [ThemeMode?] = [.system, .light, .dark, nil, .stashAuto, .stashLight, .stashDark]

    /// Where a theme sits inside the submenu, in scene points.
    static func submenuFrame(of mode: ThemeMode) -> CGRect {
        var y = submenuOrigin.y + menuPadding
        for row in themeRows {
            if row == mode {
                return CGRect(x: submenuOrigin.x, y: y, width: submenuWidth, height: rowHeight)
            }
            y += row == nil ? separatorHeight : rowHeight
        }
        return .zero
    }

    /// Checks in the demo menu: all three switches are on when the menu opens, and each goes out
    /// under its own click.
    static func isChecked(_ item: Item, _ state: State) -> Bool {
        switch item {
        case .closeAfterSelection: state.closeAfterSelectionChecked
        case .interceptKeys: state.interceptKeysChecked
        case .openAtCaret: state.openAtCaretChecked
        default: false
        }
    }

    /// The theme carrying the check: Stash Auto until Dark is picked.
    static func checkedTheme(_ state: State) -> ThemeMode {
        state.darkPicked ? .dark : .stashAuto
    }

    private static func center(of item: Item) -> CGPoint {
        CGPoint(x: menuOrigin.x + 90, y: frame(of: item).midY)
    }

    private static func center(of mode: ThemeMode) -> CGPoint {
        CGPoint(x: submenuOrigin.x + submenuWidth / 2, y: submenuFrame(of: mode).midY)
    }

    // Clicks: the icon, the three switches, then Dark in the theme submenu. The menu stays open.
    static let iconClick = 0.9
    static let switchClicks = [1.35, 1.7, 2.05]
    static let themeClick = 3.2
    static var itemClicks: [Double] { switchClicks + [themeClick] }
    /// A clicked item goes dark for a moment and lights up again, as in macOS.
    static let blinkOff = 0.06...0.12

    private static let cursor = CursorTrack(
        tip: Track(CGPoint(x: 300, y: 262))
            .to(statusIcon, at: 0.3, until: 0.8)
            .to(center(of: .closeAfterSelection), at: 1.05, until: 1.3)
            .to(center(of: .interceptKeys), at: 1.45, until: 1.65)
            .to(center(of: .openAtCaret), at: 1.8, until: 2.0)
            .to(center(of: .theme), at: 2.2, until: 2.4)
            .to(center(of: .dark), at: 2.75, until: 3.15),
        opacity: Track(0.0).to(1, at: 0.15, until: 0.35),
        clicks: [iconClick] + switchClicks + [themeClick]
    )
    private static let iconHighlighted = Track(false).set(true, at: iconClick)
    private static let menuOpen = Track(false).set(true, at: iconClick + 0.05)
    /// Each check goes out as its item lights up again after the click.
    private static let closeAfterSelectionChecked = Track(true).set(false, at: switchClicks[0] + blinkOff.upperBound)
    private static let interceptKeysChecked = Track(true).set(false, at: switchClicks[1] + blinkOff.upperBound)
    private static let openAtCaretChecked = Track(true).set(false, at: switchClicks[2] + blinkOff.upperBound)
    /// The submenu opens when the arrow reaches Theme and stays open while it walks into it.
    private static let submenuOpen = Track(false).set(true, at: 2.4)
    private static let darkPicked = Track(false).set(true, at: themeClick + blinkOff.upperBound)

    static func state(at time: SceneTime) -> State {
        let cursor = cursor.state(at: time)
        let menuOpen = menuOpen.value(at: time)
        // Like a real menu, the highlight is whatever item is under the arrow, except while a clicked
        // item blinks. While the loop goes back to its start the menu is closed, so the arrow passing
        // over it lights nothing up.
        let blinking = time.rewind == 0 && itemClicks.contains { blinkOff.contains(time.t - $0) }
        let submenuOpen = menuOpen && submenuOpen.value(at: time)
        let submenuHighlighted = submenuOpen && !blinking
            ? themeRows.compactMap { $0 }.first { submenuFrame(of: $0).contains(cursor.tip) }
            : nil
        // While the arrow is inside the submenu, Theme keeps the highlight, as a real menu does.
        let highlighted = menuOpen && !blinking
            ? Item.allCases.first { frame(of: $0).contains(cursor.tip) } ?? (submenuOpen ? .theme : nil)
            : nil
        return State(
            cursor: cursor,
            ripple: Self.cursor.ripple(at: time),
            iconHighlighted: iconHighlighted.value(at: time),
            menuOpen: menuOpen,
            highlighted: highlighted,
            closeAfterSelectionChecked: closeAfterSelectionChecked.value(at: time),
            interceptKeysChecked: interceptKeysChecked.value(at: time),
            openAtCaretChecked: openAtCaretChecked.value(at: time),
            submenuOpen: submenuOpen,
            submenuHighlighted: submenuHighlighted,
            darkPicked: darkPicked.value(at: time)
        )
    }

    let time: SceneTime

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.l10n) private var l10n

    var body: some View {
        let state = Self.state(at: time)
        let palette = ThemePalette.scene(colorScheme)

        ZStack(alignment: .topLeading) {
            menuBar(state, palette: palette)

            Group {
                menuPanel(state, palette: palette)
                    .offset(x: Self.menuOrigin.x, y: Self.menuOrigin.y)

                if state.submenuOpen {
                    themeSubmenu(state, palette: palette)
                        .offset(x: Self.submenuOrigin.x, y: Self.submenuOrigin.y)
                }
            }
            .opacity(state.menuOpen ? 1 : 0)
            // Menus appear and vanish quickly, as in macOS.
            .animation(.easeOut(duration: 0.12), value: state.menuOpen)

            SceneRipple(ripple: state.ripple)
            SceneCursor(state: state.cursor)
        }
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
    }

    // MARK: Menu bar

    /// Only the tray: the Stash icon, then the system's own items at the right end.
    private func menuBar(_ state: State, palette: ThemePalette) -> some View {
        ZStack {
            statusIcon
                .frame(width: 26, height: 20)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(palette.textPrimary.opacity(state.iconHighlighted ? 0.14 : 0))
                )
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 10) {
                Image(systemName: "wifi").frame(width: 22)
                Image(systemName: "battery.75").frame(width: 30)
                Image(systemName: "switch.2").frame(width: 22)
                Text("14:02").frame(width: 40)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(.system(size: 12))
        .foregroundStyle(palette.textPrimary)
        .padding(.leading, 12)
        .padding(.trailing, 14)
        .frame(width: Self.size.width, height: 24)
        .background(menuBackground)
        .overlay(alignment: .bottom) {
            palette.separator.frame(height: 1)
        }
    }

    /// The real menu bar icon of Stash at its own 14 × 18 pt, with the app's own fallback.
    private var statusIcon: some View {
        Group {
            if let icon = Bundle.main.image(forResource: "StatusIcon") {
                Image(nsImage: icon)
                    .renderingMode(.template)
            } else {
                Image(systemName: "doc.on.clipboard")
            }
        }
        .frame(width: 14, height: 18)
    }

    private var menuBackground: Color {
        colorScheme == .dark ? Color(white: 0.17) : Color(white: 0.97)
    }

    // MARK: Menu

    private func menuPanel(_ state: State, palette: ThemePalette) -> some View {
        let titles = StatusMenuTitles(l10n: l10n)
        return VStack(spacing: 0) {
            ForEach(Array(Self.rows.enumerated()), id: \.offset) { _, row in
                if let row {
                    menuRow(
                        title: title(of: row, titles),
                        checked: Self.isChecked(row, state),
                        submenu: row == .theme || row == .language,
                        shortcut: row == .quit ? "⌘Q" : nil,
                        highlighted: state.highlighted == row,
                        palette: palette
                    )
                } else {
                    separator(palette: palette)
                }
            }
        }
        .padding(.vertical, Self.menuPadding)
        .frame(width: Self.menuWidth)
        .background(menuSurface(palette: palette))
    }

    private func themeSubmenu(_ state: State, palette: ThemePalette) -> some View {
        // The app's own order, with the separator before Stash Auto, as in AppDelegate.
        VStack(spacing: 0) {
            ForEach(Array(Self.themeRows.enumerated()), id: \.offset) { _, mode in
                if let mode {
                    menuRow(
                        title: l10n.themeName(mode),
                        checked: mode == Self.checkedTheme(state),
                        submenu: false,
                        shortcut: nil,
                        highlighted: state.submenuHighlighted == mode,
                        palette: palette
                    )
                } else {
                    separator(palette: palette)
                }
            }
        }
        .padding(.vertical, Self.menuPadding)
        .frame(width: Self.submenuWidth)
        .background(menuSurface(palette: palette))
    }

    private func separator(palette: ThemePalette) -> some View {
        palette.separator
            .frame(height: 1)
            .padding(.horizontal, 10)
            .frame(height: Self.separatorHeight)
    }

    private func menuRow(title: String, checked: Bool, submenu: Bool, shortcut: String?, highlighted: Bool, palette: ThemePalette) -> some View {
        HStack(spacing: 0) {
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .semibold))
                .opacity(checked ? 1 : 0)
                .frame(width: 18)
            Text(title)
                .lineLimit(1)
            Spacer(minLength: 8)
            if submenu {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
            }
            if let shortcut {
                Text(shortcut)
                    .opacity(0.5)
            }
        }
        .font(.system(size: 12))
        .foregroundStyle(highlighted ? Color.white : palette.textPrimary)
        .padding(.horizontal, 8)
        .frame(height: Self.rowHeight)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(highlighted ? Color(nsColor: .controlAccentColor) : .clear)
                .padding(.horizontal, 5)
        )
    }

    private func menuSurface(palette: ThemePalette) -> some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        return shape
            .fill(menuBackground)
            .overlay(shape.strokeBorder(palette.border, lineWidth: 1))
            .shadow(color: palette.shadow(0.22), radius: 12, y: 6)
    }

    private func title(of item: Item, _ titles: StatusMenuTitles) -> String {
        switch item {
        case .openStash: titles.openStash
        case .tutorial: titles.tutorial
        case .closeAfterSelection: titles.closeAfterSelection
        case .interceptKeys: titles.interceptKeys
        case .openAtCaret: titles.openAtCaret
        case .theme: titles.theme
        case .language: titles.language
        case .clearHistory: titles.clearHistory
        case .quit: titles.quit
        }
    }
}

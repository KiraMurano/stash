import CoreGraphics
import Testing
@testable import BufferJournal

/// The stop frame from the spec's "Сцены" section and the moments that lead to it.
@MainActor
struct SettingsSceneTests {
    @Test func settingsEndsOnTheDarkThemeWithEverySwitchOff() {
        let end = SettingsScene.state(at: .end(of: SettingsScene.duration))
        #expect(end.menuOpen)
        #expect(end.iconHighlighted)
        #expect(end.submenuOpen)
        #expect(SettingsScene.checkedTheme(end) == .dark)
        // All three switches were on when the menu opened and each click put one out.
        #expect(!SettingsScene.isChecked(.closeAfterSelection, end))
        #expect(!SettingsScene.isChecked(.interceptKeys, end))
        #expect(!SettingsScene.isChecked(.openAtCaret, end))
    }

    @Test func theMenuOpensWithEverySwitchOn() {
        let opened = SettingsScene.state(at: SceneTime(t: SettingsScene.iconClick + 0.1, rewind: 0))
        #expect(opened.menuOpen)
        #expect(SettingsScene.isChecked(.closeAfterSelection, opened))
        #expect(SettingsScene.isChecked(.interceptKeys, opened))
        #expect(SettingsScene.isChecked(.openAtCaret, opened))
        #expect(SettingsScene.checkedTheme(opened) == .stashAuto)
    }

    @Test func theArrowClicksTheThreeSwitchesInTurn() {
        let items: [SettingsScene.Item] = [.closeAfterSelection, .interceptKeys, .openAtCaret]
        for (index, item) in items.enumerated() {
            let click = SettingsScene.switchClicks[index]

            // The arrow is on the row it is about to click, and the switch is still on.
            let before = SettingsScene.state(at: SceneTime(t: click - 0.02, rewind: 0))
            #expect(before.highlighted == item, "\(item) is not under the arrow at its click")
            #expect(SettingsScene.isChecked(item, before), "\(item) is off before its click")

            let ripple = SettingsScene.state(at: SceneTime(t: click + 0.01, rewind: 0)).ripple
            #expect(ripple.map { SettingsScene.frame(of: item).contains($0.center) } == true, "\(item) click misses its row")

            // It blinks dark, then lights up again without its check.
            let blink = SettingsScene.state(at: SceneTime(t: click + 0.09, rewind: 0))
            #expect(blink.menuOpen && blink.highlighted == nil)
            #expect(SettingsScene.isChecked(item, blink), "\(item) loses its check too early")

            let after = SettingsScene.state(at: SceneTime(t: click + 0.13, rewind: 0))
            #expect(!SettingsScene.isChecked(item, after), "\(item) keeps its check after the click")
        }

        // From the first click on, the menu never closes before the loop goes back.
        for t in stride(from: SettingsScene.iconClick + 0.05, through: SettingsScene.duration, by: 0.05) {
            #expect(SettingsScene.state(at: SceneTime(t: t, rewind: 0)).menuOpen)
        }
    }

    @Test func aSwitchStaysOnUntilItsOwnClick() {
        // Walking over a switch does nothing; only its click does.
        let onTheWay = SettingsScene.state(at: SceneTime(t: SettingsScene.switchClicks[1] - 0.1, rewind: 0))
        #expect(onTheWay.highlighted == .interceptKeys)
        #expect(SettingsScene.isChecked(.interceptKeys, onTheWay))
        #expect(SettingsScene.isChecked(.openAtCaret, onTheWay))
        #expect(!SettingsScene.isChecked(.closeAfterSelection, onTheWay))
    }

    @Test func themeOpensItsSubmenuAndDarkIsPicked() {
        // The submenu opens when the arrow reaches Theme and stays open while it walks in.
        let opening = SettingsScene.state(at: SceneTime(t: 2.5, rewind: 0))
        #expect(opening.submenuOpen)
        #expect(opening.highlighted == .theme)
        #expect(SettingsScene.checkedTheme(opening) == .stashAuto)

        // Inside the submenu, Theme keeps the highlight and the row under the arrow lights up.
        let inside = SettingsScene.state(at: SceneTime(t: SettingsScene.themeClick - 0.02, rewind: 0))
        #expect(inside.submenuHighlighted == .dark)
        #expect(inside.highlighted == .theme)

        let ripple = SettingsScene.state(at: SceneTime(t: SettingsScene.themeClick + 0.01, rewind: 0)).ripple
        #expect(ripple.map { SettingsScene.submenuFrame(of: .dark).contains($0.center) } == true)
        let after = SettingsScene.state(at: SceneTime(t: SettingsScene.themeClick + 0.2, rewind: 0))
        #expect(SettingsScene.checkedTheme(after) == .dark)
    }

    @Test func theTutorialItemIsNeverClicked() {
        for click in SettingsScene.itemClicks {
            let ripple = SettingsScene.state(at: SceneTime(t: click + 0.01, rewind: 0)).ripple
            #expect(ripple.map { SettingsScene.frame(of: .tutorial).contains($0.center) } != true)
        }
    }

    @Test func theMenuAndItsSubmenuFitTheCanvas() {
        #expect(SettingsScene.frame(of: .quit).maxY + SettingsScene.menuPadding <= SettingsScene.size.height)
        let submenu = SettingsScene.submenuOrigin
        #expect(submenu.x >= SettingsScene.menuOrigin.x + SettingsScene.menuWidth - 8)
        #expect(submenu.x + SettingsScene.submenuWidth <= SettingsScene.size.width)
        // Six theme rows and a separator, with the menu's padding.
        let height = 6 * SettingsScene.rowHeight + SettingsScene.separatorHeight + 2 * SettingsScene.menuPadding
        #expect(submenu.y + height <= SettingsScene.size.height)
        #expect(SettingsScene.submenuFrame(of: .dark).maxY <= SettingsScene.size.height)
    }

    @Test func theMenuMatchesTheMenuBarMenu() {
        // The rows are the menu of the app, in its order: two openers, three switches, two
        // submenus, then Clear History and Quit.
        #expect(SettingsScene.rows == [
            .openStash, .tutorial, nil,
            .closeAfterSelection, .interceptKeys, .openAtCaret, .theme, .language, nil,
            .clearHistory, .quit,
        ])
        // And the theme submenu is the app's own list, separator included.
        #expect(SettingsScene.themeRows == [.system, .light, .dark, nil, .stashAuto, .stashLight, .stashDark])
    }

    @Test func nothingLightsUpWhileTheLoopGoesBack() {
        for rewind in stride(from: 0.05, through: 1, by: 0.05) {
            let state = SettingsScene.state(at: SceneTime(t: SettingsScene.duration, rewind: rewind))
            #expect(!state.menuOpen)
            #expect(!state.submenuOpen)
            #expect(state.highlighted == nil)
            #expect(state.submenuHighlighted == nil)
        }
    }
}

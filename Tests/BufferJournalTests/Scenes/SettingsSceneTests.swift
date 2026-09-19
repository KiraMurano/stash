import CoreGraphics
import Testing
@testable import BufferJournal

/// The stop frame from the spec's "Сцены" section and the moments that lead to it.
@MainActor
struct SettingsSceneTests {
    @Test func settingsEndsOnTutorialWithTheMenuOpen() {
        let end = SettingsScene.state(at: .end(of: SettingsScene.duration))
        #expect(end.menuOpen)
        #expect(end.iconHighlighted)
        #expect(end.highlighted == .tutorial)
        // Both switches the story talks about are ticked at the end.
        #expect(SettingsScene.isChecked(.closeAfterSelection, end))
        #expect(SettingsScene.isChecked(.interceptKeys, end))
    }

    @Test func theArrowPassesCloseAfterSelectionAndClicksInterceptKeys() {
        // "Close After Selection" is on from the start: the arrow only walks over it.
        let passing = SettingsScene.state(at: SceneTime(t: 1.35, rewind: 0))
        #expect(passing.highlighted == .closeAfterSelection)
        #expect(SettingsScene.isChecked(.closeAfterSelection, passing))
        #expect(!SettingsScene.isChecked(.interceptKeys, passing))

        let click = SettingsScene.itemClicks[0]
        let ripple = SettingsScene.state(at: SceneTime(t: click + 0.01, rewind: 0)).ripple
        #expect(ripple.map { SettingsScene.frame(of: .interceptKeys).contains($0.center) } == true)
        let blink = SettingsScene.state(at: SceneTime(t: click + 0.09, rewind: 0))
        #expect(blink.menuOpen && blink.highlighted == nil && !blink.interceptChecked)
        let after = SettingsScene.state(at: SceneTime(t: click + 0.2, rewind: 0))
        #expect(after.menuOpen && after.highlighted == .interceptKeys && after.interceptChecked)
        // From the first click on, the menu never closes before the loop goes back.
        for t in stride(from: SettingsScene.iconClick + 0.05, through: SettingsScene.duration, by: 0.05) {
            #expect(SettingsScene.state(at: SceneTime(t: t, rewind: 0)).menuOpen)
        }
    }

    @Test func tutorialIsClickedAtTheEnd() {
        let ripple = SettingsScene.state(at: SceneTime(t: SettingsScene.itemClicks[1] + 0.01, rewind: 0)).ripple
        #expect(ripple.map { SettingsScene.frame(of: .tutorial).contains($0.center) } == true)
    }

    @Test func theArrowRestsOnThemeBetweenTheTwoClicks() {
        #expect(SettingsScene.state(at: SceneTime(t: 2.4, rewind: 0)).highlighted == .theme)
        // By the time it is on its way to Tutorial the submenu is gone.
        #expect(SettingsScene.state(at: SceneTime(t: 3.0, rewind: 0)).highlighted != .theme)
    }

    @Test func theMenuAndItsSubmenuFitTheCanvas() {
        #expect(SettingsScene.frame(of: .quit).maxY + SettingsScene.menuPadding <= SettingsScene.size.height)
        let submenu = SettingsScene.submenuOrigin
        #expect(submenu.x >= SettingsScene.menuOrigin.x + SettingsScene.menuWidth - 8)
        #expect(submenu.x + SettingsScene.submenuWidth <= SettingsScene.size.width)
        // Six theme rows and a separator, with the menu's padding.
        let height = 6 * SettingsScene.rowHeight + SettingsScene.separatorHeight + 2 * SettingsScene.menuPadding
        #expect(submenu.y + height <= SettingsScene.size.height)
    }

    @Test func theMenuMatchesTheMenuBarMenu() {
        // The rows are the menu of the app, in its order: two openers, three switches, two
        // submenus, then Clear History and Quit.
        #expect(SettingsScene.rows == [
            .openStash, .tutorial, nil,
            .closeAfterSelection, .interceptKeys, .openAtCaret, .theme, .language, nil,
            .clearHistory, .quit,
        ])
    }

    @Test func nothingLightsUpWhileTheLoopGoesBack() {
        for rewind in stride(from: 0.05, through: 1, by: 0.05) {
            let state = SettingsScene.state(at: SceneTime(t: SettingsScene.duration, rewind: rewind))
            #expect(!state.menuOpen)
            #expect(state.highlighted == nil)
        }
    }
}

import CoreGraphics
import Testing
@testable import BufferJournal

struct OnboardingLayoutTests {
    @Test func scenesFillTheRoomKeepingTheirShape() {
        let scene = CGSize(width: 480, height: 240)
        #expect(abs(OnboardingLayout.sceneScale(scene, in: CGSize(width: 600, height: 400)) - 1.25) < 0.0001)
        #expect(abs(OnboardingLayout.sceneScale(scene, in: CGSize(width: 860, height: 371)) - 371.0 / 240.0) < 0.0001)
        #expect(abs(OnboardingLayout.sceneScale(scene, in: CGSize(width: 520, height: 193)) - 193.0 / 240.0) < 0.0001)
        #expect(OnboardingLayout.sceneScale(scene, in: .zero) == 0)
    }

    @Test func theCardTakesTheWholeWidthOrHeight() {
        // A tall scene meets the height and stays as narrow as it needs.
        let tall = OnboardingLayout.cardSize(for: CGSize(width: 344, height: 246), in: CGSize(width: 600, height: 300))
        #expect(abs(tall.height - 300) < 0.001)
        #expect(abs(tall.width - 344 * 300 / 246) < 0.001)
        // A wide scene meets the width.
        let wide = OnboardingLayout.cardSize(for: CGSize(width: 480, height: 240), in: CGSize(width: 600, height: 400))
        #expect(abs(wide.width - 600) < 0.001)
        #expect(abs(wide.height - 300) < 0.001)
    }

    @Test func heroLockupFitsItsArea() {
        let area = CGSize(width: 600, height: 262)
        let lockup = OnboardingLayout.heroLockup(in: area, wordWidthAt28: 73)
        let k = lockup.icon / 32
        #expect(lockup.icon + lockup.gap + 73 * k <= area.width * 0.8 + 0.001)
        #expect(lockup.icon <= area.height * 0.8 + 0.001)
        #expect(abs(lockup.fontSize / lockup.icon - 28.0 / 32.0) < 0.0001)
    }

    @Test func theTitleStopsAtTenPercentOfThePanel() {
        #expect(OnboardingLayout.titleFontSize(widthAt100: 500, rowWidth: 600, panelHeight: 440) == 44)
        #expect(OnboardingLayout.titleFontSize(widthAt100: 500, rowWidth: 520, panelHeight: 360) == 36)
    }

    @Test func aLongTitleShrinksToItsRow() {
        // 100 × 600 / (2000 × 1.02) = 29.4
        #expect(OnboardingLayout.titleFontSize(widthAt100: 2000, rowWidth: 600, panelHeight: 440) == 29)
    }

    @MainActor
    @Test func heavyTextIsMeasuredInTheHeaderFont() {
        #expect(HeavyTextMetrics.width("Stash", size: 56) > 2 * HeavyTextMetrics.width("Stash", size: 27))
        #expect(HeavyTextMetrics.width("ПРИВЕТ, ЭТО", size: 100, tracking: -2) < HeavyTextMetrics.width("ПРИВЕТ, ЭТО", size: 100))
        #expect(HeavyTextMetrics.capHeight(size: 28) > 15)
    }
}

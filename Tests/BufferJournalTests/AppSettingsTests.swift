import Foundation
import Testing
@testable import BufferJournal

@MainActor
struct AppSettingsTests {
    private func freshDefaults() -> UserDefaults {
        let name = "AppSettingsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func freshInstallStartsWithStashAuto() {
        #expect(AppSettings(defaults: freshDefaults()).themeMode == .stashAuto)
    }

    @Test func aThemePickedBeforeIsKept() {
        let defaults = freshDefaults()
        defaults.set(ThemeMode.dark.rawValue, forKey: "ThemeMode")
        #expect(AppSettings(defaults: defaults).themeMode == .dark)
    }

    @Test func changesAreSavedToTheGivenDefaults() {
        let defaults = freshDefaults()
        let settings = AppSettings(defaults: defaults)
        settings.themeMode = .stashLight
        #expect(defaults.string(forKey: "ThemeMode") == ThemeMode.stashLight.rawValue)
    }
}

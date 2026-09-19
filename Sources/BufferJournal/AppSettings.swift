import SwiftUI

enum ThemeMode: String, CaseIterable {
    case system
    case light
    case dark
    case stashAuto
    case stashLight
    case stashDark

    var colorScheme: ColorScheme? {
        switch self {
        case .system, .stashAuto:
            nil
        case .light, .stashLight:
            .light
        case .dark, .stashDark:
            .dark
        }
    }

    /// Stash themes paint every orange accent and button with opaque fills instead of tints.
    var usesSolidAccents: Bool {
        self == .stashAuto || self == .stashLight || self == .stashDark
    }
}

@MainActor
final class AppSettings: ObservableObject {
    private enum Keys {
        static let interceptKeys = "InterceptKeys"
        static let closeAfterSelection = "CloseAfterSelection"
        static let themeMode = "ThemeMode"
        static let language = "Language"
    }

    /// While the journal is open it takes Up, Down, Return and Esc from the app underneath.
    /// Turned off, the journal is worked with the mouse and every key stays with that app.
    @Published var interceptKeys: Bool {
        didSet {
            UserDefaults.standard.set(interceptKeys, forKey: Keys.interceptKeys)
        }
    }

    @Published var closeAfterSelection: Bool {
        didSet {
            UserDefaults.standard.set(closeAfterSelection, forKey: Keys.closeAfterSelection)
        }
    }

    @Published var themeMode: ThemeMode {
        didSet {
            UserDefaults.standard.set(themeMode.rawValue, forKey: Keys.themeMode)
        }
    }

    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: Keys.language)
        }
    }

    var l10n: L10n {
        L10n(language: language.resolved)
    }

    init() {
        let defaults = UserDefaults.standard

        if defaults.object(forKey: Keys.interceptKeys) == nil {
            defaults.set(true, forKey: Keys.interceptKeys)
        }

        // On by default: the panel closes after a paste, like Win+V, and Return goes back to the
        // user's text right away. Those who have run Stash before keep their own choice.
        if defaults.object(forKey: Keys.closeAfterSelection) == nil {
            defaults.set(true, forKey: Keys.closeAfterSelection)
        }

        interceptKeys = defaults.bool(forKey: Keys.interceptKeys)
        closeAfterSelection = defaults.bool(forKey: Keys.closeAfterSelection)
        themeMode = ThemeMode(rawValue: defaults.string(forKey: Keys.themeMode) ?? "") ?? .system
        language = AppLanguage(rawValue: defaults.string(forKey: Keys.language) ?? "") ?? .system
    }
}

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
            return nil
        case .light, .stashLight:
            return .light
        case .dark, .stashDark:
            return .dark
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
        static let openAtCaret = "OpenAtCaret"
        static let interceptKeys = "InterceptKeys"
        static let closeAfterSelection = "CloseAfterSelection"
        static let themeMode = "ThemeMode"
        static let language = "Language"
    }

    /// Tests hand in their own domain; the app takes the standard one.
    private let defaults: UserDefaults

    /// The panel opens next to the text cursor of the app the user is typing in, like Win+V.
    /// Turned off, it opens where it was left, as before.
    @Published var openAtCaret: Bool {
        didSet {
            defaults.set(openAtCaret, forKey: Keys.openAtCaret)
        }
    }

    /// While the journal is open it takes Up, Down, Return and Esc from the app underneath.
    /// Turned off, the journal is worked with the mouse and every key stays with that app.
    @Published var interceptKeys: Bool {
        didSet {
            defaults.set(interceptKeys, forKey: Keys.interceptKeys)
        }
    }

    @Published var closeAfterSelection: Bool {
        didSet {
            defaults.set(closeAfterSelection, forKey: Keys.closeAfterSelection)
        }
    }

    @Published var themeMode: ThemeMode {
        didSet {
            defaults.set(themeMode.rawValue, forKey: Keys.themeMode)
        }
    }

    @Published var language: AppLanguage {
        didSet {
            defaults.set(language.rawValue, forKey: Keys.language)
        }
    }

    var l10n: L10n {
        L10n(language: language.resolved)
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if defaults.object(forKey: Keys.openAtCaret) == nil {
            defaults.set(true, forKey: Keys.openAtCaret)
        }

        if defaults.object(forKey: Keys.interceptKeys) == nil {
            defaults.set(true, forKey: Keys.interceptKeys)
        }

        // On by default: the panel closes after a paste, like Win+V, and Return goes back to the
        // user's text right away. Those who have run Stash before keep their own choice.
        if defaults.object(forKey: Keys.closeAfterSelection) == nil {
            defaults.set(true, forKey: Keys.closeAfterSelection)
        }

        openAtCaret = defaults.bool(forKey: Keys.openAtCaret)
        interceptKeys = defaults.bool(forKey: Keys.interceptKeys)
        closeAfterSelection = defaults.bool(forKey: Keys.closeAfterSelection)
        // Stash Auto unless the person picked a theme before.
        themeMode = ThemeMode(rawValue: defaults.string(forKey: Keys.themeMode) ?? "") ?? .stashAuto
        language = AppLanguage(rawValue: defaults.string(forKey: Keys.language) ?? "") ?? .system
    }
}

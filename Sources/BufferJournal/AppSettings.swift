import SwiftUI

enum ThemeMode: String, CaseIterable {
    case system
    case light
    case dark
    case stashLight
    case stashDark

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            nil
        case .light, .stashLight:
            .light
        case .dark, .stashDark:
            .dark
        }
    }

    /// Stash themes paint every orange accent and button with opaque fills instead of tints.
    var usesSolidAccents: Bool {
        self == .stashLight || self == .stashDark
    }
}

@MainActor
final class AppSettings: ObservableObject {
    private enum Keys {
        static let pasteOnSelection = "PasteOnSelection"
        static let closeAfterSelection = "CloseAfterSelection"
        static let themeMode = "ThemeMode"
        static let language = "Language"
    }

    @Published var pasteOnSelection: Bool {
        didSet {
            UserDefaults.standard.set(pasteOnSelection, forKey: Keys.pasteOnSelection)
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

        if defaults.object(forKey: Keys.pasteOnSelection) == nil {
            defaults.set(true, forKey: Keys.pasteOnSelection)
        }

        if defaults.object(forKey: Keys.closeAfterSelection) == nil {
            defaults.set(false, forKey: Keys.closeAfterSelection)
        }

        pasteOnSelection = defaults.bool(forKey: Keys.pasteOnSelection)
        closeAfterSelection = defaults.bool(forKey: Keys.closeAfterSelection)
        themeMode = ThemeMode(rawValue: defaults.string(forKey: Keys.themeMode) ?? "") ?? .system
        language = AppLanguage(rawValue: defaults.string(forKey: Keys.language) ?? "") ?? .system
    }
}

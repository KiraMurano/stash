import SwiftUI

enum ThemeMode: String, CaseIterable {
    case system
    case light
    case dark

    var title: String {
        switch self {
        case .system:
            "Auto"
        case .light:
            "Light"
        case .dark:
            "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            nil
        case .light:
            .light
        case .dark:
            .dark
        }
    }
}

@MainActor
final class AppSettings: ObservableObject {
    private enum Keys {
        static let pasteOnSelection = "PasteOnSelection"
        static let closeAfterSelection = "CloseAfterSelection"
        static let themeMode = "ThemeMode"
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
    }
}

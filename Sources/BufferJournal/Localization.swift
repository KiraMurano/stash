import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable {
    case system
    case english
    case russian

    var resolved: ResolvedLanguage {
        switch self {
        case .english:
            .english
        case .russian:
            .russian
        case .system:
            Locale.preferredLanguages.first?.hasPrefix("ru") == true ? .russian : .english
        }
    }
}

enum ResolvedLanguage {
    case english
    case russian
}

/// Two-language string lookup: `l10n("Delete", "Удалить")`.
struct L10n {
    let language: ResolvedLanguage

    func callAsFunction(_ english: String, _ russian: String) -> String {
        language == .russian ? russian : english
    }

    func languageName(_ language: AppLanguage) -> String {
        switch language {
        case .system: self("System", "Системный")
        case .english: "English"
        case .russian: "Русский"
        }
    }

    func themeName(_ mode: ThemeMode) -> String {
        switch mode {
        case .system: self("Auto", "Авто")
        case .light: self("Light", "Светлая")
        case .dark: self("Dark", "Тёмная")
        case .stashAuto: "Stash Auto"
        case .stashLight: "Stash Light"
        case .stashDark: "Stash Dark"
        }
    }

    func characters(_ count: Int) -> String {
        guard language == .russian else {
            return "\(count) \(count == 1 ? "character" : "characters")"
        }

        let mod10 = count % 10
        let mod100 = count % 100
        let word: String
        if mod10 == 1, mod100 != 11 {
            word = "символ"
        } else if (2...4).contains(mod10), !(12...14).contains(mod100) {
            word = "символа"
        } else {
            word = "символов"
        }
        return "\(count) \(word)"
    }
}

private struct SolidAccentsKey: EnvironmentKey {
    static let defaultValue = false
}

private struct L10nKey: EnvironmentKey {
    static let defaultValue = L10n(language: AppLanguage.system.resolved)
}

extension EnvironmentValues {
    var l10n: L10n {
        get { self[L10nKey.self] }
        set { self[L10nKey.self] = newValue }
    }

    /// Set by the Stash Light / Stash Dark themes.
    var solidAccents: Bool {
        get { self[SolidAccentsKey.self] }
        set { self[SolidAccentsKey.self] = newValue }
    }
}

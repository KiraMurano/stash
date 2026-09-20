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

    /// The image's size with one decimal, in the app's language: "4,2 МБ" / "4.2 MB".
    func megabytes(_ bytes: Int64) -> String {
        let value = Double(bytes) / 1_048_576
        let number = String(format: "%.1f", value)
        return language == .russian
            ? "\(number.replacingOccurrences(of: ".", with: ",")) МБ"
            : "\(number) MB"
    }

    func updateCurrent(_ version: String, bytes: Int64) -> String {
        self("Now \(version) · \(megabytes(bytes))", "Сейчас \(version) · \(megabytes(bytes))")
    }

    func updateDownloading(_ fraction: Double) -> String {
        let percent = Int((min(max(fraction, 0), 1) * 100).rounded())
        return self("Downloading… \(percent) %", "Загрузка… \(percent) %")
    }

    var updateInstalling: String { self("Installing…", "Установка…") }
    var updateNow: String { self("Update and Relaunch", "Обновить и перезапустить") }
    var updateLater: String { self("Later", "Позже") }
    var updateOpenReleases: String { self("Open the Releases Page", "Открыть страницу релизов") }

    /// One sentence per failure. The technical detail from codesign stays in the log: it says
    /// nothing to the person and only makes the screen unreadable.
    func updateFailure(_ error: UpdateError) -> String {
        switch error {
        case .network:
            self("Could not check for updates.", "Не удалось проверить обновления.")
        case .signature:
            self(
                "The downloaded image failed its signature check. Nothing was installed.",
                "Не удалось проверить подпись загруженного образа. Ничего не установлено."
            )
        case .install:
            self("The update could not be installed.", "Не удалось установить обновление.")
        case .notWritable:
            self(
                "Stash sits in a folder it may not write to. Update it by hand.",
                "Stash лежит в каталоге, недоступном на запись. Обновите его вручную."
            )
        }
    }
}

/// Titles of the menu bar menu. The tutorial's settings scene draws the same menu.
struct StatusMenuTitles {
    let l10n: L10n

    var openStash: String { l10n("Open Stash", "Открыть Stash") }
    var tutorial: String { l10n("How to Use Stash?", "Как пользоваться Stash?") }
    var checkForUpdates: String { l10n("Check for Updates…", "Проверить обновления…") }
    var checkingForUpdates: String { l10n("Checking for Updates…", "Проверяем обновления…") }
    func updateTo(_ version: String) -> String { l10n("Update to \(version)", "Обновить до \(version)") }
    var updateAutomatically: String { l10n("Check for Updates Automatically", "Проверять обновления автоматически") }
    var closeAfterSelection: String { l10n("Close After Selection", "Закрывать после выбора") }
    var interceptKeys: String { l10n("Intercept Keys", "Перехватывать клавиши") }
    var openAtCaret: String { l10n("Open at the Cursor", "Открывать у курсора") }
    var theme: String { l10n("Theme", "Тема") }
    var language: String { l10n("Language", "Язык") }
    var clearHistory: String { l10n("Clear History", "Очистить историю") }
    var quit: String { l10n("Quit", "Выйти") }
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

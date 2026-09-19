import Foundation

/// The scene a slide plays; also the slide's identity.
enum OnboardingSceneKind: String, CaseIterable, Sendable {
    case hero, hotKey, paste, pin, images, keys, settings, access
}

/// A string in both interface languages.
struct Localized: Equatable, Sendable {
    let en: String
    let ru: String

    func callAsFunction(_ l10n: L10n) -> String {
        l10n(en, ru)
    }
}

struct OnboardingSlide: Identifiable, Equatable, Sendable {
    let kind: OnboardingSceneKind
    /// Scene length with its end hold, seconds. A looping scene then spends 0.5 s getting back to
    /// its first frame and 0.25 s paused there.
    let duration: Double
    /// The first slide plays once and stays assembled; the others loop.
    let loops: Bool
    /// Shown as a big title on the first slide only; for the others it is the VoiceOver heading.
    let word: Localized
    let text: Localized

    var id: OnboardingSceneKind { kind }
}

enum OnboardingSlides {
    /// The access slide, kept apart because it also shows on its own: the tutorial was seen, but
    /// Stash still has no Accessibility access.
    static let accessSlide = OnboardingSlide(
        kind: .access, duration: 3.0, loops: true,
        word: Localized(en: "ACCESS", ru: "ДОСТУП"),
        text: Localized(
            en: "Stash pastes by pressing ⌘V for you. macOS won't allow it without Accessibility access.",
            ru: "Stash вставляет клип, нажимая ⌘V за вас. Без Универсального доступа macOS этого не разрешит."
        )
    )

    /// Words and texts are the spec's, verbatim:
    /// docs/superpowers/specs/2026-09-19-onboarding-stories-design.md, "Слайды".
    static let all: [OnboardingSlide] = [
        OnboardingSlide(
            kind: .hero, duration: 2.6, loops: false,
            word: Localized(en: "HELLO, THIS IS", ru: "ПРИВЕТ, ЭТО"),
            text: Localized(
                en: "Stash remembers everything you copy: text, images and files. Copy something new, and the old one stays in the journal.",
                ru: "Stash запоминает всё, что вы копируете: текст, картинки и файлы. Скопировали новое — старое осталось в журнале."
            )
        ),
        OnboardingSlide(
            kind: .hotKey, duration: 2.6, loops: true,
            word: Localized(en: "OPEN", ru: "ВЫЗОВ"),
            text: Localized(
                en: "Press ⌥V anywhere — the journal opens over the current window, so you never have to switch apps.",
                ru: "Нажмите ⌥V где угодно — журнал откроется поверх текущего окна, и переключаться между приложениями не придётся."
            )
        ),
        OnboardingSlide(
            kind: .paste, duration: 3.6, loops: true,
            word: Localized(en: "PASTE", ru: "ВСТАВКА"),
            text: Localized(
                en: "Hover a clip and click the orange arrow: it lands where your cursor was and the journal closes. Double-click or Return does the same.",
                ru: "Наведите на клип и нажмите оранжевую стрелку: клип встанет туда, где стоял курсор, а журнал закроется. Двойной клик и Return — тоже."
            )
        ),
        OnboardingSlide(
            kind: .pin, duration: 4.6, loops: true,
            word: Localized(en: "PIN", ru: "ЗАКРЕП"),
            text: Localized(
                en: "Clips last a day, and new ones push out the old. Pin an address or bank details — they stay until you unpin them.",
                ru: "Клипы хранятся сутки, а новые вытесняют старые. Закрепите адрес или реквизиты — они останутся, пока вы их не открепите."
            )
        ),
        OnboardingSlide(
            kind: .images, duration: 4.2, loops: true,
            word: Localized(en: "IMAGES", ru: "КАРТИНКИ"),
            text: Localized(
                en: "Screenshots and files are saved too. The filter on top keeps one type of clip, and clicking an image opens it in Preview.",
                ru: "Скриншоты и файлы тоже сохраняются. Фильтр сверху оставит клипы одного типа, а клик по картинке откроет её в Просмотре."
            )
        ),
        OnboardingSlide(
            kind: .keys, duration: 4.2, loops: true,
            word: Localized(en: "KEYS", ru: "КЛАВИШИ"),
            text: Localized(
                en: "The journal never takes the keyboard: keep typing and your letters go to your text. ↑↓ pick a clip, Return pastes, Esc closes.",
                ru: "Журнал не забирает клавиатуру: печатайте дальше, буквы идут в ваш текст. ↑ и ↓ выбирают клип, Return вставляет, Esc закрывает."
            )
        ),
        OnboardingSlide(
            kind: .settings, duration: 4.7, loops: true,
            word: Localized(en: "SETTINGS", ru: "НАСТРОЙКИ"),
            text: Localized(
                en: "The Stash icon in the menu bar opens settings: closing after a paste, the keys, opening at the cursor, theme and language, and Tutorial.",
                ru: "Значок Stash в строке меню открывает настройки: закрытие после вставки, клавиши журнала, открытие у курсора, тему и язык. Там же «Обучение»."
            )
        ),
        accessSlide,
    ]

    /// The access slide is only for those who need it: without Accessibility access the journal
    /// does not work at all. The set is taken once, when the tutorial opens.
    static func slides(hasAccess: Bool) -> [OnboardingSlide] {
        hasAccess ? all.filter { $0.kind != .access } : all
    }
}

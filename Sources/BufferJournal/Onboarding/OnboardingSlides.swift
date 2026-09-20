import Foundation

/// The scene a slide plays; also the slide's identity.
enum OnboardingSceneKind: String, CaseIterable, Sendable {
    case hero, hotKey, paste, keys, pin, access
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
    /// The access screen. It is not part of the tour: it shows on its own whenever Stash lacks
    /// Accessibility access, whether the tour has just ended or the panel was opened later.
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
                en: "Press ⌥V to open Stash.",
                ru: "Нажмите ⌥V, чтобы открыть Stash."
            )
        ),
        OnboardingSlide(
            kind: .paste, duration: 4.0, loops: true,
            word: Localized(en: "PASTE", ru: "ВСТАВКА"),
            text: Localized(
                en: "Double-click a clip to paste it.",
                ru: "Кликните дважды по клипу, чтобы вставить его."
            )
        ),
        OnboardingSlide(
            kind: .keys, duration: 4.2, loops: true,
            word: Localized(en: "KEYS", ru: "КЛАВИШИ"),
            text: Localized(
                en: "You can also pick the clip you need with the arrow keys and paste it with Return.",
                ru: "Также нужный клип можно выбрать клавишами со стрелками и вставить нажатием Return."
            )
        ),
        OnboardingSlide(
            kind: .pin, duration: 4.6, loops: true,
            word: Localized(en: "PIN", ru: "ЗАКРЕП"),
            text: Localized(
                en: "Stash keeps the last 20 clips for a day. Pin the ones that matter — they stay at the top of the list until you unpin them.",
                ru: "Stash хранит 20 последних клипов в течение суток. Важные клипы можно закрепить — они останутся наверху списка, пока вы их не открепите."
            )
        ),
    ]
}

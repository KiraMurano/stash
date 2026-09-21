# Экран «О приложении» — план реализации

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Цель:** пункт меню «О приложении» и за ним экран на панели: лока `Stash 1.27`, строка «Сделано в OZERO.DIGITAL» шрифтом Booker Display с живой подменой букв, ссылка на репозиторий и кнопка обратной связи.

**Устройство:** новая папка `Sources/BufferJournal/About/` с четырьмя файлами — раскадровка (чистая логика), шрифт (доступ к наборам `ss01…ss06`), вид вордмарка, экран с контроллером. Экран встаёт в тот же `ZStack` `JournalView`, что тур и обновление, и подключается к меню в `AppDelegate`.

**Стек:** Swift 6, SwiftUI, AppKit, swift-testing (`import Testing`), сборка `Scripts/build_app.sh`.

Спека: [`docs/superpowers/specs/2026-09-21-about-screen-design.md`](../specs/2026-09-21-about-screen-design.md).
Концепт: [`.concepts/2026-09-21-about-screen.html`](../../../.concepts/2026-09-21-about-screen.html), вариант 1.2, кегль 56.

## Общие требования

- Комментарии в коде — по-английски, как во всём `Sources/`: объясняют «почему», а не «что». Тексты интерфейса — через `L10n`, оба языка сразу.
- Тесты — `swift test`, фреймворк `Testing` (`@Test`, `#expect`), имена тестов — предложения о поведении, как в `Tests/BufferJournalTests/UpdateTextsTests.swift`.
- Экран не берёт ни одной клавиши и не закрывается кликом мимо панели — как тур и экран обновления.
- Метрики экрана: отступы 12 / 20 / 16, шаг 10, голова 28 pt, кнопка 36 pt высотой и не уже 150, текст 13 pt, лока 18 pt semibold с иконкой 21 pt.
- Кегль вордмарка — 56 pt, цвет `palette.textPrimary`.
- Границы ширины строки: 0,90…1,04 от набора по умолчанию.
- Такты глитча: покой буквы 1,6…8,5 с, первая подмена через 0,18…0,52 с, кадр 0,058…0,096 с (последний 0,078…0,116 с), гашение 0,046…0,072 с с вероятностью 0,35, покой строки 6…16 с.
- Адреса: репозиторий `https://github.com/KiraMurano/stash`, обратная связь `https://github.com/KiraMurano/stash/issues/new`.
- Шрифт: `BookerDisplay-Regular.ttf`, PostScript-имя `BookerDisplay-Regular`, семейство `Booker Display`. Лицензия разрешает встраивать файл в приложение только вместе с самой лицензией.

---

### Задача 1: тексты меню и экрана

**Файлы:**
- Изменить: `Sources/BufferJournal/Localization.swift` (добавить строки в `L10n` и в `StatusMenuTitles`)
- Создать: `Tests/BufferJournalTests/AboutTextsTests.swift`

**Связи:**
- Потребляет: `L10n`, `StatusMenuTitles` — уже есть.
- Отдаёт: `L10n.aboutMadeIn`, `L10n.aboutFeedback`, `StatusMenuTitles.about` — их зовут задачи 5 и 6.

- [ ] **Шаг 1: написать падающий тест**

`Tests/BufferJournalTests/AboutTextsTests.swift`:

```swift
import Testing
@testable import BufferJournal

struct AboutTextsTests {
    private let ru = L10n(language: .russian)
    private let en = L10n(language: .english)

    @Test func theMenuItemNamesTheApp() {
        #expect(StatusMenuTitles(l10n: ru).about == "О приложении")
        #expect(StatusMenuTitles(l10n: en).about == "About Stash")
    }

    @Test func theScreenSaysWhoMadeIt() {
        #expect(ru.aboutMadeIn == "Сделано в")
        #expect(en.aboutMadeIn == "Made in")
    }

    @Test func theButtonAsksForFeedback() {
        #expect(ru.aboutFeedback == "Обратная связь")
        #expect(en.aboutFeedback == "Send Feedback")
    }

    @Test func everyItemInTheMenuHasATitleOfItsOwn() {
        let titles = StatusMenuTitles(l10n: ru)
        let all = [titles.openStash, titles.tutorial, titles.about, titles.clearHistory, titles.quit]
        #expect(Set(all).count == all.count)
    }
}
```

- [ ] **Шаг 2: убедиться, что тест падает**

Запустить: `swift test --filter AboutTextsTests`
Ожидается: компиляция падает — `value of type 'L10n' has no member 'aboutMadeIn'`.

- [ ] **Шаг 3: добавить строки**

В `Sources/BufferJournal/Localization.swift`, в `struct L10n`, после строк обновления:

```swift
    // MARK: About

    var aboutMadeIn: String { self("Made in", "Сделано в") }
    var aboutFeedback: String { self("Send Feedback", "Обратная связь") }
```

В `struct StatusMenuTitles`, строкой после `tutorial`:

```swift
    var about: String { l10n("About Stash", "О приложении") }
```

- [ ] **Шаг 4: убедиться, что тест проходит**

Запустить: `swift test --filter AboutTextsTests`
Ожидается: PASS, четыре теста.

- [ ] **Шаг 5: коммит**

```bash
git add Sources/BufferJournal/Localization.swift Tests/BufferJournalTests/AboutTextsTests.swift
git commit -m "Name the About screen in both languages"
```

---

### Задача 2: раскадровка вордмарка

Чистая логика: какие формы принимают буквы и как долго держится каждый кадр. Ни шрифта, ни экрана она не знает — ширины букв приходят снаружи, поэтому её целиком проверяют тесты.

**Файлы:**
- Создать: `Sources/BufferJournal/About/WordmarkStoryboard.swift`
- Создать: `Tests/BufferJournalTests/WordmarkStoryboardTests.swift`

**Связи:**
- Потребляет: ничего.
- Отдаёт: `WordmarkLetter`, `WordmarkMark`, `WordmarkStep`, `WordmarkLineStep`, `WordmarkStoryboard` (`init(letters:widths:rng:)`, `sets`, `width(of:)`, `glitch(of:using:)`, `lineGlitch(using:)`, `WordmarkStoryboard.letters`), `SeededGenerator(seed:)` — их зовут задачи 4 и 5.

- [ ] **Шаг 1: написать падающий тест**

`Tests/BufferJournalTests/WordmarkStoryboardTests.swift`:

```swift
import Testing
@testable import BufferJournal

struct WordmarkStoryboardTests {
    /// Ширины букв, похожие на настоящие: самый узкий набор вдвое короче самого широкого.
    private static let factors: [Double] = [1.0, 0.55, 1.05, 0.62, 0.86, 0.94, 1.12]

    private func widths(for letters: [WordmarkLetter]) -> [[Double]] {
        letters.enumerated().map { index, letter in
            let own = 30.0 + Double(index)
            return Self.factors.map { letter.hasAlternates ? own * $0 : own }
        }
    }

    private func storyboard(seed: UInt64) -> (WordmarkStoryboard, SeededGenerator) {
        let letters = WordmarkStoryboard.letters
        var rng = SeededGenerator(seed: seed)
        let board = WordmarkStoryboard(letters: letters, widths: widths(for: letters), rng: &rng)
        return (board, rng)
    }

    @Test func theLineStaysWithinItsWidth() {
        var (board, rng) = storyboard(seed: 1)
        let base = board.width(of: board.letters.indices.map { _ in 0 })

        for round in 0..<400 {
            let index = board.letters.indices.filter { board.letters[$0].hasAlternates }[round % 11]
            _ = board.glitch(of: index, using: &rng)
            let width = board.width(of: board.sets)
            #expect(width >= base * 0.86)
            #expect(width <= base * 1.08)
        }
    }

    @Test func aLetterNeverComesBackToTheFormItLeft() {
        var (board, rng) = storyboard(seed: 2)

        for round in 0..<200 {
            let index = board.letters.indices.filter { board.letters[$0].hasAlternates }[round % 11]
            let was = board.sets[index]
            let steps = board.glitch(of: index, using: &rng)
            #expect(steps.last?.mark.set != was)
        }
    }

    @Test func theDotKeepsTheFontsOwnForm() {
        var (board, rng) = storyboard(seed: 3)
        let dot = board.letters.firstIndex { $0.character == "." }!

        #expect(board.glitch(of: dot, using: &rng).isEmpty)
        #expect(board.sets[dot] == 0)
    }

    @Test func everyGlitchEndsInRest() {
        var (board, rng) = storyboard(seed: 4)
        let steps = board.glitch(of: 0, using: &rng)
        let rest = steps.last!

        #expect(rest.mark == WordmarkMark(set: rest.mark.set))
        #expect(WordmarkStoryboard.letterRest.contains(rest.duration))
    }

    @Test func theSameSeedGivesTheSameRun() {
        var (first, firstRNG) = storyboard(seed: 5)
        var (second, secondRNG) = storyboard(seed: 5)

        #expect(first.sets == second.sets)
        #expect(first.glitch(of: 0, using: &firstRNG) == second.glitch(of: 0, using: &secondRNG))
    }

    @Test func aLineGlitchLeavesTheLettersAlone() {
        var (board, rng) = storyboard(seed: 6)
        let before = board.sets

        let steps = board.lineGlitch(using: &rng)
        #expect(board.sets == before)
        #expect(steps.last?.duration ?? 0 >= WordmarkStoryboard.lineRest.lowerBound)
    }
}
```

- [ ] **Шаг 2: убедиться, что тест падает**

Запустить: `swift test --filter WordmarkStoryboardTests`
Ожидается: компиляция падает — `cannot find 'WordmarkStoryboard' in scope`.

- [ ] **Шаг 3: написать раскадровку**

`Sources/BufferJournal/About/WordmarkStoryboard.swift`:

```swift
import Foundation

/// A letter of the wordmark. The dot has no alternate forms in the font, so it never changes.
struct WordmarkLetter: Equatable {
    let character: Character
    let hasAlternates: Bool
}

/// How one letter is drawn at a given moment: which stylistic set (0 is the font's own form,
/// 1…6 are ss01…ss06) and what a glitch leaves on it.
struct WordmarkMark: Equatable {
    var set: Int
    var dx: Double = 0
    var dy: Double = 0
    var skew: Double = 0
    /// How far the two coloured shadows move apart, in points; 0 draws none.
    var aberration: Double = 0
    var aberrationDY: Double = 0
    /// The letter is gone for this frame.
    var isDim: Bool = false
}

/// A mark and how long it holds, in seconds.
struct WordmarkStep: Equatable {
    var mark: WordmarkMark
    var duration: Double
}

/// A glitch over the whole line. It never changes the letters, only shakes the setting.
struct WordmarkLineStep: Equatable {
    var dx: Double = 0
    var dy: Double = 0
    var skew: Double = 0
    var scaleY: Double = 1
    var aberration: Double = 0
    var aberrationDY: Double = 0
    var duration: Double
}

/// Picks the forms the wordmark's letters take, and how long each frame holds.
///
/// A free choice would make the word jump about: the narrowest setting of "OZERO.DIGITAL" is
/// about half the widest. So a new form is only taken when the line stays within the width of
/// the font's own setting, and the choice is made against what the neighbours show right now.
struct WordmarkStoryboard {
    static let word = "OZERO.DIGITAL"
    /// ss01…ss06.
    static let sets = Array(1...6)
    /// Bounds of the line's width, as a share of the default setting.
    static let narrowest = 0.90
    static let widest = 1.04
    /// A letter's rest between its own substitutions.
    static let letterRest: ClosedRange<Double> = 1.6...8.5
    /// The first substitution after the screen opens — of one letter, not of the word.
    static let firstRest: ClosedRange<Double> = 0.18...0.52
    /// Rest between glitches of the whole line.
    static let lineRest: ClosedRange<Double> = 6...16

    static var letters: [WordmarkLetter] {
        word.map { WordmarkLetter(character: $0, hasAlternates: $0.isLetter) }
    }

    let letters: [WordmarkLetter]
    /// widths[letter][set], set 0…6, at the size they were measured.
    let widths: [[Double]]
    private(set) var sets: [Int]

    private let lowerWidth: Double
    private let upperWidth: Double

    init(letters: [WordmarkLetter], widths: [[Double]], rng: inout some RandomNumberGenerator) {
        self.letters = letters
        self.widths = widths
        let base = letters.indices.reduce(0.0) { $0 + widths[$1][0] }
        lowerWidth = base * Self.narrowest
        upperWidth = base * Self.widest
        sets = letters.map { _ in 0 }
        seed(using: &rng)
    }

    func width(of sets: [Int]) -> Double {
        sets.indices.reduce(0.0) { $0 + widths[$1][sets[$1]] }
    }

    /// One substitution: two to four intermediate forms, then rest in the new one. The rest is
    /// the last step's own duration — counted apart, it would be waited out twice.
    mutating func glitch(of index: Int, using rng: inout some RandomNumberGenerator) -> [WordmarkStep] {
        guard letters[index].hasAlternates else { return [] }

        let was = sets[index]
        var steps: [WordmarkStep] = []
        let hops = Int.random(in: 2...4, using: &rng)

        for hop in 0..<hops {
            let isLast = hop == hops - 1
            // On the last hop the form it came from is barred: otherwise the letter "changes"
            // into itself and the glitch is left without a reason.
            sets[index] = alternate(for: index, avoiding: isLast ? was : nil, using: &rng)
            steps.append(
                WordmarkStep(
                    mark: WordmarkMark(
                        set: sets[index],
                        dx: isLast ? 0 : .random(in: -2.5...2.5, using: &rng),
                        dy: isLast ? 0 : .random(in: -1.5...1.5, using: &rng),
                        skew: isLast ? 0 : .random(in: -12...12, using: &rng),
                        aberration: isLast
                            ? .random(in: 1...2, using: &rng)
                            : .random(in: 2...5, using: &rng),
                        aberrationDY: isLast ? 0 : .random(in: -1...1, using: &rng)
                    ),
                    duration: isLast
                        ? .random(in: 0.078...0.116, using: &rng)
                        : .random(in: 0.058...0.096, using: &rng)
                )
            )

            if !isLast, Double.random(in: 0...1, using: &rng) < 0.35 {
                steps.append(
                    WordmarkStep(
                        mark: WordmarkMark(set: sets[index], isDim: true),
                        duration: .random(in: 0.046...0.072, using: &rng)
                    )
                )
            }
        }

        steps.append(
            WordmarkStep(
                mark: WordmarkMark(set: sets[index]),
                duration: .random(in: Self.letterRest, using: &rng)
            )
        )
        return steps
    }

    /// The channels split, or the setting jolts. Either way the last step is the rest until the
    /// next glitch.
    func lineGlitch(using rng: inout some RandomNumberGenerator) -> [WordmarkLineStep] {
        let rest = WordmarkLineStep(duration: .random(in: Self.lineRest, using: &rng))

        if Bool.random(using: &rng) {
            let far = Double.random(in: 2...4.5, using: &rng)
            return [
                WordmarkLineStep(
                    dx: .random(in: -1.5...1.5, using: &rng),
                    aberration: far,
                    aberrationDY: .random(in: -1...1, using: &rng),
                    duration: .random(in: 0.105...0.160, using: &rng)
                ),
                WordmarkLineStep(aberration: -far * 0.6, duration: .random(in: 0.085...0.125, using: &rng)),
                rest,
            ]
        }

        return [
            WordmarkLineStep(
                dx: .random(in: -3...3, using: &rng),
                dy: .random(in: -2...2, using: &rng),
                skew: .random(in: -5...5, using: &rng),
                scaleY: .random(in: 0.94...1.06, using: &rng),
                duration: .random(in: 0.070...0.120, using: &rng)
            ),
            rest,
        ]
    }

    /// A new form for one letter, chosen so the line keeps its width. When nothing fits, the
    /// form that misses by the least: better to move the edge by a couple of points than to
    /// leave the letter as it was.
    private func alternate(
        for index: Int,
        avoiding avoided: Int?,
        using rng: inout some RandomNumberGenerator
    ) -> Int {
        let rest = width(of: sets) - widths[index][sets[index]]
        func miss(_ set: Int) -> Double {
            let total = rest + widths[index][set]
            return Swift.max(lowerWidth - total, total - upperWidth, 0)
        }

        let options = Self.sets.filter { $0 != sets[index] && $0 != avoided }
        let fitting = options.filter { miss($0) == 0 }
        return fitting.randomElement(using: &rng) ?? options.min { miss($0) < miss($1) }!
    }

    /// The setting the word opens in: random forms, nudged until the line fits.
    private mutating func seed(using rng: inout some RandomNumberGenerator) {
        sets = letters.map { $0.hasAlternates ? Self.sets.randomElement(using: &rng)! : 0 }
        let changeable = letters.indices.filter { letters[$0].hasAlternates }

        for _ in 0..<200 {
            let total = width(of: sets)
            guard total < lowerWidth || total > upperWidth else { break }
            let index = changeable.randomElement(using: &rng)!
            sets[index] = alternate(for: index, avoiding: nil, using: &rng)
        }
    }
}

/// SplitMix64. The tests seed it to get the same run twice; the screen seeds it from the clock.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
```

- [ ] **Шаг 4: убедиться, что тесты проходят**

Запустить: `swift test --filter WordmarkStoryboardTests`
Ожидается: PASS, шесть тестов.

- [ ] **Шаг 5: коммит**

```bash
git add Sources/BufferJournal/About/WordmarkStoryboard.swift Tests/BufferJournalTests/WordmarkStoryboardTests.swift
git commit -m "Lay out the wordmark's letter glitch"
```

---

### Задача 3: шрифт в проекте и в бандле

**Файлы:**
- Создать: `Resources/Fonts/BookerDisplay-Regular.ttf`, `Resources/Fonts/BookerDisplay-LICENSE.txt` (копии из `/Users/ozero/IT/mrbooker/brand/fonts/`)
- Изменить: `Info.plist`, `Scripts/build_app.sh:20`, `README.md`

**Связи:**
- Потребляет: ничего.
- Отдаёт: шрифт `BookerDisplay-Regular` в бандле, зарегистрированный системой, — его зовёт задача 4.

- [ ] **Шаг 1: положить файлы в проект**

```bash
mkdir -p Resources/Fonts
cp /Users/ozero/IT/mrbooker/brand/fonts/BookerDisplay-Regular.ttf Resources/Fonts/
cp /Users/ozero/IT/mrbooker/brand/fonts/BookerDisplay-LICENSE.txt Resources/Fonts/
```

- [ ] **Шаг 2: прописать папку шрифтов в Info.plist**

В `Info.plist`, первой парой внутри `<dict>` (ключи идут по алфавиту):

```xml
	<key>ATSApplicationFontsPath</key>
	<string>Fonts</string>
```

- [ ] **Шаг 3: копировать шрифт в бандл при сборке**

В `Scripts/build_app.sh`, сразу после строки, копирующей значки (строка 20):

```bash
# The About screen sets the wordmark in Booker Display. Its licence allows the file inside an
# app, but only travelling together with the licence itself, so both go into the bundle.
cp -R "Resources/Fonts" "$CONTENTS_DIR/Resources/Fonts"
```

- [ ] **Шаг 4: собрать и проверить, что шрифт на месте**

```bash
Scripts/build_app.sh
ls .build/Stash.app/Contents/Resources/Fonts
plutil -p .build/Stash.app/Contents/Info.plist | grep ATSApplicationFontsPath
```

Ожидается: в папке оба файла — `BookerDisplay-Regular.ttf` и `BookerDisplay-LICENSE.txt`; `plutil` печатает `"ATSApplicationFontsPath" => "Fonts"`.

- [ ] **Шаг 5: дописать README**

В `README.md`, в раздел `## Build`, абзацем после строки про сборку значков:

```markdown
The wordmark on the About screen is set in Booker Display, a typeface of ozero.digital. Its file
lives in `Resources/Fonts` next to its licence, which allows the font inside an app as long as the
two travel together; `Scripts/build_app.sh` copies both into the bundle, and `ATSApplicationFontsPath`
in `Info.plist` has macOS register the font at launch.
```

- [ ] **Шаг 6: коммит**

```bash
git add Resources/Fonts Info.plist Scripts/build_app.sh README.md
git commit -m "Carry Booker Display in the bundle"
```

---

### Задача 4: вордмарк на экране

**Файлы:**
- Создать: `Sources/BufferJournal/About/WordmarkFont.swift`
- Создать: `Sources/BufferJournal/About/Wordmark.swift`
- Создать: `Tests/BufferJournalTests/WordmarkFontTests.swift`

**Связи:**
- Потребляет: `WordmarkStoryboard`, `WordmarkLetter`, `WordmarkMark`, `WordmarkLineStep`, `SeededGenerator` из задачи 2; шрифт из задачи 3.
- Отдаёт: `Wordmark(size:color:)` — его зовёт задача 5.

- [ ] **Шаг 1: написать падающий тест**

`Tests/BufferJournalTests/WordmarkFontTests.swift`:

```swift
import AppKit
import Testing
@testable import BufferJournal

struct WordmarkFontTests {
    @Test func aSetAsksTheFontForItsOpenTypeFeature() {
        let features = WordmarkFont.featureSettings(set: 3)
        let tag = features.first?[NSFontDescriptor.FeatureKey(rawValue: kCTFontOpenTypeFeatureTag as String)] as? String

        #expect(features.count == 1)
        #expect(tag == "ss03")
    }

    @Test func theFontsOwnFormAsksForNothing() {
        #expect(WordmarkFont.featureSettings(set: 0).isEmpty)
    }

    /// Without the bundle there is no font, and the screen must still draw the line.
    @Test func everyLetterIsMeasuredInEverySet() {
        let letters = WordmarkStoryboard.letters
        let widths = WordmarkFont.widths(of: letters, size: 56)

        #expect(widths.count == letters.count)
        #expect(widths.allSatisfy { $0.count == 7 })
        #expect(widths.allSatisfy { $0.allSatisfy { $0 > 0 } })
    }
}
```

- [ ] **Шаг 2: убедиться, что тест падает**

Запустить: `swift test --filter WordmarkFontTests`
Ожидается: компиляция падает — `cannot find 'WordmarkFont' in scope`.

- [ ] **Шаг 3: написать доступ к шрифту**

`Sources/BufferJournal/About/WordmarkFont.swift`:

```swift
import AppKit

/// Booker Display, one stylistic set at a time.
///
/// SwiftUI has no way to ask for an OpenType feature, so the set is put on an `NSFont` through a
/// descriptor. A descriptor's features cover a whole run of text — that is why the wordmark is
/// drawn letter by letter, each `Text` with a font of its own.
enum WordmarkFont {
    /// The font's PostScript name. It is registered by `ATSApplicationFontsPath` in Info.plist,
    /// so a build run straight from SwiftPM — without a bundle — does not have it.
    static let name = "BookerDisplay-Regular"

    private static let tagKey = NSFontDescriptor.FeatureKey(rawValue: kCTFontOpenTypeFeatureTag as String)
    private static let valueKey = NSFontDescriptor.FeatureKey(rawValue: kCTFontOpenTypeFeatureValue as String)

    static var isAvailable: Bool {
        NSFont(name: name, size: 12) != nil
    }

    /// Set 0 is the font's own form and asks for no feature at all.
    static func featureSettings(set: Int) -> [[NSFontDescriptor.FeatureKey: Any]] {
        guard set > 0 else { return [] }
        return [[tagKey: String(format: "ss%02d", set), valueKey: 1]]
    }

    static func font(size: CGFloat, set: Int) -> NSFont? {
        guard let base = NSFont(name: name, size: size) else { return nil }
        let settings = featureSettings(set: set)
        guard !settings.isEmpty else { return base }

        let descriptor = base.fontDescriptor.addingAttributes([.featureSettings: settings])
        return NSFont(descriptor: descriptor, size: size)
    }

    /// The width of every letter in every set, measured once. The storyboard adds these up
    /// instead of laying the line out again on every frame.
    static func widths(of letters: [WordmarkLetter], size: CGFloat) -> [[Double]] {
        letters.map { letter in
            (0...6).map { set in
                let font = font(size: size, set: letter.hasAlternates ? set : 0)
                    ?? .systemFont(ofSize: size, weight: .semibold)
                let text = NSAttributedString(string: String(letter.character), attributes: [.font: font])
                return Double(text.size().width)
            }
        }
    }
}
```

- [ ] **Шаг 4: убедиться, что тесты проходят**

Запустить: `swift test --filter WordmarkFontTests`
Ожидается: PASS, три теста. Шрифта в тестовом процессе нет, поэтому ширины меряются системным шрифтом — тест проверяет только, что мера взята со всех букв и наборов.

- [ ] **Шаг 5: написать вид вордмарка**

`Sources/BufferJournal/About/Wordmark.swift`:

```swift
import AppKit
import SwiftUI

/// "OZERO.DIGITAL" in Booker Display: the letters change their form on their own, each in its
/// own time, and every change comes as a glitch.
struct Wordmark: View {
    let size: CGFloat
    let color: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var glitch: WordmarkGlitch

    init(size: CGFloat, color: Color) {
        self.size = size
        self.color = color
        _glitch = StateObject(wrappedValue: WordmarkGlitch(size: size))
    }

    /// The channels of a broken screen: red and cyan, the sRGB of the oklch pair the studio's
    /// own page uses. The app's orange would read as a reflection of the button below, not as
    /// interference.
    private static let redGhost = Color(red: 0.91, green: 0.16, blue: 0.20)
    private static let cyanGhost = Color(red: 0.25, green: 0.74, blue: 0.86)

    var body: some View {
        line
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("OZERO.DIGITAL")
            .task {
                guard !reduceMotion, WordmarkFont.isAvailable else { return }
                glitch.start()
            }
            .onDisappear { glitch.stop() }
    }

    @ViewBuilder
    private var line: some View {
        if WordmarkFont.isAvailable {
            HStack(spacing: 0) {
                ForEach(Array(glitch.letters.enumerated()), id: \.offset) { index, letter in
                    letterView(letter, mark: glitch.marks[index])
                }
            }
            .offset(x: glitch.line.dx, y: glitch.line.dy)
            .scaleEffect(x: 1, y: glitch.line.scaleY)
            .transformEffect(Self.skew(glitch.line.skew))
            .shadow(color: Self.redGhost, radius: 0, x: -glitch.line.aberration, y: glitch.line.aberrationDY)
            .shadow(color: Self.cyanGhost, radius: 0, x: glitch.line.aberration, y: -glitch.line.aberrationDY)
        } else {
            // A build run without the bundle has no font to set this in; the line still has to
            // read, so it falls back to the system face and stands still.
            Text(WordmarkStoryboard.word)
                .font(.system(size: size * 0.72, weight: .semibold))
                .tracking(size * 0.02)
                .foregroundStyle(color)
        }
    }

    private func letterView(_ letter: WordmarkLetter, mark: WordmarkMark) -> some View {
        let font = WordmarkFont.font(size: size, set: mark.set)
            ?? .systemFont(ofSize: size, weight: .semibold)

        return Text(String(letter.character))
            .font(Font(font))
            .foregroundStyle(color)
            .opacity(mark.isDim ? 0 : 1)
            .shadow(color: Self.redGhost, radius: 0, x: -mark.aberration, y: mark.aberrationDY)
            .shadow(color: Self.cyanGhost, radius: 0, x: mark.aberration, y: -mark.aberrationDY)
            .offset(x: mark.dx, y: mark.dy)
            .transformEffect(Self.skew(mark.skew))
    }

    /// SwiftUI has no skew of its own; the transform does what `skewX` does in the browser.
    private static func skew(_ degrees: Double) -> CGAffineTransform {
        CGAffineTransform(a: 1, b: 0, c: CGFloat(tan(-degrees * .pi / 180)), d: 1, tx: 0, ty: 0)
    }
}

/// Runs the wordmark: one task per letter, so the word never ticks as one, and one more for the
/// glitch that goes over the whole line.
@MainActor
final class WordmarkGlitch: ObservableObject {
    let letters = WordmarkStoryboard.letters

    @Published private(set) var marks: [WordmarkMark]
    @Published private(set) var line = WordmarkLineStep(duration: 0)

    private var storyboard: WordmarkStoryboard
    private var rng: SeededGenerator
    private var tasks: [Task<Void, Never>] = []

    init(size: CGFloat) {
        var rng = SeededGenerator(seed: UInt64.random(in: UInt64.min...UInt64.max))
        let letters = WordmarkStoryboard.letters
        let storyboard = WordmarkStoryboard(
            letters: letters,
            widths: WordmarkFont.widths(of: letters, size: size),
            rng: &rng
        )

        self.rng = rng
        self.storyboard = storyboard
        marks = storyboard.sets.map { WordmarkMark(set: $0) }
    }

    func start() {
        guard tasks.isEmpty else { return }

        for index in letters.indices where letters[index].hasAlternates {
            tasks.append(Task { [weak self] in await self?.run(letter: index) })
        }
        tasks.append(Task { [weak self] in await self?.runLine() })
    }

    /// The screen is gone: nothing is counted while nobody looks.
    func stop() {
        tasks.forEach { $0.cancel() }
        tasks.removeAll()
    }

    private func run(letter index: Int) async {
        await rest(.random(in: WordmarkStoryboard.firstRest, using: &rng))

        while !Task.isCancelled {
            for step in storyboard.glitch(of: index, using: &rng) {
                marks[index] = step.mark
                await rest(step.duration)
                if Task.isCancelled { return }
            }
        }
    }

    private func runLine() async {
        while !Task.isCancelled {
            for step in storyboard.lineGlitch(using: &rng) {
                line = step
                await rest(step.duration)
                if Task.isCancelled { return }
            }
        }
    }

    private func rest(_ seconds: Double) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}
```

- [ ] **Шаг 6: убедиться, что всё собирается и тесты целы**

Запустить: `swift build && swift test`
Ожидается: сборка без ошибок, все тесты проходят.

- [ ] **Шаг 7: коммит**

```bash
git add Sources/BufferJournal/About/WordmarkFont.swift Sources/BufferJournal/About/Wordmark.swift Tests/BufferJournalTests/WordmarkFontTests.swift
git commit -m "Set the wordmark in Booker Display"
```

---

### Задача 5: экран и его контроллер

**Файлы:**
- Создать: `Sources/BufferJournal/About/AboutController.swift`
- Создать: `Sources/BufferJournal/About/AboutView.swift`
- Создать: `Tests/BufferJournalTests/AboutControllerTests.swift`

**Связи:**
- Потребляет: `Wordmark(size:color:)` из задачи 4, `L10n.aboutMadeIn` / `L10n.aboutFeedback` из задачи 1, `UpdateEnvironment.current()`, `OnboardingColors`, `OnboardingPrimaryButtonStyle`, `OnboardingCloseButtonStyle`, `ThemePalette`, `WindowDragHandle`.
- Отдаёт: `AboutController` (`isPresented`, `present()`, `close()`, `openRepository()`, `openFeedback()`, `currentVersion`), `AboutView(controller:l10n:)` — их зовёт задача 6.

- [ ] **Шаг 1: написать падающий тест**

`Tests/BufferJournalTests/AboutControllerTests.swift`:

```swift
import Testing
@testable import BufferJournal

@MainActor
struct AboutControllerTests {
    @Test func theScreenIsShownOnlyWhenAsked() {
        let controller = AboutController(environment: UpdateEnvironment.current())
        #expect(!controller.isPresented)

        controller.present()
        #expect(controller.isPresented)

        controller.close()
        #expect(!controller.isPresented)
    }

    @Test func theButtonAndTheLinkLeadToDifferentPages() {
        #expect(AboutController.repository.absoluteString == "https://github.com/KiraMurano/stash")
        #expect(AboutController.feedback.absoluteString == "https://github.com/KiraMurano/stash/issues/new")
    }

    /// A source build has no released version, and the lockup then names the app alone.
    @Test func aBuildWithoutAVersionSaysNothingAboutIt() {
        let environment = UpdateEnvironment(
            currentVersion: nil,
            requirement: nil,
            bundleURL: URL(fileURLWithPath: "/tmp"),
            isDestinationWritable: false
        )

        #expect(AboutController(environment: environment).currentVersion == nil)
    }
}
```

- [ ] **Шаг 2: убедиться, что тест падает**

Запустить: `swift test --filter AboutControllerTests`
Ожидается: компиляция падает — `cannot find 'AboutController' in scope`.

- [ ] **Шаг 3: написать контроллер**

`Sources/BufferJournal/About/AboutController.swift`:

```swift
import AppKit
import Foundation

/// The About screen: it is either on the panel or not, and it knows the two pages it opens.
/// Keeping the URLs here leaves the screen itself without any knowledge of the outside world.
@MainActor
final class AboutController: ObservableObject {
    static let repository = URL(string: "https://github.com/KiraMurano/stash")!
    /// Stash has no server to take a message, the way the studio's other apps do, so feedback
    /// goes where the source is.
    static let feedback = URL(string: "https://github.com/KiraMurano/stash/issues/new")!

    @Published private(set) var isPresented = false

    private let environment: UpdateEnvironment

    init(environment: UpdateEnvironment = .current()) {
        self.environment = environment
    }

    /// Nil in a build made from source: it keeps the placeholder version, which is not one.
    var currentVersion: AppVersion? {
        environment.currentVersion
    }

    func present() {
        isPresented = true
    }

    func close() {
        isPresented = false
    }

    func openRepository() {
        NSWorkspace.shared.open(Self.repository)
    }

    func openFeedback() {
        NSWorkspace.shared.open(Self.feedback)
    }
}
```

- [ ] **Шаг 4: убедиться, что тесты проходят**

Запустить: `swift test --filter AboutControllerTests`
Ожидается: PASS, три теста.

- [ ] **Шаг 5: написать экран**

`Sources/BufferJournal/About/AboutView.swift`:

```swift
import AppKit
import SwiftUI

/// The About screen over the journal panel. Its head and footer are the update screen's, to the
/// pixel; the middle is bare field, as on an update check that found nothing — one thing, the
/// one the screen was opened for, standing on the window's own background (concept 1.2).
struct AboutView: View {
    @ObservedObject var controller: AboutController
    let l10n: L10n

    @Environment(\.colorScheme) private var colorScheme

    private enum Metrics {
        static let top: CGFloat = 12
        static let side: CGFloat = 20
        static let bottom: CGFloat = 16
        static let gap: CGFloat = 10
        static let headHeight: CGFloat = 28
        static let buttonHeight: CGFloat = 36
        static let textSize: CGFloat = 13
        static let titleSize: CGFloat = 18
        static let iconFrame: CGFloat = 21
        /// The wordmark: 56 pt takes 384 pt of the 600 pt column at its widest setting, so it
        /// still fits the smallest panel (concept round 1).
        static let wordmarkSize: CGFloat = 56
        /// Between "Made in" and the wordmark under it.
        static let madeInGap: CGFloat = 12
    }

    private var colors: OnboardingColors {
        OnboardingColors(isDark: colorScheme == .dark)
    }

    private var palette: ThemePalette {
        ThemePalette(colorScheme: colorScheme, solid: true)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            colors.field

            VStack(spacing: 0) {
                head
                studio
                footer
                    .padding(.top, Metrics.gap)
            }
            .padding(.top, Metrics.top)
            .padding(.horizontal, Metrics.side)
            .padding(.bottom, Metrics.bottom)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(l10n("About Stash", "О приложении Stash"))
        .accessibilityAddTraits(.isModal)
    }

    // MARK: Head

    private var head: some View {
        HStack(spacing: 12) {
            lockup
            Spacer(minLength: 0)
            closeButton
        }
        .frame(height: Metrics.headHeight)
        // The head row moves the panel, like the journal's header and the update screen's.
        .background(WindowDragHandle())
    }

    private var lockup: some View {
        let capHeight = NSFont.systemFont(ofSize: Metrics.titleSize, weight: .semibold).capHeight
        let version = controller.currentVersion.map { " \($0)" } ?? ""

        return HStack(spacing: 2) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: Metrics.iconFrame, height: Metrics.iconFrame)
                .accessibilityHidden(true)

            (Text("Stash").foregroundColor(palette.accentText) + Text(version))
                .font(.system(size: Metrics.titleSize, weight: .semibold))
                .foregroundStyle(palette.textPrimary)
                .alignmentGuide(VerticalAlignment.center) { $0[.firstTextBaseline] - capHeight / 2 }
                .accessibilityAddTraits(.isHeader)
        }
    }

    private var closeButton: some View {
        Button {
            controller.close()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(OnboardingCloseButtonStyle(color: colors.close))
        .help(l10n("Close", "Закрыть"))
        .accessibilityLabel(l10n("Close", "Закрыть"))
    }

    // MARK: Middle

    private var studio: some View {
        VStack(spacing: Metrics.madeInGap) {
            Text(l10n.aboutMadeIn)
                .font(.system(size: Metrics.textSize))
                .foregroundStyle(palette.textSecondary)

            Wordmark(size: Metrics.wordmarkSize, color: palette.textPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Footer

    private var footer: some View {
        HStack(alignment: .center, spacing: 16) {
            Button {
                controller.openRepository()
            } label: {
                Text(AboutController.repository.host.map { "\($0)\(AboutController.repository.path)" } ?? "")
                    .font(.system(size: Metrics.textSize))
                    .foregroundStyle(palette.textSecondary)
                    .underline(true, color: palette.textTertiary)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                controller.openFeedback()
            } label: {
                Text(l10n.aboutFeedback)
                    .font(.system(size: Metrics.textSize, weight: .semibold))
                    .padding(.horizontal, 16)
                    .frame(minWidth: 150, minHeight: Metrics.buttonHeight, maxHeight: Metrics.buttonHeight)
            }
            .buttonStyle(OnboardingPrimaryButtonStyle(colors: colors))
        }
    }
}
```

- [ ] **Шаг 6: убедиться, что всё собирается**

Запустить: `swift build && swift test`
Ожидается: сборка без ошибок, все тесты проходят.

- [ ] **Шаг 7: коммит**

```bash
git add Sources/BufferJournal/About Tests/BufferJournalTests/AboutControllerTests.swift
git commit -m "Put the About screen on the panel"
```

---

### Задача 6: экран в панели и пункт в меню

**Файлы:**
- Изменить: `Sources/BufferJournal/JournalKeys.swift` (случай `.about` и разбор того, что на панели)
- Изменить: `Sources/BufferJournal/JournalView.swift:45` (свойство), `:152` (ZStack), `:187` (анимация)
- Изменить: `Sources/BufferJournal/JournalPanelController.swift` (свойство, `showAbout()`, `showUpdate()`, `panelContent`, `makePanelIfNeeded`)
- Изменить: `Sources/BufferJournal/AppDelegate.swift` (контроллер, пункт меню, действие)
- Создать: `Tests/BufferJournalTests/PanelContentTests.swift`

**Связи:**
- Потребляет: `AboutController`, `AboutView` из задачи 5.
- Отдаёт: `JournalKeys.content(onboardingPresented:onboardingIsAccess:aboutPresented:updatePresented:accessGranted:)`.

- [ ] **Шаг 1: написать падающий тест**

`Tests/BufferJournalTests/PanelContentTests.swift`:

```swift
import Testing
@testable import BufferJournal

struct PanelContentTests {
    @Test func theTutorialCoversEveryOtherScreen() {
        let content = JournalKeys.content(
            onboardingPresented: true,
            onboardingIsAccess: false,
            aboutPresented: true,
            updatePresented: true,
            accessGranted: true
        )
        #expect(content == .onboarding)
    }

    @Test func theAboutScreenCoversTheUpdateScreen() {
        let content = JournalKeys.content(
            onboardingPresented: false,
            onboardingIsAccess: false,
            aboutPresented: true,
            updatePresented: true,
            accessGranted: true
        )
        #expect(content == .about)
    }

    @Test func withoutAccessTheJournalGivesWayToTheAccessSlide() {
        let content = JournalKeys.content(
            onboardingPresented: false,
            onboardingIsAccess: false,
            aboutPresented: false,
            updatePresented: false,
            accessGranted: false
        )
        #expect(content == .access)
    }

    @Test func theAboutScreenTakesNoKeys() {
        let mode = JournalKeys.mode(
            intercepts: true,
            panelVisible: true,
            content: .about,
            stashActive: false,
            menuOpen: false
        )
        #expect(mode == .off)
    }
}
```

- [ ] **Шаг 2: убедиться, что тест падает**

Запустить: `swift test --filter PanelContentTests`
Ожидается: компиляция падает — `type 'JournalKeys' has no member 'content'`.

- [ ] **Шаг 3: добавить случай и разбор в JournalKeys**

В `Sources/BufferJournal/JournalKeys.swift`, в `enum PanelContent`, после случая `update`:

```swift
        /// The About screen: like the tutorial, it takes no keys at all.
        case about
```

Там же, внутри `final class JournalKeys`, рядом с `mode`:

```swift
    /// What the panel shows right now. The tutorial covers everything, the About screen covers
    /// the update screen, and without access the journal gives way to the access slide — which
    /// counts the same in both of its looks, last in the tutorial and on its own.
    nonisolated static func content(
        onboardingPresented: Bool,
        onboardingIsAccess: Bool,
        aboutPresented: Bool,
        updatePresented: Bool,
        accessGranted: Bool
    ) -> PanelContent {
        if onboardingPresented {
            return onboardingIsAccess ? .access : .onboarding
        }
        if aboutPresented {
            return .about
        }
        if updatePresented {
            return .update
        }
        return accessGranted ? .journal : .access
    }
```

И в `switch content` внутри `mode` дописать `.about` к списку экранов, что не берут клавиш:

```swift
        case .onboarding, .access, .update, .about: return .off
```

- [ ] **Шаг 4: убедиться, что тесты проходят**

Запустить: `swift test --filter PanelContentTests`
Ожидается: PASS, четыре теста.

- [ ] **Шаг 5: показать экран в JournalView**

В `Sources/BufferJournal/JournalView.swift`, рядом с `@ObservedObject var updates: UpdateController` (строка 45):

```swift
    @ObservedObject var about: AboutController
```

В `ZStack`, между блоком `updates.isPresented` и блоком тура (после строки 156):

```swift
            // The About screen covers the update screen; the tutorial, if it is up, covers both.
            if about.isPresented {
                AboutView(controller: about, l10n: l10n)
                    .transition(.opacity)
                    .zIndex(36)
            }
```

Рядом с остальными анимациями (после строки 187):

```swift
        .animation(.easeOut(duration: 0.2), value: about.isPresented)
```

- [ ] **Шаг 6: завести контроллер в панели**

В `Sources/BufferJournal/JournalPanelController.swift`: свойство рядом с `private let updates: UpdateController`:

```swift
    private let about: AboutController
```

Параметр в `init` после `updates: UpdateController` и присваивание `self.about = about` рядом с `self.updates = updates`.

Передача во вью в `makePanelIfNeeded`, рядом с `updates: updates`:

```swift
            about: about,
```

Показ экрана, строкой после `showUpdate()`:

```swift
    /// The menu item: the About screen comes up on the panel, wherever the panel opens. It and
    /// the update screen never share the panel — the newer one takes it.
    func showAbout() {
        updates.close()
        about.present()
        show()
    }
```

И в самом `showUpdate()`, первой строкой:

```swift
        about.close()
```

`panelContent` заменяется на разбор из `JournalKeys`:

```swift
    private var panelContent: JournalKeys.PanelContent {
        JournalKeys.content(
            onboardingPresented: onboarding.isPresented,
            onboardingIsAccess: onboarding.slide.kind == .access,
            aboutPresented: about.isPresented,
            updatePresented: updates.isPresented,
            accessGranted: access.isGranted
        )
    }
```

Экран должен менять клавиши и слежение за кликами, как обновление, — подписка рядом с `updatesObserver`:

```swift
    private var aboutObserver: AnyCancellable?
```

```swift
        // The About screen covers the journal, so it changes both the keys and the outside clicks.
        aboutObserver = about.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in
                self?.updateKeys()
                self?.updateOutsideClicks()
            }
        }
```

- [ ] **Шаг 7: завести пункт меню**

В `Sources/BufferJournal/AppDelegate.swift`: свойство рядом с `private var updates: UpdateController!`:

```swift
    private var about: AboutController!
```

Создание в `applicationDidFinishLaunching`, строкой после создания `updates`:

```swift
        about = AboutController()
```

Передача в `JournalPanelController(...)` рядом с `updates: updates`:

```swift
            about: about,
```

Пункт в `rebuildMenu()`, строкой после пункта тура:

```swift
        // Always there, in a source build too: such a build has a version and an author no less.
        menu.addItem(menuItem(titles.about, action: #selector(openAbout)))
```

Действие рядом с `openTutorial`:

```swift
    @objc private func openAbout() {
        panelController.showAbout()
    }
```

- [ ] **Шаг 8: собрать и прогнать все тесты**

Запустить: `swift build && swift test`
Ожидается: сборка без ошибок, все тесты проходят.

- [ ] **Шаг 9: коммит**

```bash
git add Sources/BufferJournal Tests/BufferJournalTests/PanelContentTests.swift
git commit -m "Open the About screen from the menu"
```

---

### Задача 7: проверка в собранном приложении и README

**Файлы:**
- Изменить: `README.md`
- Проверить: `.build/Stash.app`

**Связи:**
- Потребляет: всё из задач 1–6.
- Отдаёт: ничего.

- [ ] **Шаг 1: собрать приложение**

```bash
Scripts/build_app.sh
open .build/Stash.app
```

- [ ] **Шаг 2: пройти экран руками**

В строке меню: «О приложении» стоит под «Как пользоваться Stash?». Нажать. Проверить:

1. Панель открывается с экраном; в голове иконка и `Stash` оранжевым (версии не будет: сборка без номера).
2. Строка `OZERO.DIGITAL` набрана Booker Display, а не системным шрифтом, и буквы сами меняют начертание — первая подмена в первые полсекунды.
3. Строка держит своё место: слово не уезжает вбок и не вылезает за края панели, в том числе если сузить панель до минимума.
4. Нажатие на ссылку открывает репозиторий, на кнопку — форму нового issue.
5. Крестик закрывает экран и возвращает журнал.
6. Пока экран открыт, ↑/↓, Return и Esc уходят в приложение под панелью, а не в журнал.
7. «Проверить обновления…» поверх открытого экрана «О приложении» показывает обновление, а не два экрана разом; и наоборот.
8. Тёмная тема и английский язык: строки на месте, кнопка читается.

- [ ] **Шаг 3: проверить покой при «Уменьшении движения»**

Включить «Системные настройки → Универсальный доступ → Дисплей → Уменьшение движения», открыть экран заново. Ожидается: строка стоит в одной сборке и не меняется. Выключить обратно.

- [ ] **Шаг 4: дописать README**

В `README.md`, в список `## Features`, пунктом после строки про тур:

```markdown
- `About Stash` in the menu bar menu opens a screen with the app's version, the studio's wordmark, a link to the repository and a button that opens a new issue for feedback.
```

- [ ] **Шаг 5: коммит**

```bash
git add README.md
git commit -m "Say what the About screen shows"
```

## Что осталось за планом

- Снимков экрана в тестах нет: у проекта нет снимочной инфраструктуры, а живая строка всё равно не снимается одним кадром. Взамен — проверка руками в задаче 7.
- Взаимное вытеснение экрана обновления и «О приложении» проверяется руками (шаг 2.7): правило живёт в `JournalPanelController`, а его нельзя собрать в тесте без панели, истории и доступа.

# Обучение Stash — план реализации

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Сториз-обучение внутри панели журнала: восемь слайдов с живыми сценами из настоящих деталей Stash, показ при первом запуске, пункт «Обучение» в меню значка. Последний слайд просит Универсальный доступ, и он же показывается один, когда обучение уже видели, а доступа нет.

**Architecture:** Обучение — слой `OnboardingView` поверх `JournalView`; им управляет `OnboardingController`: показ, набор слайдов, клавиши, отметка «увидено» в `UserDefaults`. Доступ берётся из готового `AccessGate`. Сцены — SwiftUI-виды на своих холстах по содержимому, карточка обнимает холст; состояние сцены — чистая функция времени (`Track`, `CursorTrack`, `SceneLoop`), кадры даёт `TimelineView`. Всё, что в сцене изображает Stash, — настоящие виды журнала (`EntryRow`, `TypeSegmentedControl`, `ToastOverlay`, кнопки, палитра), которые план выносит из `JournalView.swift` в `Components/`. Клавиши обучения приходят теми же глобальными хоткеями, что и клавиши журнала: `JournalKeys` получает режимы.

**Tech Stack:** Swift 6 (swift-tools-version 6.0, строгая конкурентность), SwiftUI + AppKit, Carbon (`RegisterEventHotKey`), SwiftPM, Swift Testing (Xcode 26), macOS 13+.

## Global Constraints

- Спека: `docs/superpowers/specs/2026-09-19-onboarding-stories-design.md` (переработана 2026-09-20). Концепты: `.concepts/2026-09-18-onboarding.html`, вариант 1.3; экран доступа — `.concepts/2026-09-19-access-screen.html`.
- Отправная точка: `main` после коммита `cdfa4a3`. Работа «журнал без фокуса» уже в коде: поиска нет, панель не ключевая, клавиши приходят хоткеями, Универсальный доступ обязателен, панель открывается у точки ввода.
- Система — от macOS 13: нет `UnitCurve`, `onChange` — старой формы `onChange(of:perform:)`; то, что появилось в macOS 14, — только через `#available`.
- Swift 6: всё, что трогает AppKit, `NSImage` и кэши картинок, живёт на главном акторе. Колбэки Carbon, `Timer` и `NotificationCenter` входят в актор через `MainActor.assumeIsolated`.
- Комментарии в коде и коммиты — по-английски, как в репозитории.
- Слова и тексты слайдов — дословно из спеки; в коде они появляются в Task 5 и больше не меняются.
- После каждой задачи: `swift build` и `swift test`. Тестовая цель `BufferJournalTests` уже есть, в ней 20 тестов. С Task 9 — снимки: `SNAPSHOT_DIR=/tmp/stash-snapshots swift test --filter SnapshotTests`. Приложение: `Scripts/build_app.sh` → `.build/Stash.app`.
- Тестовая сборка делит с установленным Stash настройки (домен `local.buffer-journal`) и папку истории. Установленный Stash на время проверки закрыть: ⌥V может держать только одна копия.
- Разрешение Универсального доступа выдаёт и снимает только пользователь. Сборка подписана ad-hoc, поэтому каждой новой сборке доступ нужен заново: старую строку Stash удалить кнопкой «−» и добавить новую.
- **Код этого плана не проигран на чистой копии**, в отличие от прежнего плана обучения: он собран по спеке и по нынешнему коду. Исполнитель после каждой задачи гоняет `swift build` и `swift test` и правит расхождения по месту, не дожидаясь конца плана.
- Нумерация задач сохранена от прежнего плана, чтобы сравнение было простым. Изменилось наполнение: Task 17 — сцена «КЛАВИШИ» вместо сцены «ПОИСК», задачи 1–3, 5, 8–11, 13, 14, 18–20 переписаны под новый код, задачи 4, 6, 7, 12, 15, 16 перенесены как были.

## Карта файлов

| Файл | Ответственность |
|---|---|
| `Sources/BufferJournal/Components/ClipLabels.swift` | подписи строк, общие для журнала и сцен |
| `Sources/BufferJournal/Components/EntryRow.swift`, `TypeSegmentedControl.swift`, `TranslucentButtonStyle.swift`, `GlassIconButton.swift`, `ToastOverlay.swift`, `ThemePalette.swift`, `WindowDragHandle.swift` | виды журнала, вынесенные без изменений; у `EntryRow` — `hoverOverride` |
| `Sources/BufferJournal/Components/EntryThumb.swift`, `SectionHeader.swift` | миниатюра строки и заголовок раздела — для журнала и сцен |
| `Sources/BufferJournal/AppSettings.swift` | `init(defaults:)`, тема по умолчанию Stash Auto |
| `Sources/BufferJournal/Onboarding/OnboardingSlides.swift` | восемь слайдов и правило, когда нужен «ДОСТУП» |
| `Sources/BufferJournal/Onboarding/OnboardingLayout.swift` | масштаб сцены, карточка по сцене, логотип первого слайда |
| `Sources/BufferJournal/Onboarding/SceneEngine.swift` | кривые, дорожки, круг, указатель — время сцены в состояние |
| `Sources/BufferJournal/Onboarding/OnboardingController.swift` | показ, слайды, клавиши, «увидено», одиночный показ слайда «ДОСТУП» |
| `Sources/BufferJournal/Onboarding/SceneClock.swift` | часы сцены на `TimelineView` |
| `Sources/BufferJournal/Onboarding/OnboardingSceneView.swift` | какая сцена на слайде, её холст и как он встаёт в карточку |
| `Sources/BufferJournal/Onboarding/OnboardingChrome.swift`, `OnboardingView.swift` | рамка обучения: цвета, кнопки, полосы, каркас, одиночный вид слайда «ДОСТУП» |
| `Sources/BufferJournal/Onboarding/Scenes/SceneKit.swift`, `DemoClips.swift`, `DemoDetailPane.swift`, `JournalMiniature.swift` | детали сцен и демо-клипы |
| `Sources/BufferJournal/Onboarding/Scenes/*Scene.swift` | восемь сцен, среди них `KeysScene` |
| `Sources/BufferJournal/JournalKeys.swift` | режимы клавиш: журнал, обучение, ничего |
| `Sources/BufferJournal/JournalView.swift`, `JournalPanelController.swift`, `AppDelegate.swift`, `README.md` | подключение: слой, клавиши, показ при запуске, пункт меню |
| `Sources/BufferJournal/AccessScreen.swift` | удаляется: его место занимает слайд «ДОСТУП» |
| `Sources/BufferJournal/AccessibilityAccess.swift` | уже есть: `AccessibilityAccess` и `AccessGate`, обучение берёт готовое |
| `Tests/BufferJournalTests/…` | логика, стоп-кадры сцен, снимки PNG |

---

---

### Task 1: Подписи строк в одном месте

Тестовая цель `BufferJournalTests` уже есть в `Package.swift` (работа «журнал без фокуса»), и в ней 20 тестов: `JournalKeyActionTests`, `JournalKeysTests`, `AccessGateTests`, `PanelPlacementTests`. Создавать её не нужно — задача только добавляет свой файл тестов. Поиска в журнале нет, поэтому правила `matches` в `ClipLabels` тоже нет: переезжают одни подписи строк.

**Files:**
- Create: `Sources/BufferJournal/Components/ClipLabels.swift`
- Modify: `Sources/BufferJournal/JournalView.swift` — `kindTitle`, `rowTitle`, `rowSubtitle`, `pixelSize(of:)`, `timeTitle` зовут `ClipLabels`
- Test: `Tests/BufferJournalTests/ClipLabelsTests.swift`
- `Package.swift` не меняется.

**Interfaces:**
- Consumes: `ClipboardEntry` (`title(_:)`, `subtitle(_:)`, `payload`, `createdAt`), `L10n`, `DateFormatter.entryTime`, `ClipboardHistoryStore.pixelSize(for:)`, тестовая цель `BufferJournalTests` (`import Testing`, `@testable import BufferJournal`).
- Produces: `enum ClipLabels` — `kindTitle(_ entry: ClipboardEntry, _ l10n: L10n) -> String`, `rowTitle(_ entry: ClipboardEntry, _ l10n: L10n) -> String`, `rowSubtitle(_ entry: ClipboardEntry, pixelSize: CGSize?, _ l10n: L10n, now: Date = Date()) -> String`, `pixelSizeTitle(_ size: CGSize) -> String`, `timeTitle(_ date: Date, _ l10n: L10n, now: Date = Date()) -> String`.
- Removes: ничего. `matches` в `ClipLabels` не появляется — в журнале поиска нет.

- [ ] **Step 1: Тест**

Создать `Tests/BufferJournalTests/ClipLabelsTests.swift`:

```swift
import CoreGraphics
import Foundation
import Testing
@testable import BufferJournal

struct ClipLabelsTests {
    private let ru = L10n(language: .russian)
    private let en = L10n(language: .english)
    private let now = Calendar.current.date(bySettingHour: 15, minute: 0, second: 0, of: Date())!

    private func entry(_ payload: ClipboardPayload, minutesAgo: Double = 30) -> ClipboardEntry {
        ClipboardEntry(
            id: UUID(),
            payload: payload,
            createdAt: now.addingTimeInterval(-minutesAgo * 60),
            fingerprint: "test"
        )
    }

    @Test func imageRowIsTitledByKindAndSubtitledBySizeAndTime() {
        let image = entry(.image(filename: "x.png"))
        let time = DateFormatter.entryTime.string(from: image.createdAt)
        #expect(ClipLabels.rowTitle(image, ru) == "Изображение")
        #expect(ClipLabels.rowSubtitle(image, pixelSize: CGSize(width: 1600, height: 1000), ru, now: now) == "1600×1000 · \(time)")
    }

    @Test func textRowCollapsesWhitespaceAndShowsOnlyTime() {
        let text = entry(.text("  Счёт\n\nза   сентябрь "))
        #expect(ClipLabels.rowTitle(text, ru) == "Счёт за сентябрь")
        #expect(ClipLabels.rowSubtitle(text, pixelSize: nil, ru, now: now) == DateFormatter.entryTime.string(from: text.createdAt))
    }

    @Test func fileRowShowsNameThenSizeAndTime() {
        let file = entry(.file(storedFilename: "a", originalName: "Договор.pdf", byteCount: 1_200_000))
        let time = DateFormatter.entryTime.string(from: file.createdAt)
        #expect(ClipLabels.rowTitle(file, ru) == "Договор.pdf")
        #expect(ClipLabels.rowSubtitle(file, pixelSize: nil, ru, now: now) == "\(file.subtitle(ru)) · \(time)")
    }

    @Test func yesterdayIsSpelledOut() {
        let old = entry(.text("x"), minutesAgo: 24 * 60)
        #expect(ClipLabels.timeTitle(old.createdAt, en, now: now).hasPrefix("yesterday, "))
    }
}
```

- [ ] **Step 2: Запустить — падает**

Run: `swift test --filter ClipLabelsTests`
Expected: FAIL: ошибка сборки `cannot find 'ClipLabels' in scope`.

- [ ] **Step 3: Код**

Функции — дословно из `JournalView.swift`, только `pixelSize` приходит параметром, а «сегодня» можно подставить в тестах. Локаль берётся из `l10n.language`: в журнале это тот же язык, что `settings.language.resolved`, потому что `l10n` там и есть `settings.l10n`.

Создать `Sources/BufferJournal/Components/ClipLabels.swift`:

```swift
import CoreGraphics
import Foundation

/// How journal rows are titled. The journal and the tutorial scenes both use it, so a scene's
/// rows read exactly like the real ones.
enum ClipLabels {
    static func kindTitle(_ entry: ClipboardEntry, _ l10n: L10n) -> String {
        switch entry.payload {
        case .text: l10n("Text", "Текст")
        case .image: l10n("Image", "Изображение")
        case .file: l10n("File", "Файл")
        }
    }

    static func rowTitle(_ entry: ClipboardEntry, _ l10n: L10n) -> String {
        switch entry.payload {
        case let .text(text):
            // Collapse whitespace so two lines show real content, not blank lines.
            let collapsed = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            return collapsed.isEmpty ? l10n("Empty text", "Пустой текст") : collapsed
        case .image:
            return kindTitle(entry, l10n)
        case .file:
            return entry.title(l10n)
        }
    }

    /// `pixelSize` comes from the store for real clips and from the scene for demo ones.
    static func rowSubtitle(_ entry: ClipboardEntry, pixelSize: CGSize?, _ l10n: L10n, now: Date = Date()) -> String {
        let time = timeTitle(entry.createdAt, l10n, now: now)
        switch entry.payload {
        case .text:
            return time
        case .image:
            return [pixelSize.map(pixelSizeTitle), time].compactMap { $0 }.joined(separator: " · ")
        case .file:
            return "\(entry.subtitle(l10n)) · \(time)"
        }
    }

    static func pixelSizeTitle(_ size: CGSize) -> String {
        "\(Int(size.width))×\(Int(size.height))"
    }

    /// `now` is today for the journal; tests pass their own so the day boundary is not the clock's.
    static func timeTitle(_ date: Date, _ l10n: L10n, now: Date = Date()) -> String {
        let calendar = Calendar.current
        if calendar.isDate(date, inSameDayAs: now) {
            return DateFormatter.entryTime.string(from: date)
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) {
            return l10n("yesterday", "вчера") + ", " + DateFormatter.entryTime.string(from: date)
        }
        let locale = Locale(identifier: l10n.language == .russian ? "ru_RU" : "en_US")
        return date.formatted(.dateTime.day().month(.abbreviated).locale(locale))
    }
}
```

`L10n.language` — это `ResolvedLanguage`, у него нет `Equatable` по объявлению, но это `enum` без ассоциированных значений, так что `==` синтезируется.

- [ ] **Step 4: Запустить — проходит**

Run: `swift test --filter ClipLabelsTests`
Expected: PASS: 4 теста.

- [ ] **Step 5: Журнал зовёт ClipLabels**

Две замены в `Sources/BufferJournal/JournalView.swift`; остальной журнал продолжает звать свои обёртки (`metaTitle` зовёт `pixelSize(of:)`, строки — `rowTitle`/`rowSubtitle`).

В `Sources/BufferJournal/JournalView.swift` заменить:

```swift
    private func kindTitle(_ entry: ClipboardEntry) -> String {
        switch entry.payload {
        case .text: l10n("Text", "Текст")
        case .image: l10n("Image", "Изображение")
        case .file: l10n("File", "Файл")
        }
    }

    private func rowTitle(_ entry: ClipboardEntry) -> String {
        switch entry.payload {
        case let .text(text):
            // Collapse whitespace so two lines show real content, not blank lines.
            let collapsed = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            return collapsed.isEmpty ? l10n("Empty text", "Пустой текст") : collapsed
        case .image:
            return kindTitle(entry)
        case .file:
            return entry.title(l10n)
        }
    }

    private func rowSubtitle(_ entry: ClipboardEntry) -> String {
        let time = timeTitle(entry.createdAt)
        switch entry.payload {
        case .text: return time
        case .image: return [pixelSize(of: entry), time].compactMap { $0 }.joined(separator: " · ")
        case .file: return "\(entry.subtitle(l10n)) · \(time)"
        }
    }
```

на:

```swift
    private func kindTitle(_ entry: ClipboardEntry) -> String {
        ClipLabels.kindTitle(entry, l10n)
    }

    private func rowTitle(_ entry: ClipboardEntry) -> String {
        ClipLabels.rowTitle(entry, l10n)
    }

    private func rowSubtitle(_ entry: ClipboardEntry) -> String {
        ClipLabels.rowSubtitle(entry, pixelSize: store.pixelSize(for: entry), l10n)
    }
```

В `Sources/BufferJournal/JournalView.swift` заменить:

```swift
    private func pixelSize(of entry: ClipboardEntry) -> String? {
        guard let size = store.pixelSize(for: entry) else { return nil }
        return "\(Int(size.width))×\(Int(size.height))"
    }

    private func timeTitle(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return DateFormatter.entryTime.string(from: date)
        }
        if calendar.isDateInYesterday(date) {
            return l10n("yesterday", "вчера") + ", " + DateFormatter.entryTime.string(from: date)
        }
        let locale = Locale(identifier: settings.language.resolved == .russian ? "ru_RU" : "en_US")
        return date.formatted(.dateTime.day().month(.abbreviated).locale(locale))
    }
```

на:

```swift
    private func pixelSize(of entry: ClipboardEntry) -> String? {
        store.pixelSize(for: entry).map(ClipLabels.pixelSizeTitle)
    }

    private func timeTitle(_ date: Date) -> String {
        ClipLabels.timeTitle(date, l10n)
    }
```

Обёртки остаются: `kindTitle(_:)` зовёт шапка превью (`Text(entry.isFile ? entry.title(l10n) : kindTitle(entry))`), `pixelSize(of:)` — `metaTitle(_:)`, `timeTitle(_:)` — шапка превью (`Text("· \(timeTitle(entry.createdAt))")`).

- [ ] **Step 6: Сборка и все тесты**

Run: `swift build && swift test`
Expected: `Build complete!`, PASS: 24 теста (20 прежних и 4 новых).

- [ ] **Step 7: Коммит**

```bash
git add Sources/BufferJournal/Components/ClipLabels.swift Sources/BufferJournal/JournalView.swift Tests/BufferJournalTests/ClipLabelsTests.swift
git commit -m "Share the journal's row labels with the tutorial" -m "Row titles, subtitles and times move from JournalView into ClipLabels, so the
tutorial's demo rows read exactly like the journal's."
```

---

### Task 2: Общие виды журнала — в свои файлы

`GlassIconButton`, `TranslucentButtonStyle`, `ThemePalette` и `WindowDragHandle` в текущем коде уже `internal` (их зовёт `AccessScreen.swift`), так что снимать `private` нужно только у `EntryRow`, `TypeSegmentedControl` и `ToastOverlay`. Переезжают все семь: сценам обучения нужны файлы, а не только видимость.

**Files:**
- Create: `Sources/BufferJournal/Components/EntryRow.swift`, `TypeSegmentedControl.swift`, `TranslucentButtonStyle.swift`, `GlassIconButton.swift`, `ToastOverlay.swift`, `ThemePalette.swift`, `WindowDragHandle.swift` — перенос без изменений
- Modify: `Sources/BufferJournal/JournalView.swift` — эти объявления уходят, два `MARK` переименованы

**Interfaces:**
- Consumes: `JournalView.Layout.rowHeight` (зовёт `EntryRow`), `ClipboardEntry`, `L10n`, `EnvironmentValues.solidAccents`.
- Produces: `EntryRow`, `TypeSegmentedControl`, `ToastOverlay` видны всему модулю (было `private`), инициализаторы прежние. `ThemePalette`, `TranslucentButtonStyle`, `GlassIconButton` и `WindowDragHandle` переезжают как есть, видимость не меняется.
- Removes: те же объявления из `JournalView.swift`; поведение нигде не меняется.

- [ ] **Step 1: Перенос скриптом**

Сохранить скрипт и запустить из корня репозитория. Он вырезает объявление вместе с doc-комментарием над ним до закрывающей `}` в нулевой колонке, снимает `private` и кладёт в `Components/` с шапкой `import AppKit` / `import SwiftUI`.

Сохранить в `/tmp/move_components.py`:

```python
"""Moves the views the tutorial reuses out of JournalView.swift, one file each, unchanged
except that `private` is dropped from the top-level declaration."""
import pathlib
import re

SOURCE = pathlib.Path("Sources/BufferJournal/JournalView.swift")
TARGET = pathlib.Path("Sources/BufferJournal/Components")
HEADER = "import AppKit\nimport SwiftUI\n\n"

# (declaration line as it appears in JournalView.swift, file name)
MOVES = [
    ("private struct EntryRow: View {", "EntryRow.swift"),
    ("private struct TypeSegmentedControl: View {", "TypeSegmentedControl.swift"),
    ("struct TranslucentButtonStyle: ButtonStyle {", "TranslucentButtonStyle.swift"),
    ("struct GlassIconButton: View {", "GlassIconButton.swift"),
    ("private struct ToastOverlay: View {", "ToastOverlay.swift"),
    ("struct ThemePalette {", "ThemePalette.swift"),
    ("struct WindowDragHandle: NSViewRepresentable {", "WindowDragHandle.swift"),
]

lines = SOURCE.read_text().split("\n")
TARGET.mkdir(parents=True, exist_ok=True)

for declaration, filename in MOVES:
    start = lines.index(declaration)
    # Doc comments directly above belong to the declaration.
    while start > 0 and lines[start - 1].startswith("///"):
        start -= 1
    end = lines.index("}", lines.index(declaration)) + 1  # top-level blocks close with "}" at column 0
    block = lines[start:end]
    block = [re.sub(r"^private (struct|final class|enum)", r"\1", line) for line in block]
    (TARGET / filename).write_text(HEADER + "\n".join(block) + "\n")
    del lines[start:end]
    # Drop the blank line the block leaves behind.
    if start < len(lines) and lines[start] == "" and start > 0 and lines[start - 1] == "":
        del lines[start]

SOURCE.write_text("\n".join(lines))
print("moved", len(MOVES), "declarations;", len(lines), "lines left in JournalView.swift")

# The section markers above the moved blocks now head other views.
text = SOURCE.read_text()
text = text.replace("// MARK: - Row\n", "// MARK: - Window chrome\n").replace("// MARK: - Controls\n", "// MARK: - Overlays\n")
SOURCE.write_text(text)
```

Запустить из корня репозитория: `python3 /tmp/move_components.py`

Порядок в `MOVES` совпадает с порядком объявлений в файле, и каждая строка взята дословно: `EntryRow`, `TypeSegmentedControl` и `ToastOverlay` объявлены с `private`, остальные четыре — без. Под `// MARK: - Row` после переноса остаются `SidebarResizeHandle`, `WindowResizeGrip`, `WindowResizeArea`, `EdgeShadow`, `ScrollEdges` и `ScrollOffsetObserver` — отсюда «Window chrome»; под `// MARK: - Controls` остаются `DeleteConfirmationOverlay` и `ScrollBarAppearanceSetter` — отсюда «Overlays».

- [ ] **Step 2: Сборка и тесты**

Run: `python3 /tmp/move_components.py && swift build && swift test`
Expected: скрипт печатает `moved 7 declarations; …`; `Build complete!`, PASS: 24 теста.

- [ ] **Step 3: Проверить, что ничего не потеряли**

Run: `git diff --stat && grep -rn "struct EntryRow\|struct ThemePalette\|struct WindowDragHandle" Sources/BufferJournal`
Expected: в `JournalView.swift` только удаления; каждое из трёх имён объявлено ровно один раз и в `Components/`.

- [ ] **Step 4: Коммит**

```bash
git add Sources/BufferJournal/Components Sources/BufferJournal/JournalView.swift
git commit -m "Move the journal's reusable views into Components" -m "EntryRow, the type filter, the translucent button style, the glass icon button,
the toast, the palette and the drag handle get their own files, unchanged except
for dropping private, so the tutorial's scenes can use them."
```

---

### Task 3: Детали для сцен: миниатюра, заголовок раздела, наведение строки

Поля поиска в журнале нет, поэтому `SearchFieldChrome` не создаётся — ни здесь, ни дальше в плане. Остаются два вида и наведение строки снаружи.

**Files:**
- Create: `Sources/BufferJournal/Components/EntryThumb.swift`, `Sources/BufferJournal/Components/SectionHeader.swift`
- Modify: `Sources/BufferJournal/Components/EntryRow.swift` — `hoverOverride`, миниатюра через `EntryThumb`
- Modify: `Sources/BufferJournal/JournalView.swift` — заголовки разделов через `SectionHeader`

**Interfaces:**
- Consumes: `ThemePalette` (`placeholderBackground`, `sidebarTint`, `controlShadow`, `controlShadowRadius`, `textSecondary`, `textTertiary`), `ClipboardEntry`.
- Produces: `EntryThumb(entry:thumbnail:fileIcon:palette:)` — плитка 42 pt.
- Produces: `SectionHeader(title:palette:)` — «Закреплённые», «Сегодня» и остальные заголовки между группами строк.
- Produces: `EntryRow(…, onDelete:, hoverOverride: Bool? = nil)` — последний параметр необязательный, журнал его не передаёт.
- Removes: `EntryRow.thumb` (переехал в `EntryThumb`), `@State private var isHovered` (стал `isMouseOver` плюс вычисляемое `isHovered`).

- [ ] **Step 1: Два вида**

Код — дословно из `EntryRow.thumb` и заголовка раздела в `JournalView.entryList`.

Создать `Sources/BufferJournal/Components/EntryThumb.swift`:

```swift
import AppKit
import SwiftUI

/// The 42 pt tile at the start of a row: an image thumbnail, a file icon or the text's first letter.
struct EntryThumb: View {
    let entry: ClipboardEntry
    let thumbnail: NSImage?
    let fileIcon: NSImage?
    let palette: ThemePalette

    var body: some View {
        content
            .frame(width: 42, height: 42)
            .background(palette.placeholderBackground)
            .background(palette.sidebarTint)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .shadow(color: palette.controlShadow, radius: ThemePalette.controlShadowRadius, y: 1)
    }

    @ViewBuilder
    private var content: some View {
        switch entry.payload {
        case .image:
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .interpolation(.medium)
                    .scaledToFill()
            }
        case .file:
            if let fileIcon {
                Image(nsImage: fileIcon)
                    .resizable()
                    .padding(4)
            } else {
                Image(systemName: "doc")
                    .font(.system(size: 16))
                    .foregroundStyle(palette.textSecondary)
            }
        case let .text(text):
            Text(String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1)))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(palette.textSecondary)
        }
    }
}
```

Создать `Sources/BufferJournal/Components/SectionHeader.swift`:

```swift
import SwiftUI

/// "Pinned", "Today" and the other headings between groups of rows.
struct SectionHeader: View {
    let title: String
    let palette: ThemePalette

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(palette.textTertiary)
            .padding(.leading, 8)
            .padding(.top, 6)
            .frame(maxWidth: .infinity, minHeight: 26, maxHeight: 26, alignment: .leading)
    }
}
```

- [ ] **Step 2: Строка берёт наведение снаружи**

Четыре замены в `Sources/BufferJournal/Components/EntryRow.swift` (файл появился в Task 2; строки внутри него те же, что были в `JournalView.swift`). Все чтения `isHovered` остаются: теперь это вычисляемое свойство.

В `Sources/BufferJournal/Components/EntryRow.swift` заменить:

```swift
    let onDelete: () -> Void

    @Environment(\.l10n) private var l10n
    @State private var isHovered = false
```

на:

```swift
    let onDelete: () -> Void
    /// Tutorial scenes show hover without a mouse; the journal leaves it nil.
    var hoverOverride: Bool? = nil

    @Environment(\.l10n) private var l10n
    @State private var isMouseOver = false

    private var isHovered: Bool {
        hoverOverride ?? isMouseOver
    }
```

В `Sources/BufferJournal/Components/EntryRow.swift` заменить:

```swift
            thumb
                .frame(width: 42, height: 42)
                .background(palette.placeholderBackground)
                .background(palette.sidebarTint)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .shadow(color: palette.controlShadow, radius: ThemePalette.controlShadowRadius, y: 1)
```

на:

```swift
            EntryThumb(entry: entry, thumbnail: thumbnail, fileIcon: fileIcon, palette: palette)
```

В `Sources/BufferJournal/Components/EntryRow.swift` заменить:

```swift
        .onHover { isHovered = $0 }
```

на:

```swift
        .onHover { isMouseOver = $0 }
```

В `Sources/BufferJournal/Components/EntryRow.swift` заменить:

```swift
    }

    @ViewBuilder
    private var thumb: some View {
        switch entry.payload {
        case .image:
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .interpolation(.medium)
                    .scaledToFill()
            }
        case .file:
            if let fileIcon {
                Image(nsImage: fileIcon)
                    .resizable()
                    .padding(4)
            } else {
                Image(systemName: "doc")
                    .font(.system(size: 16))
                    .foregroundStyle(palette.textSecondary)
            }
        case let .text(text):
            Text(String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1)))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(palette.textSecondary)
        }
    }
}
```

на:

```swift
    }
}
```

Так `subtitleText` остаётся последним свойством, а `}` в нулевой колонке закрывает `EntryRow`.

- [ ] **Step 3: Журнал на новом заголовке**

В `Sources/BufferJournal/JournalView.swift` заменить:

```swift
                        Text(section.title)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(palette.textTertiary)
                            .padding(.leading, 8)
                            .padding(.top, 6)
                            .frame(maxWidth: .infinity, minHeight: 26, maxHeight: 26, alignment: .leading)
                            .id(section.title)
```

на:

```swift
                        SectionHeader(title: section.title, palette: palette)
                            .id(section.title)
```

- [ ] **Step 4: Сборка и тесты**

Run: `swift build && swift test`
Expected: `Build complete!`, PASS: 24 теста.

- [ ] **Step 5: Журнал не изменился**

Проверка вручную: собрать `Scripts/build_app.sh`, открыть `.build/Stash.app`, нажать ⌥V. Наведение на строку показывает кнопки и гасит текст под ними, миниатюры и их тени на месте, заголовки «Сегодня» и «Закреплённые» стоят как прежде. Установленный Stash на время проверки закрыть: у сборок общие настройки и история.

- [ ] **Step 6: Коммит**

```bash
git add Sources/BufferJournal/Components Sources/BufferJournal/JournalView.swift
git commit -m "Split out the row thumbnail and the section header" -m "Rows also take a hover override, so a tutorial scene can show hover without
a mouse. The journal looks and behaves the same."
```

---

### Task 4: Stash Auto — тема по умолчанию

Настройки `AppSettings` в текущем коде — `openAtCaret`, `interceptKeys`, `closeAfterSelection`, `themeMode`, `language`; «Вставлять при выборе» (`pasteOnSelection`) удалена вместе с работой «журнал без фокуса», и в заменах её нет.

**Files:**
- Modify: `Sources/BufferJournal/AppSettings.swift` — `init(defaults:)`, тема по умолчанию `.stashAuto`
- Test: `Tests/BufferJournalTests/AppSettingsTests.swift`

**Interfaces:**
- Consumes: `ThemeMode`, `AppLanguage`.
- Produces: `AppSettings(defaults: UserDefaults = .standard)` — вызовы без параметра (`AppDelegate`) не меняются.
- Removes: обращения к `UserDefaults.standard` из `didSet` — вместо них хранимое свойство `defaults`.

- [ ] **Step 1: Тест**

Создать `Tests/BufferJournalTests/AppSettingsTests.swift`:

```swift
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
```

`ThemeMode` — `enum` без ассоциированных значений, `==` синтезируется; свой домен у каждого теста, чтобы настройки установленного Stash не мешали.

- [ ] **Step 2: Запустить — падает**

Run: `swift test --filter AppSettingsTests`
Expected: FAIL: ошибка сборки `extra argument 'defaults' in call`.

- [ ] **Step 3: Код**

Три замены в `Sources/BufferJournal/AppSettings.swift`.

В `Sources/BufferJournal/AppSettings.swift` заменить:

```swift
    /// The panel opens next to the text cursor of the app the user is typing in, like Win+V.
    /// Turned off, it opens where it was left, as before.
    @Published var openAtCaret: Bool {
        didSet {
            UserDefaults.standard.set(openAtCaret, forKey: Keys.openAtCaret)
        }
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
```

на:

```swift
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
```

В `Sources/BufferJournal/AppSettings.swift` заменить:

```swift
    init() {
        let defaults = UserDefaults.standard

        if defaults.object(forKey: Keys.openAtCaret) == nil {
```

на:

```swift
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if defaults.object(forKey: Keys.openAtCaret) == nil {
```

В `Sources/BufferJournal/AppSettings.swift` заменить:

```swift
        themeMode = ThemeMode(rawValue: defaults.string(forKey: Keys.themeMode) ?? "") ?? .system
```

на:

```swift
        // Stash Auto unless the person picked a theme before.
        themeMode = ThemeMode(rawValue: defaults.string(forKey: Keys.themeMode) ?? "") ?? .stashAuto
```

- [ ] **Step 4: Запустить — проходит**

Run: `swift test --filter AppSettingsTests`
Expected: PASS: 3 теста.

- [ ] **Step 5: Сборка и все тесты**

Run: `swift build && swift test`
Expected: `Build complete!`, PASS: 27 тестов (20 прежних, 4 из Task 1 и 3 новых).

- [ ] **Step 6: Коммит**

```bash
git add Sources/BufferJournal/AppSettings.swift Tests/BufferJournalTests/AppSettingsTests.swift
git commit -m "Default to Stash Auto when no theme was picked" -m "Settings also take their UserDefaults from outside, for tests."
```

---

### Task 5: Слайды

**Files:**
- Create: `Sources/BufferJournal/Onboarding/OnboardingSlides.swift`
- Test: `Tests/BufferJournalTests/OnboardingSlidesTests.swift`

**Interfaces:**
- Consumes: `L10n` (`Sources/BufferJournal/Localization.swift`) — двухъязычный поиск строк.
- Produces: `enum OnboardingSceneKind: String, CaseIterable, Sendable` — `hero, hotKey, paste, pin, images, keys, settings, access`.
- Produces: `struct Localized: Equatable, Sendable` — `en`, `ru`, `callAsFunction(_ l10n: L10n) -> String`.
- Produces: `struct OnboardingSlide: Identifiable, Equatable, Sendable` — `kind`, `duration: Double`, `loops: Bool`, `word: Localized` (на первом слайде — видимый заголовок «ПРИВЕТ, ЭТО», у остальных — заголовок карточки для VoiceOver), `text: Localized`, `id == kind`.
- Produces: `OnboardingSlides.all` (восемь слайдов по спеке), `OnboardingSlides.accessSlide` (слайд «ДОСТУП» отдельно — для одиночного показа в Task 8), `static func slides(hasAccess: Bool) -> [OnboardingSlide]`.
- Removes: —

- [ ] **Step 1: Тест**

Создать `Tests/BufferJournalTests/OnboardingSlidesTests.swift`:

```swift
import Testing
@testable import BufferJournal

struct OnboardingSlidesTests {
    @Test func slidesComeInTheSpecOrderWithAccessLast() {
        #expect(OnboardingSlides.all.map(\.kind) == [.hero, .hotKey, .paste, .pin, .images, .keys, .settings, .access])
    }

    @Test func theSixthSlideIsAboutKeys() {
        let sixth = OnboardingSlides.all[5]
        #expect(sixth.kind == .keys)
        #expect(sixth.word.ru == "КЛАВИШИ")
        #expect(sixth.word.en == "KEYS")
    }

    /// The spec keeps every text within 140 characters, so it takes at most three lines on a
    /// 560 × 360 panel and the block under the card never eats the card's room.
    @Test func wordsAreCapitalsAndTextsStayShort() {
        for slide in OnboardingSlides.all {
            #expect(slide.word.en == slide.word.en.uppercased())
            #expect(slide.word.ru == slide.word.ru.uppercased())
            #expect(slide.text.en.count <= 140, "\(slide.kind) EN is \(slide.text.en.count)")
            #expect(slide.text.ru.count <= 140, "\(slide.kind) RU is \(slide.text.ru.count)")
        }
    }

    @Test func onlyTheFirstSlidePlaysOnce() {
        #expect(OnboardingSlides.all.filter { !$0.loops }.map(\.kind) == [.hero])
    }

    @Test func theAccessSlideIsOnlyForThoseWithoutAccess() {
        #expect(OnboardingSlides.slides(hasAccess: false).count == 8)
        #expect(OnboardingSlides.slides(hasAccess: false).last?.kind == .access)

        let withAccess = OnboardingSlides.slides(hasAccess: true)
        #expect(withAccess.map(\.kind) == [.hero, .hotKey, .paste, .pin, .images, .keys, .settings])
    }

    @Test func theAccessSlideStandsAlone() {
        #expect(OnboardingSlides.accessSlide.kind == .access)
        #expect(OnboardingSlides.all.last == OnboardingSlides.accessSlide)
    }

    @Test func aSlideIsIdentifiedByItsScene() {
        #expect(OnboardingSlides.all.map(\.id) == OnboardingSceneKind.allCases)
    }
}
```

- [ ] **Step 2: Запустить — падает**

Run: `swift test --filter OnboardingSlidesTests`
Expected: FAIL: ошибка сборки `cannot find 'OnboardingSlides' in scope`.

- [ ] **Step 3: Код**

Слова и тексты — дословно из таблицы «Слайды» в спеке, длительности — оттуда же.

Создать `Sources/BufferJournal/Onboarding/OnboardingSlides.swift`:

```swift
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
```

- [ ] **Step 4: Запустить — проходит**

Run: `swift test --filter OnboardingSlidesTests`
Expected: PASS: 7 тестов.

- [ ] **Step 5: Коммит**

```bash
git add Sources/BufferJournal/Onboarding/OnboardingSlides.swift Tests/BufferJournalTests/OnboardingSlidesTests.swift
git commit -m "Tutorial slides: words, texts and durations" -m "The access slide joins the set only without Accessibility access, and stands apart because it also shows on its own."
```

---

### Task 6: Раскладка: масштаб сцены, карточка по сцене, логотип

**Files:**
- Create: `Sources/BufferJournal/Onboarding/OnboardingLayout.swift`
- Test: `Tests/BufferJournalTests/OnboardingLayoutTests.swift`

**Interfaces:**
- Produces: `OnboardingLayout.sceneSize` (480 × 240 — самый большой холст, заглушка до сцен), `sceneScale(_ scene: CGSize, in area: CGSize) -> CGFloat` (во всё место с сохранением пропорций, вверх и вниз), `cardSize(for scene: CGSize, in area: CGSize) -> CGSize`, `struct Lockup { icon, gap, fontSize }`, `heroLockup(in:wordWidthAt28:) -> Lockup`, `titleFontSize(widthAt100:rowWidth:panelHeight:) -> CGFloat` — кегль заголовка первого слайда.
- Produces: `@MainActor enum HeavyTextMetrics` — `width(_ text: String, size:, tracking: = 0) -> CGFloat` и `capHeight(size:) -> CGFloat` шрифтом `.heavy`.

- [ ] **Step 1: Тест**

Создать `Tests/BufferJournalTests/OnboardingLayoutTests.swift`:

```swift
import CoreGraphics
import Testing
@testable import BufferJournal

struct OnboardingLayoutTests {
    @Test func scenesFillTheRoomKeepingTheirShape() {
        let scene = CGSize(width: 480, height: 240)
        #expect(abs(OnboardingLayout.sceneScale(scene, in: CGSize(width: 600, height: 400)) - 1.25) < 0.0001)
        #expect(abs(OnboardingLayout.sceneScale(scene, in: CGSize(width: 860, height: 371)) - 371.0 / 240.0) < 0.0001)
        #expect(abs(OnboardingLayout.sceneScale(scene, in: CGSize(width: 520, height: 193)) - 193.0 / 240.0) < 0.0001)
        #expect(OnboardingLayout.sceneScale(scene, in: .zero) == 0)
    }

    @Test func theCardTakesTheWholeWidthOrHeight() {
        // A tall scene meets the height and stays as narrow as it needs.
        let tall = OnboardingLayout.cardSize(for: CGSize(width: 344, height: 246), in: CGSize(width: 600, height: 300))
        #expect(abs(tall.height - 300) < 0.001)
        #expect(abs(tall.width - 344 * 300 / 246) < 0.001)
        // A wide scene meets the width.
        let wide = OnboardingLayout.cardSize(for: CGSize(width: 480, height: 240), in: CGSize(width: 600, height: 400))
        #expect(abs(wide.width - 600) < 0.001)
        #expect(abs(wide.height - 300) < 0.001)
    }

    @Test func heroLockupFitsItsArea() {
        let area = CGSize(width: 600, height: 262)
        let lockup = OnboardingLayout.heroLockup(in: area, wordWidthAt28: 73)
        let k = lockup.icon / 32
        #expect(lockup.icon + lockup.gap + 73 * k <= area.width * 0.8 + 0.001)
        #expect(lockup.icon <= area.height * 0.8 + 0.001)
        #expect(abs(lockup.fontSize / lockup.icon - 28.0 / 32.0) < 0.0001)
    }

    @Test func theTitleStopsAtTenPercentOfThePanel() {
        #expect(OnboardingLayout.titleFontSize(widthAt100: 500, rowWidth: 600, panelHeight: 440) == 44)
        #expect(OnboardingLayout.titleFontSize(widthAt100: 500, rowWidth: 520, panelHeight: 360) == 36)
    }

    @Test func aLongTitleShrinksToItsRow() {
        // 100 × 600 / (2000 × 1.02) = 29.4
        #expect(OnboardingLayout.titleFontSize(widthAt100: 2000, rowWidth: 600, panelHeight: 440) == 29)
    }

    @MainActor
    @Test func heavyTextIsMeasuredInTheHeaderFont() {
        #expect(HeavyTextMetrics.width("Stash", size: 56) > 2 * HeavyTextMetrics.width("Stash", size: 27))
        #expect(HeavyTextMetrics.width("ПРИВЕТ, ЭТО", size: 100, tracking: -2) < HeavyTextMetrics.width("ПРИВЕТ, ЭТО", size: 100))
        #expect(HeavyTextMetrics.capHeight(size: 28) > 15)
    }
}
```

- [ ] **Step 2: Запустить — падает**

Run: `swift test --filter OnboardingLayoutTests`
Expected: FAIL: ошибка сборки `cannot find 'OnboardingLayout' in scope`.

- [ ] **Step 3: Код**

Создать `Sources/BufferJournal/Onboarding/OnboardingLayout.swift`:

```swift
import AppKit

enum OnboardingLayout {
    /// The largest scene canvas. Each scene has its own size, fitted to what it shows; this one
    /// stands in for a scene that is not built yet.
    static let sceneSize = CGSize(width: 480, height: 240)

    /// The scene grows or shrinks until it meets the width or the height of the room, keeping
    /// its proportions.
    static func sceneScale(_ scene: CGSize, in area: CGSize) -> CGFloat {
        guard scene.width > 0, scene.height > 0, area.width > 0, area.height > 0 else { return 0 }
        return min(area.width / scene.width, area.height / scene.height)
    }

    /// The card hugs its scene at the scale the scene gets: it takes the whole width or the whole
    /// height of the room, and no more than the scene needs of the other.
    static func cardSize(for scene: CGSize, in area: CGSize) -> CGSize {
        let scale = sceneScale(scene, in: area)
        return CGSize(width: scene.width * scale, height: scene.height * scale)
    }

    /// The journal header's lockup: a 32 pt icon, a 2 pt gap and "Stash" at 28 pt heavy.
    struct Lockup: Equatable {
        var icon: CGFloat
        var gap: CGFloat
        var fontSize: CGFloat
    }

    static let headerLockup = Lockup(icon: 32, gap: 2, fontSize: 28)

    /// The header lockup scaled up to 80 % of the area's width or height, whichever binds first.
    /// `wordWidthAt28` is the width of "Stash" at 28 pt heavy.
    static func heroLockup(in area: CGSize, wordWidthAt28: CGFloat) -> Lockup {
        let natural = headerLockup
        let width = natural.icon + natural.gap + wordWidthAt28
        guard width > 0, area.width > 0, area.height > 0 else { return Lockup(icon: 0, gap: 0, fontSize: 0) }
        let k = min(area.width * 0.8 / width, area.height * 0.8 / natural.icon)
        return Lockup(icon: natural.icon * k, gap: natural.gap * k, fontSize: natural.fontSize * k)
    }

    /// Spare width for the title, and the share of the panel height it may take.
    static let titleSlack: CGFloat = 1.02
    static let titleHeightShare: CGFloat = 0.1

    /// The first slide's title: as wide as its row allows, capped at 10 % of the panel height.
    /// `widthAt100` is the title's width at 100 pt.
    static func titleFontSize(widthAt100: CGFloat, rowWidth: CGFloat, panelHeight: CGFloat) -> CGFloat {
        let cap = (panelHeight * titleHeightShare).rounded()
        guard widthAt100 > 0 else { return max(cap, 1) }
        let byWidth = floor(100 * rowWidth / (widthAt100 * titleSlack))
        return max(1, min(byWidth, cap))
    }
}

/// Widths of text in the heavy system font: the "Stash" wordmark and the first slide's title.
@MainActor
enum HeavyTextMetrics {
    static func width(_ text: String, size: CGFloat, tracking: CGFloat = 0) -> CGFloat {
        let font = NSFont.systemFont(ofSize: size, weight: .heavy)
        return ceil(NSAttributedString(string: text, attributes: [.font: font, .kern: tracking]).size().width)
    }

    static func capHeight(size: CGFloat) -> CGFloat {
        NSFont.systemFont(ofSize: size, weight: .heavy).capHeight
    }
}
```

- [ ] **Step 4: Запустить — проходит**

Run: `swift test --filter OnboardingLayoutTests`
Expected: PASS: 6 тестов.

- [ ] **Step 5: Коммит**

```bash
git add Sources/BufferJournal/Onboarding/OnboardingLayout.swift Tests/BufferJournalTests/OnboardingLayoutTests.swift
git commit -m "Tutorial layout: scene scale, card size, the hero lockup and its title"
```

---

### Task 7: Движок сцен: кривые, дорожки, круг, указатель

**Files:**
- Create: `Sources/BufferJournal/Onboarding/SceneEngine.swift`
- Test: `Tests/BufferJournalTests/SceneEngineTests.swift`

**Interfaces:**
- Produces: `enum SceneCurve` — `.linear/.easeIn/.easeOut/.easeInOut`, вызывается как функция `(Double) -> Double`.
- Produces: `protocol SceneValue` — готовы `Double`, `CGFloat`, `CGPoint` (плавные) и `Bool`, `Int`, `String`, `Optional` (переключаются).
- Produces: `struct SceneTime { t, rewind }`, `SceneTime.end(of:)`; `SceneLoop.time(elapsed:duration:loops:) -> SceneTime`, `returnTime = 0.5`, `pauseTime = 0.25`.
- Produces: `struct Track<Value: SceneValue>` — `init(_ initial:)`, `to(_:at:until:_:)`, `set(_:at:)`, `value(at: Double)`, `value(at: SceneTime)`, `initial`, `final`.
- Produces: `CursorState { tip, opacity, press }`, `ClickRipple { center, progress }`, `CursorTrack(tip:opacity:clicks:)` — `state(at:)`, `ripple(at:)`.

- [ ] **Step 1: Тест**

Создать `Tests/BufferJournalTests/SceneEngineTests.swift`:

```swift
import CoreGraphics
import Testing
@testable import BufferJournal

struct SceneEngineTests {
    @Test func curvesStartAndEndInPlace() {
        for curve in [SceneCurve.linear, .easeIn, .easeOut, .easeInOut] {
            #expect(abs(curve(0)) < 0.0001)
            #expect(abs(curve(1) - 1) < 0.0001)
        }
        #expect(abs(SceneCurve.easeInOut(0.5) - 0.5) < 0.001)
        #expect(SceneCurve.easeOut(0.25) > 0.25)
        #expect(SceneCurve.easeIn(0.25) < 0.25)
    }

    @Test func aTrackHoldsGlidesAndHolds() {
        let track = Track(0.0).to(10, at: 1, until: 2, .linear).set(3, at: 3)
        #expect(track.value(at: 0.5) == 0)
        #expect(track.value(at: 1.5) == 5)
        #expect(track.value(at: 2.5) == 10)
        #expect(track.value(at: 3) == 3)
        #expect(track.final == 3)
    }

    @Test func onTheWayBackContinuousValuesGlideAndFlagsSwitch() {
        let offset = Track(0.0).to(10, at: 0, until: 1, .linear)
        let flag = Track(false).set(true, at: 0.5)
        let halfway = SceneTime(t: 1, rewind: 0.5)
        #expect(abs(offset.value(at: halfway) - 5) < 0.0001)
        #expect(flag.value(at: halfway) == false)
        #expect(flag.value(at: SceneTime.end(of: 1)) == true)
    }

    @Test func aLoopPlaysReturnsAndPauses() {
        #expect(SceneLoop.time(elapsed: 1, duration: 2, loops: true) == SceneTime(t: 1, rewind: 0))
        #expect(SceneLoop.time(elapsed: 2.25, duration: 2, loops: true) == SceneTime(t: 2, rewind: 0.5))
        #expect(SceneLoop.time(elapsed: 2.6, duration: 2, loops: true) == SceneTime(t: 2, rewind: 1))
        // A cycle is 2 + 0.5 + 0.25 s; then it starts over.
        #expect(abs(SceneLoop.time(elapsed: 3.0, duration: 2, loops: true).t - 0.25) < 0.0001)
    }

    @Test func aSceneThatPlaysOnceStaysAtItsEnd() {
        #expect(SceneLoop.time(elapsed: 9, duration: 2, loops: false) == SceneTime.end(of: 2))
    }

    @Test func aClickSqueezesTheArrowAndSendsAWave() {
        let tip = Track(CGPoint(x: 0, y: 0)).to(CGPoint(x: 100, y: 50), at: 0, until: 1)
        let cursor = CursorTrack(tip: tip, opacity: Track(1.0), clicks: [1.5])
        #expect(cursor.state(at: SceneTime(t: 1.4, rewind: 0)).press == 0)
        #expect(abs(cursor.state(at: SceneTime(t: 1.58, rewind: 0)).press - 1) < 0.001)
        #expect(cursor.state(at: SceneTime(t: 1.8, rewind: 0)).press == 0)
        #expect(cursor.ripple(at: SceneTime(t: 1.6, rewind: 0))?.center == CGPoint(x: 100, y: 50))
        #expect(cursor.ripple(at: SceneTime(t: 2, rewind: 0)) == nil)
    }

    @Test func theArrowFadesInPlaceBeforeGoingBack() {
        let tip = Track(CGPoint(x: 0, y: 0)).to(CGPoint(x: 100, y: 0), at: 0, until: 1)
        let cursor = CursorTrack(tip: tip, opacity: Track(1.0), clicks: [])
        let fading = cursor.state(at: SceneTime(t: 1, rewind: 0.25))
        #expect(fading.tip == CGPoint(x: 100, y: 0))
        #expect(abs(fading.opacity - 0.5) < 0.0001)
        let travelling = cursor.state(at: SceneTime(t: 1, rewind: 0.75))
        #expect(travelling.opacity == 0)
        #expect(abs(travelling.tip.x - 50) < 0.0001)
    }
}
```

- [ ] **Step 2: Запустить — падает**

Run: `swift test --filter SceneEngineTests`
Expected: FAIL: ошибка сборки `cannot find 'SceneCurve' in scope`.

- [ ] **Step 3: Код**

Состояние сцены — чистая функция времени: дорожка держит значение, едет к новому между двумя моментами и снова держит. На возврате круга плавные значения едут к началу, а флаги сбрасываются сразу — их анимацию делают сами виды журнала. Указатель на возврате сначала гаснет на месте, потом невидимым едет к началу.

Создать `Sources/BufferJournal/Onboarding/SceneEngine.swift`:

```swift
import CoreGraphics
import Foundation

/// SwiftUI's timing curves evaluated by hand: `UnitCurve` needs macOS 14 and Stash runs on 13.
enum SceneCurve: Sendable {
    case linear
    case easeIn
    case easeOut
    case easeInOut

    func callAsFunction(_ progress: Double) -> Double {
        let x = min(max(progress, 0), 1)
        switch self {
        case .linear: return x
        case .easeIn: return Self.bezier(x, 0.42, 0, 1, 1)
        case .easeOut: return Self.bezier(x, 0, 0, 0.58, 1)
        case .easeInOut: return Self.bezier(x, 0.42, 0, 0.58, 1)
        }
    }

    /// y of the cubic Bézier (0,0)–(x1,y1)–(x2,y2)–(1,1) at x; its parameter is found by bisection.
    private static func bezier(_ x: Double, _ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> Double {
        func coordinate(_ t: Double, _ a: Double, _ b: Double) -> Double {
            let u = 1 - t
            return 3 * u * u * t * a + 3 * u * t * t * b + t * t * t
        }
        var low = 0.0
        var high = 1.0
        for _ in 0..<32 {
            let mid = (low + high) / 2
            if coordinate(mid, x1, x2) < x { low = mid } else { high = mid }
        }
        return coordinate((low + high) / 2, y1, y2)
    }
}

/// Something a scene animates. Continuous values glide; discrete ones (flags, indices) switch.
protocol SceneValue: Sendable {
    static var isDiscrete: Bool { get }
    static func interpolate(_ from: Self, _ to: Self, _ progress: Double) -> Self
}

extension SceneValue {
    static var isDiscrete: Bool { false }
}

extension Double: SceneValue {
    static func interpolate(_ from: Double, _ to: Double, _ progress: Double) -> Double {
        from + (to - from) * progress
    }
}

extension CGFloat: SceneValue {
    static func interpolate(_ from: CGFloat, _ to: CGFloat, _ progress: Double) -> CGFloat {
        from + (to - from) * CGFloat(progress)
    }
}

extension CGPoint: SceneValue {
    static func interpolate(_ from: CGPoint, _ to: CGPoint, _ progress: Double) -> CGPoint {
        CGPoint(x: CGFloat.interpolate(from.x, to.x, progress), y: CGFloat.interpolate(from.y, to.y, progress))
    }
}

extension Bool: SceneValue {
    static var isDiscrete: Bool { true }

    static func interpolate(_ from: Bool, _ to: Bool, _ progress: Double) -> Bool {
        progress >= 1 ? to : from
    }
}

extension Int: SceneValue {
    static var isDiscrete: Bool { true }

    static func interpolate(_ from: Int, _ to: Int, _ progress: Double) -> Int {
        progress >= 1 ? to : from
    }
}

extension String: SceneValue {
    static var isDiscrete: Bool { true }

    static func interpolate(_ from: String, _ to: String, _ progress: Double) -> String {
        progress >= 1 ? to : from
    }
}

extension Optional: SceneValue where Wrapped: SceneValue {
    static var isDiscrete: Bool { true }

    static func interpolate(_ from: Wrapped?, _ to: Wrapped?, _ progress: Double) -> Wrapped? {
        progress >= 1 ? to : from
    }
}

/// Where a scene is: `t` seconds into it, and how far a loop has got back to its first frame.
struct SceneTime: Equatable, Sendable {
    var t: Double
    /// 0 while the scene plays, 0…1 while it returns to its first frame, 1 during the pause.
    var rewind: Double

    /// The stop frame: the scene has played out and holds.
    static func end(of duration: Double) -> SceneTime {
        SceneTime(t: duration, rewind: 0)
    }
}

/// The loop from mrbooker's welcome scenes: play, glide back to the first frame, pause, again.
enum SceneLoop {
    static let returnTime = 0.5
    static let pauseTime = 0.25

    static func time(elapsed: Double, duration: Double, loops: Bool) -> SceneTime {
        let elapsed = max(elapsed, 0)
        guard loops else { return SceneTime(t: min(elapsed, duration), rewind: 0) }
        let cycle = duration + returnTime + pauseTime
        let local = elapsed.truncatingRemainder(dividingBy: cycle)
        if local <= duration { return SceneTime(t: local, rewind: 0) }
        return SceneTime(t: duration, rewind: min((local - duration) / returnTime, 1))
    }
}

/// A value over scene time, built from moves: it holds, glides to a new value between two
/// moments along a curve, and holds again.
struct Track<Value: SceneValue>: Sendable {
    private struct Move: Sendable {
        let start: Double
        let end: Double
        let from: Value
        let to: Value
        let curve: SceneCurve
    }

    let initial: Value
    private let moves: [Move]

    init(_ initial: Value) {
        self.init(initial: initial, moves: [])
    }

    private init(initial: Value, moves: [Move]) {
        self.initial = initial
        self.moves = moves
    }

    /// The value the track ends on.
    var final: Value {
        moves.last?.to ?? initial
    }

    /// Glides to `value` between `start` and `end`. Moves must come in time order.
    func to(_ value: Value, at start: Double, until end: Double, _ curve: SceneCurve = .easeInOut) -> Track {
        precondition(start >= (moves.last?.end ?? 0) && end >= start, "moves must come in time order")
        return Track(initial: initial, moves: moves + [Move(start: start, end: end, from: final, to: value, curve: curve)])
    }

    /// Switches to `value` at `time`.
    func set(_ value: Value, at time: Double) -> Track {
        to(value, at: time, until: time, .linear)
    }

    func value(at t: Double) -> Value {
        var current = initial
        for move in moves {
            if t < move.start { return current }
            if t < move.end {
                return Value.interpolate(move.from, move.to, move.curve((t - move.start) / (move.end - move.start)))
            }
            current = move.to
        }
        return current
    }

    /// While a loop returns to its first frame, continuous values glide back and discrete ones
    /// switch back at once, so the app's own views animate them the way the journal does.
    func value(at time: SceneTime) -> Value {
        guard time.rewind > 0 else { return value(at: time.t) }
        if Value.isDiscrete { return initial }
        return Value.interpolate(final, initial, SceneCurve.easeInOut(time.rewind))
    }
}

/// The arrow in a scene: where its tip is, how visible it is, how squeezed by a click.
struct CursorState: Equatable, Sendable {
    var tip: CGPoint
    var opacity: Double
    /// 0 at rest, 1 fully pressed.
    var press: Double
}

/// The orange wave a click sends out from under the arrow.
struct ClickRipple: Equatable, Sendable {
    var center: CGPoint
    /// 0…1 over `CursorTrack.rippleTime`.
    var progress: Double
}

/// The arrow's path, fade and clicks. On the way back to the first frame it fades where it
/// stands and travels unseen, instead of flying back across the scene.
struct CursorTrack: Sendable {
    static let pressDown = 0.08
    static let pressUp = 0.12
    static let rippleTime = 0.35

    let tip: Track<CGPoint>
    let opacity: Track<Double>
    let clicks: [Double]

    func state(at time: SceneTime) -> CursorState {
        if time.rewind > 0 {
            let fade = min(time.rewind * 2, 1)
            let travel = max(time.rewind * 2 - 1, 0)
            return CursorState(
                tip: CGPoint.interpolate(tip.final, tip.initial, SceneCurve.easeInOut(travel)),
                opacity: opacity.final * (1 - fade),
                press: 0
            )
        }
        return CursorState(tip: tip.value(at: time.t), opacity: opacity.value(at: time.t), press: press(at: time.t))
    }

    func ripple(at time: SceneTime) -> ClickRipple? {
        guard time.rewind == 0 else { return nil }
        for click in clicks where time.t >= click && time.t < click + Self.rippleTime {
            return ClickRipple(center: tip.value(at: click), progress: (time.t - click) / Self.rippleTime)
        }
        return nil
    }

    private func press(at t: Double) -> Double {
        for click in clicks {
            if t >= click, t < click + Self.pressDown {
                return (t - click) / Self.pressDown
            }
            if t >= click + Self.pressDown, t < click + Self.pressDown + Self.pressUp {
                return 1 - (t - click - Self.pressDown) / Self.pressUp
            }
        }
        return 0
    }
}
```

- [ ] **Step 4: Запустить — проходит**

Run: `swift test --filter SceneEngineTests`
Expected: PASS: 7 тестов.

- [ ] **Step 5: Коммит**

```bash
git add Sources/BufferJournal/Onboarding/SceneEngine.swift Tests/BufferJournalTests/SceneEngineTests.swift
git commit -m "Scene engine: curves, tracks, loops and the cursor"
```

---

### Task 8: Контроллер обучения и доступ

**Files:**
- Create: `Sources/BufferJournal/Onboarding/OnboardingController.swift`
- Test: `Tests/BufferJournalTests/OnboardingControllerTests.swift` (в нём же `FakeAccessGate` для тестов следующих задач)

**Interfaces:**
- Consumes: `OnboardingSlides.slides(hasAccess:)`, `OnboardingSlides.accessSlide`, `OnboardingSlide` (Task 5).
- Consumes: `AccessGate` и `AccessibilityAccess` из `Sources/BufferJournal/AccessibilityAccess.swift` — готовые, новых не создаём: `isGranted`, `refresh()`, `request()`, `setPolling(_:)`. Проверку раз в секунду уже держит `JournalPanelController` (`access.setPolling(isPanelVisible)`), контроллер обучения её не трогает.
- Consumes: `JournalKey` из `Sources/BufferJournal/JournalKeys.swift` — сейчас `up, down, enter, escape`.
- Produces: `@MainActor final class OnboardingController: ObservableObject`, `init(defaults: UserDefaults = .standard, access: AccessGate)`; `@Published private(set)` — `isPresented`, `slides`, `index`, `run`; `private(set) var isReplay`, `private(set) var isAccessOnly`; `shouldShowOnLaunch`, `slide`, `isLast`; `present(replay:)`, `presentAccessOnly()`, `next()`, `back()`, `primaryAction()`, `close()`, `restartScene()`, `requestAccess()`, `handleKey(_ key: JournalKey) -> Bool`; `static let currentVersion = 1`, `static let seenVersionKey = "OnboardingSeenVersion"`.
- Produces (тесты): `FakeAccessGate(granted:)` — `granted` меняется, `requests` считает запросы, `gate: AccessGate` для контроллера и для видов в Task 9 и дальше.
- Removes: —

- [ ] **Step 1: Тест**

Создать `Tests/BufferJournalTests/OnboardingControllerTests.swift`:

```swift
import Foundation
import Testing
@testable import BufferJournal

/// A stand-in for the system permission behind a real `AccessGate`.
@MainActor
final class FakeAccessGate {
    var granted: Bool
    private(set) var requests = 0

    /// Built on first use so the gate reads `granted` as the test set it.
    private(set) lazy var gate = AccessGate(
        access: AccessibilityAccess(
            isGranted: { [unowned self] in granted },
            request: { [unowned self] in requests += 1 }
        )
    )

    init(granted: Bool) {
        self.granted = granted
    }
}

@MainActor
struct OnboardingControllerTests {
    /// A fresh domain per test: Swift Testing makes a new instance for each one.
    private let defaults: UserDefaults = {
        let name = "OnboardingControllerTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }()

    private func make(granted: Bool = true) -> (OnboardingController, FakeAccessGate) {
        let access = FakeAccessGate(granted: granted)
        return (OnboardingController(defaults: defaults, access: access.gate), access)
    }

    @Test func showsOnFirstLaunchUntilClosed() {
        let (controller, _) = make()
        #expect(controller.shouldShowOnLaunch)
        controller.present(replay: false)
        controller.close()
        #expect(!controller.shouldShowOnLaunch)
        #expect(defaults.integer(forKey: OnboardingController.seenVersionKey) == OnboardingController.currentVersion)
    }

    @Test func quittingMidwayShowsItAgain() {
        let (controller, _) = make()
        controller.present(replay: false)
        controller.next()
        #expect(controller.shouldShowOnLaunch)
    }

    @Test func aReplayDoesNotMarkItSeen() {
        let (controller, _) = make()
        controller.present(replay: true)
        controller.close()
        #expect(controller.shouldShowOnLaunch)
    }

    @Test func theMenuDuringTheFirstShowingRestartsItAndStillMarksItSeen() {
        let (controller, _) = make()
        controller.present(replay: false)
        controller.next()
        controller.present(replay: true)
        #expect(controller.index == 0)
        controller.close()
        #expect(!controller.shouldShowOnLaunch)
    }

    @Test func theAccessSlideIsOnlyForThoseWithoutAccess() {
        let (without, _) = make(granted: false)
        without.present(replay: false)
        #expect(without.slides.count == 8)
        #expect(without.slides.last?.kind == .access)
        #expect(!without.isAccessOnly)

        let (with, _) = make(granted: true)
        with.present(replay: false)
        #expect(with.slides.count == 7)
        #expect(with.slides.last?.kind == .settings)
    }

    @Test func theSlideSetStaysWhileOpen() {
        let (controller, access) = make(granted: false)
        controller.present(replay: false)
        access.granted = true
        access.gate.refresh()
        #expect(controller.slides.count == 8)
        #expect(controller.slides.last?.kind == .access)
    }

    @Test func slidesStayInBoundsAndEveryEntryRestartsTheScene() {
        let (controller, _) = make()
        controller.present(replay: false)
        let run = controller.run
        controller.back()
        #expect(controller.index == 0)
        #expect(controller.run == run)
        for _ in 0..<20 { controller.next() }
        #expect(controller.isLast)
        #expect(controller.isPresented)
        #expect(controller.run == run + controller.slides.count - 1)
        controller.back()
        #expect(controller.index == controller.slides.count - 2)
    }

    @Test func startOnTheLastSlideCloses() {
        let (controller, _) = make()
        controller.present(replay: false)
        for _ in 0..<(controller.slides.count - 1) { controller.primaryAction() }
        #expect(controller.isPresented)
        controller.primaryAction()
        #expect(!controller.isPresented)
    }

    @Test func theAccessScreenShowsOnItsOwnWithoutRecordingAnything() {
        let (controller, _) = make(granted: false)
        controller.presentAccessOnly()
        #expect(controller.isPresented)
        #expect(controller.isAccessOnly)
        #expect(controller.slides.map(\.kind) == [.access])
        #expect(controller.isLast)
        controller.close()
        #expect(controller.shouldShowOnLaunch)
        #expect(!controller.isAccessOnly)
    }

    @Test func theAccessScreenIsPointlessWithAccess() {
        let (controller, _) = make(granted: true)
        controller.presentAccessOnly()
        #expect(!controller.isPresented)
    }

    @Test func theButtonOfTheLoneAccessScreenAsksForAccess() {
        let (controller, access) = make(granted: false)
        controller.presentAccessOnly()
        controller.primaryAction()
        #expect(access.requests == 1)
        #expect(controller.isPresented)
    }

    @Test func theMenuOpensTheTutorialOverTheLoneAccessScreen() {
        let (controller, _) = make(granted: false)
        controller.presentAccessOnly()
        controller.present(replay: true)
        #expect(!controller.isAccessOnly)
        #expect(controller.slides.count == 8)
        #expect(controller.index == 0)
    }

    @Test func theCardButtonAsksForAccess() {
        let (controller, access) = make(granted: false)
        controller.present(replay: false)
        controller.requestAccess()
        #expect(access.requests == 1)
    }

    @Test func keysDriveTheTutorial() {
        let (controller, _) = make()
        #expect(!controller.handleKey(.enter))
        controller.present(replay: false)
        #expect(controller.handleKey(.enter))
        #expect(controller.index == 1)
        #expect(controller.handleKey(.escape))
        #expect(!controller.isPresented)
    }

    @Test func returnOnTheLastSlideStarts() {
        let (controller, _) = make()
        controller.present(replay: false)
        for _ in 0..<(controller.slides.count - 1) { controller.next() }
        #expect(controller.handleKey(.enter))
        #expect(!controller.isPresented)
    }

    @Test func theTutorialLeavesOtherKeysAlone() {
        let (controller, _) = make()
        controller.present(replay: false)
        #expect(!controller.handleKey(.up))
        #expect(!controller.handleKey(.down))
        #expect(controller.index == 0)
    }

    @Test func theAccessSlideHasNoKeys() {
        let (controller, _) = make(granted: false)
        controller.present(replay: false)
        for _ in 0..<(controller.slides.count - 1) { controller.next() }
        #expect(controller.slide.kind == .access)
        #expect(!controller.handleKey(.enter))
        #expect(!controller.handleKey(.escape))
        #expect(controller.isPresented)

        let (lone, _) = make(granted: false)
        lone.presentAccessOnly()
        #expect(!lone.handleKey(.enter))
        #expect(!lone.handleKey(.escape))
        #expect(lone.isPresented)
    }

    @Test func showingThePanelAgainRestartsTheSceneOnlyWhileOpen() {
        let (controller, _) = make()
        controller.restartScene()
        #expect(controller.run == 0)
        controller.present(replay: false)
        controller.restartScene()
        #expect(controller.run == 2)
    }
}
```

- [ ] **Step 2: Запустить — падает**

Run: `swift test --filter OnboardingControllerTests`
Expected: FAIL: ошибка сборки `cannot find 'OnboardingController' in scope`.

- [ ] **Step 3: Код**

Правила — из спеки, «Кому и когда», «Управление» и «Слайд «ДОСТУП»». Набор слайдов складывается при открытии и не меняется до закрытия. Увиденным обучение отмечается при закрытии, если это не повтор из меню и не одиночный экран доступа. Разрешение контроллер только читает и запрашивает: `AccessGate` уже есть в приложении, а опрос раз в секунду держит `JournalPanelController`.

Клавиши: Return — «Дальше», на последнем слайде «Начать»; Esc закрывает обучение, но не панель. ↑ и ↓ обучение не берёт: они остаются журналу. ← и → появятся в `JournalKey` в Task 10, и `switch` без `default` заставит их там дописать. На слайде «ДОСТУП» и на одиночном экране доступа клавиш нет вовсе.

Создать `Sources/BufferJournal/Onboarding/OnboardingController.swift`:

```swift
import Combine
import Foundation

/// The tutorial's state: whether it is on screen, which slides this showing has and which one is
/// current. It also remembers that the person has seen it, and shows the access slide on its own
/// when the tutorial was seen but Stash still may not paste.
@MainActor
final class OnboardingController: ObservableObject {
    /// Bump to show the tutorial to everyone again after a big update.
    static let currentVersion = 1
    static let seenVersionKey = "OnboardingSeenVersion"

    @Published private(set) var isPresented = false
    @Published private(set) var slides: [OnboardingSlide] = OnboardingSlides.slides(hasAccess: true)
    @Published private(set) var index = 0
    /// Grows each time a slide is entered or the panel shows again; scenes restart on a change.
    @Published private(set) var run = 0
    /// A showing opened from the menu does not mark the tutorial as seen.
    private(set) var isReplay = false
    /// The access slide alone: no progress bars, and the bottom button opens System Settings.
    private(set) var isAccessOnly = false

    private let defaults: UserDefaults
    private let access: AccessGate

    init(defaults: UserDefaults = .standard, access: AccessGate) {
        self.defaults = defaults
        self.access = access
    }

    var shouldShowOnLaunch: Bool {
        defaults.integer(forKey: Self.seenVersionKey) < Self.currentVersion
    }

    var slide: OnboardingSlide {
        slides[index]
    }

    var isLast: Bool {
        index == slides.count - 1
    }

    /// Opens the tutorial on its first slide. The slide set is taken here and stays fixed until it
    /// closes, so a permission granted midway does not move the ground under the person.
    func present(replay: Bool) {
        if isPresented, !isAccessOnly {
            // The menu item during the first showing restarts it; closing still marks it seen.
            isReplay = isReplay && replay
        } else {
            isReplay = replay
            isAccessOnly = false
            slides = OnboardingSlides.slides(hasAccess: access.isGranted)
            isPresented = true
        }
        index = 0
        run += 1
    }

    /// The access slide on its own: the tutorial was seen, but Stash has no Accessibility access.
    /// With access there is nothing to ask for.
    func presentAccessOnly() {
        guard !access.isGranted else { return }
        isReplay = false
        isAccessOnly = true
        slides = [OnboardingSlides.accessSlide]
        isPresented = true
        index = 0
        run += 1
    }

    func next() {
        guard isPresented, index < slides.count - 1 else { return }
        index += 1
        run += 1
    }

    func back() {
        guard isPresented, index > 0 else { return }
        index -= 1
        run += 1
    }

    /// The bottom button: "Next", "Start" on the last slide, "Open Settings" on the lone access screen.
    func primaryAction() {
        if isAccessOnly {
            requestAccess()
        } else if isLast {
            close()
        } else {
            next()
        }
    }

    func close() {
        guard isPresented else { return }
        isPresented = false
        // A replay from the menu and the lone access screen record nothing.
        if !isReplay, !isAccessOnly {
            defaults.set(Self.currentVersion, forKey: Self.seenVersionKey)
        }
        isAccessOnly = false
    }

    /// The panel showed again: the current scene starts over.
    func restartScene() {
        guard isPresented else { return }
        run += 1
    }

    /// Asks macOS for Accessibility access; the panel drops to the normal window level on its own,
    /// so it does not cover System Settings.
    func requestAccess() {
        access.request()
    }

    /// Keys while the tutorial is open: Return goes on ("Start" on the last slide), Escape closes
    /// the tutorial but not the panel. Up and Down are none of the tutorial's business — they stay
    /// with the journal. The access slide has no keys at all: Return and Escape belong to System
    /// Settings, where the person is headed, and that slide is turned with the mouse and buttons.
    func handleKey(_ key: JournalKey) -> Bool {
        guard isPresented, !isAccessOnly, slide.kind != .access else { return false }
        switch key {
        case .enter:
            primaryAction()
            return true
        case .escape:
            close()
            return true
        case .up, .down:
            return false
        }
    }
}
```

- [ ] **Step 4: Запустить — проходит**

Run: `swift test --filter OnboardingControllerTests`
Expected: PASS: 18 тестов.

- [ ] **Step 5: Коммит**

```bash
git add Sources/BufferJournal/Onboarding/OnboardingController.swift Tests/BufferJournalTests/OnboardingControllerTests.swift
git commit -m "Tutorial controller: showing, slides, keys and access" -m "Access comes from the app's own AccessGate; the access slide also shows on its own, without the tutorial and without keys."
```

---

### Task 9: Рамка обучения: полосы, карточка по сцене, текст, кнопка

**Files:**
- Create: `Sources/BufferJournal/Onboarding/SceneClock.swift` — часы сцены на `TimelineView`
- Create: `Sources/BufferJournal/Onboarding/OnboardingSceneView.swift` — выбор сцены и её холста; пока сцены `Color.clear`, холсты 480 × 240
- Create: `Sources/BufferJournal/Onboarding/OnboardingChrome.swift` — цвета, кнопки, полоса прогресса, окружение кнопки доступа
- Create: `Sources/BufferJournal/Onboarding/OnboardingView.swift` — каркас в двух видах: обучение и одиночный слайд «ДОСТУП»
- Test: `Tests/BufferJournalTests/SnapshotTests.swift` — PNG рамки в трёх размерах панели, в обоих видах; `Tests/BufferJournalTests/OnboardingViewTests.swift`

**Interfaces:**
- Consumes: `OnboardingController` (Task 8) — `isPresented`, `isAccessOnly`, `slides`, `index`, `run`, `slide`, `isLast`, `next()`, `back()`, `primaryAction()`, `close()`; `OnboardingLayout` (Task 6) — `sceneSize`, `sceneScale(_:in:)`, `cardSize(for:in:)`, `titleFontSize(widthAt100:rowWidth:panelHeight:)`, `HeavyTextMetrics.width(_:size:tracking:)`; `SceneTime`, `SceneLoop.time(elapsed:duration:loops:)` (Task 7); `OnboardingSlide`, `OnboardingSlides.all`, `OnboardingSceneKind` (Task 5); `AccessGate` (`AccessibilityAccess.swift`, уже в приложении); `WindowDragHandle`, `ThemePalette` (Task 2).
- Produces: `SceneClock(duration:loops:still:content:)`; `OnboardingSceneView(slide:still:)`, `static func size(of: OnboardingSceneKind) -> CGSize?` (у первого слайда `nil`) и `static func canvas(for:at:in:) -> some View`.
- Produces: `OnboardingColors(isDark:)` — `field`, `close`, `text`, `barFill`, `barTrack`, `cardShadow`, `wordmark`, `title`, `button(_ level: Int)`; `OnboardingPrimaryButtonStyle`, `OnboardingCloseButtonStyle`, `OnboardingProgressBar`.
- Produces: `OnboardingView(controller:access:l10n:onOpenSettings:onClosePanel:)`, `static func spoken(_ word: String) -> String` — слово слайда предложением для VoiceOver.
- Produces: `EnvironmentValues.onboardingOpenSettings: () -> Void` — кнопка «Открыть настройки» внутри карточки слайда «ДОСТУП» (Task 19) берёт действие отсюда, чтобы оно было тем же, что у нижней кнопки.
- Produces: `EnvironmentValues.scenesHoldStopFrame` — тесты-снимки держат сцены на стоп-кадре.
- Produces (тесты): `SnapshotTests.render(_:name:)`, `SnapshotTests.schemes`, `SnapshotTests.sizes`, `controller(on:)`, `accessOnlyController()`, `gate(granted:)`.

- [ ] **Step 1: Часы сцены**

Сцена играет с момента появления: `TimelineView(.animation)` даёт время, `SceneLoop` превращает его в круг. «Меньше движения» и слайд «ДОСТУП» с полученным доступом держат стоп-кадр; тесты-снимки держат его через `scenesHoldStopFrame`. Сцена без круга перестаёт просить кадры, когда доиграла.

Создать `Sources/BufferJournal/Onboarding/SceneClock.swift`:

```swift
import SwiftUI

/// Runs a scene: plays it from the moment it appears and loops it, or holds its stop frame.
struct SceneClock<Content: View>: View {
    let duration: Double
    let loops: Bool
    /// Stop frame only: "reduce motion", or the access slide once access is granted.
    let still: Bool
    @ViewBuilder let content: (SceneTime) -> Content

    @Environment(\.scenesHoldStopFrame) private var holdStopFrame
    @State private var start = Date()
    @State private var finished = false

    var body: some View {
        if still || finished || holdStopFrame {
            content(.end(of: duration))
        } else {
            TimelineView(.animation) { context in
                content(SceneLoop.time(elapsed: context.date.timeIntervalSince(start), duration: duration, loops: loops))
            }
            .task {
                // A scene that plays once stops asking for frames when it is done.
                guard !loops else { return }
                try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                finished = true
            }
        }
    }
}

private struct HoldStopFrameKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Snapshot tests set it to see each scene's stop frame instead of its first frame.
    var scenesHoldStopFrame: Bool {
        get { self[HoldStopFrameKey.self] }
        set { self[HoldStopFrameKey.self] = newValue }
    }
}
```

- [ ] **Step 2: Выбор сцены**

Каждая сцена — отдельная задача ниже; до неё её место занимает `Color.clear`, а холст — 480 × 240. У сцен 2–8 свой холст по содержимому, он растёт или уменьшается во всё свободное место с сохранением пропорций; свой размер каждая сцена ставит в своей задаче. У первого слайда холста нет. `size` и `canvas` открыты для рамки и тестов-снимков.

Создать `Sources/BufferJournal/Onboarding/OnboardingSceneView.swift`:

```swift
import SwiftUI

/// The card's content: the slide's scene, fitted into the card and run by its clock.
struct OnboardingSceneView: View {
    let slide: OnboardingSlide
    let still: Bool

    var body: some View {
        GeometryReader { geometry in
            SceneClock(duration: slide.duration, loops: slide.loops, still: still) { time in
                Self.canvas(for: slide.kind, at: time, in: geometry.size)
            }
        }
        .environment(\.solidAccents, true)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Each scene's own canvas, fitted to what it shows; the card hugs it. The first slide has no
    /// canvas: it lays its logo out by whatever room it gets. Every scene keeps the placeholder
    /// size until its own task gives it the one from the spec.
    static func size(of kind: OnboardingSceneKind) -> CGSize? {
        switch kind {
        case .hero: nil
        case .hotKey: OnboardingLayout.sceneSize
        case .paste: OnboardingLayout.sceneSize
        case .pin: OnboardingLayout.sceneSize
        case .images: OnboardingLayout.sceneSize
        case .keys: OnboardingLayout.sceneSize
        case .settings: OnboardingLayout.sceneSize
        case .access: OnboardingLayout.sceneSize
        }
    }

    /// The scene fitted into `area`, grown or shrunk to fill it and keeping its proportions.
    @ViewBuilder
    static func canvas(for kind: OnboardingSceneKind, at time: SceneTime, in area: CGSize) -> some View {
        if let size = size(of: kind) {
            scene(kind, at: time, area: area)
                .frame(width: size.width, height: size.height, alignment: .topLeading)
                .scaleEffect(OnboardingLayout.sceneScale(size, in: area))
                .frame(width: area.width, height: area.height)
        } else {
            scene(kind, at: time, area: area)
                .frame(width: area.width, height: area.height)
        }
    }

    @ViewBuilder
    private static func scene(_ kind: OnboardingSceneKind, at time: SceneTime, area: CGSize) -> some View {
        switch kind {
        case .hero: Color.clear
        case .hotKey: Color.clear
        case .paste: Color.clear
        case .pin: Color.clear
        case .images: Color.clear
        case .keys: Color.clear
        case .settings: Color.clear
        case .access: Color.clear
        }
    }
}
```

- [ ] **Step 3: Цвета, кнопки и окружение рамки**

Цвета — таблица «Цвета» из спеки: светло-серое поле или чёрное, оранжевые полосы и кнопка, «Stash» первого слайда — оранжевым иконки. Рядом окружение с действием «Открыть настройки»: нижняя кнопка одиночного вида и кнопка внутри карточки слайда «ДОСТУП» делают одно и то же.

Создать `Sources/BufferJournal/Onboarding/OnboardingChrome.swift`:

```swift
import SwiftUI

/// Colours of the tutorial's frame: a light grey field in light, black in dark, orange accents.
struct OnboardingColors {
    let isDark: Bool

    /// The window's own light grey, or black.
    var field: Color { isDark ? .black : ThemePalette(colorScheme: .light).windowBackground }
    var close: Color { isDark ? Color.white.opacity(0.9) : Color.black.opacity(0.8) }
    var text: Color { isDark ? Color.white.opacity(0.68) : Color.black.opacity(0.68) }
    var barFill: Color { ThemePalette.orange }
    var barTrack: Color { isDark ? Color.white.opacity(0.16) : Color.black.opacity(0.1) }
    var cardShadow: Color { isDark ? .clear : Color.black.opacity(0.1) }
    /// "Stash" on the first slide, in the icon's orange. It is a logo, so no contrast minimum applies.
    var wordmark: Color { ThemePalette.orange }
    /// The first slide's big title.
    var title: Color { ThemePalette.orange }

    /// The main button, orange in both looks; `level` is 0 at rest, 1 hovered, 2 pressed.
    func button(_ level: Int) -> Color {
        ThemePalette.darken(ThemePalette.orange, by: 0.08 * Double(min(max(level, 0), 2)))
    }
}

/// "Next" / "Start" / "Open Settings": an orange capsule that darkens on hover and press, like
/// the journal's buttons.
struct OnboardingPrimaryButtonStyle: ButtonStyle {
    let colors: OnboardingColors

    func makeBody(configuration: Configuration) -> some View {
        PrimaryBody(configuration: configuration, colors: colors)
    }

    private struct PrimaryBody: View {
        let configuration: ButtonStyleConfiguration
        let colors: OnboardingColors
        @State private var isHovered = false

        var body: some View {
            configuration.label
                .foregroundStyle(Color.white)
                .background(Capsule().fill(colors.button(configuration.isPressed ? 2 : (isHovered ? 1 : 0))))
                .contentShape(Capsule())
                .onHover { isHovered = $0 }
                .animation(.easeOut(duration: 0.12), value: isHovered)
        }
    }
}

/// The close cross: a plate of its own colour at 10 % on hover and 16 % when pressed.
struct OnboardingCloseButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        CloseBody(configuration: configuration, color: color)
    }

    private struct CloseBody: View {
        let configuration: ButtonStyleConfiguration
        let color: Color
        @State private var isHovered = false

        var body: some View {
            configuration.label
                .foregroundStyle(color)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(color.opacity(configuration.isPressed ? 0.16 : (isHovered ? 0.10 : 0)))
                )
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .onHover { isHovered = $0 }
                .animation(.easeOut(duration: 0.12), value: isHovered)
        }
    }
}

/// One progress bar per slide: done ones full, later ones empty, the current one fills in
/// 0.3 s when entered and stays full. It is not a timer.
struct OnboardingProgressBar: View {
    enum Phase {
        case done
        case current
        case upcoming
    }

    let phase: Phase
    let colors: OnboardingColors
    let animated: Bool

    @State private var filled = false

    var body: some View {
        Capsule()
            .fill(colors.barTrack)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(colors.barFill)
                    .scaleEffect(x: fill, y: 1, anchor: .leading)
            }
            .clipShape(Capsule())
            .onAppear {
                guard phase == .current else { return }
                withAnimation(animated ? .easeOut(duration: 0.3) : nil) {
                    filled = true
                }
            }
    }

    private var fill: CGFloat {
        switch phase {
        case .done: 1
        case .upcoming: 0
        case .current: filled ? 1 : 0
        }
    }
}

private struct OpenSettingsKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    /// Asks for Accessibility access, opens System Settings and lowers the panel. The access
    /// slide's own button inside the card and the single view's bottom button share it.
    var onboardingOpenSettings: () -> Void {
        get { self[OpenSettingsKey.self] }
        set { self[OpenSettingsKey.self] = newValue }
    }
}
```

- [ ] **Step 4: Каркас в двух видах**

Один вид рисует и обучение, и одиночный показ слайда «ДОСТУП»; вид выбирает `controller.isAccessOnly`.

Сверху вниз: строка из полос (3 pt, зазор 4) и крестика, место для карточки, текст рядом с кнопкой 150 × 36. Отступы 12 / 20 / 16, между блоками 10. На первом слайде под шапкой большой оранжевый заголовок — его слово, «ПРИВЕТ, ЭТО»: `.heavy`, трекинг −2 %, кегль по ширине строки, но не больше 10 % высоты панели. У остальных слайдов заголовка нет, слово — только заголовок карточки для VoiceOver, прочитанный предложением. Карточка занимает всю ширину или всю высоту свободного места и обнимает сцену; стоит по центру и при смене слайда пружинисто перетекает в размер следующей. Тексты всех восьми слайдов лежат друг на друге, виден один — высота низа не прыгает. Клик по левым 30 % ниже шапки — назад, по остальному — вперёд; строка с полосами двигает окно.

В одиночном показе слайда «ДОСТУП» листать нечего: полос нет, зон клика нет, крестик закрывает панель, а нижняя кнопка — «Открыть настройки».

Создать `Sources/BufferJournal/Onboarding/OnboardingView.swift`:

```swift
import AppKit
import SwiftUI

/// The tutorial: stories over the whole journal panel. Progress bars and the close cross on top,
/// the first slide's big title under them, the scene in a card that hugs it, and the text beside
/// the main button at the bottom. The same view shows the access slide on its own, without the
/// bars and with "Open Settings" as its main button.
struct OnboardingView: View {
    @ObservedObject var controller: OnboardingController
    /// Watched so the access slide goes to its stop frame the moment access is granted.
    @ObservedObject var access: AccessGate
    let l10n: L10n
    /// Asks for access, opens System Settings and lowers the panel (`JournalPanelController`).
    let onOpenSettings: () -> Void
    /// Closes the panel: the single access screen has no journal to fall back to.
    let onClosePanel: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Metrics {
        static let top: CGFloat = 12
        static let side: CGFloat = 20
        static let bottom: CGFloat = 16
        static let gap: CGFloat = 10
        /// The bars share a row with the 28 pt close cross.
        static let headHeight: CGFloat = 28
        static let bar: CGFloat = 3
        static let cardRadius: CGFloat = 20
        static let buttonWidth: CGFloat = 150
        static let buttonHeight: CGFloat = 36
        static let textSize: CGFloat = 13
        /// Line height 1.4 of the 13 pt system font, whose own line is about 1.19 of its size.
        static let lineSpacing: CGFloat = 2.7
        /// Share of the panel width the "back" zone takes.
        static let backZone: CGFloat = 0.3
    }

    private var colors: OnboardingColors {
        OnboardingColors(isDark: colorScheme == .dark)
    }

    /// Everything inside the card is drawn in the Stash style, whatever theme is picked.
    private var palette: ThemePalette {
        ThemePalette(colorScheme: colorScheme, solid: true)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                colors.field

                if !controller.isAccessOnly {
                    zones(width: geometry.size.width, top: Metrics.top + Metrics.headHeight)
                }

                VStack(spacing: 0) {
                    head
                    if controller.slide.kind == .hero {
                        title(rowWidth: geometry.size.width - 2 * Metrics.side, panelHeight: geometry.size.height)
                            .padding(.top, Metrics.gap)
                            .transition(.opacity)
                    }
                    stage
                        .padding(.top, Metrics.gap)
                    footer
                        .padding(.top, Metrics.gap)
                }
                .animation(reduceMotion ? nil : .easeOut(duration: 0.26), value: controller.slide.kind == .hero)
                .padding(.top, Metrics.top)
                .padding(.horizontal, Metrics.side)
                .padding(.bottom, Metrics.bottom)
            }
        }
        .environment(\.onboardingOpenSettings, onOpenSettings)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(controller.isAccessOnly
            ? l10n("Stash needs Accessibility access", "Stash нужен Универсальный доступ")
            : l10n("Stash tour", "Знакомство со Stash"))
        .accessibilityAddTraits(.isModal)
        .onChange(of: controller.index) { index in
            announce(index)
        }
    }

    // MARK: Head

    private var head: some View {
        HStack(spacing: 12) {
            // Nothing to page through on the single access screen, so it shows no bars.
            if controller.isAccessOnly {
                Spacer(minLength: 0)
            } else {
                bars
            }
            closeButton
        }
        .frame(height: Metrics.headHeight)
        // The bars' row moves the panel, like the journal's header.
        .background(WindowDragHandle())
    }

    private var bars: some View {
        HStack(spacing: 4) {
            ForEach(Array(controller.slides.enumerated()), id: \.element.id) { offset, slide in
                OnboardingProgressBar(phase: phase(of: offset), colors: colors, animated: !reduceMotion)
                    // A new identity each time the slide is entered refills the current bar.
                    .id(offset == controller.index ? "\(slide.kind.rawValue)-\(controller.run)" : slide.kind.rawValue)
            }
        }
        .frame(height: Metrics.bar)
    }

    private func phase(of offset: Int) -> OnboardingProgressBar.Phase {
        if offset < controller.index { return .done }
        return offset == controller.index ? .current : .upcoming
    }

    /// Closes the tutorial and leaves the journal under it; on the single access screen there is
    /// no journal to show, so it closes the panel.
    private var closeButton: some View {
        Button {
            if controller.isAccessOnly {
                onClosePanel()
            } else {
                controller.close()
            }
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(OnboardingCloseButtonStyle(color: colors.close))
        .help(l10n("Close", "Закрыть"))
        .accessibilityLabel(l10n("Close", "Закрыть"))
    }

    /// "HELLO, THIS IS" on the first slide: big, orange, in the top left corner, as the slides'
    /// words once were, and no taller than 10 % of the panel.
    private func title(rowWidth: CGFloat, panelHeight: CGFloat) -> some View {
        let text = controller.slide.word(l10n)
        let size = OnboardingLayout.titleFontSize(
            widthAt100: HeavyTextMetrics.width(text, size: 100, tracking: -2),
            rowWidth: rowWidth,
            panelHeight: panelHeight
        )
        let height = (size * 0.95).rounded()
        return Text(text)
            .font(.system(size: size, weight: .heavy))
            .tracking(-0.02 * size)
            .foregroundStyle(colors.title)
            .lineLimit(1)
            .fixedSize()
            .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .leading)
            // The card's heading already says it to VoiceOver.
            .accessibilityHidden(true)
    }

    // MARK: Stage

    /// The room between the bars and the text. The card hugs the slide's scene and sits in the
    /// middle; between slides it grows or shrinks to the next scene.
    private var stage: some View {
        GeometryReader { geometry in
            let kind = controller.slide.kind
            let scene = OnboardingSceneView.size(of: kind)
            let card = scene.map { OnboardingLayout.cardSize(for: $0, in: geometry.size) } ?? geometry.size

            self.card(size: card, hasSurface: scene != nil)
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    private func card(size: CGSize, hasSurface: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)

        return ZStack {
            // An opaque copy of the panel: the window background under the list pane's tint.
            shape
                .fill(palette.windowBackground)
                .overlay(shape.fill(palette.sidebarTint))
                .overlay(shape.strokeBorder(palette.border, lineWidth: 1))
                .shadow(color: colors.cardShadow, radius: 16, y: 6)
                .opacity(hasSurface ? 1 : 0)
                .allowsHitTesting(false)

            // The first slide has no card, so nothing clips its flying tiles.
            OnboardingSceneView(slide: controller.slide, still: isStill)
                .clipShape(hasSurface ? AnyShape(shape) : AnyShape(Rectangle().inset(by: -200)))
                .id(controller.run)
                .transition(.opacity)
        }
        .frame(width: size.width, height: size.height)
        .animation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.86), value: controller.index)
        .animation(.easeOut(duration: 0.26), value: hasSurface)
        .animation(.easeOut(duration: 0.2), value: controller.run)
        // The slide's name, for VoiceOver: the scene itself says nothing to it.
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Self.spoken(controller.slide.word(l10n)))
        .accessibilityAddTraits(.isHeader)
    }

    private var isStill: Bool {
        reduceMotion || (controller.slide.kind == .access && access.isGranted)
    }

    // MARK: Footer

    private var footer: some View {
        HStack(alignment: .center, spacing: 16) {
            texts
            Button {
                if controller.isAccessOnly {
                    onOpenSettings()
                } else {
                    controller.primaryAction()
                }
            } label: {
                Text(primaryTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 16)
                    // 150 pt wide for "Next" and "Start"; "Открыть настройки" is allowed to grow.
                    .frame(minWidth: Metrics.buttonWidth, minHeight: Metrics.buttonHeight, maxHeight: Metrics.buttonHeight)
            }
            .buttonStyle(OnboardingPrimaryButtonStyle(colors: colors))
        }
    }

    private var primaryTitle: String {
        if controller.isAccessOnly {
            return l10n("Open Settings", "Открыть настройки")
        }
        return controller.isLast ? l10n("Start", "Начать") : l10n("Next", "Дальше")
    }

    /// Every slide's text lies in the same spot, the current one visible: the block is as tall
    /// as the longest text, hidden slides included, so the button never jumps.
    private var texts: some View {
        ZStack(alignment: .topLeading) {
            ForEach(OnboardingSlides.all) { slide in
                let isCurrent = slide.kind == controller.slide.kind
                Text(slide.text(l10n))
                    .font(.system(size: Metrics.textSize))
                    .lineSpacing(Metrics.lineSpacing)
                    .foregroundStyle(colors.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .opacity(isCurrent ? 1 : 0)
                    .offset(y: isCurrent || reduceMotion ? 0 : 6)
                    .accessibilityHidden(!isCurrent)
            }
        }
        .animation(.easeOut(duration: 0.26), value: controller.index)
        .allowsHitTesting(false)
    }

    // MARK: Navigation

    /// Clicks below the bars: the left 30 % of the panel goes back, the rest goes on.
    private func zones(width: CGFloat, top: CGFloat) -> some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: width * Metrics.backZone)
                .contentShape(Rectangle())
                .onTapGesture { controller.back() }
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { controller.next() }
        }
        .padding(.top, top)
        .accessibilityHidden(true)
    }

    /// "ПРИВЕТ, ЭТО" read as "Привет, это": capitals only where a sentence has them.
    static func spoken(_ word: String) -> String {
        let lower = word.lowercased()
        return lower.prefix(1).uppercased() + lower.dropFirst()
    }

    private func announce(_ index: Int) {
        // One slide on its own is not a story: nothing to count.
        guard !controller.isAccessOnly else { return }
        let count = controller.slides.count
        let message = l10n("Slide \(index + 1) of \(count)", "Слайд \(index + 1) из \(count)")
        NSAccessibility.post(
            element: NSApplication.shared,
            notification: .announcementRequested,
            userInfo: [
                .announcement: message,
                .priority: NSAccessibilityPriorityLevel.high.rawValue,
            ]
        )
    }
}
```

- [ ] **Step 5: Тесты рамки**

Тесты-снимки рисуют обучение в PNG через `ImageRenderer`, сцены — на стоп-кадре. Оба вида рамки: обучение на трёх слайдах и одиночный слайд «ДОСТУП». Без `SNAPSHOT_DIR` они только проверяют, что всё рисуется.

Создать `Tests/BufferJournalTests/SnapshotTests.swift`:

```swift
import AppKit
import SwiftUI
import Testing
@testable import BufferJournal

/// PNGs of the tutorial for a person to look at. Run with a folder to write into:
///     SNAPSHOT_DIR=/tmp/stash-snapshots swift test --filter SnapshotTests
/// Without SNAPSHOT_DIR these tests only check that every view renders.
@MainActor
struct SnapshotTests {
    private static let directory = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"].map { URL(fileURLWithPath: $0) }
    private static let schemes: [(ColorScheme, String)] = [(.light, "light"), (.dark, "dark")]
    /// The panel at its smallest, its default and a large size.
    private static let sizes = [
        CGSize(width: 560, height: 360),
        CGSize(width: 640, height: 440),
        CGSize(width: 900, height: 600),
    ]

    private func render<V: View>(_ view: V, name: String) throws {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let image = try #require(renderer.nsImage, "\(name) did not render")
        guard let directory = Self.directory else { return }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let bitmap = try #require(image.tiffRepresentation.flatMap(NSBitmapImageRep.init(data:)))
        let png = try #require(bitmap.representation(using: .png, properties: [:]))
        try png.write(to: directory.appendingPathComponent("\(name).png"))
    }

    /// An Accessibility gate that answers what the test wants and never touches the system.
    private func gate(granted: Bool) -> AccessGate {
        AccessGate(access: AccessibilityAccess(isGranted: { granted }, request: {}))
    }

    private func defaults() -> UserDefaults {
        UserDefaults(suiteName: "SnapshotTests-\(UUID().uuidString)")!
    }

    private func controller(on kind: OnboardingSceneKind) -> (OnboardingController, AccessGate) {
        let access = gate(granted: false)
        let controller = OnboardingController(defaults: defaults(), access: access)
        controller.present(replay: true)
        while controller.slide.kind != kind { controller.next() }
        return (controller, access)
    }

    private func accessOnlyController() -> (OnboardingController, AccessGate) {
        let access = gate(granted: false)
        let controller = OnboardingController(defaults: defaults(), access: access)
        controller.presentAccessOnly()
        return (controller, access)
    }

    private func frame(_ controller: OnboardingController, _ access: AccessGate, scheme: ColorScheme, size: CGSize) -> some View {
        OnboardingView(
            controller: controller,
            access: access,
            l10n: L10n(language: .russian),
            onOpenSettings: {},
            onClosePanel: {}
        )
        .frame(width: size.width, height: size.height)
        .environment(\.colorScheme, scheme)
        .environment(\.scenesHoldStopFrame, true)
    }

    /// The whole tutorial on three slides, at three panel sizes.
    @Test func tutorialFrame() throws {
        for (scheme, name) in Self.schemes {
            for kind in [OnboardingSceneKind.hero, .keys, .access] {
                for size in Self.sizes {
                    let (controller, access) = controller(on: kind)
                    try render(frame(controller, access, scheme: scheme, size: size), name: "frame-\(kind.rawValue)-\(Int(size.width))-\(name)")
                }
            }
        }
    }

    /// The access slide on its own: no bars, and "Открыть настройки" at the bottom.
    @Test func accessOnlyFrame() throws {
        for (scheme, name) in Self.schemes {
            for size in Self.sizes {
                let (controller, access) = accessOnlyController()
                try render(frame(controller, access, scheme: scheme, size: size), name: "frame-access-only-\(Int(size.width))-\(name)")
            }
        }
    }
}
```

Создать `Tests/BufferJournalTests/OnboardingViewTests.swift`:

```swift
import Testing
@testable import BufferJournal

@MainActor
struct OnboardingViewTests {
    @Test func voiceOverReadsSlideWordsAsSentences() {
        #expect(OnboardingView.spoken("ПРИВЕТ, ЭТО") == "Привет, это")
        #expect(OnboardingView.spoken("HELLO, THIS IS") == "Hello, this is")
        #expect(OnboardingView.spoken("ЗАКРЕП") == "Закреп")
    }
}
```

- [ ] **Step 6: Сборка, тесты, снимки**

Run: `swift build && swift test`
Expected: `Build complete!`, все тесты PASS.

Run: `SNAPSHOT_DIR=/tmp/stash-snapshots swift test --filter SnapshotTests`
Expected: PASS; в `/tmp/stash-snapshots` 24 файла: 18 `frame-<слайд>-<ширина>-<тема>.png` и 6 `frame-access-only-<ширина>-<тема>.png`.

- [ ] **Step 7: Посмотреть снимки**

Проверка вручную: Открыть `frame-hero-640-light.png`: под полосами слева оранжевое «ПРИВЕТ, ЭТО» 44 pt, ниже пустое место под логотип, карточки нет. Открыть `frame-keys-640-light.png` и `frame-keys-640-dark.png`. Светлый: светло-серое поле, оранжевые полосы (восемь, шесть полных) и крестик в одной строке, пустая светлая карточка — холст-заглушка 480 × 240, растянутый во всю ширину места, — с обводкой и мягкой тенью, текст слева, оранжевая капсула «Дальше». Тёмный: чёрное поле, карточка с тонкой обводкой. Открыть `frame-access-640-light.png`: полосы на месте, капсула «Начать». Открыть `frame-access-only-640-light.png`: полос нет, в шапке один крестик справа, карточка стала выше на 13 pt, внизу капсула «Открыть настройки». Жёлтая полоса с перечёркнутым кругом поверх шапки — так `ImageRenderer` рисует AppKit-ручку перетаскивания; в приложении её не видно. На `frame-*-560-*` и `frame-*-900-*` карточка так же упирается в свободное место.

- [ ] **Step 8: Коммит**

```bash
git add Sources/BufferJournal/Onboarding Tests/BufferJournalTests/SnapshotTests.swift Tests/BufferJournalTests/OnboardingViewTests.swift
git commit -m "Tutorial frame: bars, card and footer" -m "The stories layout from the concept, in both looks: the tutorial with its progress
bars, and the access slide alone with Open Settings at the bottom. Only the first
slide keeps a big title; the card hugs its scene. Not wired into the app yet;
scenes are placeholders."
```

---

### Task 10: Подключение: журнал, панель, меню, README

**Files:**
- Modify: `Sources/BufferJournal/JournalKeys.swift` — режимы клавиш: `.off`, `.journal`, `.onboarding`
- Modify: `Sources/BufferJournal/Localization.swift` — `StatusMenuTitles`
- Modify: `Sources/BufferJournal/JournalView.swift` — слой обучения поверх всего, клавиши сначала обучению; экран доступа больше не отдельный
- Delete: `Sources/BufferJournal/AccessScreen.swift` — его место занял слайд «ДОСТУП»
- Modify: `Sources/BufferJournal/JournalPanelController.swift` — `showOnboarding(replay:)`, перезапуск сцены при показе панели, обучение по центру экрана, режим клавиш по содержимому панели
- Modify: `Sources/BufferJournal/AppDelegate.swift` — контроллер, показ при запуске, пункт «Обучение»
- Modify: `README.md`
- Test: `Tests/BufferJournalTests/JournalKeysTests.swift` (переписан под режимы), `Tests/BufferJournalTests/JournalKeyActionTests.swift`

**Interfaces:**
- Consumes: `OnboardingController` (Task 8) — `init(defaults:access:)`, `isPresented`, `isAccessOnly`, `slide`, `present(replay:)`, `presentAccessOnly()`, `restartScene()`, `requestAccess()`, `handleKey(_ key: JournalKey) -> Bool`, `shouldShowOnLaunch`; `OnboardingView(controller:access:l10n:onOpenSettings:onClosePanel:)` (Task 9); `OnboardingSceneKind.access` (Task 5); `AccessGate` (уже в приложении).
- Produces: `enum JournalKey` — добавлены `.left` и `.right`; `JournalKeys.Mode` (`off`, `journal`, `onboarding`), `JournalKeys.PanelContent` (`journal`, `onboarding`, `access`), `JournalKeys.mode(intercepts:panelVisible:content:stashActive:menuOpen:) -> Mode`, `var mode: Mode`.
- Produces: `StatusMenuTitles(l10n:)` — `openStash`, `tutorial`, `closeAfterSelection`, `interceptKeys`, `openAtCaret`, `theme`, `language`, `clearHistory`, `quit`. Меню значка и сцена «НАСТРОЙКИ» (Task 18) берут названия отсюда.
- Produces: `JournalPanelController(store:writer:settings:hotKeys:access:onboarding:)`, `showOnboarding(replay: Bool)`; `JournalView(store:settings:access:onboarding:keyEvents:…)`.
- Removes: `AccessScreen`; `JournalKeys.shouldListen(intercepts:panelVisible:journalShown:stashActive:menuOpen:)`; `JournalKeys.isListening`.

- [ ] **Step 1: Падающий тест режимов клавиш**

Правило одно и чистое: что Stash забирает у приложения под панелью, решает содержимое панели. Журнал — ↑ ↓ Return Esc, обучение — ← → Return Esc, экран доступа — ничего.

Переписать `Tests/BufferJournalTests/JournalKeysTests.swift` целиком:

```swift
import Testing
@testable import BufferJournal

struct JournalKeysTests {
    @Test func theOpenJournalTakesItsOwnKeys() {
        #expect(JournalKeys.mode(intercepts: true, panelVisible: true, content: .journal, stashActive: false, menuOpen: false) == .journal)
    }

    @Test func theTutorialTakesTheArrowsItNeeds() {
        #expect(JournalKeys.mode(intercepts: true, panelVisible: true, content: .onboarding, stashActive: false, menuOpen: false) == .onboarding)
    }

    @Test func theAccessScreenTakesNone() {
        // The user is on their way to System Settings, where Return and Esc are theirs.
        #expect(JournalKeys.mode(intercepts: true, panelVisible: true, content: .access, stashActive: false, menuOpen: false) == .off)
    }

    @Test func letsTheKeysGoOtherwise() {
        for content in [JournalKeys.PanelContent.journal, .onboarding] {
            #expect(JournalKeys.mode(intercepts: true, panelVisible: false, content: content, stashActive: false, menuOpen: false) == .off)
            #expect(JournalKeys.mode(intercepts: true, panelVisible: true, content: content, stashActive: true, menuOpen: false) == .off)
            #expect(JournalKeys.mode(intercepts: true, panelVisible: true, content: content, stashActive: false, menuOpen: true) == .off)
        }
    }

    @Test func staysOutOfTheWayWithInterceptKeysOff() {
        #expect(JournalKeys.mode(intercepts: false, panelVisible: true, content: .journal, stashActive: false, menuOpen: false) == .off)
        #expect(JournalKeys.mode(intercepts: false, panelVisible: true, content: .onboarding, stashActive: false, menuOpen: false) == .off)
    }
}
```

В `Tests/BufferJournalTests/JournalKeyActionTests.swift` заменить:

```swift
    @Test func aDialogIgnoresArrowsAndReturn() {
```

на:

```swift
    @Test func theJournalIgnoresTheTutorialsArrows() {
        // Left and Right are registered only while the tutorial is open; the journal drops them.
        #expect(JournalKeyAction.resolve(.left, dialogShown: false, hasSelection: true) == .ignore)
        #expect(JournalKeyAction.resolve(.right, dialogShown: false, hasSelection: true) == .ignore)
    }

    @Test func aDialogIgnoresArrowsAndReturn() {
```

Run: `swift test --filter JournalKeys`
Expected: не собирается — `JournalKeys.mode`, `JournalKeys.PanelContent`, `JournalKey.left` и `.right` ещё не существуют.

- [ ] **Step 2: Режимы клавиш**

В `Sources/BufferJournal/JournalKeys.swift` заменить:

```swift
/// Keys the journal takes while it is open: plain Up, Down, Return (or keypad Enter) and Escape.
enum JournalKey: Equatable {
    case up
    case down
    case enter
    case escape
}
```

на:

```swift
/// Keys Stash takes while the panel is open: the journal's plain Up, Down, Return (or keypad
/// Enter) and Escape, and the tutorial's Left and Right.
enum JournalKey: Equatable {
    case up
    case down
    case left
    case right
    case enter
    case escape
}
```

В `Sources/BufferJournal/JournalKeys.swift` заменить:

```swift
        switch key {
        case .up: return .moveUp
        case .down: return .moveDown
        case .enter: return hasSelection ? .paste : .ignore
        case .escape: return .closePanel
        }
```

на:

```swift
        switch key {
        case .up: return .moveUp
        case .down: return .moveDown
        // The tutorial's arrows never reach the journal: they are taken only while it is open.
        case .left, .right: return .ignore
        case .enter: return hasSelection ? .paste : .ignore
        case .escape: return .closePanel
        }
```

В `Sources/BufferJournal/JournalKeys.swift` заменить:

```swift
/// The journal's hotkeys. While listening, plain Up, Down, Return, keypad Enter and Escape are
/// registered as global hotkeys, so macOS hands them to Stash instead of the app under the panel.
/// macOS swallows the auto-repeats of a held hotkey, so Up and Down repeat on a timer at the
/// system key-repeat rate.
@MainActor
final class JournalKeys {
    /// Listen only while Intercept Keys is on, the journal is on screen, Stash is not the active
    /// app (its clip editor needs these keys) and no menu of Stash is open (menus are walked with
    /// the arrows). Turned off, every key stays with the app the user is typing in.
    nonisolated static func shouldListen(intercepts: Bool, panelVisible: Bool, journalShown: Bool, stashActive: Bool, menuOpen: Bool) -> Bool {
        intercepts && panelVisible && journalShown && !stashActive && !menuOpen
    }

    let events = PassthroughSubject<JournalKey, Never>()

    var isListening = false {
        didSet {
            guard isListening != oldValue else { return }
            if isListening {
                register()
            } else {
                unregister()
            }
        }
    }

    private static let bindings: [(keyCode: Int, key: JournalKey)] = [
        (kVK_UpArrow, .up),
        (kVK_DownArrow, .down),
        (kVK_Return, .enter),
        (kVK_ANSI_KeypadEnter, .enter),
        (kVK_Escape, .escape),
    ]
```

на:

```swift
/// Stash's hotkeys while the panel is open. The keys of the mode in force are registered as
/// global hotkeys, so macOS hands them to Stash instead of the app under the panel. macOS
/// swallows the auto-repeats of a held hotkey, so Up and Down repeat on a timer at the system
/// key-repeat rate.
@MainActor
final class JournalKeys {
    /// What the panel shows right now.
    enum PanelContent: Equatable {
        case journal
        case onboarding
        case access
    }

    /// Which keys are registered.
    enum Mode: Equatable {
        /// None: every key stays with the app the user is typing in.
        case off
        /// Up, Down, Return, keypad Enter, Escape.
        case journal
        /// Left, Right, Return, keypad Enter, Escape.
        case onboarding
    }

    /// Take keys only while Intercept Keys is on, the panel is on screen, Stash is not the active
    /// app (its clip editor needs these keys) and no menu of Stash is open (menus are walked with
    /// the arrows). The access screen takes none: the user is on their way to System Settings,
    /// where Return and Escape are theirs.
    nonisolated static func mode(intercepts: Bool, panelVisible: Bool, content: PanelContent, stashActive: Bool, menuOpen: Bool) -> Mode {
        guard intercepts, panelVisible, !stashActive, !menuOpen else { return .off }

        switch content {
        case .journal: return .journal
        case .onboarding: return .onboarding
        case .access: return .off
        }
    }

    let events = PassthroughSubject<JournalKey, Never>()

    var mode: Mode = .off {
        didSet {
            guard mode != oldValue else { return }
            unregister()
            register()
        }
    }

    private static func bindings(for mode: Mode) -> [(keyCode: Int, key: JournalKey)] {
        switch mode {
        case .off:
            return []
        case .journal:
            return [
                (kVK_UpArrow, .up),
                (kVK_DownArrow, .down),
                (kVK_Return, .enter),
                (kVK_ANSI_KeypadEnter, .enter),
                (kVK_Escape, .escape),
            ]
        case .onboarding:
            return [
                (kVK_LeftArrow, .left),
                (kVK_RightArrow, .right),
                (kVK_Return, .enter),
                (kVK_ANSI_KeypadEnter, .enter),
                (kVK_Escape, .escape),
            ]
        }
    }
```

В `Sources/BufferJournal/JournalKeys.swift` заменить:

```swift
    private func register() {
        for binding in Self.bindings {
```

на:

```swift
    private func register() {
        for binding in Self.bindings(for: mode) {
```

Run: `swift build 2>&1 | tail -20`
Expected: `JournalPanelController.swift` ругается на `keys.isListening` и `JournalKeys.shouldListen` — их чинит Step 6; остальных ошибок в `JournalKeys.swift` нет.

- [ ] **Step 3: Названия пунктов меню в одном месте**

В `Sources/BufferJournal/Localization.swift` заменить:

```swift
private struct SolidAccentsKey: EnvironmentKey {
```

на:

```swift
/// Titles of the menu bar menu. The tutorial's settings scene draws the same menu.
struct StatusMenuTitles {
    let l10n: L10n

    var openStash: String { l10n("Open Stash", "Открыть Stash") }
    var tutorial: String { l10n("Tutorial", "Обучение") }
    var closeAfterSelection: String { l10n("Close After Selection", "Закрывать после выбора") }
    var interceptKeys: String { l10n("Intercept Keys", "Перехватывать клавиши") }
    var openAtCaret: String { l10n("Open at the Cursor", "Открывать у курсора") }
    var theme: String { l10n("Theme", "Тема") }
    var language: String { l10n("Language", "Язык") }
    var clearHistory: String { l10n("Clear History", "Очистить историю") }
    var quit: String { l10n("Quit", "Выйти") }
}

private struct SolidAccentsKey: EnvironmentKey {
```

- [ ] **Step 4: Журнал: слой обучения вместо экрана доступа**

Обучение лежит в том же `ZStack`, что диалоги и тост, над ними (`zIndex(40)`), и потому обрезается скруглением панели. Отдельного экрана доступа больше нет: без разрешения панель показывает тот же слой с одиночным слайдом «ДОСТУП», а журнал остаётся под ним.

В `Sources/BufferJournal/JournalView.swift` заменить:

```swift
    @ObservedObject var store: ClipboardHistoryStore
    @ObservedObject var settings: AppSettings
    @ObservedObject var access: AccessGate
```

на:

```swift
    @ObservedObject var store: ClipboardHistoryStore
    @ObservedObject var settings: AppSettings
    @ObservedObject var access: AccessGate
    @ObservedObject var onboarding: OnboardingController
```

В `Sources/BufferJournal/JournalView.swift` заменить:

```swift
            if access.isGranted {
                journal
                    .transition(.opacity)
            } else {
                AccessScreen(palette: palette, onOpenSettings: onOpenAccessSettings, onClose: onClose)
                    .transition(.opacity)
            }

            // Dialogs belong to the journal; the access screen never shows one left over.
            if access.isGranted, isClearConfirmationShown || entryPendingDeletion != nil {
```

на:

```swift
            journal

            // Dialogs belong to the journal; the access slide over it never shows one left over.
            if access.isGranted, isClearConfirmationShown || entryPendingDeletion != nil {
```

В `Sources/BufferJournal/JournalView.swift` заменить:

```swift
            if let toastMessage {
                ToastOverlay(message: toastMessage)
                    .padding(.bottom, 56)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(30)
            }
```

на:

```swift
            if let toastMessage {
                ToastOverlay(message: toastMessage)
                    .padding(.bottom, 56)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(30)
            }

            // The tutorial, and the access slide on its own, cover the whole panel.
            if onboarding.isPresented {
                OnboardingView(
                    controller: onboarding,
                    access: access,
                    l10n: l10n,
                    onOpenSettings: onOpenAccessSettings,
                    onClosePanel: onClose
                )
                .transition(.opacity)
                .zIndex(40)
            }
```

В `Sources/BufferJournal/JournalView.swift` заменить:

```swift
        .animation(.easeOut(duration: 0.2), value: access.isGranted)
```

на:

```swift
        .animation(.easeOut(duration: 0.2), value: onboarding.isPresented)
```

В `Sources/BufferJournal/JournalView.swift` заменить:

```swift
    /// Keys arrive as hotkeys while the journal is open (see `JournalKeys`).
    private func handleKey(_ key: JournalKey) {
        let action = JournalKeyAction.resolve(
```

на:

```swift
    /// Keys arrive as hotkeys while the panel is open (see `JournalKeys`).
    private func handleKey(_ key: JournalKey) {
        // The tutorial covers the journal and takes the keys it knows while it is open.
        if onboarding.isPresented, onboarding.handleKey(key) { return }

        let action = JournalKeyAction.resolve(
```

- [ ] **Step 5: Убрать экран доступа**

Его заголовок, текст, кнопка и подсказка живут теперь в слайде «ДОСТУП» (Task 19).

```bash
git rm Sources/BufferJournal/AccessScreen.swift
```

- [ ] **Step 6: Панель**

Панель с обучением встаёт по центру экрана мимо «Открывать у курсора», при каждом показе перезапускает сцену, а без разрешения сама поднимает одиночный слайд «ДОСТУП». Режим клавиш идёт за содержимым панели, и смена слайда его меняет.

В `Sources/BufferJournal/JournalPanelController.swift` заменить:

```swift
import AppKit
import QuartzCore
import SwiftUI
```

на:

```swift
import AppKit
import Combine
import QuartzCore
import SwiftUI
```

В `Sources/BufferJournal/JournalPanelController.swift` заменить:

```swift
    private let settings: AppSettings
    private let access: AccessGate
    private let keys: JournalKeys
    private var panel: NSPanel?
```

на:

```swift
    private let settings: AppSettings
    private let access: AccessGate
    private let onboarding: OnboardingController
    private let keys: JournalKeys
    private var panel: NSPanel?
    private var onboardingObserver: AnyCancellable?
```

В `Sources/BufferJournal/JournalPanelController.swift` заменить:

```swift
    init(store: ClipboardHistoryStore, writer: ClipboardWriter, settings: AppSettings, hotKeys: HotKeyController, access: AccessGate) {
        self.store = store
        self.writer = writer
        self.settings = settings
        self.access = access
        keys = JournalKeys(hotKeys: hotKeys)
```

на:

```swift
    init(store: ClipboardHistoryStore, writer: ClipboardWriter, settings: AppSettings, hotKeys: HotKeyController, access: AccessGate, onboarding: OnboardingController) {
        self.store = store
        self.writer = writer
        self.settings = settings
        self.access = access
        self.onboarding = onboarding
        keys = JournalKeys(hotKeys: hotKeys)

        // Which slide is on screen decides the keys, and the access slide takes none.
        // `objectWillChange` fires before the change, so the mode is read a turn of the run loop later.
        onboardingObserver = onboarding.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in
                self?.updateKeys()
            }
        }
```

В `Sources/BufferJournal/JournalPanelController.swift` заменить:

```swift
    func show() {
        let panel = makePanelIfNeeded()
        positionIfNeeded(panel)
        access.refresh()
        panel.level = .floating
```

на:

```swift
    /// Opens the tutorial on its first slide, showing the panel if it is hidden.
    func showOnboarding(replay: Bool) {
        onboarding.present(replay: replay)
        // Already on screen: move it to the middle for the stories and take the tutorial's keys.
        if isPanelVisible, let panel, panel.level == .floating {
            positionIfNeeded(panel)
            updateKeys()
        } else {
            show()
        }
    }

    func show() {
        let panel = makePanelIfNeeded()
        access.refresh()
        // Without access there is no journal to show: the panel puts up the access slide alone.
        if !access.isGranted, !onboarding.isPresented {
            onboarding.presentAccessOnly()
        }
        // A tutorial left open while the panel was hidden starts its scene over.
        onboarding.restartScene()
        positionIfNeeded(panel)
        panel.level = .floating
```

В `Sources/BufferJournal/JournalPanelController.swift` заменить:

```swift
    private func updateKeys() {
        keys.isListening = JournalKeys.shouldListen(
            intercepts: settings.interceptKeys,
            panelVisible: isPanelVisible,
            journalShown: access.isGranted,
            stashActive: NSApp.isActive,
            menuOpen: !trackingMenus.isEmpty
        )
    }
```

на:

```swift
    private func updateKeys() {
        keys.mode = JournalKeys.mode(
            intercepts: settings.interceptKeys,
            panelVisible: isPanelVisible,
            content: panelContent,
            stashActive: NSApp.isActive,
            menuOpen: !trackingMenus.isEmpty
        )
    }

    /// What the panel shows right now. The access slide counts the same in both of its looks —
    /// last in the tutorial and on its own — because both send the user to System Settings.
    private var panelContent: JournalKeys.PanelContent {
        guard onboarding.isPresented else {
            return access.isGranted ? .journal : .access
        }
        return onboarding.slide.kind == .access ? .access : .onboarding
    }
```

В `Sources/BufferJournal/JournalPanelController.swift` заменить:

```swift
    private func openAccessSettings() {
        access.request()
        panel?.level = .normal
    }
```

на:

```swift
    private func openAccessSettings() {
        onboarding.requestAccess()
        panel?.level = .normal
    }
```

В `Sources/BufferJournal/JournalPanelController.swift` заменить:

```swift
        let contentView = JournalView(
            store: store,
            settings: settings,
            access: access,
            keyEvents: keys.events,
```

на:

```swift
        let contentView = JournalView(
            store: store,
            settings: settings,
            access: access,
            onboarding: onboarding,
            keyEvents: keys.events,
```

В `Sources/BufferJournal/JournalPanelController.swift` заменить:

```swift
    private func positionIfNeeded(_ panel: NSPanel) {
        // Next to the text cursor, like Win+V. The panel is read before it is ordered in, while
        // the app the user types in still holds the focus.
        if settings.openAtCaret, let anchor = CaretLocator.anchor()?.rect {
```

на:

```swift
    private func positionIfNeeded(_ panel: NSPanel) {
        // The stories open in the middle of the screen: nobody is typing while they play, so
        // "Open at the Cursor" does not apply to them.
        if onboarding.isPresented {
            center(panel)
            return
        }

        // Next to the text cursor, like Win+V. The panel is read before it is ordered in, while
        // the app the user types in still holds the focus.
        if settings.openAtCaret, let anchor = CaretLocator.anchor()?.rect {
```

В `Sources/BufferJournal/JournalPanelController.swift` заменить:

```swift
        guard let screen = NSScreen.main else {
            panel.center()
            return
        }

        let frame = screen.visibleFrame
        let panelSize = panel.frame.size
        let x = frame.midX - panelSize.width / 2
        let y = frame.midY - panelSize.height / 2 + 40
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
```

на:

```swift
        center(panel)
    }

    /// The middle of the screen, a touch above centre.
    private func center(_ panel: NSPanel) {
        guard let screen = NSScreen.main else {
            panel.center()
            return
        }

        let frame = screen.visibleFrame
        let panelSize = panel.frame.size
        let x = frame.midX - panelSize.width / 2
        let y = frame.midY - panelSize.height / 2 + 40
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
```

- [ ] **Step 7: Приложение и меню**

Пункт «Обучение» — сразу под «Открыть Stash»: оба открывают панель, а «Очистить историю» очищает без подтверждения, и промах стоил бы истории.

В `Sources/BufferJournal/AppDelegate.swift` заменить:

```swift
    private var access: AccessGate!
    private var panelController: JournalPanelController!
```

на:

```swift
    private var access: AccessGate!
    private var onboarding: OnboardingController!
    private var panelController: JournalPanelController!
```

В `Sources/BufferJournal/AppDelegate.swift` заменить:

```swift
        access = AccessGate()
        hotKeyController = HotKeyController()
        hotKeyController.install()
        panelController = JournalPanelController(
            store: store,
            writer: writer,
            settings: settings,
            hotKeys: hotKeyController,
            access: access
        )
```

на:

```swift
        access = AccessGate()
        onboarding = OnboardingController(defaults: .standard, access: access)
        hotKeyController = HotKeyController()
        hotKeyController.install()
        panelController = JournalPanelController(
            store: store,
            writer: writer,
            settings: settings,
            hotKeys: hotKeyController,
            access: access,
            onboarding: onboarding
        )
```

В `Sources/BufferJournal/AppDelegate.swift` заменить:

```swift
        configureStatusItem()
        monitor.start()

        // Pasting needs Accessibility access; without it the panel opens right away on the access screen.
        if !access.isGranted {
            panelController.show()
        }
    }
```

на:

```swift
        configureStatusItem()
        monitor.start()

        // The tour runs once, on the first launch after the update, and its last slide asks for
        // access. Later on, pasting still needs that access, and without it the panel opens right
        // away on the access slide alone.
        if onboarding.shouldShowOnLaunch {
            panelController.showOnboarding(replay: false)
        } else if !access.isGranted {
            panelController.show()
        }
    }
```

В `Sources/BufferJournal/AppDelegate.swift` заменить:

```swift
        let l10n = settings.l10n
        let menu = NSMenu()
        menu.addItem(menuItem(l10n("Open Stash", "Открыть Stash"), action: #selector(openJournal)))
        menu.addItem(NSMenuItem.separator())

        closeAfterSelectionItem = menuItem(l10n("Close After Selection", "Закрывать после выбора"), action: #selector(toggleCloseAfterSelection))
        menu.addItem(closeAfterSelectionItem)

        interceptKeysItem = menuItem(l10n("Intercept Keys", "Перехватывать клавиши"), action: #selector(toggleInterceptKeys))
        menu.addItem(interceptKeysItem)

        openAtCaretItem = menuItem(l10n("Open at the Cursor", "Открывать у курсора"), action: #selector(toggleOpenAtCaret))
        menu.addItem(openAtCaretItem)

        let themeItem = NSMenuItem(title: l10n("Theme", "Тема"), action: nil, keyEquivalent: "")
```

на:

```swift
        let l10n = settings.l10n
        let titles = StatusMenuTitles(l10n: l10n)
        let menu = NSMenu()
        menu.addItem(menuItem(titles.openStash, action: #selector(openJournal)))
        // Next to "Open Stash": both open the panel. Away from "Clear History", which asks nothing.
        menu.addItem(menuItem(titles.tutorial, action: #selector(openTutorial)))
        menu.addItem(NSMenuItem.separator())

        closeAfterSelectionItem = menuItem(titles.closeAfterSelection, action: #selector(toggleCloseAfterSelection))
        menu.addItem(closeAfterSelectionItem)

        interceptKeysItem = menuItem(titles.interceptKeys, action: #selector(toggleInterceptKeys))
        menu.addItem(interceptKeysItem)

        openAtCaretItem = menuItem(titles.openAtCaret, action: #selector(toggleOpenAtCaret))
        menu.addItem(openAtCaretItem)

        let themeItem = NSMenuItem(title: titles.theme, action: nil, keyEquivalent: "")
```

В `Sources/BufferJournal/AppDelegate.swift` заменить:

```swift
        let languageItem = NSMenuItem(title: l10n("Language", "Язык"), action: nil, keyEquivalent: "")
```

на:

```swift
        let languageItem = NSMenuItem(title: titles.language, action: nil, keyEquivalent: "")
```

В `Sources/BufferJournal/AppDelegate.swift` заменить:

```swift
        menu.addItem(menuItem(l10n("Clear History", "Очистить историю"), action: #selector(clearHistory)))
        menu.addItem(menuItem(l10n("Quit", "Выйти"), action: #selector(quit), keyEquivalent: "q"))
```

на:

```swift
        menu.addItem(menuItem(titles.clearHistory, action: #selector(clearHistory)))
        menu.addItem(menuItem(titles.quit, action: #selector(quit), keyEquivalent: "q"))
```

В `Sources/BufferJournal/AppDelegate.swift` заменить:

```swift
    @objc private func openJournal() {
        panelController.show()
    }
```

на:

```swift
    @objc private func openJournal() {
        panelController.show()
    }

    @objc private func openTutorial() {
        panelController.showOnboarding(replay: true)
    }
```

- [ ] **Step 8: README**

В `README.md` заменить:

```markdown
- Menu settings open the journal at the cursor (`Open at the Cursor`, on by default), close it after a paste or copy, take or leave the journal's keys (`Intercept Keys`, on by default), and switch theme and interface language (System, English, Русский).
```

на:

```markdown
- Menu settings open the journal at the cursor (`Open at the Cursor`, on by default), close it after a paste or copy, take or leave the journal's keys (`Intercept Keys`, on by default), and switch theme and interface language (System, English, Русский).
- A short tour opens inside the panel on the first launch and walks through the journal in eight slides; → and Return go on, ← goes back, Esc closes it. `Tutorial` in the menu bar menu plays it again. The default theme is Stash Auto.
```

В `README.md` заменить:

```markdown
Stash needs Accessibility access to paste (System Settings → Privacy & Security → Accessibility); until it has it, the journal shows an access screen with a button that opens those settings. The app is signed ad hoc, so macOS treats every update as a new app: if the access screen stays although Stash is switched on, remove Stash from the list with − and click Open Settings again.
```

на:

```markdown
Stash needs Accessibility access to paste (System Settings → Privacy & Security → Accessibility); until it has it, the panel shows the tour's access slide on its own, with a button that opens those settings. The app is signed ad hoc, so macOS treats every update as a new app: if that slide stays although Stash is switched on, remove Stash from the list with − and click Open Settings again.
```

- [ ] **Step 9: Сборка и тесты**

Run: `swift build && swift test`
Expected: `Build complete!`, все тесты PASS, в том числе `JournalKeysTests` и `JournalKeyActionTests`.

- [ ] **Step 10: Проверить в приложении**

Проверка вручную: Закрыть установленный Stash. `Scripts/build_app.sh`, затем `defaults delete local.buffer-journal OnboardingSeenVersion` и `open .build/Stash.app`. Панель открывается сама по центру экрана, на ней обучение: «ПРИВЕТ, ЭТО», полосы, пустые карточки. → и Return листают вперёд, ← назад, клик по левой трети назад, по остальному вперёд; буквы при этом идут в приложение под панелью. Esc закрывает обучение, под ним журнал; второй Esc закрывает панель. Перезапуск — обучение само не открывается. В меню значка «Обучение» под «Открыть Stash» — открывает с первого слайда и ставит панель по центру, даже с включённой настройкой «Открывать у курсора». ⌥V посреди обучения прячет панель; следующий ⌥V — тот же слайд, сцена с начала. На последнем слайде «ДОСТУП» (если доступа нет) ←, →, Return и Esc не работают, листается мышью. Без разрешения и с уже увиденным обучением ⌥V открывает одиночный слайд «ДОСТУП»: полос нет, внизу «Открыть настройки», крестик закрывает панель.

- [ ] **Step 11: Коммит**

```bash
git add Sources/BufferJournal Tests/BufferJournalTests README.md
git commit -m "Show the tutorial on first launch and from the menu" -m "The tutorial lies over the journal and takes ←, →, Return and Esc while it is open;
the access slide takes none. The separate access screen is gone: without access the
panel shows that slide alone. A Tutorial item under Open Stash plays the tour again
without marking anything."
```

---

### Task 11: Набор для сцен: указатель, клавиши, окна, демо-клипы, панель превью

**Files:**
- Create: `Sources/BufferJournal/Onboarding/Scenes/SceneKit.swift`
- Create: `Sources/BufferJournal/Onboarding/Scenes/DemoClips.swift`
- Create: `Sources/BufferJournal/Onboarding/Scenes/DemoDetailPane.swift`
- Test: `Tests/BufferJournalTests/DemoClipsTests.swift`; Modify: `Tests/BufferJournalTests/SnapshotTests.swift` — снимки всех сцен

**Interfaces:**
- Consumes: `EntryRow`, `EntryThumb`, `GlassIconButton`, `TranslucentButtonStyle`, `ThemePalette` (Tasks 2–3), `ClipLabels` (Task 1), `CursorState`, `ClickRipple`, `SceneTime` (Task 7), `Localized` (Task 5).
- Produces: `ThemePalette.scene(_ colorScheme:)`, `listSurface`, `detailSurface`; `SceneCursor(state:)`, `SceneRipple(ripple:)`, `SceneKeycap(label:secondary:caption:size:pressed:)`, `SceneWindow(title:palette:content:)`, `TrafficLights()`, `SceneTextLine(width:palette:)`, `SceneCaret(height:visible:)` и `SceneCaret.isVisible(at:duration:)`, `PhotoArt(style: .mountains | .sunset)`.
- Produces: `DemoClip { id, entry, thumbnail, fileIcon, pixelSize; pinned(_:) }`, `DemoClips.text(_:_:_:at:_:)`, `DemoClips.image(_:_:pixelSize:at:_:)`, `DemoClips.file(_:_:bytes:_:at:_:)`, `DemoImages.thumbnail(_:)`, `DemoImages.pdfIcon`, `DemoRow(clip:isSelected:isHovered:palette:)`, `AnyTransition.journalRow`, `DemoDetailPane(clip:photo:palette:)`.

- [ ] **Step 1: Детали сцен**

Указатель — системная стрелка `NSCursor.arrow`, её кончик ставится в точку сцены. Клавиши, окна, строка текста, точка вставки системного цвета, векторные «фотографии» для демо-клипов — всё, чего нет в журнале, рисуется здесь.

Создать `Sources/BufferJournal/Onboarding/Scenes/SceneKit.swift`:

```swift
import AppKit
import SwiftUI

extension ThemePalette {
    /// The Stash look every scene uses, whatever theme the person picked.
    static func scene(_ colorScheme: ColorScheme) -> ThemePalette {
        ThemePalette(colorScheme: colorScheme, solid: true)
    }

    /// Opaque copy of the list pane: the window background under the pane's tint.
    var listSurface: some View {
        ZStack {
            windowBackground
            sidebarTint
        }
    }

    /// Opaque copy of the preview pane.
    var detailSurface: some View {
        ZStack {
            windowBackground
            detailTint
        }
    }
}

/// The system arrow with its tip at `state.tip`, squeezed by clicks.
struct SceneCursor: View {
    let state: CursorState

    var body: some View {
        let cursor = NSCursor.arrow
        let size = cursor.image.size
        Image(nsImage: cursor.image)
            .scaleEffect(1 - 0.12 * state.press, anchor: UnitPoint(x: cursor.hotSpot.x / size.width, y: cursor.hotSpot.y / size.height))
            .offset(x: state.tip.x - cursor.hotSpot.x, y: state.tip.y - cursor.hotSpot.y)
            .opacity(state.opacity)
    }
}

/// The orange wave a click sends out.
struct SceneRipple: View {
    let ripple: ClickRipple?

    var body: some View {
        if let ripple {
            Circle()
                .fill(ThemePalette.orange)
                .frame(width: 28, height: 28)
                .scaleEffect(0.5 + 1.4 * ripple.progress)
                .opacity(0.45 * (1 - ripple.progress))
                .position(ripple.center)
        }
    }
}

/// A Mac key: light with a dark lower edge in the light theme, dark grey in the dark one.
/// Pressed, it sinks by 2 pt and the edge disappears.
struct SceneKeycap: View {
    let label: String
    /// A second letter in the lower right corner, as on a Russian keyboard.
    var secondary: String?
    /// A small word under the symbol, like "option".
    var caption: String?
    var size: CGFloat = 64
    let pressed: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let isDark = colorScheme == .dark
        let shape = RoundedRectangle(cornerRadius: size * 0.19, style: .continuous)
        ZStack {
            shape
                .fill(isDark ? Color.black.opacity(0.6) : Color.black.opacity(0.2))
                .offset(y: pressed ? 0 : 3)
            shape
                .fill(isDark ? Color(white: 0.29) : Color.white)
                .overlay(labels(isDark: isDark))
                .offset(y: pressed ? 2 : 0)
        }
        .frame(width: size, height: size)
        .shadow(color: Color.black.opacity(pressed ? 0.08 : 0.16), radius: pressed ? 3 : 8, y: pressed ? 1 : 5)
        .animation(.easeOut(duration: 0.08), value: pressed)
    }

    private func labels(isDark: Bool) -> some View {
        let ink = isDark ? Color.white.opacity(0.9) : Color.black.opacity(0.82)
        return ZStack {
            VStack(spacing: size * 0.02) {
                Text(label)
                    .font(.system(size: size * 0.36, weight: .medium))
                if let caption {
                    Text(caption)
                        .font(.system(size: size * 0.14, weight: .medium))
                        .opacity(0.6)
                }
            }
            if let secondary {
                Text(secondary)
                    .font(.system(size: size * 0.2, weight: .medium))
                    .opacity(0.55)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(size * 0.12)
            }
        }
        .foregroundStyle(ink)
    }
}

/// A macOS window around scene content: traffic lights and a title.
struct SceneWindow<Content: View>: View {
    let title: String
    let palette: ThemePalette
    @ViewBuilder let content: () -> Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        VStack(spacing: 0) {
            ZStack {
                HStack(spacing: 6) {
                    TrafficLights()
                    Spacer(minLength: 0)
                }
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .frame(height: 24)

            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(palette.modalBackground)
        .clipShape(shape)
        .overlay(shape.strokeBorder(palette.border, lineWidth: 1))
        .shadow(color: palette.shadow(0.18), radius: 16, y: 8)
    }
}

/// Close, minimise and zoom, in their system colours.
struct TrafficLights: View {
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(Color(red: 1, green: 0.373, blue: 0.341))
            Circle().fill(Color(red: 0.996, green: 0.737, blue: 0.180))
            Circle().fill(Color(red: 0.157, green: 0.784, blue: 0.251))
        }
        .frame(width: 42, height: 10)
    }
}

/// A grey bar standing in for a line of text in someone else's window.
struct SceneTextLine: View {
    let width: CGFloat
    let palette: ThemePalette

    var body: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(palette.textTertiary.opacity(0.45))
            .frame(width: width, height: 6)
    }
}

/// The text insertion point, in the system's own colour.
struct SceneCaret: View {
    var height: CGFloat = 14
    var visible = true

    var body: some View {
        Rectangle()
            .fill(Self.color)
            .frame(width: 1.5, height: height)
            .opacity(visible ? 1 : 0)
    }

    static var color: Color {
        if #available(macOS 14.0, *) {
            return Color(nsColor: .textInsertionPointColor)
        }
        return Color(nsColor: .controlAccentColor)
    }

    /// Blinks twice a second, and is always on in a stop frame.
    static func isVisible(at time: SceneTime, duration: Double) -> Bool {
        time.t >= duration || time.t.truncatingRemainder(dividingBy: 1) < 0.6
    }
}

/// A made-up photo for demo clips: sky, sun and hills, drawn so no image files ship.
struct PhotoArt: View {
    enum Style {
        case mountains
        case sunset
    }

    let style: Style

    var body: some View {
        Canvas { context, size in
            let colors = palette
            let rect = CGRect(origin: .zero, size: size)
            context.fill(
                Path(rect),
                with: .linearGradient(Gradient(colors: [colors.skyTop, colors.skyBottom]), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height))
            )
            let sun = size.height * 0.24
            context.fill(Path(ellipseIn: CGRect(x: size.width * 0.66, y: size.height * 0.14, width: sun, height: sun)), with: .color(colors.sun))
            context.fill(hills(size, peaks: [0.18, 0.46, 0.72, 0.95], heights: [0.40, 0.26, 0.44, 0.32], base: 0.72), with: .color(colors.far))
            context.fill(hills(size, peaks: [0.1, 0.38, 0.64, 0.9], heights: [0.62, 0.56, 0.66, 0.58], base: 1), with: .color(colors.near))
        }
    }

    private var palette: (skyTop: Color, skyBottom: Color, sun: Color, far: Color, near: Color) {
        switch style {
        case .mountains:
            (Color(red: 0.49, green: 0.77, blue: 1), Color(red: 0.87, green: 0.94, blue: 1), Color(red: 1, green: 0.82, blue: 0.40),
             Color(red: 0.56, green: 0.75, blue: 0.50), Color(red: 0.30, green: 0.50, blue: 0.27))
        case .sunset:
            (Color(red: 1, green: 0.70, blue: 0.48), Color(red: 1, green: 0.88, blue: 0.76), Color(red: 1, green: 0.95, blue: 0.79),
             Color(red: 0.71, green: 0.54, blue: 0.82), Color(red: 0.42, green: 0.31, blue: 0.61))
        }
    }

    /// A ridge through the given peaks (x, y as shares of the size), closed along the bottom.
    private func hills(_ size: CGSize, peaks: [CGFloat], heights: [CGFloat], base: CGFloat) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: size.height))
        path.addLine(to: CGPoint(x: 0, y: size.height * base))
        for (x, y) in zip(peaks, heights) {
            path.addLine(to: CGPoint(x: size.width * x, y: size.height * y))
        }
        path.addLine(to: CGPoint(x: size.width, y: size.height * base))
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.closeSubpath()
        return path
    }
}
```

- [ ] **Step 2: Демо-клипы**

Демо-клип — настоящая `ClipboardEntry` и то, что для неё дал бы журнал: миниатюра, значок файла, размер в пикселях. Строка сцены — настоящий `EntryRow` с подписями из `ClipLabels`. Личность клипа одна и та же из кадра в кадр, иначе строки теряли бы состояние. Поиска в журнале нет, поэтому у клипа нет и правила совпадения: `ClipLabels` умеет только подписи.

Создать `Sources/BufferJournal/Onboarding/Scenes/DemoClips.swift`:

```swift
import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// A made-up clip for the scenes: an entry plus what the store would give for it.
struct DemoClip: Identifiable {
    let id: String
    var entry: ClipboardEntry
    var thumbnail: NSImage?
    var fileIcon: NSImage?
    var pixelSize: CGSize?

    func pinned(_ isPinned: Bool = true) -> DemoClip {
        var copy = self
        copy.entry.isPinned = isPinned
        return copy
    }
}

/// Builds demo clips. They never reach the history or the disk.
@MainActor
enum DemoClips {
    static func text(_ id: String, _ text: Localized, _ l10n: L10n, at hour: Int, _ minute: Int) -> DemoClip {
        DemoClip(id: id, entry: entry(id, .text(text(l10n)), hour, minute))
    }

    static func image(_ id: String, _ style: PhotoArt.Style, pixelSize: CGSize, at hour: Int, _ minute: Int) -> DemoClip {
        DemoClip(id: id, entry: entry(id, .image(filename: "\(id).png"), hour, minute), thumbnail: DemoImages.thumbnail(style), pixelSize: pixelSize)
    }

    static func file(_ id: String, _ name: Localized, bytes: Int64, _ l10n: L10n, at hour: Int, _ minute: Int) -> DemoClip {
        let payload = ClipboardPayload.file(storedFilename: id, originalName: name(l10n), byteCount: bytes)
        return DemoClip(id: id, entry: entry(id, payload, hour, minute), fileIcon: DemoImages.pdfIcon)
    }

    private static func entry(_ id: String, _ payload: ClipboardPayload, _ hour: Int, _ minute: Int) -> ClipboardEntry {
        let date = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
        return ClipboardEntry(id: uuid(id), payload: payload, createdAt: date, fingerprint: id)
    }

    /// The same identity for the same demo clip, frame after frame.
    private static func uuid(_ id: String) -> UUID {
        let bits = UInt64(UInt(bitPattern: id.hashValue)) & 0xFFFF_FFFF_FFFF
        return UUID(uuidString: String(format: "00000000-0000-4000-8000-%012llx", bits)) ?? UUID()
    }
}

/// Pictures for demo clips, drawn once.
@MainActor
enum DemoImages {
    static let pdfIcon = NSWorkspace.shared.icon(for: .pdf)
    private static var thumbnails: [PhotoArt.Style: NSImage] = [:]

    static func thumbnail(_ style: PhotoArt.Style) -> NSImage {
        if let image = thumbnails[style] {
            return image
        }
        let size = style == .mountains ? CGSize(width: 160, height: 100) : CGSize(width: 90, height: 120)
        let renderer = ImageRenderer(content: PhotoArt(style: style).frame(width: size.width, height: size.height))
        renderer.scale = 2
        let image = renderer.nsImage ?? NSImage(size: size)
        thumbnails[style] = image
        return image
    }
}

/// A journal row for a demo clip, titled exactly as the journal titles it.
struct DemoRow: View {
    let clip: DemoClip
    var isSelected = false
    var isHovered = false
    let palette: ThemePalette

    @Environment(\.l10n) private var l10n

    var body: some View {
        EntryRow(
            entry: clip.entry,
            thumbnail: clip.thumbnail,
            fileIcon: clip.fileIcon,
            title: ClipLabels.rowTitle(clip.entry, l10n),
            subtitle: ClipLabels.rowSubtitle(clip.entry, pixelSize: clip.pixelSize, l10n),
            isSelected: isSelected,
            isCurrent: false,
            palette: palette,
            onQuickPaste: {},
            onExpand: clip.entry.isText ? nil : {},
            onTogglePin: {},
            onDelete: {},
            hoverOverride: isHovered
        )
    }
}

/// How the journal inserts and removes rows (JournalView's list).
extension AnyTransition {
    static var journalRow: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .offset(y: -10)),
            removal: .opacity.combined(with: .scale(scale: 0.96))
        )
    }
}
```

- [ ] **Step 3: Панель превью**

Собрана из тех же частей, что `JournalView.detail`: вид клипа и время, клип, кнопки и оранжевая «Вставить».

Создать `Sources/BufferJournal/Onboarding/Scenes/DemoDetailPane.swift`:

```swift
import SwiftUI

/// The journal's preview pane for a demo clip: kind and time on top, the clip itself, and the
/// action bar with the orange "Paste" button. Built from the same parts as JournalView's `detail`.
struct DemoDetailPane: View {
    let clip: DemoClip
    /// The photo drawn large for image clips.
    var photo: PhotoArt.Style = .mountains
    let palette: ThemePalette

    @Environment(\.l10n) private var l10n

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text(ClipLabels.kindTitle(clip.entry, l10n))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)
                Text("· \(ClipLabels.timeTitle(clip.entry.createdAt, l10n))")
                    .font(.system(size: 11))
                    .foregroundStyle(palette.textTertiary)
                Spacer(minLength: 0)
                GlassIconButton(systemName: "xmark", help: l10n("Close", "Закрыть"), action: {})
            }
            .padding(.leading, 16)
            .padding(.trailing, 10)
            .padding(.top, 10)
            .padding(.bottom, 4)

            stage
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: 6) {
                if clip.entry.isImage {
                    GlassIconButton(systemName: "arrow.up.left.and.arrow.down.right", help: "", action: {})
                } else {
                    GlassIconButton(systemName: "pencil", help: "", action: {})
                }
                GlassIconButton(systemName: clip.entry.isPinned ? "pin.fill" : "pin", help: "", action: {})
                GlassIconButton(systemName: "trash", isDestructive: true, help: "", action: {})
                Spacer(minLength: 0)
                Button(action: {}) {
                    HStack(spacing: 6) {
                        Text(l10n("Paste", "Вставить"))
                        Image(systemName: "return")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 12)
                    .frame(height: 28)
                }
                .buttonStyle(TranslucentButtonStyle(tone: .accent, cornerRadius: 8))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .overlay(alignment: .top) {
                palette.separator.frame(height: 1)
            }
        }
    }

    @ViewBuilder
    private var stage: some View {
        switch clip.entry.payload {
        case let .text(text):
            Text(text)
                .font(.system(size: 13))
                .lineSpacing(3)
                .foregroundStyle(palette.textPrimary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        case .image:
            PhotoArt(style: photo)
                .aspectRatio(clip.pixelSize.map { $0.width / $0.height } ?? 1.6, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .shadow(color: palette.shadow(0.18), radius: 10, y: 4)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        case .file:
            Image(nsImage: clip.fileIcon ?? DemoImages.pdfIcon)
                .resizable()
                .frame(width: 72, height: 72)
        }
    }
}
```

- [ ] **Step 4: Тест демо-клипов**

Создать `Tests/BufferJournalTests/DemoClipsTests.swift`:

```swift
import CoreGraphics
import Testing
@testable import BufferJournal

@MainActor
struct DemoClipsTests {
    @Test func aDemoClipKeepsItsIdentityFromFrameToFrame() {
        let l10n = L10n(language: .russian)
        let first = DemoClips.text("same", Localized(en: "a", ru: "а"), l10n, at: 9, 0)
        let second = DemoClips.text("same", Localized(en: "a", ru: "а"), l10n, at: 9, 0)
        #expect(first.entry.id == second.entry.id)
    }

    @Test func demoImagesAreLabelledLikeTheJournal() {
        let l10n = L10n(language: .russian)
        let clip = DemoClips.image("photo", .mountains, pixelSize: CGSize(width: 1600, height: 1000), at: 14, 2)
        #expect(ClipLabels.rowTitle(clip.entry, l10n) == "Изображение")
        #expect(ClipLabels.rowSubtitle(clip.entry, pixelSize: clip.pixelSize, l10n).hasPrefix("1600×1000 · "))
        #expect(clip.thumbnail != nil)
    }
}
```

- [ ] **Step 5: Снимки всех сцен**

Дописать в конец `Tests/BufferJournalTests/SnapshotTests.swift`. Тест рисует стоп-кадр и середину каждой сцены в обеих темах и на обоих языках; пока сцен нет, картинки пустые.

Дописать в конец `Tests/BufferJournalTests/SnapshotTests.swift`:

```swift

extension SnapshotTests {
    /// Every scene's stop frame and its middle, on the card's surface, in both themes and languages.
    @Test func sceneFrames() throws {
        for (scheme, schemeName) in Self.schemes {
            for (language, languageName) in [(ResolvedLanguage.russian, "ru"), (.english, "en")] {
                for slide in OnboardingSlides.all {
                    let area = OnboardingSceneView.size(of: slide.kind) ?? CGSize(width: 600, height: 309)
                    let palette = ThemePalette.scene(scheme)
                    for (time, timeName) in [(SceneTime.end(of: slide.duration), "end"), (SceneTime(t: slide.duration * 0.4, rewind: 0), "mid")] {
                        let view = OnboardingSceneView.canvas(for: slide.kind, at: time, in: area)
                            .background(slide.kind == .hero ? AnyView(OnboardingColors(isDark: scheme == .dark).field) : AnyView(palette.listSurface))
                            .environment(\.colorScheme, scheme)
                            .environment(\.l10n, L10n(language: language))
                            .environment(\.solidAccents, true)
                        try render(view, name: "scene-\(slide.kind.rawValue)-\(timeName)-\(languageName)-\(schemeName)")
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 6: Сборка и тесты**

Run: `swift build && swift test`
Expected: `Build complete!`, все тесты PASS.

- [ ] **Step 7: Коммит**

```bash
git add Sources/BufferJournal/Onboarding/Scenes Tests/BufferJournalTests/DemoClipsTests.swift Tests/BufferJournalTests/SnapshotTests.swift
git commit -m "Scene kit: cursor, keys, windows, demo clips and the preview pane"
```

---

### Task 12: Сцена «ПРИВЕТ»

**Files:**
- Create: `Sources/BufferJournal/Onboarding/Scenes/HeroScene.swift`
- Modify: `Sources/BufferJournal/Onboarding/OnboardingSceneView.swift` — `case .hero`
- Test: `Tests/BufferJournalTests/Scenes/HeroSceneTests.swift`

**Interfaces:**
- Consumes: набор для сцен (Task 11), `Track`, `CursorTrack`, `SceneTime` (Task 7), `Localized` (Task 5).
- Produces: `HeroScene(time: area:)`, `HeroScene.duration`, `HeroScene.State`, `HeroScene.state(at: SceneTime) -> State`.

- [ ] **Step 1: Тест стоп-кадра**

Создать `Tests/BufferJournalTests/Scenes/HeroSceneTests.swift`:

```swift
import CoreGraphics
import Testing
@testable import BufferJournal

/// The stop frame from the spec's "Сцены" section and the moments that lead to it.
@MainActor
struct HeroSceneTests {
    @Test func heroEndsAssembledAndStill() {
        let end = HeroScene.state(at: .end(of: HeroScene.duration))
        #expect(end.iconOpacity == 1)
        #expect(end.iconScaleX == 1 && end.iconScaleY == 1)
        #expect(end.flash == 0 && end.shake == 0)
        #expect(end.wordOpacity == 1)
        #expect(end.wordShift == 0)
        #expect(end.tiles.allSatisfy { $0 == nil })
    }

    @Test func tilesFlyThenHitTheIcon() {
        let flying = HeroScene.state(at: SceneTime(t: 0.55, rewind: 0))
        #expect(flying.tiles[0] != nil)
        #expect(flying.wordOpacity == 0)
        // Just after the first hit the icon is squashed: wider and lower.
        let hit = HeroScene.state(at: SceneTime(t: HeroScene.hits[0] + 0.06, rewind: 0))
        #expect(hit.iconScaleX > 1 && hit.iconScaleY < 1)
        // The last hit shakes the lockup.
        let last = HeroScene.state(at: SceneTime(t: HeroScene.hits[2] + 0.1, rewind: 0))
        #expect(last.shake != 0)
        #expect(HeroScene.state(at: SceneTime(t: HeroScene.hits[0] + 0.02, rewind: 0)).flash > 0)
    }

    @Test func eachFlightEndsInTheIcon() {
        let icon = CGPoint(x: 200, y: 150)
        for flight in HeroScene.flights(in: CGSize(width: 600, height: 300), to: icon) {
            #expect(flight.point(at: 1) == icon)
        }
    }
}
```

- [ ] **Step 2: Запустить — падает**

Run: `swift test --filter HeroSceneTests`
Expected: FAIL: ошибка сборки `cannot find 'HeroScene' in scope`.

- [ ] **Step 3: Сцена**

Карточки нет, логотип стоит на поле и ничем не обрезается; над ним в рамке заголовок «ПРИВЕТ, ЭТО» (Task 9), и экран читается «Привет, это Stash». Логотип — связка из шапки журнала (иконка 32 : шрифт 28 : зазор 2), слово выровнено по заглавным, всё вместе — до 80 % ширины или высоты области. Иконка поднимается на 24 pt и проявляется (0,1–0,55 с). Три плитки строк журнала — текст, фото, PDF — в две трети иконки вылетают из трёх углов (0,3, 0,48, 0,66 с) и за 0,45 с по дуге с разгоном падают в иконку сверху: кувыркаются, уменьшаются, тянут шлейф из четырёх бледнеющих копий и уходят за иконку (плитки лежат слоем под логотипом). Удар — белая вспышка по иконке и приплющивание от низа с отскоком; последний в 1,6 раза сильнее и встряхивает логотип, и «Stash» выезжает из-за иконки (1,12–1,66 с). Волн и искр нет. Слой прибит к углу области (`.frame(…, alignment: .topLeading)`): без летящих плиток он иначе сожмётся и съедет к центру. Играет один раз.

Создать `Sources/BufferJournal/Onboarding/Scenes/HeroScene.swift`:

```swift
import AppKit
import SwiftUI

/// ПРИВЕТ, ЭТО: no card; the slide's title above says "Hello, this is". The Stash icon rises. A text,
/// a photo and a PDF, as journal row tiles, swoop
/// in on arcs, tumbling and trailing, and drop into the icon from above: they pass behind it and
/// are gone. Each hit flashes and squashes the icon; the last hits hardest, shakes the lockup and
/// pushes "Stash" out from behind the icon. The lockup is the journal header's (icon 32 : type
/// 28 : gap 2), scaled up.
struct HeroScene: View {
    static let duration = 2.6

    struct State: Equatable {
        var iconOpacity: Double
        var iconRise: Double
        /// Squash and stretch from the hits, 1 when still.
        var iconScaleX: Double
        var iconScaleY: Double
        /// White flash over the icon at a hit, 0…1.
        var flash: Double
        /// Sideways shake of the lockup after the last hit, in points.
        var shake: Double
        /// 0…1 along each tile's flight; nil before it sets off and after it is in.
        var tiles: [Double?]
        var wordOpacity: Double
        var wordShift: Double
    }

    static let departures = [0.3, 0.48, 0.66]
    static let flight = 0.45
    static let hits = departures.map { $0 + flight }

    private static let iconOpacity = Track(0.0).to(1, at: 0.1, until: 0.45, .easeOut)
    private static let iconRise = Track(24.0).to(0, at: 0.1, until: 0.55, .easeOut)
    private static let wordOpacity = Track(0.0).to(1, at: 1.14, until: 1.32, .easeOut)
    /// Out from behind the icon with a little overshoot.
    private static let wordShift = Track(-56.0).to(6, at: 1.12, until: 1.44, .easeOut).to(0, at: 1.44, until: 1.66, .easeInOut)

    static func state(at time: SceneTime) -> State {
        let t = time.t
        let squash = impact(at: t)
        let last = hits[hits.count - 1]
        return State(
            iconOpacity: iconOpacity.value(at: time),
            iconRise: iconRise.value(at: time),
            iconScaleX: 1 + 0.08 * squash,
            iconScaleY: 1 - 0.12 * squash,
            flash: hits.map { hit in t >= hit && t < hit + 0.2 ? 0.55 * (1 - (t - hit) / 0.2) : 0 }.max() ?? 0,
            shake: t >= last && t < last + 0.3 ? 5 * sin((t - last) * 60) * (1 - (t - last) / 0.3) : 0,
            tiles: departures.map { start in t >= start && t < start + flight ? (t - start) / flight : nil },
            wordOpacity: wordOpacity.value(at: time),
            wordShift: wordShift.value(at: time)
        )
    }

    /// Positive squashes (wider, lower), negative stretches. Each hit squashes, then springs back
    /// past still; the last is 1.6 times as hard.
    private static func impact(at t: Double) -> Double {
        for (index, hit) in hits.enumerated().reversed() {
            let since = t - hit
            guard since >= 0, since < 0.3 else { continue }
            let strength = index == hits.count - 1 ? 1.6 : 1
            if since < 0.12 {
                return strength * sin(.pi * since / 0.12)
            }
            return -0.45 * strength * sin(.pi * (since - 0.12) / 0.18)
        }
        return 0
    }

    let time: SceneTime
    let area: CGSize

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.l10n) private var l10n

    var body: some View {
        let state = Self.state(at: time)
        let palette = ThemePalette.scene(colorScheme)
        let colors = OnboardingColors(isDark: colorScheme == .dark)
        let lockup = OnboardingLayout.heroLockup(in: area, wordWidthAt28: HeavyTextMetrics.width("Stash", size: 28))
        let wordWidth = HeavyTextMetrics.width("Stash", size: lockup.fontSize)
        let capHeight = HeavyTextMetrics.capHeight(size: lockup.fontSize)
        let left = (area.width - (lockup.icon + lockup.gap + wordWidth)) / 2
        let top = (area.height - lockup.icon) / 2
        let icon = CGPoint(x: left + lockup.icon / 2, y: top + lockup.icon / 2)
        let tile = lockup.icon * 0.66
        let flights = Self.flights(in: area, to: icon)
        let clips = [
            DemoClips.text("hero-text", Localized(en: "Address", ru: "Адрес"), l10n, at: 14, 20),
            DemoClips.image("hero-photo", .mountains, pixelSize: CGSize(width: 1600, height: 1000), at: 14, 2),
            DemoClips.file("hero-file", Localized(en: "Contract.pdf", ru: "Договор.pdf"), bytes: 1_240_000, l10n, at: 12, 10),
        ]
        let iconImage = Image(nsImage: NSApplication.shared.applicationIconImage)

        ZStack(alignment: .topLeading) {
            // Tiles fly under the lockup, so they vanish into the icon instead of covering it.
            ForEach(Array(clips.enumerated()), id: \.element.id) { index, clip in
                if let progress = state.tiles[index] {
                    // A trail of fading copies behind each tile reads as speed.
                    ForEach(Self.trail, id: \.lag) { ghost in
                        let p = max(progress - ghost.lag, 0)
                        EntryThumb(entry: clip.entry, thumbnail: clip.thumbnail, fileIcon: clip.fileIcon, palette: palette)
                            .scaleEffect(tile / 42 * (1 - 0.62 * SceneCurve.easeIn(p)))
                            .rotationEffect(.degrees(flights[index].spin * (1 - SceneCurve.easeOut(p))))
                            .opacity(ghost.opacity * min(p / 0.1, 1))
                            .position(flights[index].point(at: SceneCurve.easeIn(p)))
                    }
                }
            }

            HStack(spacing: lockup.gap) {
                iconImage
                    .resizable()
                    .interpolation(.high)
                    .frame(width: lockup.icon, height: lockup.icon)
                    .overlay(Color.white.opacity(state.flash).mask(iconImage.resizable()))
                    .scaleEffect(x: state.iconScaleX, y: state.iconScaleY, anchor: .bottom)
                    .offset(y: state.iconRise)
                    .opacity(state.iconOpacity)
                    .zIndex(1)
                Text("Stash")
                    .font(.system(size: lockup.fontSize, weight: .heavy))
                    .foregroundStyle(colors.wordmark)
                    .fixedSize()
                    // Centred on the capitals, as in the journal header.
                    .alignmentGuide(VerticalAlignment.center) { $0[.firstTextBaseline] - capHeight / 2 }
                    .offset(x: state.wordShift)
                    .opacity(state.wordOpacity)
            }
            .frame(height: lockup.icon)
            .offset(x: left + state.shake, y: top)
        }
        // Pinned to the area's corner: the offsets above count from it, flying tiles or not.
        .frame(width: area.width, height: area.height, alignment: .topLeading)
    }

    private struct Ghost {
        let lag: Double
        let opacity: Double
    }

    /// Four fading copies trail each tile; the tile itself goes last, fully opaque.
    private static let trail = [
        Ghost(lag: 0.2, opacity: 0.08), Ghost(lag: 0.15, opacity: 0.15),
        Ghost(lag: 0.1, opacity: 0.25), Ghost(lag: 0.05, opacity: 0.35), Ghost(lag: 0, opacity: 1),
    ]

    /// A curved path into the icon and the turn a tile makes on it.
    struct Flight {
        let start: CGPoint
        let bend: CGPoint
        let end: CGPoint
        /// Degrees the tile is turned when it sets off; it straightens on the way.
        let spin: Double

        /// Quadratic Bézier from `start` through the pull of `bend` to `end`.
        func point(at p: Double) -> CGPoint {
            let u = 1 - p
            return CGPoint(
                x: u * u * start.x + 2 * u * p * bend.x + p * p * end.x,
                y: u * u * start.y + 2 * u * p * bend.y + p * p * end.y
            )
        }
    }

    /// From the upper left, the upper right and the lower left. Every path bends above the icon, so
    /// each tile comes down into it from the top, like into a pocket.
    static func flights(in area: CGSize, to icon: CGPoint) -> [Flight] {
        let w = area.width
        let h = area.height
        return [
            Flight(start: CGPoint(x: w * 0.1, y: h * 0.22), bend: CGPoint(x: icon.x - w * 0.02, y: -h * 0.15), end: icon, spin: -24),
            Flight(start: CGPoint(x: w * 0.9, y: h * 0.18), bend: CGPoint(x: icon.x + w * 0.2, y: -h * 0.2), end: icon, spin: 28),
            Flight(start: CGPoint(x: w * 0.16, y: h * 0.88), bend: CGPoint(x: icon.x - w * 0.25, y: -h * 0.1), end: icon, spin: -18),
        ]
    }
}
```

- [ ] **Step 4: Сцена на своём слайде**

В `Sources/BufferJournal/Onboarding/OnboardingSceneView.swift` заменить:

```swift
        case .hero: Color.clear
```

на:

```swift
        case .hero: HeroScene(time: time, area: area)
```

- [ ] **Step 5: Запустить — проходит**

Run: `swift test --filter HeroSceneTests`
Expected: PASS.

Run: `swift build && swift test`
Expected: `Build complete!`, все тесты PASS.

- [ ] **Step 6: Посмотреть снимки**

Run: `SNAPSHOT_DIR=/tmp/stash-snapshots swift test --filter SnapshotTests`
Expected: PASS.

Проверка вручную: `scene-hero-mid-ru-light.png` — последняя плитка со шлейфом ныряет в иконку. `scene-hero-end-ru-light.png` — иконка и «Stash» оранжевым иконки на светло-сером; `…-dark.png` — на чёрном. `frame-hero-640-light.png` — над логотипом заголовок «ПРИВЕТ, ЭТО». В тестах у процесса нет иконки Stash, поэтому на снимке значок папки; в приложении — иконка Stash.

- [ ] **Step 7: Коммит**

```bash
git add Sources/BufferJournal/Onboarding/Scenes/HeroScene.swift Sources/BufferJournal/Onboarding/OnboardingSceneView.swift Tests/BufferJournalTests/Scenes/HeroSceneTests.swift
git commit -m "Tutorial scene: hello"
```

---

### Task 13: Сцена «ВЫЗОВ»

**Files:**
- Create: `Sources/BufferJournal/Onboarding/Scenes/JournalMiniature.swift`
- Create: `Sources/BufferJournal/Onboarding/Scenes/HotKeyScene.swift`
- Modify: `Sources/BufferJournal/Onboarding/OnboardingSceneView.swift` — `case .hotKey`
- Test: `Tests/BufferJournalTests/Scenes/HotKeySceneTests.swift`

**Interfaces:**
- Consumes: набор для сцен (Task 11), `Track`, `CursorTrack`, `SceneTime` (Task 7), `Localized` (Task 5), `PanelPlacement.gap` (приложение).
- Produces: `HotKeyScene(time:)`, `HotKeyScene.duration`, `HotKeyScene.size`, `HotKeyScene.State`, `HotKeyScene.state(at: SceneTime) -> State`, `HotKeyScene.caret`, `HotKeyScene.journalFrame`.
- Produces: `JournalMiniature(palette:)` — журнал 640 × 440 без стекла.

- [ ] **Step 1: Тест стоп-кадра**

Кроме стоп-кадра тест проверяет место журнала: он стоит под строкой с точкой вставки, с тем же зазором `PanelPlacement.gap`, что и настоящая панель, и целиком помещается на холсте.

Создать `Tests/BufferJournalTests/Scenes/HotKeySceneTests.swift`:

```swift
import CoreGraphics
import Testing
@testable import BufferJournal

/// The stop frame from the spec's "Сцены" section and the moments that lead to it.
@MainActor
struct HotKeySceneTests {
    @Test func hotKeyEndsWithTheJournalUnderTheCaretAndKeysUp() {
        let end = HotKeyScene.state(at: .end(of: HotKeyScene.duration))
        #expect(end.journal == 1)
        #expect(!end.optionDown && !end.vDown)
        let pressed = HotKeyScene.state(at: SceneTime(t: 0.55, rewind: 0))
        #expect(pressed.optionDown && pressed.vDown)
    }

    @Test func theJournalOpensUnderTheCaretWithTheAppsOwnGap() {
        // The scene places the journal the way PanelPlacement does on screen: left edge at the
        // caret, top edge a gap below the line it stands on.
        #expect(HotKeyScene.journalFrame.minX == HotKeyScene.caret.minX)
        #expect(HotKeyScene.journalFrame.minY == HotKeyScene.caret.maxY + PanelPlacement.gap)
        #expect(HotKeyScene.journalFrame.maxX <= HotKeyScene.size.width)
        #expect(HotKeyScene.journalFrame.maxY <= HotKeyScene.size.height)
    }
}
```

- [ ] **Step 2: Запустить — падает**

Run: `swift test --filter HotKeySceneTests`
Expected: FAIL: ошибка сборки `cannot find 'HotKeyScene' in scope`.

- [ ] **Step 3: Сцена**

Слева клавиши ⌥ option и V; в русском интерфейсе на V вторая буква «М», как на русской клавиатуре Mac: сочетание работает по положению клавиши. Справа окно «Документ» со строками и мигающей точкой вставки во второй строке. ⌥ нажимается (0,3 с), следом V (0,5 с); журнал проявляется с увеличением от 0,96 прямо под строкой с точкой вставки, с зазором `PanelPlacement.gap` = 16 pt (0,6–0,9 с); клавиши отпускаются (1,0 с). Журнал закрывает нижнюю часть окна и выходит за его край — так и бывает, когда панель открывается у курсора в высоком окне.

Журнал — `JournalMiniature`: весь журнал 640 × 440 из его же частей (шапка с иконкой и счётчиком, фильтр, строки, панель превью), уменьшенный до 0,3. Поля поиска в журнале больше нет, и на его месте помещается ещё одна строка.

Создать `Sources/BufferJournal/Onboarding/Scenes/JournalMiniature.swift`:

```swift
import AppKit
import SwiftUI

/// The whole journal at its default 640 × 440, built from the journal's own parts, for scenes to
/// shrink. Opaque: there is no glass inside a scene to show through.
struct JournalMiniature: View {
    let palette: ThemePalette

    @Environment(\.l10n) private var l10n

    var body: some View {
        let clips = [
            DemoClips.text("mini-address", Localized(en: "Office address: 12 Main St, entrance 3", ru: "Адрес офиса: Тверская, 12, подъезд 3"), l10n, at: 14, 20),
            DemoClips.image("mini-photo", .mountains, pixelSize: CGSize(width: 1600, height: 1000), at: 14, 2),
            DemoClips.file("mini-contract", Localized(en: "Contract.pdf", ru: "Договор.pdf"), bytes: 1_240_000, l10n, at: 12, 10),
            DemoClips.text("mini-promo", Localized(en: "Promo code AUTUMN25", ru: "Промокод AUTUMN25"), l10n, at: 9, 12),
        ]
        let shape = RoundedRectangle(cornerRadius: JournalView.Layout.cornerRadius, style: .continuous)

        HStack(spacing: 0) {
            VStack(spacing: 0) {
                HStack(spacing: 2) {
                    Image(nsImage: NSApplication.shared.applicationIconImage)
                        .resizable()
                        .frame(width: 32, height: 32)
                    Text("Stash")
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundStyle(palette.textPrimary)
                    Spacer(minLength: 0)
                    Text("\(clips.count)/20")
                        .font(.system(size: 11, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(palette.textTertiary)
                        .padding(.trailing, 6)
                    GlassIconButton(systemName: "trash", isDestructive: true, help: "", action: {})
                }
                .padding(.leading, 14)
                .padding(.trailing, 10)
                .padding(.top, 12)
                .padding(.bottom, 10)

                TypeSegmentedControl(
                    titles: [l10n("All", "Все"), l10n("Text", "Текст"), l10n("Images", "Картинки"), l10n("Files", "Файлы")],
                    selectedIndex: 0,
                    palette: palette,
                    onSelect: { _ in }
                )
                .padding(.horizontal, 10)
                .padding(.bottom, 8)

                VStack(spacing: 0) {
                    SectionHeader(title: l10n("Today", "Сегодня"), palette: palette)
                    ForEach(Array(clips.enumerated()), id: \.element.id) { index, clip in
                        DemoRow(clip: clip, isSelected: index == 0, palette: palette)
                    }
                }
                .padding(.horizontal, 10)
                Spacer(minLength: 0)
            }
            .frame(width: JournalView.Layout.sidebarWidth)
            .background(palette.listSurface)
            .overlay(alignment: .trailing) {
                palette.separator.frame(width: 1)
            }

            DemoDetailPane(clip: clips[0], palette: palette)
                .background(palette.detailSurface)
        }
        .frame(width: JournalView.Layout.width, height: JournalView.Layout.height)
        .clipShape(shape)
        .overlay(shape.strokeBorder(palette.border, lineWidth: 1))
    }
}
```

Создать `Sources/BufferJournal/Onboarding/Scenes/HotKeyScene.swift`:

```swift
import SwiftUI

/// ВЫЗОВ: ⌥ and V go down on a Mac keyboard, and the journal opens right under the line the
/// insertion point stands on, as it does on screen.
struct HotKeyScene: View {
    static let duration = 2.6
    /// Two keys, and another app's window with the journal under its caret.
    static let size = CGSize(width: 470, height: 234)

    struct State: Equatable {
        var optionDown: Bool
        var vDown: Bool
        /// 0…1: the journal appearing under the caret.
        var journal: Double
    }

    private static let option = Track(false).set(true, at: 0.3).set(false, at: 1.0)
    private static let v = Track(false).set(true, at: 0.5).set(false, at: 1.02)
    private static let journal = Track(0.0).to(1, at: 0.6, until: 0.9, .easeOut)

    static func state(at time: SceneTime) -> State {
        State(optionDown: option.value(at: time), vDown: v.value(at: time), journal: journal.value(at: time))
    }

    /// The journal is shown at this share of its real size: what is left under the caret once the
    /// window and the app's own gap have taken their room.
    static let miniatureScale: CGFloat = 0.3

    // MARK: Geometry, in canvas coordinates

    /// The other app's window with the document text.
    static let window = CGRect(x: 142, y: 6, width: 312, height: 150)
    /// SceneWindow draws a 24 pt title bar above its content.
    private static let titleBar: CGFloat = 24
    private static let textInset = CGSize(width: 14, height: 12)
    /// Grey lines of the document; the caret stands at the end of the second one.
    private static let lines: [CGFloat] = [190, 64, 168, 212, 140]
    private static let lineHeight: CGFloat = 6
    private static let lineSpacing: CGFloat = 9
    private static let caretLine = 1
    private static let caretHeight: CGFloat = 13

    /// The insertion point: at the end of its line, centred on it.
    static let caret = CGRect(
        x: window.minX + textInset.width + lines[caretLine] + 4,
        y: window.minY + titleBar + textInset.height
            + CGFloat(caretLine) * (lineHeight + lineSpacing) + lineHeight / 2 - caretHeight / 2,
        width: 1.5,
        height: caretHeight
    )

    /// Where the journal lands: left edge at the caret, top edge a gap below its line — the same
    /// placement `PanelPlacement` computes on screen.
    static let journalFrame = CGRect(
        x: caret.minX,
        y: caret.maxY + PanelPlacement.gap,
        width: JournalView.Layout.width * miniatureScale,
        height: JournalView.Layout.height * miniatureScale
    )

    let time: SceneTime

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.l10n) private var l10n

    var body: some View {
        let state = Self.state(at: time)
        let palette = ThemePalette.scene(colorScheme)

        ZStack(alignment: .topLeading) {
            SceneKeycap(label: "⌥", caption: "option", size: 60, pressed: state.optionDown)
                .offset(x: 10, y: 84)
            // On a Russian keyboard V also carries "М"; the shortcut works by key, in any layout.
            SceneKeycap(label: "V", secondary: l10n.language == .russian ? "М" : nil, size: 60, pressed: state.vDown)
                .offset(x: 78, y: 84)

            SceneWindow(title: l10n("Document", "Документ"), palette: palette) {
                VStack(alignment: .leading, spacing: Self.lineSpacing) {
                    ForEach(Array(Self.lines.enumerated()), id: \.offset) { _, width in
                        SceneTextLine(width: width, palette: palette)
                    }
                }
                .padding(.leading, Self.textInset.width)
                .padding(.top, Self.textInset.height)
            }
            .frame(width: Self.window.width, height: Self.window.height)
            .offset(x: Self.window.minX, y: Self.window.minY)

            // Drawn over the window at the canvas's own coordinates, so the caret and the journal
            // under it come from the same numbers.
            SceneCaret(height: Self.caret.height, visible: SceneCaret.isVisible(at: time, duration: Self.duration))
                .offset(x: Self.caret.minX, y: Self.caret.minY)

            JournalMiniature(palette: palette)
                .scaleEffect(Self.miniatureScale)
                .frame(width: Self.journalFrame.width, height: Self.journalFrame.height)
                .shadow(color: palette.shadow(0.3), radius: 14, y: 8)
                .scaleEffect(0.96 + 0.04 * state.journal, anchor: .top)
                .opacity(state.journal)
                .offset(x: Self.journalFrame.minX, y: Self.journalFrame.minY)
        }
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
    }
}
```

- [ ] **Step 4: Сцена на своём слайде**

В `Sources/BufferJournal/Onboarding/OnboardingSceneView.swift` заменить:

```swift
        case .hotKey: OnboardingLayout.sceneSize
```

на:

```swift
        case .hotKey: HotKeyScene.size
```

В `Sources/BufferJournal/Onboarding/OnboardingSceneView.swift` заменить:

```swift
        case .hotKey: Color.clear
```

на:

```swift
        case .hotKey: HotKeyScene(time: time)
```

- [ ] **Step 5: Запустить — проходит**

Run: `swift test --filter HotKeySceneTests`
Expected: PASS.

Run: `swift build && swift test`
Expected: `Build complete!`, все тесты PASS.

- [ ] **Step 6: Посмотреть снимки**

Run: `SNAPSHOT_DIR=/tmp/stash-snapshots swift test --filter SnapshotTests`
Expected: PASS.

Проверка вручную: `scene-hotKey-end-ru-light.png` — две клавиши слева, окно «Документ», точка вставки во второй строке и прямо под ней, с зазором, маленький журнал: оранжевая выбранная строка, фильтр «Все», четыре строки без поля поиска, справа текст клипа и оранжевая «Вставить». Журнал не выходит за холст и не налезает на клавиши. На V в русской версии видна «М», в английской нет. `scene-hotKey-mid-ru-light.png` — клавиши нажаты, журнал ещё проявляется.

- [ ] **Step 7: Коммит**

```bash
git add Sources/BufferJournal/Onboarding/Scenes/JournalMiniature.swift Sources/BufferJournal/Onboarding/Scenes/HotKeyScene.swift Sources/BufferJournal/Onboarding/OnboardingSceneView.swift Tests/BufferJournalTests/Scenes/HotKeySceneTests.swift
git commit -m "Tutorial scene: open with ⌥V" -m "The journal opens under the line with the insertion point, a PanelPlacement gap
below it, as it does on screen."
```

---

### Task 14: Сцена «ВСТАВКА»

**Files:**
- Create: `Sources/BufferJournal/Onboarding/Scenes/PasteScene.swift`
- Modify: `Sources/BufferJournal/Onboarding/OnboardingSceneView.swift` — `case .paste`
- Test: `Tests/BufferJournalTests/Scenes/PasteSceneTests.swift`

**Interfaces:**
- Consumes: набор для сцен (Task 11), `Track`, `CursorTrack`, `SceneTime` (Task 7), `Localized` (Task 5).
- Produces: `PasteScene(time:)`, `PasteScene.duration`, `PasteScene.size`, `PasteScene.State`, `PasteScene.state(at: SceneTime) -> State`.

- [ ] **Step 1: Тест стоп-кадра**

Создать `Tests/BufferJournalTests/Scenes/PasteSceneTests.swift`:

```swift
import CoreGraphics
import Testing
@testable import BufferJournal

/// The stop frame from the spec's "Сцены" section and the moments that lead to it.
@MainActor
struct PasteSceneTests {
    @Test func pasteEndsWithTheClipInTheLetterAndTheJournalGone() {
        let end = PasteScene.state(at: .end(of: PasteScene.duration))
        #expect(end.selectedRow == 1)
        #expect(end.hoveredRow == 1)
        #expect(end.pasted == 1)
        // Close After Selection is on by default: the journal dissolves after the click.
        #expect(end.journal == 0)
        #expect(end.cursor.tip == PasteScene.returnButton)
        #expect(end.cursor.opacity == 1)
        let beforeClick = PasteScene.state(at: SceneTime(t: 1.4, rewind: 0))
        #expect(beforeClick.selectedRow == nil)
        #expect(beforeClick.journal == 1)
        #expect(beforeClick.pasted == 0)
    }
}
```

- [ ] **Step 2: Запустить — падает**

Run: `swift test --filter PasteSceneTests`
Expected: FAIL: ошибка сборки `cannot find 'PasteScene' in scope`.

- [ ] **Step 3: Сцена**

Слева «Сегодня» из трёх строк — картинка, текст «Счёт за сентябрь № 1042», PDF; справа окно «Письмо» с точкой вставки. Указатель заходит на строку с текстом: подсветка наведения, кнопки строки, текст гаснет под ними (0,3–0,8 с). Указатель на оранжевой стрелке, клик (1,5 с): строка выбрана, стрелка белая с оранжевым значком, в письме у точки вставки появляется текст клипа, а журнал растворяется — «Закрывать после выбора» включено по умолчанию (1,6–2,2 с). Тоста «Вставлено» в сцене нет: журнал уходит, и говорить о вставке нечему.

Создать `Sources/BufferJournal/Onboarding/Scenes/PasteScene.swift`:

```swift
import SwiftUI

/// ВСТАВКА: the arrow hovers a text clip and clicks its orange arrow; the row is selected, the
/// clip's text lands at the insertion point of a letter next to the list, and the journal goes
/// away — Close After Selection is on by default.
struct PasteScene: View {
    static let duration = 3.6
    /// The list, and the letter to its right.
    static let size = CGSize(width: 470, height: 236)

    struct State: Equatable {
        var cursor: CursorState
        var ripple: ClickRipple?
        var hoveredRow: Int?
        var selectedRow: Int?
        /// 1 while the journal is there, 0 once it has dissolved.
        var journal: Double
        /// 0…1: the pasted text appearing in the letter.
        var pasted: Double
    }

    /// Tip of the arrow over the orange return button of the second row (list x 10…260, row y 88…146).
    static let returnButton = CGPoint(x: 239, y: 117)
    private static let click = 1.5

    private static let cursor = CursorTrack(
        tip: Track(CGPoint(x: 230, y: 240))
            .to(CGPoint(x: 150, y: 117), at: 0.3, until: 0.8)
            .to(returnButton, at: 0.95, until: 1.35),
        opacity: Track(0.0).to(1, at: 0.15, until: 0.35),
        clicks: [click]
    )
    private static let hovered = Track<Int?>(nil).set(1, at: 0.62)
    private static let selected = Track<Int?>(nil).set(1, at: click + 0.04)
    // The panel's own fade is 0.055 s — too quick to follow; the spec gives the scene 0.2 s.
    private static let journal = Track(1.0).to(0, at: 1.7, until: 1.9, .easeOut)
    private static let pasted = Track(0.0).to(1, at: 1.75, until: 2.05, .easeOut)

    static func state(at time: SceneTime) -> State {
        State(
            cursor: cursor.state(at: time),
            ripple: cursor.ripple(at: time),
            hoveredRow: hovered.value(at: time),
            selectedRow: selected.value(at: time),
            journal: journal.value(at: time),
            pasted: pasted.value(at: time)
        )
    }

    static let invoice = Localized(en: "Invoice for September #1042", ru: "Счёт за сентябрь № 1042")

    let time: SceneTime

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.l10n) private var l10n

    var body: some View {
        let state = Self.state(at: time)
        let palette = ThemePalette.scene(colorScheme)
        let clips = [
            DemoClips.image("paste-photo", .mountains, pixelSize: CGSize(width: 1600, height: 1000), at: 14, 2),
            DemoClips.text("paste-invoice", Self.invoice, l10n, at: 13, 47),
            DemoClips.file("paste-contract", Localized(en: "Contract.pdf", ru: "Договор.pdf"), bytes: 1_240_000, l10n, at: 12, 10),
        ]

        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                SectionHeader(title: l10n("Today", "Сегодня"), palette: palette)
                ForEach(Array(clips.enumerated()), id: \.element.id) { index, clip in
                    DemoRow(clip: clip, isSelected: state.selectedRow == index, isHovered: state.hoveredRow == index, palette: palette)
                }
            }
            .padding(.horizontal, 10)
            .frame(width: 270)
            .padding(.top, 4)
            .opacity(state.journal)

            SceneWindow(title: l10n("Letter", "Письмо"), palette: palette) {
                letter(state, palette: palette)
            }
            .frame(width: 186, height: 212)
            .offset(x: 274, y: 10)

            SceneRipple(ripple: state.ripple)
            SceneCursor(state: state.cursor)
        }
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
    }

    private func letter(_ state: State, palette: ThemePalette) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            SceneTextLine(width: 120, palette: palette)
            SceneTextLine(width: 150, palette: palette)
            SceneTextLine(width: 96, palette: palette)
            SceneTextLine(width: 138, palette: palette)
            HStack(spacing: 1) {
                if state.pasted > 0 {
                    Text(Self.invoice(l10n))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(palette.textPrimary)
                        .lineLimit(1)
                        .opacity(state.pasted)
                        .offset(y: (1 - state.pasted) * 4)
                }
                SceneCaret(height: 13, visible: SceneCaret.isVisible(at: time, duration: Self.duration))
            }
        }
        .padding(14)
    }
}
```

- [ ] **Step 4: Сцена на своём слайде**

В `Sources/BufferJournal/Onboarding/OnboardingSceneView.swift` заменить:

```swift
        case .paste: OnboardingLayout.sceneSize
```

на:

```swift
        case .paste: PasteScene.size
```

В `Sources/BufferJournal/Onboarding/OnboardingSceneView.swift` заменить:

```swift
        case .paste: Color.clear
```

на:

```swift
        case .paste: PasteScene(time: time)
```

- [ ] **Step 5: Запустить — проходит**

Run: `swift test --filter PasteSceneTests`
Expected: PASS.

Run: `swift build && swift test`
Expected: `Build complete!`, все тесты PASS.

- [ ] **Step 6: Посмотреть снимки**

Run: `SNAPSHOT_DIR=/tmp/stash-snapshots swift test --filter SnapshotTests`
Expected: PASS.

Проверка вручную: `scene-paste-mid-ru-light.png` — строка с наведением и тремя кнопками, указатель на оранжевой стрелке, список на месте. `scene-paste-end-ru-light.png` — списка нет, в письме «Счёт за сентябрь № 1042» и точка вставки после него, указатель стоит там, где была кнопка. Тоста нигде нет.

- [ ] **Step 7: Коммит**

```bash
git add Sources/BufferJournal/Onboarding/Scenes/PasteScene.swift Sources/BufferJournal/Onboarding/OnboardingSceneView.swift Tests/BufferJournalTests/Scenes/PasteSceneTests.swift
git commit -m "Tutorial scene: paste" -m "The clip lands in the letter and the journal dissolves: Close After Selection is
on by default, so the scene ends with the journal gone."
```

---

### Task 15: Сцена «ЗАКРЕП»

**Files:**
- Create: `Sources/BufferJournal/Onboarding/Scenes/PinScene.swift`
- Modify: `Sources/BufferJournal/Onboarding/OnboardingSceneView.swift` — `case .pin`
- Test: `Tests/BufferJournalTests/Scenes/PinSceneTests.swift`

**Interfaces:**
- Consumes: набор для сцен (Task 11), `Track`, `CursorTrack`, `SceneTime` (Task 7), `Localized` (Task 5).
- Produces: `PinScene(time:)`, `PinScene.duration`, `PinScene.size`, `PinScene.State`, `PinScene.state(at: SceneTime) -> State`.

- [ ] **Step 1: Тест стоп-кадра**

Создать `Tests/BufferJournalTests/Scenes/PinSceneTests.swift`:

```swift
import CoreGraphics
import Testing
@testable import BufferJournal

/// The stop frame from the spec's "Сцены" section and the moments that lead to it.
@MainActor
struct PinSceneTests {
    @Test func pinEndsWithTheAddressPinnedAndTwoNewClips() {
        let end = PinScene.state(at: .end(of: PinScene.duration))
        #expect(end.isPinned)
        #expect(end.hovered == nil)
        #expect(PinScene.layout(end) == ["header-pinned", "pin-address", "header-today", "pin-order", "pin-promo"])
        let start = PinScene.state(at: SceneTime(t: 0, rewind: 0))
        #expect(PinScene.layout(start) == ["header-today", "pin-link", "pin-address", "pin-photo"])
    }
}
```

- [ ] **Step 2: Запустить — падает**

Run: `swift test --filter PinSceneTests`
Expected: FAIL: ошибка сборки `cannot find 'PinScene' in scope`.

- [ ] **Step 3: Сцена**

Список «Сегодня»: ссылка на презентацию, «Адрес офиса: Тверская, 12, подъезд 3», картинка. Указатель наводит на адрес и жмёт булавку (1,4 с): строка уезжает в новый раздел «Закреплённые», остальные сдвигаются за 0,3 с, как в журнале. Указатель уходит вправо, у строки метка-булавка. В «Сегодня» сверху приходят два новых клипа (2,4 и 2,9 с), старые уходят: после закрепа в «Сегодня» помещаются две строки. Список — один `ForEach` по ключам строк и заголовков, чтобы закреплённая строка переезжала, а не исчезала и появлялась.

Создать `Sources/BufferJournal/Onboarding/Scenes/PinScene.swift`:

```swift
import SwiftUI

/// ЗАКРЕП: the arrow pins the office address; the row rises into a new "Pinned" section. Then two
/// new clips arrive at the top of "Today" and push the older ones out, while the pinned one stays.
struct PinScene: View {
    static let duration = 4.6
    /// The list, with room on its right for the arrow to step away.
    static let size = CGSize(width: 310, height: 234)

    struct State: Equatable {
        var cursor: CursorState
        var ripple: ClickRipple?
        var hovered: String?
        var isPinned: Bool
        var arrived: Int
    }

    /// The pin button of the address row (rows x 10…260, y 88…146).
    static let pinButton = CGPoint(x: 179, y: 117)
    private static let click = 1.4

    private static let cursor = CursorTrack(
        tip: Track(CGPoint(x: 296, y: 240))
            .to(CGPoint(x: 110, y: 117), at: 0.3, until: 0.8)
            .to(pinButton, at: 0.95, until: 1.3)
            .to(CGPoint(x: 290, y: 172), at: 1.55, until: 1.95),
        opacity: Track(0.0).to(1, at: 0.15, until: 0.35),
        clicks: [click]
    )
    private static let hovered = Track<String?>(nil).set("pin-address", at: 0.62).set(nil, at: 1.62)
    private static let pinned = Track(false).set(true, at: click + 0.04)
    private static let arrived = Track(0).set(1, at: 2.4).set(2, at: 2.9)

    static func state(at time: SceneTime) -> State {
        State(
            cursor: cursor.state(at: time),
            ripple: cursor.ripple(at: time),
            hovered: hovered.value(at: time),
            isPinned: pinned.value(at: time),
            arrived: arrived.value(at: time)
        )
    }

    /// Rows in list order: the pinned section, then "Today" — at most two clips once something is
    /// pinned, so the newest push the oldest out.
    static func layout(_ state: State) -> [String] {
        var today = ["pin-link", "pin-address", "pin-photo"]
        if state.isPinned {
            today.removeAll { $0 == "pin-address" }
        }
        today.insert(contentsOf: ["pin-order", "pin-promo"].suffix(state.arrived), at: 0)
        if state.isPinned {
            today = Array(today.prefix(2))
        }
        return (state.isPinned ? ["header-pinned", "pin-address"] : []) + ["header-today"] + today
    }

    let time: SceneTime

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.l10n) private var l10n

    var body: some View {
        let state = Self.state(at: time)
        let palette = ThemePalette.scene(colorScheme)
        let clips = Dictionary(uniqueKeysWithValues: clips.map { ($0.id, $0) })
        let items = Self.layout(state)

        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                ForEach(items, id: \.self) { item in
                    switch item {
                    case "header-pinned":
                        SectionHeader(title: l10n("Pinned", "Закреплённые"), palette: palette)
                            .transition(.opacity)
                    case "header-today":
                        SectionHeader(title: l10n("Today", "Сегодня"), palette: palette)
                    default:
                        if let clip = clips[item] {
                            DemoRow(
                                clip: item == "pin-address" ? clip.pinned(state.isPinned) : clip,
                                isHovered: state.hovered == item,
                                palette: palette
                            )
                            .transition(.journalRow)
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .frame(width: 270)
            .offset(y: 4)
            .animation(.easeOut(duration: 0.3), value: items)

            SceneRipple(ripple: state.ripple)
            SceneCursor(state: state.cursor)
        }
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
    }

    private var clips: [DemoClip] {
        [
            DemoClips.text("pin-link", Localized(en: "Link to the slides", ru: "Ссылка на презентацию"), l10n, at: 14, 20),
            DemoClips.text("pin-address", Localized(en: "Office address: 12 Main St, entrance 3", ru: "Адрес офиса: Тверская, 12, подъезд 3"), l10n, at: 13, 5),
            DemoClips.image("pin-photo", .sunset, pixelSize: CGSize(width: 900, height: 1200), at: 11, 48),
            DemoClips.text("pin-promo", Localized(en: "Promo code AUTUMN25", ru: "Промокод AUTUMN25"), l10n, at: 14, 31),
            DemoClips.text("pin-order", Localized(en: "Order number 48213", ru: "Номер заказа 48213"), l10n, at: 14, 35),
        ]
    }
}
```

- [ ] **Step 4: Сцена на своём слайде**

В `Sources/BufferJournal/Onboarding/OnboardingSceneView.swift` заменить:

```swift
        case .pin: OnboardingLayout.sceneSize
```

на:

```swift
        case .pin: PinScene.size
```

В `Sources/BufferJournal/Onboarding/OnboardingSceneView.swift` заменить:

```swift
        case .pin: Color.clear
```

на:

```swift
        case .pin: PinScene(time: time)
```

- [ ] **Step 5: Запустить — проходит**

Run: `swift test --filter PinSceneTests`
Expected: PASS.

Run: `swift build && swift test`
Expected: `Build complete!`, все тесты PASS.

- [ ] **Step 6: Посмотреть снимки**

Run: `SNAPSHOT_DIR=/tmp/stash-snapshots swift test --filter SnapshotTests`
Expected: PASS.

Проверка вручную: `scene-pin-mid-ru-light.png` — «Закреплённые» с адресом, под «Сегодня» ссылка и картинка. `scene-pin-end-ru-light.png` — адрес в «Закреплённых» с булавкой справа, в «Сегодня» «Номер заказа 48213» и «Промокод AUTUMN25», указатель справа от списка.

- [ ] **Step 7: Коммит**

```bash
git add Sources/BufferJournal/Onboarding/Scenes/PinScene.swift Sources/BufferJournal/Onboarding/OnboardingSceneView.swift Tests/BufferJournalTests/Scenes/PinSceneTests.swift
git commit -m "Tutorial scene: pin"
```

---

### Task 16: Сцена «КАРТИНКИ»

**Files:**
- Create: `Sources/BufferJournal/Onboarding/Scenes/ImagesScene.swift`
- Modify: `Sources/BufferJournal/Onboarding/OnboardingSceneView.swift` — `case .images`
- Test: `Tests/BufferJournalTests/Scenes/ImagesSceneTests.swift`

**Interfaces:**
- Consumes: набор для сцен (Task 11), `Track`, `CursorTrack`, `SceneTime` (Task 7), `Localized` (Task 5).
- Produces: `ImagesScene(time:)`, `ImagesScene.duration`, `ImagesScene.size`, `ImagesScene.State`, `ImagesScene.state(at: SceneTime) -> State`.

- [ ] **Step 1: Тест стоп-кадра**

Создать `Tests/BufferJournalTests/Scenes/ImagesSceneTests.swift`:

```swift
import CoreGraphics
import Testing
@testable import BufferJournal

/// The stop frame from the spec's "Сцены" section and the moments that lead to it.
@MainActor
struct ImagesSceneTests {
    @Test func imagesEndsInPreviewWithTheImagesFilter() {
        let end = ImagesScene.state(at: .end(of: ImagesScene.duration))
        #expect(end.filter == 2)
        #expect(end.preview == 1)
        #expect(end.cursor.tip == ImagesScene.picture)
    }
}
```

- [ ] **Step 2: Запустить — падает**

Run: `swift test --filter ImagesSceneTests`
Expected: FAIL: ошибка сборки `cannot find 'ImagesScene' in scope`.

- [ ] **Step 3: Сцена**

Кусок журнала 1:1: слева список шириной 270 pt — фильтр типов помещается целиком — и строки: текст, картинка, PDF; справа превью текста. Указатель жмёт «Картинки» (1,0 с): полозок переезжает за 0,22 с, в списке две картинки, первая выбрана, справа её превью. Указатель жмёт на картинку (2,3 с) — поверх открывается окно «Просмотр».

Создать `Sources/BufferJournal/Onboarding/Scenes/ImagesScene.swift`:

```swift
import SwiftUI

/// КАРТИНКИ: a piece of the journal at full size. The arrow picks "Images" in the type filter,
/// the list keeps the two images and shows the first; a click on it opens Preview.
struct ImagesScene: View {
    static let duration = 4.2
    /// A piece of the journal at full size: the list pane, wide enough for the whole filter, and
    /// the preview pane.
    static let size = CGSize(width: 520, height: 240)
    static let listWidth: CGFloat = 270

    struct State: Equatable {
        var cursor: CursorState
        var ripple: ClickRipple?
        /// Index in the type filter: 0 all, 2 images.
        var filter: Int
        /// 0…1: the Preview window opening.
        var preview: Double
    }

    /// Centre of the "Images" segment: filter x 10…260, four segments of 61.5 pt after a 2 pt inset.
    static let imagesSegment = CGPoint(x: 166, y: 24)
    /// The picture in the preview pane, which runs from x 270 to 520.
    static let picture = CGPoint(x: 395, y: 112)

    private static let cursor = CursorTrack(
        tip: Track(CGPoint(x: 300, y: 236))
            .to(imagesSegment, at: 0.3, until: 0.85)
            .to(picture, at: 1.5, until: 2.05),
        opacity: Track(0.0).to(1, at: 0.15, until: 0.35),
        clicks: [1.0, 2.3]
    )
    private static let filter = Track(0).set(2, at: 1.04)
    private static let preview = Track(0.0).to(1, at: 2.35, until: 2.6, .easeOut)

    static func state(at time: SceneTime) -> State {
        State(
            cursor: cursor.state(at: time),
            ripple: cursor.ripple(at: time),
            filter: filter.value(at: time),
            preview: preview.value(at: time)
        )
    }

    let time: SceneTime

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.l10n) private var l10n

    var body: some View {
        let state = Self.state(at: time)
        let palette = ThemePalette.scene(colorScheme)
        let all = clips
        let visible = state.filter == 2 ? all.filter(\.entry.isImage) : all
        let selected = visible[0]

        ZStack(alignment: .topLeading) {
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    TypeSegmentedControl(
                        titles: [l10n("All", "Все"), l10n("Text", "Текст"), l10n("Images", "Картинки"), l10n("Files", "Файлы")],
                        selectedIndex: state.filter,
                        palette: palette,
                        onSelect: { _ in }
                    )
                    .padding(.horizontal, 10)
                    .padding(.top, 10)
                    .padding(.bottom, 6)

                    VStack(spacing: 0) {
                        SectionHeader(title: l10n("Today", "Сегодня"), palette: palette)
                        ForEach(visible) { clip in
                            DemoRow(clip: clip, isSelected: clip.id == selected.id, palette: palette)
                                .transition(.journalRow)
                        }
                    }
                    .padding(.horizontal, 10)
                    Spacer(minLength: 0)
                }
                .frame(width: Self.listWidth)
                .background(palette.listSurface)
                .overlay(alignment: .trailing) {
                    palette.separator.frame(width: 1)
                }

                DemoDetailPane(clip: selected, photo: selected.id == "images-sunset" ? .sunset : .mountains, palette: palette)
                    .id(selected.id)
                    .transition(.opacity)
                    .background(palette.detailSurface)
            }
            .animation(.easeOut(duration: 0.22), value: state.filter)

            SceneWindow(title: l10n("Preview", "Просмотр"), palette: palette) {
                PhotoArt(style: .mountains)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .padding(8)
            }
            .frame(width: 340, height: 212)
            .scaleEffect(0.96 + 0.04 * state.preview)
            .opacity(state.preview)
            .offset(x: 90, y: 14)

            SceneRipple(ripple: state.ripple)
            SceneCursor(state: state.cursor)
        }
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
        .clipped()
    }

    private var clips: [DemoClip] {
        [
            DemoClips.text("images-meeting", Localized(en: "Meeting at 3 pm, room 3", ru: "Встреча в 15:00, переговорка 3"), l10n, at: 14, 20),
            DemoClips.image("images-mountains", .mountains, pixelSize: CGSize(width: 1600, height: 1000), at: 14, 2),
            DemoClips.file("images-contract", Localized(en: "Contract.pdf", ru: "Договор.pdf"), bytes: 1_240_000, l10n, at: 12, 10),
            DemoClips.image("images-sunset", .sunset, pixelSize: CGSize(width: 900, height: 1200), at: 11, 48),
        ]
    }
}
```

- [ ] **Step 4: Сцена на своём слайде**

В `Sources/BufferJournal/Onboarding/OnboardingSceneView.swift` заменить:

```swift
        case .images: OnboardingLayout.sceneSize
```

на:

```swift
        case .images: ImagesScene.size
```

В `Sources/BufferJournal/Onboarding/OnboardingSceneView.swift` заменить:

```swift
        case .images: Color.clear
```

на:

```swift
        case .images: ImagesScene(time: time)
```

- [ ] **Step 5: Запустить — проходит**

Run: `swift test --filter ImagesSceneTests`
Expected: PASS.

Run: `swift build && swift test`
Expected: `Build complete!`, все тесты PASS.

- [ ] **Step 6: Посмотреть снимки**

Run: `SNAPSHOT_DIR=/tmp/stash-snapshots swift test --filter SnapshotTests`
Expected: PASS.

Проверка вручную: `scene-images-mid-ru-light.png` — фильтр на «Картинки», слово помещается в свой сегмент целиком; две картинки, первая оранжевая, справа пейзаж и кнопки. `scene-images-end-ru-light.png` — поверх окно «Просмотр» с пейзажем, указатель на картинке.

- [ ] **Step 7: Коммит**

```bash
git add Sources/BufferJournal/Onboarding/Scenes/ImagesScene.swift Sources/BufferJournal/Onboarding/OnboardingSceneView.swift Tests/BufferJournalTests/Scenes/ImagesSceneTests.swift
git commit -m "Tutorial scene: images"
```

---

### Task 17: Сцена «КЛАВИШИ»

**Files:**
- Create: `Sources/BufferJournal/Onboarding/Scenes/KeysScene.swift`
- Modify: `Sources/BufferJournal/Onboarding/OnboardingSceneView.swift` — `case .keys`
- Test: `Tests/BufferJournalTests/Scenes/KeysSceneTests.swift`

**Interfaces:**
- Consumes: набор для сцен (Task 11), `Track`, `SceneTime` (Task 7), `Localized` (Task 5).
- Produces: `KeysScene(time:)`, `KeysScene.duration`, `KeysScene.size`, `KeysScene.State`, `KeysScene.state(at: SceneTime) -> State`, `KeysScene.word`, `KeysScene.letters`.

- [ ] **Step 1: Тест стоп-кадра**

Создать `Tests/BufferJournalTests/Scenes/KeysSceneTests.swift`:

```swift
import CoreGraphics
import Testing
@testable import BufferJournal

/// The stop frame from the spec's "Сцены" section and the moments that lead to it.
@MainActor
struct KeysSceneTests {
    @Test func keysEndWithTheThirdClipBehindTheTypedWordAndTheJournalGone() {
        let end = KeysScene.state(at: .end(of: KeysScene.duration))
        #expect(end.typed == KeysScene.letters)
        #expect(end.selectedRow == 2)
        #expect(end.pasted == 1)
        #expect(end.journal == 0)
        #expect(!end.downPressed && !end.returnPressed)

        // The letters go to the document while the journal is open.
        let typing = KeysScene.state(at: SceneTime(t: 0.5, rewind: 0))
        #expect(typing.typed == 1)
        #expect(typing.journal == 1)

        // One ↓ moves the selection by one row, and nothing is pasted yet.
        let afterFirstDown = KeysScene.state(at: SceneTime(t: 1.8, rewind: 0))
        #expect(afterFirstDown.selectedRow == 1)
        #expect(afterFirstDown.pasted == 0)
        #expect(KeysScene.state(at: SceneTime(t: 1.65, rewind: 0)).downPressed)
        #expect(KeysScene.state(at: SceneTime(t: 2.65, rewind: 0)).returnPressed)
    }

    @Test func theSceneTypesThreeLettersInBothLanguages() {
        #expect(KeysScene.word.ru == "нап")
        #expect(KeysScene.word.en == "typ")
        #expect(KeysScene.word.ru.count == KeysScene.letters)
        #expect(KeysScene.word.en.count == KeysScene.letters)
    }
}
```

- [ ] **Step 2: Запустить — падает**

Run: `swift test --filter KeysSceneTests`
Expected: FAIL: ошибка сборки `cannot find 'KeysScene' in scope`.

- [ ] **Step 3: Сцена**

Указателя нет: мышь здесь не нужна. Слева окно «Документ» с мигающей точкой вставки, справа от него журнал из трёх строк — картинка, PDF, текст; выбрана первая. Сначала в документе печатается слово: буквы «н», «а», «п» появляются через 0,2 с (0,4–1,0 с) у точки вставки — журнал открыт, а текст идёт в документ. Затем под окном нажимается ↓ (1,6 с), и выбор переходит на вторую строку, потом ещё раз ↓ (2,0 с) — на третью. ⏎ (2,6 с): текст третьего клипа появляется в документе за набранным словом, журнал растворяется за 0,2 с. В английском печатается «typ». Клавиши рисуются как в сцене «ВЫЗОВ» — тем же `SceneKeycap`.

Создать `Sources/BufferJournal/Onboarding/Scenes/KeysScene.swift`:

```swift
import SwiftUI

/// КЛАВИШИ: no pointer. The journal is open next to a document, and the letters still go to the
/// document. ↓ and ↓ move the selection, ⏎ pastes the third clip behind the typed word and the
/// journal goes away.
struct KeysScene: View {
    static let duration = 4.2
    /// The document with its keys, and the journal's rows to its right.
    static let size = CGSize(width: 470, height: 236)

    struct State: Equatable {
        /// Letters of the word typed so far.
        var typed: Int
        var downPressed: Bool
        var returnPressed: Bool
        /// Which row the journal's keys have landed on.
        var selectedRow: Int
        /// 1 while the journal is there, 0 once it has dissolved.
        var journal: Double
        /// 0…1: the pasted clip appearing in the document.
        var pasted: Double
    }

    /// The word being typed while the journal is open.
    static let word = Localized(en: "typ", ru: "нап")
    static let letters = 3

    // Typing starts at 0.4 s and a letter lands every 0.2 s; the word stands by 1.0 s.
    private static let typed = Track(0).set(1, at: 0.4).set(2, at: 0.6).set(3, at: 0.8)
    private static let down = Track(false)
        .set(true, at: 1.6).set(false, at: 1.72)
        .set(true, at: 2.0).set(false, at: 2.12)
    private static let selected = Track(0).set(1, at: 1.64).set(2, at: 2.04)
    private static let enter = Track(false).set(true, at: 2.6).set(false, at: 2.72)
    // The panel's own fade is 0.055 s — too quick to follow; the spec gives the scene 0.2 s.
    private static let journal = Track(1.0).to(0, at: 2.7, until: 2.9, .easeOut)
    private static let pasted = Track(0.0).to(1, at: 2.68, until: 2.98, .easeOut)

    static func state(at time: SceneTime) -> State {
        State(
            typed: typed.value(at: time),
            downPressed: down.value(at: time),
            returnPressed: enter.value(at: time),
            selectedRow: selected.value(at: time),
            journal: journal.value(at: time),
            pasted: pasted.value(at: time)
        )
    }

    // MARK: Geometry, in canvas coordinates

    /// The document the person keeps typing in.
    private static let window = CGRect(x: 8, y: 6, width: 178, height: 152)
    /// The keys pressed under it: ↓ and ⏎, centred on the window.
    private static let keySize: CGFloat = 52
    private static let keysTop: CGFloat = 172
    /// The journal's rows, at their real width, to the right of the window.
    private static let listLeft: CGFloat = 192
    private static let listWidth: CGFloat = 270

    let time: SceneTime

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.l10n) private var l10n

    var body: some View {
        let state = Self.state(at: time)
        let palette = ThemePalette.scene(colorScheme)
        let clips = self.clips

        ZStack(alignment: .topLeading) {
            SceneWindow(title: l10n("Document", "Документ"), palette: palette) {
                document(state, palette: palette)
            }
            .frame(width: Self.window.width, height: Self.window.height)
            .offset(x: Self.window.minX, y: Self.window.minY)

            SceneKeycap(label: "↓", size: Self.keySize, pressed: state.downPressed)
                .offset(x: 34, y: Self.keysTop)
            SceneKeycap(label: "⏎", size: Self.keySize, pressed: state.returnPressed)
                .offset(x: 102, y: Self.keysTop)

            VStack(spacing: 0) {
                SectionHeader(title: l10n("Today", "Сегодня"), palette: palette)
                ForEach(Array(clips.enumerated()), id: \.element.id) { index, clip in
                    DemoRow(clip: clip, isSelected: state.selectedRow == index, palette: palette)
                }
            }
            .padding(.horizontal, 10)
            .frame(width: Self.listWidth)
            .opacity(state.journal)
            .offset(x: Self.listLeft, y: 6)
        }
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
    }

    /// Two grey lines and the line being typed: the word, then the pasted clip, then the caret.
    private func document(_ state: State, palette: ThemePalette) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            SceneTextLine(width: 110, palette: palette)
            SceneTextLine(width: 130, palette: palette)
            HStack(spacing: 1) {
                if state.typed > 0 {
                    Text(String(Self.word(l10n).prefix(state.typed)))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(palette.textPrimary)
                }
                if state.pasted > 0 {
                    Text(Self.promo(l10n))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(palette.textPrimary)
                        .lineLimit(1)
                        .opacity(state.pasted)
                        .offset(y: (1 - state.pasted) * 4)
                }
                SceneCaret(height: 13, visible: SceneCaret.isVisible(at: time, duration: Self.duration))
            }
        }
        .padding(.leading, 14)
        .padding(.top, 12)
    }

    /// The clip ⏎ pastes: the third row of the list.
    private static let promo = Localized(en: "Promo code AUTUMN25", ru: "Промокод AUTUMN25")

    private var clips: [DemoClip] {
        [
            DemoClips.image("keys-photo", .mountains, pixelSize: CGSize(width: 1600, height: 1000), at: 14, 2),
            DemoClips.file("keys-contract", Localized(en: "Contract.pdf", ru: "Договор.pdf"), bytes: 1_240_000, l10n, at: 12, 10),
            DemoClips.text("keys-promo", Self.promo, l10n, at: 9, 12),
        ]
    }
}
```

- [ ] **Step 4: Сцена на своём слайде**

В `Sources/BufferJournal/Onboarding/OnboardingSceneView.swift` заменить:

```swift
        case .keys: OnboardingLayout.sceneSize
```

на:

```swift
        case .keys: KeysScene.size
```

В `Sources/BufferJournal/Onboarding/OnboardingSceneView.swift` заменить:

```swift
        case .keys: Color.clear
```

на:

```swift
        case .keys: KeysScene(time: time)
```

- [ ] **Step 5: Запустить — проходит**

Run: `swift test --filter KeysSceneTests`
Expected: PASS: 2 теста.

Run: `swift build && swift test`
Expected: `Build complete!`, все тесты PASS.

- [ ] **Step 6: Посмотреть снимки**

Run: `SNAPSHOT_DIR=/tmp/stash-snapshots swift test --filter SnapshotTests`
Expected: PASS.

Проверка вручную: `scene-keys-mid-ru-light.png` — окно «Документ» со словом «нап» у точки вставки, под ним клавиши ↓ и ⏎, справа три строки журнала, выбрана первая. `scene-keys-end-ru-light.png` — строк журнала нет, в документе «нап» и за ним «Промокод AUTUMN25», клавиши отпущены. В английской версии в документе «typ» и «Promo code AUTUMN25».

- [ ] **Step 7: Коммит**

```bash
git add Sources/BufferJournal/Onboarding/Scenes/KeysScene.swift Sources/BufferJournal/Onboarding/OnboardingSceneView.swift Tests/BufferJournalTests/Scenes/KeysSceneTests.swift
git commit -m "Tutorial scene: the journal's keys" -m "Letters keep going to the document while the journal is open; ↓ picks a clip and
⏎ pastes it behind the typed word, and the journal closes."
```

---

### Task 18: Сцена «НАСТРОЙКИ»

**Files:**
- Create: `Sources/BufferJournal/Onboarding/Scenes/SettingsScene.swift`
- Modify: `Sources/BufferJournal/Onboarding/OnboardingSceneView.swift` — `case .settings`
- Test: `Tests/BufferJournalTests/Scenes/SettingsSceneTests.swift`

**Interfaces:**
- Consumes: набор для сцен (Task 11) — `SceneCursor`, `SceneRipple`, `ThemePalette.scene(_:)`; `Track`, `CursorTrack`, `SceneTime` (Task 7); `StatusMenuTitles` (Task 10) — `openStash`, `tutorial`, `closeAfterSelection`, `interceptKeys`, `openAtCaret`, `theme`, `language`, `clearHistory`, `quit`; `L10n.themeName(_:)`; ресурс `StatusIcon`.
- Produces: `SettingsScene(time:)`, `SettingsScene.duration`, `SettingsScene.size`, `SettingsScene.State`, `SettingsScene.state(at: SceneTime) -> State`.
- Produces: `SettingsScene.Item`, `rows`, `menuOrigin`, `menuWidth`, `submenuWidth`, `submenuOrigin`, `rowHeight`, `separatorHeight`, `menuPadding`, `frame(of:)`, `isChecked(_:_:)`, `iconClick`, `itemClicks`, `blinkOff` — геометрия и моменты для тестов.
- Removes: ничего.

- [ ] **Step 1: Тест стоп-кадра**

Создать `Tests/BufferJournalTests/Scenes/SettingsSceneTests.swift`:

```swift
import CoreGraphics
import Testing
@testable import BufferJournal

/// The stop frame from the spec's "Сцены" section and the moments that lead to it.
@MainActor
struct SettingsSceneTests {
    @Test func settingsEndsOnTutorialWithTheMenuOpen() {
        let end = SettingsScene.state(at: .end(of: SettingsScene.duration))
        #expect(end.menuOpen)
        #expect(end.iconHighlighted)
        #expect(end.highlighted == .tutorial)
        // Both switches the story talks about are ticked at the end.
        #expect(SettingsScene.isChecked(.closeAfterSelection, end))
        #expect(SettingsScene.isChecked(.interceptKeys, end))
    }

    @Test func theArrowPassesCloseAfterSelectionAndClicksInterceptKeys() {
        // "Close After Selection" is on from the start: the arrow only walks over it.
        let passing = SettingsScene.state(at: SceneTime(t: 1.35, rewind: 0))
        #expect(passing.highlighted == .closeAfterSelection)
        #expect(SettingsScene.isChecked(.closeAfterSelection, passing))
        #expect(!SettingsScene.isChecked(.interceptKeys, passing))

        let click = SettingsScene.itemClicks[0]
        let ripple = SettingsScene.state(at: SceneTime(t: click + 0.01, rewind: 0)).ripple
        #expect(ripple.map { SettingsScene.frame(of: .interceptKeys).contains($0.center) } == true)
        let blink = SettingsScene.state(at: SceneTime(t: click + 0.09, rewind: 0))
        #expect(blink.menuOpen && blink.highlighted == nil && !blink.interceptChecked)
        let after = SettingsScene.state(at: SceneTime(t: click + 0.2, rewind: 0))
        #expect(after.menuOpen && after.highlighted == .interceptKeys && after.interceptChecked)
        // From the first click on, the menu never closes before the loop goes back.
        for t in stride(from: SettingsScene.iconClick + 0.05, through: SettingsScene.duration, by: 0.05) {
            #expect(SettingsScene.state(at: SceneTime(t: t, rewind: 0)).menuOpen)
        }
    }

    @Test func tutorialIsClickedAtTheEnd() {
        let ripple = SettingsScene.state(at: SceneTime(t: SettingsScene.itemClicks[1] + 0.01, rewind: 0)).ripple
        #expect(ripple.map { SettingsScene.frame(of: .tutorial).contains($0.center) } == true)
    }

    @Test func theArrowRestsOnThemeBetweenTheTwoClicks() {
        #expect(SettingsScene.state(at: SceneTime(t: 2.4, rewind: 0)).highlighted == .theme)
        // By the time it is on its way to Tutorial the submenu is gone.
        #expect(SettingsScene.state(at: SceneTime(t: 3.0, rewind: 0)).highlighted != .theme)
    }

    @Test func theMenuAndItsSubmenuFitTheCanvas() {
        #expect(SettingsScene.frame(of: .quit).maxY + SettingsScene.menuPadding <= SettingsScene.size.height)
        let submenu = SettingsScene.submenuOrigin
        #expect(submenu.x >= SettingsScene.menuOrigin.x + SettingsScene.menuWidth - 8)
        #expect(submenu.x + SettingsScene.submenuWidth <= SettingsScene.size.width)
        // Six theme rows and a separator, with the menu's padding.
        let height = 6 * SettingsScene.rowHeight + SettingsScene.separatorHeight + 2 * SettingsScene.menuPadding
        #expect(submenu.y + height <= SettingsScene.size.height)
    }

    @Test func theMenuMatchesTheMenuBarMenu() {
        // The rows are the menu of the app, in its order: two openers, three switches, two
        // submenus, then Clear History and Quit.
        #expect(SettingsScene.rows == [
            .openStash, .tutorial, nil,
            .closeAfterSelection, .interceptKeys, .openAtCaret, .theme, .language, nil,
            .clearHistory, .quit,
        ])
    }

    @Test func nothingLightsUpWhileTheLoopGoesBack() {
        for rewind in stride(from: 0.05, through: 1, by: 0.05) {
            let state = SettingsScene.state(at: SceneTime(t: SettingsScene.duration, rewind: rewind))
            #expect(!state.menuOpen)
            #expect(state.highlighted == nil)
        }
    }
}
```

- [ ] **Step 2: Запустить — падает**

Run: `swift test --filter SettingsSceneTests`
Expected: FAIL: ошибка сборки `cannot find 'SettingsScene' in scope`.

- [ ] **Step 3: Сцена**

Сверху правый край строки меню — только трей: слева значок Stash (настоящий ресурс `StatusIcon` в своих 14 × 18 pt; в тестах — запасной символ, как в `AppDelegate`), справа системные значки и часы. Указатель жмёт значок (0,9 с): значок подсвечен, под ним выпадает меню в новом составе — «Открыть Stash», «Обучение», черта, «Закрывать после выбора», «Перехватывать клавиши», «Открывать у курсора», «Тема ▸», «Язык ▸», черта, «Очистить историю», «Выйти ⌘Q». Указатель проходит по «Закрывать после выбора» — у него уже галочка — и жмёт «Перехватывать клавиши» (1,6 с): пункт на 0,06 с гаснет и снова загорается, и у него появляется галочка. Меню остаётся открытым. Указатель встаёт на «Тему» (2,1–2,8 с) — справа открывается подменю тем с галочкой у Stash Auto, — поднимается к «Обучению» и жмёт его (3,35 с), пункт так же мигает. Подсветка — системный акцент, и она всегда у пункта под указателем. Меню открыто по флагу, а не по плавной дорожке: на возврате круга оно закрывается сразу, и указатель по дороге к началу ничего не подсвечивает.

Ряды и подменю умещаются в холст 380 × 280 при ряде 20 pt: меню кончается на 230 pt, подменю тем — на 270 pt.

Создать `Sources/BufferJournal/Onboarding/Scenes/SettingsScene.swift`:

```swift
import AppKit
import SwiftUI

/// НАСТРОЙКИ: the menu bar tray. The arrow clicks the Stash icon, then "Intercept Keys",
/// which blinks and gets its check; the menu stays open. The arrow rests on Theme to open the
/// submenu on the right and ends clicking Tutorial.
struct SettingsScene: View {
    static let duration = 4.7
    /// The tray end of the menu bar, the menu under the Stash icon and the theme submenu beside it.
    static let size = CGSize(width: 380, height: 280)

    enum Item: CaseIterable, Equatable, Sendable {
        case openStash, tutorial, closeAfterSelection, interceptKeys, openAtCaret, theme, language, clearHistory, quit
    }

    struct State: Equatable {
        var cursor: CursorState
        var ripple: ClickRipple?
        var iconHighlighted: Bool
        var menuOpen: Bool
        var highlighted: Item?
        /// "Intercept Keys" has been switched on by the click.
        var interceptChecked: Bool
    }

    // Geometry, in scene points. The Stash icon opens the tray; a real menu hangs from its status
    // item's left edge, and a submenu opens to the right when there is room.
    static let statusIcon = CGPoint(x: 25, y: 12)
    static let menuOrigin = CGPoint(x: 8, y: 26)
    static let menuWidth: CGFloat = 210
    static let submenuWidth: CGFloat = 150
    static let rowHeight: CGFloat = 20
    static let separatorHeight: CGFloat = 8
    static let menuPadding: CGFloat = 4

    /// Menu rows top to bottom, as in the app's menu; nil is a separator.
    static let rows: [Item?] = [
        .openStash, .tutorial, nil,
        .closeAfterSelection, .interceptKeys, .openAtCaret, .theme, .language, nil,
        .clearHistory, .quit,
    ]

    /// Where each item sits in the menu, for the highlight to follow the arrow.
    static func frame(of item: Item) -> CGRect {
        var y = menuOrigin.y + menuPadding
        for row in rows {
            if row == item {
                return CGRect(x: menuOrigin.x, y: y, width: menuWidth, height: rowHeight)
            }
            y += row == nil ? separatorHeight : rowHeight
        }
        return .zero
    }

    /// The submenu's top-left corner: just over the menu's right edge, its first item level with Theme.
    static var submenuOrigin: CGPoint {
        CGPoint(x: menuOrigin.x + menuWidth - 4, y: frame(of: .theme).minY - menuPadding)
    }

    /// Checks in the demo menu: closing after a selection is on from the start, intercepting keys
    /// is switched on by the click. Opening at the cursor stays off so only the story's two
    /// switches carry a check.
    static func isChecked(_ item: Item, _ state: State) -> Bool {
        switch item {
        case .closeAfterSelection: true
        case .interceptKeys: state.interceptChecked
        default: false
        }
    }

    private static func center(of item: Item) -> CGPoint {
        CGPoint(x: menuOrigin.x + 90, y: frame(of: item).midY)
    }

    // Clicks: the icon, "Intercept Keys", Tutorial. The menu stays open throughout.
    static let iconClick = 0.9
    static let itemClicks = [1.6, 3.35]
    /// A clicked item goes dark for a moment and lights up again, as in macOS.
    static let blinkOff = 0.06...0.12

    private static let cursor = CursorTrack(
        tip: Track(CGPoint(x: 300, y: 262))
            .to(statusIcon, at: 0.3, until: 0.8)
            .to(center(of: .closeAfterSelection), at: 1.05, until: 1.3)
            .to(center(of: .interceptKeys), at: 1.42, until: 1.55)
            .to(center(of: .theme), at: 1.9, until: 2.1)
            .to(center(of: .tutorial), at: 2.8, until: 3.2),
        opacity: Track(0.0).to(1, at: 0.15, until: 0.35),
        clicks: [iconClick] + itemClicks
    )
    private static let iconHighlighted = Track(false).set(true, at: iconClick)
    private static let menuOpen = Track(false).set(true, at: iconClick + 0.05)
    /// The check appears as the clicked item lights up again.
    private static let interceptChecked = Track(false).set(true, at: itemClicks[0] + blinkOff.upperBound)

    static func state(at time: SceneTime) -> State {
        let cursor = cursor.state(at: time)
        let menuOpen = menuOpen.value(at: time)
        // Like a real menu, the highlight is whatever item is under the arrow, except while a clicked
        // item blinks. While the loop goes back to its start the menu is closed, so the arrow passing
        // over it lights nothing up.
        let blinking = time.rewind == 0 && itemClicks.contains { blinkOff.contains(time.t - $0) }
        let highlighted = menuOpen && !blinking ? Item.allCases.first { frame(of: $0).contains(cursor.tip) } : nil
        return State(
            cursor: cursor,
            ripple: Self.cursor.ripple(at: time),
            iconHighlighted: iconHighlighted.value(at: time),
            menuOpen: menuOpen,
            highlighted: highlighted,
            interceptChecked: interceptChecked.value(at: time)
        )
    }

    let time: SceneTime

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.l10n) private var l10n

    var body: some View {
        let state = Self.state(at: time)
        let palette = ThemePalette.scene(colorScheme)

        ZStack(alignment: .topLeading) {
            menuBar(state, palette: palette)

            Group {
                menuPanel(state, palette: palette)
                    .offset(x: Self.menuOrigin.x, y: Self.menuOrigin.y)

                if state.highlighted == .theme {
                    themeSubmenu(palette: palette)
                        .offset(x: Self.submenuOrigin.x, y: Self.submenuOrigin.y)
                }
            }
            .opacity(state.menuOpen ? 1 : 0)
            // Menus appear and vanish quickly, as in macOS.
            .animation(.easeOut(duration: 0.12), value: state.menuOpen)

            SceneRipple(ripple: state.ripple)
            SceneCursor(state: state.cursor)
        }
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
    }

    // MARK: Menu bar

    /// Only the tray: the Stash icon, then the system's own items at the right end.
    private func menuBar(_ state: State, palette: ThemePalette) -> some View {
        ZStack {
            statusIcon
                .frame(width: 26, height: 20)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(palette.textPrimary.opacity(state.iconHighlighted ? 0.14 : 0))
                )
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 10) {
                Image(systemName: "wifi").frame(width: 22)
                Image(systemName: "battery.75").frame(width: 30)
                Image(systemName: "switch.2").frame(width: 22)
                Text("14:02").frame(width: 40)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(.system(size: 12))
        .foregroundStyle(palette.textPrimary)
        .padding(.leading, 12)
        .padding(.trailing, 14)
        .frame(width: Self.size.width, height: 24)
        .background(menuBackground)
        .overlay(alignment: .bottom) {
            palette.separator.frame(height: 1)
        }
    }

    /// The real menu bar icon of Stash at its own 14 × 18 pt, with the app's own fallback.
    private var statusIcon: some View {
        Group {
            if let icon = Bundle.main.image(forResource: "StatusIcon") {
                Image(nsImage: icon)
                    .renderingMode(.template)
            } else {
                Image(systemName: "doc.on.clipboard")
            }
        }
        .frame(width: 14, height: 18)
    }

    private var menuBackground: Color {
        colorScheme == .dark ? Color(white: 0.17) : Color(white: 0.97)
    }

    // MARK: Menu

    private func menuPanel(_ state: State, palette: ThemePalette) -> some View {
        let titles = StatusMenuTitles(l10n: l10n)
        return VStack(spacing: 0) {
            ForEach(Array(Self.rows.enumerated()), id: \.offset) { _, row in
                if let row {
                    menuRow(
                        title: title(of: row, titles),
                        checked: Self.isChecked(row, state),
                        submenu: row == .theme || row == .language,
                        shortcut: row == .quit ? "⌘Q" : nil,
                        highlighted: state.highlighted == row,
                        palette: palette
                    )
                } else {
                    separator(palette: palette)
                }
            }
        }
        .padding(.vertical, Self.menuPadding)
        .frame(width: Self.menuWidth)
        .background(menuSurface(palette: palette))
    }

    private func themeSubmenu(palette: ThemePalette) -> some View {
        // The app's own order, with the separator before Stash Auto, as in AppDelegate.
        let modes: [ThemeMode?] = [.system, .light, .dark, nil, .stashAuto, .stashLight, .stashDark]
        return VStack(spacing: 0) {
            ForEach(Array(modes.enumerated()), id: \.offset) { _, mode in
                if let mode {
                    menuRow(title: l10n.themeName(mode), checked: mode == .stashAuto, submenu: false, shortcut: nil, highlighted: false, palette: palette)
                } else {
                    separator(palette: palette)
                }
            }
        }
        .padding(.vertical, Self.menuPadding)
        .frame(width: Self.submenuWidth)
        .background(menuSurface(palette: palette))
    }

    private func separator(palette: ThemePalette) -> some View {
        palette.separator
            .frame(height: 1)
            .padding(.horizontal, 10)
            .frame(height: Self.separatorHeight)
    }

    private func menuRow(title: String, checked: Bool, submenu: Bool, shortcut: String?, highlighted: Bool, palette: ThemePalette) -> some View {
        HStack(spacing: 0) {
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .semibold))
                .opacity(checked ? 1 : 0)
                .frame(width: 18)
            Text(title)
                .lineLimit(1)
            Spacer(minLength: 8)
            if submenu {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
            }
            if let shortcut {
                Text(shortcut)
                    .opacity(0.5)
            }
        }
        .font(.system(size: 12))
        .foregroundStyle(highlighted ? Color.white : palette.textPrimary)
        .padding(.horizontal, 8)
        .frame(height: Self.rowHeight)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(highlighted ? Color(nsColor: .controlAccentColor) : .clear)
                .padding(.horizontal, 5)
        )
    }

    private func menuSurface(palette: ThemePalette) -> some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        return shape
            .fill(menuBackground)
            .overlay(shape.strokeBorder(palette.border, lineWidth: 1))
            .shadow(color: palette.shadow(0.22), radius: 12, y: 6)
    }

    private func title(of item: Item, _ titles: StatusMenuTitles) -> String {
        switch item {
        case .openStash: titles.openStash
        case .tutorial: titles.tutorial
        case .closeAfterSelection: titles.closeAfterSelection
        case .interceptKeys: titles.interceptKeys
        case .openAtCaret: titles.openAtCaret
        case .theme: titles.theme
        case .language: titles.language
        case .clearHistory: titles.clearHistory
        case .quit: titles.quit
        }
    }
}
```

- [ ] **Step 4: Сцена на своём слайде**

В `Sources/BufferJournal/Onboarding/OnboardingSceneView.swift` заменить:

```swift
        case .settings: OnboardingLayout.sceneSize
```

на:

```swift
        case .settings: SettingsScene.size
```

В `Sources/BufferJournal/Onboarding/OnboardingSceneView.swift` заменить:

```swift
        case .settings: Color.clear
```

на:

```swift
        case .settings: SettingsScene(time: time)
```

- [ ] **Step 5: Запустить — проходит**

Run: `swift test --filter SettingsSceneTests`
Expected: PASS.

Run: `swift build && swift test`
Expected: `Build complete!`, все тесты PASS.

- [ ] **Step 6: Посмотреть снимки**

Run: `SNAPSHOT_DIR=/tmp/stash-snapshots swift test --filter SnapshotTests`
Expected: PASS.

Проверка вручную: `scene-settings-mid-ru-light.png` (1,88 с) — меню открыто в новом составе, галочки у «Закрывать после выбора» и «Перехватывать клавиши», указатель идёт к «Теме». `scene-settings-end-ru-light.png` — подсвечено «Обучение», подменю тем закрыто, меню целиком в холсте. В английской версии те же пункты: «Close After Selection», «Intercept Keys», «Open at the Cursor», «Tutorial».

- [ ] **Step 7: Коммит**

```bash
git add Sources/BufferJournal/Onboarding/Scenes/SettingsScene.swift Sources/BufferJournal/Onboarding/OnboardingSceneView.swift Tests/BufferJournalTests/Scenes/SettingsSceneTests.swift
git commit -m "Tutorial scene: settings" -m "The menu bar menu as the app builds it: two openers, three switches, Theme and
Language, Clear History and Quit. The arrow ticks Intercept Keys and ends on Tutorial."
```

---

### Task 19: Сцена и слайд «ДОСТУП»

Слайд работает в двух видах: последним в обучении и сам по себе, когда обучение уже видели, а доступа нет. Общее у видов — сцена с окном «Системных настроек» и три части под карточкой, взятые с экрана доступа: заголовок со значком приложения и оранжевым «Stash», строка про ⌘V и подсказка с серой полоской. В обучении в карточке под сценой стоит кнопка «Открыть настройки», а нижняя — «Начать»; один, без обучения, слайд идёт без полос прогресса и без кнопки в карточке, её место занимает нижняя кнопка «Открыть настройки» (рамку одиночного вида делает Task 9). Доступ и его проверку раз в секунду берём у готового `AccessGate`: своего кода доступа обучение не заводит.

**Files:**
- Create: `Sources/BufferJournal/Onboarding/Scenes/AccessScene.swift`
- Create: `Sources/BufferJournal/Onboarding/AccessSlide.swift` — тексты экрана доступа, заголовок, подсказка и кнопка в карточке
- Modify: `Sources/BufferJournal/Onboarding/OnboardingSceneView.swift` — `case .access`
- Modify: `Sources/BufferJournal/Onboarding/OnboardingView.swift` — низ слайда и кнопка в карточке
- Test: `Tests/BufferJournalTests/Scenes/AccessSceneTests.swift`, `Tests/BufferJournalTests/AccessSlideTests.swift`

**Interfaces:**
- Consumes: набор для сцен (Task 11) — `SceneCursor`, `SceneRipple`, `TrafficLights`, `ThemePalette.scene(_:)`; `Track`, `CursorTrack`, `SceneTime` (Task 7); `TranslucentButtonStyle`, `ThemePalette` (Task 2); `OnboardingController` (Task 8) — `isAccessOnly`, `requestAccess()`, `primaryAction()`, `handleKey(_:)`; `AccessGate.isGranted` и `AccessibilityAccess` (уже в приложении); `EnvironmentValues.onboardingOpenSettings` (Task 9).
- Produces: `AccessScene(time:)`, `AccessScene.duration`, `AccessScene.size`, `AccessScene.State`, `AccessScene.state(at: SceneTime) -> State`; `AccessScene.window`, `sidebarWidth`, `toggle`, `click` — геометрия и момент для тестов; `SceneSwitch(isOn:)`.
- Produces: `enum AccessSlide` — `titleTail(_:)`, `line(_:)`, `hint(_:)`, `buttonTitle(_:)`, `grantedTitle(_:)`, `showsCardButton(isAccessOnly:)`; `AccessPrompt(palette:l10n:)`, `AccessRequestButton(controller:palette:l10n:)`.
- Removes: ничего. `AccessScreen.swift` удаляет задача подключения (Task 10); его тексты и части живут здесь.

- [ ] **Step 1: Тест стоп-кадра сцены**

Создать `Tests/BufferJournalTests/Scenes/AccessSceneTests.swift`:

```swift
import CoreGraphics
import Testing
@testable import BufferJournal

/// The stop frame from the spec's "Сцены" section and the moments that lead to it.
@MainActor
struct AccessSceneTests {
    @Test func accessEndsSwitchedOn() {
        #expect(AccessScene.state(at: .end(of: AccessScene.duration)).isOn)
        #expect(!AccessScene.state(at: SceneTime(t: 1, rewind: 0)).isOn)
    }

    @Test func theArrowClicksTheSwitchInTheSettingsWindow() {
        let ripple = AccessScene.state(at: SceneTime(t: AccessScene.click + 0.01, rewind: 0)).ripple
        #expect(ripple?.center == AccessScene.toggle)
        // The switch belongs to the Stash row in the right-hand pane, not to the sidebar.
        #expect(AccessScene.window.contains(AccessScene.toggle))
        #expect(AccessScene.toggle.x > AccessScene.window.minX + AccessScene.sidebarWidth)
    }

    @Test func theCanvasKeepsRoomUnderTheWindowForTheCardButton() {
        // The tutorial puts the real "Open Settings" button in that strip; alone it stays empty.
        #expect(AccessScene.size.height - AccessScene.window.maxY >= 42)
    }
}
```

- [ ] **Step 2: Запустить — падает**

Run: `swift test --filter AccessSceneTests`
Expected: FAIL: ошибка сборки `cannot find 'AccessScene' in scope`.

- [ ] **Step 3: Сцена**

Окно «Системных настроек» занимает верх сцены: слева разделы, выделен «Конфиденциальность и безопасность»; справа «Универсальный доступ» — строка Stash с выключенным переключателем, под списком «+» и «−». Указатель подходит к переключателю и включает его (1,2 с): рычажок переезжает, дорожка окрашивается системным акцентом. Низ холста свободен: в обучении там стоит настоящая кнопка карточки, в одиночном виде — воздух.

Создать `Sources/BufferJournal/Onboarding/Scenes/AccessScene.swift`:

```swift
import AppKit
import SwiftUI

/// ДОСТУП: System Settings open on Privacy & Security → Accessibility; the arrow switches Stash on.
/// The bottom of the canvas stays free for the card's real "Open Settings" button; in the single
/// view of the slide there is no button and the strip is just air.
struct AccessScene: View {
    static let duration = 3.0
    /// The System Settings window, and room under it for the card's button.
    static let size = CGSize(width: 460, height: 236)

    struct State: Equatable {
        var cursor: CursorState
        var ripple: ClickRipple?
        var isOn: Bool
    }

    /// The window and the pane inside it: the sidebar on the left, the app list on the right.
    static let window = CGRect(x: 10, y: 10, width: 440, height: 174)
    static let sidebarWidth: CGFloat = 150
    /// The Stash switch: the list row sits under the title and the explanation, the switch at its
    /// trailing edge.
    static let toggle = CGPoint(x: 418, y: 96)
    static let click = 1.2

    private static let cursor = CursorTrack(
        tip: Track(CGPoint(x: 390, y: 232)).to(toggle, at: 0.3, until: 1.0),
        opacity: Track(0.0).to(1, at: 0.15, until: 0.35),
        clicks: [click]
    )
    private static let isOn = Track(false).set(true, at: click + 0.04)

    static func state(at time: SceneTime) -> State {
        State(cursor: cursor.state(at: time), ripple: cursor.ripple(at: time), isOn: isOn.value(at: time))
    }

    let time: SceneTime

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.l10n) private var l10n

    var body: some View {
        let state = Self.state(at: time)
        let palette = ThemePalette.scene(colorScheme)
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)

        ZStack(alignment: .topLeading) {
            HStack(spacing: 0) {
                sidebar(palette: palette)
                    .frame(width: Self.sidebarWidth)
                    .background(palette.listSurface)
                content(state, palette: palette)
                    .background(palette.modalBackground)
            }
            .frame(width: Self.window.width, height: Self.window.height)
            .clipShape(shape)
            .overlay(shape.strokeBorder(palette.border, lineWidth: 1))
            .shadow(color: palette.shadow(0.18), radius: 16, y: 8)
            .offset(x: Self.window.minX, y: Self.window.minY)

            SceneRipple(ripple: state.ripple)
            SceneCursor(state: state.cursor)
        }
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
    }

    private func sidebar(palette: ThemePalette) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            TrafficLights()
                .padding(.bottom, 8)
            settingsItem("wifi", l10n("Wi\u{2011}Fi", "Wi\u{2011}Fi"), color: .blue, selected: false, palette: palette)
            settingsItem("network", l10n("Network", "Сеть"), color: .blue, selected: false, palette: palette)
            settingsItem("gearshape.fill", l10n("General", "Основные"), color: .gray, selected: false, palette: palette)
            settingsItem("hand.raised.fill", l10n("Privacy & Security", "Конфиденциальность и безопасность"), color: .blue, selected: true, palette: palette)
            Spacer(minLength: 0)
        }
        .padding(10)
    }

    private func settingsItem(_ symbol: String, _ title: String, color: Color, selected: Bool, palette: ThemePalette) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(width: 18, height: 18)
                .background(color, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            Text(title)
                .font(.system(size: 11))
                .lineLimit(1)
                .foregroundStyle(selected ? Color.white : palette.textPrimary)
        }
        .padding(.horizontal, 5)
        .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(selected ? Color(nsColor: .controlAccentColor) : .clear)
        )
    }

    private func content(_ state: State, palette: ThemePalette) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.textTertiary)
                Text(l10n("Accessibility", "Универсальный доступ"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)
            }
            .padding(.bottom, 4)
            Text(l10n("Allow the applications below to control your computer.", "Разрешить приложениям ниже управлять компьютером."))
                .font(.system(size: 11))
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 22, height: 22)
                Text("Stash")
                    .font(.system(size: 13))
                    .foregroundStyle(palette.textPrimary)
                Spacer(minLength: 0)
                SceneSwitch(isOn: state.isOn)
            }
            .padding(.horizontal, 10)
            .frame(height: 38)
            .background(palette.placeholderBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            // The buttons the footnote under the card talks about.
            HStack(spacing: 10) {
                Image(systemName: "plus")
                Image(systemName: "minus")
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(palette.textTertiary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
    }
}

/// A macOS switch: the knob slides and the track takes the system accent when on.
struct SceneSwitch: View {
    let isOn: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Capsule()
            .fill(isOn ? Color(nsColor: .controlAccentColor) : (colorScheme == .dark ? Color(white: 0.32) : Color(white: 0.84)))
            .frame(width: 32, height: 19)
            .overlay(alignment: isOn ? .trailing : .leading) {
                Circle()
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.25), radius: 1, y: 0.5)
                    .padding(2)
            }
            .animation(.easeOut(duration: 0.2), value: isOn)
    }
}
```

- [ ] **Step 4: Сцена на своём слайде**

В `Sources/BufferJournal/Onboarding/OnboardingSceneView.swift` заменить:

```swift
        case .access: OnboardingLayout.sceneSize
```

на:

```swift
        case .access: AccessScene.size
```

В `Sources/BufferJournal/Onboarding/OnboardingSceneView.swift` заменить:

```swift
        case .access: Color.clear
```

на:

```swift
        case .access: AccessScene(time: time)
```

Run: `swift test --filter AccessSceneTests`
Expected: PASS.

- [ ] **Step 5: Тест слайда**

Тексты слайда — дословно с экрана доступа (`AccessScreen.swift`), обоих языков; кнопка в карточке есть только в обучении; клавиш на слайде нет; один, без обучения, слайд просит доступ нижней кнопкой.

Создать `Tests/BufferJournalTests/AccessSlideTests.swift`:

```swift
import Foundation
import Testing
@testable import BufferJournal

/// The access screen stands in for the system here: `AccessibilityAccess` is a struct of closures.
@MainActor
final class AccessSpy {
    var granted: Bool
    private(set) var requests = 0

    init(granted: Bool) {
        self.granted = granted
    }

    var access: AccessibilityAccess {
        AccessibilityAccess(
            isGranted: { [self] in granted },
            request: { [self] in
                requests += 1
                granted = true
            }
        )
    }
}

/// The ДОСТУП slide: the texts it took from the access screen, its button and its silent keys.
@MainActor
struct AccessSlideTests {
    private func defaults() -> UserDefaults {
        let name = "AccessSlideTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func controller(granted: Bool) -> (OnboardingController, AccessSpy, AccessGate) {
        let spy = AccessSpy(granted: granted)
        let gate = AccessGate(access: spy.access)
        return (OnboardingController(defaults: defaults(), access: gate), spy, gate)
    }

    private func onAccessSlide(granted: Bool = false) -> (OnboardingController, AccessSpy, AccessGate) {
        let (controller, spy, gate) = controller(granted: granted)
        controller.present(replay: false)
        while !controller.isLast {
            controller.next()
        }
        return (controller, spy, gate)
    }

    @Test func theTextsAreTheAccessScreensOwn() {
        let ru = L10n(language: .russian)
        let en = L10n(language: .english)
        #expect(AccessSlide.titleTail(ru) == " нужен Универсальный доступ")
        #expect(AccessSlide.titleTail(en) == " needs Accessibility access")
        #expect(AccessSlide.line(ru) == "Stash вставляет клип, нажимая ⌘V за вас. Без Универсального доступа macOS этого не разрешит.")
        #expect(AccessSlide.line(en) == "Stash pastes by pressing ⌘V for you. macOS won't allow it without Accessibility access.")
        #expect(AccessSlide.hint(ru).hasPrefix("Stash уже в списке и включён"))
        #expect(AccessSlide.hint(en).hasPrefix("Stash is already in the list"))
        #expect(AccessSlide.buttonTitle(ru) == "Открыть настройки")
        #expect(AccessSlide.buttonTitle(en) == "Open Settings")
        #expect(AccessSlide.grantedTitle(ru) == "Доступ включён")
        #expect(AccessSlide.grantedTitle(en) == "Access granted")
    }

    @Test func theCardHasAButtonOnlyInTheTutorial() {
        #expect(AccessSlide.showsCardButton(isAccessOnly: false))
        #expect(!AccessSlide.showsCardButton(isAccessOnly: true))
    }

    @Test func theSlideIsTheLastOneWithoutAccess() {
        let (controller, _, gate) = onAccessSlide()
        #expect(controller.slide.kind == .access)
        #expect(controller.isLast)
        #expect(!gate.isGranted)
    }

    @Test func theButtonAsksTheGateAndGrantedAccessShowsUp() {
        let (controller, spy, gate) = onAccessSlide()
        controller.requestAccess()
        #expect(spy.requests == 1)
        // The gate polls once a second while the panel is up; a refresh is what its timer does.
        gate.refresh()
        #expect(gate.isGranted)
    }

    @Test func theSlideHasNoKeys() {
        let (controller, _, _) = onAccessSlide()
        for key in [JournalKey.left, .right, .up, .down, .enter, .escape] {
            #expect(!controller.handleKey(key))
        }
        #expect(controller.slide.kind == .access)
        #expect(controller.isPresented)
    }

    @Test func aloneItIsTheOnlySlideAndItsMainButtonAsksForAccess() {
        let (controller, spy, _) = controller(granted: false)
        controller.presentAccessOnly()
        #expect(controller.isAccessOnly)
        #expect(controller.slides.count == 1)
        #expect(controller.slide.kind == .access)
        controller.primaryAction()
        #expect(spy.requests == 1)
    }
}
```

- [ ] **Step 6: Запустить — падает**

Run: `swift test --filter AccessSlideTests`
Expected: FAIL: ошибка сборки `cannot find 'AccessSlide' in scope`.

- [ ] **Step 7: Части экрана доступа**

Тексты и виды переезжают с экрана доступа как есть: заголовок 18 pt полужирный со значком приложения 21 pt (зазор 2, выравнивание по заглавным) и оранжевым «Stash» цвета `accentText`; строка 13 pt `textSecondary`; подсказка 11 pt `textTertiary` по левому краю с полоской 3 pt цвета `iconOpacity(0.22)` и зазором 10 pt до текста. Кнопка — значок `accessibility` 15 pt перед подписью 12 pt, зазор 6, высота 32, `TranslucentButtonStyle(tone: .accent, cornerRadius: 8)`. Нажатие зовёт `controller.requestAccess()`: тот просит `AccessGate.request()` и опускает панель на обычный уровень окон, чтобы не заслонять Системные настройки. Своего таймера здесь нет: пока панель на экране, `AccessGate` проверяет разрешение раз в секунду сам, и `AccessGate.isGranted` меняется следом.

Создать `Sources/BufferJournal/Onboarding/AccessSlide.swift`:

```swift
import AppKit
import SwiftUI

/// Texts of the ДОСТУП slide, word for word from the access screen it replaces.
enum AccessSlide {
    /// The title reads "Stash needs Accessibility access"; "Stash" is drawn in the icon's orange.
    static func titleTail(_ l10n: L10n) -> String {
        l10n(" needs Accessibility access", " нужен Универсальный доступ")
    }

    static func line(_ l10n: L10n) -> String {
        l10n(
            "Stash pastes by pressing ⌘V for you. macOS won't allow it without Accessibility access.",
            "Stash вставляет клип, нажимая ⌘V за вас. Без Универсального доступа macOS этого не разрешит."
        )
    }

    static func hint(_ l10n: L10n) -> String {
        l10n(
            "Stash is already in the list and switched on, but you still see this screen? Try removing it from the list of apps with “−” and clicking Open Settings again.",
            "Stash уже в списке и включён, а вы всё ещё видите этот экран? Попробуйте удалить его из списка приложений кнопкой «−» и снова нажать «Открыть настройки»."
        )
    }

    static func buttonTitle(_ l10n: L10n) -> String {
        l10n("Open Settings", "Открыть настройки")
    }

    static func grantedTitle(_ l10n: L10n) -> String {
        l10n("Access granted", "Доступ включён")
    }

    /// In the tutorial the card carries the button; alone, the main button at the bottom asks.
    static func showsCardButton(isAccessOnly: Bool) -> Bool {
        !isAccessOnly
    }
}

/// Under the card in both views of the slide: the title with the app icon, the ⌘V line and the
/// footnote about a stale entry in the Accessibility list.
struct AccessPrompt: View {
    let palette: ThemePalette
    let l10n: L10n

    /// The app icon before "Stash" keeps the proportions of the journal header's logo (icon 32 : font 28).
    private enum Title {
        static let fontSize: CGFloat = 18
        static let iconFrame: CGFloat = 21
        static let capHeight = NSFont.systemFont(ofSize: fontSize, weight: .semibold).capHeight
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 2) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: Title.iconFrame, height: Title.iconFrame)
                    .accessibilityHidden(true)

                (Text("Stash").foregroundColor(palette.accentText)
                    + Text(AccessSlide.titleTail(l10n)))
                    .font(.system(size: Title.fontSize, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)
                    // Center on the capitals, not on the line box, so the icon lines up with "S".
                    .alignmentGuide(VerticalAlignment.center) { $0[.firstTextBaseline] - Title.capHeight / 2 }
                    .accessibilityAddTraits(.isHeader)
            }

            Text(AccessSlide.line(l10n))
                .font(.system(size: 13))
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)

            // A side note: left-aligned under a grey bar, like a footnote. On the access screen the
            // button stood between the two; here it sits in the card, so the note comes closer.
            HStack(alignment: .top, spacing: 10) {
                Capsule()
                    .fill(palette.iconOpacity(0.22))
                    .frame(width: 3)

                Text(AccessSlide.hint(l10n))
                    .font(.system(size: 11))
                    .foregroundStyle(palette.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            // The bar takes the height of the text.
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The one thing inside a card that can be pressed: it asks for access and opens System Settings.
/// Once access is granted it dissolves into a note and the scene holds its stop frame.
struct AccessRequestButton: View {
    let hasAccess: Bool
    let palette: ThemePalette
    let l10n: L10n

    /// The frame hands down the same action its own button runs (Task 9).
    @Environment(\.onboardingOpenSettings) private var openSettings

    var body: some View {
        ZStack {
            if hasAccess {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ThemePalette.orange)
                    Text(AccessSlide.grantedTitle(l10n))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.textPrimary)
                }
                .frame(height: 32)
                .transition(.opacity)
            } else {
                Button {
                    openSettings()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "accessibility")
                            .font(.system(size: 15, weight: .semibold))
                        Text(AccessSlide.buttonTitle(l10n))
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 32)
                }
                .buttonStyle(TranslucentButtonStyle(tone: .accent, cornerRadius: 8))
                .transition(.opacity)
            }
        }
        // Inside a card everything keeps the Stash look, whatever theme is picked.
        .environment(\.solidAccents, true)
        .animation(.easeOut(duration: 0.2), value: hasAccess)
    }
}
```

- [ ] **Step 8: Слайд в рамке**

Две замены в `Sources/BufferJournal/Onboarding/OnboardingView.swift` (код Task 9). Первая ставит кнопку в карточку — в обучении и только там. Вторая отдаёт низ слайда заголовку, строке и подсказке вместо обычного текста: строка слайда и есть текст экрана доступа, а заголовок с подсказкой стоят вокруг неё. Низ на этом слайде выше обычного, и карточка отдаёт ему место сама.

В `Sources/BufferJournal/Onboarding/OnboardingView.swift` заменить:

```swift
            OnboardingSceneView(slide: controller.slide, still: isStill)
                .clipShape(hasSurface ? AnyShape(shape) : AnyShape(Rectangle().inset(by: -200)))
                .id(controller.run)
                .transition(.opacity)
        }
```

на:

```swift
            OnboardingSceneView(slide: controller.slide, still: isStill)
                .clipShape(hasSurface ? AnyShape(shape) : AnyShape(Rectangle().inset(by: -200)))
                .id(controller.run)
                .transition(.opacity)

            // In the tutorial the access slide carries a real button under its scene; shown alone,
            // the slide has none and the main button at the bottom asks instead.
            if controller.slide.kind == .access, AccessSlide.showsCardButton(isAccessOnly: controller.isAccessOnly) {
                AccessRequestButton(hasAccess: access.isGranted, palette: palette, l10n: l10n)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 10)
            }
        }
```

В `Sources/BufferJournal/Onboarding/OnboardingView.swift` заменить:

```swift
        HStack(alignment: .center, spacing: 16) {
            texts
```

на:

```swift
        HStack(alignment: .center, spacing: 16) {
            if controller.slide.kind == .access {
                // The slide's own text, with the title over it and the footnote under it.
                AccessPrompt(palette: palette, l10n: l10n)
            } else {
                texts
            }
```

- [ ] **Step 9: Запустить — проходит**

Run: `swift test --filter AccessSlideTests`
Expected: PASS.

Run: `swift build && swift test`
Expected: `Build complete!`, все тесты PASS.

- [ ] **Step 10: Посмотреть снимки**

Run: `SNAPSHOT_DIR=/tmp/stash-snapshots swift test --filter SnapshotTests`
Expected: PASS.

Проверка вручную: `scene-access-end-ru-light.png` — переключатель у Stash включён, указатель на нём, под окном пусто. `frame-access-640-light.png` — в карточке под окном оранжевая кнопка «Открыть настройки», ниже карточки заголовок со значком и оранжевым «Stash», строка про ⌘V и подсказка с серой полоской, справа «Начать», сверху полосы прогресса. `frame-access-only-640-light.png` (одиночный вид, Task 9) — полос нет, кнопки в карточке нет, нижняя кнопка — «Открыть настройки». На `frame-access-560-*` заголовок и подсказка помещаются, карточка ужимается.

- [ ] **Step 11: Коммит**

```bash
git add Sources/BufferJournal/Onboarding/Scenes/AccessScene.swift Sources/BufferJournal/Onboarding/AccessSlide.swift Sources/BufferJournal/Onboarding/OnboardingSceneView.swift Sources/BufferJournal/Onboarding/OnboardingView.swift Tests/BufferJournalTests/Scenes/AccessSceneTests.swift Tests/BufferJournalTests/AccessSlideTests.swift
git commit -m "Tutorial slide: Accessibility access" -m "The scene switches Stash on in System Settings; the access screen's title, line, hint
and button move under and into the card. The button asks the existing AccessGate, and
granted access turns it into a note."
```

---

### Task 20: Финальная проверка

**Files:**
- Test: `Tests/BufferJournalTests/Scenes/SceneDurationTests.swift`

**Interfaces:**
- Consumes: все сцены (Tasks 12–19), `OnboardingSlides.all` (Task 5).
- Produces: ничего нового — проверка собранного.
- Removes: ничего.

- [ ] **Step 1: Длительности сцен и слайдов совпадают**

Создать `Tests/BufferJournalTests/Scenes/SceneDurationTests.swift`:

```swift
import CoreGraphics
import Testing
@testable import BufferJournal

/// Every scene is as long as its slide says, and every kind has a scene.
@MainActor
struct SceneDurationTests {
    private static let durations: [OnboardingSceneKind: Double] = [
        .hero: HeroScene.duration,
        .hotKey: HotKeyScene.duration,
        .paste: PasteScene.duration,
        .pin: PinScene.duration,
        .images: ImagesScene.duration,
        .keys: KeysScene.duration,
        .settings: SettingsScene.duration,
        .access: AccessScene.duration,
    ]

    @Test func sceneDurationsMatchTheSlides() {
        for slide in OnboardingSlides.all {
            #expect(Self.durations[slide.kind] == slide.duration, "\(slide.kind)")
        }
    }

    @Test func everyKindHasAScene() {
        #expect(Set(Self.durations.keys) == Set(OnboardingSceneKind.allCases))
        // Every scene but the first one draws on a canvas of its own.
        for kind in OnboardingSceneKind.allCases where kind != .hero {
            #expect(OnboardingSceneView.size(of: kind) != nil, "\(kind)")
        }
        #expect(OnboardingSceneView.size(of: .hero) == nil)
    }
}
```

- [ ] **Step 2: Все тесты и снимки**

Run: `swift build && swift test`
Expected: `Build complete!`, все тесты PASS.

Run: `SNAPSHOT_DIR=/tmp/stash-snapshots swift test --filter SnapshotTests`
Expected: PASS; в `/tmp/stash-snapshots` снимки рамки в трёх размерах панели и на двух темах, снимки одиночного вида слайда «ДОСТУП» и снимки всех восьми сцен.

- [ ] **Step 3: Приложение: первый запуск**

Проверка вручную: Закрыть установленный Stash. `Scripts/build_app.sh`; `defaults delete local.buffer-journal OnboardingSeenVersion`; `open .build/Stash.app`. Панель открывается сама **по центру экрана** — настройка «Открывать у курсора» на обучение не влияет — сразу с первым слайдом. Пройти все слайды: на каждом сцена играет, доигрывает, за 0,5 с возвращается к началу, после паузы повторяется; первый слайд играет один раз — плитки падают в иконку Stash, она вспыхивает и приплющивается, после третьего удара выезжает «Stash». Полоса текущего слайда заливается за 0,3 с и стоит. Слайд «НАСТРОЙКИ» показывает меню в нынешнем составе: «Открыть Stash», «Обучение», «Закрывать после выбора», «Перехватывать клавиши», «Открывать у курсора», «Тема», «Язык», «Очистить историю», «Выйти». «Начать» на последнем слайде закрывает обучение, под ним журнал; после перезапуска обучение само не открывается.

- [ ] **Step 4: Приложение: пункт меню, клавиши, ⌥V**

Проверка вручную:

- Значок в строке меню → «Обучение»: обучение открывается с первого слайда, панель поднимается, если была спрятана. Повтор ничего не записывает: закрыть крестиком и снова открыть «Обучение» — оно открывается.
- Клавиши при открытом обучении: → и Return — вперёд, ← — назад, Esc закрывает обучение, но не панель (под ним остаётся журнал). Буквы уходят в приложение под панелью: поставить курсор в заметку, нажать несколько букв — они появляются в заметке, обучение не реагирует.
- На последнем слайде → ничего не делает, Return — «Начать».
- ⌥V посреди обучения: панель прячется вместе с обучением; ещё раз ⌥V — обучение на том же слайде, сцена начинается заново.
- Клики по зонам: левые 30 % ниже полос — назад, остальное — вперёд; на первом слайде «назад» ничего не делает.
- Меню значка → снять «Перехватывать клавиши»: клавиши перестают листать обучение — ни ←, ни →, ни Return, ни Esc, — и оно остаётся на мыши и кнопках. Вернуть галочку.

- [ ] **Step 5: Приложение: слайд «ДОСТУП» в обучении и отдельно**

Проверка вручную: разрешение Универсального доступа выдаёт и снимает пользователь, `tccutil reset Accessibility local.buffer-journal` — тоже: системные настройки безопасности агент не трогает.

- Без разрешения последний слайд обучения — «ДОСТУП»: в карточке окно «Системных настроек», под окном оранжевая кнопка «Открыть настройки», ниже карточки заголовок со значком приложения и оранжевым «Stash», строка про ⌘V и подсказка с серой полоской, справа внизу «Начать».
- Клавиш на этом слайде нет вовсе: ←, →, Return и Esc ничего не делают, панель и обучение остаются на месте; листается слайд мышью и кнопками.
- «Открыть настройки» открывает Универсальный доступ, панель опускается и не заслоняет Системные настройки.
- **Выдача доступа при открытом слайде:** включить Stash в списке — кнопка в карточке за 0,2 с растворяется в «✓ Доступ включён», сцена встаёт на стоп-кадр с включённым переключателем, панель возвращается наверх.
- С разрешением слайда нет: последний — «НАСТРОЙКИ», и «Начать» стоит на нём.
- Слайд отдельно: обучение уже отмечено увиденным (`defaults read local.buffer-journal OnboardingSeenVersion` → 1), разрешение снято, запустить Stash — панель показывает слайд «ДОСТУП» один: полос прогресса нет, кнопки в карточке нет, главная нижняя кнопка — «Открыть настройки», крестик закрывает панель. Выдать доступ — экран за 0,2 с сменяется журналом.

- [ ] **Step 6: Приложение: размеры, темы, языки**

Проверка вручную: Потянуть панель до минимума **560 × 360**: крупные сцены уменьшаются, текст слайда не больше трёх строк, на слайде «ДОСТУП» заголовок, строка и подсказка помещаются, карточка ужимается. Растянуть до **900 × 600**: карточка растёт вместе с панелью и упирается в ширину или высоту места, текст в сценах не мылится. Листать слайды: карточка пружинисто перетекает в размер следующей сцены. Переключить систему в **тёмный** режим: поле чёрное, карточка с тонкой обводкой; вернуть **светлый**: светло-серое поле и мягкая тень у карточки. Тема Stash Light или Light: в карточке всё равно стиль Stash — непрозрачные акценты. Меню значка → Язык → **English**: тексты слайдов, меню в сцене «НАСТРОЙКИ», «Next»/«Start» и тексты слайда «ДОСТУП» английские, сцена «КЛАВИШИ» печатает «typ»; вернуть **Русский** — всё перерисовывается на месте, обучение остаётся на своём слайде.

- [ ] **Step 7: Меньше движения**

Проверка вручную: Системные настройки → Универсальный доступ → Дисплей → «Уменьшить движение» включает пользователь. Сцены стоят на стоп-кадрах, тексты меняются без сдвига, карточка меняет размер без пружины, полосы заливаются сразу, первый слайд — сразу собранный логотип. Без этой проверки вживую остаются тесты стоп-кадров.

- [ ] **Step 8: Коммит**

```bash
git add Tests/BufferJournalTests/Scenes/SceneDurationTests.swift
git commit -m "Check every scene's length against its slide"
```

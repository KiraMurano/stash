# Обучение Stash — план реализации

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Сториз-обучение внутри панели журнала: восемь слайдов с живыми сценами из настоящих деталей Stash, показ при первом запуске и пункт «Обучение» в меню значка.

**Architecture:** Обучение — слой `OnboardingView` поверх `JournalView`; им управляет `OnboardingController`: показ, набор слайдов, клавиши, отметка «увидено» в `UserDefaults`. Сцены — SwiftUI-виды на своих холстах по содержимому, карточка обнимает холст; состояние сцены — чистая функция времени (`Track`, `CursorTrack`, `SceneLoop`), кадры даёт `TimelineView`. Всё, что в сцене изображает Stash, — настоящие виды журнала (`EntryRow`, `TypeSegmentedControl`, `ToastOverlay`, кнопки, палитра), которые план выносит из `JournalView.swift` в `Components/`.

**Tech Stack:** Swift 6 (swift-tools-version 6.0, строгая конкурентность), SwiftUI + AppKit, SwiftPM, Swift Testing (Xcode 26), macOS 13+.

## Global Constraints

- Спека: `docs/superpowers/specs/2026-09-19-onboarding-stories-design.md`. Концепт: `.concepts/2026-09-18-onboarding.html`, вариант 1.3.
- Система — от macOS 13: нет `UnitCurve`, `onChange` — старой формы `onChange(of:perform:)`; то, что появилось в macOS 14, — только через `#available`.
- Swift 6: всё, что трогает AppKit, `NSImage` и кэши картинок, живёт на главном акторе.
- Комментарии в коде и коммиты — по-английски, как в репозитории.
- Слова и тексты слайдов — дословно из спеки; в коде они появляются в Task 5 и больше не меняются.
- После каждой задачи: `swift build` и `swift test`. С Task 9 — снимки: `SNAPSHOT_DIR=/tmp/stash-snapshots swift test --filter SnapshotTests`. Приложение: `Scripts/build_app.sh` → `.build/Stash.app`.
- Тестовая сборка делит с установленным Stash настройки (домен `local.buffer-journal`) и папку истории. Установленный Stash на время проверки закрыть.
- Разрешение Универсального доступа выдаёт и снимает только пользователь.
- Весь код ниже собран и проверен: задачи проиграны по порядку на чистой копии репозитория, после каждой `swift build` и `swift test` проходят.

## Карта файлов

| Файл | Ответственность |
|---|---|
| `Package.swift` | тестовая цель `BufferJournalTests` |
| `Sources/BufferJournal/Components/ClipLabels.swift` | подписи строк и правило поиска, общие для журнала и сцен |
| `Sources/BufferJournal/Components/EntryRow.swift`, `TypeSegmentedControl.swift`, `TranslucentButtonStyle.swift`, `GlassIconButton.swift`, `ToastOverlay.swift`, `ThemePalette.swift`, `WindowDragHandle.swift` | виды журнала, вынесенные без изменений; у `EntryRow` — `hoverOverride` |
| `Sources/BufferJournal/Components/EntryThumb.swift`, `SearchFieldChrome.swift`, `SectionHeader.swift` | миниатюра строки, рамка поля поиска, заголовок раздела — для журнала и сцен |
| `Sources/BufferJournal/AppSettings.swift` | `init(defaults:)`, тема по умолчанию Stash Auto |
| `Sources/BufferJournal/Onboarding/OnboardingSlides.swift` | восемь слайдов и правило, когда нужен «ДОСТУП» |
| `Sources/BufferJournal/Onboarding/OnboardingLayout.swift` | масштаб сцены, карточка по сцене, логотип первого слайда |
| `Sources/BufferJournal/Onboarding/SceneEngine.swift` | кривые, дорожки, круг, указатель — время сцены в состояние |
| `Sources/BufferJournal/Onboarding/AccessibilityAccess.swift` | есть ли разрешение и как его попросить |
| `Sources/BufferJournal/Onboarding/OnboardingController.swift` | показ, слайды, клавиши, «увидено» |
| `Sources/BufferJournal/Onboarding/SceneClock.swift` | часы сцены на `TimelineView` |
| `Sources/BufferJournal/Onboarding/OnboardingSceneView.swift` | какая сцена на слайде, её холст и как он встаёт в карточку |
| `Sources/BufferJournal/Onboarding/OnboardingChrome.swift`, `OnboardingView.swift` | рамка обучения: цвета, кнопки, полосы, каркас |
| `Sources/BufferJournal/Onboarding/Scenes/SceneKit.swift`, `DemoClips.swift`, `DemoDetailPane.swift`, `JournalMiniature.swift` | детали сцен и демо-клипы |
| `Sources/BufferJournal/Onboarding/Scenes/*Scene.swift` | восемь сцен |
| `Sources/BufferJournal/JournalView.swift`, `JournalPanelController.swift`, `AppDelegate.swift`, `Localization.swift`, `README.md` | подключение: слой, клавиши, показ при запуске, пункт меню |
| `Tests/BufferJournalTests/…` | логика, стоп-кадры сцен, снимки PNG |

---

### Task 1: Тестовая цель и подписи строк в одном месте

**Files:**
- Modify: `Package.swift` — тестовая цель `BufferJournalTests`
- Create: `Sources/BufferJournal/Components/ClipLabels.swift`
- Modify: `Sources/BufferJournal/JournalView.swift` — `kindTitle`, `rowTitle`, `rowSubtitle`, `pixelSize(of:)`, `timeTitle`, `matches` зовут `ClipLabels`
- Test: `Tests/BufferJournalTests/ClipLabelsTests.swift`

**Interfaces:**
- Produces: тестовая цель `BufferJournalTests` на Swift Testing (`import Testing`, `@testable import BufferJournal`), запуск — `swift test`.
- Produces: `enum ClipLabels` — `kindTitle(_ entry: ClipboardEntry, _ l10n: L10n) -> String`, `rowTitle(_:_:) -> String`, `rowSubtitle(_ entry:, pixelSize: CGSize?, _ l10n:, now: Date = Date()) -> String`, `pixelSizeTitle(_ size: CGSize) -> String`, `timeTitle(_ date: Date, _ l10n: L10n, now: Date = Date()) -> String`, `matches(_ entry:, _ needle: String, pixelSize: CGSize?, _ l10n:) -> Bool`.

- [ ] **Step 1: Тестовая цель**

Заменить `Package.swift` целиком. Тестировать исполняемую цель SwiftPM умеет: `@testable import BufferJournal` работает, `@main` не мешает.

Создать `Package.swift`:

```swift
// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BufferJournal",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "BufferJournal", targets: ["BufferJournal"])
    ],
    targets: [
        .executableTarget(
            name: "BufferJournal",
            path: "Sources/BufferJournal"
        ),
        .testTarget(
            name: "BufferJournalTests",
            dependencies: ["BufferJournal"],
            path: "Tests/BufferJournalTests"
        )
    ]
)
```

- [ ] **Step 2: Тест**

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
        ClipboardEntry(id: UUID(), payload: payload, createdAt: now.addingTimeInterval(-minutesAgo * 60), fingerprint: "test")
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

    @Test func searchMatchesLikeTheJournal() {
        let invoice = entry(.text("Инвойс № 1042 за сентябрь"))
        let image = entry(.image(filename: "x.png"))
        let contract = entry(.file(storedFilename: "a", originalName: "Договор аренды.pdf", byteCount: 10))
        let size = CGSize(width: 1200, height: 800)
        #expect(ClipLabels.matches(invoice, "инв", pixelSize: nil, ru))
        #expect(ClipLabels.matches(image, "и", pixelSize: size, ru))
        #expect(!ClipLabels.matches(image, "ин", pixelSize: size, ru))
        #expect(ClipLabels.matches(image, "1200", pixelSize: size, ru))
        #expect(!ClipLabels.matches(contract, "и", pixelSize: nil, ru))
    }
}
```

- [ ] **Step 3: Запустить — падает**

Run: `swift test --filter ClipLabelsTests`
Expected: FAIL: ошибка сборки `cannot find 'ClipLabels' in scope`.

- [ ] **Step 4: Код**

Функции — дословно из `JournalView.swift`, только `pixelSize` приходит параметром, а «сегодня» можно подставить в тестах.

Создать `Sources/BufferJournal/Components/ClipLabels.swift`:

```swift
import CoreGraphics
import Foundation

/// How journal rows are titled and searched. The journal and the tutorial scenes both use it,
/// so a scene's rows read exactly like the real ones.
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

    /// Search: text by content, images by kind and pixel size, files by name; case and accents ignored.
    static func matches(_ entry: ClipboardEntry, _ needle: String, pixelSize: CGSize?, _ l10n: L10n) -> Bool {
        let haystack: String = switch entry.payload {
        case let .text(text): text
        case .image: kindTitle(entry, l10n) + " " + (pixelSize.map(pixelSizeTitle) ?? "")
        case .file: entry.title(l10n)
        }
        return haystack.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
}
```

- [ ] **Step 5: Запустить — проходит**

Run: `swift test --filter ClipLabelsTests`
Expected: PASS: 5 тестов.

- [ ] **Step 6: Журнал зовёт ClipLabels**

Три замены в `Sources/BufferJournal/JournalView.swift`; остальной журнал продолжает звать свои обёртки.

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

В `Sources/BufferJournal/JournalView.swift` заменить:

```swift
    private func matches(_ entry: ClipboardEntry, _ needle: String) -> Bool {
        let haystack: String = switch entry.payload {
        case let .text(text): text
        case .image: kindTitle(entry) + " " + (pixelSize(of: entry) ?? "")
        case .file: entry.title(l10n)
        }
        return haystack.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
```

на:

```swift
    private func matches(_ entry: ClipboardEntry, _ needle: String) -> Bool {
        ClipLabels.matches(entry, needle, pixelSize: store.pixelSize(for: entry), l10n)
    }
```

- [ ] **Step 7: Сборка и все тесты**

Run: `swift build && swift test`
Expected: `Build complete!`, все тесты PASS.

- [ ] **Step 8: Коммит**

```bash
git add Package.swift Sources/BufferJournal/Components/ClipLabels.swift Sources/BufferJournal/JournalView.swift Tests/BufferJournalTests/ClipLabelsTests.swift
git commit -m "Add a test target and share row labels with the tutorial" -m "Row titles, subtitles, times and search matching move from JournalView into
ClipLabels, so the tutorial's demo rows read exactly like the journal's."
```


### Task 2: Общие виды журнала — в свои файлы

**Files:**
- Create: `Sources/BufferJournal/Components/EntryRow.swift`, `TypeSegmentedControl.swift`, `TranslucentButtonStyle.swift`, `GlassIconButton.swift`, `ToastOverlay.swift`, `ThemePalette.swift`, `WindowDragHandle.swift` — перенос без изменений
- Modify: `Sources/BufferJournal/JournalView.swift` — эти объявления уходят, два `MARK` переименованы

**Interfaces:**
- Produces: `EntryRow`, `TypeSegmentedControl`, `GlassIconButton`, `ToastOverlay`, `WindowDragHandle` видны всему модулю (было `private`), инициализаторы прежние. `ThemePalette` и `TranslucentButtonStyle` переезжают как есть.

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
    ("private struct GlassIconButton: View {", "GlassIconButton.swift"),
    ("private struct ToastOverlay: View {", "ToastOverlay.swift"),
    ("struct ThemePalette {", "ThemePalette.swift"),
    ("private struct WindowDragHandle: NSViewRepresentable {", "WindowDragHandle.swift"),
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

- [ ] **Step 2: Сборка и тесты**

Run: `swift build && swift test`
Expected: Скрипт печатает `moved 7 declarations; …`. `Build complete!`, все тесты PASS.

- [ ] **Step 3: Коммит**

```bash
git add Sources/BufferJournal/Components Sources/BufferJournal/JournalView.swift
git commit -m "Move the journal's reusable views into Components" -m "EntryRow, the type filter, the translucent button style, the glass icon button,
the toast, the palette and the drag handle get their own files, unchanged except
for dropping private, so the tutorial's scenes can use them."
```


### Task 3: Детали для сцен: миниатюра, поле поиска, заголовок раздела, наведение строки

**Files:**
- Create: `Sources/BufferJournal/Components/EntryThumb.swift`, `SearchFieldChrome.swift`, `SectionHeader.swift`
- Modify: `Sources/BufferJournal/Components/EntryRow.swift` — `hoverOverride`, миниатюра через `EntryThumb`
- Modify: `Sources/BufferJournal/JournalView.swift` — заголовки разделов и поле поиска через новые виды

**Interfaces:**
- Produces: `EntryThumb(entry:thumbnail:fileIcon:palette:)` — плитка 42 pt.
- Produces: `SearchFieldChrome(palette:isEditing:showsClear:clearHelp:onClear:field:)` — рамка поля, содержимое — замыкание.
- Produces: `SectionHeader(title:palette:)`.
- Produces: `EntryRow(…, onDelete:, hoverOverride: Bool? = nil)` — последний параметр необязательный, журнал его не передаёт.

- [ ] **Step 1: Три вида**

Код — дословно из `EntryRow.thumb`, `JournalView.searchField` и заголовка раздела в `JournalView.entryList`.

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

Создать `Sources/BufferJournal/Components/SearchFieldChrome.swift`:

```swift
import SwiftUI

/// The search field's frame: magnifier, grey plate, orange ring while editing, and a clear button
/// once there is a query. The journal puts a real TextField inside; the tutorial puts typed text.
struct SearchFieldChrome<Field: View>: View {
    let palette: ThemePalette
    let isEditing: Bool
    let showsClear: Bool
    let clearHelp: String
    let onClear: () -> Void
    @ViewBuilder let field: () -> Field

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(palette.textTertiary)

            field()

            if showsClear {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(palette.textTertiary)
                }
                .buttonStyle(.plain)
                .help(clearHelp)
            }
        }
        .padding(.horizontal, 9)
        .frame(height: 30)
        .background(palette.placeholderBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(isEditing ? ThemePalette.orange : .clear, lineWidth: 1.5)
        )
        .animation(.easeOut(duration: 0.12), value: isEditing)
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

Четыре замены в `Sources/BufferJournal/Components/EntryRow.swift`. Все чтения `isHovered` остаются: теперь это вычисляемое свойство.

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
```

- [ ] **Step 3: Журнал на новых видах**

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

В `Sources/BufferJournal/JournalView.swift` заменить:

```swift
    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(palette.textTertiary)

            TextField(l10n("Search", "Поиск"), text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(palette.textPrimary)
                .focused($isSearchFocused)

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(palette.textTertiary)
                }
                .buttonStyle(.plain)
                .help(l10n("Clear search", "Очистить поиск"))
            }
        }
        .padding(.horizontal, 9)
        .frame(height: 30)
        .background(palette.placeholderBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(isSearchEditing ? ThemePalette.orange : .clear, lineWidth: 1.5)
        )
        .animation(.easeOut(duration: 0.12), value: isSearchEditing)
    }
```

на:

```swift
    private var searchField: some View {
        SearchFieldChrome(
            palette: palette,
            isEditing: isSearchEditing,
            showsClear: !query.isEmpty,
            clearHelp: l10n("Clear search", "Очистить поиск"),
            onClear: { query = "" }
        ) {
            TextField(l10n("Search", "Поиск"), text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(palette.textPrimary)
                .focused($isSearchFocused)
        }
    }
```

- [ ] **Step 4: Сборка и тесты**

Run: `swift build && swift test`
Expected: `Build complete!`, все тесты PASS.

- [ ] **Step 5: Журнал не изменился**

Проверка вручную: Собрать `Scripts/build_app.sh`, открыть `.build/Stash.app`, нажать ⌥V. Наведение на строку показывает кнопки, поле поиска подсвечивается оранжевым, заголовки «Сегодня» и «Закреплённые» на месте — всё как до задачи. Установленный Stash на время проверки закрыть: у сборок общие настройки и история.

- [ ] **Step 6: Коммит**

```bash
git add Sources/BufferJournal/Components Sources/BufferJournal/JournalView.swift
git commit -m "Split out the row thumbnail, search field frame and section header" -m "Rows also take a hover override, so a tutorial scene can show hover without
a mouse. The journal looks and behaves the same."
```


### Task 4: Stash Auto — тема по умолчанию

**Files:**
- Modify: `Sources/BufferJournal/AppSettings.swift` — `init(defaults:)`, тема по умолчанию `.stashAuto`
- Test: `Tests/BufferJournalTests/AppSettingsTests.swift`

**Interfaces:**
- Produces: `AppSettings(defaults: UserDefaults = .standard)` — вызовы без параметра не меняются.

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

- [ ] **Step 2: Запустить — падает**

Run: `swift test --filter AppSettingsTests`
Expected: FAIL: ошибка сборки `extra argument 'defaults' in call`.

- [ ] **Step 3: Код**

Три замены в `Sources/BufferJournal/AppSettings.swift`.

В `Sources/BufferJournal/AppSettings.swift` заменить:

```swift
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
```

на:

```swift
    private let defaults: UserDefaults

    @Published var pasteOnSelection: Bool {
        didSet {
            defaults.set(pasteOnSelection, forKey: Keys.pasteOnSelection)
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

        if defaults
```

на:

```swift
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if defaults
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

- [ ] **Step 5: Коммит**

```bash
git add Sources/BufferJournal/AppSettings.swift Tests/BufferJournalTests/AppSettingsTests.swift
git commit -m "Default to Stash Auto when no theme was picked" -m "Settings also take their UserDefaults from outside, for tests."
```


### Task 5: Слайды

**Files:**
- Create: `Sources/BufferJournal/Onboarding/OnboardingSlides.swift`
- Test: `Tests/BufferJournalTests/OnboardingSlidesTests.swift`

**Interfaces:**
- Produces: `enum OnboardingSceneKind: String, CaseIterable` — `hero, hotKey, paste, pin, images, search, settings, access`.
- Produces: `struct Localized { en, ru; callAsFunction(_ l10n: L10n) -> String }`.
- Produces: `struct OnboardingSlide: Identifiable` — `kind`, `duration: Double`, `loops: Bool`, `word: Localized`, `text: Localized`, `id == kind`.
- Produces: `OnboardingSlides.all` (8 слайдов по спеке) и `OnboardingSlides.visible(includeAccess: Bool) -> [OnboardingSlide]`.

- [ ] **Step 1: Тест**

Создать `Tests/BufferJournalTests/OnboardingSlidesTests.swift`:

```swift
import Testing
@testable import BufferJournal

struct OnboardingSlidesTests {
    @Test func slidesComeInTheSpecOrderWithAccessLast() {
        #expect(OnboardingSlides.all.map(\.kind) == [.hero, .hotKey, .paste, .pin, .images, .search, .settings, .access])
    }

    @Test func wordsAreCapitalsAndTextsFitThreeLines() {
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

    @Test func theAccessSlideIsOptional() {
        #expect(OnboardingSlides.visible(includeAccess: true).count == 8)
        let without = OnboardingSlides.visible(includeAccess: false)
        #expect(without.map(\.kind) == [.hero, .hotKey, .paste, .pin, .images, .search, .settings])
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
    case hero, hotKey, paste, pin, images, search, settings, access
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
    /// Scene length with its end hold, seconds. A looping scene then spends
    /// `SceneLoop.returnTime + SceneLoop.pauseTime` getting back to its first frame.
    let duration: Double
    /// The first slide plays once and stays assembled; the others loop.
    let loops: Bool
    let word: Localized
    let text: Localized

    var id: OnboardingSceneKind { kind }
}

enum OnboardingSlides {
    /// Words and texts are the spec's, verbatim:
    /// docs/superpowers/specs/2026-09-19-onboarding-stories-design.md, "Слайды".
    static let all: [OnboardingSlide] = [
        OnboardingSlide(
            kind: .hero, duration: 2.6, loops: false,
            word: Localized(en: "HELLO", ru: "ПРИВЕТ"),
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
                en: "Hover a clip and click the orange arrow — it's pasted right where your cursor was. Double-click or Return does the same.",
                ru: "Наведите указатель на клип и нажмите оранжевую стрелку — он вставится туда, где стоял курсор. Двойной клик и Return делают то же самое."
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
            kind: .search, duration: 4.2, loops: true,
            word: Localized(en: "SEARCH", ru: "ПОИСК"),
            text: Localized(
                en: "Don't scroll — start typing, and only matching clips stay. ↑↓ select, Return pastes, Esc clears the search.",
                ru: "Не листайте — начните печатать, и останутся только подходящие клипы. Стрелки ↑↓ выбирают, Return вставляет, Esc очищает поиск."
            )
        ),
        OnboardingSlide(
            kind: .settings, duration: 4.6, loops: true,
            word: Localized(en: "SETTINGS", ru: "НАСТРОЙКИ"),
            text: Localized(
                en: "The Stash icon in the menu bar opens settings: paste and close on selection, theme and language. Tutorial replays this tour.",
                ru: "Значок Stash в строке меню открывает настройки: вставку и закрытие журнала при выборе, тему и язык. «Обучение» покажет этот рассказ снова."
            )
        ),
        OnboardingSlide(
            kind: .access, duration: 3.0, loops: true,
            word: Localized(en: "ACCESS", ru: "ДОСТУП"),
            text: Localized(
                en: "Stash pastes by pressing ⌘V for you. Turn it on in Accessibility settings, or clips will only be copied.",
                ru: "Stash вставляет клип, нажимая ⌘V за вас. Для этого включите его в Универсальном доступе, иначе клип только скопируется."
            )
        ),
    ]

    /// The access slide is only for people who need it: paste on selection is on and Stash may
    /// not press ⌘V yet.
    static func visible(includeAccess: Bool) -> [OnboardingSlide] {
        includeAccess ? all : all.filter { $0.kind != .access }
    }
}
```

- [ ] **Step 4: Запустить — проходит**

Run: `swift test --filter OnboardingSlidesTests`
Expected: PASS: 4 теста.

- [ ] **Step 5: Коммит**

```bash
git add Sources/BufferJournal/Onboarding/OnboardingSlides.swift Tests/BufferJournalTests/OnboardingSlidesTests.swift
git commit -m "Tutorial slides: words, texts and durations"
```


### Task 6: Раскладка: масштаб сцены, карточка по сцене, логотип

**Files:**
- Create: `Sources/BufferJournal/Onboarding/OnboardingLayout.swift`
- Test: `Tests/BufferJournalTests/OnboardingLayoutTests.swift`

**Interfaces:**
- Produces: `OnboardingLayout.sceneSize` (480 × 240 — самый большой холст, заглушка до сцен), `sceneScale(_ scene: CGSize, in area: CGSize) -> CGFloat` (во всё место с сохранением пропорций, вверх и вниз), `cardSize(for scene: CGSize, in area: CGSize) -> CGSize`, `struct Lockup { icon, gap, fontSize }`, `heroLockup(in:wordWidthAt28:) -> Lockup`.
- Produces: `@MainActor enum WordmarkMetrics` — `width(size:) -> CGFloat` и `capHeight(size:) -> CGFloat` для «Stash» шрифтом шапки.

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

    @MainActor
    @Test func theWordmarkIsMeasuredInTheHeaderFont() {
        #expect(WordmarkMetrics.width(size: 56) > 2 * WordmarkMetrics.width(size: 27))
        #expect(WordmarkMetrics.capHeight(size: 28) > 15)
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
}

/// The "Stash" wordmark in the heavy system font, as in the journal header.
@MainActor
enum WordmarkMetrics {
    static func width(size: CGFloat) -> CGFloat {
        let font = NSFont.systemFont(ofSize: size, weight: .heavy)
        return ceil(NSAttributedString(string: "Stash", attributes: [.font: font]).size().width)
    }

    static func capHeight(size: CGFloat) -> CGFloat {
        NSFont.systemFont(ofSize: size, weight: .heavy).capHeight
    }
}
```

- [ ] **Step 4: Запустить — проходит**

Run: `swift test --filter OnboardingLayoutTests`
Expected: PASS: 4 теста.

- [ ] **Step 5: Коммит**

```bash
git add Sources/BufferJournal/Onboarding/OnboardingLayout.swift Tests/BufferJournalTests/OnboardingLayoutTests.swift
git commit -m "Tutorial layout: scene scale, card size and the hero lockup"
```


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


### Task 8: Контроллер обучения и доступ

**Files:**
- Create: `Sources/BufferJournal/Onboarding/AccessibilityAccess.swift`, `Sources/BufferJournal/Onboarding/OnboardingController.swift`
- Test: `Tests/BufferJournalTests/OnboardingControllerTests.swift` (в нём же `FakeAccess` для следующих тестов)

**Interfaces:**
- Consumes: `OnboardingSlides.visible(includeAccess:)` (Task 5).
- Produces: `@MainActor protocol AccessibilityAccess: AnyObject { var isTrusted: Bool; func requestAndOpenSettings() }`, `SystemAccessibilityAccess`.
- Produces: `OnboardingController(defaults:access:pasteOnSelection:)`; `@Published private(set)` — `isPresented`, `slides`, `index`, `run`, `hasAccess`; `isReplay`, `shouldShowOnLaunch`, `slide`, `isLast`; `present(replay:)`, `next()`, `back()`, `primaryAction()`, `close()`, `restartScene()`, `requestAccess()`, `refreshAccess()`, `handleKey(_ keyCode: UInt16) -> Bool`; `currentVersion = 1`, `seenVersionKey = "OnboardingSeenVersion"`.
- Produces (тесты): `FakeAccess(trusted:)` — `isTrusted` меняется, `requests` считает нажатия кнопки.

- [ ] **Step 1: Тест**

Создать `Tests/BufferJournalTests/OnboardingControllerTests.swift`:

```swift
import Foundation
import Testing
@testable import BufferJournal

@MainActor
final class FakeAccess: AccessibilityAccess {
    var isTrusted: Bool
    private(set) var requests = 0

    init(trusted: Bool) {
        isTrusted = trusted
    }

    func requestAndOpenSettings() {
        requests += 1
    }
}

@MainActor
struct OnboardingControllerTests {
    private let defaults: UserDefaults = {
        let name = "OnboardingControllerTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }()

    private func make(trusted: Bool = true, paste: Bool = true) -> (OnboardingController, FakeAccess) {
        let access = FakeAccess(trusted: trusted)
        return (OnboardingController(defaults: defaults, access: access, pasteOnSelection: { paste }), access)
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

    @Test func theAccessSlideIsOnlyForThoseWhoNeedIt() {
        let (untrusted, _) = make(trusted: false, paste: true)
        untrusted.present(replay: false)
        #expect(untrusted.slides.count == 8)
        #expect(untrusted.slides.last?.kind == .access)

        let (trusted, _) = make(trusted: true, paste: true)
        trusted.present(replay: false)
        #expect(trusted.slides.count == 7)

        let (noPaste, _) = make(trusted: false, paste: false)
        noPaste.present(replay: false)
        #expect(noPaste.slides.count == 7)
    }

    @Test func theSlideSetStaysWhileOpenAndAccessIsNoticed() {
        let (controller, access) = make(trusted: false)
        controller.present(replay: false)
        access.isTrusted = true
        controller.refreshAccess()
        #expect(controller.hasAccess)
        #expect(controller.slides.count == 8)
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
    }

    @Test func startOnTheLastSlideCloses() {
        let (controller, _) = make()
        controller.present(replay: false)
        for _ in 0..<(controller.slides.count - 1) { controller.primaryAction() }
        #expect(controller.isPresented)
        controller.primaryAction()
        #expect(!controller.isPresented)
    }

    @Test func keysDriveTheTutorialAndOthersAreSwallowed() {
        let (controller, _) = make()
        #expect(!controller.handleKey(124))
        controller.present(replay: false)
        #expect(controller.handleKey(124))
        #expect(controller.index == 1)
        #expect(controller.handleKey(0))
        #expect(controller.index == 1)
        #expect(controller.handleKey(123))
        #expect(controller.index == 0)
        #expect(controller.handleKey(53))
        #expect(!controller.isPresented)
    }

    @Test func theButtonAsksTheSystem() {
        let (controller, access) = make(trusted: false)
        controller.requestAccess()
        #expect(access.requests == 1)
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
Expected: FAIL: ошибка сборки `cannot find type 'AccessibilityAccess' in scope`.

- [ ] **Step 3: Код**

Правила — из спеки, «Кому и когда» и «Слайд «ДОСТУП»». Набор слайдов складывается при открытии и не меняется до закрытия. Увиденным обучение отмечается при закрытии, если это не повтор из меню. Клавиши: → и Return — дальше (на последнем Return — «Начать»), ← — назад, Esc — закрыть; остальные глотаются, чтобы не печатать в поиск под обучением.

Создать `Sources/BufferJournal/Onboarding/AccessibilityAccess.swift`:

```swift
import AppKit
import ApplicationServices

/// Whether Stash may press ⌘V for the person, and a way to ask for it.
@MainActor
protocol AccessibilityAccess: AnyObject {
    var isTrusted: Bool { get }
    /// Puts Stash on the Accessibility list and opens that pane of System Settings.
    func requestAndOpenSettings()
}

@MainActor
final class SystemAccessibilityAccess: AccessibilityAccess {
    static let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!

    var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    func requestAndOpenSettings() {
        // Asking with a prompt is what puts Stash on the list; macOS may show its own alert too.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        NSWorkspace.shared.open(Self.settingsURL)
    }
}
```

Создать `Sources/BufferJournal/Onboarding/OnboardingController.swift`:

```swift
import Combine
import Foundation

/// The tutorial's state: whether it is on screen, which slides this showing has and which one
/// is current. It also remembers that the person has seen it.
@MainActor
final class OnboardingController: ObservableObject {
    /// Bump to show the tutorial to everyone again after a big update.
    static let currentVersion = 1
    static let seenVersionKey = "OnboardingSeenVersion"

    @Published private(set) var isPresented = false
    @Published private(set) var slides: [OnboardingSlide] = OnboardingSlides.visible(includeAccess: false)
    @Published private(set) var index = 0
    /// Grows each time a slide is entered or the panel shows again; scenes restart on a change.
    @Published private(set) var run = 0
    @Published private(set) var hasAccess = false
    /// A showing opened from the menu does not mark the tutorial as seen.
    private(set) var isReplay = false

    private let defaults: UserDefaults
    private let access: AccessibilityAccess
    private let pasteOnSelection: @MainActor () -> Bool

    init(defaults: UserDefaults = .standard, access: AccessibilityAccess, pasteOnSelection: @escaping @MainActor () -> Bool) {
        self.defaults = defaults
        self.access = access
        self.pasteOnSelection = pasteOnSelection
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

    /// Opens the tutorial on its first slide. The slide set stays fixed until it closes.
    func present(replay: Bool) {
        if isPresented {
            // The menu item during the first showing restarts it; closing still marks it seen.
            isReplay = isReplay && replay
        } else {
            isReplay = replay
            hasAccess = access.isTrusted
            slides = OnboardingSlides.visible(includeAccess: !hasAccess && pasteOnSelection())
            isPresented = true
        }
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

    /// "Next", or "Start" on the last slide.
    func primaryAction() {
        if isLast {
            close()
        } else {
            next()
        }
    }

    func close() {
        guard isPresented else { return }
        isPresented = false
        if !isReplay {
            defaults.set(Self.currentVersion, forKey: Self.seenVersionKey)
        }
    }

    /// The panel showed again: the current scene starts over.
    func restartScene() {
        guard isPresented else { return }
        run += 1
    }

    func requestAccess() {
        access.requestAndOpenSettings()
    }

    func refreshAccess() {
        let trusted = access.isTrusted
        if trusted != hasAccess {
            hasAccess = trusted
        }
    }

    /// Keys while the tutorial is open: → and Return go on, ← goes back, Esc closes. Every other
    /// plain key is swallowed so nothing gets typed into the search field underneath.
    func handleKey(_ keyCode: UInt16) -> Bool {
        guard isPresented else { return false }
        switch keyCode {
        case 124: next()
        case 123: back()
        case 36, 76: primaryAction()
        case 53: close()
        default: break
        }
        return true
    }
}
```

- [ ] **Step 4: Запустить — проходит**

Run: `swift test --filter OnboardingControllerTests`
Expected: PASS: 11 тестов.

- [ ] **Step 5: Коммит**

```bash
git add Sources/BufferJournal/Onboarding/AccessibilityAccess.swift Sources/BufferJournal/Onboarding/OnboardingController.swift Tests/BufferJournalTests/OnboardingControllerTests.swift
git commit -m "Tutorial controller: showing, slides, keys and access"
```


### Task 9: Рамка обучения: полосы, карточка по сцене, текст, кнопка

**Files:**
- Create: `Sources/BufferJournal/Onboarding/SceneClock.swift` — часы сцены на `TimelineView`
- Create: `Sources/BufferJournal/Onboarding/OnboardingSceneView.swift` — выбор сцены и её холста; пока сцены `Color.clear`, холсты 480 × 240
- Create: `Sources/BufferJournal/Onboarding/OnboardingChrome.swift` — цвета, кнопки, полоса прогресса
- Create: `Sources/BufferJournal/Onboarding/OnboardingView.swift` — каркас
- Test: `Tests/BufferJournalTests/SnapshotTests.swift` — PNG рамки в трёх размерах панели

**Interfaces:**
- Consumes: `OnboardingController` (Task 8), `OnboardingLayout` (Task 6), `SceneTime`, `SceneLoop` (Task 7), `WindowDragHandle`, `ThemePalette`, `TranslucentButtonStyle` (Task 2), `FakeAccess` (Task 8, тесты).
- Produces: `SceneClock(duration:loops:still:content:)`; `OnboardingSceneView(slide:still:)`, `static func size(of: OnboardingSceneKind) -> CGSize?` (у первого слайда `nil`) и `static func canvas(for:at:in:) -> some View`.
- Produces: `OnboardingColors(isDark:)` — `field`, `close`, `text`, `barFill`, `barTrack`, `cardShadow`, `wordmark`, `button(_ level: Int)`; `OnboardingPrimaryButtonStyle`, `OnboardingCloseButtonStyle`, `OnboardingProgressBar`.
- Produces: `OnboardingView(controller:l10n:)`.
- Produces (тесты): `SnapshotTests.render(_:name:)`, `SnapshotTests.schemes`, `controller(on:)`.

- [ ] **Step 1: Часы сцены**

Сцена играет с момента появления: `TimelineView(.animation)` даёт время, `SceneLoop` превращает его в круг. «Меньше движения» и слайд «ДОСТУП» с полученным доступом держат стоп-кадр. Сцена без круга перестаёт просить кадры, когда доиграла.

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

    @State private var start = Date()
    @State private var finished = false

    var body: some View {
        if still || finished {
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
```

- [ ] **Step 2: Выбор сцены**

Каждая сцена — отдельная задача ниже; до неё её место занимает `Color.clear`, а холст — 480 × 240. У сцен 2–8 свой холст по содержимому, он растёт или уменьшается во всё свободное место с сохранением пропорций. У первого слайда холста нет. `size` и `canvas` открыты для рамки и тестов-снимков.

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
    /// canvas: it lays its logo out by whatever room it gets.
    static func size(of kind: OnboardingSceneKind) -> CGSize? {
        switch kind {
        case .hero: nil
        case .hotKey: OnboardingLayout.sceneSize
        case .paste: OnboardingLayout.sceneSize
        case .pin: OnboardingLayout.sceneSize
        case .images: OnboardingLayout.sceneSize
        case .search: OnboardingLayout.sceneSize
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
        case .search: Color.clear
        case .settings: Color.clear
        case .access: Color.clear
        }
    }
}
```

- [ ] **Step 3: Цвета и кнопки рамки**

Цвета — таблица «Цвета» из спеки: светло-серое поле или чёрное, оранжевые полосы и кнопка, «Stash» первого слайда — оранжевым иконки.

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

    /// The main button, orange in both looks; `level` is 0 at rest, 1 hovered, 2 pressed.
    func button(_ level: Int) -> Color {
        ThemePalette.darken(ThemePalette.orange, by: 0.08 * Double(min(max(level, 0), 2)))
    }
}

/// "Next" / "Start": an orange capsule that darkens on hover and press, like the journal's buttons.
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
```

- [ ] **Step 4: Каркас**

Сверху вниз: строка из полос (3 pt, зазор 4) и крестика, место для карточки, текст рядом с кнопкой 150 × 36. Отступы 12 / 20 / 16, между блоками 10. Слова-заголовка нет, слово слайда — только заголовок для VoiceOver. Карточка занимает всю ширину или всю высоту свободного места и обнимает сцену; стоит по центру и при смене слайда пружинисто перетекает в размер следующей. Тексты всех восьми слайдов лежат друг на друге, виден один — высота низа не прыгает. Клик по левым 30 % ниже шапки — назад, по остальному — вперёд; строка с полосами двигает окно.

Создать `Sources/BufferJournal/Onboarding/OnboardingView.swift`:

```swift
import AppKit
import SwiftUI

/// The tutorial: stories over the whole journal panel. Progress bars and the close cross on top,
/// the scene in a card that hugs it, and the text beside the main button at the bottom.
struct OnboardingView: View {
    @ObservedObject var controller: OnboardingController
    let l10n: L10n

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

                zones(width: geometry.size.width, top: Metrics.top + Metrics.headHeight)

                VStack(spacing: 0) {
                    head
                    stage
                        .padding(.top, Metrics.gap)
                    footer
                        .padding(.top, Metrics.gap)
                }
                .padding(.top, Metrics.top)
                .padding(.horizontal, Metrics.side)
                .padding(.bottom, Metrics.bottom)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(l10n("Stash tour", "Знакомство со Stash"))
        .accessibilityAddTraits(.isModal)
        .onChange(of: controller.index) { index in
            announce(index)
        }
    }

    // MARK: Head

    private var head: some View {
        HStack(spacing: 12) {
            bars
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
        // The slide's name, for VoiceOver only: the scene itself says nothing to it.
        .accessibilityElement(children: .contain)
        .accessibilityLabel(controller.slide.word(l10n).capitalized)
        .accessibilityAddTraits(.isHeader)
    }

    private var isStill: Bool {
        reduceMotion || (controller.slide.kind == .access && controller.hasAccess)
    }

    // MARK: Footer

    private var footer: some View {
        HStack(alignment: .center, spacing: 16) {
            texts
            Button {
                controller.primaryAction()
            } label: {
                Text(controller.isLast ? l10n("Start", "Начать") : l10n("Next", "Дальше"))
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: Metrics.buttonWidth, height: Metrics.buttonHeight)
            }
            .buttonStyle(OnboardingPrimaryButtonStyle(colors: colors))
        }
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

    private func announce(_ index: Int) {
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

- [ ] **Step 5: Тест-снимок**

Тесты рисуют обучение в PNG через `ImageRenderer`. Без `SNAPSHOT_DIR` они только проверяют, что всё рисуется.

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

    private func controller(on kind: OnboardingSceneKind) -> OnboardingController {
        let defaults = UserDefaults(suiteName: "SnapshotTests-\(UUID().uuidString)")!
        let controller = OnboardingController(defaults: defaults, access: FakeAccess(trusted: false), pasteOnSelection: { true })
        controller.present(replay: true)
        while controller.slide.kind != kind { controller.next() }
        return controller
    }

    /// The whole tutorial on three slides, at the panel's smallest, default and a large size.
    @Test func tutorialFrame() throws {
        for (scheme, name) in Self.schemes {
            for kind in [OnboardingSceneKind.hero, .search, .access] {
                for size in [CGSize(width: 560, height: 360), CGSize(width: 640, height: 440), CGSize(width: 900, height: 600)] {
                    let view = OnboardingView(controller: controller(on: kind), l10n: L10n(language: .russian))
                        .frame(width: size.width, height: size.height)
                        .environment(\.colorScheme, scheme)
                    try render(view, name: "frame-\(kind.rawValue)-\(Int(size.width))-\(name)")
                }
            }
        }
    }
}

```

- [ ] **Step 6: Сборка, тесты, снимки**

Run: `swift build && swift test`
Expected: `Build complete!`, все тесты PASS.

Run: `SNAPSHOT_DIR=/tmp/stash-snapshots swift test --filter SnapshotTests`
Expected: PASS; в `/tmp/stash-snapshots` 18 файлов `frame-<слайд>-<ширина>-<тема>.png`.

- [ ] **Step 7: Посмотреть снимки**

Проверка вручную: Открыть `frame-search-640-light.png` и `frame-search-640-dark.png`. Светлый: светло-серое поле, оранжевые полосы (шесть полных) и крестик в одной строке, пустая светлая карточка — холст-заглушка 480 × 240, растянутый во всю ширину места, — с обводкой и мягкой тенью, текст слева, оранжевая капсула «Дальше». Тёмный: чёрное поле, карточка с тонкой обводкой. Жёлтая полоса с перечёркнутым кругом поверх строки с полосами — так `ImageRenderer` рисует AppKit-ручку перетаскивания; в приложении её не видно. На `frame-*-560-*` и `frame-*-900-*` карточка так же упирается в свободное место. На `frame-hero-*` карточки нет.

- [ ] **Step 8: Коммит**

```bash
git add Sources/BufferJournal/Onboarding Tests/BufferJournalTests/SnapshotTests.swift
git commit -m "Tutorial frame: bars, card and footer" -m "The stories layout from the concept, without the title word: the card hugs its
scene. Not wired into the app yet; scenes are placeholders until their commits."
```


### Task 10: Подключение: журнал, панель, меню, README

**Files:**
- Modify: `Sources/BufferJournal/Localization.swift` — `StatusMenuTitles`
- Modify: `Sources/BufferJournal/JournalView.swift` — слой обучения поверх всего, клавиши сначала обучению
- Modify: `Sources/BufferJournal/JournalPanelController.swift` — `showOnboarding(replay:)`, перезапуск сцены при показе панели
- Modify: `Sources/BufferJournal/AppDelegate.swift` — контроллер, показ при запуске, пункт «Обучение»
- Modify: `README.md`

**Interfaces:**
- Consumes: `OnboardingController`, `SystemAccessibilityAccess` (Task 8), `OnboardingView` (Task 9).
- Produces: `StatusMenuTitles(l10n:)` — `openStash`, `tutorial`, `pasteOnSelection`, `closeAfterSelection`, `theme`, `language`, `clearHistory`, `quit`. Меню значка и сцена «НАСТРОЙКИ» (Task 18) берут названия отсюда.
- Produces: `JournalPanelController(store:writer:settings:onboarding:)`, `showOnboarding(replay: Bool)`; `JournalView(store:settings:onboarding:…)`.

- [ ] **Step 1: Названия пунктов меню в одном месте**

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
    var pasteOnSelection: String { l10n("Paste on Selection", "Вставлять при выборе") }
    var closeAfterSelection: String { l10n("Close After Selection", "Закрывать после выбора") }
    var theme: String { l10n("Theme", "Тема") }
    var language: String { l10n("Language", "Язык") }
    var clearHistory: String { l10n("Clear History", "Очистить историю") }
    var quit: String { l10n("Quit", "Выйти") }
}

private struct SolidAccentsKey: EnvironmentKey {
```

- [ ] **Step 2: Журнал: слой обучения и клавиши**

Обучение лежит в том же `ZStack`, что диалоги и тост, над ними (`zIndex(40)`), и потому обрезается скруглением панели. Пока оно открыто, все клавиши без ⌘ ⌃ ⌥ идут ему.

В `Sources/BufferJournal/JournalView.swift` заменить:

```swift
    @ObservedObject var settings: AppSettings
```

на:

```swift
    @ObservedObject var settings: AppSettings
    @ObservedObject var onboarding: OnboardingController
```

В `Sources/BufferJournal/JournalView.swift` заменить:

```swift
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(30)
            }
```

на:

```swift
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(30)
            }

            if onboarding.isPresented {
                OnboardingView(controller: onboarding, l10n: l10n)
                    .transition(.opacity)
                    .zIndex(40)
            }
```

В `Sources/BufferJournal/JournalView.swift` заменить:

```swift
        .animation(.easeOut(duration: 0.16), value: entryPendingDeletion)
```

на:

```swift
        .animation(.easeOut(duration: 0.16), value: entryPendingDeletion)
        .animation(.easeOut(duration: 0.2), value: onboarding.isPresented)
```

В `Sources/BufferJournal/JournalView.swift` заменить:

```swift
    private func handleKey(_ event: NSEvent) -> Bool {
```

на:

```swift
    private func handleKey(_ event: NSEvent) -> Bool {
        // The tutorial covers the journal and takes every plain key while it is open.
        if onboarding.isPresented {
            return onboarding.handleKey(event.keyCode)
        }

```

- [ ] **Step 3: Панель**

В `Sources/BufferJournal/JournalPanelController.swift` заменить:

```swift
    private let settings: AppSettings
    private var panel: NSPanel?
```

на:

```swift
    private let settings: AppSettings
    private let onboarding: OnboardingController
    private var panel: NSPanel?
```

В `Sources/BufferJournal/JournalPanelController.swift` заменить:

```swift
    init(store: ClipboardHistoryStore, writer: ClipboardWriter, settings: AppSettings) {
        self.store = store
        self.writer = writer
        self.settings = settings
    }
```

на:

```swift
    init(store: ClipboardHistoryStore, writer: ClipboardWriter, settings: AppSettings, onboarding: OnboardingController) {
        self.store = store
        self.writer = writer
        self.settings = settings
        self.onboarding = onboarding
    }
```

В `Sources/BufferJournal/JournalPanelController.swift` заменить:

```swift
    func show() {
        let panel = makePanelIfNeeded()
```

на:

```swift
    /// Opens the tutorial on its first slide, showing the panel if it is hidden.
    func showOnboarding(replay: Bool) {
        onboarding.present(replay: replay)
        if panel?.isVisible != true {
            show()
        }
    }

    func show() {
        // A tutorial left open when the panel was hidden starts its scene over.
        onboarding.restartScene()
        let panel = makePanelIfNeeded()
```

В `Sources/BufferJournal/JournalPanelController.swift` заменить:

```swift
            store: store,
            settings: settings,
            onSelect:
```

на:

```swift
            store: store,
            settings: settings,
            onboarding: onboarding,
            onSelect:
```

- [ ] **Step 4: Приложение и меню**

Пункт «Обучение» — сразу под «Открыть Stash»: оба открывают панель, а «Очистить историю» очищает без подтверждения, и промах стоил бы истории.

В `Sources/BufferJournal/AppDelegate.swift` заменить:

```swift
    private var settings: AppSettings!
```

на:

```swift
    private var settings: AppSettings!
    private var onboarding: OnboardingController!
```

В `Sources/BufferJournal/AppDelegate.swift` заменить:

```swift
        settings = AppSettings()
        panelController = JournalPanelController(store: store, writer: writer, settings: settings)
```

на:

```swift
        let settings = AppSettings()
        self.settings = settings
        onboarding = OnboardingController(
            access: SystemAccessibilityAccess(),
            pasteOnSelection: { settings.pasteOnSelection }
        )
        panelController = JournalPanelController(store: store, writer: writer, settings: settings, onboarding: onboarding)
```

В `Sources/BufferJournal/AppDelegate.swift` заменить:

```swift
        monitor.start()
        hotKeyController.register()
    }
```

на:

```swift
        monitor.start()
        hotKeyController.register()

        if onboarding.shouldShowOnLaunch {
            panelController.showOnboarding(replay: false)
        }
    }
```

В `Sources/BufferJournal/AppDelegate.swift` заменить:

```swift
        let l10n = settings.l10n
        let menu = NSMenu()
        menu.addItem(menuItem(l10n("Open Stash", "Открыть Stash"), action: #selector(openJournal)))
        menu.addItem(NSMenuItem.separator())

        pasteOnSelectionItem = menuItem(l10n("Paste on Selection", "Вставлять при выборе"), action: #selector(togglePasteOnSelection))
        menu.addItem(pasteOnSelectionItem)

        closeAfterSelectionItem = menuItem(l10n("Close After Selection", "Закрывать после выбора"), action: #selector(toggleCloseAfterSelection))
        menu.addItem(closeAfterSelectionItem)

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

        pasteOnSelectionItem = menuItem(titles.pasteOnSelection, action: #selector(togglePasteOnSelection))
        menu.addItem(pasteOnSelectionItem)

        closeAfterSelectionItem = menuItem(titles.closeAfterSelection, action: #selector(toggleCloseAfterSelection))
        menu.addItem(closeAfterSelectionItem)

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

- [ ] **Step 5: README**

В `README.md` заменить:

```markdown
- Menu settings can also paste immediately after selection, close the journal after selection, and switch theme and interface language (System, English, Русский).
```

на:

```markdown
- Menu settings can also paste immediately after selection, close the journal after selection, and switch theme and interface language (System, English, Русский).
- A short tour opens inside the journal on first launch; Tutorial in the menu bar menu plays it again. The default theme is Stash Auto.
```

- [ ] **Step 6: Сборка и тесты**

Run: `swift build && swift test`
Expected: `Build complete!`, все тесты PASS.

- [ ] **Step 7: Проверить в приложении**

Проверка вручную: Закрыть установленный Stash. `Scripts/build_app.sh`, затем `defaults delete local.buffer-journal OnboardingSeenVersion` и `open .build/Stash.app`. Панель открывается сама, на ней обучение: «ПРИВЕТ», полосы, пустые карточки. → и Return листают вперёд, ← назад, клик слева назад, справа вперёд; буквы не печатаются в поиск под обучением. Esc закрывает обучение, под ним журнал; второй Esc закрывает панель. Перезапуск — обучение само не открывается. В меню значка «Обучение» под «Открыть Stash» — открывает с первого слайда. ⌥V посреди обучения прячет панель; следующий ⌥V — тот же слайд.

- [ ] **Step 8: Коммит**

```bash
git add Sources/BufferJournal/Localization.swift Sources/BufferJournal/JournalView.swift Sources/BufferJournal/JournalPanelController.swift Sources/BufferJournal/AppDelegate.swift README.md
git commit -m "Show the tutorial on first launch and from the menu" -m "The tutorial lies over the journal and takes plain keys while open. A Tutorial
item under Open Stash plays it again without marking anything."
```


### Task 11: Набор для сцен: указатель, клавиши, окна, демо-клипы, панель превью

**Files:**
- Create: `Sources/BufferJournal/Onboarding/Scenes/SceneKit.swift`
- Create: `Sources/BufferJournal/Onboarding/Scenes/DemoClips.swift`
- Create: `Sources/BufferJournal/Onboarding/Scenes/DemoDetailPane.swift`
- Test: `Tests/BufferJournalTests/DemoClipsTests.swift`; Modify: `Tests/BufferJournalTests/SnapshotTests.swift` — снимки всех сцен

**Interfaces:**
- Consumes: `EntryRow`, `EntryThumb`, `GlassIconButton`, `TranslucentButtonStyle`, `ThemePalette` (Tasks 2–3), `ClipLabels` (Task 1), `CursorState`, `ClickRipple`, `SceneTime` (Task 7), `Localized` (Task 5).
- Produces: `ThemePalette.scene(_ colorScheme:)`, `listSurface`, `detailSurface`; `SceneCursor(state:)`, `SceneRipple(ripple:)`, `SceneKeycap(label:secondary:caption:size:pressed:)`, `SceneWindow(title:palette:content:)`, `TrafficLights()`, `SceneTextLine(width:palette:)`, `SceneCaret(height:visible:)` и `SceneCaret.isVisible(at:duration:)`, `PhotoArt(style: .mountains | .sunset)`.
- Produces: `DemoClip { id, entry, thumbnail, fileIcon, pixelSize; pinned(_:), matches(_:_:) }`, `DemoClips.text(_:_:_:at:_:)`, `DemoClips.image(_:_:pixelSize:at:_:)`, `DemoClips.file(_:_:bytes:_:at:_:)`, `DemoImages.thumbnail(_:)`, `DemoImages.pdfIcon`, `DemoRow(clip:isSelected:isHovered:palette:)`, `AnyTransition.journalRow`, `DemoDetailPane(clip:photo:palette:)`.

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

Демо-клип — настоящая `ClipboardEntry` и то, что для неё дал бы журнал: миниатюра, значок файла, размер в пикселях. Строка сцены — настоящий `EntryRow` с подписями из `ClipLabels`. Личность клипа одна и та же из кадра в кадр, иначе строки теряли бы состояние.

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

    func matches(_ query: String, _ l10n: L10n) -> Bool {
        ClipLabels.matches(entry, query, pixelSize: pixelSize, l10n)
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
            quickPasteTitle: l10n("Paste", "Вставить"),
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

Карточки нет, логотип стоит на поле и ничем не обрезается. Это связка из шапки журнала (иконка 32 : шрифт 28 : зазор 2), увеличенная до 80 % ширины или высоты области; слово выровнено по заглавным, как в шапке. Иконка поднимается на 24 pt и проявляется (0–0,45 с). Три плитки строк журнала — текст, фото, PDF — в две трети иконки вылетают из трёх углов (0,3, 0,48, 0,66 с) и за 0,45 с по дуге с разгоном падают в иконку сверху: кувыркаются, уменьшаются, тянут шлейф из четырёх бледнеющих копий и уходят за иконку (плитки лежат слоем под логотипом). Удар — белая вспышка по иконке и приплющивание от низа с отскоком; последний в 1,6 раза сильнее и встряхивает логотип, и «Stash» выезжает из-за иконки (1,12–1,66 с). Волн и искр нет. Играет один раз.

Создать `Sources/BufferJournal/Onboarding/Scenes/HeroScene.swift`:

```swift
import AppKit
import SwiftUI

/// ПРИВЕТ: no card. The Stash icon rises. A text, a photo and a PDF, as journal row tiles, swoop
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

    private static let iconOpacity = Track(0.0).to(1, at: 0, until: 0.35, .easeOut)
    private static let iconRise = Track(24.0).to(0, at: 0, until: 0.45, .easeOut)
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
        let lockup = OnboardingLayout.heroLockup(in: area, wordWidthAt28: WordmarkMetrics.width(size: 28))
        let wordWidth = WordmarkMetrics.width(size: lockup.fontSize)
        let capHeight = WordmarkMetrics.capHeight(size: lockup.fontSize)
        let left = (area.width - (lockup.icon + lockup.gap + wordWidth)) / 2
        let icon = CGPoint(x: left + lockup.icon / 2, y: area.height / 2)
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
            .frame(width: area.width, height: area.height)
            .offset(x: state.shake)
        }
        .frame(width: area.width, height: area.height)
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

Проверка вручную: `scene-hero-mid-ru-light.png` — последняя плитка со шлейфом ныряет в иконку, иконка ещё светлее после второго удара. `scene-hero-end-ru-light.png` — иконка и «Stash» оранжевым иконки на светло-сером; `…-dark.png` — на чёрном. В тестах у процесса нет иконки Stash, поэтому на снимке значок папки; в приложении — иконка Stash.

- [ ] **Step 7: Коммит**

```bash
git add Sources/BufferJournal/Onboarding/Scenes/HeroScene.swift Sources/BufferJournal/Onboarding/OnboardingSceneView.swift Tests/BufferJournalTests/Scenes/HeroSceneTests.swift
git commit -m "Tutorial scene: hello"
```


### Task 13: Сцена «ВЫЗОВ»

**Files:**
- Create: `Sources/BufferJournal/Onboarding/Scenes/JournalMiniature.swift`
- Create: `Sources/BufferJournal/Onboarding/Scenes/HotKeyScene.swift`
- Modify: `Sources/BufferJournal/Onboarding/OnboardingSceneView.swift` — `case .hotKey`
- Test: `Tests/BufferJournalTests/Scenes/HotKeySceneTests.swift`

**Interfaces:**
- Consumes: набор для сцен (Task 11), `Track`, `CursorTrack`, `SceneTime` (Task 7), `Localized` (Task 5).
- Produces: `HotKeyScene(time:)`, `HotKeyScene.duration`, `HotKeyScene.size`, `HotKeyScene.State`, `HotKeyScene.state(at: SceneTime) -> State`.
- Produces: `JournalMiniature(palette:)` — журнал 640 × 440 без стекла.

- [ ] **Step 1: Тест стоп-кадра**

Создать `Tests/BufferJournalTests/Scenes/HotKeySceneTests.swift`:

```swift
import CoreGraphics
import Testing
@testable import BufferJournal

/// The stop frame from the spec's "Сцены" section and the moments that lead to it.
@MainActor
struct HotKeySceneTests {
    @Test func hotKeyEndsWithTheJournalOverTheWindowAndKeysUp() {
        let end = HotKeyScene.state(at: .end(of: HotKeyScene.duration))
        #expect(end.journal == 1)
        #expect(!end.optionDown && !end.vDown)
        let pressed = HotKeyScene.state(at: SceneTime(t: 0.55, rewind: 0))
        #expect(pressed.optionDown && pressed.vDown)
    }
}
```

- [ ] **Step 2: Запустить — падает**

Run: `swift test --filter HotKeySceneTests`
Expected: FAIL: ошибка сборки `cannot find 'HotKeyScene' in scope`.

- [ ] **Step 3: Сцена**

Слева клавиши ⌥ option и V; в русском интерфейсе на V вторая буква «М», как на русской клавиатуре Mac: сочетание работает по положению клавиши. Справа окно «Документ» со строками и мигающей точкой вставки. ⌥ нажимается (0,3 с), следом V (0,5 с); поверх окна проявляется журнал с увеличением от 0,96 (0,6–0,9 с); клавиши отпускаются (1,0 с). Журнал — `JournalMiniature`: весь журнал 640 × 440 из его же частей (шапка с иконкой и счётчиком, поле поиска, фильтр, строки, панель превью), уменьшенный до 0,4.

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
                    Text("3/20")
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

                SearchFieldChrome(palette: palette, isEditing: false, showsClear: false, clearHelp: "", onClear: {}) {
                    Text(l10n("Search", "Поиск"))
                        .font(.system(size: 13))
                        .foregroundStyle(palette.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 8)

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

/// ВЫЗОВ: ⌥ and V go down on a Mac keyboard, and the journal appears over another app's window.
struct HotKeyScene: View {
    static let duration = 2.6
    /// Two keys, and another app's window with the journal over it.
    static let size = CGSize(width: 470, height: 234)

    struct State: Equatable {
        var optionDown: Bool
        var vDown: Bool
        /// 0…1: the journal appearing over the window.
        var journal: Double
    }

    private static let option = Track(false).set(true, at: 0.3).set(false, at: 1.0)
    private static let v = Track(false).set(true, at: 0.5).set(false, at: 1.02)
    private static let journal = Track(0.0).to(1, at: 0.6, until: 0.9, .easeOut)

    static func state(at time: SceneTime) -> State {
        State(optionDown: option.value(at: time), vDown: v.value(at: time), journal: journal.value(at: time))
    }

    /// The journal is shown at this share of its real size, so it fits over the window.
    static let miniatureScale: CGFloat = 0.4

    let time: SceneTime

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.l10n) private var l10n

    var body: some View {
        let state = Self.state(at: time)
        let palette = ThemePalette.scene(colorScheme)
        let journalSize = CGSize(
            width: JournalView.Layout.width * Self.miniatureScale,
            height: JournalView.Layout.height * Self.miniatureScale
        )

        ZStack(alignment: .topLeading) {
            SceneKeycap(label: "⌥", caption: "option", pressed: state.optionDown)
                .offset(x: 12, y: 85)
            // On a Russian keyboard V also carries "М"; the shortcut works by key, in any layout.
            SceneKeycap(label: "V", secondary: l10n.language == .russian ? "М" : nil, pressed: state.vDown)
                .offset(x: 88, y: 85)

            SceneWindow(title: l10n("Document", "Документ"), palette: palette) {
                VStack(alignment: .leading, spacing: 9) {
                    SceneTextLine(width: 180, palette: palette)
                    SceneTextLine(width: 230, palette: palette)
                    SceneTextLine(width: 150, palette: palette)
                    SceneTextLine(width: 205, palette: palette)
                    HStack(spacing: 4) {
                        SceneTextLine(width: 90, palette: palette)
                        SceneCaret(height: 13, visible: SceneCaret.isVisible(at: time, duration: Self.duration))
                    }
                }
                .padding(16)
            }
            .frame(width: 290, height: 210)
            .offset(x: 168, y: 12)

            JournalMiniature(palette: palette)
                .scaleEffect(Self.miniatureScale)
                .frame(width: journalSize.width, height: journalSize.height)
                .shadow(color: palette.shadow(0.3), radius: 14, y: 8)
                .scaleEffect(0.96 + 0.04 * state.journal)
                .opacity(state.journal)
                .offset(x: 313 - journalSize.width / 2, y: 117 - journalSize.height / 2)
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

Проверка вручную: `scene-hotKey-end-ru-light.png` — две клавиши слева, над окном «Документ» маленький журнал: оранжевая выбранная строка, фильтр «Все», справа текст клипа и оранжевая «Вставить». На V в русской версии видна «М», в английской нет.

- [ ] **Step 7: Коммит**

```bash
git add Sources/BufferJournal/Onboarding/Scenes/JournalMiniature.swift Sources/BufferJournal/Onboarding/Scenes/HotKeyScene.swift Sources/BufferJournal/Onboarding/OnboardingSceneView.swift Tests/BufferJournalTests/Scenes/HotKeySceneTests.swift
git commit -m "Tutorial scene: open with ⌥V"
```


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
    @Test func pasteEndsPastedWithTheArrowOnTheButton() {
        let end = PasteScene.state(at: .end(of: PasteScene.duration))
        #expect(end.selectedRow == 1)
        #expect(end.hoveredRow == 1)
        #expect(end.toast)
        #expect(end.pasted == 1)
        #expect(end.cursor.tip == PasteScene.returnButton)
        #expect(end.cursor.opacity == 1)
        let beforeClick = PasteScene.state(at: SceneTime(t: 1.4, rewind: 0))
        #expect(beforeClick.selectedRow == nil)
        #expect(!beforeClick.toast)
    }
}
```

- [ ] **Step 2: Запустить — падает**

Run: `swift test --filter PasteSceneTests`
Expected: FAIL: ошибка сборки `cannot find 'PasteScene' in scope`.

- [ ] **Step 3: Сцена**

Слева «Сегодня» из трёх строк — картинка, текст «Счёт за сентябрь № 1042», PDF; справа окно «Письмо» с точкой вставки. Указатель заходит на строку с текстом: подсветка наведения, кнопки строки, текст гаснет под ними (0,3–0,8 с). Указатель на оранжевой стрелке, клик (1,5 с): строка выбрана, стрелка белая с оранжевым значком, тост «Вставлено», в письме появляется текст клипа (1,6–2,0 с).

Создать `Sources/BufferJournal/Onboarding/Scenes/PasteScene.swift`:

```swift
import SwiftUI

/// ВСТАВКА: the arrow hovers a text clip, clicks its orange arrow; the row is selected, the toast
/// says "Pasted", and the clip's text lands at the insertion point of a letter next to the list.
struct PasteScene: View {
    static let duration = 3.6
    /// The list, and the letter to its right.
    static let size = CGSize(width: 470, height: 236)

    struct State: Equatable {
        var cursor: CursorState
        var ripple: ClickRipple?
        var hoveredRow: Int?
        var selectedRow: Int?
        var toast: Bool
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
    private static let toast = Track(false).set(true, at: 1.6)
    private static let pasted = Track(0.0).to(1, at: 1.75, until: 2.0, .easeOut)

    static func state(at time: SceneTime) -> State {
        State(
            cursor: cursor.state(at: time),
            ripple: cursor.ripple(at: time),
            hoveredRow: hovered.value(at: time),
            selectedRow: selected.value(at: time),
            toast: toast.value(at: time),
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

            if state.toast {
                ToastOverlay(message: l10n("Pasted", "Вставлено"))
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .position(x: 135, y: 212)
            }

            SceneWindow(title: l10n("Letter", "Письмо"), palette: palette) {
                letter(state, palette: palette)
            }
            .frame(width: 186, height: 212)
            .offset(x: 274, y: 10)

            SceneRipple(ripple: state.ripple)
            SceneCursor(state: state.cursor)
        }
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
        .animation(.easeOut(duration: 0.16), value: state.toast)
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

Проверка вручную: `scene-paste-mid-ru-light.png` — строка с наведением и тремя кнопками, указатель на оранжевой стрелке. `scene-paste-end-ru-light.png` — строка оранжевая, стрелка белая, внизу списка «Вставлено», в письме «Счёт за сентябрь № 1042» и точка вставки после него.

- [ ] **Step 7: Коммит**

```bash
git add Sources/BufferJournal/Onboarding/Scenes/PasteScene.swift Sources/BufferJournal/Onboarding/OnboardingSceneView.swift Tests/BufferJournalTests/Scenes/PasteSceneTests.swift
git commit -m "Tutorial scene: paste"
```


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


### Task 17: Сцена «ПОИСК»

**Files:**
- Create: `Sources/BufferJournal/Onboarding/Scenes/SearchScene.swift`
- Modify: `Sources/BufferJournal/Onboarding/OnboardingSceneView.swift` — `case .search`
- Test: `Tests/BufferJournalTests/Scenes/SearchSceneTests.swift`

**Interfaces:**
- Consumes: набор для сцен (Task 11), `Track`, `CursorTrack`, `SceneTime` (Task 7), `Localized` (Task 5).
- Produces: `SearchScene(time:)`, `SearchScene.duration`, `SearchScene.size`, `SearchScene.State`, `SearchScene.state(at: SceneTime) -> State`.

- [ ] **Step 1: Тест стоп-кадра**

Создать `Tests/BufferJournalTests/Scenes/SearchSceneTests.swift`:

```swift
import CoreGraphics
import Testing
@testable import BufferJournal

/// The stop frame from the spec's "Сцены" section and the moments that lead to it.
@MainActor
struct SearchSceneTests {
    @Test func searchEndsOnTheSecondInvoiceWithTheToast() {
        let end = SearchScene.state(at: .end(of: SearchScene.duration))
        #expect(end.typed == 3)
        #expect(end.movedDown)
        #expect(end.toast)
        #expect(!end.downPressed && !end.returnPressed)
    }

    @Test func searchFiltersByTheJournalsRule() {
        for language in [ResolvedLanguage.russian, .english] {
            let l10n = L10n(language: language)
            let clips = [
                DemoClips.file("lease", Localized(en: "Lease agreement.pdf", ru: "Договор аренды.pdf"), bytes: 1, l10n, at: 14, 31),
                DemoClips.text("sep", Localized(en: "Invoice #1042 for September", ru: "Инвойс № 1042 за сентябрь"), l10n, at: 13, 47),
                DemoClips.image("photo", .mountains, pixelSize: CGSize(width: 1200, height: 800), at: 12, 20),
                DemoClips.text("aug", Localized(en: "Invoice for August, paid", ru: "Инвойс за август, оплачен"), l10n, at: 9, 12),
            ]
            let query = SearchScene.query(l10n)
            let afterFirst = clips.filter { $0.matches(String(query.prefix(1)), l10n) }.map(\.id)
            let afterAll = clips.filter { $0.matches(query, l10n) }.map(\.id)
            #expect(afterFirst == ["sep", "photo", "aug"], "\(language)")
            #expect(afterAll == ["sep", "aug"], "\(language)")
        }
    }
}
```

- [ ] **Step 2: Запустить — падает**

Run: `swift test --filter SearchSceneTests`
Expected: FAIL: ошибка сборки `cannot find 'SearchScene' in scope`.

- [ ] **Step 3: Сцена**

Указателя нет: мышь не нужна. Поле поиска в фокусе — оранжевая обводка, как при открытии журнала. Под ним «Договор аренды.pdf», «Инвойс № 1042 за сентябрь», картинка, «Инвойс за август, оплачен»; выбрана первая строка. Буквы «и», «н», «в» появляются через 0,2 с (0,4–0,8 с), список фильтруется правилом журнала (`ClipLabels.matches`): после «и» уходит договор, после «н» — картинка, выбор — на первом подходящем. Клавиша ↓ (1,6 с) — выбран второй инвойс; ⏎ (2,3 с) — тост «Вставлено». В журнале список при поиске меняется мгновенно, в сцене — за 0,2 с, чтобы глаз успел проследить.

Создать `Sources/BufferJournal/Onboarding/Scenes/SearchScene.swift`:

```swift
import SwiftUI

/// ПОИСК: no pointer. The search field already has focus; «инв» is typed a letter at a time and
/// the list filters by the journal's own rule. ↓ moves to the second invoice, ⏎ pastes it.
struct SearchScene: View {
    static let duration = 4.2
    /// The list with its search field, and the two keys to its right.
    static let size = CGSize(width: 344, height: 246)

    struct State: Equatable {
        /// Letters of the query typed so far.
        var typed: Int
        var downPressed: Bool
        var returnPressed: Bool
        /// ↓ has moved the selection to the second match.
        var movedDown: Bool
        var toast: Bool
    }

    static let query = Localized(en: "inv", ru: "инв")

    private static let typed = Track(0).set(1, at: 0.4).set(2, at: 0.6).set(3, at: 0.8)
    private static let down = Track(false).set(true, at: 1.6).set(false, at: 1.72)
    private static let movedDown = Track(false).set(true, at: 1.64)
    private static let enter = Track(false).set(true, at: 2.3).set(false, at: 2.42)
    private static let toast = Track(false).set(true, at: 2.35)

    static func state(at time: SceneTime) -> State {
        State(
            typed: typed.value(at: time),
            downPressed: down.value(at: time),
            returnPressed: enter.value(at: time),
            movedDown: movedDown.value(at: time),
            toast: toast.value(at: time)
        )
    }

    let time: SceneTime

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.l10n) private var l10n

    var body: some View {
        let state = Self.state(at: time)
        let palette = ThemePalette.scene(colorScheme)
        let query = String(Self.query(l10n).prefix(state.typed))
        let visible = query.isEmpty ? clips : clips.filter { $0.matches(query, l10n) }
        // The journal's rule: no explicit choice means the first visible clip is selected.
        let selected = state.movedDown && visible.count > 1 ? visible[1].id : visible.first?.id

        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                SearchFieldChrome(palette: palette, isEditing: true, showsClear: !query.isEmpty, clearHelp: "", onClear: {}) {
                    HStack(spacing: 1) {
                        if query.isEmpty {
                            SceneCaret(height: 15, visible: SceneCaret.isVisible(at: time, duration: Self.duration))
                            Text(l10n("Search", "Поиск"))
                                .foregroundStyle(palette.textTertiary)
                        } else {
                            Text(query)
                                .foregroundStyle(palette.textPrimary)
                            SceneCaret(height: 15, visible: SceneCaret.isVisible(at: time, duration: Self.duration))
                        }
                        Spacer(minLength: 0)
                    }
                    .font(.system(size: 13))
                }
                .padding(.top, 10)
                .padding(.bottom, 6)

                SectionHeader(title: l10n("Today", "Сегодня"), palette: palette)
                ForEach(visible) { clip in
                    DemoRow(clip: clip, isSelected: clip.id == selected, palette: palette)
                        .transition(.journalRow)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            // Top-aligned: four rows are taller than the scene, and the field must stay in view.
            .frame(width: 270, height: Self.size.height, alignment: .top)
            .clipped()
            .animation(.easeOut(duration: 0.2), value: visible.map(\.id))

            SceneKeycap(label: "↓", size: 44, pressed: state.downPressed)
                .offset(x: 290, y: 96)
            SceneKeycap(label: "⏎", size: 44, pressed: state.returnPressed)
                .offset(x: 290, y: 152)

            if state.toast {
                ToastOverlay(message: l10n("Pasted", "Вставлено"))
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .position(x: 135, y: 222)
            }
        }
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
        .clipped()
        .animation(.easeOut(duration: 0.16), value: state.toast)
    }

    private var clips: [DemoClip] {
        [
            DemoClips.file("search-lease", Localized(en: "Lease agreement.pdf", ru: "Договор аренды.pdf"), bytes: 860_000, l10n, at: 14, 31),
            DemoClips.text("search-invoice-sep", Localized(en: "Invoice #1042 for September", ru: "Инвойс № 1042 за сентябрь"), l10n, at: 13, 47),
            DemoClips.image("search-photo", .mountains, pixelSize: CGSize(width: 1200, height: 800), at: 12, 20),
            DemoClips.text("search-invoice-aug", Localized(en: "Invoice for August, paid", ru: "Инвойс за август, оплачен"), l10n, at: 9, 12),
        ]
    }
}
```

- [ ] **Step 4: Сцена на своём слайде**

В `Sources/BufferJournal/Onboarding/OnboardingSceneView.swift` заменить:

```swift
        case .search: OnboardingLayout.sceneSize
```

на:

```swift
        case .search: SearchScene.size
```

В `Sources/BufferJournal/Onboarding/OnboardingSceneView.swift` заменить:

```swift
        case .search: Color.clear
```

на:

```swift
        case .search: SearchScene(time: time)
```

- [ ] **Step 5: Запустить — проходит**

Run: `swift test --filter SearchSceneTests`
Expected: PASS.

Run: `swift build && swift test`
Expected: `Build complete!`, все тесты PASS.

- [ ] **Step 6: Посмотреть снимки**

Run: `SNAPSHOT_DIR=/tmp/stash-snapshots swift test --filter SnapshotTests`
Expected: PASS.

Проверка вручную: `scene-search-end-ru-light.png` — в поле «инв» и кнопка очистки, два инвойса, второй оранжевый, клавиши ↓ и ⏎ справа, «Вставлено» внизу. В английской версии «inv» и два «Invoice…».

- [ ] **Step 7: Коммит**

```bash
git add Sources/BufferJournal/Onboarding/Scenes/SearchScene.swift Sources/BufferJournal/Onboarding/OnboardingSceneView.swift Tests/BufferJournalTests/Scenes/SearchSceneTests.swift
git commit -m "Tutorial scene: search"
```


### Task 18: Сцена «НАСТРОЙКИ»

**Files:**
- Create: `Sources/BufferJournal/Onboarding/Scenes/SettingsScene.swift`
- Modify: `Sources/BufferJournal/Onboarding/OnboardingSceneView.swift` — `case .settings`
- Test: `Tests/BufferJournalTests/Scenes/SettingsSceneTests.swift`

**Interfaces:**
- Consumes: набор для сцен (Task 11), `Track`, `CursorTrack`, `SceneTime` (Task 7), `Localized` (Task 5).
- Produces: `SettingsScene(time:)`, `SettingsScene.duration`, `SettingsScene.size`, `SettingsScene.State`, `SettingsScene.state(at: SceneTime) -> State`.
- Consumes: `StatusMenuTitles` (Task 10), `L10n.themeName(_:)`.
- Produces: `SettingsScene.menuOrigin`, `menuWidth`, `submenuWidth`, `submenuOrigin`, `rowHeight`, `separatorHeight`, `menuPadding`, `frame(of:)` — геометрия меню для тестов.

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
        let onTheme = SettingsScene.state(at: SceneTime(t: 2.3, rewind: 0))
        #expect(onTheme.highlighted == .theme)
    }

    @Test func theSubmenuOpensToTheRightInsideTheScene() {
        let submenu = SettingsScene.submenuOrigin
        #expect(submenu.x >= SettingsScene.menuOrigin.x + SettingsScene.menuWidth - 8)
        #expect(submenu.x + SettingsScene.submenuWidth <= SettingsScene.size.width)
        // Seven rows and a separator, with the menu's padding.
        let height = 6 * SettingsScene.rowHeight + SettingsScene.separatorHeight + 2 * SettingsScene.menuPadding
        #expect(submenu.y + height <= SettingsScene.size.height)
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

Сверху правый край строки меню — только трей: слева значок Stash (настоящий ресурс `StatusIcon` в своих 14 × 18 pt; в тестах — запасной символ, как в `AppDelegate`), справа системные значки и часы. Указатель жмёт значок (0,9 с): значок подсвечен, под ним выпадает меню в составе из Task 10. Указатель идёт по «Вставлять при выборе» (с галочкой) и «Закрывать после выбора», встаёт на «Тему» — справа открывается подменю тем с галочкой у Stash Auto (1,9–2,6 с) — и поднимается к «Обучению» (2,7–3,2 с). Подсветка — системный акцент, и она всегда у пункта под указателем, как в настоящем меню. По пунктам сцена не кликает: клик закрыл бы меню. Меню открыто по флагу, а не по плавной дорожке: на возврате круга оно закрывается сразу, и указатель по дороге к началу ничего не подсвечивает.

Создать `Sources/BufferJournal/Onboarding/Scenes/SettingsScene.swift`:

```swift
import AppKit
import SwiftUI

/// НАСТРОЙКИ: the menu bar tray. The arrow clicks the Stash icon; the menu drops down under it and
/// the arrow walks over the settings, rests on Theme to open its submenu on the right, and ends on
/// Tutorial.
struct SettingsScene: View {
    static let duration = 4.6
    /// The tray end of the menu bar, the menu under the Stash icon and the theme submenu beside it.
    static let size = CGSize(width: 380, height: 280)

    enum Item: CaseIterable, Equatable, Sendable {
        case openStash, tutorial, pasteOnSelection, closeAfterSelection, theme, language, clearHistory, quit
    }

    struct State: Equatable {
        var cursor: CursorState
        var ripple: ClickRipple?
        var iconHighlighted: Bool
        var menuOpen: Bool
        var highlighted: Item?
    }

    // Geometry, in scene points. The Stash icon opens the tray; a real menu hangs from its status
    // item's left edge, and a submenu opens to the right when there is room.
    static let statusIcon = CGPoint(x: 25, y: 12)
    static let menuOrigin = CGPoint(x: 8, y: 26)
    static let menuWidth: CGFloat = 210
    static let submenuWidth: CGFloat = 150
    static let rowHeight: CGFloat = 22
    static let separatorHeight: CGFloat = 9
    static let menuPadding: CGFloat = 5

    /// Menu rows top to bottom; nil is a separator.
    static let rows: [Item?] = [.openStash, .tutorial, nil, .pasteOnSelection, .closeAfterSelection, .theme, .language, nil, .clearHistory, .quit]

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

    private static func center(of item: Item) -> CGPoint {
        CGPoint(x: menuOrigin.x + 90, y: frame(of: item).midY)
    }

    private static let click = 0.9

    private static let cursor = CursorTrack(
        tip: Track(CGPoint(x: 300, y: 262))
            .to(statusIcon, at: 0.3, until: 0.8)
            .to(center(of: .pasteOnSelection), at: 1.2, until: 1.45)
            .to(center(of: .closeAfterSelection), at: 1.5, until: 1.65)
            .to(center(of: .theme), at: 1.75, until: 1.9)
            .to(center(of: .tutorial), at: 2.7, until: 3.2),
        opacity: Track(0.0).to(1, at: 0.15, until: 0.35),
        clicks: [click]
    )
    private static let iconHighlighted = Track(false).set(true, at: click)
    private static let menuOpen = Track(false).set(true, at: click + 0.05)

    static func state(at time: SceneTime) -> State {
        let cursor = cursor.state(at: time)
        let menuOpen = menuOpen.value(at: time)
        // Like a real menu, the highlight is whatever item is under the arrow. While the loop goes
        // back to its start the menu is closed, so the arrow passing over it lights nothing up.
        let highlighted = menuOpen ? Item.allCases.first { frame(of: $0).contains(cursor.tip) } : nil
        return State(
            cursor: cursor,
            ripple: Self.cursor.ripple(at: time),
            iconHighlighted: iconHighlighted.value(at: time),
            menuOpen: menuOpen,
            highlighted: highlighted
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
                    menuRow(title: title(of: row, titles), checked: row == .pasteOnSelection, submenu: row == .theme || row == .language,
                            shortcut: row == .quit ? "⌘Q" : nil, highlighted: state.highlighted == row, palette: palette)
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
        .font(.system(size: 13))
        .foregroundStyle(highlighted ? Color.white : palette.textPrimary)
        .padding(.horizontal, 10)
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
        case .pasteOnSelection: titles.pasteOnSelection
        case .closeAfterSelection: titles.closeAfterSelection
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

Проверка вручную: `scene-settings-mid-ru-light.png` — меню под значком, «Тема» подсвечена, справа подменю с «✓ Stash Auto». `scene-settings-end-ru-light.png` — подменю закрыто, подсвечено «Обучение», галочка у «Вставлять при выборе».

- [ ] **Step 7: Коммит**

```bash
git add Sources/BufferJournal/Onboarding/Scenes/SettingsScene.swift Sources/BufferJournal/Onboarding/OnboardingSceneView.swift Tests/BufferJournalTests/Scenes/SettingsSceneTests.swift
git commit -m "Tutorial scene: settings"
```


### Task 19: Сцена «ДОСТУП»

**Files:**
- Create: `Sources/BufferJournal/Onboarding/Scenes/AccessScene.swift`
- Modify: `Sources/BufferJournal/Onboarding/OnboardingSceneView.swift` — `case .access`
- Test: `Tests/BufferJournalTests/Scenes/AccessSceneTests.swift`

**Interfaces:**
- Consumes: набор для сцен (Task 11), `Track`, `CursorTrack`, `SceneTime` (Task 7), `Localized` (Task 5).
- Produces: `AccessScene(time:)`, `AccessScene.duration`, `AccessScene.size`, `AccessScene.State`, `AccessScene.state(at: SceneTime) -> State`.

- [ ] **Step 1: Тест стоп-кадра**

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
}
```

- [ ] **Step 2: Запустить — падает**

Run: `swift test --filter AccessSceneTests`
Expected: FAIL: ошибка сборки `cannot find 'AccessScene' in scope`.

- [ ] **Step 3: Сцена**

Окно «Системных настроек» занимает верх сцены: слева разделы, выделен «Конфиденциальность и безопасность»; справа «Универсальный доступ» — строка Stash с выключенным переключателем, под списком «+» и «−». Указатель подходит к переключателю и включает его (1,2 с): рычажок переезжает, дорожка окрашивается системным акцентом. Низ сцены свободен под настоящую кнопку карточки.

Создать `Sources/BufferJournal/Onboarding/Scenes/AccessScene.swift`:

```swift
import AppKit
import SwiftUI

/// ДОСТУП: System Settings open on Privacy & Security → Accessibility; the arrow switches Stash on.
/// The bottom of the scene stays free for the card's real "Open Settings" button.
struct AccessScene: View {
    static let duration = 3.0
    /// The System Settings window, and room under it for the card's real button.
    static let size = CGSize(width: 460, height: 236)

    struct State: Equatable {
        var cursor: CursorState
        var ripple: ClickRipple?
        var isOn: Bool
    }

    /// The Stash switch: window x 10…450, content pane from x 160, list row centred at y 106.
    static let toggle = CGPoint(x: 410, y: 106)
    private static let click = 1.2

    private static let cursor = CursorTrack(
        tip: Track(CGPoint(x: 390, y: 240)).to(toggle, at: 0.3, until: 1.0),
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
                    .frame(width: 150)
                    .background(palette.listSurface)
                content(state, palette: palette)
                    .background(palette.modalBackground)
            }
            .frame(width: 440, height: 174)
            .clipShape(shape)
            .overlay(shape.strokeBorder(palette.border, lineWidth: 1))
            .shadow(color: palette.shadow(0.18), radius: 16, y: 8)
            .offset(x: 10, y: 10)

            SceneRipple(ripple: state.ripple)
            SceneCursor(state: state.cursor)
        }
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
    }

    private func sidebar(palette: ThemePalette) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            TrafficLights()
                .padding(.bottom, 8)
            settingsItem("wifi", l10n("Wi‑Fi", "Wi‑Fi"), color: .blue, selected: false, palette: palette)
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
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
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

- [ ] **Step 5: Кнопка «Открыть настройки» в карточке**

Две замены в `Sources/BufferJournal/Onboarding/OnboardingView.swift`. Кнопка — единственное, что в карточке нажимается; стиль — акцентная кнопка журнала. Пока слайд на экране, раз в секунду проверяется доступ; как только он есть, кнопка растворяется в «✓ Доступ включён», а сцена встаёт на стоп-кадр (`isStill` уже учитывает `hasAccess`).

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

            if controller.slide.kind == .access {
                accessButton
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 10)
            }
        }
```

В `Sources/BufferJournal/Onboarding/OnboardingView.swift` заменить:

```swift
    private var isStill: Bool {
```

на:

```swift
    /// The one thing in a card that can be pressed. Once access is granted it turns into a note.
    private var accessButton: some View {
        ZStack {
            if controller.hasAccess {
                Label(l10n("Access granted", "Доступ включён"), systemImage: "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)
                    .frame(height: 32)
                    .transition(.opacity)
            } else {
                Button {
                    controller.requestAccess()
                } label: {
                    Text(l10n("Open Settings", "Открыть настройки"))
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 16)
                        .frame(height: 32)
                }
                .buttonStyle(TranslucentButtonStyle(tone: .accent, cornerRadius: 8))
                .transition(.opacity)
            }
        }
        .environment(\.solidAccents, true)
        .animation(.easeOut(duration: 0.2), value: controller.hasAccess)
        // While the slide is on screen, check once a second whether access has been granted.
        .task(id: controller.run) {
            while !Task.isCancelled {
                controller.refreshAccess()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    private var isStill: Bool {
```

- [ ] **Step 6: Запустить — проходит**

Run: `swift test --filter AccessSceneTests`
Expected: PASS.

Run: `swift build && swift test`
Expected: `Build complete!`, все тесты PASS.

- [ ] **Step 7: Посмотреть снимки**

Run: `SNAPSHOT_DIR=/tmp/stash-snapshots swift test --filter SnapshotTests`
Expected: PASS.

Проверка вручную: `scene-access-end-ru-light.png` — переключатель у Stash включён, указатель на нём. `frame-access-640-light.png` — под сценой оранжевая кнопка «Открыть настройки», внизу «Начать».

- [ ] **Step 8: Коммит**

```bash
git add Sources/BufferJournal/Onboarding/Scenes/AccessScene.swift Sources/BufferJournal/Onboarding/OnboardingSceneView.swift Tests/BufferJournalTests/Scenes/AccessSceneTests.swift Sources/BufferJournal/Onboarding/OnboardingView.swift
git commit -m "Tutorial scene: accessibility access"
```


### Task 20: Финальная проверка

**Files:**
- Test: `Tests/BufferJournalTests/Scenes/SceneDurationTests.swift`

**Interfaces:**
- Consumes: все сцены (Tasks 12–19), `OnboardingSlides.all` (Task 5).

- [ ] **Step 1: Длительности сцен и слайдов совпадают**

Создать `Tests/BufferJournalTests/Scenes/SceneDurationTests.swift`:

```swift
import CoreGraphics
import Testing
@testable import BufferJournal

/// Every scene is as long as its slide says.
@MainActor
struct SceneDurationTests {
    @Test func sceneDurationsMatchTheSlides() {
        let durations: [OnboardingSceneKind: Double] = [
            .hero: HeroScene.duration, .hotKey: HotKeyScene.duration, .paste: PasteScene.duration, .pin: PinScene.duration,
            .images: ImagesScene.duration, .search: SearchScene.duration, .settings: SettingsScene.duration, .access: AccessScene.duration,
        ]
        for slide in OnboardingSlides.all {
            #expect(durations[slide.kind] == slide.duration, "\(slide.kind)")
        }
    }
}
```

- [ ] **Step 2: Все тесты и снимки**

Run: `swift build && swift test`
Expected: `Build complete!`, все тесты PASS.

Run: `SNAPSHOT_DIR=/tmp/stash-snapshots swift test --filter SnapshotTests`
Expected: PASS; 18 снимков рамки и 64 снимка сцен.

- [ ] **Step 3: Приложение: первый запуск и повтор**

Проверка вручную: Закрыть установленный Stash. `Scripts/build_app.sh`; `defaults delete local.buffer-journal OnboardingSeenVersion`; `open .build/Stash.app`. Пройти все слайды: на каждом сцена играет, доигрывает, за 0,5 с возвращается к началу, после паузы повторяется; первый слайд играет один раз — плитки падают в иконку Stash, она вспыхивает и приплющивается, после третьего удара выезжает «Stash». Полоса текущего слайда заливается за 0,3 с и стоит. «Начать» на последнем закрывает обучение, после перезапуска оно само не открывается. «Обучение» в меню — снова с первого слайда.

- [ ] **Step 4: Приложение: размеры, темы, языки**

Проверка вручную: Потянуть панель до минимума (560 × 360): крупные сцены уменьшаются, текст не больше трёх строк. Растянуть: карточка растёт вместе с панелью и упирается в ширину или высоту места, текст в сценах не мылится. Листать слайды: карточка перетекает в размер следующей сцены. Переключить систему в тёмный режим: поле чёрное. В меню значка Язык → English: тексты английские. Тема Stash Light или Light: в карточке всё равно стиль Stash — непрозрачные акценты.

- [ ] **Step 5: Приложение: доступ**

Проверка вручную: Если у сборки нет разрешения Универсального доступа, последний слайд — «ДОСТУП». «Открыть настройки» открывает Универсальный доступ; после включения Stash на слайде появляется «✓ Доступ включён». Выдаёт и снимает разрешение пользователь: системные настройки безопасности агент не трогает. С разрешением слайда нет, последний — «НАСТРОЙКИ».

- [ ] **Step 6: Меньше движения**

Проверка вручную: Системные настройки → Универсальный доступ → Дисплей → «Уменьшить движение» включает пользователь. Сцены стоят на стоп-кадрах, слова меняются без сдвига, полосы заливаются сразу. Без этой проверки вживую остаются тесты стоп-кадров.

- [ ] **Step 7: Коммит**

```bash
git add Tests/BufferJournalTests/Scenes/SceneDurationTests.swift
git commit -m "Check every scene's length against its slide"
```


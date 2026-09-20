# Автообновление Stash — план реализации

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stash сам замечает новую версию на GitHub, показывает её заметки на экране внутри панели и по кнопке скачивает, проверяет подпись, ставит и перезапускается — не теряя Универсальный доступ.

**Architecture:** Слой обновления живёт в `Sources/BufferJournal/Updates/` и делится на чистые части (`AppVersion`, `ReleaseFeed`, `ReleaseNotes`, `UpdateSchedule`, `UpdateEnvironment`) и части с внешним миром за протоколами (`UpdateChecking`, `UpdateDownloading`). Над ними стоит `UpdateController` — `ObservableObject` с конечным набором состояний, на который смотрят экран `UpdateView` и меню значка. Подмену приложения делает отвязанный bash-скрипт: приложение не может переписать само себя на ходу. Подпись проверяется дважды — в приложении до выхода и в скрипте на скопированном бандле, — требованием `StashUpdateRequirement`, которое `build_app.sh` кладёт в `Info.plist` при релизной сборке.

**Tech Stack:** Swift 6 (swift-tools-version 6.0, строгая конкурентность), SwiftUI + AppKit, `URLSession` (async/await), `Process` (`codesign`, `hdiutil`, `ditto`), SwiftPM, Swift Testing, macOS 13+.

## Global Constraints

- Спека: `docs/superpowers/specs/2026-09-20-auto-update-design.md`. Концепт: `.concepts/2026-09-20-update-screen.html`, выбраны варианты **1.2.1.2** (оранжевая палка 12×3 у пункта) и **2.1.2** (точка бейджа наполовину на углу значка).
- Отправная точка: `main` после коммита `f0eb8d8`.
- Система — от macOS 13: `onChange` только старой формы `onChange(of:perform:)`; то, что появилось позже, — через `#available`.
- Swift 6: всё, что трогает AppKit и `NSStatusItem`, живёт на главном акторе. Протоколы `UpdateChecking` и `UpdateDownloading` — `Sendable`, их реализации не держат изменяемого состояния. Колбэки `Timer` входят в актор через `MainActor.assumeIsolated`.
- Комментарии в коде и сообщения коммитов — по-английски, как во всём репозитории.
- Тексты интерфейса — только через `L10n`, двумя языками: `l10n("English", "Русский")`.
- Адрес ленты: `https://api.github.com/repos/KiraMurano/stash/releases/latest`. Имя ассета: `Stash-<версия>.dmg`. Идентификатор бандла: `local.buffer-journal`.
- Ключи `UserDefaults`: `CheckForUpdatesAutomatically`, `LastUpdateCheck`, `SeenUpdateVersion`.
- Ключ `Info.plist`: `StashUpdateRequirement`. Нет ключа или версия `0.0` — приложение считает себя сборкой из исходников и не проверяет обновления вовсе.
- Сетевые запросы в тестах запрещены. `UpdateChecking` и `UpdateDownloading` в тестах подменяются; настоящая загрузка проверяется на `file://`, который `URLSession` умеет.
- После каждой задачи: `swift build` и `swift test`. Приложение: `Scripts/build_app.sh` → `.build/Stash.app`.
- Тестовая сборка делит с установленным Stash домен настроек (`local.buffer-journal`). Тесты берут свой домен `UserDefaults(suiteName:)`, как в `AppSettingsTests`.
- Задача 12 меняет подпись приложения. До неё `Scripts/build_app.sh` продолжает собирать ad hoc, и апдейтер в такой сборке молчит — это ожидаемо, а не поломка.

## Карта файлов

| Файл | Ответственность |
|---|---|
| `Sources/BufferJournal/Updates/AppVersion.swift` | разбор и сравнение `МАЖОР.МИНОР` |
| `Sources/BufferJournal/Updates/ReleaseFeed.swift` | `Release` и разбор ответа GitHub |
| `Sources/BufferJournal/Updates/ReleaseNotes.swift` | разбор текста релиза на пункты и абзацы |
| `Sources/BufferJournal/Updates/UpdateEnvironment.swift` | что приложение знает о себе: версия, требование подписи, свой каталог, право на запись |
| `Sources/BufferJournal/Updates/UpdateSchedule.swift` | «пора ли проверять», переключатель автопроверки, отметка времени |
| `Sources/BufferJournal/Updates/UpdateChecking.swift` | протокол и запрос к ленте GitHub |
| `Sources/BufferJournal/Updates/UpdateDownloading.swift` | протокол и загрузка DMG с прогрессом |
| `Sources/BufferJournal/Updates/Codesign.swift` | проверка подписи требованием, чтение designated requirement |
| `Sources/BufferJournal/Updates/UpdateInstaller.swift` | текст скрипта подмены, его окружение, запуск |
| `Sources/BufferJournal/Updates/UpdateFailureMarker.swift` | файл-маркер о неудавшейся установке |
| `Sources/BufferJournal/Updates/UpdateController.swift` | состояния, расписание, бейдж, показ экрана |
| `Sources/BufferJournal/Updates/UpdateView.swift` | экран обновления в панели |
| `Sources/BufferJournal/Updates/StatusItemBadge.swift` | оранжевая точка поверх значка в строке меню |
| `Sources/BufferJournal/Localization.swift` | тексты экрана и пунктов меню |
| `Sources/BufferJournal/JournalKeys.swift` | `PanelContent.update` |
| `Sources/BufferJournal/JournalView.swift` | слой `UpdateView` над журналом |
| `Sources/BufferJournal/JournalPanelController.swift` | показ экрана обновления, клавиши, клики мимо |
| `Sources/BufferJournal/AppDelegate.swift` | пункты меню, бейдж, взвод проверки, маркер неудачи |
| `Scripts/build_app.sh` | подпись идентичностью и ключ `StashUpdateRequirement` |
| `Scripts/make_dmg.sh` | подпись собранного образа |
| `Scripts/release.sh` | обязательный файл заметок |
| `docs/releases/` | заметки к выпускам |
| `README.md` | как создать сертификат, как работает обновление |
| `Tests/BufferJournalTests/Updates*` | тесты всех частей выше |

---

### Task 1: Версия приложения

**Files:**
- Create: `Sources/BufferJournal/Updates/AppVersion.swift`
- Test: `Tests/BufferJournalTests/AppVersionTests.swift`

**Interfaces:**
- Consumes: ничего.
- Produces: `struct AppVersion: Equatable, Comparable, CustomStringConvertible` с `init?(_ string: String)`, полями `major: Int`, `minor: Int` и `description` вида `"1.27"`.

- [ ] **Step 1: Написать падающий тест**

`Tests/BufferJournalTests/AppVersionTests.swift`:

```swift
import Testing
@testable import BufferJournal

struct AppVersionTests {
    @Test func readsAPlainVersion() {
        #expect(AppVersion("1.27") == AppVersion(major: 1, minor: 27))
    }

    @Test func readsATagWithItsLetter() {
        #expect(AppVersion("v1.27") == AppVersion(major: 1, minor: 27))
    }

    @Test func trimsSurroundingSpace() {
        #expect(AppVersion(" v1.27\n") == AppVersion(major: 1, minor: 27))
    }

    @Test func refusesWhatIsNotAVersion() {
        #expect(AppVersion("") == nil)
        #expect(AppVersion("latest") == nil)
        #expect(AppVersion("1") == nil)
        #expect(AppVersion("1.2.3") == nil)
        #expect(AppVersion("v1.x") == nil)
    }

    @Test func comparesTheMajorFirst() {
        #expect(AppVersion("0.25")! < AppVersion("1.26")!)
        #expect(AppVersion("1.26")! > AppVersion("0.99")!)
    }

    @Test func comparesTheMinorWithinTheMajor() {
        #expect(AppVersion("1.26")! < AppVersion("1.27")!)
        #expect(!(AppVersion("1.27")! < AppVersion("1.27")!))
    }

    @Test func printsItselfBack() {
        #expect(AppVersion("v1.27")!.description == "1.27")
    }
}
```

- [ ] **Step 2: Прогнать тест и убедиться, что он падает**

Run: `swift test --filter AppVersionTests`
Expected: FAIL, `cannot find 'AppVersion' in scope`.

- [ ] **Step 3: Написать минимальную реализацию**

`Sources/BufferJournal/Updates/AppVersion.swift`:

```swift
import Foundation

/// Stash's version: MAJOR.MINOR, where MAJOR is set by hand in the VERSION file and MINOR is a
/// running release counter that never resets (0.25 → 1.26). Both numbers are compared, so a new
/// MAJOR wins even when its MINOR is somehow smaller.
struct AppVersion: Equatable, Comparable, CustomStringConvertible {
    let major: Int
    let minor: Int

    init(major: Int, minor: Int) {
        self.major = major
        self.minor = minor
    }

    /// Takes "1.27" and the tag form "v1.27"; anything else is not a version.
    init?(_ string: String) {
        var text = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("v") || text.hasPrefix("V") {
            text.removeFirst()
        }

        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 2, let major = Int(parts[0]), let minor = Int(parts[1]) else { return nil }

        self.init(major: major, minor: minor)
    }

    var description: String {
        "\(major).\(minor)"
    }

    static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        (lhs.major, lhs.minor) < (rhs.major, rhs.minor)
    }
}
```

- [ ] **Step 4: Прогнать тест и убедиться, что он проходит**

Run: `swift test --filter AppVersionTests`
Expected: PASS, 7 тестов.

- [ ] **Step 5: Коммит**

```bash
git add Sources/BufferJournal/Updates/AppVersion.swift Tests/BufferJournalTests/AppVersionTests.swift
git commit -m "Read and compare app versions"
```

---

### Task 2: Лента релизов и разбор заметок

**Files:**
- Create: `Sources/BufferJournal/Updates/ReleaseFeed.swift`, `Sources/BufferJournal/Updates/ReleaseNotes.swift`
- Test: `Tests/BufferJournalTests/ReleaseFeedTests.swift`, `Tests/BufferJournalTests/ReleaseNotesTests.swift`

**Interfaces:**
- Consumes: `AppVersion` (Task 1).
- Produces:
  - `struct Release: Equatable, Sendable` с полями `version: AppVersion`, `notes: String`, `dmgURL: URL`, `size: Int64`.
  - `enum ReleaseFeed { static func parse(_ data: Data) -> Release? }`.
  - `struct ReleaseNote: Equatable, Identifiable` с `id: Int`, `kind: Kind` (`.item` / `.paragraph`), `text: String`; `enum ReleaseNotes { static func parse(_ body: String) -> [ReleaseNote] }`.

- [ ] **Step 1: Написать падающие тесты ленты**

`Tests/BufferJournalTests/ReleaseFeedTests.swift`:

```swift
import Foundation
import Testing
@testable import BufferJournal

struct ReleaseFeedTests {
    /// Ответ GitHub, обрезанный до полей, которые читает Stash.
    private func json(tag: String = "v1.27", assets: String = Self.dmgAsset) -> Data {
        Data("""
        {
          "tag_name": "\(tag)",
          "name": "Stash 1.27",
          "body": "- Журнал открывается у курсора.\\n- Stash обновляется сам.",
          "assets": [\(assets)]
        }
        """.utf8)
    }

    private static let dmgAsset = """
    {
      "name": "Stash-1.27.dmg",
      "size": 4404019,
      "browser_download_url": "https://github.com/KiraMurano/stash/releases/download/v1.27/Stash-1.27.dmg"
    }
    """

    @Test func readsVersionNotesAndTheImage() throws {
        let release = try #require(ReleaseFeed.parse(json()))
        #expect(release.version == AppVersion(major: 1, minor: 27))
        #expect(release.size == 4_404_019)
        #expect(release.dmgURL.lastPathComponent == "Stash-1.27.dmg")
        #expect(release.notes.contains("Stash обновляется сам."))
    }

    @Test func skipsAssetsThatAreNotTheImage() throws {
        let extra = """
        { "name": "Stash-1.27.dmg.sha256", "size": 80,
          "browser_download_url": "https://example.invalid/checksum" },
        \(Self.dmgAsset)
        """
        let release = try #require(ReleaseFeed.parse(json(assets: extra)))
        #expect(release.dmgURL.lastPathComponent == "Stash-1.27.dmg")
    }

    @Test func aReleaseWithoutAnImageIsNoRelease() {
        #expect(ReleaseFeed.parse(json(assets: "")) == nil)
    }

    @Test func aTagThatIsNotAVersionIsNoRelease() {
        #expect(ReleaseFeed.parse(json(tag: "nightly")) == nil)
    }

    @Test func rubbishIsNoRelease() {
        #expect(ReleaseFeed.parse(Data("not json".utf8)) == nil)
    }
}
```

- [ ] **Step 2: Написать падающие тесты заметок**

`Tests/BufferJournalTests/ReleaseNotesTests.swift`:

```swift
import Testing
@testable import BufferJournal

struct ReleaseNotesTests {
    @Test func aDashedLineBecomesAnItem() {
        let notes = ReleaseNotes.parse("- Журнал открывается у курсора.")
        #expect(notes == [ReleaseNote(id: 0, kind: .item, text: "Журнал открывается у курсора.")])
    }

    @Test func anAsteriskIsAnItemToo() {
        #expect(ReleaseNotes.parse("* Второй пункт.").first?.kind == .item)
    }

    @Test func aPlainLineStaysAParagraph() {
        let notes = ReleaseNotes.parse("Подпись приложения сменилась.")
        #expect(notes == [ReleaseNote(id: 0, kind: .paragraph, text: "Подпись приложения сменилась.")])
    }

    @Test func headingsLoseTheirHashes() {
        #expect(ReleaseNotes.parse("## Что нового").first?.text == "Что нового")
        #expect(ReleaseNotes.parse("## Что нового").first?.kind == .paragraph)
    }

    @Test func emptyLinesAndWindowsEndingsAreDropped() {
        let notes = ReleaseNotes.parse("- Первый\r\n\r\n- Второй\r\n")
        #expect(notes.map(\.text) == ["Первый", "Второй"])
        #expect(notes.map(\.id) == [0, 1])
    }

    @Test func nothingInNothingOut() {
        #expect(ReleaseNotes.parse("   \n\n").isEmpty)
    }
}
```

- [ ] **Step 3: Прогнать оба набора и убедиться, что они падают**

Run: `swift test --filter "ReleaseFeedTests|ReleaseNotesTests"`
Expected: FAIL, `cannot find 'ReleaseFeed' in scope`.

- [ ] **Step 4: Написать разбор ленты**

`Sources/BufferJournal/Updates/ReleaseFeed.swift`:

```swift
import Foundation

/// One release on GitHub: the version it carries, its notes and the image to download.
struct Release: Equatable, Sendable {
    let version: AppVersion
    let notes: String
    let dmgURL: URL
    let size: Int64
}

/// Reads the answer of https://api.github.com/repos/KiraMurano/stash/releases/latest.
/// A tag that is not a version and a release without a DMG both mean "no release": Stash treats
/// them as "nothing new", never as an error.
enum ReleaseFeed {
    private struct Payload: Decodable {
        struct Asset: Decodable {
            let name: String
            let size: Int64
            let browserDownloadURL: URL

            enum CodingKeys: String, CodingKey {
                case name
                case size
                case browserDownloadURL = "browser_download_url"
            }
        }

        let tagName: String
        let body: String?
        let assets: [Asset]

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case body
            case assets
        }
    }

    static func parse(_ data: Data) -> Release? {
        guard
            let payload = try? JSONDecoder().decode(Payload.self, from: data),
            let version = AppVersion(payload.tagName),
            let asset = payload.assets.first(where: { $0.name.lowercased().hasSuffix(".dmg") })
        else {
            return nil
        }

        return Release(
            version: version,
            notes: payload.body ?? "",
            dmgURL: asset.browserDownloadURL,
            size: asset.size
        )
    }
}
```

- [ ] **Step 5: Написать разбор заметок**

`Sources/BufferJournal/Updates/ReleaseNotes.swift`:

```swift
import Foundation

/// A line of the release text on the update screen.
struct ReleaseNote: Equatable, Identifiable {
    enum Kind: Equatable {
        /// A line that began with "- " or "* ": it gets the orange marker.
        case item
        /// Everything else, including headings stripped of their hashes.
        case paragraph
    }

    let id: Int
    let kind: Kind
    let text: String
}

/// Splits the release text into lines Stash can draw. AttributedString(markdown:) does bold,
/// italics and links but not bulleted lists, so the markers are ours and the list is cut here.
enum ReleaseNotes {
    static func parse(_ body: String) -> [ReleaseNote] {
        var notes: [ReleaseNote] = []

        for rawLine in body.split(whereSeparator: \.isNewline) {
            var line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            var kind = ReleaseNote.Kind.paragraph
            if line.hasPrefix("- ") || line.hasPrefix("* ") {
                kind = .item
                line.removeFirst(2)
            } else if line.hasPrefix("#") {
                line = String(line.drop(while: { $0 == "#" }))
            }

            line = line.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            notes.append(ReleaseNote(id: notes.count, kind: kind, text: line))
        }

        return notes
    }
}
```

- [ ] **Step 6: Прогнать тесты и убедиться, что они проходят**

Run: `swift test --filter "ReleaseFeedTests|ReleaseNotesTests"`
Expected: PASS, 11 тестов.

- [ ] **Step 7: Коммит**

```bash
git add Sources/BufferJournal/Updates/ReleaseFeed.swift Sources/BufferJournal/Updates/ReleaseNotes.swift Tests/BufferJournalTests/ReleaseFeedTests.swift Tests/BufferJournalTests/ReleaseNotesTests.swift
git commit -m "Read the GitHub release feed and its notes"
```

---

### Task 3: Что приложение знает о себе

**Files:**
- Create: `Sources/BufferJournal/Updates/UpdateEnvironment.swift`
- Test: `Tests/BufferJournalTests/UpdateEnvironmentTests.swift`

**Interfaces:**
- Consumes: `AppVersion` (Task 1).
- Produces: `struct UpdateEnvironment: Sendable` с полями `currentVersion: AppVersion?`, `requirement: String?`, `bundleURL: URL`, `isDestinationWritable: Bool`; вычисляемым `canSelfUpdate: Bool`; методами `isNewer(_ release: Release) -> Bool` и `static func releasedVersion(_ raw: String?) -> AppVersion?`; фабрикой `static func current(bundle: Bundle = .main) -> UpdateEnvironment` и прямым `init` для тестов.

- [ ] **Step 1: Написать падающий тест**

`Tests/BufferJournalTests/UpdateEnvironmentTests.swift`:

```swift
import Foundation
import Testing
@testable import BufferJournal

struct UpdateEnvironmentTests {
    private let requirement = #"identifier "local.buffer-journal" and certificate leaf H"abc""#

    private func environment(
        version: String? = "1.26",
        requirement: String? = nil,
        writable: Bool = true
    ) -> UpdateEnvironment {
        UpdateEnvironment(
            currentVersion: UpdateEnvironment.releasedVersion(version),
            requirement: requirement ?? self.requirement,
            bundleURL: URL(fileURLWithPath: "/Applications/Stash.app"),
            isDestinationWritable: writable
        )
    }

    private func release(_ version: String) -> Release {
        Release(
            version: AppVersion(version)!,
            notes: "",
            dmgURL: URL(string: "https://example.invalid/Stash-\(version).dmg")!,
            size: 1
        )
    }

    @Test func aSignedBuildWithAVersionCanUpdateItself() {
        #expect(environment().canSelfUpdate)
    }

    @Test func aBuildWithoutTheRequirementCannot() {
        let environment = UpdateEnvironment(
            currentVersion: AppVersion("1.26"),
            requirement: nil,
            bundleURL: URL(fileURLWithPath: "/Applications/Stash.app"),
            isDestinationWritable: true
        )
        #expect(!environment.canSelfUpdate)
    }

    @Test func theSourceBuildPlaceholderIsNoVersion() {
        #expect(!environment(version: "0.0").canSelfUpdate)
    }

    @Test func aHigherReleaseIsNewer() {
        #expect(environment().isNewer(release("1.27")))
    }

    @Test func theSameOrAnOlderReleaseIsNot() {
        #expect(!environment().isNewer(release("1.26")))
        #expect(!environment().isNewer(release("1.25")))
    }

    @Test func withoutAVersionNothingIsNewer() {
        #expect(!environment(version: nil).isNewer(release("1.27")))
    }

    @Test func aReadOnlyFolderStillSeesTheRelease() {
        // Права на запись решают, можно ли поставить, а не можно ли узнать.
        let environment = environment(writable: false)
        #expect(environment.isNewer(release("1.27")))
        #expect(!environment.isDestinationWritable)
    }

    @Test func theTestBundleHasNoRequirementOfItsOwn() {
        // Тесты идут не в .app: фабрика не должна падать и обязана сказать "обновлять нечего".
        #expect(!UpdateEnvironment.current(bundle: .main).canSelfUpdate)
    }
}
```

- [ ] **Step 2: Прогнать тест и убедиться, что он падает**

Run: `swift test --filter UpdateEnvironmentTests`
Expected: FAIL, `cannot find 'UpdateEnvironment' in scope`.

- [ ] **Step 3: Написать реализацию**

`Sources/BufferJournal/Updates/UpdateEnvironment.swift`:

```swift
import Foundation

/// What the running copy of Stash knows about itself: which version it is, what a downloaded
/// build must satisfy to be trusted, where it lives and whether that place can be written to.
///
/// A build made by `swift build` or by `Scripts/build_app.sh` without a version keeps the
/// placeholder 0.0 from Info.plist and carries no StashUpdateRequirement. Such a build never
/// checks for updates: there is nothing to compare against and nothing to verify with.
struct UpdateEnvironment: Sendable {
    /// The placeholder Info.plist ships with; it is not a released version.
    static let placeholderVersion = "0.0"
    static let requirementKey = "StashUpdateRequirement"

    let currentVersion: AppVersion?
    let requirement: String?
    let bundleURL: URL
    let isDestinationWritable: Bool

    var canSelfUpdate: Bool {
        currentVersion != nil && requirement != nil
    }

    func isNewer(_ release: Release) -> Bool {
        guard let currentVersion else { return false }
        return release.version > currentVersion
    }

    /// The version a build reports, or nil when it is the placeholder a source build keeps.
    /// The rule lives here, not inside `current`, so the tests can build an environment that
    /// obeys it without going through Bundle.
    static func releasedVersion(_ raw: String?) -> AppVersion? {
        guard let raw, raw != placeholderVersion else { return nil }
        return AppVersion(raw)
    }

    static func current(bundle: Bundle = .main) -> UpdateEnvironment {
        let version = releasedVersion(bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
        let requirement = bundle.object(forInfoDictionaryKey: requirementKey) as? String
        let url = bundle.bundleURL

        return UpdateEnvironment(
            currentVersion: version,
            requirement: requirement?.isEmpty == false ? requirement : nil,
            bundleURL: url,
            // The swap renames the bundle inside its parent folder, so the folder is what must
            // be writable — not the bundle.
            isDestinationWritable: FileManager.default.isWritableFile(atPath: url.deletingLastPathComponent().path)
        )
    }
}
```

- [ ] **Step 4: Прогнать тест и убедиться, что он проходит**

Run: `swift test --filter UpdateEnvironmentTests`
Expected: PASS, 8 тестов.

- [ ] **Step 5: Коммит**

```bash
git add Sources/BufferJournal/Updates/UpdateEnvironment.swift Tests/BufferJournalTests/UpdateEnvironmentTests.swift
git commit -m "Tell a released build from a build made from source"
```

---

### Task 4: Расписание проверок и запрос к ленте

**Files:**
- Create: `Sources/BufferJournal/Updates/UpdateSchedule.swift`, `Sources/BufferJournal/Updates/UpdateChecking.swift`
- Test: `Tests/BufferJournalTests/UpdateScheduleTests.swift`

**Interfaces:**
- Consumes: `Release`, `ReleaseFeed` (Task 2).
- Produces:
  - `struct UpdateSchedule` с `init(defaults: UserDefaults)`, свойствами `isAutomatic: Bool` и `lastCheck: Date?` (оба пишут в `UserDefaults`), методом `isDue(now: Date) -> Bool`, константами `interval: TimeInterval = 86_400` и `launchDelay: TimeInterval = 10`.
  - `protocol UpdateChecking: Sendable { func latestRelease() async throws -> Release? }`.
  - `struct GitHubUpdateChecker: UpdateChecking` с `static let feedURL` и `init(session: URLSession = .shared)`.
  - `enum UpdateError: Error, Equatable { case network, signature(String), install(String), notWritable }`.

- [ ] **Step 1: Написать падающий тест**

`Tests/BufferJournalTests/UpdateScheduleTests.swift`:

```swift
import Foundation
import Testing
@testable import BufferJournal

struct UpdateScheduleTests {
    private func freshDefaults() -> UserDefaults {
        let name = "UpdateScheduleTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func automaticChecksAreOnForANewInstall() {
        #expect(UpdateSchedule(defaults: freshDefaults()).isAutomatic)
    }

    @Test func theChoiceMadeBeforeIsKept() {
        let defaults = freshDefaults()
        defaults.set(false, forKey: "CheckForUpdatesAutomatically")
        #expect(!UpdateSchedule(defaults: defaults).isAutomatic)
    }

    @Test func switchingItOffIsSaved() {
        let defaults = freshDefaults()
        var schedule = UpdateSchedule(defaults: defaults)
        schedule.isAutomatic = false
        #expect(defaults.bool(forKey: "CheckForUpdatesAutomatically") == false)
    }

    @Test func aCheckIsDueWhenThereHasNeverBeenOne() {
        #expect(UpdateSchedule(defaults: freshDefaults()).isDue(now: Date()))
    }

    @Test func aCheckIsNotDueWithinTheDay() {
        var schedule = UpdateSchedule(defaults: freshDefaults())
        let now = Date()
        schedule.lastCheck = now
        #expect(!schedule.isDue(now: now.addingTimeInterval(60 * 60)))
    }

    @Test func aCheckIsDueAfterTheDay() {
        var schedule = UpdateSchedule(defaults: freshDefaults())
        let now = Date()
        schedule.lastCheck = now
        #expect(schedule.isDue(now: now.addingTimeInterval(UpdateSchedule.interval + 1)))
    }

    @Test func aClockMovedBackwardsDoesNotLockChecksOut() {
        // Часы переставили назад: отметка из будущего не должна запереть проверки навсегда.
        var schedule = UpdateSchedule(defaults: freshDefaults())
        let now = Date()
        schedule.lastCheck = now.addingTimeInterval(10 * UpdateSchedule.interval)
        #expect(schedule.isDue(now: now))
    }

    @Test func switchedOffItIsNeverDue() {
        var schedule = UpdateSchedule(defaults: freshDefaults())
        schedule.isAutomatic = false
        #expect(!schedule.isDue(now: Date()))
    }
}
```

- [ ] **Step 2: Прогнать тест и убедиться, что он падает**

Run: `swift test --filter UpdateScheduleTests`
Expected: FAIL, `cannot find 'UpdateSchedule' in scope`.

- [ ] **Step 3: Написать расписание**

`Sources/BufferJournal/Updates/UpdateSchedule.swift`:

```swift
import Foundation

/// When Stash asks GitHub about a new version: the first time ten seconds after the app has
/// settled, then once a day. The time of the last check is kept, so ten restarts in a row make
/// one request, not ten.
struct UpdateSchedule {
    static let interval: TimeInterval = 24 * 60 * 60
    /// The first check waits, so it never competes with the app's own start.
    static let launchDelay: TimeInterval = 10

    private enum Keys {
        static let automatic = "CheckForUpdatesAutomatically"
        static let lastCheck = "LastUpdateCheck"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults.object(forKey: Keys.automatic) == nil {
            defaults.set(true, forKey: Keys.automatic)
        }
    }

    var isAutomatic: Bool {
        get { defaults.bool(forKey: Keys.automatic) }
        nonmutating set { defaults.set(newValue, forKey: Keys.automatic) }
    }

    var lastCheck: Date? {
        get { defaults.object(forKey: Keys.lastCheck) as? Date }
        nonmutating set { defaults.set(newValue, forKey: Keys.lastCheck) }
    }

    func isDue(now: Date) -> Bool {
        guard isAutomatic else { return false }
        guard let lastCheck else { return true }
        // A mark from the future means the clock was moved; it must not lock checks out forever.
        let elapsed = now.timeIntervalSince(lastCheck)
        return elapsed >= Self.interval || elapsed < 0
    }
}
```

- [ ] **Step 4: Написать запрос к ленте**

`Sources/BufferJournal/Updates/UpdateChecking.swift`:

```swift
import Foundation

/// Everything that can go wrong on the way to a new version. The texts the user sees are built
/// from these cases by the controller, in the language of the app.
enum UpdateError: Error, Equatable {
    /// GitHub did not answer, or answered with something that is not a release.
    case network
    /// The downloaded image does not satisfy this build's requirement.
    case signature(String)
    /// The install script could not be started, or it left a failure behind.
    case install(String)
    /// Stash lives in a folder it may not write to.
    case notWritable
}

/// Asks where the newest release is. The app talks to GitHub; the tests hand in their own.
protocol UpdateChecking: Sendable {
    /// The newest release, or nil when there is nothing that looks like one.
    func latestRelease() async throws -> Release?
}

struct GitHubUpdateChecker: UpdateChecking {
    static let feedURL = URL(string: "https://api.github.com/repos/KiraMurano/stash/releases/latest")!

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func latestRelease() async throws -> Release? {
        var request = URLRequest(url: Self.feedURL)
        request.timeoutInterval = 15
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw UpdateError.network
        }

        // 403 is GitHub's rate limit — 60 unauthenticated requests an hour. One check a day never
        // reaches it, but a shared address might, and that is an ordinary failed check.
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw UpdateError.network
        }

        return ReleaseFeed.parse(data)
    }
}
```

- [ ] **Step 5: Прогнать тест и убедиться, что он проходит**

Run: `swift test --filter UpdateScheduleTests`
Expected: PASS, 8 тестов.

- [ ] **Step 6: Коммит**

```bash
git add Sources/BufferJournal/Updates/UpdateSchedule.swift Sources/BufferJournal/Updates/UpdateChecking.swift Tests/BufferJournalTests/UpdateScheduleTests.swift
git commit -m "Check for a new version once a day"
```

---

### Task 5: Загрузка образа с прогрессом

**Files:**
- Create: `Sources/BufferJournal/Updates/UpdateDownloading.swift`
- Test: `Tests/BufferJournalTests/UpdateDownloadingTests.swift`

**Interfaces:**
- Consumes: `Release` (Task 2), `UpdateError` (Task 4).
- Produces: `protocol UpdateDownloading: Sendable { func download(_ release: Release, onProgress: @escaping @Sendable (Double) -> Void) async throws -> URL }` и `struct FileUpdateDownloader: UpdateDownloading` с `init(session: URLSession = .shared)`.

- [ ] **Step 1: Написать падающий тест**

`Tests/BufferJournalTests/UpdateDownloadingTests.swift`:

```swift
import Foundation
import Testing
@testable import BufferJournal

struct UpdateDownloadingTests {
    /// URLSession умеет file://, поэтому настоящий загрузчик проверяется без сети.
    /// Прогресс на файловых адресах система не сообщает, и тест его не ждёт.
    private func temporaryImage(bytes: Int) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("UpdateDownloadingTests-\(UUID().uuidString).dmg")
        try Data(repeating: 0x42, count: bytes).write(to: url)
        return url
    }

    private func release(at url: URL, size: Int64) -> Release {
        Release(version: AppVersion(major: 1, minor: 27), notes: "", dmgURL: url, size: size)
    }

    @Test func bringsTheFileDownWholeAndNamesItAfterTheVersion() async throws {
        let source = try temporaryImage(bytes: 4096)
        defer { try? FileManager.default.removeItem(at: source) }

        let downloaded = try await FileUpdateDownloader().download(release(at: source, size: 4096)) { _ in }
        defer { try? FileManager.default.removeItem(at: downloaded) }

        #expect(downloaded.lastPathComponent == "Stash-1.27.dmg")
        #expect(try Data(contentsOf: downloaded).count == 4096)
    }

    @Test func aMissingFileIsANetworkFailure() async throws {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("no-such-\(UUID().uuidString).dmg")

        await #expect(throws: UpdateError.network) {
            _ = try await FileUpdateDownloader().download(release(at: missing, size: 1)) { _ in }
        }
    }

    @Test func twoDownloadsDoNotShareAFile() async throws {
        let source = try temporaryImage(bytes: 16)
        defer { try? FileManager.default.removeItem(at: source) }

        let first = try await FileUpdateDownloader().download(release(at: source, size: 16)) { _ in }
        let second = try await FileUpdateDownloader().download(release(at: source, size: 16)) { _ in }
        defer {
            try? FileManager.default.removeItem(at: first)
            try? FileManager.default.removeItem(at: second)
        }

        #expect(first != second)
    }
}
```

- [ ] **Step 2: Прогнать тест и убедиться, что он падает**

Run: `swift test --filter UpdateDownloadingTests`
Expected: FAIL, `cannot find 'FileUpdateDownloader' in scope`.

- [ ] **Step 3: Написать реализацию**

`Sources/BufferJournal/Updates/UpdateDownloading.swift`:

```swift
import Foundation

/// Brings the release image down. The app uses URLSession; the tests hand in their own.
protocol UpdateDownloading: Sendable {
    /// The image on disk. `onProgress` is called with 0…1 and may be called from any thread.
    func download(_ release: Release, onProgress: @escaping @Sendable (Double) -> Void) async throws -> URL
}

struct FileUpdateDownloader: UpdateDownloading {
    /// URLSession hands the download to its delegate on a queue of its own, so the delegate only
    /// ever touches the closure it was built with.
    private final class ProgressDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
        private let onProgress: @Sendable (Double) -> Void

        init(onProgress: @escaping @Sendable (Double) -> Void) {
            self.onProgress = onProgress
        }

        func urlSession(
            _ session: URLSession,
            downloadTask: URLSessionDownloadTask,
            didWriteData bytesWritten: Int64,
            totalBytesWritten: Int64,
            totalBytesExpectedToWrite: Int64
        ) {
            guard totalBytesExpectedToWrite > 0 else { return }
            onProgress(min(1, Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)))
        }

        // Required by the protocol; the awaited call returns the file itself.
        func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {}
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func download(_ release: Release, onProgress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        var request = URLRequest(url: release.dmgURL)
        request.timeoutInterval = 60

        let temporary: URL
        let response: URLResponse
        do {
            (temporary, response) = try await session.download(for: request, delegate: ProgressDelegate(onProgress: onProgress))
        } catch {
            throw UpdateError.network
        }

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw UpdateError.network
        }

        // URLSession deletes its temporary file as soon as the call returns, so it moves now.
        // Each download gets a folder of its own: a second attempt must not land on the first.
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("StashUpdate-\(UUID().uuidString)")
        let destination = folder.appendingPathComponent("Stash-\(release.version).dmg")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try FileManager.default.moveItem(at: temporary, to: destination)
        } catch {
            throw UpdateError.network
        }

        return destination
    }
}
```

- [ ] **Step 4: Прогнать тест и убедиться, что он проходит**

Run: `swift test --filter UpdateDownloadingTests`
Expected: PASS, 3 теста.

- [ ] **Step 5: Коммит**

```bash
git add Sources/BufferJournal/Updates/UpdateDownloading.swift Tests/BufferJournalTests/UpdateDownloadingTests.swift
git commit -m "Download the release image with progress"
```

---

### Task 6: Проверка подписи

**Files:**
- Create: `Sources/BufferJournal/Updates/Codesign.swift`
- Test: `Tests/BufferJournalTests/CodesignTests.swift`

**Interfaces:**
- Consumes: `UpdateError` (Task 4).
- Produces: `enum Codesign` с `static func verify(_ url: URL, requirement: String, deep: Bool) throws`, `static func designatedRequirement(of url: URL) throws -> String` и `static func sign(_ url: URL, identifier: String) throws` (последняя — для тестов и только ad hoc).

- [ ] **Step 1: Написать падающий тест**

`Tests/BufferJournalTests/CodesignTests.swift`:

```swift
import Foundation
import Testing
@testable import BufferJournal

struct CodesignTests {
    /// Пустой бандл приложения: Info.plist и пустой исполняемый файл — этого хватает codesign.
    private func makeBundle(marker: String) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("CodesignTests-\(UUID().uuidString)")
        let app = root.appendingPathComponent("Stash.app")
        let macos = app.appendingPathComponent("Contents/MacOS")
        try FileManager.default.createDirectory(at: macos, withIntermediateDirectories: true)
        try Data(marker.utf8).write(to: macos.appendingPathComponent("BufferJournal"))
        try """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0"><dict>
        <key>CFBundleExecutable</key><string>BufferJournal</string>
        <key>CFBundleIdentifier</key><string>local.buffer-journal</string>
        </dict></plist>
        """.write(to: app.appendingPathComponent("Contents/Info.plist"), atomically: true, encoding: .utf8)
        return app
    }

    @Test func aSignedBundleSatisfiesItsOwnRequirement() throws {
        let app = try makeBundle(marker: "one")
        defer { try? FileManager.default.removeItem(at: app.deletingLastPathComponent()) }

        try Codesign.sign(app, identifier: "local.buffer-journal")
        let requirement = try Codesign.designatedRequirement(of: app)
        #expect(requirement.contains("local.buffer-journal"))
        try Codesign.verify(app, requirement: requirement, deep: true)
    }

    @Test func anotherBuildFailsACdhashRequirement() throws {
        // Именно это и ломает ad hoc подпись: требование держит cdhash, а он у каждой сборки свой.
        let first = try makeBundle(marker: "one")
        let second = try makeBundle(marker: "two")
        defer {
            try? FileManager.default.removeItem(at: first.deletingLastPathComponent())
            try? FileManager.default.removeItem(at: second.deletingLastPathComponent())
        }

        try Codesign.sign(first, identifier: "local.buffer-journal")
        try Codesign.sign(second, identifier: "local.buffer-journal")

        let requirement = try Codesign.designatedRequirement(of: first)
        #expect(throws: (any Error).self) {
            try Codesign.verify(second, requirement: requirement, deep: true)
        }
    }

    @Test func theIdentifierAloneIsSatisfiedByBothBuilds() throws {
        let first = try makeBundle(marker: "one")
        let second = try makeBundle(marker: "two")
        defer {
            try? FileManager.default.removeItem(at: first.deletingLastPathComponent())
            try? FileManager.default.removeItem(at: second.deletingLastPathComponent())
        }

        try Codesign.sign(first, identifier: "local.buffer-journal")
        try Codesign.sign(second, identifier: "local.buffer-journal")

        let requirement = #"identifier "local.buffer-journal""#
        try Codesign.verify(first, requirement: requirement, deep: true)
        try Codesign.verify(second, requirement: requirement, deep: true)
    }

    @Test func anUnsignedBundleSatisfiesNothing() throws {
        let app = try makeBundle(marker: "bare")
        defer { try? FileManager.default.removeItem(at: app.deletingLastPathComponent()) }

        #expect(throws: (any Error).self) {
            try Codesign.verify(app, requirement: #"identifier "local.buffer-journal""#, deep: true)
        }
    }

    @Test func aPathWithSpacesIsHandedOverWhole() throws {
        let app = try makeBundle(marker: "spaced")
        let spaced = app.deletingLastPathComponent().appendingPathComponent("Stash Copy.app")
        try FileManager.default.moveItem(at: app, to: spaced)
        defer { try? FileManager.default.removeItem(at: spaced.deletingLastPathComponent()) }

        try Codesign.sign(spaced, identifier: "local.buffer-journal")
        try Codesign.verify(spaced, requirement: #"identifier "local.buffer-journal""#, deep: true)
    }
}
```

- [ ] **Step 2: Прогнать тест и убедиться, что он падает**

Run: `swift test --filter CodesignTests`
Expected: FAIL, `cannot find 'Codesign' in scope`.

- [ ] **Step 3: Написать реализацию**

`Sources/BufferJournal/Updates/Codesign.swift`:

```swift
import Foundation

/// A thin wrapper over /usr/bin/codesign. Stash is signed with a self-signed certificate, not a
/// Developer ID, so Gatekeeper knows nothing about it and `spctl` is never asked: the only
/// question that means anything here is whether a build satisfies this build's own requirement.
enum Codesign {
    private static let tool = "/usr/bin/codesign"

    /// Fails when the item does not satisfy `requirement`, and says what codesign said.
    static func verify(_ url: URL, requirement: String, deep: Bool) throws {
        var arguments = ["-v", "--strict", "-R=\(requirement)"]
        if deep {
            arguments.append("--deep")
        }
        arguments.append(url.path)

        let result = try run(arguments)
        guard result.status == 0 else {
            throw UpdateError.signature(result.output.isEmpty ? "codesign exited with \(result.status)" : result.output)
        }
    }

    /// The requirement a signed item satisfies by itself. Used by the tests and by
    /// `Scripts/build_app.sh` to see what it has produced.
    static func designatedRequirement(of url: URL) throws -> String {
        let result = try run(["-d", "-r-", "--", url.path])
        guard result.status == 0 else {
            throw UpdateError.signature(result.output)
        }

        for line in result.output.split(whereSeparator: \.isNewline) where line.hasPrefix("designated =>") {
            return line.replacingOccurrences(of: "designated =>", with: "").trimmingCharacters(in: .whitespaces)
        }

        throw UpdateError.signature("codesign printed no designated requirement")
    }

    /// Ad hoc signing, for the tests only: the app itself is signed by `Scripts/build_app.sh`.
    static func sign(_ url: URL, identifier: String) throws {
        let result = try run(["--force", "--deep", "--sign", "-", "--identifier", identifier, url.path])
        guard result.status == 0 else {
            throw UpdateError.signature(result.output)
        }
    }

    private static func run(_ arguments: [String]) throws -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments

        // codesign says most of what it has to say on stderr; both streams go into one pipe.
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        return (process.terminationStatus, String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
```

- [ ] **Step 4: Прогнать тест и убедиться, что он проходит**

Run: `swift test --filter CodesignTests`
Expected: PASS, 5 тестов. Тесты зовут настоящий `/usr/bin/codesign`; он есть на любом Mac с Command Line Tools.

- [ ] **Step 5: Коммит**

```bash
git add Sources/BufferJournal/Updates/Codesign.swift Tests/BufferJournalTests/CodesignTests.swift
git commit -m "Check a build against a code signing requirement"
```

---

### Task 7: Скрипт подмены и маркер неудачи

**Files:**
- Create: `Sources/BufferJournal/Updates/UpdateInstaller.swift`, `Sources/BufferJournal/Updates/UpdateFailureMarker.swift`
- Test: `Tests/BufferJournalTests/UpdateInstallerTests.swift`

**Interfaces:**
- Consumes: `UpdateEnvironment` (Task 3), `UpdateError` (Task 4), `Codesign` (Task 6).
- Produces:
  - `enum UpdateInstaller` с `static let script: String`, `static func environment(dmg: URL, destination: URL, requirement: String, pid: Int32, relaunch: Bool) -> [String: String]` и `static func launch(dmg: URL, environment: UpdateEnvironment) throws`.
  - `enum UpdateFailureMarker` с `static var url: URL` и `static func take() -> String?`.

- [ ] **Step 1: Написать падающий тест**

`Tests/BufferJournalTests/UpdateInstallerTests.swift`:

```swift
import Foundation
import Testing
@testable import BufferJournal

struct UpdateInstallerTests {
    // MARK: Окружение

    @Test func pathsGoIntoTheEnvironmentWhole() {
        let environment = UpdateInstaller.environment(
            dmg: URL(fileURLWithPath: "/tmp/my images/Stash 1.27.dmg"),
            destination: URL(fileURLWithPath: "/Applications/My Apps/Stash.app"),
            requirement: #"identifier "local.buffer-journal""#,
            pid: 4321,
            relaunch: true
        )

        #expect(environment["STASH_DMG"] == "/tmp/my images/Stash 1.27.dmg")
        #expect(environment["STASH_DEST"] == "/Applications/My Apps/Stash.app")
        #expect(environment["STASH_APP_NAME"] == "Stash.app")
        #expect(environment["STASH_REQUIREMENT"] == #"identifier "local.buffer-journal""#)
        #expect(environment["STASH_PID"] == "4321")
        #expect(environment["STASH_RELAUNCH"] == "1")
    }

    @Test func theMarkerLivesBesideTheHistory() {
        #expect(UpdateFailureMarker.url.lastPathComponent == "update-failure.txt")
        #expect(UpdateFailureMarker.url.deletingLastPathComponent().lastPathComponent == "BufferJournal")
    }

    // MARK: Скрипт целиком

    /// Пустой бандл с опознавательным файлом внутри.
    private func makeBundle(at url: URL, marker: String) throws {
        let macos = url.appendingPathComponent("Contents/MacOS")
        try FileManager.default.createDirectory(at: macos, withIntermediateDirectories: true)
        try Data(marker.utf8).write(to: macos.appendingPathComponent("BufferJournal"))
        try """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0"><dict>
        <key>CFBundleExecutable</key><string>BufferJournal</string>
        <key>CFBundleIdentifier</key><string>local.buffer-journal</string>
        </dict></plist>
        """.write(to: url.appendingPathComponent("Contents/Info.plist"), atomically: true, encoding: .utf8)
    }

    private func shell(_ tool: String, _ arguments: [String]) throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        _ = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return process.terminationStatus
    }

    /// Гоняет скрипт как есть и ждёт его конца.
    private func runScript(_ environment: [String: String]) throws -> Int32 {
        let script = FileManager.default.temporaryDirectory
            .appendingPathComponent("stash-update-\(UUID().uuidString).sh")
        try UpdateInstaller.script.write(to: script, atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [script.path]
        process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }

    /// Проходит весь путь: образ → монтирование → копия → подмена.
    /// Требование здесь — `identifier`, а не хеш сертификата: обе стороны подписаны ad hoc,
    /// и их cdhash не совпадает по определению. Проверяется ход скрипта, не стойкость требования.
    @Test func theScriptPutsTheNewVersionInPlace() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("UpdateInstallerTests-\(UUID().uuidString)")
        let stagingFolder = root.appendingPathComponent("image")
        let installed = root.appendingPathComponent("Applications/Stash.app")
        // Скрипт подчищает за собой каталог образа целиком, поэтому образ лежит в своём.
        let downloads = root.appendingPathComponent("download")
        try FileManager.default.createDirectory(at: stagingFolder, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: downloads, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: installed.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try makeBundle(at: installed, marker: "old")
        let fresh = stagingFolder.appendingPathComponent("Stash.app")
        try makeBundle(at: fresh, marker: "new")
        try Codesign.sign(installed, identifier: "local.buffer-journal")
        try Codesign.sign(fresh, identifier: "local.buffer-journal")

        let dmg = downloads.appendingPathComponent("Stash-1.27.dmg")
        #expect(try shell("/usr/bin/hdiutil", [
            "create", "-srcfolder", stagingFolder.path, "-volname", "Stash 1.27",
            "-ov", "-quiet", "-format", "UDZO", dmg.path,
        ]) == 0)
        #expect(try shell("/usr/bin/codesign", [
            "--force", "--sign", "-", "--identifier", "local.buffer-journal", dmg.path,
        ]) == 0)

        let status = try runScript(UpdateInstaller.environment(
            dmg: dmg,
            destination: installed,
            requirement: #"identifier "local.buffer-journal""#,
            pid: 1,                  // существующий и точно не наш процесс: launchd
            relaunch: false
        ))

        #expect(status == 0)
        let executable = installed.appendingPathComponent("Contents/MacOS/BufferJournal")
        #expect(String(decoding: try Data(contentsOf: executable), as: UTF8.self) == "new")
        // Ни промежуточных копий, ни резервной: каталог чист.
        let left = try FileManager.default.contentsOfDirectory(atPath: installed.deletingLastPathComponent().path)
        #expect(left == ["Stash.app"])
    }

    /// Подпись не сошлась: установленное приложение остаётся на месте, остаётся и маркер.
    @Test func aWrongRequirementChangesNothing() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("UpdateInstallerTests-\(UUID().uuidString)")
        let stagingFolder = root.appendingPathComponent("image")
        let installed = root.appendingPathComponent("Applications/Stash.app")
        let downloads = root.appendingPathComponent("download")
        try FileManager.default.createDirectory(at: stagingFolder, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: downloads, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: installed.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try makeBundle(at: installed, marker: "old")
        try makeBundle(at: stagingFolder.appendingPathComponent("Stash.app"), marker: "new")
        try Codesign.sign(stagingFolder.appendingPathComponent("Stash.app"), identifier: "local.buffer-journal")

        let dmg = downloads.appendingPathComponent("Stash-1.27.dmg")
        _ = try shell("/usr/bin/hdiutil", [
            "create", "-srcfolder", stagingFolder.path, "-volname", "Stash 1.27",
            "-ov", "-quiet", "-format", "UDZO", dmg.path,
        ])
        _ = try shell("/usr/bin/codesign", ["--force", "--sign", "-", "--identifier", "local.buffer-journal", dmg.path])

        let marker = root.appendingPathComponent("update-failure.txt")
        var environment = UpdateInstaller.environment(
            dmg: dmg,
            destination: installed,
            requirement: #"identifier "com.someone.else""#,
            pid: 1,
            relaunch: false
        )
        environment["STASH_MARKER"] = marker.path

        #expect(try runScript(environment) != 0)
        let executable = installed.appendingPathComponent("Contents/MacOS/BufferJournal")
        #expect(String(decoding: try Data(contentsOf: executable), as: UTF8.self) == "old")
        #expect(FileManager.default.fileExists(atPath: marker.path))
    }
}
```

- [ ] **Step 2: Прогнать тест и убедиться, что он падает**

Run: `swift test --filter UpdateInstallerTests`
Expected: FAIL, `cannot find 'UpdateInstaller' in scope`.

- [ ] **Step 3: Написать маркер неудачи**

`Sources/BufferJournal/Updates/UpdateFailureMarker.swift`:

```swift
import Foundation

/// A line left by the install script when the swap went wrong after the app had already quit.
/// Stash reads it on the next launch, shows it and deletes it: the message is for one showing.
enum UpdateFailureMarker {
    static var url: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("BufferJournal/update-failure.txt")
    }

    /// Reads the message and removes the file, so it is never shown twice.
    static func take() -> String? {
        let url = Self.url
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        try? FileManager.default.removeItem(at: url)

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
```

- [ ] **Step 4: Написать скрипт и его запуск**

`Sources/BufferJournal/Updates/UpdateInstaller.swift`:

```swift
import AppKit
import Foundation

/// Stash cannot overwrite itself while it runs, so the swap is done by a detached script: the app
/// writes it, starts it and quits. Every path reaches the script through the environment — a path
/// with a space must not have to survive a round trip through quoting.
///
/// The image's signature is checked by the app before this runs (`UpdateController`); the script
/// checks it again, and checks the copied bundle, because by then the app is gone and nobody else
/// can.
enum UpdateInstaller {
    static let script = """
    #!/bin/bash
    # Swaps Stash for a freshly downloaded build. Started by the app just before it quits.
    set -u

    LOG="${STASH_LOG:-/dev/null}"
    MNT=""

    note() { printf '%s\\n' "$1" >>"$LOG" 2>/dev/null || true; }

    cleanup() {
        if [ -n "$MNT" ]; then
            /usr/bin/hdiutil detach "$MNT" -quiet 2>/dev/null \\
                || /usr/bin/hdiutil detach "$MNT" -force -quiet 2>/dev/null || true
            /bin/rmdir "$MNT" 2>/dev/null || true
        fi
        /bin/rm -rf "$(/usr/bin/dirname "$STASH_DMG")" 2>/dev/null || true
        /bin/rm -f "$0" 2>/dev/null || true
    }

    relaunch() {
        [ "${STASH_RELAUNCH:-1}" = "1" ] || return 0
        /usr/bin/open "$STASH_DEST" 2>/dev/null || true
    }

    fail() {
        note "$1"
        printf '%s\\n' "$1" >"$STASH_MARKER" 2>/dev/null || true
        cleanup
        relaunch
        exit 1
    }

    # 1. Wait for the app to go: at most ten seconds, then give up on waiting and try anyway.
    i=0
    while [ "$i" -lt 100 ]; do
        /bin/kill -0 "$STASH_PID" 2>/dev/null || break
        /bin/sleep 0.1
        i=$((i + 1))
    done

    # 2. The image must satisfy this build's requirement before it is even mounted.
    /usr/bin/codesign -v --strict -R="$STASH_REQUIREMENT" "$STASH_DMG" 2>>"$LOG" \\
        || fail "The downloaded image failed its signature check. Nothing was installed."

    MNT="$(/usr/bin/mktemp -d)" || fail "The update could not be mounted."
    /usr/bin/hdiutil attach "$STASH_DMG" -nobrowse -quiet -mountpoint "$MNT" 2>>"$LOG" \\
        || fail "The update could not be mounted."

    SRC="$MNT/$STASH_APP_NAME"
    [ -d "$SRC" ] || fail "The image holds no $STASH_APP_NAME."

    # 3. Copy beside the installed app, clear every xattr the DMG round trip leaves behind
    #    (quarantine and FinderInfo), then check the copy itself.
    STAGE="$STASH_DEST.update-new"
    /bin/rm -rf "$STAGE"
    /usr/bin/ditto "$SRC" "$STAGE" 2>>"$LOG" || fail "The new version could not be copied into place."
    /usr/bin/xattr -cr "$STAGE" 2>/dev/null || true

    if ! /usr/bin/codesign -v --deep --strict -R="$STASH_REQUIREMENT" "$STAGE" 2>>"$LOG"; then
        /bin/rm -rf "$STAGE"
        fail "The copied app failed its signature check. Nothing was installed."
    fi

    # 4. Swap. If the new version cannot take the old one's place, the old one goes back.
    /bin/rm -rf "$STASH_DEST".update-old.* 2>/dev/null || true
    BACKUP="$STASH_DEST.update-old.$$"
    if ! /bin/mv "$STASH_DEST" "$BACKUP"; then
        /bin/rm -rf "$STAGE"
        fail "The old version could not be moved aside."
    fi

    if ! /bin/mv "$STAGE" "$STASH_DEST"; then
        /bin/mv "$BACKUP" "$STASH_DEST" 2>/dev/null || true
        /bin/rm -rf "$STAGE"
        fail "The new version could not be put in place."
    fi

    /bin/rm -rf "$BACKUP"
    cleanup
    relaunch
    exit 0
    """

    static func environment(
        dmg: URL,
        destination: URL,
        requirement: String,
        pid: Int32,
        relaunch: Bool
    ) -> [String: String] {
        [
            "STASH_DMG": dmg.path,
            "STASH_DEST": destination.path,
            "STASH_APP_NAME": destination.lastPathComponent,
            "STASH_REQUIREMENT": requirement,
            "STASH_PID": String(pid),
            "STASH_MARKER": UpdateFailureMarker.url.path,
            "STASH_LOG": dmg.deletingLastPathComponent().appendingPathComponent("install.log").path,
            "STASH_RELAUNCH": relaunch ? "1" : "0",
        ]
    }

    /// Writes the script, starts it detached and returns. The caller quits the app right after:
    /// the script waits for this process to go before it touches anything.
    static func launch(dmg: URL, environment updates: UpdateEnvironment) throws {
        guard let requirement = updates.requirement else {
            throw UpdateError.install("This build carries no update requirement.")
        }

        let scriptURL = dmg.deletingLastPathComponent().appendingPathComponent("stash-update.sh")
        do {
            try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        } catch {
            throw UpdateError.install("The install script could not be written.")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [scriptURL.path]
        process.environment = ProcessInfo.processInfo.environment.merging(
            environment(
                dmg: dmg,
                destination: updates.bundleURL,
                requirement: requirement,
                pid: ProcessInfo.processInfo.processIdentifier,
                relaunch: true
            )
        ) { _, new in new }

        do {
            try process.run()
        } catch {
            throw UpdateError.install("The install script could not be started.")
        }
    }
}
```

- [ ] **Step 5: Прогнать тест и убедиться, что он проходит**

Run: `swift test --filter UpdateInstallerTests`
Expected: PASS, 4 теста. Два последних зовут `hdiutil` и `codesign` и идут несколько секунд — это ожидаемо: подмена приложения слишком дорога, чтобы проверять её на заглушках.

- [ ] **Step 6: Коммит**

```bash
git add Sources/BufferJournal/Updates/UpdateInstaller.swift Sources/BufferJournal/Updates/UpdateFailureMarker.swift Tests/BufferJournalTests/UpdateInstallerTests.swift
git commit -m "Swap the app for a new build with a detached script"
```

---

### Task 8: Состояния обновления

**Files:**
- Create: `Sources/BufferJournal/Updates/UpdateController.swift`
- Test: `Tests/BufferJournalTests/UpdateControllerTests.swift`

**Interfaces:**
- Consumes: всё из задач 1–7.
- Produces: `@MainActor final class UpdateController: ObservableObject` с:
  - `enum State: Equatable { case idle, checking, upToDate, available, downloading(Double), installing, failed(UpdateError) }` — без полезной нагрузки: найденный релиз лежит отдельно, иначе его негде взять в состояниях загрузки и ошибки
  - `@Published private(set) var state: State`, `@Published private(set) var release: Release?`, `@Published private(set) var isPresented: Bool`
  - `var isAutomatic: Bool { get set }`, `var isBadgeVisible: Bool`, `var canSelfUpdate: Bool`, `var currentVersion: AppVersion?`
  - `func armIfReady()`, `private(set) var isArmed: Bool`, `func checkNow()`, `func check(manual: Bool) async`
  - `func present()`, `func close()`, `func install()`, `func runInstall() async`, `func openReleasesPage()`
  - `init(environment:checker:downloader:defaults:now:isReady:install:quit:release:state:)` — два последних с умолчанием `nil` и `.idle`, ими пользуются снимки

- [ ] **Step 1: Написать падающий тест**

`Tests/BufferJournalTests/UpdateControllerTests.swift`:

```swift
import Foundation
import Testing
@testable import BufferJournal

@MainActor
struct UpdateControllerTests {
    // MARK: Заглушки

    private struct StubChecker: UpdateChecking {
        let result: Result<Release?, UpdateError>
        func latestRelease() async throws -> Release? { try result.get() }
    }

    private struct StubDownloader: UpdateDownloading {
        let result: Result<URL, UpdateError>
        func download(_ release: Release, onProgress: @escaping @Sendable (Double) -> Void) async throws -> URL {
            onProgress(0.5)
            return try result.get()
        }
    }

    private final class Recorder: @unchecked Sendable {
        var installed: URL?
        var quits = 0
    }

    private func release(_ version: String, notes: String = "- Пункт") -> Release {
        Release(
            version: AppVersion(version)!,
            notes: notes,
            dmgURL: URL(string: "https://example.invalid/Stash-\(version).dmg")!,
            size: 4_404_019
        )
    }

    private func freshDefaults() -> UserDefaults {
        let name = "UpdateControllerTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func environment(version: String? = "1.26", requirement: String? = "req", writable: Bool = true) -> UpdateEnvironment {
        UpdateEnvironment(
            currentVersion: version.flatMap(AppVersion.init),
            requirement: requirement,
            bundleURL: URL(fileURLWithPath: "/Applications/Stash.app"),
            isDestinationWritable: writable
        )
    }

    private func controller(
        environment: UpdateEnvironment? = nil,
        checker: Result<Release?, UpdateError> = .success(nil),
        downloader: Result<URL, UpdateError> = .success(URL(fileURLWithPath: "/tmp/Stash-1.27.dmg")),
        defaults: UserDefaults? = nil,
        ready: Bool = true,
        installFails: UpdateError? = nil,
        recorder: Recorder = Recorder()
    ) -> (UpdateController, Recorder) {
        let controller = UpdateController(
            environment: environment ?? self.environment(),
            checker: StubChecker(result: checker),
            downloader: StubDownloader(result: downloader),
            defaults: defaults ?? freshDefaults(),
            now: { Date() },
            isReady: { ready },
            install: { url in
                if let installFails { throw installFails }
                recorder.installed = url
            },
            quit: { recorder.quits += 1 }
        )
        return (controller, recorder)
    }

    // MARK: Проверка

    @Test func aNewerReleaseBecomesAvailable() async {
        let (controller, _) = controller(checker: .success(release("1.27")))
        await controller.check(manual: true)
        #expect(controller.state == .available)
        #expect(controller.release == release("1.27"))
    }

    @Test func theSameVersionIsUpToDate() async {
        let (controller, _) = controller(checker: .success(release("1.26")))
        await controller.check(manual: true)
        #expect(controller.state == .upToDate)
    }

    @Test func nothingInTheFeedIsUpToDate() async {
        let (controller, _) = controller(checker: .success(nil))
        await controller.check(manual: true)
        #expect(controller.state == .upToDate)
    }

    @Test func aManualCheckReportsAFailedRequest() async {
        let (controller, _) = controller(checker: .failure(.network))
        await controller.check(manual: true)
        #expect(controller.state == .failed(.network))
    }

    @Test func anAutomaticCheckKeepsQuietAboutAFailedRequest() async {
        let (controller, _) = controller(checker: .failure(.network))
        await controller.check(manual: false)
        #expect(controller.state == .idle)
    }

    @Test func aBuildFromSourceChecksNothing() async {
        let (controller, _) = controller(
            environment: environment(requirement: nil),
            checker: .success(release("1.27"))
        )
        #expect(!controller.canSelfUpdate)
        await controller.check(manual: true)
        #expect(controller.state == .idle)
    }

    @Test func aCheckLeavesItsTimeBehind() async {
        let defaults = freshDefaults()
        let (controller, _) = controller(checker: .success(release("1.27")), defaults: defaults)
        await controller.check(manual: true)
        #expect(defaults.object(forKey: "LastUpdateCheck") is Date)
    }

    // MARK: Бейдж

    @Test func aFoundReleaseLightsTheBadge() async {
        let (controller, _) = controller(checker: .success(release("1.27")))
        await controller.check(manual: true)
        #expect(controller.isBadgeVisible)
    }

    @Test func openingTheScreenPutsTheBadgeOut() async {
        let (controller, _) = controller(checker: .success(release("1.27")))
        await controller.check(manual: true)
        controller.present()
        #expect(controller.isPresented)
        #expect(!controller.isBadgeVisible)
    }

    @Test func laterKeepsTheBadgeOut() async {
        let (controller, _) = controller(checker: .success(release("1.27")))
        await controller.check(manual: true)
        controller.present()
        controller.close()
        #expect(!controller.isPresented)
        #expect(!controller.isBadgeVisible)
    }

    @Test func theNextReleaseLightsItAgain() async {
        let defaults = freshDefaults()
        let (seen, _) = controller(checker: .success(release("1.27")), defaults: defaults)
        await seen.check(manual: true)
        seen.present()

        let (next, _) = controller(checker: .success(release("1.28")), defaults: defaults)
        await next.check(manual: true)
        #expect(next.isBadgeVisible)
    }

    @Test func nothingFoundMeansNoBadge() async {
        let (controller, _) = controller(checker: .success(nil))
        await controller.check(manual: true)
        #expect(!controller.isBadgeVisible)
    }

    // MARK: Установка

    @Test func installingGoesThroughDownloadToTheScript() async {
        let dmg = URL(fileURLWithPath: "/tmp/Stash-1.27.dmg")
        let (controller, recorder) = controller(checker: .success(release("1.27")), downloader: .success(dmg))
        await controller.check(manual: true)
        await controller.runInstall()
        #expect(controller.state == .installing)
        #expect(recorder.installed == dmg)
        #expect(recorder.quits == 1)
    }

    @Test func aFolderWithoutWriteRightsStopsBeforeTheDownload() async {
        let (controller, recorder) = controller(
            environment: environment(writable: false),
            checker: .success(release("1.27"))
        )
        await controller.check(manual: true)
        await controller.runInstall()
        #expect(controller.state == .failed(.notWritable))
        #expect(recorder.installed == nil)
        #expect(recorder.quits == 0)
    }

    @Test func aBrokenDownloadIsReported() async {
        let (controller, recorder) = controller(
            checker: .success(release("1.27")),
            downloader: .failure(.network)
        )
        await controller.check(manual: true)
        await controller.runInstall()
        #expect(controller.state == .failed(.network))
        #expect(recorder.quits == 0)
    }

    @Test func aSignatureThatDoesNotMatchLeavesTheAppAlone() async {
        let (controller, recorder) = controller(
            checker: .success(release("1.27")),
            installFails: .signature("no match")
        )
        await controller.check(manual: true)
        await controller.runInstall()
        #expect(controller.state == .failed(.signature("no match")))
        #expect(recorder.quits == 0)
    }

    @Test func installingWithoutAReleaseDoesNothing() async {
        let (controller, recorder) = controller()
        await controller.runInstall()
        #expect(controller.state == .idle)
        #expect(recorder.quits == 0)
    }

    // MARK: Взвод первой проверки

    @Test func itDoesNotArmBeforeTheAppIsReady() {
        let (controller, _) = controller(ready: false)
        controller.armIfReady()
        #expect(!controller.isArmed)
    }

    @Test func itArmsOnceTheAppIsReady() {
        let (controller, _) = controller(ready: true)
        controller.armIfReady()
        #expect(controller.isArmed)
    }

    @Test func armingTwiceChangesNothing() {
        let (controller, _) = controller(ready: true)
        controller.armIfReady()
        controller.armIfReady()
        #expect(controller.isArmed)
    }

    @Test func automaticChecksSwitchedOffDoNotArm() {
        let (controller, _) = controller(ready: true)
        controller.isAutomatic = false
        controller.armIfReady()
        #expect(!controller.isArmed)
    }

    @Test func aBuildFromSourceNeverArms() {
        let (controller, _) = controller(environment: environment(requirement: nil), ready: true)
        controller.armIfReady()
        #expect(!controller.isArmed)
    }
}
```

- [ ] **Step 2: Прогнать тест и убедиться, что он падает**

Run: `swift test --filter UpdateControllerTests`
Expected: FAIL, `cannot find 'UpdateController' in scope`.

- [ ] **Step 3: Написать реализацию**

`Sources/BufferJournal/Updates/UpdateController.swift`:

```swift
import AppKit
import Combine
import Foundation

/// The whole of updating, as a handful of states the screen and the menu read.
///
/// The first check waits for the app to settle: on the very first launch that means the tour has
/// been walked through and Accessibility access is granted, so nothing competes with getting
/// started. After that it is once a day, and the menu can ask at any time.
@MainActor
final class UpdateController: ObservableObject {
    /// The release itself is kept beside the state, not inside it: downloading, installing and
    /// failed all still need to name the version and its notes.
    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available
        case downloading(Double)
        case installing
        case failed(UpdateError)
    }

    static let releasesPage = URL(string: "https://github.com/KiraMurano/stash/releases")!
    private static let seenVersionKey = "SeenUpdateVersion"

    @Published private(set) var state: State
    @Published private(set) var release: Release?
    @Published private(set) var isPresented = false
    private(set) var isArmed = false

    private let environment: UpdateEnvironment
    private let checker: any UpdateChecking
    private let downloader: any UpdateDownloading
    private let defaults: UserDefaults
    private let schedule: UpdateSchedule
    private let now: () -> Date
    private let isReady: @MainActor () -> Bool
    private let installStep: @MainActor (URL) throws -> Void
    private let quit: @MainActor () -> Void
    private var timers: [Timer] = []

    init(
        environment: UpdateEnvironment,
        checker: any UpdateChecking,
        downloader: any UpdateDownloading,
        defaults: UserDefaults = .standard,
        now: @escaping () -> Date = Date.init,
        isReady: @escaping @MainActor () -> Bool,
        install: (@MainActor (URL) throws -> Void)? = nil,
        quit: @escaping @MainActor () -> Void = { NSApp.terminate(nil) },
        // The snapshots put the screen straight into a state; the app leaves both alone.
        release: Release? = nil,
        state: State = .idle
    ) {
        self.release = release
        self.state = state
        self.environment = environment
        self.checker = checker
        self.downloader = downloader
        self.defaults = defaults
        self.schedule = UpdateSchedule(defaults: defaults)
        self.now = now
        self.isReady = isReady
        // By default the image is verified here, while the app is still on screen and can say so;
        // the install script checks it again once the app is gone.
        self.installStep = install ?? { dmg in
            if let requirement = environment.requirement {
                try Codesign.verify(dmg, requirement: requirement, deep: false)
            }
            try UpdateInstaller.launch(dmg: dmg, environment: environment)
        }
        self.quit = quit
    }

    // MARK: What the menu and the screen read

    var canSelfUpdate: Bool {
        environment.canSelfUpdate
    }

    var currentVersion: AppVersion? {
        environment.currentVersion
    }

    var isAutomatic: Bool {
        get { schedule.isAutomatic }
        set {
            objectWillChange.send()
            schedule.isAutomatic = newValue
        }
    }

    /// The orange dot on the status item: a release is waiting and its screen has not been opened.
    var isBadgeVisible: Bool {
        guard let release else { return false }
        return defaults.string(forKey: Self.seenVersionKey) != release.version.description
    }

    // MARK: Checking

    /// Called at launch, when access changes and when the tour closes. It arms the timers once
    /// per session, and only when the app has nothing more pressing to show.
    func armIfReady() {
        guard !isArmed, canSelfUpdate, schedule.isAutomatic, isReady() else { return }
        isArmed = true

        timers.append(Timer.scheduledTimer(withTimeInterval: UpdateSchedule.launchDelay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkIfDue() }
        })
        timers.append(Timer.scheduledTimer(withTimeInterval: UpdateSchedule.interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkIfDue() }
        })
    }

    private func checkIfDue() {
        guard schedule.isDue(now: now()) else { return }
        Task { await check(manual: false) }
    }

    /// The menu item.
    func checkNow() {
        Task { await check(manual: true) }
    }

    func check(manual: Bool) async {
        guard canSelfUpdate else { return }
        // A check while something is already happening would throw that away.
        switch state {
        case .idle, .upToDate, .available, .failed: break
        case .checking, .downloading, .installing: return
        }

        state = .checking
        schedule.lastCheck = now()

        do {
            let latest = try await checker.latestRelease()
            if let latest, environment.isNewer(latest) {
                release = latest
                state = .available
            } else {
                release = nil
                state = .upToDate
            }
        } catch let error as UpdateError {
            // An automatic check that failed says nothing: the next one is in a day.
            state = manual ? .failed(error) : .idle
        } catch {
            state = manual ? .failed(.network) : .idle
        }
    }

    // MARK: The screen

    /// Opening the screen counts as having seen this version, so the dot goes out even if the
    /// answer is "Later".
    func present() {
        if let release {
            defaults.set(release.version.description, forKey: Self.seenVersionKey)
        }
        isPresented = true
    }

    func close() {
        isPresented = false
    }

    func openReleasesPage() {
        NSWorkspace.shared.open(Self.releasesPage)
    }

    // MARK: Installing

    func install() {
        Task { await runInstall() }
    }

    func runInstall() async {
        guard let release else { return }
        guard environment.isDestinationWritable else {
            state = .failed(.notWritable)
            return
        }

        state = .downloading(0)

        do {
            let dmg = try await downloader.download(release) { [weak self] progress in
                Task { @MainActor in
                    guard let self, case .downloading = self.state else { return }
                    self.state = .downloading(progress)
                }
            }
            state = .installing
            try installStep(dmg)
            quit()
        } catch let error as UpdateError {
            state = .failed(error)
        } catch {
            state = .failed(.network)
        }
    }
}
```

- [ ] **Step 4: Прогнать тест и убедиться, что он проходит**

Run: `swift test --filter UpdateControllerTests`
Expected: PASS, 21 тест.

- [ ] **Step 5: Коммит**

```bash
git add Sources/BufferJournal/Updates/UpdateController.swift Tests/BufferJournalTests/UpdateControllerTests.swift
git commit -m "Drive the update from check to relaunch"
```

---

### Task 9: Экран обновления

**Files:**
- Modify: `Sources/BufferJournal/Localization.swift` (после `func characters`, и в `StatusMenuTitles`)
- Create: `Sources/BufferJournal/Updates/UpdateView.swift`
- Test: `Tests/BufferJournalTests/UpdateTextsTests.swift`, `Tests/BufferJournalTests/SnapshotTests.swift` (дополнить)

**Interfaces:**
- Consumes: `UpdateController` (Task 8), `ReleaseNotes` (Task 2), `OnboardingColors`, `OnboardingPrimaryButtonStyle`, `OnboardingCloseButtonStyle` (уже есть), `ThemePalette`, `WindowDragHandle`.
- Produces:
  - В `L10n`: `func megabytes(_ bytes: Int64) -> String`, `func updateCurrent(_ version: String, bytes: Int64) -> String`, `func updateDownloading(_ fraction: Double) -> String`, `var updateInstalling: String`, `var updateNow: String`, `var updateLater: String`, `var updateOpenReleases: String`, `func updateFailure(_ error: UpdateError) -> String`.
  - В `StatusMenuTitles`: `var checkForUpdates: String`, `var checkingForUpdates: String`, `func updateTo(_ version: String) -> String`, `var updateAutomatically: String`.
  - `struct UpdateView: View` с `init(controller: UpdateController, l10n: L10n)`.

- [ ] **Step 1: Написать падающий тест текстов**

`Tests/BufferJournalTests/UpdateTextsTests.swift`:

```swift
import Testing
@testable import BufferJournal

struct UpdateTextsTests {
    private let ru = L10n(language: .russian)
    private let en = L10n(language: .english)

    @Test func megabytesFollowTheLanguage() {
        #expect(ru.megabytes(4_404_019) == "4,2 МБ")
        #expect(en.megabytes(4_404_019) == "4.2 MB")
    }

    @Test func aSmallImageStillShowsAFraction() {
        #expect(en.megabytes(102_400) == "0.1 MB")
    }

    @Test func theFooterSaysWhatIsInstalledNow() {
        #expect(ru.updateCurrent("1.26", bytes: 4_404_019) == "Сейчас 1.26 · 4,2 МБ")
        #expect(en.updateCurrent("1.26", bytes: 4_404_019) == "Now 1.26 · 4.2 MB")
    }

    @Test func progressIsWholePercent() {
        #expect(ru.updateDownloading(0.404) == "Загрузка… 40 %")
        #expect(en.updateDownloading(1) == "Downloading… 100 %")
    }

    @Test func everyFailureHasItsOwnSentence() {
        #expect(ru.updateFailure(.network) != ru.updateFailure(.notWritable))
        #expect(ru.updateFailure(.signature("x")) != ru.updateFailure(.install("x")))
        #expect(!ru.updateFailure(.signature("x")).contains("x"))
    }

    @Test func theMenuNamesTheVersionItOffers() {
        #expect(StatusMenuTitles(l10n: ru).updateTo("1.27") == "Обновить до 1.27")
        #expect(StatusMenuTitles(l10n: en).updateTo("1.27") == "Update to 1.27")
    }
}
```

- [ ] **Step 2: Прогнать тест и убедиться, что он падает**

Run: `swift test --filter UpdateTextsTests`
Expected: FAIL, `value of type 'L10n' has no member 'megabytes'`.

- [ ] **Step 3: Дописать тексты**

В `Sources/BufferJournal/Localization.swift`, внутри `struct L10n` после `func characters(_:)`:

```swift
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
```

В `struct StatusMenuTitles`, после `var tutorial`:

```swift
    var checkForUpdates: String { l10n("Check for Updates…", "Проверить обновления…") }
    var checkingForUpdates: String { l10n("Checking for Updates…", "Проверяем обновления…") }
    func updateTo(_ version: String) -> String { l10n("Update to \(version)", "Обновить до \(version)") }
    var updateAutomatically: String { l10n("Check for Updates Automatically", "Проверять обновления автоматически") }
```

- [ ] **Step 4: Прогнать тест текстов и убедиться, что он проходит**

Run: `swift test --filter UpdateTextsTests`
Expected: PASS, 6 тестов.

- [ ] **Step 5: Написать экран**

`Sources/BufferJournal/Updates/UpdateView.swift`:

```swift
import AppKit
import SwiftUI

/// The update screen over the journal panel. It is built like the tutorial — same field, same
/// card, same orange button — with the version in the head row, the release notes in the card
/// and only the actions at the bottom (concept round 1, variant 1.2).
struct UpdateView: View {
    @ObservedObject var controller: UpdateController
    let l10n: L10n

    @Environment(\.colorScheme) private var colorScheme

    /// The tutorial's metrics, so the two screens line up to the pixel.
    private enum Metrics {
        static let top: CGFloat = 12
        static let side: CGFloat = 20
        static let bottom: CGFloat = 16
        static let gap: CGFloat = 10
        static let headHeight: CGFloat = 28
        static let cardRadius: CGFloat = 20
        static let buttonHeight: CGFloat = 36
        static let progressWidth: CGFloat = 220
        static let textSize: CGFloat = 13
        static let notesPadding: CGFloat = 18
        static let notesSpacing: CGFloat = 8
        /// The marker's column and the 12×3 bar inside it (concept round 3, variant 1.2.1.2).
        static let markColumn: CGFloat = 14
        static let markWidth: CGFloat = 12
        static let markHeight: CGFloat = 3
        /// One line of 13 pt text at line height 1.4.
        static let lineHeight: CGFloat = 18
        /// The title lockup, as on the access slide: a 21 pt icon before 18 pt semibold.
        static let titleSize: CGFloat = 18
        static let iconFrame: CGFloat = 21
    }

    private var colors: OnboardingColors {
        OnboardingColors(isDark: colorScheme == .dark)
    }

    /// Everything inside the card is drawn in the Stash style, whatever theme is picked.
    private var palette: ThemePalette {
        ThemePalette(colorScheme: colorScheme, solid: true)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            colors.field

            VStack(spacing: 0) {
                head
                card
                    .padding(.top, Metrics.gap)
                footer
                    .padding(.top, Metrics.gap)
            }
            .padding(.top, Metrics.top)
            .padding(.horizontal, Metrics.side)
            .padding(.bottom, Metrics.bottom)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(l10n("Stash update", "Обновление Stash"))
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
        // The head row moves the panel, like the journal's header and the tutorial's bars.
        .background(WindowDragHandle())
    }

    private var lockup: some View {
        let capHeight = NSFont.systemFont(ofSize: Metrics.titleSize, weight: .semibold).capHeight
        let version = controller.release.map { " \($0.version)" } ?? ""

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

    // MARK: Card

    private var card: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)

        return shape
            .fill(palette.windowBackground)
            .overlay(shape.fill(palette.sidebarTint))
            .overlay(shape.strokeBorder(palette.border, lineWidth: 1))
            .shadow(color: colors.cardShadow, radius: 16, y: 6)
            .overlay(notes.clipShape(shape))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var notes: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.notesSpacing) {
                ForEach(ReleaseNotes.parse(controller.release?.notes ?? "")) { note in
                    switch note.kind {
                    case .item: item(note.text)
                    case .paragraph: paragraph(note.text)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Metrics.notesPadding)
        }
    }

    private func item(_ text: String) -> some View {
        HStack(alignment: .top, spacing: Metrics.notesSpacing) {
            Capsule()
                .fill(ThemePalette.orange)
                .frame(width: Metrics.markWidth, height: Metrics.markHeight)
                .frame(width: Metrics.markColumn, height: Metrics.lineHeight, alignment: .leading)
                .accessibilityHidden(true)

            Text(Self.markdown(text))
                .font(.system(size: Metrics.textSize))
                .foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func paragraph(_ text: String) -> some View {
        Text(Self.markdown(text))
            .font(.system(size: Metrics.textSize, weight: .semibold))
            .foregroundStyle(palette.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
    }

    /// Bold, italics and links inside a line; the list itself was cut by ReleaseNotes.
    private static func markdown(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text)) ?? AttributedString(text)
    }

    // MARK: Footer

    private var footer: some View {
        HStack(alignment: .center, spacing: 16) {
            meta
            actions
        }
    }

    @ViewBuilder
    private var meta: some View {
        switch controller.state {
        case .failed(let error):
            Text(l10n.updateFailure(error))
                .font(.system(size: Metrics.textSize))
                .foregroundStyle(ThemePalette.solidDestructive)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        default:
            Text(current)
                .font(.system(size: Metrics.textSize))
                .foregroundStyle(palette.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var current: String {
        guard let version = controller.currentVersion else { return "" }
        return l10n.updateCurrent(version.description, bytes: controller.release?.size ?? 0)
    }

    @ViewBuilder
    private var actions: some View {
        switch controller.state {
        case .downloading(let progress):
            bar(l10n.updateDownloading(progress), fill: progress)
        case .installing:
            bar(l10n.updateInstalling, fill: 1)
        case .failed:
            primary(l10n.updateOpenReleases) { controller.openReleasesPage() }
        default:
            Button(l10n.updateLater) { controller.close() }
                .buttonStyle(OnboardingCloseButtonStyle(color: colors.close))
                .font(.system(size: Metrics.textSize, weight: .semibold))
                .padding(.horizontal, 12)
                .frame(height: Metrics.buttonHeight)

            primary(l10n.updateNow) { controller.install() }
        }
    }

    private func primary(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: Metrics.textSize, weight: .semibold))
                .padding(.horizontal, 16)
                .frame(minWidth: 150, minHeight: Metrics.buttonHeight, maxHeight: Metrics.buttonHeight)
        }
        .buttonStyle(OnboardingPrimaryButtonStyle(colors: colors))
    }

    private func bar(_ title: String, fill: Double) -> some View {
        let shape = Capsule()

        return shape
            .fill(colors.barTrack)
            .overlay(alignment: .leading) {
                shape
                    .fill(ThemePalette.orange)
                    .frame(width: Metrics.progressWidth * min(max(fill, 0), 1))
            }
            .clipShape(shape)
            .overlay {
                Text(title)
                    .font(.system(size: Metrics.textSize, weight: .semibold))
                    .foregroundStyle(Color.white)
            }
            .frame(width: Metrics.progressWidth, height: Metrics.buttonHeight)
            .accessibilityLabel(title)
    }
}
```

- [ ] **Step 6: Дописать снимки**

В `Tests/BufferJournalTests/SnapshotTests.swift`, в конец структуры `SnapshotTests`:

```swift
    /// Контроллер обновления в нужном состоянии, без сети и без установки.
    private func updateController(_ state: UpdateController.State) -> UpdateController {
        struct Checker: UpdateChecking {
            func latestRelease() async throws -> Release? { nil }
        }
        struct Downloader: UpdateDownloading {
            func download(_ release: Release, onProgress: @escaping @Sendable (Double) -> Void) async throws -> URL {
                throw UpdateError.network
            }
        }

        let release = Release(
            version: AppVersion(major: 1, minor: 27),
            notes: """
            - Журнал открывается у текстового курсора, как Win+V: под ним, а если внизу нет места — над ним.
            - Клавиши ↑, ↓, Return и Esc достаются журналу, пока он открыт.
            - Короткое знакомство при первом запуске: пять слайдов внутри панели.
            - Картинка из журнала открывается в «Просмотре» по клику на миниатюре.
            - Stash обновляется сам: проверяет раз в сутки и ставит новую версию по кнопке.
            Подпись приложения сменилась, поэтому Универсальный доступ нужно выдать один раз заново.
            """,
            dmgURL: URL(string: "https://example.invalid/Stash-1.27.dmg")!,
            size: 4_404_019
        )

        return UpdateController(
            environment: UpdateEnvironment(
                currentVersion: AppVersion(major: 1, minor: 26),
                requirement: "req",
                bundleURL: URL(fileURLWithPath: "/Applications/Stash.app"),
                isDestinationWritable: true
            ),
            checker: Checker(),
            downloader: Downloader(),
            defaults: defaults(),
            isReady: { true },
            install: { _ in },
            quit: {},
            release: release,
            state: state
        )
    }

    @Test func theUpdateScreenRenders() throws {
        let states: [(UpdateController.State, String)] = [
            (.available, "available"),
            (.downloading(0.4), "downloading"),
            (.installing, "installing"),
            (.failed(.signature("x")), "failed"),
        ]

        for (state, name) in states {
            for (scheme, schemeName) in Self.schemes {
                for size in Self.sizes {
                    let view = UpdateView(controller: updateController(state), l10n: L10n(language: .russian))
                        .frame(width: size.width, height: size.height)
                        .preferredColorScheme(scheme)
                    try render(view, name: "update-\(name)-\(schemeName)-\(Int(size.width))")
                }
            }
        }
    }
```

- [ ] **Step 7: Прогнать снимки и посмотреть на них**

Run: `SNAPSHOT_DIR=/tmp/stash-update swift test --filter SnapshotTests`
Expected: PASS. Открыть `/tmp/stash-update` и сверить с концептом: палка маркера 12×3 в колонке 14, текст чёрный, версия в шапке, футер 36 pt, на панели 560×360 заметки уходят под прокрутку.

- [ ] **Step 8: Коммит**

```bash
git add Sources/BufferJournal/Localization.swift Sources/BufferJournal/Updates/UpdateView.swift Sources/BufferJournal/Updates/UpdateController.swift Tests/BufferJournalTests/UpdateTextsTests.swift Tests/BufferJournalTests/SnapshotTests.swift
git commit -m "Show the update, its notes and its progress in the panel"
```

---

### Task 10: Точка на значке в строке меню

**Files:**
- Create: `Sources/BufferJournal/Updates/StatusItemBadge.swift`
- Test: `Tests/BufferJournalTests/StatusItemBadgeTests.swift`

**Interfaces:**
- Consumes: ничего из предыдущих задач.
- Produces: `@MainActor final class StatusItemBadge` с `init(button: NSStatusBarButton)`, `var isVisible: Bool { get set }` и чистыми `static func glyphRect(in bounds: CGRect, imageSize: CGSize) -> CGRect`, `static func dotRect(glyph: CGRect) -> CGRect`, `static let diameter: CGFloat = 5`.

- [ ] **Step 1: Написать падающий тест**

`Tests/BufferJournalTests/StatusItemBadgeTests.swift`:

```swift
import AppKit
import Testing
@testable import BufferJournal

@MainActor
struct StatusItemBadgeTests {
    private let bounds = CGRect(x: 0, y: 0, width: 26, height: 22)
    private let glyph = CGSize(width: 14, height: 18)

    @Test func theGlyphSitsInTheMiddleOfTheButton() {
        let rect = StatusItemBadge.glyphRect(in: bounds, imageSize: glyph)
        #expect(rect == CGRect(x: 6, y: 2, width: 14, height: 18))
    }

    @Test func theDotHangsOnTheTopRightCorner() {
        // Концепт, раунд 2, вариант 2.1.2: перекрытие 3×3, за правым краем 2.
        let rect = StatusItemBadge.dotRect(glyph: StatusItemBadge.glyphRect(in: bounds, imageSize: glyph))
        #expect(rect.width == 5 && rect.height == 5)
        #expect(rect.maxX == 22)   // 20 — правый край значка, плюс 2 наружу
        #expect(rect.maxY == 22)   // 20 — верх значка, плюс 2 наружу
    }

    @Test func theOverlapIsThreeByThree() {
        let glyphRect = StatusItemBadge.glyphRect(in: bounds, imageSize: glyph)
        let dot = StatusItemBadge.dotRect(glyph: glyphRect)
        #expect(dot.intersection(glyphRect).size == CGSize(width: 3, height: 3))
    }

    @Test func aWiderButtonKeepsTheDotOnTheGlyph() {
        let wide = CGRect(x: 0, y: 0, width: 40, height: 22)
        let glyphRect = StatusItemBadge.glyphRect(in: wide, imageSize: glyph)
        let dot = StatusItemBadge.dotRect(glyph: glyphRect)
        #expect(dot.intersection(glyphRect).size == CGSize(width: 3, height: 3))
        #expect(dot.maxX == glyphRect.maxX + 2)
    }

    @Test func theDotIsHiddenUntilItIsAskedFor() throws {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        defer { NSStatusBar.system.removeStatusItem(item) }
        let button = try #require(item.button)

        let badge = StatusItemBadge(button: button)
        #expect(!badge.isVisible)
        badge.isVisible = true
        #expect(badge.isVisible)
    }
}
```

- [ ] **Step 2: Прогнать тест и убедиться, что он падает**

Run: `swift test --filter StatusItemBadgeTests`
Expected: FAIL, `cannot find 'StatusItemBadge' in scope`.

- [ ] **Step 3: Написать реализацию**

`Sources/BufferJournal/Updates/StatusItemBadge.swift`:

```swift
import AppKit

/// The orange dot over the status item while an update waits to be looked at.
///
/// The status icon is a template image: macOS paints it black or white to match the menu bar, and
/// an orange dot composited into it would lose that. So the dot is a layer of its own over the
/// untouched glyph.
@MainActor
final class StatusItemBadge {
    static let diameter: CGFloat = 5
    /// How far the dot hangs past the glyph's top right corner (concept round 2, variant 2.1.2).
    private static let overhang: CGFloat = 2

    /// The image sits in the middle of the button, whatever width the button ends up with.
    static func glyphRect(in bounds: CGRect, imageSize: CGSize) -> CGRect {
        CGRect(
            x: ((bounds.width - imageSize.width) / 2).rounded(),
            y: ((bounds.height - imageSize.height) / 2).rounded(),
            width: imageSize.width,
            height: imageSize.height
        )
    }

    /// Half on the corner: 3×3 over the glyph, 2 pt out of it on each side.
    static func dotRect(glyph: CGRect) -> CGRect {
        CGRect(
            x: glyph.maxX + overhang - diameter,
            y: glyph.maxY + overhang - diameter,
            width: diameter,
            height: diameter
        )
    }

    /// Fills the button and keeps the dot on the glyph's corner through every relayout.
    private final class Container: NSView {
        let dot = NSView()
        var imageSize = CGSize(width: 14, height: 18)

        override init(frame: NSRect) {
            super.init(frame: frame)
            wantsLayer = true
            dot.wantsLayer = true
            dot.layer?.backgroundColor = NSColor(
                red: 244 / 255, green: 106 / 255, blue: 37 / 255, alpha: 1
            ).cgColor
            dot.layer?.cornerRadius = StatusItemBadge.diameter / 2
            addSubview(dot)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("not used") }

        override func layout() {
            super.layout()
            dot.frame = StatusItemBadge.dotRect(glyph: StatusItemBadge.glyphRect(in: bounds, imageSize: imageSize))
        }

        // The dot is decoration: every click goes to the button under it.
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }

    private let container = Container()

    init(button: NSStatusBarButton) {
        container.frame = button.bounds
        container.autoresizingMask = [.width, .height]
        container.imageSize = button.image?.size ?? CGSize(width: 14, height: 18)
        container.isHidden = true
        button.addSubview(container)
    }

    var isVisible: Bool {
        get { !container.isHidden }
        set {
            container.isHidden = !newValue
            container.needsLayout = true
        }
    }
}
```

- [ ] **Step 4: Прогнать тест и убедиться, что он проходит**

Run: `swift test --filter StatusItemBadgeTests`
Expected: PASS, 5 тестов.

- [ ] **Step 5: Коммит**

```bash
git add Sources/BufferJournal/Updates/StatusItemBadge.swift Tests/BufferJournalTests/StatusItemBadgeTests.swift
git commit -m "Mark the status icon while an update waits"
```

---

### Task 11: Подключение к приложению

**Files:**
- Modify: `Sources/BufferJournal/JournalKeys.swift:44-47` (`PanelContent`), `:64-70` (`mode`)
- Modify: `Sources/BufferJournal/JournalView.swift:44` (свойство), `:151-160` (слой), `:178` (анимация)
- Modify: `Sources/BufferJournal/JournalPanelController.swift:27-56` (зависимость и наблюдатель), `:112-133` (показ), `:216-222` (`panelContent`), `:239-243` (клики мимо), `:275` (передача во вью)
- Modify: `Sources/BufferJournal/AppDelegate.swift:9-56` (создание), `:66-125` (меню), `:127-175` (действия)
- Test: `Tests/BufferJournalTests/JournalKeysTests.swift` (дополнить)

**Interfaces:**
- Consumes: `UpdateController`, `UpdateView`, `StatusItemBadge`, `UpdateFailureMarker`, `StatusMenuTitles`.
- Produces: ничего нового наружу.

- [ ] **Step 1: Написать падающий тест клавиш**

В `Tests/BufferJournalTests/JournalKeysTests.swift` дописать:

```swift
    @Test func theUpdateScreenLeavesEveryKeyToTheAppUnderneath() {
        let mode = JournalKeys.mode(
            intercepts: true,
            panelVisible: true,
            content: .update,
            stashActive: false,
            menuOpen: false
        )
        #expect(mode == .off)
    }
```

- [ ] **Step 2: Прогнать тест и убедиться, что он падает**

Run: `swift test --filter JournalKeysTests`
Expected: FAIL, `type 'JournalKeys.PanelContent' has no member 'update'`.

- [ ] **Step 3: Добавить случай в клавиши**

В `Sources/BufferJournal/JournalKeys.swift`, в `enum PanelContent`:

```swift
        case journal
        case onboarding
        case access
        /// The update screen: like the tutorial, it takes no keys at all.
        case update
```

и в `mode`:

```swift
        switch content {
        case .journal: return .journal
        case .onboarding, .access, .update: return .off
        }
```

- [ ] **Step 4: Прогнать тест и убедиться, что он проходит**

Run: `swift test --filter JournalKeysTests`
Expected: PASS.

- [ ] **Step 5: Подключить слой к журналу**

В `Sources/BufferJournal/JournalView.swift` рядом с `@ObservedObject var onboarding`:

```swift
    @ObservedObject var updates: UpdateController
```

в `ZStack`, между тостом и обучением (обучение остаётся сверху — тур важнее):

```swift
            // The update screen covers the journal; the tutorial, if it is up, covers both.
            if updates.isPresented {
                UpdateView(controller: updates, l10n: l10n)
                    .transition(.opacity)
                    .zIndex(35)
            }
```

и в цепочке модификаторов, рядом с анимацией обучения:

```swift
        .animation(.easeOut(duration: 0.2), value: updates.isPresented)
```

- [ ] **Step 6: Подключить к контроллеру панели**

В `Sources/BufferJournal/JournalPanelController.swift`:

```swift
    private let updates: UpdateController
    private var updatesObserver: AnyCancellable?
```

в `init` — параметр `updates: UpdateController` после `onboarding`, присваивание `self.updates = updates`, и рядом с `onboardingObserver`:

```swift
        updatesObserver = updates.objectWillChange.sink { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updateKeys()
                self?.updateOutsideClicks()
            }
        }
```

новый метод рядом с `showOnboarding(replay:)`:

```swift
    /// The menu item: the update screen comes up on the panel, wherever the panel opens.
    func showUpdate() {
        updates.present()
        show()
    }
```

в `panelContent` — перед разбором обучения:

```swift
    private var panelContent: JournalKeys.PanelContent {
        if updates.isPresented, !onboarding.isPresented {
            return .update
        }
        guard onboarding.isPresented else {
            return access.isGranted ? .journal : .access
        }
        return onboarding.slide.kind == .access ? .access : .onboarding
    }
```

в `makePanelIfNeeded` — `updates: updates,` в списке параметров `JournalView`.

Клики мимо уже завязаны на `panelContent == .journal`, поэтому экран обновления сам собой перестаёт закрываться по клику снаружи — как тур. Отдельной правки это не требует.

- [ ] **Step 7: Подключить к меню и значку**

В `Sources/BufferJournal/AppDelegate.swift` — поля:

```swift
    private var updates: UpdateController!
    private var badge: StatusItemBadge!
    private var updatesObserver: AnyCancellable?
    private var updateItem: NSMenuItem!
    private var updateAutomaticallyItem: NSMenuItem!
```

в `applicationDidFinishLaunching`, после `onboarding`:

```swift
        let environment = UpdateEnvironment.current()
        updates = UpdateController(
            environment: environment,
            checker: GitHubUpdateChecker(),
            downloader: FileUpdateDownloader(),
            isReady: { [weak self] in
                guard let self else { return false }
                // The first check waits for the app to settle: the tour walked through, access
                // granted, the journal on the panel instead of a screen that asks for something.
                return !self.onboarding.shouldShowOnLaunch && self.access.isGranted && !self.onboarding.isPresented
            }
        )
```

`panelController` получает `updates: updates,`. После `configureStatusItem()` и `monitor.start()`:

```swift
        updatesObserver = updates.objectWillChange.sink { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updateStateChanged()
            }
        }

        // A swap that went wrong after the app had quit leaves a line behind; it is shown once.
        if let failure = UpdateFailureMarker.take() {
            NSLog("Stash update failed: \(failure)")
        }

        updates.armIfReady()
```

и в конце `applicationDidFinishLaunching`, после показа обучения или экрана доступа, ничего больше не нужно: `armIfReady()` зовётся ещё раз из наблюдателей.

В `configureStatusItem`, после `statusItem.button?.image = icon`:

```swift
        if let button = statusItem.button {
            badge = StatusItemBadge(button: button)
        }
```

В `rebuildMenu`, после `openAtCaretItem`:

```swift
        // Скрыт в сборке из исходников: обновлять там нечего.
        if updates.canSelfUpdate {
            updateAutomaticallyItem = menuItem(titles.updateAutomatically, action: #selector(toggleAutomaticUpdates))
            menu.addItem(updateAutomaticallyItem)
        }
```

и перед `titles.tutorial`:

```swift
        if updates.canSelfUpdate {
            updateItem = menuItem(titles.checkForUpdates, action: #selector(openUpdates))
            menu.addItem(updateItem)
        }
```

Действия и состояние:

```swift
    /// One menu item for both jobs: with a release in hand it opens the screen, without one it
    /// asks GitHub and opens the screen if the answer is a new version. Nothing pops up on its
    /// own — the panel only ever comes up because the person asked for it.
    @objc private func openUpdates() {
        guard updates.release == nil else {
            panelController.showUpdate()
            return
        }

        Task {
            await updates.check(manual: true)
            if updates.release != nil {
                panelController.showUpdate()
            }
        }
    }

    @objc private func toggleAutomaticUpdates() {
        updates.isAutomatic.toggle()
        updateSettingsMenuState()
        updates.armIfReady()
    }

    /// The menu item says what the updater is doing, and the dot follows the controller.
    private func updateStateChanged() {
        badge?.isVisible = updates.isBadgeVisible
        let titles = StatusMenuTitles(l10n: settings.l10n)

        switch updates.state {
        case .checking:
            updateItem?.title = titles.checkingForUpdates
            updateItem?.isEnabled = false
        case .available, .downloading, .installing:
            updateItem?.title = updates.release.map { titles.updateTo($0.version.description) } ?? titles.checkForUpdates
            updateItem?.isEnabled = true
        case .idle, .upToDate, .failed:
            updateItem?.title = titles.checkForUpdates
            updateItem?.isEnabled = true
        }
    }
```

В `updateSettingsMenuState` дописать:

```swift
        updateAutomaticallyItem?.state = updates.isAutomatic ? .on : .off
```

`armIfReady()` зовётся ещё из двух мест — там, где приложение приходит в рабочее состояние: когда выдают Универсальный доступ и когда закрывают тур. Оба события уже проходят через `JournalPanelController`, поэтому он получает в `init` колбэк:

```swift
    /// Called when the panel's content settles — access granted, tutorial closed — so the updater
    /// can arm its first check.
    private let onContentSettled: () -> Void
```

Он вызывается последней строкой `accessChanged()` и в обработчике `onboardingObserver`, а `AppDelegate` передаёт `onContentSettled: { [weak self] in self?.updates.armIfReady() }`.

- [ ] **Step 8: Собрать, прогнать тесты, проверить руками**

Run: `swift build && swift test`
Expected: PASS, все тесты.

Run: `Scripts/build_app.sh && open .build/Stash.app`
Проверить: меню значка показывает «Проверить обновления…» и «Проверять обновления автоматически» (галочка стоит). Пункт обновления в сборке без версии скрыт — значит, `canSelfUpdate` ложно, и это ожидаемо до задачи 12.

- [ ] **Step 9: Коммит**

```bash
git add Sources/BufferJournal Tests/BufferJournalTests/JournalKeysTests.swift
git commit -m "Put the update screen and its menu items into the app"
```

---

### Task 12: Релизная подпись и требование

**Files:**
- Modify: `Scripts/build_app.sh:24-27`
- Modify: `Scripts/make_dmg.sh:20-22`
- Modify: `Info.plist` (ничего не добавляем: ключ пишет сборка)

**Interfaces:**
- Consumes: ключ `StashUpdateRequirement`, который читает `UpdateEnvironment.current()` (Task 3).
- Produces: бандл и образ, подписанные одной идентичностью, и требование в `Info.plist`.

- [ ] **Step 1: Создать сертификат (один раз, руками)**

Keychain Access → меню Keychain Access → Certificate Assistant → Create a Certificate:

- Name: `Stash Updates`
- Identity Type: Self Signed Root
- Certificate Type: **Code Signing**
- Галочку «Let me override defaults» не ставить.

Проверить:

```bash
security find-certificate -c "Stash Updates" -Z | grep "SHA-1 hash:"
```

Expected: строка вида `SHA-1 hash: 3A7F…`. Пусто — сертификат не создан, дальше идти нельзя.

- [ ] **Step 2: Научить сборку подписывать идентичностью**

В `Scripts/build_app.sh` заменить строку `codesign --force --deep --sign - "$APP_DIR"` на:

```bash
# Stash is signed with a self-signed certificate, not a Developer ID. Gatekeeper still knows
# nothing about it, but the requirement below stays the same from build to build — so updates can
# be verified, and macOS keeps the Accessibility permission across them instead of treating every
# build as a new app.
IDENTITY="${STASH_SIGNING_IDENTITY:-Stash Updates}"
HASH="$(security find-certificate -c "$IDENTITY" -Z 2>/dev/null | awk '/SHA-1 hash:/ { print $3 }' | head -1)"

if [[ -n "$HASH" ]]; then
    REQUIREMENT="identifier \"local.buffer-journal\" and certificate leaf H\"$HASH\""
    /usr/libexec/PlistBuddy -c "Add :StashUpdateRequirement string $REQUIREMENT" "$CONTENTS_DIR/Info.plist"
    codesign --force --deep --sign "$IDENTITY" "$APP_DIR"
else
    echo "warning: no '$IDENTITY' certificate in the keychain; signing ad hoc." >&2
    echo "warning: this build will not offer updates. See README, \"Signing\"." >&2
    codesign --force --deep --sign - "$APP_DIR"
fi
```

Ключ пишется **до** подписи: он часть подписываемого бандла.

- [ ] **Step 3: Научить образ подписываться тем же**

В `Scripts/make_dmg.sh` после строки с `dmgbuild`, перед `echo "$DMG"`:

```bash
# The image carries the app's identifier on purpose, so one requirement checks both the image and
# the bundle inside it.
IDENTITY="${STASH_SIGNING_IDENTITY:-Stash Updates}"
if security find-certificate -c "$IDENTITY" >/dev/null 2>&1; then
    codesign --force --sign "$IDENTITY" --identifier local.buffer-journal "$DMG"
else
    codesign --force --sign - --identifier local.buffer-journal "$DMG"
fi
```

- [ ] **Step 4: Собрать и проверить, что требование на месте**

```bash
Scripts/build_app.sh 1.27
/usr/libexec/PlistBuddy -c "Print :StashUpdateRequirement" .build/Stash.app/Contents/Info.plist
codesign -d -r- .build/Stash.app
codesign -v --deep --strict -R="$(/usr/libexec/PlistBuddy -c 'Print :StashUpdateRequirement' .build/Stash.app/Contents/Info.plist)" .build/Stash.app
```

Expected: PlistBuddy печатает требование с хешем сертификата; `codesign -d -r-` показывает `designated => identifier "local.buffer-journal" and certificate leaf H"…"` с тем же хешем; последняя команда завершается без вывода и с кодом 0.

- [ ] **Step 5: Проверить, что образ тоже сходится**

```bash
Scripts/make_dmg.sh 1.27
codesign -v --strict -R="$(/usr/libexec/PlistBuddy -c 'Print :StashUpdateRequirement' .build/Stash.app/Contents/Info.plist)" .build/Stash-1.27.dmg
```

Expected: код 0.

- [ ] **Step 6: Проверить, что сборка без сертификата не падает**

```bash
STASH_SIGNING_IDENTITY="No Such Certificate" Scripts/build_app.sh 1.27
```

Expected: два предупреждения в stderr, бандл собран, ключа `StashUpdateRequirement` в нём нет, `swift build && swift test` по-прежнему проходят.

- [ ] **Step 7: Проверить, что приложение видит своё требование**

```bash
Scripts/build_app.sh 1.27 && open .build/Stash.app
```

Expected: в меню значка появились «Проверять обновления автоматически» и «Проверить обновления…» — значит, `UpdateEnvironment.canSelfUpdate` стало истинным.

- [ ] **Step 8: Коммит**

```bash
git add Scripts/build_app.sh Scripts/make_dmg.sh
git commit -m "Sign releases with a stable certificate and record its requirement"
```

---

### Task 13: Выпуск релиза и документация

**Files:**
- Modify: `Scripts/release.sh:26-36`
- Create: `docs/releases/.gitkeep`
- Modify: `README.md` (разделы Install, Versioning; новый раздел Updates)

**Interfaces:**
- Consumes: `Scripts/build_app.sh`, `Scripts/make_dmg.sh` (Task 12).
- Produces: релиз с человеческими заметками и их копией в `docs/releases/`.

- [ ] **Step 1: Сделать заметки обязательными**

В `Scripts/release.sh` после `cd "$ROOT_DIR"` добавить:

```bash
NOTES="${1:-}"
if [[ -z "$NOTES" || ! -f "$NOTES" ]]; then
    echo "Usage: Scripts/release.sh <release notes file>" >&2
    echo "The notes are shown inside the app, so a generated list of commits will not do." >&2
    exit 1
fi
```

и заменить хвост скрипта (от `git tag -a` до конца) на:

```bash
# The notes are kept with the code: they are what the update screen shows, and a release page can
# be edited afterwards while this copy stays as it shipped.
mkdir -p docs/releases
cp "$NOTES" "docs/releases/$TAG.md"
git add "docs/releases/$TAG.md"
git commit -m "Release notes for Stash $VERSION"
git push origin HEAD

git tag -a "$TAG" -m "Stash $VERSION"
git push origin "$TAG"

gh release create "$TAG" "$DMG" --title "Stash $VERSION" --notes-file "$NOTES"
```

Комментарий в шапке скрипта дополнить: `Usage: Scripts/release.sh <release notes file>`.

- [ ] **Step 2: Завести папку заметок**

```bash
mkdir -p docs/releases && touch docs/releases/.gitkeep
```

- [ ] **Step 3: Проверить, что без заметок скрипт не идёт**

```bash
Scripts/release.sh
```

Expected: две строки в stderr, код 1, ни тега, ни сборки.

- [ ] **Step 4: Дописать README**

В разделе `## Install` заменить последнее предложение абзаца (`The app is signed ad hoc, so macOS treats every update as a new app: …`) на:

```markdown
Stash is signed with a self-signed certificate, so its identity stays the same from release to release and the Accessibility permission survives an update. The one exception is the release that introduced updating: the signature changed with it, so that permission has to be granted once more — remove the old Stash entry from the list with − and click Open Settings again.
```

Новый раздел после `## Install`:

```markdown
## Updates

Stash checks GitHub for a new release ten seconds after it has settled — on the very first launch that means after the tour and after Accessibility access is granted — and once a day after that. A new version lights an orange dot on the menu bar icon and turns `Check for Updates…` into `Update to 1.27`; nothing pops up over what you are typing. The menu item opens a screen inside the panel with the release notes and a button that downloads the image, checks its signature, replaces the app and relaunches it. `Check for Updates Automatically` in the same menu turns the daily check off; the menu item still works by hand.

A build made from source carries no release signature, so it offers no updates and both menu items are hidden.
```

В разделе `## Versioning` заменить блок про `Scripts/release.sh` на:

```markdown
Versions are `MAJOR.MINOR`. `MAJOR` is set by hand in the `VERSION` file. `MINOR` is a running release counter: every release takes the next number and it is not reset when `MAJOR` changes (0.25 → 1.26). Write the release notes first — they are shown inside the app, so they are sentences for a person, not a list of commits — then publish:

```bash
Scripts/release.sh docs/releases/v1.27.md
```

The notes file is required. `release.sh` copies it into `docs/releases/`, commits it, tags the release and uploads the DMG.
```

Новый раздел после `## Build`:

```markdown
### Signing

Releases are signed with a self-signed certificate named `Stash Updates`, not with an Apple Developer ID. It is free, and it is what keeps the app's identity — and with it the Accessibility permission — the same from build to build. Create it once in Keychain Access → Certificate Assistant → Create a Certificate: name `Stash Updates`, identity type Self Signed Root, certificate type Code Signing.

`Scripts/build_app.sh` signs with it, writes the matching requirement into the bundle as `StashUpdateRequirement`, and the updater checks every download against that requirement. Without the certificate the script warns and signs ad hoc, as before; such a build runs but offers no updates. Another name can be given with `STASH_SIGNING_IDENTITY`.

The app is still not notarized, so a DMG downloaded by hand is still blocked on first launch — the Install section says what to do about it.
```

- [ ] **Step 5: Прогнать всё и собрать приложение**

Run: `swift build && swift test && Scripts/build_app.sh 1.27`
Expected: PASS, бандл собран.

- [ ] **Step 6: Коммит**

```bash
git add Scripts/release.sh docs/releases README.md
git commit -m "Require human release notes and document updating"
```

---

## Ручная проверка после всего плана

То, ради чего затевался сертификат, машине не проверить. Порядок такой:

1. Собрать и поставить версию 1.27: `Scripts/build_app.sh 1.27`, скопировать `.build/Stash.app` в `/Applications`, выдать Универсальный доступ, убедиться, что вставка работает.
2. Выпустить 1.28 с заметками: `Scripts/release.sh docs/releases/v1.28.md`.
3. В установленном 1.27 открыть меню значка → `Проверить обновления…`. Ожидается: точка на значке, пункт становится `Обновить до 1.28`, экран показывает заметки.
4. Нажать `Обновить и перезапустить`. Ожидается: полоска загрузки, затем установки, приложение исчезает и возвращается версией 1.28.
5. **Главное:** нажать ⌥V и вставить клип. Ожидается: вставка работает, Универсальный доступ заново не спрашивают, в списке Универсального доступа одна строка Stash, а не две.
6. Проверить, что мусора не осталось: `ls /Applications | grep -i stash` — только `Stash.app`, без `.update-old` и `.update-new`.

Если на шаге 5 доступ слетел — требование всё-таки изменилось между сборками. Сравнить `codesign -d -r-` у обеих версий; расхождение будет в хеше сертификата, значит, сборки подписаны разными сертификатами.

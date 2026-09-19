# Журнал без фокуса — план реализации

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Панель журнала не забирает клавиатуру, поиска нет. Пока журнал открыт, ↑, ↓, Return и Esc приходят ему глобальными хоткеями. Выбор клипа всегда вставляет, рядом кнопка «Скопировать в буфер». Без Универсального доступа панель показывает экран доступа.

**Architecture:** Панель снова неключевая (`canBecomeKey = false`), как до `c537e93`. Клавиши журнала — хоткеи Carbon без модификаторов. `HotKeyController` становится реестром хоткеев. `JournalKeys` включает их по правилу `shouldListen`, повторяет ↑ и ↓ таймером и отдаёт нажатия издателем. `JournalView` исполняет нажатия по чистой функции `JournalKeyAction.resolve`. Доступ держит `AccessGate` (`AXIsProcessTrusted()` и проверка раз в секунду); без доступа `JournalView` показывает `AccessScreen`.

**Tech Stack:** Swift 6 (swift-tools-version 6.0, строгая конкурентность), SwiftUI + AppKit, Carbon (`RegisterEventHotKey`), Combine (`PassthroughSubject`), SwiftPM, Swift Testing (Xcode 26), macOS 13+.

## Global Constraints

- Спека: `docs/superpowers/specs/2026-09-19-journal-without-focus-design.md`.
- Система — от macOS 13 (`.macOS(.v13)`): `onChange` только в старой форме `onChange(of:perform:)`; всё, что появилось в macOS 14 и новее, — только через `#available`.
- Swift 6: всё, что трогает AppKit, живёт на главном акторе. Колбэки Carbon, `Timer` и `NotificationCenter` приходят на главный поток и входят в актор через `MainActor.assumeIsolated`.
- Комментарии в коде и коммиты — по-английски, как в репозитории.
- Тексты интерфейса на двух языках берутся дословно из спеки.
- После каждой задачи: `swift build` и `swift test`. Приложение собирается `Scripts/build_app.sh` в `.build/Stash.app`.
- Тестовая сборка делит с установленным Stash настройки (домен `local.buffer-journal`) и папку истории, а ⌥V может держать только одна копия. Поэтому на время проверки установленный Stash нужно закрыть.
- Универсальный доступ выдаёт и снимает только пользователь. Сборка подписана ad-hoc, поэтому каждой новой сборке доступ нужен заново: старую строку Stash удалить кнопкой «−» и добавить новую.
- Хоткеи в тестах не регистрируются: пока тест идёт, они отняли бы у пользователя стрелки, Return и Esc.
- Проверено на macOS 26.5.2 синтетическими нажатиями в собственное окно пробника. ↑, ↓, Return, Enter цифрового блока и Esc без модификаторов регистрируются, срабатывают и до переднего окна не доходят; ⇧↓ доходит. Автоповторы удерживаемого хоткея macOS глотает и повторных нажатий не присылает. Enter, набранный как fn+Return на ноутбуке, хоткей не ловит, и он уходит в приложение — так и оставляем.

## Карта файлов

| Файл | Ответственность |
|---|---|
| `Package.swift` | тестовая цель `BufferJournalTests` |
| `Sources/BufferJournal/HotKeyController.swift` | реестр глобальных хоткеев Carbon: нажатие и отпускание |
| `Sources/BufferJournal/JournalKeys.swift` | клавиши журнала: `JournalKey`, `JournalKeyAction.resolve`, хоткеи с повтором, правило `shouldListen` |
| `Sources/BufferJournal/AccessibilityAccess.swift` | `AccessibilityAccess` (проверка и запрос) и `AccessGate` (состояние доступа для панели) |
| `Sources/BufferJournal/AccessScreen.swift` | экран доступа |
| `Sources/BufferJournal/JournalPanelController.swift` | неключевая панель, включение хоткеев, вставка и копирование, доступ |
| `Sources/BufferJournal/JournalView.swift` | журнал без поиска, клавиши из хоткеев, кнопка копирования, экран доступа вместо журнала |
| `Sources/BufferJournal/AppDelegate.swift` | ⌥V через реестр, меню без «Вставлять при выборе», делегат меню, показ при запуске без доступа |
| `Sources/BufferJournal/AppSettings.swift` | без `pasteOnSelection` |
| `Sources/BufferJournal/ClipboardWriter.swift` | вставка без запроса доступа |
| `README.md` | клавиши, вставка и копирование, обязательный доступ |
| `Tests/BufferJournalTests/…` | правила клавиш, правило хоткеев, `AccessGate` |

---

### Task 1: Тестовая цель и правила клавиш журнала

**Files:**
- Modify: `Package.swift`
- Create: `Sources/BufferJournal/JournalKeys.swift`
- Test: `Tests/BufferJournalTests/JournalKeyActionTests.swift`

**Interfaces:**
- Produces: тестовая цель `BufferJournalTests` на Swift Testing (`import Testing`, `@testable import BufferJournal`), запуск — `swift test`.
- Produces: `enum JournalKey: Equatable { case up, down, enter, escape }`.
- Produces: `enum JournalKeyAction: Equatable { case moveUp, moveDown, paste, closeDialog, closePanel, ignore }` и `static func resolve(_ key: JournalKey, dialogShown: Bool, hasSelection: Bool) -> JournalKeyAction`.

- [ ] **Step 1: Тестовая цель**

Заменить `Package.swift` целиком. Тестировать исполняемую цель SwiftPM умеет: `@testable import BufferJournal` работает, и `@main` этому не мешает.

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

- [ ] **Step 2: Падающий тест**

Создать `Tests/BufferJournalTests/JournalKeyActionTests.swift`:

```swift
import Testing
@testable import BufferJournal

struct JournalKeyActionTests {
    @Test func arrowsMoveTheSelection() {
        #expect(JournalKeyAction.resolve(.up, dialogShown: false, hasSelection: true) == .moveUp)
        #expect(JournalKeyAction.resolve(.down, dialogShown: false, hasSelection: true) == .moveDown)
    }

    @Test func returnPastesOnlyASelectedClip() {
        #expect(JournalKeyAction.resolve(.enter, dialogShown: false, hasSelection: true) == .paste)
        #expect(JournalKeyAction.resolve(.enter, dialogShown: false, hasSelection: false) == .ignore)
    }

    @Test func escapeClosesTheDialogBeforeThePanel() {
        #expect(JournalKeyAction.resolve(.escape, dialogShown: true, hasSelection: true) == .closeDialog)
        #expect(JournalKeyAction.resolve(.escape, dialogShown: false, hasSelection: true) == .closePanel)
    }

    @Test func aDialogIgnoresArrowsAndReturn() {
        for key in [JournalKey.up, .down, .enter] {
            #expect(JournalKeyAction.resolve(key, dialogShown: true, hasSelection: true) == .ignore)
        }
    }
}
```

- [ ] **Step 3: Тест падает**

Run: `swift test --filter JournalKeyActionTests`
Expected: FAIL, ошибка сборки `cannot find 'JournalKeyAction' in scope`.

- [ ] **Step 4: Правила клавиш**

Создать `Sources/BufferJournal/JournalKeys.swift`:

```swift
/// Keys the journal takes while it is open: plain Up, Down, Return (or keypad Enter) and Escape.
enum JournalKey: Equatable {
    case up
    case down
    case enter
    case escape
}

/// What the journal does with a key, given what is on screen.
enum JournalKeyAction: Equatable {
    case moveUp
    case moveDown
    case paste
    case closeDialog
    case closePanel
    case ignore

    /// A confirmation dialog takes Escape and nothing else; Return pastes only a selected clip.
    static func resolve(_ key: JournalKey, dialogShown: Bool, hasSelection: Bool) -> JournalKeyAction {
        if dialogShown {
            return key == .escape ? .closeDialog : .ignore
        }

        switch key {
        case .up: return .moveUp
        case .down: return .moveDown
        case .enter: return hasSelection ? .paste : .ignore
        case .escape: return .closePanel
        }
    }
}
```

- [ ] **Step 5: Тест проходит**

Run: `swift test --filter JournalKeyActionTests`
Expected: PASS, 4 теста.

- [ ] **Step 6: Сборка**

Run: `swift build`
Expected: `Build complete!` без предупреждений.

- [ ] **Step 7: Коммит**

```bash
git add Package.swift Sources/BufferJournal/JournalKeys.swift Tests/BufferJournalTests/JournalKeyActionTests.swift
git commit -m "Add a test target and the journal's key rules" -m "JournalKeyAction.resolve decides what Up, Down, Return and Escape do:
a confirmation dialog takes only Escape, Return pastes only a selected clip."
```

---

### Task 2: Реестр глобальных хоткеев

**Files:**
- Modify: `Sources/BufferJournal/HotKeyController.swift` (заменить целиком)
- Modify: `Sources/BufferJournal/AppDelegate.swift` — ⌥V через реестр

**Interfaces:**
- Produces: `@MainActor final class HotKeyController`: `init()`, `install()`, `@discardableResult func register(keyCode: UInt32, modifiers: UInt32, onPress: @escaping () -> Void, onRelease: (() -> Void)? = nil) -> HotKeyController.Registration?`, `func unregister(_ registration: HotKeyController.Registration)`, `struct Registration: Hashable`.

Юнит-теста нет: реестр регистрирует настоящие глобальные хоткеи (см. Global Constraints).

- [ ] **Step 1: Реестр**

Заменить `Sources/BufferJournal/HotKeyController.swift` целиком:

```swift
import Carbon
import Foundation

/// Global hotkeys through the Carbon hotkey API: ⌥V for the journal, and the journal's own keys
/// while it is open. macOS hands a registered key to Stash instead of the frontmost app.
@MainActor
final class HotKeyController {
    struct Registration: Hashable {
        fileprivate let id: UInt32
    }

    private struct Handler {
        let ref: EventHotKeyRef
        let onPress: () -> Void
        let onRelease: (() -> Void)?
    }

    private static let signature = OSType("BJRN".fourCharCode)

    private var eventHandler: EventHandlerRef?
    private var handlers: [UInt32: Handler] = [:]
    private var nextID: UInt32 = 1

    /// Installs one Carbon handler for hotkey presses and releases; call once at launch.
    func install() {
        var eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyReleased)),
        ]

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return OSStatus(eventNotHandledErr) }
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard status == noErr else { return status }

                let id = hotKeyID.id
                let isPress = GetEventKind(event) == UInt32(kEventHotKeyPressed)
                nonisolated(unsafe) let pointer = userData
                // Carbon delivers hotkey events on the main thread.
                return MainActor.assumeIsolated {
                    let controller = Unmanaged<HotKeyController>.fromOpaque(pointer).takeUnretainedValue()
                    return controller.handle(id: id, isPress: isPress) ? noErr : OSStatus(eventNotHandledErr)
                }
            },
            eventTypes.count,
            &eventTypes,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )

        if status != noErr {
            NSLog("BufferJournal: failed to install hotkey handler: \(status)")
        }
    }

    /// Registers a global hotkey. Returns nil, and logs, when macOS refuses the combination.
    @discardableResult
    func register(
        keyCode: UInt32,
        modifiers: UInt32,
        onPress: @escaping () -> Void,
        onRelease: (() -> Void)? = nil
    ) -> Registration? {
        let id = nextID
        nextID += 1

        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            EventHotKeyID(signature: Self.signature, id: id),
            GetApplicationEventTarget(),
            0,
            &ref
        )

        guard status == noErr, let ref else {
            NSLog("BufferJournal: failed to register hotkey \(keyCode) with modifiers \(modifiers): \(status)")
            return nil
        }

        handlers[id] = Handler(ref: ref, onPress: onPress, onRelease: onRelease)
        return Registration(id: id)
    }

    func unregister(_ registration: Registration) {
        guard let handler = handlers.removeValue(forKey: registration.id) else { return }
        UnregisterEventHotKey(handler.ref)
    }

    private func handle(id: UInt32, isPress: Bool) -> Bool {
        guard let handler = handlers[id] else { return false }
        if isPress {
            handler.onPress()
        } else {
            handler.onRelease?()
        }
        return true
    }
}

private extension String {
    var fourCharCode: UInt32 {
        utf8.reduce(0) { result, character in
            (result << 8) + UInt32(character)
        }
    }
}
```

- [ ] **Step 2: ⌥V через реестр**

В `Sources/BufferJournal/AppDelegate.swift` добавить импорт Carbon: коды клавиш `kVK_*` и `optionKey` живут в нём.

Найти:

```swift
import AppKit
import SwiftUI
```

Заменить на:

```swift
import AppKit
import Carbon
import SwiftUI
```

Найти:

```swift
        settings = AppSettings()
        panelController = JournalPanelController(store: store, writer: writer, settings: settings)
        hotKeyController = HotKeyController { [weak self] in
            Task { @MainActor in
                self?.panelController.toggle()
            }
        }

        configureStatusItem()
        monitor.start()
        hotKeyController.register()
    }
```

Заменить на:

```swift
        settings = AppSettings()
        hotKeyController = HotKeyController()
        hotKeyController.install()
        panelController = JournalPanelController(store: store, writer: writer, settings: settings)
        hotKeyController.register(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(optionKey)) { [weak self] in
            self?.panelController.toggle()
        }

        configureStatusItem()
        monitor.start()
    }
```

- [ ] **Step 3: Сборка и тесты**

Run: `swift build && swift test`
Expected: `Build complete!` без предупреждений, 4 теста проходят.

- [ ] **Step 4: Проверка вручную**

Закрыть установленный Stash. Выполнить `Scripts/build_app.sh` и `open .build/Stash.app`. ⌥V открывает панель, повторное ⌥V её закрывает. Панель пока, как и раньше, забирает клавиатуру: это меняет Task 4.

- [ ] **Step 5: Коммит**

```bash
git add Sources/BufferJournal/HotKeyController.swift Sources/BufferJournal/AppDelegate.swift
git commit -m "Turn the hotkey controller into a registry" -m "One Carbon handler serves presses and releases of any number of hotkeys,
so the journal can take its own keys while open. Option+V registers
through it like any other."
```

---

### Task 3: Хоткеи журнала с повтором ↑ и ↓

**Files:**
- Modify: `Sources/BufferJournal/JournalKeys.swift` — класс `JournalKeys`
- Test: `Tests/BufferJournalTests/JournalKeysTests.swift`

**Interfaces:**
- Consumes: `HotKeyController.register(keyCode:modifiers:onPress:onRelease:)`, `unregister(_:)`, `HotKeyController.Registration` (Task 2); `JournalKey` (Task 1).
- Produces: `@MainActor final class JournalKeys`: `init(hotKeys: HotKeyController)`, `let events: PassthroughSubject<JournalKey, Never>`, `var isListening: Bool`, `nonisolated static func shouldListen(panelVisible: Bool, journalShown: Bool, stashActive: Bool, menuOpen: Bool) -> Bool`.

- [ ] **Step 1: Падающий тест**

Создать `Tests/BufferJournalTests/JournalKeysTests.swift`:

```swift
import Testing
@testable import BufferJournal

struct JournalKeysTests {
    @Test func listensToTheOpenJournalOverAnotherApp() {
        #expect(JournalKeys.shouldListen(panelVisible: true, journalShown: true, stashActive: false, menuOpen: false))
    }

    @Test func letsTheKeysGoOtherwise() {
        #expect(!JournalKeys.shouldListen(panelVisible: false, journalShown: true, stashActive: false, menuOpen: false))
        #expect(!JournalKeys.shouldListen(panelVisible: true, journalShown: false, stashActive: false, menuOpen: false))
        #expect(!JournalKeys.shouldListen(panelVisible: true, journalShown: true, stashActive: true, menuOpen: false))
        #expect(!JournalKeys.shouldListen(panelVisible: true, journalShown: true, stashActive: false, menuOpen: true))
    }
}
```

- [ ] **Step 2: Тест падает**

Run: `swift test --filter JournalKeysTests`
Expected: FAIL, ошибка сборки `cannot find 'JournalKeys' in scope`.

- [ ] **Step 3: Хоткеи журнала**

В начало `Sources/BufferJournal/JournalKeys.swift`, перед `/// Keys the journal takes while it is open…`, добавить импорты:

```swift
import AppKit
import Carbon
import Combine

```

В конец файла, после `JournalKeyAction`, добавить:

```swift

/// The journal's hotkeys. While listening, plain Up, Down, Return, keypad Enter and Escape are
/// registered as global hotkeys, so macOS hands them to Stash instead of the app under the panel.
/// macOS swallows the auto-repeats of a held hotkey, so Up and Down repeat on a timer at the
/// system key-repeat rate.
@MainActor
final class JournalKeys {
    /// Listen only while the journal is on screen, Stash is not the active app (its clip editor
    /// needs these keys) and the menu bar menu is closed (its items are walked with the arrows).
    nonisolated static func shouldListen(panelVisible: Bool, journalShown: Bool, stashActive: Bool, menuOpen: Bool) -> Bool {
        panelVisible && journalShown && !stashActive && !menuOpen
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

    private let hotKeys: HotKeyController
    private var registrations: [HotKeyController.Registration] = []
    private var heldKey: JournalKey?
    private var repeatTimer: Timer?

    init(hotKeys: HotKeyController) {
        self.hotKeys = hotKeys
    }

    private func register() {
        for binding in Self.bindings {
            let key = binding.key
            let registration = hotKeys.register(
                keyCode: UInt32(binding.keyCode),
                modifiers: 0,
                onPress: { [weak self] in self?.press(key) },
                onRelease: { [weak self] in self?.release(key) }
            )
            if let registration {
                registrations.append(registration)
            }
        }
    }

    private func unregister() {
        registrations.forEach { hotKeys.unregister($0) }
        registrations = []
        stopRepeating()
    }

    private func press(_ key: JournalKey) {
        // The held key already repeats on the timer.
        guard heldKey != key else { return }
        stopRepeating()
        events.send(key)

        guard key == .up || key == .down else { return }
        heldKey = key
        repeatTimer = Timer.scheduledTimer(withTimeInterval: NSEvent.keyRepeatDelay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.startRepeating(key)
            }
        }
    }

    private func startRepeating(_ key: JournalKey) {
        guard heldKey == key else { return }
        repeatTimer = Timer.scheduledTimer(withTimeInterval: NSEvent.keyRepeatInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.events.send(key)
            }
        }
    }

    private func release(_ key: JournalKey) {
        guard heldKey == key else { return }
        stopRepeating()
    }

    private func stopRepeating() {
        repeatTimer?.invalidate()
        repeatTimer = nil
        heldKey = nil
    }
}
```

- [ ] **Step 4: Тест проходит**

Run: `swift test`
Expected: PASS, 6 тестов в двух наборах.

- [ ] **Step 5: Сборка**

Run: `swift build`
Expected: `Build complete!` без предупреждений.

- [ ] **Step 6: Коммит**

```bash
git add Sources/BufferJournal/JournalKeys.swift Tests/BufferJournalTests/JournalKeysTests.swift
git commit -m "Add the journal's hotkeys with a repeat for Up and Down" -m "JournalKeys registers plain Up, Down, Return, keypad Enter and Escape
while listening and publishes the presses. macOS swallows the repeats of
a held hotkey, so Up and Down repeat on a timer at the system rate."
```

---

### Task 4: Панель не забирает клавиатуру, поиска нет

**Files:**
- Modify: `Sources/BufferJournal/JournalPanelController.swift`
- Modify: `Sources/BufferJournal/JournalView.swift`
- Modify: `Sources/BufferJournal/AppDelegate.swift`
- Modify: `README.md`

**Interfaces:**
- Consumes: `JournalKeys(hotKeys:)`, `.events`, `.isListening`, `JournalKeys.shouldListen(panelVisible:journalShown:stashActive:menuOpen:)` (Task 3); `JournalKeyAction.resolve(_:dialogShown:hasSelection:)` (Task 1); `HotKeyController` (Task 2).
- Produces: `JournalPanelController.init(store:writer:settings:hotKeys:)`, `func setMenuOpen(_ isOpen: Bool)`; у `JournalView` новый параметр `keyEvents: PassthroughSubject<JournalKey, Never>` сразу после `settings`; `AppDelegate` — `NSMenuDelegate`.

- [ ] **Step 1: Неключевая панель и хоткеи журнала**

В `Sources/BufferJournal/JournalPanelController.swift`.

Найти:

```swift
    private let store: ClipboardHistoryStore
    private let writer: ClipboardWriter
    private let settings: AppSettings
    private var panel: NSPanel?
    private var textEditSessions: [ClipboardEntry.ID: TextEditWindowSession] = [:]

    init(store: ClipboardHistoryStore, writer: ClipboardWriter, settings: AppSettings) {
        self.store = store
        self.writer = writer
        self.settings = settings
    }
```

Заменить на:

```swift
    private let store: ClipboardHistoryStore
    private let writer: ClipboardWriter
    private let settings: AppSettings
    private let keys: JournalKeys
    private var panel: NSPanel?
    private var textEditSessions: [ClipboardEntry.ID: TextEditWindowSession] = [:]
    private var isPanelVisible = false
    private var isMenuOpen = false
    private var activationObservers: [NSObjectProtocol] = []

    init(store: ClipboardHistoryStore, writer: ClipboardWriter, settings: AppSettings, hotKeys: HotKeyController) {
        self.store = store
        self.writer = writer
        self.settings = settings
        keys = JournalKeys(hotKeys: hotKeys)

        // The clip editor activates Stash and needs the arrows, Return and Esc for itself.
        for name in [NSApplication.didBecomeActiveNotification, NSApplication.didResignActiveNotification] {
            let observer = NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.updateKeys()
                }
            }
            activationObservers.append(observer)
        }
    }
```

Найти:

```swift
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        // Key without activating the app: search and arrows work, the target app stays frontmost.
        panel.makeKey()
```

Заменить на:

```swift
        panel.alphaValue = 0
        // Never key: typing stays with the app under the panel; the journal's keys come as hotkeys.
        panel.orderFrontRegardless()
        isPanelVisible = true
        updateKeys()
```

Найти:

```swift
            completion?()
            return
        }

        savePosition(panel)
```

Заменить на:

```swift
            completion?()
            return
        }

        isPanelVisible = false
        updateKeys()
        savePosition(panel)
```

Найти:

```swift
    private func makePanelIfNeeded() -> NSPanel {
        if let panel {
            return panel
        }

        let contentView = JournalView(
            store: store,
            settings: settings,
            onSelect: { [weak self] entry in
```

Заменить на:

```swift
    /// The menu bar menu walks its items with the arrows, so the journal lets go of them meanwhile.
    func setMenuOpen(_ isOpen: Bool) {
        isMenuOpen = isOpen
        updateKeys()
    }

    private func updateKeys() {
        keys.isListening = JournalKeys.shouldListen(
            panelVisible: isPanelVisible,
            journalShown: true,
            stashActive: NSApp.isActive,
            menuOpen: isMenuOpen
        )
    }

    private func makePanelIfNeeded() -> NSPanel {
        if let panel {
            return panel
        }

        let contentView = JournalView(
            store: store,
            settings: settings,
            keyEvents: keys.events,
            onSelect: { [weak self] entry in
```

Найти:

```swift
        panel.animationBehavior = .none
        panel.minSize = Constants.minSize
```

Заменить на:

```swift
        panel.animationBehavior = .none
        panel.minSize = Constants.minSize
        // Stash stays inactive while the panel is open; without this its tooltips never show.
        panel.allowsToolTipsWhenApplicationIsInactive = true
```

Найти:

```swift
        if settings.closeAfterSelection {
            close(completion: performSelection)
        } else if settings.pasteOnSelection, let panel, panel.isKeyWindow {
            relinquishKeyFocus(of: panel)
            // Give the window server a moment to hand key focus back before Cmd+V is sent.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                performSelection()
            }
        } else {
            performSelection()
        }
    }

    /// Hands keyboard focus back to the app underneath while keeping the panel on screen,
    /// so a synthesized Cmd+V reaches that app instead of the search field.
    private func relinquishKeyFocus(of panel: NSPanel) {
        panel.orderOut(nil)
        panel.orderFrontRegardless()
    }
```

Заменить на:

```swift
        if settings.closeAfterSelection {
            close(completion: performSelection)
        } else {
            performSelection()
        }
    }
```

Найти:

```swift
private final class JournalPanel: NSPanel {
    override var canBecomeKey: Bool { true }
```

Заменить на:

```swift
/// Never key: the keyboard stays with the app the user is typing in, even after a click.
private final class JournalPanel: NSPanel {
    override var canBecomeKey: Bool { false }
```

- [ ] **Step 2: Журнал без поиска, клавиши из хоткеев**

В `Sources/BufferJournal/JournalView.swift`.

Найти:

```swift
import AppKit
import SwiftUI
```

Заменить на:

```swift
import AppKit
import Combine
import SwiftUI
```

Найти:

```swift
    @ObservedObject var settings: AppSettings
    let onSelect: (ClipboardEntry) -> Void
```

Заменить на:

```swift
    @ObservedObject var settings: AppSettings
    /// The journal's keys, taken as hotkeys while it is open: the panel itself never takes the keyboard.
    let keyEvents: PassthroughSubject<JournalKey, Never>
    let onSelect: (ClipboardEntry) -> Void
```

Найти:

```swift
    @State private var query = ""
    @State private var keyboardScrollTarget: KeyboardScrollTarget?
    @FocusState private var isSearchFocused: Bool
    @State private var isSearchEditing = false
```

Заменить на:

```swift
    @State private var keyboardScrollTarget: KeyboardScrollTarget?
```

Найти:

```swift
    private var filteredEntries: [ClipboardEntry] {
        let byType: [ClipboardEntry] = switch selectedFilter {
        case .all: store.entries
        case .text: store.entries.filter(\.isText)
        case .media: store.entries.filter(\.isImage)
        case .files: store.entries.filter(\.isFile)
        }

        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return byType }
        return byType.filter { matches($0, needle) }
    }
```

Заменить на:

```swift
    private var filteredEntries: [ClipboardEntry] {
        switch selectedFilter {
        case .all: store.entries
        case .text: store.entries.filter(\.isText)
        case .media: store.entries.filter(\.isImage)
        case .files: store.entries.filter(\.isFile)
        }
    }
```

Найти:

```swift
        .environment(\.solidAccents, settings.themeMode.usesSolidAccents)
        .background(
            KeyboardMonitor(
                onKey: handleKey,
                onBecomeKey: { isSearchFocused = true },
                onEditingChanged: { isSearchEditing = $0 }
            )
        )
    }
```

Заменить на:

```swift
        .environment(\.solidAccents, settings.themeMode.usesSolidAccents)
        .onReceive(keyEvents) { handleKey($0) }
    }
```

Найти:

```swift
            searchField
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
                .background(WindowDragHandle())

            TypeSegmentedControl(
```

Заменить на:

```swift
            TypeSegmentedControl(
```

Удалить свойство `searchField` целиком: от строки `    private var searchField: some View {` до его закрывающей `    }` и пустой строки после неё, так чтобы следующей шла `    private static let listBottomID = "list-bottom"`.

Найти:

```swift
    private var emptyStateMessage: String {
        if !query.trimmingCharacters(in: .whitespaces).isEmpty {
            return l10n("Nothing found", "Ничего не найдено")
        }
        if store.entries.isEmpty {
```

Заменить на:

```swift
    private var emptyStateMessage: String {
        if store.entries.isEmpty {
```

Удалить функцию `matches(_:_:)` и старую `handleKey(_ event: NSEvent) -> Bool` вместе с её комментарием: от строки `    private func matches(_ entry: ClipboardEntry, _ needle: String) -> Bool {` до закрывающей `    }` функции `handleKey`, перед пустой строкой и `    // MARK: Actions`. На их место вставить:

```swift
    /// Keys arrive as hotkeys while the journal is open (see `JournalKeys`).
    private func handleKey(_ key: JournalKey) {
        let action = JournalKeyAction.resolve(
            key,
            dialogShown: isClearConfirmationShown || entryPendingDeletion != nil,
            hasSelection: selectedEntry != nil
        )

        switch action {
        case .moveUp, .moveDown:
            let entries = orderedEntries
            guard !entries.isEmpty else { return }
            let current = entries.firstIndex { $0.id == selectedEntry?.id } ?? 0
            let next = action == .moveDown ? min(current + 1, entries.count - 1) : max(current - 1, 0)
            selectedID = entries[next].id
            // At the ends scroll to the header / bottom inset so the row keeps its margin.
            keyboardScrollTarget = next == 0 ? .top : (next == entries.count - 1 ? .bottom : .entry(entries[next].id))
        case .paste:
            if let entry = selectedEntry {
                select(entry)
            }
        case .closeDialog:
            isClearConfirmationShown = false
            entryPendingDeletion = nil
        case .closePanel:
            onClose()
        case .ignore:
            break
        }
    }
```

Удалить структуру `KeyboardMonitor` целиком: от строки `/// Local key-down monitor for the panel's window, plus a callback when that window becomes key.` до её закрывающей `}` и пустой строки после неё, так чтобы следующей шла `/// Reports whether the enclosing scroll view has scrolled away from the top.`

- [ ] **Step 3: Делегат меню**

В `Sources/BufferJournal/AppDelegate.swift`.

Найти:

```swift
final class AppDelegate: NSObject, NSApplicationDelegate {
```

Заменить на:

```swift
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
```

Найти:

```swift
        panelController = JournalPanelController(store: store, writer: writer, settings: settings)
```

Заменить на:

```swift
        panelController = JournalPanelController(
            store: store,
            writer: writer,
            settings: settings,
            hotKeys: hotKeyController
        )
```

Найти:

```swift
        let menu = NSMenu()
        menu.addItem(menuItem(l10n("Open Stash", "Открыть Stash"), action: #selector(openJournal)))
```

Заменить на:

```swift
        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(menuItem(l10n("Open Stash", "Открыть Stash"), action: #selector(openJournal)))
```

Найти:

```swift
    @objc private func quit() {
        NSApp.terminate(nil)
    }
```

Заменить на:

```swift
    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // The journal lets go of the arrows while the menu is open: they walk its items.
    func menuWillOpen(_ menu: NSMenu) {
        panelController.setMenuOpen(true)
    }

    func menuDidClose(_ menu: NSMenu) {
        panelController.setMenuOpen(false)
    }
```

- [ ] **Step 4: README**

В `README.md` найти:

```
Type to search, use ↑/↓ to move, Return to paste and Esc to clear the search or close.
```

Заменить на:

```
The journal never takes the keyboard: whatever you type goes to the app you are typing in. While it is open, ↑/↓ move the selection, Return pastes and Esc closes it.
```

- [ ] **Step 5: Сборка и тесты**

Run: `swift build && swift test`
Expected: `Build complete!` без предупреждений, 6 тестов проходят. Проверить, что хвостов не осталось: `grep -n "query\|isSearch\|KeyboardMonitor\|makeKey\|relinquishKeyFocus" Sources/BufferJournal/*.swift` ничего не находит.

- [ ] **Step 6: Проверка вручную**

Закрыть установленный Stash. Выполнить `Scripts/build_app.sh` и `open .build/Stash.app`. Выдать сборке Универсальный доступ (это делает пользователь), иначе Return только скопирует клип.

- TextEdit: печатать, нажать ⌥V, продолжать печатать — буквы попадают в TextEdit, поля поиска нет.
- ↑ и ↓ двигают выбор, удержание повторяет с системной скоростью. ⇧↓ выделяет текст в TextEdit.
- Return вставляет выбранный клип в TextEdit. Esc закрывает панель.
- Клик по строке, фильтру, кнопкам, разделителю, шапке и углу: TextEdit не теряет фокус, печать продолжается.
- Диалог «Удалить клип?»: Esc закрывает, Return ничего не делает.
- Меню значка при открытой панели: стрелки ходят по меню.
- Редактор клипа поверх панели: стрелки, Return и Esc работают в редакторе. После возврата в TextEdit клавиши снова у журнала.
- Подсказки у кнопок появляются.

- [ ] **Step 7: Коммит**

```bash
git add Sources/BufferJournal/JournalPanelController.swift Sources/BufferJournal/JournalView.swift Sources/BufferJournal/AppDelegate.swift README.md
git commit -m "Keep the keyboard with the app under the journal and drop search" -m "- The panel never becomes key again (as before c537e93): typing and
  clicks leave the keyboard with the app the user is typing in
- Up, Down, Return and Esc reach the journal as hotkeys while it is
  open, except while Stash itself is active or its menu is open
- Search, its field and the key monitor are gone; tooltips show
  although Stash is inactive"
```

---

### Task 5: Выбор всегда вставляет, кнопка «Скопировать в буфер»

**Files:**
- Modify: `Sources/BufferJournal/AppSettings.swift`
- Modify: `Sources/BufferJournal/AppDelegate.swift`
- Modify: `Sources/BufferJournal/JournalPanelController.swift`
- Modify: `Sources/BufferJournal/JournalView.swift`
- Modify: `README.md`

**Interfaces:**
- Consumes: состояние файлов после Task 4.
- Produces: `JournalPanelController.paste(_ entry: ClipboardEntry) -> Bool` (пока всегда `true`), `JournalPanelController.copy(_ entry: ClipboardEntry)`; у `JournalView` вместо `onSelect` — `onPaste: (ClipboardEntry) -> Bool` и `onCopy: (ClipboardEntry) -> Void`, в том же месте списка параметров.
- Removes: `AppSettings.pasteOnSelection`, пункт меню «Вставлять при выборе».

- [ ] **Step 1: Настройка уходит**

В `Sources/BufferJournal/AppSettings.swift` найти:

```swift
    private enum Keys {
        static let pasteOnSelection = "PasteOnSelection"
        static let closeAfterSelection = "CloseAfterSelection"
```

Заменить на:

```swift
    private enum Keys {
        static let closeAfterSelection = "CloseAfterSelection"
```

Найти и удалить (вместе с пустой строкой после):

```swift
    @Published var pasteOnSelection: Bool {
        didSet {
            UserDefaults.standard.set(pasteOnSelection, forKey: Keys.pasteOnSelection)
        }
    }

```

Найти и удалить (вместе с пустой строкой после):

```swift
        if defaults.object(forKey: Keys.pasteOnSelection) == nil {
            defaults.set(true, forKey: Keys.pasteOnSelection)
        }

```

Найти и удалить:

```swift
        pasteOnSelection = defaults.bool(forKey: Keys.pasteOnSelection)
```

- [ ] **Step 2: Меню без «Вставлять при выборе»**

В `Sources/BufferJournal/AppDelegate.swift` найти и удалить:

```swift
    private var pasteOnSelectionItem: NSMenuItem!
```

Найти:

```swift
        menu.addItem(NSMenuItem.separator())

        pasteOnSelectionItem = menuItem(l10n("Paste on Selection", "Вставлять при выборе"), action: #selector(togglePasteOnSelection))
        menu.addItem(pasteOnSelectionItem)

        closeAfterSelectionItem
```

Заменить на:

```swift
        menu.addItem(NSMenuItem.separator())

        closeAfterSelectionItem
```

Найти и удалить (вместе с пустой строкой после):

```swift
    @objc private func togglePasteOnSelection() {
        settings.pasteOnSelection.toggle()
        updateSettingsMenuState()
    }

```

Найти и удалить:

```swift
        pasteOnSelectionItem?.state = settings.pasteOnSelection ? .on : .off
```

- [ ] **Step 3: Вставка и копирование в контроллере**

В `Sources/BufferJournal/JournalPanelController.swift` найти:

```swift
            onSelect: { [weak self] entry in
                self?.handleSelection(entry)
            },
```

Заменить на:

```swift
            onPaste: { [weak self] entry in
                self?.paste(entry) ?? false
            },
            onCopy: { [weak self] entry in
                self?.copy(entry)
            },
```

Найти:

```swift
    private func handleSelection(_ entry: ClipboardEntry) {
        let performSelection: @MainActor @Sendable () -> Void = { [writer, settings] in
            if settings.pasteOnSelection {
                writer.paste(entry)
            } else {
                writer.copy(entry)
            }
        }

        if settings.closeAfterSelection {
            close(completion: performSelection)
        } else {
            performSelection()
        }
    }
```

Заменить на:

```swift
    /// Pastes the clip into the app under the panel and returns whether it did.
    func paste(_ entry: ClipboardEntry) -> Bool {
        perform { [writer] in writer.paste(entry) }
        return true
    }

    func copy(_ entry: ClipboardEntry) {
        perform { [writer] in writer.copy(entry) }
    }

    /// Runs a paste or copy, closing the panel first when Close After Selection is on.
    private func perform(_ action: @escaping @MainActor @Sendable () -> Void) {
        if settings.closeAfterSelection {
            close(completion: action)
        } else {
            action()
        }
    }
```

- [ ] **Step 4: Вставка, копирование и подписи в журнале**

В `Sources/BufferJournal/JournalView.swift` найти:

```swift
    let onSelect: (ClipboardEntry) -> Void
    let onEditText: (ClipboardEntry) -> Void
```

Заменить на:

```swift
    /// Returns false when nothing was pasted.
    let onPaste: (ClipboardEntry) -> Bool
    let onCopy: (ClipboardEntry) -> Void
    let onEditText: (ClipboardEntry) -> Void
```

Найти:

```swift
            quickPasteTitle: settings.pasteOnSelection ? l10n("Paste", "Вставить") : l10n("Copy", "Скопировать"),
            onQuickPaste: { select(entry) },
```

Заменить на:

```swift
            onQuickPaste: { paste(entry) },
```

Найти:

```swift
        .simultaneousGesture(TapGesture(count: 2).onEnded { select(entry) })
```

Заменить на:

```swift
        .simultaneousGesture(TapGesture(count: 2).onEnded { paste(entry) })
```

Найти:

```swift
            Spacer()

            Button {
                select(entry)
            } label: {
                HStack(spacing: 6) {
                    Text(settings.pasteOnSelection ? l10n("Paste", "Вставить") : l10n("Copy", "Скопировать"))
```

Заменить на:

```swift
            Spacer()

            GlassIconButton(
                systemName: "doc.on.doc",
                help: l10n("Copy to clipboard", "Скопировать в буфер"),
                action: { copy(entry) }
            )

            Button {
                paste(entry)
            } label: {
                HStack(spacing: 6) {
                    Text(l10n("Paste", "Вставить"))
```

Найти:

```swift
        case .paste:
            if let entry = selectedEntry {
                select(entry)
            }
```

Заменить на:

```swift
        case .paste:
            if let entry = selectedEntry {
                paste(entry)
            }
```

Найти:

```swift
    private func select(_ entry: ClipboardEntry) {
        selectedID = entry.id
        if !settings.closeAfterSelection {
            showToast(settings.pasteOnSelection ? l10n("Pasted", "Вставлено") : l10n("Copied", "Скопировано"))
        }
        onSelect(entry)
    }
```

Заменить на:

```swift
    private func paste(_ entry: ClipboardEntry) {
        selectedID = entry.id
        guard onPaste(entry) else { return }
        if !settings.closeAfterSelection {
            showToast(l10n("Pasted", "Вставлено"))
        }
    }

    private func copy(_ entry: ClipboardEntry) {
        onCopy(entry)
        if !settings.closeAfterSelection {
            showToast(l10n("Copied", "Скопировано"))
        }
    }
```

В `EntryRow` найти:

```swift
    let palette: ThemePalette
    let quickPasteTitle: String
    let onQuickPaste: () -> Void
```

Заменить на:

```swift
    let palette: ThemePalette
    let onQuickPaste: () -> Void
```

Найти:

```swift
                    rowAction("return", tone: accentTone, help: quickPasteTitle, action: onQuickPaste)
```

Заменить на:

```swift
                    rowAction("return", tone: accentTone, help: l10n("Paste", "Вставить"), action: onQuickPaste)
```

- [ ] **Step 5: README**

В `README.md` найти:

```
Hover a clip and press the orange return button, double-click it, or press Paste to put it back on the pasteboard.
```

Заменить на:

```
Hover a clip and press the orange return button, double-click it, or press Paste to paste it where your cursor is; the copy button next to Paste only puts it on the pasteboard.
```

Найти:

```
- Menu settings can also paste immediately after selection, close the journal after selection, and switch theme and interface language (System, English, Русский).
```

Заменить на:

```
- Menu settings close the journal after a paste or copy and switch theme and interface language (System, English, Русский).
```

Найти:

```
Open the generated app bundle. Copy text or an image, press `Option+V`, then click a card to copy it back into the system pasteboard. If `Paste on Selection` is enabled in the menu bar menu, Stash also sends `Cmd+V` without refocusing the target app.
```

Заменить на:

```
Open the generated app bundle. Copy text or an image, press `Option+V`, then double-click a clip: Stash pastes it into the app you are typing in by sending `Cmd+V`.
```

- [ ] **Step 6: Сборка и тесты**

Run: `swift build && swift test`
Expected: `Build complete!` без предупреждений, 6 тестов проходят. `grep -rn "pasteOnSelection\|quickPasteTitle\|onSelect(entry)\|handleSelection" Sources` ничего не находит.

- [ ] **Step 7: Проверка вручную**

Собрать и запустить, как в Task 4.

- В меню значка нет «Вставлять при выборе», «Закрывать после выбора» на месте.
- Стрелка на строке, двойной клик, «Вставить ⏎» и Return вставляют клип в TextEdit, тост «Вставлено».
- «Скопировать в буфер» (значок `doc.on.doc` перед «Вставить ⏎», подсказка «Скопировать в буфер»): клип в буфере, в TextEdit ничего не вставилось, тост «Скопировано».
- При включённом «Закрывать после выбора» вставка и копирование закрывают панель, тоста нет.

- [ ] **Step 8: Коммит**

```bash
git add Sources/BufferJournal/AppSettings.swift Sources/BufferJournal/AppDelegate.swift Sources/BufferJournal/JournalPanelController.swift Sources/BufferJournal/JournalView.swift README.md
git commit -m "Always paste a picked clip and add a copy button" -m "Paste on Selection is gone: the row arrow, a double-click, Paste and
Return always paste. A copy button next to Paste only puts the clip on
the pasteboard. Close After Selection covers both."
```

---

### Task 6: Состояние доступа: `AccessibilityAccess` и `AccessGate`

**Files:**
- Create: `Sources/BufferJournal/AccessibilityAccess.swift`
- Test: `Tests/BufferJournalTests/AccessGateTests.swift`

**Interfaces:**
- Produces: `struct AccessibilityAccess: Sendable` — `var isGranted: @MainActor @Sendable () -> Bool`, `var request: @MainActor @Sendable () -> Void`, `static let live`.
- Produces: `@MainActor final class AccessGate: ObservableObject` — `init(access: AccessibilityAccess = .live)`, `@Published private(set) var isGranted: Bool`, `var onChange: (() -> Void)?` (зовётся после смены `isGranted`), `private(set) var isPolling: Bool`, `@discardableResult func refresh() -> Bool`, `func request()`, `func setPolling(_ on: Bool)`.

- [ ] **Step 1: Падающий тест**

Создать `Tests/BufferJournalTests/AccessGateTests.swift`:

```swift
import Testing
@testable import BufferJournal

/// Stand-in for the system permission.
@MainActor
private final class FakeAccess {
    var granted = false
    var requests = 0

    var access: AccessibilityAccess {
        AccessibilityAccess(
            isGranted: { [unowned self] in granted },
            request: { [unowned self] in requests += 1 }
        )
    }
}

@MainActor
struct AccessGateTests {
    @Test func readsThePermissionWhenCreated() {
        let fake = FakeAccess()
        fake.granted = true
        #expect(AccessGate(access: fake.access).isGranted)
    }

    @Test func refreshPicksUpAGrant() {
        let fake = FakeAccess()
        let gate = AccessGate(access: fake.access)
        var changes = 0
        gate.onChange = { changes += 1 }
        #expect(!gate.isGranted)

        fake.granted = true
        #expect(gate.refresh())
        #expect(gate.isGranted)
        #expect(changes == 1)

        gate.refresh()
        #expect(changes == 1)
    }

    @Test func requestAsksTheSystem() {
        let fake = FakeAccess()
        AccessGate(access: fake.access).request()
        #expect(fake.requests == 1)
    }

    @Test func doesNotPollWithAccess() {
        let fake = FakeAccess()
        fake.granted = true
        let gate = AccessGate(access: fake.access)
        gate.setPolling(true)
        #expect(!gate.isPolling)
    }

    @Test func stopsPollingOnceAccessAppears() {
        let fake = FakeAccess()
        let gate = AccessGate(access: fake.access)
        gate.setPolling(true)
        #expect(gate.isPolling)

        fake.granted = true
        gate.refresh()
        #expect(!gate.isPolling)
    }

    @Test func stopsPollingWhenTurnedOff() {
        let fake = FakeAccess()
        let gate = AccessGate(access: fake.access)
        gate.setPolling(true)
        gate.setPolling(false)
        #expect(!gate.isPolling)
    }
}
```

- [ ] **Step 2: Тест падает**

Run: `swift test --filter AccessGateTests`
Expected: FAIL, ошибка сборки `cannot find 'AccessibilityAccess' in scope`.

- [ ] **Step 3: Доступ**

Создать `Sources/BufferJournal/AccessibilityAccess.swift`:

```swift
import AppKit
import ApplicationServices

/// Whether macOS lets Stash press ⌘V for the user (Accessibility access), and how to ask for it.
/// The app uses `live`; tests pass their own closures.
struct AccessibilityAccess: Sendable {
    var isGranted: @MainActor @Sendable () -> Bool
    var request: @MainActor @Sendable () -> Void

    static let live = AccessibilityAccess(
        isGranted: { AXIsProcessTrusted() },
        request: {
            // Asking puts Stash on the Accessibility list and shows the system prompt.
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    )
}

/// Accessibility access as the panel sees it. Without access the panel shows the access screen;
/// while polling is on, the gate checks once a second until access appears.
@MainActor
final class AccessGate: ObservableObject {
    @Published private(set) var isGranted: Bool {
        didSet {
            if isGranted != oldValue {
                onChange?()
            }
        }
    }

    /// Called after `isGranted` changes.
    var onChange: (() -> Void)?
    private(set) var isPolling = false

    private let access: AccessibilityAccess
    private var timer: Timer?

    init(access: AccessibilityAccess = .live) {
        self.access = access
        isGranted = access.isGranted()
    }

    /// Reads the permission again and returns it. Polling stops once access is granted.
    @discardableResult
    func refresh() -> Bool {
        let granted = access.isGranted()
        // Assign only on change: every assignment would redraw the panel while polling.
        if granted != isGranted {
            isGranted = granted
        }
        if granted {
            setPolling(false)
        }
        return granted
    }

    func request() {
        access.request()
    }

    /// Checks once a second while on. There is nothing to wait for once access is granted.
    func setPolling(_ on: Bool) {
        let shouldPoll = on && !isGranted
        guard shouldPoll != isPolling else { return }
        isPolling = shouldPoll
        timer?.invalidate()
        timer = nil
        guard shouldPoll else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                _ = self?.refresh()
            }
        }
    }
}
```

- [ ] **Step 4: Тест проходит**

Run: `swift test`
Expected: PASS, 12 тестов в трёх наборах.

- [ ] **Step 5: Сборка**

Run: `swift build`
Expected: `Build complete!` без предупреждений.

- [ ] **Step 6: Коммит**

```bash
git add Sources/BufferJournal/AccessibilityAccess.swift Tests/BufferJournalTests/AccessGateTests.swift
git commit -m "Track Accessibility access for the panel" -m "AccessGate reads AXIsProcessTrusted, asks for access through the system
prompt and the Accessibility settings, and polls once a second until
access appears. Tests drive it with a stand-in permission."
```

---

### Task 7: Экран доступа в панели

**Files:**
- Create: `Sources/BufferJournal/AccessScreen.swift`
- Modify: `Sources/BufferJournal/JournalView.swift`
- Modify: `Sources/BufferJournal/JournalPanelController.swift`
- Modify: `Sources/BufferJournal/AppDelegate.swift`
- Modify: `Sources/BufferJournal/ClipboardWriter.swift`
- Modify: `README.md`

**Interfaces:**
- Consumes: `AccessGate` (Task 6); `GlassIconButton`, `WindowDragHandle`, `TranslucentButtonStyle`, `ThemePalette` из `JournalView.swift`; `JournalPanelController.paste(_:)` (Task 5).
- Produces: `struct AccessScreen: View` — `init(palette: ThemePalette, onOpenSettings: @escaping () -> Void, onClose: @escaping () -> Void)`; `JournalPanelController.init(store:writer:settings:hotKeys:access:)`; у `JournalView` новые параметры `access: AccessGate` (после `settings`) и `onOpenAccessSettings: () -> Void` (перед `onClose`).

- [ ] **Step 1: Экран доступа**

Создать `Sources/BufferJournal/AccessScreen.swift`:

```swift
import SwiftUI

/// Shown in the panel instead of the journal while Stash has no Accessibility access: pasting
/// presses ⌘V for the user, and macOS allows that only with access.
struct AccessScreen: View {
    let palette: ThemePalette
    let onOpenSettings: () -> Void
    let onClose: () -> Void

    @Environment(\.l10n) private var l10n

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                GlassIconButton(systemName: "xmark", help: l10n("Close", "Закрыть"), action: onClose)
            }
            .padding(.top, 10)
            .padding(.trailing, 10)

            Spacer(minLength: 0)

            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(palette.accentFill)
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: "accessibility")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(palette.onAccent)
                    }
                    .accessibilityHidden(true)

                Text(l10n("Stash needs Accessibility access", "Stash нужен Универсальный доступ"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, 14)

                Text(l10n(
                    "Stash pastes by pressing ⌘V for you. macOS won't allow it without Accessibility access.",
                    "Stash вставляет клип, нажимая ⌘V за вас. Без Универсального доступа macOS этого не разрешит."
                ))
                .font(.system(size: 13))
                .foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)

                Button(action: onOpenSettings) {
                    Text(l10n("Open Settings", "Открыть настройки"))
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 16)
                        .frame(height: 32)
                }
                .buttonStyle(TranslucentButtonStyle(tone: .accent, cornerRadius: 8))
                .padding(.top, 16)

                Text(l10n(
                    "Stash is already in the list and switched on, but this screen stays? After an update macOS treats Stash as a new app. Remove it from the list with “−” and click Open Settings again.",
                    "Stash уже в списке и включён, а экран не уходит? После обновления macOS считает Stash новым приложением. Удалите его из списка кнопкой «−» и снова нажмите «Открыть настройки»."
                ))
                .font(.system(size: 11))
                .foregroundStyle(palette.textTertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)
            }
            .frame(maxWidth: 360)
            .padding(.horizontal, 24)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // The empty area moves the window, like the journal's header.
        .background(WindowDragHandle())
        .background(palette.sidebarTint)
    }
}
```

- [ ] **Step 2: Журнал уступает место экрану доступа**

В `Sources/BufferJournal/JournalView.swift` найти:

```swift
    @ObservedObject var settings: AppSettings
    /// The journal's keys, taken as hotkeys while it is open: the panel itself never takes the keyboard.
```

Заменить на:

```swift
    @ObservedObject var settings: AppSettings
    @ObservedObject var access: AccessGate
    /// The journal's keys, taken as hotkeys while it is open: the panel itself never takes the keyboard.
```

Найти:

```swift
    let onPreviewImage: (ClipboardEntry) -> Void
    let onClose: () -> Void
```

Заменить на:

```swift
    let onPreviewImage: (ClipboardEntry) -> Void
    let onOpenAccessSettings: () -> Void
    let onClose: () -> Void
```

Найти в `body` блок разделённого журнала целиком:

```swift
            GeometryReader { geometry in
                let width = sidebarWidth(in: geometry.size.width)

                HStack(spacing: 0) {
                    sidebar
                        .frame(width: width)
                        .background(palette.sidebarTint)
                        .overlay(alignment: .trailing) {
                            palette.separator.frame(width: 1)
                        }
                        .overlay(alignment: .trailing) {
                            SidebarResizeHandle(
                                palette: palette,
                                onChanged: { translation in
                                    let start = sidebarDragStartWidth ?? width
                                    sidebarDragStartWidth = start
                                    storedSidebarWidth = Double(clampedSidebarWidth(start + translation, in: geometry.size.width))
                                },
                                onEnded: { sidebarDragStartWidth = nil }
                            )
                            // Hit area spans 4 pt left of the divider to 10 pt right of it, so the
                            // border and the grab mark light up and drag as one.
                            .offset(x: 10)
                        }
                        .zIndex(1)

                    detail
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(palette.detailTint)
                }
            }
```

Заменить на:

```swift
            if access.isGranted {
                journal
                    .transition(.opacity)
            } else {
                AccessScreen(palette: palette, onOpenSettings: onOpenAccessSettings, onClose: onClose)
                    .transition(.opacity)
            }
```

Найти:

```swift
        .animation(.easeOut(duration: 0.16), value: entryPendingDeletion)
```

Заменить на:

```swift
        .animation(.easeOut(duration: 0.16), value: entryPendingDeletion)
        .animation(.easeOut(duration: 0.2), value: access.isGranted)
```

Найти:

```swift
        .onReceive(keyEvents) { handleKey($0) }
    }

    // MARK: Sidebar
```

Заменить на:

```swift
        .onReceive(keyEvents) { handleKey($0) }
    }

    /// The split journal: clips on the left, the selected clip in full on the right.
    private var journal: some View {
        GeometryReader { geometry in
            let width = sidebarWidth(in: geometry.size.width)

            HStack(spacing: 0) {
                sidebar
                    .frame(width: width)
                    .background(palette.sidebarTint)
                    .overlay(alignment: .trailing) {
                        palette.separator.frame(width: 1)
                    }
                    .overlay(alignment: .trailing) {
                        SidebarResizeHandle(
                            palette: palette,
                            onChanged: { translation in
                                let start = sidebarDragStartWidth ?? width
                                sidebarDragStartWidth = start
                                storedSidebarWidth = Double(clampedSidebarWidth(start + translation, in: geometry.size.width))
                            },
                            onEnded: { sidebarDragStartWidth = nil }
                        )
                        // Hit area spans 4 pt left of the divider to 10 pt right of it, so the
                        // border and the grab mark light up and drag as one.
                        .offset(x: 10)
                    }
                    .zIndex(1)

                detail
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(palette.detailTint)
            }
        }
    }

    // MARK: Sidebar
```

Сделать две детали видимыми модулю, их берёт `AccessScreen`. Найти `private struct GlassIconButton: View {` и заменить на `struct GlassIconButton: View {`. Найти `private struct WindowDragHandle: NSViewRepresentable {` и заменить на `struct WindowDragHandle: NSViewRepresentable {`.

- [ ] **Step 3: Доступ в контроллере панели**

В `Sources/BufferJournal/JournalPanelController.swift` найти:

```swift
    private let settings: AppSettings
    private let keys: JournalKeys
```

Заменить на:

```swift
    private let settings: AppSettings
    private let access: AccessGate
    private let keys: JournalKeys
```

Найти:

```swift
    init(store: ClipboardHistoryStore, writer: ClipboardWriter, settings: AppSettings, hotKeys: HotKeyController) {
        self.store = store
        self.writer = writer
        self.settings = settings
        keys = JournalKeys(hotKeys: hotKeys)
```

Заменить на:

```swift
    init(store: ClipboardHistoryStore, writer: ClipboardWriter, settings: AppSettings, hotKeys: HotKeyController, access: AccessGate) {
        self.store = store
        self.writer = writer
        self.settings = settings
        self.access = access
        keys = JournalKeys(hotKeys: hotKeys)
```

Найти:

```swift
            activationObservers.append(observer)
        }
    }
```

Заменить на:

```swift
            activationObservers.append(observer)
        }

        access.onChange = { [weak self] in
            self?.accessChanged()
        }
    }
```

Найти:

```swift
        positionIfNeeded(panel)
        panel.alphaValue = 0
        // Never key: typing stays with the app under the panel; the journal's keys come as hotkeys.
        panel.orderFrontRegardless()
        isPanelVisible = true
        updateKeys()
```

Заменить на:

```swift
        positionIfNeeded(panel)
        access.refresh()
        panel.level = .floating
        panel.alphaValue = 0
        // Never key: typing stays with the app under the panel; the journal's keys come as hotkeys.
        panel.orderFrontRegardless()
        isPanelVisible = true
        access.setPolling(true)
        updateKeys()
```

Найти:

```swift
        isPanelVisible = false
        updateKeys()
        savePosition(panel)
```

Заменить на:

```swift
        isPanelVisible = false
        access.setPolling(false)
        updateKeys()
        savePosition(panel)
```

Найти:

```swift
    private func updateKeys() {
        keys.isListening = JournalKeys.shouldListen(
            panelVisible: isPanelVisible,
            journalShown: true,
            stashActive: NSApp.isActive,
            menuOpen: isMenuOpen
        )
    }
```

Заменить на:

```swift
    private func updateKeys() {
        keys.isListening = JournalKeys.shouldListen(
            panelVisible: isPanelVisible,
            journalShown: access.isGranted,
            stashActive: NSApp.isActive,
            menuOpen: isMenuOpen
        )
    }

    private func accessChanged() {
        if access.isGranted, isPanelVisible, let panel {
            // Granted while System Settings was in front: come back over it with the journal.
            panel.level = .floating
            panel.orderFrontRegardless()
        }
        access.setPolling(isPanelVisible)
        updateKeys()
    }

    /// Asks for access and lowers the panel to the normal window level so it does not cover
    /// System Settings; the panel rises again once access is granted or on the next show.
    private func openAccessSettings() {
        access.request()
        panel?.level = .normal
    }
```

Найти:

```swift
            store: store,
            settings: settings,
            keyEvents: keys.events,
```

Заменить на:

```swift
            store: store,
            settings: settings,
            access: access,
            keyEvents: keys.events,
```

Найти:

```swift
            onPreviewImage: { [weak self] entry in
                self?.openImagePreview(for: entry)
            },
            onClose: { [weak self] in
```

Заменить на:

```swift
            onPreviewImage: { [weak self] entry in
                self?.openImagePreview(for: entry)
            },
            onOpenAccessSettings: { [weak self] in
                self?.openAccessSettings()
            },
            onClose: { [weak self] in
```

Найти:

```swift
    /// Pastes the clip into the app under the panel and returns whether it did.
    func paste(_ entry: ClipboardEntry) -> Bool {
        perform { [writer] in writer.paste(entry) }
        return true
    }
```

Заменить на:

```swift
    /// Pastes the clip into the app under the panel. Without Accessibility access nothing is
    /// pasted, the panel turns to the access screen and this returns false.
    func paste(_ entry: ClipboardEntry) -> Bool {
        guard access.refresh() else { return false }
        perform { [writer] in writer.paste(entry) }
        return true
    }
```

- [ ] **Step 4: Доступ при запуске**

В `Sources/BufferJournal/AppDelegate.swift` найти:

```swift
    private var settings: AppSettings!
    private var panelController: JournalPanelController!
```

Заменить на:

```swift
    private var settings: AppSettings!
    private var access: AccessGate!
    private var panelController: JournalPanelController!
```

Найти:

```swift
        settings = AppSettings()
        hotKeyController = HotKeyController()
```

Заменить на:

```swift
        settings = AppSettings()
        access = AccessGate()
        hotKeyController = HotKeyController()
```

Найти:

```swift
            settings: settings,
            hotKeys: hotKeyController
        )
```

Заменить на:

```swift
            settings: settings,
            hotKeys: hotKeyController,
            access: access
        )
```

Найти:

```swift
        configureStatusItem()
        monitor.start()
    }
```

Заменить на:

```swift
        configureStatusItem()
        monitor.start()

        // Pasting needs Accessibility access; without it the panel opens right away on the access screen.
        if !access.isGranted {
            panelController.show()
        }
    }
```

- [ ] **Step 5: Вставка без запроса доступа**

В `Sources/BufferJournal/ClipboardWriter.swift` найти:

```swift
import AppKit
import ApplicationServices
import Foundation
```

Заменить на:

```swift
import AppKit
import Foundation
```

Найти:

```swift
    func paste(_ entry: ClipboardEntry) {
        copy(entry)

        if !isAccessibilityTrusted {
            requestAccessibilityIfNeeded()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            Self.sendCommandV()
        }
    }

    var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    func requestAccessibilityIfNeeded() {
        guard !isAccessibilityTrusted else { return }
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
```

Заменить на:

```swift
    /// Puts the clip on the pasteboard and presses ⌘V in the frontmost app. macOS lets this
    /// through only with Accessibility access, which `JournalPanelController` checks first.
    func paste(_ entry: ClipboardEntry) {
        copy(entry)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            Self.sendCommandV()
        }
    }
```

- [ ] **Step 6: README**

В `README.md` найти:

```
Paste on Selection needs Accessibility access in System Settings → Privacy & Security.
```

Заменить на:

```
Stash needs Accessibility access to paste (System Settings → Privacy & Security → Accessibility); until it has it, the journal shows an access screen with a button that opens those settings. The app is signed ad hoc, so macOS treats every update as a new app: if the access screen stays although Stash is switched on, remove Stash from the list with − and click Open Settings again.
```

- [ ] **Step 7: Сборка и тесты**

Run: `swift build && swift test`
Expected: `Build complete!` без предупреждений, 12 тестов проходят. `grep -rn "isAccessibilityTrusted\|requestAccessibilityIfNeeded" Sources` ничего не находит.

- [ ] **Step 8: Проверка вручную**

Закрыть установленный Stash, выполнить `Scripts/build_app.sh`. Снимать и выдавать доступ — дело пользователя.

- Без доступа: `open .build/Stash.app` — панель открывается сама, на ней экран доступа. ✕ и ⌥V закрывают её. Клавиши на экране доступа не перехватываются. Подсказки у ✕ видны.
- «Открыть настройки»: появляется системный запрос и открывается раздел Универсального доступа, а панель уходит под окно настроек. Если адрес раздела на этой macOS не открывается, записать это в риски спеки.
- Включить Stash в списке: в течение секунды экран растворяется в журнал, панель поднимается над настройками, клавиши журнала работают.
- С доступом: запуск не открывает панель. ⌥V открывает журнал.
- Светлая и тёмная тема, темы Stash, русский и английский язык: экран доступа и кнопка «Скопировать в буфер».
- Полный список ручных проверок спеки (раздел «Тесты»): пройти его целиком на этой сборке.

- [ ] **Step 9: Коммит**

```bash
git add Sources/BufferJournal/AccessScreen.swift Sources/BufferJournal/JournalView.swift Sources/BufferJournal/JournalPanelController.swift Sources/BufferJournal/AppDelegate.swift Sources/BufferJournal/ClipboardWriter.swift README.md
git commit -m "Require Accessibility access with an access screen in the panel" -m "- Without access the panel shows an access screen instead of the
  journal and opens on it at launch; it checks once a second and turns
  into the journal as soon as access appears
- Open Settings asks through the system prompt, opens the Accessibility
  settings and lowers the panel so it does not cover them
- Access is checked before every paste; the writer no longer asks"
```

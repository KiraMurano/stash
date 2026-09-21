# Три отдельных окна Stash — план реализации

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Обновление, «О приложении» и обучение переезжают с панели журнала каждое в своё окно: два первых висят у значка в строке меню, тур встаёт по центру экрана.

**Architecture:** Одно общее окно-спутник (`AccessoryWindow`) — безрамочная `NSPanel`, которая никогда не берёт клавиатуру и встаёт по правилу, а не по воле пользователя. Место ей считает чистая функция `StatusItemAnchor`. Три экрана остаются теми же `View`, что и сейчас; из `JournalView` они уходят, а `AppDelegate` держит три экземпляра окна и зовёт их из меню.

**Tech Stack:** Swift 6, SwiftUI, AppKit (`NSPanel`, `NSHostingView`), swift-testing (`import Testing`), SwiftPM. Платформа — macOS 13.

**Spec:** [`docs/superpowers/specs/2026-09-21-separate-windows-design.md`](../specs/2026-09-21-separate-windows-design.md)

## Global Constraints

- Ширина окон обновления и «О приложении» — **400 pt**. Высота — по содержимому.
- Окно обучения — **640 × 440**, фиксированное, по центру экрана.
- Правый край окна у значка — на **6 pt** правее правого края значка; верх — на **8 pt** ниже строки меню; поле до краёв экрана — **12 pt**; поле снизу под потолок высоты — **16 pt**.
- Радиус окон обновления и «О приложении» — **20**, окна обучения — **24**.
- Полоса загрузки — **3 pt**, во всю ширину окна, трек `ThemePalette.orange` при 0,18 в светлой и 0,28 в тёмной, заливка — сплошной `ThemePalette.orange`.
- Кегль вордмарка на «О приложении» — **38 pt**.
- Ни одно из трёх окон не берёт клавиатуру, не меняет размер мышью и не запоминает положение между запусками.
- Комментарии и сообщения коммитов в этом репозитории — по-английски, в повелительном наклонении, без префиксов вроде `feat:`.
- Тесты гоняются `swift test`; до начала работы их 195 и все зелёные.
- Стендов и отдельных песочниц не заводим: правим приложение и чиним те тесты, которые ломаются.

## Карта файлов

| Файл | За что отвечает |
|---|---|
| `Sources/BufferJournal/Windows/StatusItemAnchor.swift` — создать | Чистая арифметика: где встаёт окно, висящее у значка. |
| `Sources/BufferJournal/Windows/AccessoryWindow.swift` — создать | Безрамочная панель-спутник: создание, показ, уход, место, потолок высоты, клик мимо. |
| `Tests/BufferJournalTests/StatusItemAnchorTests.swift` — создать | Проверки арифметики привязки. |
| `Tests/BufferJournalTests/AccessoryWindowTests.swift` — создать | Проверки потолка высоты. |
| `Sources/BufferJournal/Updates/UpdateView.swift` — переписать середину и футер | Список на голом поле, полоса над футером, футер без строки слева. |
| `Sources/BufferJournal/Updates/UpdateController.swift` — убрать `isPresented`/`close()` | Видимостью владеет окно; у контроллера остаётся только отметка «версию видели». |
| `Sources/BufferJournal/About/AboutView.swift` — футер и кегль | Одна ссылка по центру, вордмарк 38 pt. |
| `Sources/BufferJournal/About/AboutController.swift` — убрать показ и обратную связь | Остаются версия и адрес репозитория. |
| `Sources/BufferJournal/Onboarding/OnboardingController.swift` — `close()` | Тур больше не передаёт эстафету экрану доступа. |
| `Sources/BufferJournal/AppDelegate.swift` | Три окна, пункты меню, что делать после тура. |
| `Sources/BufferJournal/JournalView.swift` | Теряет три слоя и три `@ObservedObject`. |
| `Sources/BufferJournal/JournalPanelController.swift` | Теряет три подписки, три поля и три метода. |
| `Sources/BufferJournal/JournalKeys.swift` | `PanelContent` уходит; режим клавиш считается от одного флага. |

---

### Task 1: Привязка окна к значку

Чистая арифметика, поэтому её можно проверить без единого окна на экране — как уже сделано с `PanelPlacement`.

**Files:**
- Create: `Sources/BufferJournal/Windows/StatusItemAnchor.swift`
- Test: `Tests/BufferJournalTests/StatusItemAnchorTests.swift`

**Interfaces:**
- Consumes: ничего.
- Produces: `enum StatusItemAnchor` с константами `rightInset: CGFloat = 6`, `topGap: CGFloat = 8`, `screenMargin: CGFloat = 12`, `bottomMargin: CGFloat = 16` и функцией `static func origin(itemFrame: NSRect, windowSize: NSSize, visibleFrame: NSRect) -> NSPoint`.

- [ ] **Step 1: Написать падающий тест**

Создать `Tests/BufferJournalTests/StatusItemAnchorTests.swift`:

```swift
import AppKit
import Testing
@testable import BufferJournal

struct StatusItemAnchorTests {
    /// Экран 1440 × 900 с 24-точечной строкой меню сверху.
    private let screen = NSRect(x: 0, y: 0, width: 1440, height: 876)
    private let size = NSSize(width: 400, height: 300)

    @Test func theWindowHangsFromTheRightEdgeOfTheIcon() {
        let item = NSRect(x: 1000, y: 876, width: 24, height: 24)
        let origin = StatusItemAnchor.origin(itemFrame: item, windowSize: size, visibleFrame: screen)

        #expect(origin.x + size.width == item.maxX + StatusItemAnchor.rightInset)
    }

    @Test func theTopEdgeSitsUnderTheMenuBar() {
        let item = NSRect(x: 1000, y: 876, width: 24, height: 24)
        let origin = StatusItemAnchor.origin(itemFrame: item, windowSize: size, visibleFrame: screen)

        #expect(origin.y + size.height == screen.maxY - StatusItemAnchor.topGap)
    }

    /// Значок у самого правого края: окно не вылезает за экран.
    @Test func theWindowStopsAtTheRightEdgeOfTheScreen() {
        let item = NSRect(x: 1430, y: 876, width: 10, height: 24)
        let origin = StatusItemAnchor.origin(itemFrame: item, windowSize: size, visibleFrame: screen)

        #expect(origin.x + size.width == screen.maxX - StatusItemAnchor.screenMargin)
    }

    /// Окно шире экрана прижимается к левому краю, а не уезжает за него.
    @Test func theWindowStopsAtTheLeftEdgeOfTheScreen() {
        let item = NSRect(x: 100, y: 876, width: 24, height: 24)
        let wide = NSSize(width: 1600, height: 300)
        let origin = StatusItemAnchor.origin(itemFrame: item, windowSize: wide, visibleFrame: screen)

        #expect(origin.x == screen.minX + StatusItemAnchor.screenMargin)
    }

    /// Второй экран слева от главного: координаты отрицательные, привязка та же.
    @Test func itWorksOnAScreenWithNegativeCoordinates() {
        let left = NSRect(x: -1680, y: 0, width: 1680, height: 1050)
        let item = NSRect(x: -400, y: 1050, width: 24, height: 24)
        let origin = StatusItemAnchor.origin(itemFrame: item, windowSize: size, visibleFrame: left)

        #expect(origin.x + size.width == item.maxX + StatusItemAnchor.rightInset)
        #expect(origin.y + size.height == left.maxY - StatusItemAnchor.topGap)
    }
}
```

- [ ] **Step 2: Убедиться, что тесты падают**

Run: `swift test --filter StatusItemAnchorTests`
Expected: FAIL, сборка не проходит — `cannot find 'StatusItemAnchor' in scope`.

- [ ] **Step 3: Написать реализацию**

Создать `Sources/BufferJournal/Windows/StatusItemAnchor.swift`:

```swift
import AppKit

/// Where a window hanging from the status item goes.
///
/// Not under the middle of the icon: the status item sits near the right edge of the menu bar,
/// and a window centred on it is pushed left by the edge of the screen almost every time — the
/// concept measured 101 pt of drift even with three other icons to the right of ours. The right
/// edge of the window is tied to the right edge of the icon instead, so nothing ever drifts
/// (`.concepts/2026-09-21-separate-windows-round1.html`, variant 3.2).
enum StatusItemAnchor {
    /// How far the window's right edge sits past the icon's.
    static let rightInset: CGFloat = 6
    /// Between the menu bar and the top of the window.
    static let topGap: CGFloat = 8
    /// The least room left between the window and the sides of the screen.
    static let screenMargin: CGFloat = 12
    /// The least room left under a window that grows with its content.
    static let bottomMargin: CGFloat = 16

    /// `itemFrame` is the status item button's frame in screen coordinates, `visibleFrame` the
    /// screen's usable area — it already excludes the menu bar.
    static func origin(itemFrame: NSRect, windowSize: NSSize, visibleFrame: NSRect) -> NSPoint {
        let right = min(itemFrame.maxX + rightInset, visibleFrame.maxX - screenMargin)
        let x = max(right - windowSize.width, visibleFrame.minX + screenMargin)
        let y = visibleFrame.maxY - topGap - windowSize.height
        return NSPoint(x: x, y: y)
    }
}
```

- [ ] **Step 4: Убедиться, что тесты проходят**

Run: `swift test --filter StatusItemAnchorTests`
Expected: PASS, 5 тестов.

- [ ] **Step 5: Коммит**

```bash
git add Sources/BufferJournal/Windows/StatusItemAnchor.swift Tests/BufferJournalTests/StatusItemAnchorTests.swift
git commit -m "$(cat <<'EOF'
Work out where a window hangs from the status item
EOF
)"
```

---

### Task 2: Окно-спутник

Общая панель для трёх экранов. Проверяем тестом только то, что поддаётся проверке без экрана, — потолок высоты; остальное проверяется глазами в Task 3.

**Files:**
- Create: `Sources/BufferJournal/Windows/AccessoryWindow.swift`
- Test: `Tests/BufferJournalTests/AccessoryWindowTests.swift`

**Interfaces:**
- Consumes: `StatusItemAnchor.origin(itemFrame:windowSize:visibleFrame:)`, `StatusItemAnchor.topGap`, `.bottomMargin`; `PanelPresentation.appearDuration`, `.disappearDuration` из `JournalPanelController.swift`.
- Produces:
  - `AccessoryWindow<Content: View>` c `init(placement:sizing:cornerRadius:closesOnOutsideClick:rootView:)`, методами `show()`, `close()` и свойством `isVisible: Bool`.
  - `AccessoryWindow.Placement`: `.statusItem(() -> NSRect?)`, `.center`.
  - `AccessoryWindow.Sizing`: `.fixed(NSSize)`, `.fitsContent(width: CGFloat)`.
  - `static func heightCap(visibleFrame: NSRect) -> CGFloat`.

- [ ] **Step 1: Написать падающий тест**

Создать `Tests/BufferJournalTests/AccessoryWindowTests.swift`:

```swift
import AppKit
import SwiftUI
import Testing
@testable import BufferJournal

@MainActor
struct AccessoryWindowTests {
    /// Потолок — вся полезная высота экрана без зазора сверху и поля снизу.
    @Test func theCapIsTheScreenLessTheGapAndTheMargin() {
        let screen = NSRect(x: 0, y: 0, width: 1440, height: 876)
        let cap = AccessoryWindow<EmptyView>.heightCap(visibleFrame: screen)

        #expect(cap == 876 - StatusItemAnchor.topGap - StatusItemAnchor.bottomMargin)
    }

    /// На крошечном экране потолок не уходит в ноль и не становится отрицательным.
    @Test func theCapNeverFallsBelowAFloor() {
        let tiny = NSRect(x: 0, y: 0, width: 800, height: 40)
        #expect(AccessoryWindow<EmptyView>.heightCap(visibleFrame: tiny) == 120)
    }
}
```

- [ ] **Step 2: Убедиться, что тесты падают**

Run: `swift test --filter AccessoryWindowTests`
Expected: FAIL, сборка не проходит — `cannot find 'AccessoryWindow' in scope`.

- [ ] **Step 3: Написать реализацию**

Создать `Sources/BufferJournal/Windows/AccessoryWindow.swift`:

```swift
import AppKit
import QuartzCore
import SwiftUI

/// A window of Stash that is not the journal: the update screen, About and the tour.
///
/// Borderless and never key, like the journal panel — whatever the person types keeps going to
/// the app underneath. Unlike the journal it is placed by a rule rather than by the person: it
/// hangs from the status item or stands in the middle of the screen, so it neither moves nor
/// remembers where it was.
@MainActor
final class AccessoryWindow<Content: View> {
    enum Placement {
        /// Right edge just past the status item's, top edge under the menu bar. The closure is
        /// asked every time the window is shown: the item moves as other menu bar icons come and go.
        case statusItem(() -> NSRect?)
        /// The middle of the screen, a touch above centre, like the journal panel's own fallback.
        case center
    }

    enum Sizing {
        case fixed(NSSize)
        /// Fixed width; the height is whatever the content asks for, capped by the screen.
        case fitsContent(width: CGFloat)
    }

    /// The tallest a window that grows with its content may be.
    static func heightCap(visibleFrame: NSRect) -> CGFloat {
        max(120, visibleFrame.height - StatusItemAnchor.topGap - StatusItemAnchor.bottomMargin)
    }

    private let placement: Placement
    private let sizing: Sizing
    private let closesOnOutsideClick: () -> Bool
    private let panel: NSPanel
    private let hostingView: NSHostingView<Content>
    private var heightCapConstraint: NSLayoutConstraint?
    private var outsideClickMonitor: Any?
    private var resizeObserver: NSObjectProtocol?

    var isVisible: Bool { panel.isVisible }

    init(
        placement: Placement,
        sizing: Sizing,
        cornerRadius: CGFloat,
        closesOnOutsideClick: @escaping () -> Bool = { false },
        rootView: Content
    ) {
        self.placement = placement
        self.sizing = sizing
        self.closesOnOutsideClick = closesOnOutsideClick

        hostingView = FirstMouseHostingView(rootView: rootView)
        hostingView.wantsLayer = true
        hostingView.layer?.cornerRadius = cornerRadius
        hostingView.layer?.cornerCurve = .continuous
        hostingView.layer?.masksToBounds = true

        let initialSize: NSSize
        switch sizing {
        case .fixed(let size):
            initialSize = size
        case .fitsContent(let width):
            // Replaced by the content's own height the moment it reports one.
            initialSize = NSSize(width: width, height: 200)
        }

        panel = NeverKeyPanel(
            contentRect: NSRect(origin: .zero, size: initialSize),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hostingView
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.animationBehavior = .none
        // Stash stays inactive while these windows are open; without this their tooltips never show.
        panel.allowsToolTipsWhenApplicationIsInactive = true
        panel.canHide = false

        if case .fitsContent(let width) = sizing {
            hostingView.sizingOptions = [.intrinsicContentSize]
            hostingView.widthAnchor.constraint(equalToConstant: width).isActive = true
            let cap = hostingView.heightAnchor.constraint(lessThanOrEqualToConstant: 10_000)
            cap.isActive = true
            heightCapConstraint = cap

            // The content decides the height, so the window resizes on its own — from its bottom
            // left corner. Placing it again after every resize keeps its top edge under the menu bar.
            resizeObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didResizeNotification, object: panel, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.applyPlacement() }
            }
        }
    }

    deinit {
        if let resizeObserver {
            NotificationCenter.default.removeObserver(resizeObserver)
        }
    }

    func show() {
        if case .fitsContent = sizing, let screen = currentScreen {
            heightCapConstraint?.constant = Self.heightCap(visibleFrame: screen.visibleFrame)
        }
        panel.layoutIfNeeded()
        applyPlacement()
        panel.alphaValue = 0
        // Never key: typing stays with the app under the window.
        panel.orderFrontRegardless()
        watchOutsideClicks()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = PanelPresentation.appearDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }

    func close() {
        stopWatchingOutsideClicks()
        guard panel.isVisible else { return }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = PanelPresentation.disappearDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        } completionHandler: { [weak panel] in
            Task { @MainActor in
                panel?.orderOut(nil)
                panel?.alphaValue = 1
            }
        }
    }

    private var currentScreen: NSScreen? {
        if case .statusItem(let itemFrame) = placement, let frame = itemFrame() {
            return NSScreen.screens.first { $0.frame.intersects(frame) } ?? NSScreen.main
        }
        return NSScreen.main
    }

    private func applyPlacement() {
        switch placement {
        case .statusItem(let itemFrame):
            guard let frame = itemFrame(), let screen = currentScreen else { return }
            panel.setFrameOrigin(StatusItemAnchor.origin(
                itemFrame: frame,
                windowSize: panel.frame.size,
                visibleFrame: screen.visibleFrame
            ))
        case .center:
            guard let screen = NSScreen.main else {
                panel.center()
                return
            }
            let visible = screen.visibleFrame
            let size = panel.frame.size
            panel.setFrameOrigin(NSPoint(
                x: visible.midX - size.width / 2,
                y: visible.midY - size.height / 2 + 40
            ))
        }
    }

    /// A global monitor never sees clicks on Stash itself, so whatever it reports happened
    /// somewhere else. The predicate is asked at the moment of the click, not when the monitor
    /// is installed: the update window stays put while it is downloading.
    private func watchOutsideClicks() {
        guard outsideClickMonitor == nil else { return }
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.closesOnOutsideClick() else { return }
                self.close()
            }
        }
    }

    private func stopWatchingOutsideClicks() {
        guard let outsideClickMonitor else { return }
        NSEvent.removeMonitor(outsideClickMonitor)
        self.outsideClickMonitor = nil
    }
}

/// Never key: the keyboard stays with the app the person is typing in, even after a click.
private final class NeverKeyPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}
```

- [ ] **Step 4: Убедиться, что тесты проходят и всё собирается**

Run: `swift test --filter AccessoryWindowTests`
Expected: PASS, 2 теста.

Run: `swift build`
Expected: сборка без ошибок и без новых предупреждений.

- [ ] **Step 5: Коммит**

```bash
git add Sources/BufferJournal/Windows/AccessoryWindow.swift Tests/BufferJournalTests/AccessoryWindowTests.swift
git commit -m "$(cat <<'EOF'
Add the window the screens that are not the journal live in
EOF
)"
```

---

### Task 3: Окно обновления

Экран перестаёт быть слоем на панели и становится окном у значка: список на голом поле, полоса над футером, в футере только действия.

**Files:**
- Modify: `Sources/BufferJournal/Updates/UpdateView.swift` (переписать `Metrics`, `body`, `head`, середину и футер)
- Modify: `Sources/BufferJournal/Updates/UpdateController.swift:29,158-167`
- Modify: `Sources/BufferJournal/AppDelegate.swift`
- Modify: `Sources/BufferJournal/JournalView.swift:44,152-157,195`
- Modify: `Sources/BufferJournal/JournalPanelController.swift:163-168`
- Test: `Tests/BufferJournalTests/UpdateControllerTests.swift:135-160`, `Tests/BufferJournalTests/UpdateTextsTests.swift:14-30`, `Tests/BufferJournalTests/SnapshotTests.swift:170-195`

**Interfaces:**
- Consumes: `AccessoryWindow`, `StatusItemAnchor`.
- Produces:
  - `UpdateView(controller:l10n:onClose:scrolls:)` — новый параметр `onClose: () -> Void` вместо `controller.close()`.
  - `UpdateController.markSeen()` вместо `present()`; `isPresented` и `close()` удалены.
  - `AppDelegate.updateWindow: AccessoryWindow<UpdateView>`.

- [ ] **Step 1: Снять с контроллера показ экрана**

В `Sources/BufferJournal/Updates/UpdateController.swift` удалить строку `@Published private(set) var isPresented = false` и заменить блок `// MARK: The screen` целиком на:

```swift
    // MARK: The screen

    /// Opening the screen counts as having seen this version, so the dot goes out even if the
    /// answer is "Later". The window itself decides whether it is on screen; the controller
    /// holds no state about that.
    func markSeen() {
        guard let release else { return }
        defaults.set(release.version.description, forKey: Self.seenVersionKey)
    }

    func openReleasesPage() {
        NSWorkspace.shared.open(Self.releasesPage)
    }
```

- [ ] **Step 2: Починить тесты контроллера**

В `Tests/BufferJournalTests/UpdateControllerTests.swift` заменить два теста — `openingTheScreenPutsTheBadgeOut` и `laterKeepsTheBadgeOut` — на один: оба проверяли одно и то же про значок, а разницу между ними делал `isPresented`, которого больше нет.

```swift
    @Test func openingTheScreenPutsTheBadgeOut() async {
        let (controller, _) = controller(checker: .success(release("1.27")))
        await controller.check(manual: true)
        #expect(controller.isBadgeVisible)

        controller.markSeen()
        #expect(!controller.isBadgeVisible)
    }
```

В тесте `theNextReleaseLightsItAgain` заменить строку `seen.present()` на `seen.markSeen()`.

- [ ] **Step 3: Прогнать тесты — падают там, где ждём**

Run: `swift test --filter UpdateControllerTests`
Expected: FAIL сборки — `JournalView.swift` и `UpdateView.swift` ещё зовут `controller.close()` и `updates.isPresented`.

- [ ] **Step 4: Переписать экран**

В `Sources/BufferJournal/Updates/UpdateView.swift`:

1. Шапку файла заменить на:

```swift
/// The update screen, in a window of its own that hangs from the status item. The release notes
/// stand on the bare field — the window is the card now — the download runs as a 3 pt line above
/// the footer, and the footer carries nothing but the actions
/// (`.concepts/2026-09-21-separate-windows.html`, variants 1.1, 2.1, 1.1.1).
```

2. Объявление и `Metrics`:

```swift
struct UpdateView: View {
    @ObservedObject var controller: UpdateController
    let l10n: L10n
    /// Closes the window. The screen holds no state about being on screen; the window does.
    let onClose: () -> Void
    /// Off only for the snapshots: ImageRenderer draws a ScrollView as an empty box.
    var scrolls = true

    @Environment(\.colorScheme) private var colorScheme

    private enum Metrics {
        static let top: CGFloat = 12
        static let side: CGFloat = 20
        static let bottom: CGFloat = 16
        static let gap: CGFloat = 10
        static let headHeight: CGFloat = 28
        static let buttonHeight: CGFloat = 36
        static let textSize: CGFloat = 13
        /// The lone answer on the field carries the screen, so it is larger than body text.
        static let answerSize: CGFloat = 17
        static let notesSpacing: CGFloat = 8
        /// The marker's column and the 12×3 bar inside it.
        static let markColumn: CGFloat = 14
        static let markWidth: CGFloat = 12
        static let markHeight: CGFloat = 3
        /// One line of 13 pt text at line height 1.4.
        static let lineHeight: CGFloat = 18
        static let titleSize: CGFloat = 18
        static let iconFrame: CGFloat = 21
        /// The download line above the footer.
        static let bar: CGFloat = 3
    }
```

Удалены: `cardRadius`, `progressWidth`, `notesPadding`.

3. `body`:

```swift
    var body: some View {
        ZStack(alignment: .topLeading) {
            colors.field

            VStack(spacing: 0) {
                head
                // The notes stand on the field: the window's own edge does what the card did.
                // Without a release — checking, nothing new, a check that failed — one line
                // stands there instead.
                if controller.release != nil {
                    notes.padding(.top, Metrics.gap)
                } else {
                    answer.padding(.top, Metrics.gap)
                }
                if let fill = progressFill {
                    progressBar(fill).padding(.top, Metrics.gap)
                }
                footer.padding(.top, Metrics.gap)
            }
            .padding(.top, Metrics.top)
            .padding(.horizontal, Metrics.side)
            .padding(.bottom, Metrics.bottom)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(l10n("Stash update", "Обновление Stash"))
        .accessibilityAddTraits(.isModal)
    }
```

4. Шапка теряет `WindowDragHandle` — окно привязано к значку, таскать его некуда. В `head` убрать строку `.background(WindowDragHandle())`, а `closeButton` зовёт `onClose()` вместо `controller.close()`.

5. Удалить `card` целиком. `notes` теряет `.padding(Metrics.notesPadding)`, и `scrollIfNeeded` остаётся как есть:

```swift
    private var notes: some View {
        scrollIfNeeded {
            VStack(alignment: .leading, spacing: Metrics.notesSpacing) {
                ForEach(ReleaseNotes.parse(controller.release?.notes ?? "")) { note in
                    switch note.kind {
                    case .item: item(note.text)
                    case .paragraph: paragraph(note.text)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
```

6. Полоса и футер — заменить `footer`, `meta`, `current`, `actions` и `bar` на:

```swift
    // MARK: Progress

    /// How far the bar is filled, or nil when nothing is being downloaded or installed.
    private var progressFill: Double? {
        switch controller.state {
        case .downloading(let progress): min(max(progress, 0), 1)
        case .installing: 1
        default: nil
        }
    }

    /// A 3 pt line across the whole window, where the bottom of the card used to be. The side
    /// padding is undone so it runs edge to edge; the percentage is said in words in the footer.
    private func progressBar(_ fill: Double) -> some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(progressTrack)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(ThemePalette.orange)
                        .frame(width: geometry.size.width * fill)
                }
        }
        .frame(height: Metrics.bar)
        .padding(.horizontal, -Metrics.side)
        .accessibilityHidden(true)
    }

    /// The unfilled part of the bar: a tint of the same orange. The Stash themes paint their
    /// accents solid, so `palette.segmentThumb` would give the fill's own colour and hide it.
    private var progressTrack: Color {
        ThemePalette.orange.opacity(colorScheme == .dark ? 0.28 : 0.18)
    }

    // MARK: Footer

    private var footer: some View {
        HStack(alignment: .center, spacing: 16) {
            // The left of the footer is used only while something is happening. "Now 1.26 · 4.2 MB"
            // used to stand here and broke into three lines at 400 pt (concept round 2, 1.1.1).
            if let status = statusLine {
                Text(status)
                    .font(.system(size: Metrics.textSize))
                    .foregroundStyle(palette.textSecondary)
            }
            Spacer(minLength: 0)
            actions
        }
        .frame(minHeight: Metrics.buttonHeight)
    }

    private var statusLine: String? {
        switch controller.state {
        case .downloading(let progress): l10n.updateDownloading(progress)
        case .installing: l10n.updateInstalling
        default: nil
        }
    }

    @ViewBuilder
    private var actions: some View {
        switch controller.state {
        case .downloading, .installing:
            // The bar above says what is happening; there is nothing to press.
            EmptyView()
        case .failed:
            primary(l10n.updateOpenReleases) { controller.openReleasesPage() }
        case .available:
            // The style paints its hover tint straight behind the label, so the padding and the
            // height belong to the label.
            Button(action: onClose) {
                Text(l10n.updateLater)
                    .font(.system(size: Metrics.textSize, weight: .semibold))
                    .padding(.horizontal, 12)
                    .frame(height: Metrics.buttonHeight)
            }
            .buttonStyle(OnboardingCloseButtonStyle(color: colors.close))

            primary(l10n.updateNow) { controller.install() }
        default:
            // Checking, and nothing new: there is nothing to do but close the window.
            primary(l10n.updateClose, action: onClose)
        }
    }
```

7. `primary` оставить как есть.

- [ ] **Step 5: Снять экран с панели**

В `Sources/BufferJournal/JournalView.swift` удалить `@ObservedObject var updates: UpdateController`, блок `if updates.isPresented { UpdateView(...) }` (строки 152–157) и строку `.animation(.easeOut(duration: 0.2), value: updates.isPresented)`.

В `Sources/BufferJournal/JournalPanelController.swift` удалить метод `showUpdate()`, поле `private let updates: UpdateController`, параметр `updates:` в `init` и его присваивание, подписку `updatesObserver` вместе с полем, и `updates: updates` из вызова `JournalView(...)`. В `panelContent` пока оставить `updatePresented: false` — строку уберёт Task 6.

- [ ] **Step 6: Завести окно и повесить на пункт меню**

В `Sources/BufferJournal/AppDelegate.swift` добавить поле и построение окна после создания `updates` и `panelController`:

```swift
    private var updateWindow: AccessoryWindow<UpdateView>!
```

```swift
        updateWindow = AccessoryWindow(
            placement: .statusItem { [weak self] in
                guard let button = self?.statusItem.button, let window = button.window else { return nil }
                return window.convertToScreen(button.convert(button.bounds, to: nil))
            },
            sizing: .fitsContent(width: 400),
            cornerRadius: 20,
            // While the image is coming down or going in, a click elsewhere must not take the
            // progress off the screen.
            closesOnOutsideClick: { [weak self] in
                guard let self else { return false }
                switch self.updates.state {
                case .downloading, .installing: return false
                default: return true
                }
            },
            rootView: UpdateView(
                controller: updates,
                l10n: settings.l10n,
                onClose: { [weak self] in self?.updateWindow.close() }
            )
        )
```

Этот блок ставится **после** вызова `configureStatusItem()` в `applicationDidFinishLaunching`: замыкание читает `statusItem.button`, которого до него ещё нет.

Заменить `openUpdates()`:

```swift
    @objc private func openUpdates() {
        aboutWindow?.close()
        updates.markSeen()
        updateWindow.show()
        guard updates.release == nil else { return }
        Task { await updates.check(manual: true) }
    }
```

`aboutWindow` появляется в Task 4 — в этой задаче строку `aboutWindow?.close()` не пишите, она добавится там.

- [ ] **Step 7: Починить снимки**

В `Tests/BufferJournalTests/SnapshotTests.swift`, в `theUpdateScreenRenders`, заменить тройной цикл на двойной: ширина у окна теперь одна, а высота — по содержимому.

Было:

```swift
        for (state, name, withRelease) in states {
            for (scheme, schemeName) in Self.schemes {
                for size in Self.sizes {
                    let view = UpdateView(controller: updateController(state, withRelease: withRelease), l10n: L10n(language: .russian), scrolls: false)
                        .frame(width: size.width, height: size.height)
                        .environment(\.colorScheme, scheme)
                    try render(view, name: "update-\(name)-\(schemeName)-\(Int(size.width))")
                }
            }
        }
```

Стало:

```swift
        for (state, name, withRelease) in states {
            for (scheme, schemeName) in Self.schemes {
                let view = UpdateView(
                    controller: updateController(state, withRelease: withRelease),
                    l10n: L10n(language: .russian),
                    onClose: {},
                    scrolls: false
                )
                .frame(width: 400)
                .environment(\.colorScheme, scheme)
                try render(view, name: "update-\(name)-\(schemeName)")
            }
        }
```

- [ ] **Step 8: Прогнать все тесты**

Run: `swift test`
Expected: PASS. Тестов станет 194: два теста `UpdateControllerTests` про `isPresented` слились в один.

- [ ] **Step 9: Собрать и посмотреть глазами**

Run: `Scripts/build_app.sh && open .build/Stash.app`

Проверить: пункт «Проверить обновления…» открывает окно шириной 400 под значком, правым краем чуть правее значка; карточки внутри нет; клик мимо закрывает окно.

- [ ] **Step 10: Коммит**

```bash
git add -A
git commit -m "$(cat <<'EOF'
Give the update screen a window of its own

The notes stand on the bare field, the download runs as a line above the
footer, and the footer carries only the actions: "Now 1.26 · 4.2 MB" broke
into three lines at 400 pt and said nothing the head does not.
EOF
)"
```

---

### Task 4: Окно «О приложении»

**Files:**
- Modify: `Sources/BufferJournal/About/AboutView.swift`
- Modify: `Sources/BufferJournal/About/AboutController.swift`
- Modify: `Sources/BufferJournal/AppDelegate.swift`
- Modify: `Sources/BufferJournal/JournalView.swift`, `Sources/BufferJournal/JournalPanelController.swift`
- Modify: `Sources/BufferJournal/Localization.swift:105`
- Test: `Tests/BufferJournalTests/AboutControllerTests.swift`, `Tests/BufferJournalTests/AboutTextsTests.swift:19-20`, `Tests/BufferJournalTests/SnapshotTests.swift:196-218`

**Interfaces:**
- Consumes: `AccessoryWindow`, `AboutController.repository`, `AboutController.currentVersion`.
- Produces: `AboutView(controller:l10n:onClose:)`; `AppDelegate.aboutWindow: AccessoryWindow<AboutView>`.

- [ ] **Step 1: Починить тесты под то, чего больше не будет**

В `Tests/BufferJournalTests/AboutControllerTests.swift` удалить тест `theScreenIsShownOnlyWhenAsked` целиком и заменить `theButtonAndTheLinkLeadToDifferentPages` на:

```swift
    /// Кнопки обратной связи на экране больше нет: у него нет главного действия,
    /// и остался только адрес репозитория.
    @Test func theLinkLeadsToTheRepository() {
        #expect(AboutController.repository.absoluteString == "https://github.com/KiraMurano/stash")
    }
```

В `Tests/BufferJournalTests/AboutTextsTests.swift` удалить две строки с `aboutFeedback`.

- [ ] **Step 2: Прогнать — падает сборка**

Run: `swift test --filter AboutControllerTests`
Expected: FAIL сборки: `AboutView` и `JournalView` ещё зовут то, что удаляется дальше.

- [ ] **Step 3: Обрезать контроллер**

В `Sources/BufferJournal/About/AboutController.swift` удалить `static let feedback`, `@Published private(set) var isPresented`, `present()`, `close()` и `openFeedback()`. Заголовок класса заменить на:

```swift
/// The About screen's outside world: the version it names and the one page it opens.
/// Whether the screen is on the screen is the window's business, not the controller's.
```

- [ ] **Step 4: Переписать экран**

В `Sources/BufferJournal/About/AboutView.swift`:

1. Шапку файла — на:

```swift
/// The About screen, in a window of its own that hangs from the status item. Head and footer are
/// the update screen's; the middle is bare field, with the studio's wordmark on it. The footer is
/// one link and no button: the screen has no main action and no longer pretends to
/// (`.concepts/2026-09-21-separate-windows-round1.html`, variant 4.2 without the button).
```

2. Добавить `let onClose: () -> Void` рядом с `l10n`, а `closeButton` перевести на `onClose()`.

3. В `Metrics` заменить кегль вордмарка:

```swift
        /// The window is 400 pt wide, so the column under the wordmark is 360: the widest
        /// setting at 56 pt needs 384 and would not fit.
        static let wordmarkSize: CGFloat = 38
```

4. Из `head` убрать `.background(WindowDragHandle())`.

5. Заменить `footer` целиком на:

```swift
    private var footer: some View {
        Button {
            controller.openRepository()
        } label: {
            Text(Self.repositoryLabel)
                .font(.system(size: Metrics.textSize))
                .foregroundStyle(palette.textSecondary)
                .underline(true, color: palette.textTertiary)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, minHeight: Metrics.buttonHeight)
    }
```

- [ ] **Step 5: Снять экран с панели и завести окно**

В `Sources/BufferJournal/JournalView.swift` удалить `@ObservedObject var about: AboutController`, блок `if about.isPresented { AboutView(...) }` и `.animation(..., value: about.isPresented)`.

В `Sources/BufferJournal/JournalPanelController.swift` удалить `showAbout()`, поле `about`, параметр `about:` в `init`, подписку `aboutObserver` и `about: about` из вызова `JournalView(...)`.

В `Sources/BufferJournal/AppDelegate.swift` добавить окно рядом с `updateWindow`:

```swift
    private var aboutWindow: AccessoryWindow<AboutView>!
```

```swift
        aboutWindow = AccessoryWindow(
            placement: .statusItem { [weak self] in
                guard let button = self?.statusItem.button, let window = button.window else { return nil }
                return window.convertToScreen(button.convert(button.bounds, to: nil))
            },
            sizing: .fitsContent(width: 400),
            cornerRadius: 20,
            closesOnOutsideClick: { true },
            rootView: AboutView(
                controller: about,
                l10n: settings.l10n,
                onClose: { [weak self] in self?.aboutWindow.close() }
            )
        )
```

и заменить `openAbout()`:

```swift
    @objc private func openAbout() {
        updateWindow.close()
        aboutWindow.show()
    }
```

- [ ] **Step 6: Починить снимок**

В `Tests/BufferJournalTests/SnapshotTests.swift`, в `theAboutScreenRenders`, убрать перебор `Self.sizes`, поставить ширину 400 и передать `onClose: {}`. Было три вложенных цикла с `try render(view, name: "about-\(languageName)-\(schemeName)-\(Int(size.width))")`, стало:

```swift
        for (language, languageName) in [(ResolvedLanguage.russian, "ru"), (.english, "en")] {
            for (scheme, schemeName) in Self.schemes {
                let view = AboutView(controller: controller, l10n: L10n(language: language), onClose: {})
                    .frame(width: 400)
                    .environment(\.colorScheme, scheme)
                try render(view, name: "about-\(languageName)-\(schemeName)")
            }
        }
```

- [ ] **Step 7: Убрать мёртвую строку из словаря**

В `Sources/BufferJournal/Localization.swift` удалить `var aboutFeedback`.

- [ ] **Step 8: Прогнать все тесты**

Run: `swift test`
Expected: PASS, 193 теста.

- [ ] **Step 9: Собрать и посмотреть**

Run: `Scripts/build_app.sh && open .build/Stash.app`

Проверить: «О приложении» открывает окно 400 pt под значком; вордмарк читается; внизу одна ссылка; кнопки «Обратная связь» нет.

- [ ] **Step 10: Коммит**

```bash
git add -A
git commit -m "$(cat <<'EOF'
Give the About screen a window of its own

The footer is one link now: the screen has no main action, and the button
and the link led to the same repository.
EOF
)"
```

---

### Task 5: Окно обучения

Тур переезжает в своё окно по центру экрана и после себя журнал не открывает.

**Files:**
- Modify: `Sources/BufferJournal/Onboarding/OnboardingController.swift:95-108`
- Modify: `Sources/BufferJournal/AppDelegate.swift`
- Modify: `Sources/BufferJournal/JournalView.swift`, `Sources/BufferJournal/JournalPanelController.swift`
- Test: `Tests/BufferJournalTests/OnboardingControllerTests.swift`, `Tests/BufferJournalTests/SnapshotTests.swift`

**Interfaces:**
- Consumes: `AccessoryWindow`, `OnboardingController.isPresented`, `.isAccessOnly`.
- Produces: `AppDelegate.tourWindow: AccessoryWindow<OnboardingView>`. `OnboardingController.close()` больше не зовёт `presentAccessOnly()`.

- [ ] **Step 1: Переписать тест передачи эстафеты**

В `Tests/BufferJournalTests/OnboardingControllerTests.swift` заменить тест `theTourHandsOverToTheAccessScreenWhenThereIsNoAccess` на:

```swift
    /// Тур закрывается в никуда: журнал после него не открывается, и экран доступа
    /// тур больше не зовёт — его поднимает панель, когда её просят показаться.
    @Test func theTourClosesIntoNothingWithoutAccess() {
        let (controller, _) = make(granted: false)
        controller.present(replay: false)
        controller.close()

        #expect(!controller.isPresented)
        #expect(!controller.isAccessOnly)
    }
```

- [ ] **Step 2: Прогнать — тест падает**

Run: `swift test --filter OnboardingControllerTests`
Expected: FAIL — `isPresented` остаётся true, потому что `close()` зовёт `presentAccessOnly()`.

- [ ] **Step 3: Убрать передачу эстафеты**

В `Sources/BufferJournal/Onboarding/OnboardingController.swift` заменить `close()` на:

```swift
    func close() {
        guard isPresented else { return }
        // A replay from the menu and the access screen record nothing.
        if !isReplay, !isAccessOnly {
            defaults.set(Self.currentVersion, forKey: Self.seenVersionKey)
        }
        // The tour closes into nothing: the journal is not what was asked for. Without access
        // the panel puts up the access screen itself, the next time it is asked to show.
        isPresented = false
        isAccessOnly = false
    }
```

- [ ] **Step 4: Прогнать — тест проходит**

Run: `swift test --filter OnboardingControllerTests`
Expected: PASS.

- [ ] **Step 5: Завести окно тура**

`@ObservedObject var onboarding: OnboardingController` в `JournalView` **остаётся**: экран доступа никуда с панели не уходит и рисуется тем же `OnboardingView`. Сужается только условие — панель показывает его и ничего больше:

```swift
            // The access screen, and only it: the tour has a window of its own now.
            if onboarding.isPresented, onboarding.isAccessOnly {
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

В `Sources/BufferJournal/OnboardingView.swift` `WindowDragHandle` в строке с полосками **остаётся**: это единственное из трёх окон, не привязанное к значку, и подвинуть его может быть нужно.

В `Sources/BufferJournal/JournalPanelController.swift` удалить `showOnboarding(replay:)` и ветку про тур в `positionIfNeeded` (`if onboarding.isPresented { center(panel); return }`). Подписку `onboardingObserver` оставить: она всё ещё сообщает про экран доступа. То, что `armIfReady()` после тура зовётся дважды — из неё и из `tourClosed()` — безвредно: он сам сторожится флагом `isArmed`.

В `Sources/BufferJournal/AppDelegate.swift` добавить:

```swift
    private var tourWindow: AccessoryWindow<OnboardingView>!
    private var tourObserver: AnyCancellable?
```

```swift
        tourWindow = AccessoryWindow(
            placement: .center,
            sizing: .fixed(NSSize(width: 640, height: 440)),
            cornerRadius: 24,
            // A click past the tour is usually the trip to System Settings.
            closesOnOutsideClick: { false },
            rootView: OnboardingView(
                controller: onboarding,
                access: access,
                l10n: settings.l10n,
                onOpenSettings: { [weak self] in self?.onboarding.requestAccess() },
                onClosePanel: { [weak self] in self?.tourWindow.close() }
            )
        )

        // The tour's own cross and its last slide both go through the controller, so the window
        // follows the controller rather than the other way round.
        tourObserver = onboarding.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in self?.tourStateChanged() }
        }
```

```swift
    /// The tour is on screen while the controller says so and it is not the access screen —
    /// that one belongs to the journal panel, which stands in for the journal without access.
    private func tourStateChanged() {
        let wanted = onboarding.isPresented && !onboarding.isAccessOnly
        if wanted, !tourWindow.isVisible {
            tourWindow.show()
        } else if !wanted, tourWindow.isVisible {
            tourWindow.close()
            tourClosed()
        }
    }

    /// The journal is not opened after the tour. Without Accessibility access there is nothing
    /// to open it for anyway: the panel puts up the access screen instead, and that screen is
    /// what the first launch has to end on, or nobody ever grants access.
    private func tourClosed() {
        if !access.isGranted {
            panelController.show()
        }
        updates.armIfReady()
    }
```

и заменить `openTutorial()`:

```swift
    @objc private func openTutorial() {
        updateWindow.close()
        aboutWindow.close()
        onboarding.present(replay: true)
    }
```

Запуск в `applicationDidFinishLaunching` заменить на:

```swift
        if onboarding.shouldShowOnLaunch {
            onboarding.present(replay: false)
        } else if !access.isGranted {
            panelController.show()
        }
```

- [ ] **Step 6: Починить снимок тура**

После Task 3 и Task 4 `Self.sizes` осталась только у тура и экрана доступа, а у них теперь один размер — окно фиксированное. В `Tests/BufferJournalTests/SnapshotTests.swift` заменить:

```swift
    /// The panel at its smallest, its default and a large size.
    private static let sizes = [
        CGSize(width: 560, height: 360),
        CGSize(width: 640, height: 440),
        CGSize(width: 900, height: 600),
    ]
```

на:

```swift
    /// The tour's window is fixed at this size, and the access screen takes the panel's default.
    private static let sizes = [CGSize(width: 640, height: 440)]
```

Метод `frame(_:_:scheme:size:)` уже передаёт `onClosePanel: {}` — его трогать не нужно.

- [ ] **Step 7: Прогнать все тесты**

Run: `swift test`
Expected: PASS.

- [ ] **Step 8: Собрать и проверить первый запуск**

```bash
defaults delete local.buffer-journal OnboardingSeenVersion
Scripts/build_app.sh && open .build/Stash.app
```

Проверить: тур открывается по центру экрана в своём окне; после последнего слайда окно закрывается и журнал **не** открывается; при отсутствии Универсального доступа вместо него поднимается панель с экраном доступа.

- [ ] **Step 9: Коммит**

```bash
git add -A
git commit -m "$(cat <<'EOF'
Give the tour a window of its own, in the middle of the screen

It closes into nothing: the journal was never what was asked for. Without
Accessibility access the panel still puts up the access screen, or a first
launch would end on nothing and nobody would grant it.
EOF
)"
```

---

### Task 6: Уборка за переездом

Три экрана ушли с панели — значит, панель больше не обслуживает четыре содержимого, и `PanelContent` схлопывается в один флаг.

**Files:**
- Modify: `Sources/BufferJournal/JournalKeys.swift:42-92`
- Modify: `Sources/BufferJournal/JournalPanelController.swift`
- Delete: `Tests/BufferJournalTests/PanelContentTests.swift`
- Modify: `Tests/BufferJournalTests/JournalKeysTests.swift`
- Modify: `README.md`

**Interfaces:**
- Consumes: ничего нового.
- Produces: `JournalKeys.mode(intercepts:panelVisible:accessGranted:stashActive:menuOpen:) -> Mode`. Тип `JournalKeys.PanelContent` и функция `JournalKeys.content(...)` удалены.

- [ ] **Step 1: Переписать тесты клавиш**

Заменить `Tests/BufferJournalTests/JournalKeysTests.swift` целиком на текст ниже. Тесты `theTutorialTakesNone` и `theUpdateScreenLeavesEveryKeyToTheAppUnderneath` уходят вместе с экранами: тур и обновление больше не на панели и клавиш не касаются по построению, а не по правилу.

```swift
import Testing
@testable import BufferJournal

struct JournalKeysTests {
    @Test func theOpenJournalTakesItsOwnKeys() {
        #expect(JournalKeys.mode(intercepts: true, panelVisible: true, accessGranted: true, stashActive: false, menuOpen: false) == .journal)
    }

    @Test func theAccessScreenTakesNone() {
        // The user is on their way to System Settings, where Return and Esc are theirs.
        #expect(JournalKeys.mode(intercepts: true, panelVisible: true, accessGranted: false, stashActive: false, menuOpen: false) == .off)
    }

    @Test func letsTheKeysGoOtherwise() {
        #expect(JournalKeys.mode(intercepts: true, panelVisible: false, accessGranted: true, stashActive: false, menuOpen: false) == .off)
        #expect(JournalKeys.mode(intercepts: true, panelVisible: true, accessGranted: true, stashActive: true, menuOpen: false) == .off)
        #expect(JournalKeys.mode(intercepts: true, panelVisible: true, accessGranted: true, stashActive: false, menuOpen: true) == .off)
    }

    @Test func staysOutOfTheWayWithInterceptKeysOff() {
        #expect(JournalKeys.mode(intercepts: false, panelVisible: true, accessGranted: true, stashActive: false, menuOpen: false) == .off)
    }
}
```

```bash
git rm Tests/BufferJournalTests/PanelContentTests.swift
```

- [ ] **Step 2: Прогнать — падает сборка**

Run: `swift test --filter JournalKeysTests`
Expected: FAIL сборки — у `mode` ещё другая сигнатура.

- [ ] **Step 3: Схлопнуть PanelContent**

В `Sources/BufferJournal/JournalKeys.swift` удалить `enum PanelContent` и `static func content(...)` целиком, а `mode` заменить на:

```swift
    /// Take keys only while Intercept Keys is on, the panel is on screen, Stash is not the active
    /// app (its clip editor needs these keys) and no menu of Stash is open (menus are walked with
    /// the arrows). Without Accessibility access the panel shows the access screen instead of the
    /// journal, and that screen leaves every key to the app the user is typing in — as do the
    /// update screen, About and the tour, which have windows of their own and never take keys.
    nonisolated static func mode(
        intercepts: Bool,
        panelVisible: Bool,
        accessGranted: Bool,
        stashActive: Bool,
        menuOpen: Bool
    ) -> Mode {
        guard intercepts, panelVisible, accessGranted, !stashActive, !menuOpen else { return .off }
        return .journal
    }
```

В `Sources/BufferJournal/JournalPanelController.swift` удалить свойство `panelContent` и заменить `updateKeys()` и `updateOutsideClicks()` на:

```swift
    private func updateKeys() {
        keys.mode = JournalKeys.mode(
            intercepts: settings.interceptKeys,
            panelVisible: isPanelVisible,
            accessGranted: access.isGranted,
            stashActive: NSApp.isActive,
            menuOpen: !trackingMenus.isEmpty
        )
    }

    /// The journal closes when the user clicks elsewhere, like Win+V. A global monitor never sees
    /// clicks on Stash itself, so whatever it reports happened in another app. The access screen
    /// keeps watching nothing: a click there is usually the trip to System Settings.
    private func updateOutsideClicks() {
        let shouldWatch = isPanelVisible && access.isGranted
        ...
    }
```

> Тело `updateOutsideClicks` ниже первой строки не меняется — правится только вычисление `shouldWatch`.

- [ ] **Step 4: Прогнать все тесты**

Run: `swift test`
Expected: PASS.

- [ ] **Step 5: Поправить README**

В `README.md` три места.

Строка 12, начало абзаца про тур. Было: `A short tour opens inside the panel on the first launch and walks through the journal in five slides.` Стало:

```text
A short tour opens in a window of its own, in the middle of the screen, on the first launch and
walks through the journal in five slides. Closing it leaves nothing behind: the journal is not
what was asked for.
```

Строка 13, абзац про «About Stash». Было: `…a link to the repository and a button that opens a new issue for feedback.` Стало:

```text
`About Stash` in the menu bar menu opens a window under the menu bar icon with the app's version,
the studio's wordmark set in Booker Display — its letters change their form on their own — and a
link to the repository.
```

Строка 23, раздел Updates. Было: `The menu item opens a screen inside the panel with the release notes and a button that…` Стало:

```text
The menu item opens a window under the menu bar icon, as tall as the release notes need, with a
button that downloads the image, checks its signature, replaces the app and relaunches it; the
download runs as a line above the button.
```

- [ ] **Step 6: Прогнать всё в последний раз и собрать**

Run: `swift test`
Expected: PASS.

Run: `Scripts/build_app.sh`
Expected: сборка проходит, `.build/Stash.app` на месте.

- [ ] **Step 7: Коммит**

```bash
git add -A
git commit -m "$(cat <<'EOF'
Let the panel know only about the journal and the access screen

Three of its four contents moved into windows of their own, so what is on
the panel is now just whether Stash may paste.
EOF
)"
```

---

## Отступления от спецификации

1. **`PanelContent` не урезается, а удаляется.** Спецификация говорит, что тип теряет три случая из пяти. После переезда остаются два, и второй — ровно `access.isGranted`, так что тип превращается в переименованный булев флаг. Вместо него `JournalKeys.mode` принимает `accessGranted` напрямую; `PanelContentTests` уходит, его смысл перебрался в `JournalKeysTests`.
2. **`UpdateController.isPresented` и `AboutController.isPresented` удаляются, а `OnboardingController.isPresented` остаётся.** Видимостью окна владеет окно; но у тура есть состояние, переживающее показ — какой слайд, какой прогон, повтор это или первый раз, видели ли тур вообще, — и окно следует за этим состоянием, а не наоборот. У обновления и «О приложении» такого состояния нет.
3. **Снимки не расширяются.** Спецификация предлагала добавить снимок загрузки; по прямому указанию делаем приложение, а тесты только чиним. Существующие снимки переводятся на новые размеры.

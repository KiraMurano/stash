import AppKit
import Combine
import QuartzCore
import SwiftUI

@MainActor
final class JournalPanelController {
    private enum Constants {
        static let size = NSSize(
            width: JournalView.Layout.width + JournalView.Layout.gripMargin,
            height: JournalView.Layout.height + JournalView.Layout.gripMargin
        )
        static let savedOriginXKey = "JournalPanelOriginX"
        static let savedOriginYKey = "JournalPanelOriginY"
        static let savedWidthKey = "JournalPanelWidth"
        static let savedHeightKey = "JournalPanelHeight"
        static let minSize = NSSize(
            width: JournalView.Layout.minWidth + JournalView.Layout.gripMargin,
            height: JournalView.Layout.minHeight + JournalView.Layout.gripMargin
        )
    }

    private let store: ClipboardHistoryStore
    private let writer: ClipboardWriter
    private let settings: AppSettings
    private let access: AccessGate
    private let onboarding: OnboardingController
    private let updates: UpdateController
    private let about: AboutController
    /// Called when the panel's content settles — access granted, tutorial closed — so the updater
    /// can arm its first check.
    private let onContentSettled: () -> Void
    private let presentation = PanelPresentation()
    private let keys: JournalKeys
    private var panel: NSPanel?
    private var onboardingObserver: AnyCancellable?
    private var updatesObserver: AnyCancellable?
    private var aboutObserver: AnyCancellable?
    private var textEditSessions: [ClipboardEntry.ID: TextEditWindowSession] = [:]
    /// Whether the panel is meant to be on screen. The journal's hotkeys follow this, not
    /// `panel.isVisible`, which stays true through the close fade.
    private var isPanelVisible = false
    /// Menus of Stash being tracked right now: the menu bar menu, a right-click menu in the preview.
    private var trackingMenus: Set<ObjectIdentifier> = []
    private var observers: [NSObjectProtocol] = []
    private var outsideClickMonitor: Any?

    init(
        store: ClipboardHistoryStore,
        writer: ClipboardWriter,
        settings: AppSettings,
        hotKeys: HotKeyController,
        access: AccessGate,
        onboarding: OnboardingController,
        updates: UpdateController,
        about: AboutController,
        onContentSettled: @escaping () -> Void = {}
    ) {
        self.store = store
        self.writer = writer
        self.settings = settings
        self.access = access
        self.onboarding = onboarding
        self.updates = updates
        self.about = about
        self.onContentSettled = onContentSettled
        keys = JournalKeys(hotKeys: hotKeys)

        // Which slide is on screen decides the keys, and the access slide takes none.
        // `objectWillChange` fires before the change, so the mode is read a turn of the run loop later.
        onboardingObserver = onboarding.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in
                self?.updateKeys()
                self?.updateOutsideClicks()
                // The tutorial closing is one of the two moments the app settles down.
                self?.onContentSettled()
            }
        }

        // The update screen covers the journal, so it changes both the keys and the outside clicks.
        updatesObserver = updates.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in
                self?.updateKeys()
                self?.updateOutsideClicks()
            }
        }

        // The About screen covers the journal in the same way.
        aboutObserver = about.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in
                self?.updateKeys()
                self?.updateOutsideClicks()
            }
        }

        // The clip editor activates Stash and needs the arrows, Return and Esc for itself.
        for name in [NSApplication.didBecomeActiveNotification, NSApplication.didResignActiveNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.updateKeys()
                }
            })
        }

        // A menu walks its items with the arrows and closes on Esc, so the journal lets go of its
        // keys while any menu of Stash is open.
        for name in [NSMenu.didBeginTrackingNotification, NSMenu.didEndTrackingNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                let isBegin = notification.name == NSMenu.didBeginTrackingNotification
                guard let menu = notification.object as AnyObject? else { return }
                let id = ObjectIdentifier(menu)
                MainActor.assumeIsolated {
                    self?.menuTracking(id, began: isBegin)
                }
            })
        }

        // The user can no longer see the panel once the screen locks, sleeps or another user
        // takes over; the journal must not keep Return and Esc from the lock screen.
        for name in [NSWorkspace.screensDidSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.close()
                }
            })
        }
        for name in ["com.apple.screenIsLocked", "com.apple.screensaver.didstart"] {
            observers.append(DistributedNotificationCenter.default().addObserver(forName: Notification.Name(name), object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.close()
                }
            })
        }

        access.onChange = { [weak self] in
            self?.accessChanged()
        }
    }

    func toggle() {
        // A panel lowered behind System Settings counts as hidden: ⌥V brings it back up.
        if isPanelVisible, panel?.level == .floating {
            close()
        } else {
            show()
        }
    }

    /// Opens the tutorial on its first slide, showing the panel if it is hidden.
    func showOnboarding(replay: Bool) {
        onboarding.present(replay: replay)
        // Already on screen: move it to the middle for the stories and take the tutorial's keys.
        if isPanelVisible, let panel, panel.level == .floating {
            positionIfNeeded(panel)
            updateKeys()
            // The journal was watching for clicks past the panel; the tutorial is not.
            updateOutsideClicks()
        } else {
            show()
        }
    }

    /// The menu item: the update screen comes up on the panel, wherever the panel opens. It and
    /// the About screen never share the panel — whichever was asked for last takes it.
    func showUpdate() {
        about.close()
        updates.present()
        show()
    }

    /// The menu item: the About screen comes up on the panel, wherever the panel opens.
    func showAbout() {
        updates.close()
        about.present()
        show()
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
        panel.alphaValue = 0
        presentation.isOpen = false
        // Never key: typing stays with the app under the panel; the journal's keys come as hotkeys.
        panel.orderFrontRegardless()
        isPanelVisible = true
        access.setPolling(true)
        updateKeys()
        updateOutsideClicks()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = PanelPresentation.appearDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }

        // A turn of the run loop later, so the journal is drawn small once and then grows.
        DispatchQueue.main.async { [presentation] in
            withAnimation(.easeOut(duration: PanelPresentation.appearDuration)) {
                presentation.isOpen = true
            }
        }
    }

    func close(completion: (@MainActor @Sendable () -> Void)? = nil) {
        // Let go of the keys first, even when the panel is already off screen.
        isPanelVisible = false
        access.setPolling(false)
        updateKeys()
        updateOutsideClicks()

        guard let panel, panel.isVisible else {
            completion?()
            return
        }

        savePosition(panel)
        withAnimation(.easeIn(duration: PanelPresentation.disappearDuration)) {
            presentation.isOpen = false
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = PanelPresentation.disappearDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self, weak panel] in
            Task { @MainActor in
                // Shown again during the fade: stay on screen.
                if self?.isPanelVisible != true {
                    panel?.orderOut(nil)
                }
                panel?.alphaValue = 1
                completion?()
            }
        }
    }

    private func menuTracking(_ menu: ObjectIdentifier, began: Bool) {
        if began {
            trackingMenus.insert(menu)
        } else {
            trackingMenus.remove(menu)
        }
        updateKeys()
    }

    /// Called when Intercept Keys is switched in the menu: it takes effect at once.
    func interceptKeysChanged() {
        updateKeys()
    }

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
        JournalKeys.content(
            onboardingPresented: onboarding.isPresented,
            onboardingIsAccess: onboarding.slide.kind == .access,
            aboutPresented: about.isPresented,
            updatePresented: updates.isPresented,
            accessGranted: access.isGranted
        )
    }

    private func accessChanged() {
        if access.isGranted, isPanelVisible, let panel {
            // Granted while System Settings was in front: come back over it with the journal.
            panel.level = .floating
            panel.orderFrontRegardless()
        }
        // Nothing left to ask for: the access screen gives way to the journal it was standing in for.
        if access.isGranted, onboarding.isAccessOnly {
            onboarding.close()
        }
        access.setPolling(isPanelVisible)
        updateKeys()
        updateOutsideClicks()
        // Access granted is the other moment the app settles down.
        onContentSettled()
    }

    /// The journal closes when the user clicks elsewhere, like Win+V. A global monitor never sees
    /// clicks on Stash itself, so whatever it reports happened in another app. The access screen
    /// keeps watching nothing: a click there is usually the trip to System Settings.
    private func updateOutsideClicks() {
        // Only the journal closes on an outside click: the tutorial and the access slide stay put,
        // a click past them is usually the trip to System Settings.
        let shouldWatch = isPanelVisible && panelContent == .journal

        if shouldWatch, outsideClickMonitor == nil {
            outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.close()
                }
            }
        } else if !shouldWatch, let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
            self.outsideClickMonitor = nil
        }
    }

    /// Asks for access and lowers the panel to the normal window level so it does not cover
    /// System Settings; the panel rises again once access is granted or on the next show.
    private func openAccessSettings() {
        onboarding.requestAccess()
        panel?.level = .normal
    }

    private func makePanelIfNeeded() -> NSPanel {
        if let panel {
            return panel
        }

        let contentView = JournalView(
            store: store,
            settings: settings,
            access: access,
            onboarding: onboarding,
            updates: updates,
            about: about,
            presentation: presentation,
            keyEvents: keys.events,
            onPaste: { [weak self] entry in
                self?.paste(entry) ?? false
            },
            onCopy: { [weak self] entry in
                self?.copy(entry)
            },
            onEditText: { [weak self] entry in
                self?.openTextEditor(for: entry)
            },
            onPreviewImage: { [weak self] entry in
                self?.openImagePreview(for: entry)
            },
            onOpenAccessSettings: { [weak self] in
                self?.openAccessSettings()
            },
            onClose: { [weak self] in
                self?.close()
            }
        )

        let hostingView = FirstMouseHostingView(rootView: contentView)
        hostingView.wantsLayer = true
        // The view clips itself to the rounded panel; the transparent margin must stay unclipped for the grip.
        hostingView.layer?.masksToBounds = false
        hostingView.layer?.borderColor = nil
        hostingView.layer?.borderWidth = 0

        let panel = JournalPanel(
            contentRect: NSRect(origin: .zero, size: savedSize ?? Constants.size),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView, .resizable],
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
        panel.minSize = Constants.minSize
        // Stash stays inactive while the panel is open; without this its tooltips never show.
        panel.allowsToolTipsWhenApplicationIsInactive = true
        // Hide Others in another app would hide the panel behind the journal's back and leave
        // its keys taken; the panel stays until the user closes it.
        panel.canHide = false

        self.panel = panel
        return panel
    }

    /// Pastes the clip into the app under the panel. Without Accessibility access nothing is
    /// pasted, the panel turns to the access screen and this returns false.
    func paste(_ entry: ClipboardEntry) -> Bool {
        guard access.refresh() else { return false }
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

    private func openTextEditor(for entry: ClipboardEntry) {
        guard case let .text(text) = entry.payload else { return }

        if let session = textEditSessions[entry.id] {
            NSApp.activate(ignoringOtherApps: true)
            session.window.makeKeyAndOrderFront(nil)
            return
        }

        let view = ClipboardTextEditorView(
            title: entry.title(settings.l10n),
            initialText: text,
            settings: settings,
            onCancel: { [weak self] in
                self?.closeTextEditor(for: entry.id)
            },
            onSave: { [weak self] editedText in
                guard let self else { return }
                if store.updateText(for: entry, to: editedText) {
                    closeTextEditor(for: entry.id)
                }
            }
        )

        let hostingView = NSHostingView(rootView: view)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 360),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = settings.l10n("Edit Clip", "Редактирование")
        window.contentView = hostingView
        window.minSize = NSSize(width: 420, height: 260)
        window.isReleasedWhenClosed = false
        window.center()

        let delegate = TextEditWindowDelegate { [weak self] in
            self?.textEditSessions[entry.id] = nil
        }
        window.delegate = delegate
        textEditSessions[entry.id] = TextEditWindowSession(window: window, delegate: delegate)

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    /// Opens the stored image in macOS Preview; falls back to the default app for PNG.
    private func openImagePreview(for entry: ClipboardEntry) {
        guard let url = store.imageURL(for: entry) else { return }

        let workspace = NSWorkspace.shared
        guard let previewURL = workspace.urlForApplication(withBundleIdentifier: "com.apple.Preview") else {
            workspace.open(url)
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        workspace.open([url], withApplicationAt: previewURL, configuration: configuration)
    }

    private func closeTextEditor(for id: ClipboardEntry.ID) {
        guard let session = textEditSessions[id] else { return }
        session.window.close()
        textEditSessions[id] = nil
    }

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
            let screen = NSScreen.screens.first { $0.frame.intersects(anchor) } ?? NSScreen.main
            if
                let visibleFrame = screen?.visibleFrame,
                let origin = PanelPlacement.origin(
                    anchor: anchor,
                    panelSize: panel.frame.size,
                    visibleFrame: visibleFrame,
                    bottomInset: JournalView.Layout.gripMargin
                )
            {
                panel.setFrameOrigin(origin)
                return
            }
        }

        if let savedOrigin = savedOrigin {
            panel.setFrameOrigin(validOrigin(savedOrigin, for: panel))
            return
        }

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

    private var savedOrigin: NSPoint? {
        let defaults = UserDefaults.standard
        guard
            defaults.object(forKey: Constants.savedOriginXKey) != nil,
            defaults.object(forKey: Constants.savedOriginYKey) != nil
        else {
            return nil
        }

        return NSPoint(
            x: defaults.double(forKey: Constants.savedOriginXKey),
            y: defaults.double(forKey: Constants.savedOriginYKey)
        )
    }

    private func savePosition(_ panel: NSPanel) {
        UserDefaults.standard.set(panel.frame.origin.x, forKey: Constants.savedOriginXKey)
        UserDefaults.standard.set(panel.frame.origin.y, forKey: Constants.savedOriginYKey)
        UserDefaults.standard.set(panel.frame.width, forKey: Constants.savedWidthKey)
        UserDefaults.standard.set(panel.frame.height, forKey: Constants.savedHeightKey)
    }

    private var savedSize: NSSize? {
        let defaults = UserDefaults.standard
        guard
            defaults.object(forKey: Constants.savedWidthKey) != nil,
            defaults.object(forKey: Constants.savedHeightKey) != nil
        else {
            return nil
        }

        let width = defaults.double(forKey: Constants.savedWidthKey)
        let height = defaults.double(forKey: Constants.savedHeightKey)

        // Sizes saved by the old single-column panel are too narrow for the split layout.
        if width < Constants.minSize.width {
            return Constants.size
        }

        return NSSize(
            width: max(width, Constants.minSize.width),
            height: max(height, Constants.minSize.height)
        )
    }

    private func validOrigin(_ origin: NSPoint, for panel: NSPanel) -> NSPoint {
        guard let screen = NSScreen.screens.first(where: { $0.visibleFrame.intersects(NSRect(origin: origin, size: panel.frame.size)) }) ?? NSScreen.main else {
            return origin
        }

        let visibleFrame = screen.visibleFrame
        let x = min(max(origin.x, visibleFrame.minX + 12), visibleFrame.maxX - panel.frame.width - 12)
        let y = min(max(origin.y, visibleFrame.minY + 12), visibleFrame.maxY - panel.frame.height - 12)
        return NSPoint(x: x, y: y)
    }
}

/// Drives the panel's opening and closing: the window fades, and the journal inside grows into
/// place and shrinks back, so neither end of the animation snaps.
@MainActor
final class PanelPresentation: ObservableObject {
    @Published var isOpen = false

    static let appearDuration = 0.16
    static let disappearDuration = 0.13
    /// The size the panel grows from and shrinks back to.
    static let closedScale: CGFloat = 0.96
}

/// Never key: the keyboard stays with the app the user is typing in, even after a click.
private final class JournalPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}

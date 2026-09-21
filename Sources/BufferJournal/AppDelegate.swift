import AppKit
import Carbon
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var store: ClipboardHistoryStore!
    private var monitor: ClipboardMonitor!
    private var writer: ClipboardWriter!
    private var settings: AppSettings!
    private var access: AccessGate!
    private var onboarding: OnboardingController!
    private var updates: UpdateController!
    private var about: AboutController!
    private var badge: StatusItemBadge!
    private var updateWindow: AccessoryWindow<UpdateView>!
    private var aboutWindow: AccessoryWindow<AboutView>!
    private var tourWindow: AccessoryWindow<OnboardingView>!
    private var tourObserver: AnyCancellable?
    private var updatesObserver: AnyCancellable?
    private var panelController: JournalPanelController!
    private var hotKeyController: HotKeyController!
    private var statusItem: NSStatusItem!
    private var openAtCaretItem: NSMenuItem!
    private var interceptKeysItem: NSMenuItem!
    private var closeAfterSelectionItem: NSMenuItem!
    private var updateItem: NSMenuItem!
    private var updateAutomaticallyItem: NSMenuItem!
    private var themeItems: [ThemeMode: NSMenuItem] = [:]
    private var languageItems: [AppLanguage: NSMenuItem] = [:]

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        store = ClipboardHistoryStore()
        monitor = ClipboardMonitor(store: store)
        writer = ClipboardWriter(store: store, monitor: monitor)
        settings = AppSettings()
        access = AccessGate()
        onboarding = OnboardingController(defaults: .standard, access: access)
        hotKeyController = HotKeyController()
        hotKeyController.install()
        updates = UpdateController(
            environment: UpdateEnvironment.current(),
            checker: GitHubUpdateChecker(),
            downloader: FileUpdateDownloader(),
            isReady: { [weak self] in
                guard let self else { return false }
                // The first check waits for the app to settle: the tour walked through, access
                // granted, the journal on the panel instead of a screen that asks for something.
                return !self.onboarding.shouldShowOnLaunch && self.access.isGranted && !self.onboarding.isPresented
            }
        )
        about = AboutController()
        panelController = JournalPanelController(
            store: store,
            writer: writer,
            settings: settings,
            hotKeys: hotKeyController,
            access: access,
            onboarding: onboarding,
            onContentSettled: { [weak self] in self?.updates.armIfReady() }
        )
        hotKeyController.register(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(optionKey)) { [weak self] in
            self?.panelController.toggle()
        }

        configureStatusItem()
        updateWindow = AccessoryWindow(
            placement: .statusItem { [weak self] in self?.statusItemFrame() },
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
        aboutWindow = AccessoryWindow(
            placement: .statusItem { [weak self] in self?.statusItemFrame() },
            sizing: .fitsContent(width: 400),
            cornerRadius: 20,
            closesOnOutsideClick: { true },
            rootView: AboutView(
                controller: about,
                l10n: settings.l10n,
                onClose: { [weak self] in self?.aboutWindow.close() }
            )
        )
        tourWindow = AccessoryWindow(
            placement: .center,
            sizing: .fixed(NSSize(width: 640, height: 440)),
            cornerRadius: JournalView.Layout.cornerRadius,
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

        // The tour's cross, its last slide and the menu item all go through the controller, so
        // the window follows the controller rather than the other way round.
        tourObserver = onboarding.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in self?.tourStateChanged() }
        }

        monitor.start()

        updatesObserver = updates.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in
                self?.updateStateChanged()
            }
        }

        // A swap that went wrong after the app had quit leaves a line behind; it is shown once.
        if let failure = UpdateFailureMarker.take() {
            NSLog("Stash update failed: \(failure)")
        }

        updates.armIfReady()

        // The tour runs once, on the first launch after the update, and its last slide asks for
        // access. Later on, pasting still needs that access, and without it the panel opens right
        // away on the access slide alone.
        if onboarding.shouldShowOnLaunch {
            onboarding.present(replay: false)
        } else if !access.isGranted {
            panelController.show()
        }
    }

    /// The tour is on screen while the controller says so and it is not the access screen — that
    /// one belongs to the journal panel, which stands in for the journal without access.
    private func tourStateChanged() {
        let wanted = onboarding.isPresented && !onboarding.isAccessOnly
        if wanted, !tourWindow.isVisible {
            tourWindow.show()
        } else if !wanted, tourWindow.isVisible {
            tourWindow.close()
            tourClosed()
        }
    }

    /// The journal is not opened after the tour: it was never what was asked for. Without
    /// Accessibility access there is nothing to open it for anyway, and the panel puts up the
    /// access screen instead — a first launch has to end on that screen, or nobody grants access.
    private func tourClosed() {
        if !access.isGranted {
            panelController.show()
        }
        updates.armIfReady()
    }

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let icon = Bundle.main.image(forResource: "StatusIcon")
            ?? NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Stash")
        icon?.isTemplate = true
        icon?.accessibilityDescription = "Stash"
        statusItem.button?.image = icon
        if let button = statusItem.button {
            badge = StatusItemBadge(button: button)
        }
        rebuildMenu()
    }

    /// The status item button in screen coordinates: where the windows that belong to it hang from.
    private func statusItemFrame() -> NSRect? {
        guard let button = statusItem.button, let window = button.window else { return nil }
        return window.convertToScreen(button.convert(button.bounds, to: nil))
    }

    private func rebuildMenu() {
        let l10n = settings.l10n
        let titles = StatusMenuTitles(l10n: l10n)
        let menu = NSMenu()
        // ⌥V is a global hotkey, not a menu shortcut; a status item's menu registers its key
        // equivalents only while it is open, so this line only tells the user what to press.
        let openItem = menuItem(titles.openStash, action: #selector(openJournal), keyEquivalent: "v")
        openItem.keyEquivalentModifierMask = .option
        menu.addItem(openItem)
        menu.addItem(NSMenuItem.separator())

        closeAfterSelectionItem = menuItem(titles.closeAfterSelection, action: #selector(toggleCloseAfterSelection))
        menu.addItem(closeAfterSelectionItem)

        interceptKeysItem = menuItem(titles.interceptKeys, action: #selector(toggleInterceptKeys))
        menu.addItem(interceptKeysItem)

        openAtCaretItem = menuItem(titles.openAtCaret, action: #selector(toggleOpenAtCaret))
        menu.addItem(openAtCaretItem)

        // Hidden in a build made from source: there is nothing to update there.
        if updates.canSelfUpdate {
            updateAutomaticallyItem = menuItem(titles.updateAutomatically, action: #selector(toggleAutomaticUpdates))
            menu.addItem(updateAutomaticallyItem)
        }

        let themeItem = NSMenuItem(title: titles.theme, action: nil, keyEquivalent: "")
        let themeMenu = NSMenu()
        themeItems = [:]
        for themeMode in ThemeMode.allCases {
            let item = menuItem(l10n.themeName(themeMode), action: #selector(selectTheme))
            item.representedObject = themeMode.rawValue
            if themeMode == .stashAuto {
                themeMenu.addItem(NSMenuItem.separator())
            }
            themeMenu.addItem(item)
            themeItems[themeMode] = item
        }
        themeItem.submenu = themeMenu
        menu.addItem(themeItem)

        let languageItem = NSMenuItem(title: titles.language, action: nil, keyEquivalent: "")
        let languageMenu = NSMenu()
        languageItems = [:]
        for language in AppLanguage.allCases {
            let item = menuItem(l10n.languageName(language), action: #selector(selectLanguage))
            item.representedObject = language.rawValue
            languageMenu.addItem(item)
            languageItems[language] = item
            if language == .system {
                languageMenu.addItem(NSMenuItem.separator())
            }
        }
        languageItem.submenu = languageMenu
        menu.addItem(languageItem)

        menu.addItem(NSMenuItem.separator())
        if updates.canSelfUpdate {
            updateItem = menuItem(titles.checkForUpdates, action: #selector(openUpdates))
            menu.addItem(updateItem)
        }

        // Above "Clear History", which asks nothing before it clears: a miss costs the history.
        menu.addItem(menuItem(titles.tutorial, action: #selector(openTutorial)))
        // Always there, in a source build too: such a build has an author no less.
        menu.addItem(menuItem(titles.about, action: #selector(openAbout)))
        menu.addItem(menuItem(titles.clearHistory, action: #selector(clearHistory)))
        menu.addItem(menuItem(titles.quit, action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu
        updateSettingsMenuState()
    }

    private func menuItem(_ title: String, action: Selector, keyEquivalent: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        return item
    }

    @objc private func openJournal() {
        panelController.show()
    }

    @objc private func openTutorial() {
        updateWindow.close()
        aboutWindow.close()
        onboarding.present(replay: true)
    }

    @objc private func openAbout() {
        updateWindow.close()
        aboutWindow.show()
    }

    /// The screen comes up at once, before the answer: a press has to do something visible, and
    /// all three answers — a new version, nothing new, a check that failed — are its faces.
    /// Nothing pops up on its own; the panel only ever comes up because the person asked for it.
    @objc private func openUpdates() {
        aboutWindow.close()
        updates.markSeen()
        updateWindow.show()
        guard updates.release == nil else { return }
        Task { await updates.check(manual: true) }
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

    @objc private func clearHistory() {
        store.clear()
    }

    @objc private func toggleCloseAfterSelection() {
        settings.closeAfterSelection.toggle()
        updateSettingsMenuState()
    }

    @objc private func toggleOpenAtCaret() {
        settings.openAtCaret.toggle()
        updateSettingsMenuState()
    }

    @objc private func toggleInterceptKeys() {
        settings.interceptKeys.toggle()
        updateSettingsMenuState()
        panelController.interceptKeysChanged()
    }

    @objc private func selectTheme(_ sender: NSMenuItem) {
        guard
            let rawValue = sender.representedObject as? String,
            let themeMode = ThemeMode(rawValue: rawValue)
        else {
            return
        }

        settings.themeMode = themeMode
        updateSettingsMenuState()
    }

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        guard
            let rawValue = sender.representedObject as? String,
            let language = AppLanguage(rawValue: rawValue)
        else {
            return
        }

        settings.language = language
        rebuildMenu()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func updateSettingsMenuState() {
        closeAfterSelectionItem?.state = settings.closeAfterSelection ? .on : .off
        interceptKeysItem?.state = settings.interceptKeys ? .on : .off
        openAtCaretItem?.state = settings.openAtCaret ? .on : .off
        updateAutomaticallyItem?.state = updates.isAutomatic ? .on : .off
        for (themeMode, item) in themeItems {
            item.state = settings.themeMode == themeMode ? .on : .off
        }
        for (language, item) in languageItems {
            item.state = settings.language == language ? .on : .off
        }
    }
}

@main
enum BufferJournalMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

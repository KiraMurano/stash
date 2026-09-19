import AppKit
import Carbon
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var store: ClipboardHistoryStore!
    private var monitor: ClipboardMonitor!
    private var writer: ClipboardWriter!
    private var settings: AppSettings!
    private var access: AccessGate!
    private var onboarding: OnboardingController!
    private var panelController: JournalPanelController!
    private var hotKeyController: HotKeyController!
    private var statusItem: NSStatusItem!
    private var openAtCaretItem: NSMenuItem!
    private var interceptKeysItem: NSMenuItem!
    private var closeAfterSelectionItem: NSMenuItem!
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
        panelController = JournalPanelController(
            store: store,
            writer: writer,
            settings: settings,
            hotKeys: hotKeyController,
            access: access,
            onboarding: onboarding
        )
        hotKeyController.register(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(optionKey)) { [weak self] in
            self?.panelController.toggle()
        }

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

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let icon = Bundle.main.image(forResource: "StatusIcon")
            ?? NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Stash")
        icon?.isTemplate = true
        icon?.accessibilityDescription = "Stash"
        statusItem.button?.image = icon
        rebuildMenu()
    }

    private func rebuildMenu() {
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
        panelController.showOnboarding(replay: true)
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

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
    private var panelController: JournalPanelController!
    private var hotKeyController: HotKeyController!
    private var statusItem: NSStatusItem!
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
        hotKeyController = HotKeyController()
        hotKeyController.install()
        panelController = JournalPanelController(
            store: store,
            writer: writer,
            settings: settings,
            hotKeys: hotKeyController,
            access: access
        )
        hotKeyController.register(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(optionKey)) { [weak self] in
            self?.panelController.toggle()
        }

        configureStatusItem()
        monitor.start()

        // Pasting needs Accessibility access; without it the panel opens right away on the access screen.
        if !access.isGranted {
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
        let menu = NSMenu()
        menu.addItem(menuItem(l10n("Open Stash", "Открыть Stash"), action: #selector(openJournal)))
        menu.addItem(NSMenuItem.separator())

        closeAfterSelectionItem = menuItem(l10n("Close After Selection", "Закрывать после выбора"), action: #selector(toggleCloseAfterSelection))
        menu.addItem(closeAfterSelectionItem)

        let themeItem = NSMenuItem(title: l10n("Theme", "Тема"), action: nil, keyEquivalent: "")
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

        let languageItem = NSMenuItem(title: l10n("Language", "Язык"), action: nil, keyEquivalent: "")
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
        menu.addItem(menuItem(l10n("Clear History", "Очистить историю"), action: #selector(clearHistory)))
        menu.addItem(menuItem(l10n("Quit", "Выйти"), action: #selector(quit), keyEquivalent: "q"))
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

    @objc private func clearHistory() {
        store.clear()
    }

    @objc private func toggleCloseAfterSelection() {
        settings.closeAfterSelection.toggle()
        updateSettingsMenuState()
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

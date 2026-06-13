import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var store: ClipboardHistoryStore!
    private var monitor: ClipboardMonitor!
    private var writer: ClipboardWriter!
    private var settings: AppSettings!
    private var panelController: JournalPanelController!
    private var hotKeyController: HotKeyController!
    private var statusItem: NSStatusItem!
    private var pasteOnSelectionItem: NSMenuItem!
    private var closeAfterSelectionItem: NSMenuItem!
    private var themeItems: [ThemeMode: NSMenuItem] = [:]

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        store = ClipboardHistoryStore()
        monitor = ClipboardMonitor(store: store)
        writer = ClipboardWriter(store: store, monitor: monitor)
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

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Buffer Journal")

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open Journal", action: #selector(openJournal), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        pasteOnSelectionItem = NSMenuItem(title: "Paste on Selection", action: #selector(togglePasteOnSelection), keyEquivalent: "")
        pasteOnSelectionItem.target = self
        menu.addItem(pasteOnSelectionItem)

        closeAfterSelectionItem = NSMenuItem(title: "Close After Selection", action: #selector(toggleCloseAfterSelection), keyEquivalent: "")
        closeAfterSelectionItem.target = self
        menu.addItem(closeAfterSelectionItem)

        let themeItem = NSMenuItem(title: "Theme", action: nil, keyEquivalent: "")
        let themeMenu = NSMenu()
        for themeMode in ThemeMode.allCases {
            let item = NSMenuItem(title: themeMode.title, action: #selector(selectTheme), keyEquivalent: "")
            item.target = self
            item.representedObject = themeMode.rawValue
            themeMenu.addItem(item)
            themeItems[themeMode] = item
        }
        themeItem.submenu = themeMenu
        menu.addItem(themeItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Clear History", action: #selector(clearHistory), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu
        updateSettingsMenuState()
    }

    @objc private func openJournal() {
        panelController.show()
    }

    @objc private func clearHistory() {
        store.clear()
    }

    @objc private func togglePasteOnSelection() {
        settings.pasteOnSelection.toggle()
        updateSettingsMenuState()
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

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func updateSettingsMenuState() {
        pasteOnSelectionItem?.state = settings.pasteOnSelection ? .on : .off
        closeAfterSelectionItem?.state = settings.closeAfterSelection ? .on : .off
        for (themeMode, item) in themeItems {
            item.state = settings.themeMode == themeMode ? .on : .off
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

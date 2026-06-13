import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var store: ClipboardHistoryStore!
    private var monitor: ClipboardMonitor!
    private var writer: ClipboardWriter!
    private var panelController: JournalPanelController!
    private var hotKeyController: HotKeyController!
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        store = ClipboardHistoryStore()
        monitor = ClipboardMonitor(store: store)
        writer = ClipboardWriter(store: store, monitor: monitor)
        panelController = JournalPanelController(store: store, writer: writer)
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
        menu.addItem(NSMenuItem(title: "Clear History", action: #selector(clearHistory), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc private func openJournal() {
        panelController.show()
    }

    @objc private func clearHistory() {
        store.clear()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
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

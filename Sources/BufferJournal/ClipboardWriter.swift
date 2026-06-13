import AppKit
import ApplicationServices
import Foundation

@MainActor
final class ClipboardWriter {
    private let store: ClipboardHistoryStore
    private let monitor: ClipboardMonitor

    init(store: ClipboardHistoryStore, monitor: ClipboardMonitor) {
        self.store = store
        self.monitor = monitor
    }

    func paste(_ entry: ClipboardEntry, into targetApplication: NSRunningApplication?) {
        writeToPasteboard(entry)
        monitor.markPasteboardWasChangedByApp()

        if !isAccessibilityTrusted {
            requestAccessibilityIfNeeded()
        }

        targetApplication?.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) {
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

    private func writeToPasteboard(_ entry: ClipboardEntry) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch entry.payload {
        case let .text(text):
            pasteboard.setString(text, forType: .string)
        case .image:
            guard let image = store.image(for: entry) else { return }
            pasteboard.writeObjects([image])
        }
    }

    private static func sendCommandV() {
        let source = CGEventSource(stateID: .hidSystemState)
        let commandKey = CGKeyCode(55)
        let vKey = CGKeyCode(9)
        let tap: CGEventTapLocation = .cgAnnotatedSessionEventTap

        let commandDown = CGEvent(keyboardEventSource: source, virtualKey: commandKey, keyDown: true)
        commandDown?.flags = .maskCommand
        commandDown?.post(tap: tap)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.008) {
            let vDown = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
            vDown?.flags = .maskCommand
            vDown?.post(tap: tap)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.024) {
            let vUp = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
            vUp?.flags = .maskCommand
            vUp?.post(tap: tap)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.035) {
            let commandUp = CGEvent(keyboardEventSource: source, virtualKey: commandKey, keyDown: false)
            commandUp?.flags = []
            commandUp?.post(tap: tap)
        }
    }
}

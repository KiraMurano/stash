import AppKit
import Foundation

@MainActor
final class ClipboardMonitor {
    private let pasteboard = NSPasteboard.general
    private let store: ClipboardHistoryStore
    private var timer: Timer?
    private var lastChangeCount: Int

    init(store: ClipboardHistoryStore) {
        self.store = store
        lastChangeCount = pasteboard.changeCount
    }

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.captureIfNeeded()
            }
        }
    }

    func markPasteboardWasChangedByApp() {
        lastChangeCount = pasteboard.changeCount
    }

    private func captureIfNeeded() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        if let text = pasteboard.string(forType: .string) {
            store.addText(text)
            return
        }

        if let image = NSImage(pasteboard: pasteboard) {
            store.addImage(image)
        }
    }
}

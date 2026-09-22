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
            guard let self = self else { return }
            Task { @MainActor in
                self.captureIfNeeded()
            }
        }
    }

    func markPasteboardWasChangedByApp() {
        lastChangeCount = pasteboard.changeCount
    }

    private func captureIfNeeded() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        if let fileURLs = readFileURLs() {
            for url in fileURLs {
                store.addFile(from: url)
            }
            return
        }

        if let text = pasteboard.string(forType: .string) {
            store.addText(text)
            return
        }

        if let image = NSImage(pasteboard: pasteboard) {
            store.addImage(image)
        }
    }

    private func readFileURLs() -> [URL]? {
        if
            let urls = pasteboard.readObjects(
                forClasses: [NSURL.self],
                options: [
                    .urlReadingFileURLsOnly: true
                ]
            ) as? [URL],
            !urls.isEmpty
        {
            let fileURLs = urls
                .map { $0.isFileURL ? $0 : URL(fileURLWithPath: $0.path) }
                .filter { FileManager.default.fileExists(atPath: $0.path) }

            if !fileURLs.isEmpty {
                return fileURLs
            }
        }

        if
            let filenames = pasteboard.propertyList(
                forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")
            ) as? [String]
        {
            let fileURLs = filenames
                .map { URL(fileURLWithPath: $0) }
                .filter { FileManager.default.fileExists(atPath: $0.path) }

            if !fileURLs.isEmpty {
                return fileURLs
            }
        }

        return nil
    }
}

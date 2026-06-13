import AppKit
import Foundation

@MainActor
final class ClipboardHistoryStore: ObservableObject {
    @Published private(set) var entries: [ClipboardEntry] = []
    @Published private(set) var currentClipboardFingerprint: String?

    private let maxEntries = 20
    private let maxEntryAge: TimeInterval = 24 * 60 * 60
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let rootURL: URL
    private let imagesURL: URL
    private let historyURL: URL
    private var imageCache: [UUID: NSImage] = [:]

    init() {
        let supportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        rootURL = supportURL.appendingPathComponent("BufferJournal", isDirectory: true)
        imagesURL = rootURL.appendingPathComponent("Images", isDirectory: true)
        historyURL = rootURL.appendingPathComponent("history.json")

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()

        createDirectoriesIfNeeded()
        load()
    }

    func addText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        add(ClipboardEntry.text(text))
    }

    func addImage(_ image: NSImage) {
        guard let data = image.pngData else { return }
        let filename = "\(UUID().uuidString).png"
        let url = imagesURL.appendingPathComponent(filename)

        do {
            try data.write(to: url, options: .atomic)
            add(ClipboardEntry.image(filename: filename, data: data))
        } catch {
            NSLog("BufferJournal: failed to write image: \(error.localizedDescription)")
        }
    }

    func imageURL(for entry: ClipboardEntry) -> URL? {
        guard case let .image(filename) = entry.payload else { return nil }
        return imagesURL.appendingPathComponent(filename)
    }

    func image(for entry: ClipboardEntry) -> NSImage? {
        if let cachedImage = imageCache[entry.id] {
            return cachedImage
        }

        guard let url = imageURL(for: entry) else { return nil }
        let image = NSImage(contentsOf: url)
        imageCache[entry.id] = image
        return image
    }

    func clear() {
        entries.removeAll()
        currentClipboardFingerprint = nil
        imageCache.removeAll()
        try? FileManager.default.removeItem(at: imagesURL)
        createDirectoriesIfNeeded()
        save()
    }

    func remove(_ entry: ClipboardEntry) {
        entries.removeAll { $0.id == entry.id }
        if currentClipboardFingerprint == entry.fingerprint {
            currentClipboardFingerprint = nil
        }
        imageCache[entry.id] = nil
        removeImageFiles(for: [entry])
        save()
    }

    func markCurrent(_ entry: ClipboardEntry) {
        currentClipboardFingerprint = entry.fingerprint
    }

    private func add(_ entry: ClipboardEntry) {
        entries.removeAll { $0.fingerprint == entry.fingerprint }
        entries.insert(entry, at: 0)
        markCurrent(entry)

        pruneEntries()
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: historyURL) else { return }

        do {
            entries = try decoder.decode([ClipboardEntry].self, from: data)
            pruneEntries()
            save()
        } catch {
            NSLog("BufferJournal: failed to load history: \(error.localizedDescription)")
        }
    }

    private func save() {
        do {
            let data = try encoder.encode(entries)
            try data.write(to: historyURL, options: .atomic)
        } catch {
            NSLog("BufferJournal: failed to save history: \(error.localizedDescription)")
        }
    }

    private func createDirectoriesIfNeeded() {
        do {
            try FileManager.default.createDirectory(at: imagesURL, withIntermediateDirectories: true)
        } catch {
            NSLog("BufferJournal: failed to create storage: \(error.localizedDescription)")
        }
    }

    private func removeImageFiles(for entries: [ClipboardEntry]) {
        for entry in entries {
            guard let url = imageURL(for: entry) else { continue }
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func pruneEntries() {
        let cutoff = Date().addingTimeInterval(-maxEntryAge)
        let retainedEntries = Array(entries.filter { $0.createdAt >= cutoff }.prefix(maxEntries))
        let retainedIDs = Set(retainedEntries.map(\.id))
        let removedEntries = entries.filter { !retainedIDs.contains($0.id) }
        guard !removedEntries.isEmpty else { return }

        entries = retainedEntries
        if
            let currentClipboardFingerprint,
            !retainedEntries.contains(where: { $0.fingerprint == currentClipboardFingerprint })
        {
            self.currentClipboardFingerprint = nil
        }
        for entry in removedEntries {
            imageCache[entry.id] = nil
        }
        removeImageFiles(for: removedEntries)
    }
}

private extension NSImage {
    var pngData: Data? {
        guard
            let tiffData = tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffData)
        else {
            return nil
        }

        return bitmap.representation(using: .png, properties: [:])
    }
}

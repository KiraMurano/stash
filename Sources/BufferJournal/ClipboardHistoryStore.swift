import AppKit
import Foundation
import ImageIO

@MainActor
final class ClipboardHistoryStore: ObservableObject {
    @Published private(set) var entries: [ClipboardEntry] = []
    @Published private(set) var currentClipboardFingerprint: String?

    private let maxEntries = 20
    private let maxPinnedEntries = 10
    private let maxEntryAge: TimeInterval = 24 * 60 * 60
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let rootURL: URL
    private let imagesURL: URL
    private let filesURL: URL
    private let historyURL: URL
    private var imageCache: [UUID: NSImage] = [:]
    private var thumbnailCache: [UUID: NSImage] = [:]
    private var thumbnailsInFlight: Set<UUID> = []
    private var pixelSizeCache: [UUID: CGSize] = [:]
    private var fileIconCache: [UUID: NSImage] = [:]
    private var pruneTimer: Timer?

    init() {
        let supportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        rootURL = supportURL.appendingPathComponent("BufferJournal", isDirectory: true)
        imagesURL = rootURL.appendingPathComponent("Images", isDirectory: true)
        filesURL = rootURL.appendingPathComponent("Files", isDirectory: true)
        historyURL = rootURL.appendingPathComponent("history.json")

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()

        createDirectoriesIfNeeded()
        load()
        scheduleNextPrune()
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

    func addFile(from sourceURL: URL) {
        guard sourceURL.isFileURL else { return }

        let didAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: sourceURL.path) else { return }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: sourceURL.path, isDirectory: &isDirectory), !isDirectory.boolValue else {
            return
        }

        let originalName = sourceURL.lastPathComponent
        let storedFilename = Self.storedFilename(for: originalName)
        let destinationURL = filesURL.appendingPathComponent(storedFilename)

        do {
            let data = try Data(contentsOf: sourceURL)
            try data.write(to: destinationURL, options: .atomic)

            let attributes = try fileManager.attributesOfItem(atPath: sourceURL.path)
            let byteCount = (attributes[.size] as? NSNumber)?.int64Value ?? Int64(data.count)

            add(
                ClipboardEntry.file(
                    storedFilename: storedFilename,
                    originalName: originalName,
                    byteCount: byteCount,
                    data: data
                )
            )
        } catch {
            NSLog("BufferJournal: failed to write file: \(error.localizedDescription)")
        }
    }

    func imageURL(for entry: ClipboardEntry) -> URL? {
        guard case let .image(filename) = entry.payload else { return nil }
        return imagesURL.appendingPathComponent(filename)
    }

    func fileURL(for entry: ClipboardEntry) -> URL? {
        guard case let .file(storedFilename, _, _) = entry.payload else { return nil }
        return filesURL.appendingPathComponent(storedFilename)
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

    /// Row thumbnail. Returns the cached one, or nil while it is being made off the main thread;
    /// the store publishes a change when it is ready. Decoding full images on the main thread
    /// while rows scrolled in made the list jump.
    func thumbnail(for entry: ClipboardEntry) -> NSImage? {
        if let cached = thumbnailCache[entry.id] {
            return cached
        }
        requestThumbnail(for: entry)
        return nil
    }

    /// Pixel size read from the image file's header, without decoding the image.
    func pixelSize(for entry: ClipboardEntry) -> CGSize? {
        if let cached = pixelSizeCache[entry.id] {
            return cached
        }
        guard let url = imageURL(for: entry), let size = Self.pixelSize(at: url) else { return nil }
        pixelSizeCache[entry.id] = size
        return size
    }

    private func requestThumbnail(for entry: ClipboardEntry) {
        guard
            !thumbnailsInFlight.contains(entry.id),
            let url = imageURL(for: entry)
        else {
            return
        }

        let id = entry.id
        // Enough pixels on the short side for a 42 pt square at 2x after aspect-fill cropping.
        let shortSide = 96.0
        let size = pixelSize(for: entry) ?? CGSize(width: shortSide, height: shortSide)
        let aspect = max(size.width, size.height) / max(min(size.width, size.height), 1)
        let maxPixel = Int(min(shortSide * aspect, 1024))
        thumbnailsInFlight.insert(id)

        Task.detached(priority: .userInitiated) { [weak self] in
            let cgImage = Self.makeThumbnail(at: url, maxPixel: maxPixel)
            guard let store = self else { return }
            await store.thumbnailDidFinish(id: id, cgImage: cgImage)
        }
    }

    private func thumbnailDidFinish(id: UUID, cgImage: CGImage?) {
        thumbnailsInFlight.remove(id)
        guard let cgImage, entries.contains(where: { $0.id == id }) else { return }
        thumbnailCache[id] = NSImage(cgImage: cgImage, size: .zero)
        objectWillChange.send()
    }

    nonisolated private static func makeThumbnail(at url: URL, maxPixel: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    nonisolated private static func pixelSize(at url: URL) -> CGSize? {
        guard
            let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? Int,
            let height = properties[kCGImagePropertyPixelHeight] as? Int
        else {
            return nil
        }
        return CGSize(width: width, height: height)
    }

    func fileIcon(for entry: ClipboardEntry) -> NSImage? {
        if let cached = fileIconCache[entry.id] {
            return cached
        }

        guard let url = fileURL(for: entry) else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        fileIconCache[entry.id] = icon
        return icon
    }

    private func forgetCachedImages(for id: UUID) {
        imageCache[id] = nil
        thumbnailCache[id] = nil
        pixelSizeCache[id] = nil
        fileIconCache[id] = nil
    }

    func clear() {
        let removedEntries = entries.filter { !$0.isPinned }
        guard !removedEntries.isEmpty else { return }

        entries.removeAll { !$0.isPinned }
        if
            let currentClipboardFingerprint,
            !entries.contains(where: { $0.fingerprint == currentClipboardFingerprint })
        {
            self.currentClipboardFingerprint = nil
        }
        for entry in removedEntries {
            forgetCachedImages(for: entry.id)
        }
        removeStoredFiles(for: removedEntries)
        save()
        scheduleNextPrune()
    }

    func remove(_ entry: ClipboardEntry) {
        entries.removeAll { $0.id == entry.id }
        if currentClipboardFingerprint == entry.fingerprint {
            currentClipboardFingerprint = nil
        }
        forgetCachedImages(for: entry.id)
        removeStoredFiles(for: [entry])
        save()
        scheduleNextPrune()
    }

    @discardableResult
    func updateText(for entry: ClipboardEntry, to text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard let entryIndex = entries.firstIndex(where: { $0.id == entry.id }) else { return false }
        guard case .text = entries[entryIndex].payload else { return false }

        let oldFingerprint = entries[entryIndex].fingerprint
        let newFingerprint = ClipboardEntry.textFingerprint(text)

        if oldFingerprint != newFingerprint {
            let duplicateEntries = entries.filter { $0.id != entry.id && $0.fingerprint == newFingerprint }
            entries.removeAll { $0.id != entry.id && $0.fingerprint == newFingerprint }
            removeStoredFiles(for: duplicateEntries)
        }

        guard let updatedIndex = entries.firstIndex(where: { $0.id == entry.id }) else { return false }
        entries[updatedIndex].payload = .text(text)
        entries[updatedIndex].fingerprint = newFingerprint

        if currentClipboardFingerprint == oldFingerprint {
            currentClipboardFingerprint = newFingerprint
        }

        sortEntries()
        pruneEntries()
        save()
        scheduleNextPrune()
        return true
    }

    @discardableResult
    func togglePin(_ entry: ClipboardEntry) -> Bool {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return false }

        if entries[index].isPinned {
            entries[index].isPinned = false
            entries[index].pinnedOrder = nil
            normalizePinnedOrder()
            sortEntries()
            pruneEntries()
            save()
            scheduleNextPrune()
            return true
        }

        guard entries.filter(\.isPinned).count < maxPinnedEntries else {
            return false
        }

        let nextOrder = (entries.compactMap(\.pinnedOrder).max() ?? -1) + 1
        entries[index].isPinned = true
        entries[index].pinnedOrder = nextOrder
        sortEntries()
        pruneEntries()
        save()
        scheduleNextPrune()
        return true
    }

    func movePinnedEntry(sourceID: ClipboardEntry.ID, to targetID: ClipboardEntry.ID, afterTarget: Bool) {
        guard sourceID != targetID else { return }

        var pinnedEntries = entries
            .filter(\.isPinned)
            .sorted { lhs, rhs in
                let lhsOrder = lhs.pinnedOrder ?? Int.max
                let rhsOrder = rhs.pinnedOrder ?? Int.max
                if lhsOrder == rhsOrder {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhsOrder < rhsOrder
            }
        let originalPinnedIDs = pinnedEntries.map(\.id)

        guard
            let sourceIndex = pinnedEntries.firstIndex(where: { $0.id == sourceID }),
            pinnedEntries.contains(where: { $0.id == targetID })
        else {
            return
        }

        let movedEntry = pinnedEntries.remove(at: sourceIndex)
        guard var targetIndex = pinnedEntries.firstIndex(where: { $0.id == targetID }) else { return }
        if afterTarget {
            targetIndex += 1
        }
        pinnedEntries.insert(movedEntry, at: min(targetIndex, pinnedEntries.count))
        guard pinnedEntries.map(\.id) != originalPinnedIDs else { return }

        for (order, pinnedEntry) in pinnedEntries.enumerated() {
            if let index = entries.firstIndex(where: { $0.id == pinnedEntry.id }) {
                entries[index].pinnedOrder = order
            }
        }

        sortEntries()
        save()
    }

    func markCurrent(_ entry: ClipboardEntry) {
        currentClipboardFingerprint = entry.fingerprint
    }

    private func add(_ entry: ClipboardEntry) {
        if let duplicate = entries.first(where: { $0.fingerprint == entry.fingerprint && $0.isPinned }) {
            markCurrent(duplicate)
            sortEntries()
            save()
            scheduleNextPrune()
            return
        }

        entries.removeAll { $0.fingerprint == entry.fingerprint }
        entries.insert(entry, at: 0)
        markCurrent(entry)

        sortEntries()
        pruneEntries()
        save()
        scheduleNextPrune()
    }

    private func load() {
        guard let data = try? Data(contentsOf: historyURL) else { return }

        do {
            entries = try decoder.decode([ClipboardEntry].self, from: data)
            normalizePinnedOrder()
            sortEntries()
            pruneEntries()
            save()
            scheduleNextPrune()
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
            try FileManager.default.createDirectory(at: filesURL, withIntermediateDirectories: true)
        } catch {
            NSLog("BufferJournal: failed to create storage: \(error.localizedDescription)")
        }
    }

    private func removeStoredFiles(for entries: [ClipboardEntry]) {
        for entry in entries {
            if let url = imageURL(for: entry) {
                try? FileManager.default.removeItem(at: url)
            }
            if let url = fileURL(for: entry) {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    private func pruneEntries() {
        let cutoff = Date().addingTimeInterval(-maxEntryAge)
        let pinnedEntries = entries.filter(\.isPinned)
        let unpinnedCapacity = max(0, maxEntries - pinnedEntries.count)
        let retainedUnpinnedEntries = Array(
            entries
                .filter { !$0.isPinned && $0.createdAt > cutoff }
                .prefix(unpinnedCapacity)
        )
        let retainedEntries = pinnedEntries + retainedUnpinnedEntries
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
            forgetCachedImages(for: entry.id)
        }
        removeStoredFiles(for: removedEntries)
    }

    private func scheduleNextPrune() {
        pruneTimer?.invalidate()
        pruneTimer = nil

        let now = Date()
        guard let nextExpiration = entries
            .filter({ !$0.isPinned })
            .map({ $0.createdAt.addingTimeInterval(maxEntryAge) })
            .filter({ $0 > now })
            .min()
        else {
            return
        }

        pruneTimer = Timer.scheduledTimer(withTimeInterval: nextExpiration.timeIntervalSince(now), repeats: false) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.pruneEntries()
                self.save()
                self.scheduleNextPrune()
            }
        }
    }

    private func sortEntries() {
        let pinnedEntries = entries
            .filter(\.isPinned)
            .sorted { lhs, rhs in
                let lhsOrder = lhs.pinnedOrder ?? Int.max
                let rhsOrder = rhs.pinnedOrder ?? Int.max
                if lhsOrder == rhsOrder {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhsOrder < rhsOrder
            }
        let unpinnedEntries = entries.filter { !$0.isPinned }
        entries = pinnedEntries + unpinnedEntries
    }

    private func normalizePinnedOrder() {
        let pinnedIDs = entries
            .filter(\.isPinned)
            .sorted { lhs, rhs in
                let lhsOrder = lhs.pinnedOrder ?? Int.max
                let rhsOrder = rhs.pinnedOrder ?? Int.max
                if lhsOrder == rhsOrder {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhsOrder < rhsOrder
            }
            .map(\.id)

        for (order, id) in pinnedIDs.enumerated() {
            if let index = entries.firstIndex(where: { $0.id == id }) {
                entries[index].pinnedOrder = order
            }
        }
    }

    private static func storedFilename(for originalName: String) -> String {
        let sanitized = originalName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        return "\(UUID().uuidString)_\(sanitized)"
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

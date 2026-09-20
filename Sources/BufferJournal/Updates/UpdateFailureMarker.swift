import Foundation

/// A line left by the install script when the swap went wrong after the app had already quit.
/// Stash reads it on the next launch, shows it and deletes it: the message is for one showing.
enum UpdateFailureMarker {
    static var url: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("BufferJournal/update-failure.txt")
    }

    /// Reads the message and removes the file, so it is never shown twice.
    static func take() -> String? {
        let url = Self.url
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        try? FileManager.default.removeItem(at: url)

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

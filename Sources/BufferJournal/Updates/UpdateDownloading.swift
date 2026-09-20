import Foundation

/// Brings the release image down. The app uses URLSession; the tests hand in their own.
protocol UpdateDownloading: Sendable {
    /// The image on disk. `onProgress` is called with 0…1 and may be called from any thread.
    func download(_ release: Release, onProgress: @escaping @Sendable (Double) -> Void) async throws -> URL
}

struct FileUpdateDownloader: UpdateDownloading {
    /// URLSession hands the download to its delegate on a queue of its own, so the delegate only
    /// ever touches the closure it was built with.
    private final class ProgressDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
        private let onProgress: @Sendable (Double) -> Void

        init(onProgress: @escaping @Sendable (Double) -> Void) {
            self.onProgress = onProgress
        }

        func urlSession(
            _ session: URLSession,
            downloadTask: URLSessionDownloadTask,
            didWriteData bytesWritten: Int64,
            totalBytesWritten: Int64,
            totalBytesExpectedToWrite: Int64
        ) {
            guard totalBytesExpectedToWrite > 0 else { return }
            onProgress(min(1, Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)))
        }

        // Required by the protocol; the awaited call returns the file itself.
        func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {}
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func download(_ release: Release, onProgress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        var request = URLRequest(url: release.dmgURL)
        request.timeoutInterval = 60

        let temporary: URL
        let response: URLResponse
        do {
            (temporary, response) = try await session.download(for: request, delegate: ProgressDelegate(onProgress: onProgress))
        } catch {
            throw UpdateError.network
        }

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw UpdateError.network
        }

        // URLSession deletes its temporary file as soon as the call returns, so it moves now.
        // Each download gets a folder of its own: a second attempt must not land on the first.
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("StashUpdate-\(UUID().uuidString)")
        let destination = folder.appendingPathComponent("Stash-\(release.version).dmg")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try FileManager.default.moveItem(at: temporary, to: destination)
        } catch {
            throw UpdateError.network
        }

        return destination
    }
}

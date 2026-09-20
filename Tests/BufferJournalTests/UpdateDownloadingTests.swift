import Foundation
import Testing
@testable import BufferJournal

struct UpdateDownloadingTests {
    /// URLSession умеет file://, поэтому настоящий загрузчик проверяется без сети.
    /// Прогресс на файловых адресах система не сообщает, и тест его не ждёт.
    private func temporaryImage(bytes: Int) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("UpdateDownloadingTests-\(UUID().uuidString).dmg")
        try Data(repeating: 0x42, count: bytes).write(to: url)
        return url
    }

    private func release(at url: URL, size: Int64) -> Release {
        Release(version: AppVersion(major: 1, minor: 27), notes: "", dmgURL: url, size: size)
    }

    @Test func bringsTheFileDownWholeAndNamesItAfterTheVersion() async throws {
        let source = try temporaryImage(bytes: 4096)
        defer { try? FileManager.default.removeItem(at: source) }

        let downloaded = try await FileUpdateDownloader().download(release(at: source, size: 4096)) { _ in }
        defer { try? FileManager.default.removeItem(at: downloaded) }

        #expect(downloaded.lastPathComponent == "Stash-1.27.dmg")
        #expect(try Data(contentsOf: downloaded).count == 4096)
    }

    @Test func aMissingFileIsANetworkFailure() async throws {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("no-such-\(UUID().uuidString).dmg")

        await #expect(throws: UpdateError.network) {
            _ = try await FileUpdateDownloader().download(release(at: missing, size: 1)) { _ in }
        }
    }

    @Test func twoDownloadsDoNotShareAFile() async throws {
        let source = try temporaryImage(bytes: 16)
        defer { try? FileManager.default.removeItem(at: source) }

        let first = try await FileUpdateDownloader().download(release(at: source, size: 16)) { _ in }
        let second = try await FileUpdateDownloader().download(release(at: source, size: 16)) { _ in }
        defer {
            try? FileManager.default.removeItem(at: first)
            try? FileManager.default.removeItem(at: second)
        }

        #expect(first != second)
    }
}

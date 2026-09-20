import Foundation
import Testing
@testable import BufferJournal

@MainActor
struct UpdateControllerTests {
    // MARK: Заглушки

    private struct StubChecker: UpdateChecking {
        let result: Result<Release?, UpdateError>
        func latestRelease() async throws -> Release? { try result.get() }
    }

    private struct StubDownloader: UpdateDownloading {
        let result: Result<URL, UpdateError>
        func download(_ release: Release, onProgress: @escaping @Sendable (Double) -> Void) async throws -> URL {
            onProgress(0.5)
            return try result.get()
        }
    }

    private final class Recorder: @unchecked Sendable {
        var installed: URL?
        var quits = 0
    }

    private func release(_ version: String, notes: String = "- Пункт") -> Release {
        Release(
            version: AppVersion(version)!,
            notes: notes,
            dmgURL: URL(string: "https://example.invalid/Stash-\(version).dmg")!,
            size: 4_404_019
        )
    }

    private func freshDefaults() -> UserDefaults {
        let name = "UpdateControllerTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func environment(version: String? = "1.26", requirement: String? = "req", writable: Bool = true) -> UpdateEnvironment {
        UpdateEnvironment(
            currentVersion: UpdateEnvironment.releasedVersion(version),
            requirement: requirement,
            bundleURL: URL(fileURLWithPath: "/Applications/Stash.app"),
            isDestinationWritable: writable
        )
    }

    private func controller(
        environment: UpdateEnvironment? = nil,
        checker: Result<Release?, UpdateError> = .success(nil),
        downloader: Result<URL, UpdateError> = .success(URL(fileURLWithPath: "/tmp/Stash-1.27.dmg")),
        defaults: UserDefaults? = nil,
        ready: Bool = true,
        installFails: UpdateError? = nil,
        recorder: Recorder = Recorder()
    ) -> (UpdateController, Recorder) {
        let controller = UpdateController(
            environment: environment ?? self.environment(),
            checker: StubChecker(result: checker),
            downloader: StubDownloader(result: downloader),
            defaults: defaults ?? freshDefaults(),
            now: { Date() },
            isReady: { ready },
            install: { url in
                if let installFails { throw installFails }
                recorder.installed = url
            },
            quit: { recorder.quits += 1 }
        )
        return (controller, recorder)
    }

    // MARK: Проверка

    @Test func aNewerReleaseBecomesAvailable() async {
        let (controller, _) = controller(checker: .success(release("1.27")))
        await controller.check(manual: true)
        #expect(controller.state == .available)
        #expect(controller.release == release("1.27"))
    }

    @Test func theSameVersionIsUpToDate() async {
        let (controller, _) = controller(checker: .success(release("1.26")))
        await controller.check(manual: true)
        #expect(controller.state == .upToDate)
    }

    @Test func nothingInTheFeedIsUpToDate() async {
        let (controller, _) = controller(checker: .success(nil))
        await controller.check(manual: true)
        #expect(controller.state == .upToDate)
    }

    @Test func aManualCheckReportsAFailedRequest() async {
        let (controller, _) = controller(checker: .failure(.network))
        await controller.check(manual: true)
        #expect(controller.state == .failed(.network))
    }

    @Test func anAutomaticCheckKeepsQuietAboutAFailedRequest() async {
        let (controller, _) = controller(checker: .failure(.network))
        await controller.check(manual: false)
        #expect(controller.state == .idle)
    }

    @Test func aBuildFromSourceChecksNothing() async {
        let (controller, _) = controller(
            environment: environment(requirement: nil),
            checker: .success(release("1.27"))
        )
        #expect(!controller.canSelfUpdate)
        await controller.check(manual: true)
        #expect(controller.state == .idle)
    }

    @Test func aCheckLeavesItsTimeBehind() async {
        let defaults = freshDefaults()
        let (controller, _) = controller(checker: .success(release("1.27")), defaults: defaults)
        await controller.check(manual: true)
        #expect(defaults.object(forKey: "LastUpdateCheck") is Date)
    }

    // MARK: Бейдж

    @Test func aFoundReleaseLightsTheBadge() async {
        let (controller, _) = controller(checker: .success(release("1.27")))
        await controller.check(manual: true)
        #expect(controller.isBadgeVisible)
    }

    @Test func openingTheScreenPutsTheBadgeOut() async {
        let (controller, _) = controller(checker: .success(release("1.27")))
        await controller.check(manual: true)
        controller.present()
        #expect(controller.isPresented)
        #expect(!controller.isBadgeVisible)
    }

    @Test func laterKeepsTheBadgeOut() async {
        let (controller, _) = controller(checker: .success(release("1.27")))
        await controller.check(manual: true)
        controller.present()
        controller.close()
        #expect(!controller.isPresented)
        #expect(!controller.isBadgeVisible)
    }

    @Test func theNextReleaseLightsItAgain() async {
        let defaults = freshDefaults()
        let (seen, _) = controller(checker: .success(release("1.27")), defaults: defaults)
        await seen.check(manual: true)
        seen.present()

        let (next, _) = controller(checker: .success(release("1.28")), defaults: defaults)
        await next.check(manual: true)
        #expect(next.isBadgeVisible)
    }

    @Test func nothingFoundMeansNoBadge() async {
        let (controller, _) = controller(checker: .success(nil))
        await controller.check(manual: true)
        #expect(!controller.isBadgeVisible)
    }

    // MARK: Установка

    @Test func installingGoesThroughDownloadToTheScript() async {
        let dmg = URL(fileURLWithPath: "/tmp/Stash-1.27.dmg")
        let (controller, recorder) = controller(checker: .success(release("1.27")), downloader: .success(dmg))
        await controller.check(manual: true)
        await controller.runInstall()
        #expect(controller.state == .installing)
        #expect(recorder.installed == dmg)
        #expect(recorder.quits == 1)
    }

    @Test func aFolderWithoutWriteRightsStopsBeforeTheDownload() async {
        let (controller, recorder) = controller(
            environment: environment(writable: false),
            checker: .success(release("1.27"))
        )
        await controller.check(manual: true)
        await controller.runInstall()
        #expect(controller.state == .failed(.notWritable))
        #expect(recorder.installed == nil)
        #expect(recorder.quits == 0)
    }

    @Test func aBrokenDownloadIsReported() async {
        let (controller, recorder) = controller(
            checker: .success(release("1.27")),
            downloader: .failure(.network)
        )
        await controller.check(manual: true)
        await controller.runInstall()
        #expect(controller.state == .failed(.network))
        #expect(recorder.quits == 0)
    }

    @Test func aSignatureThatDoesNotMatchLeavesTheAppAlone() async {
        let (controller, recorder) = controller(
            checker: .success(release("1.27")),
            installFails: .signature("no match")
        )
        await controller.check(manual: true)
        await controller.runInstall()
        #expect(controller.state == .failed(.signature("no match")))
        #expect(recorder.quits == 0)
    }

    @Test func installingWithoutAReleaseDoesNothing() async {
        let (controller, recorder) = controller()
        await controller.runInstall()
        #expect(controller.state == .idle)
        #expect(recorder.quits == 0)
    }

    // MARK: Взвод первой проверки

    @Test func itDoesNotArmBeforeTheAppIsReady() {
        let (controller, _) = controller(ready: false)
        controller.armIfReady()
        #expect(!controller.isArmed)
    }

    @Test func itArmsOnceTheAppIsReady() {
        let (controller, _) = controller(ready: true)
        controller.armIfReady()
        #expect(controller.isArmed)
    }

    @Test func armingTwiceChangesNothing() {
        let (controller, _) = controller(ready: true)
        controller.armIfReady()
        controller.armIfReady()
        #expect(controller.isArmed)
    }

    @Test func automaticChecksSwitchedOffDoNotArm() {
        let (controller, _) = controller(ready: true)
        controller.isAutomatic = false
        controller.armIfReady()
        #expect(!controller.isArmed)
    }

    @Test func aBuildFromSourceNeverArms() {
        let (controller, _) = controller(environment: environment(requirement: nil), ready: true)
        controller.armIfReady()
        #expect(!controller.isArmed)
    }
}

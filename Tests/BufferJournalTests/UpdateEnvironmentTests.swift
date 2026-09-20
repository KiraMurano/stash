import Foundation
import Testing
@testable import BufferJournal

struct UpdateEnvironmentTests {
    private let requirement = #"identifier "local.buffer-journal" and certificate leaf H"abc""#

    private func environment(
        version: String? = "1.26",
        requirement: String? = nil,
        writable: Bool = true
    ) -> UpdateEnvironment {
        UpdateEnvironment(
            currentVersion: UpdateEnvironment.releasedVersion(version),
            requirement: requirement ?? self.requirement,
            bundleURL: URL(fileURLWithPath: "/Applications/Stash.app"),
            isDestinationWritable: writable
        )
    }

    private func release(_ version: String) -> Release {
        Release(
            version: AppVersion(version)!,
            notes: "",
            dmgURL: URL(string: "https://example.invalid/Stash-\(version).dmg")!,
            size: 1
        )
    }

    @Test func aSignedBuildWithAVersionCanUpdateItself() {
        #expect(environment().canSelfUpdate)
    }

    @Test func aBuildWithoutTheRequirementCannot() {
        let environment = UpdateEnvironment(
            currentVersion: AppVersion("1.26"),
            requirement: nil,
            bundleURL: URL(fileURLWithPath: "/Applications/Stash.app"),
            isDestinationWritable: true
        )
        #expect(!environment.canSelfUpdate)
    }

    @Test func theSourceBuildPlaceholderIsNoVersion() {
        #expect(!environment(version: "0.0").canSelfUpdate)
    }

    @Test func aHigherReleaseIsNewer() {
        #expect(environment().isNewer(release("1.27")))
    }

    @Test func theSameOrAnOlderReleaseIsNot() {
        #expect(!environment().isNewer(release("1.26")))
        #expect(!environment().isNewer(release("1.25")))
    }

    @Test func withoutAVersionNothingIsNewer() {
        #expect(!environment(version: nil).isNewer(release("1.27")))
    }

    @Test func aReadOnlyFolderStillSeesTheRelease() {
        // Права на запись решают, можно ли поставить, а не можно ли узнать.
        let environment = environment(writable: false)
        #expect(environment.isNewer(release("1.27")))
        #expect(!environment.isDestinationWritable)
    }

    @Test func theTestBundleHasNoRequirementOfItsOwn() {
        // Тесты идут не в .app: фабрика не должна падать и обязана сказать "обновлять нечего".
        #expect(!UpdateEnvironment.current(bundle: .main).canSelfUpdate)
    }
}

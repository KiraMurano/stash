import Foundation
import Testing
@testable import BufferJournal

@MainActor
struct AboutControllerTests {
    /// Кнопки обратной связи на экране больше нет: у него нет главного действия,
    /// и остался только адрес репозитория.
    @Test func theLinkLeadsToTheRepository() {
        #expect(AboutController.repository.absoluteString == "https://github.com/KiraMurano/stash")
    }

    /// A source build has no released version, and the lockup then names the app alone.
    @Test func aBuildWithoutAVersionSaysNothingAboutIt() {
        let environment = UpdateEnvironment(
            currentVersion: nil,
            requirement: nil,
            bundleURL: URL(fileURLWithPath: "/tmp"),
            isDestinationWritable: false
        )

        #expect(AboutController(environment: environment).currentVersion == nil)
    }
}

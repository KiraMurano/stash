import Foundation
import Testing
@testable import BufferJournal

@MainActor
struct AboutControllerTests {
    @Test func theScreenIsShownOnlyWhenAsked() {
        let controller = AboutController(environment: UpdateEnvironment.current())
        #expect(!controller.isPresented)

        controller.present()
        #expect(controller.isPresented)

        controller.close()
        #expect(!controller.isPresented)
    }

    @Test func theButtonAndTheLinkLeadToDifferentPages() {
        #expect(AboutController.repository.absoluteString == "https://github.com/KiraMurano/stash")
        #expect(AboutController.feedback.absoluteString == "https://github.com/KiraMurano/stash/issues/new")
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

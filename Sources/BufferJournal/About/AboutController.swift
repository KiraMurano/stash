import AppKit
import Foundation

/// The About screen: it is either on the panel or not, and it knows the two pages it opens.
/// Keeping the URLs here leaves the screen itself without any knowledge of the outside world.
@MainActor
final class AboutController: ObservableObject {
    static let repository = URL(string: "https://github.com/KiraMurano/stash")!
    /// Stash has no server to take a message, the way the studio's other apps do, so feedback
    /// goes where the source is.
    static let feedback = URL(string: "https://github.com/KiraMurano/stash/issues/new")!

    @Published private(set) var isPresented = false

    private let environment: UpdateEnvironment

    init(environment: UpdateEnvironment = .current()) {
        self.environment = environment
    }

    /// Nil in a build made from source: it keeps the placeholder version, which is not one.
    var currentVersion: AppVersion? {
        environment.currentVersion
    }

    func present() {
        isPresented = true
    }

    func close() {
        isPresented = false
    }

    func openRepository() {
        NSWorkspace.shared.open(Self.repository)
    }

    func openFeedback() {
        NSWorkspace.shared.open(Self.feedback)
    }
}

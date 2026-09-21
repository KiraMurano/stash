import AppKit
import Foundation

/// The About screen's outside world: the version it names and the one page it opens. Whether
/// the screen is on screen is the window's business, not the controller's.
@MainActor
final class AboutController: ObservableObject {
    static let repository = URL(string: "https://github.com/KiraMurano/stash")!

    private let environment: UpdateEnvironment

    init(environment: UpdateEnvironment = .current()) {
        self.environment = environment
    }

    /// Nil in a build made from source: it keeps the placeholder version, which is not one.
    var currentVersion: AppVersion? {
        environment.currentVersion
    }

    func openRepository() {
        NSWorkspace.shared.open(Self.repository)
    }
}

import Foundation

/// Everything that can go wrong on the way to a new version. The texts the user sees are built
/// from these cases by the controller, in the language of the app.
enum UpdateError: Error, Equatable {
    /// GitHub did not answer, or answered with something that is not a release.
    case network
    /// The downloaded image does not satisfy this build's requirement.
    case signature(String)
    /// The install script could not be started, or it left a failure behind.
    case install(String)
    /// Stash lives in a folder it may not write to.
    case notWritable
}

/// Asks where the newest release is. The app talks to GitHub; the tests hand in their own.
protocol UpdateChecking: Sendable {
    /// The newest release, or nil when there is nothing that looks like one.
    func latestRelease() async throws -> Release?
}

struct GitHubUpdateChecker: UpdateChecking {
    static let feedURL = URL(string: "https://api.github.com/repos/KiraMurano/stash/releases/latest")!

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func latestRelease() async throws -> Release? {
        var request = URLRequest(url: Self.feedURL)
        request.timeoutInterval = 15
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw UpdateError.network
        }

        // 403 is GitHub's rate limit — 60 unauthenticated requests an hour. One check a day never
        // reaches it, but a shared address might, and that is an ordinary failed check.
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw UpdateError.network
        }

        return ReleaseFeed.parse(data)
    }
}

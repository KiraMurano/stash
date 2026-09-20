import Foundation

/// Stash's version: MAJOR.MINOR, where MAJOR is set by hand in the VERSION file and MINOR is a
/// running release counter that never resets (0.25 → 1.26). Both numbers are compared, so a new
/// MAJOR wins even when its MINOR is somehow smaller.
struct AppVersion: Equatable, Comparable, CustomStringConvertible {
    let major: Int
    let minor: Int

    init(major: Int, minor: Int) {
        self.major = major
        self.minor = minor
    }

    /// Takes "1.27" and the tag form "v1.27"; anything else is not a version.
    init?(_ string: String) {
        var text = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("v") || text.hasPrefix("V") {
            text.removeFirst()
        }

        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 2, let major = Int(parts[0]), let minor = Int(parts[1]) else { return nil }

        self.init(major: major, minor: minor)
    }

    var description: String {
        "\(major).\(minor)"
    }

    static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        (lhs.major, lhs.minor) < (rhs.major, rhs.minor)
    }
}

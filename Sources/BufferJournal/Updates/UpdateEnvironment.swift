import Foundation

/// What the running copy of Stash knows about itself: which version it is, what a downloaded
/// build must satisfy to be trusted, where it lives and whether that place can be written to.
///
/// A build made by `swift build` or by `Scripts/build_app.sh` without a version keeps the
/// placeholder 0.0 from Info.plist and carries no StashUpdateRequirement. Such a build never
/// checks for updates: there is nothing to compare against and nothing to verify with.
struct UpdateEnvironment: Sendable {
    /// The placeholder Info.plist ships with; it is not a released version.
    static let placeholderVersion = "0.0"
    static let requirementKey = "StashUpdateRequirement"

    let currentVersion: AppVersion?
    let requirement: String?
    let bundleURL: URL
    let isDestinationWritable: Bool

    var canSelfUpdate: Bool {
        currentVersion != nil && requirement != nil
    }

    func isNewer(_ release: Release) -> Bool {
        guard let currentVersion else { return false }
        return release.version > currentVersion
    }

    /// The version a build reports, or nil when it is the placeholder a source build keeps.
    static func releasedVersion(_ raw: String?) -> AppVersion? {
        guard let raw, raw != placeholderVersion else { return nil }
        return AppVersion(raw)
    }

    static func current(bundle: Bundle = .main) -> UpdateEnvironment {
        let version = releasedVersion(bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
        let requirement = bundle.object(forInfoDictionaryKey: requirementKey) as? String
        let url = bundle.bundleURL

        return UpdateEnvironment(
            currentVersion: version,
            requirement: requirement?.isEmpty == false ? requirement : nil,
            bundleURL: url,
            // The swap renames the bundle inside its parent folder, so the folder is what must
            // be writable — not the bundle.
            isDestinationWritable: FileManager.default.isWritableFile(atPath: url.deletingLastPathComponent().path)
        )
    }
}

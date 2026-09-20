import Foundation

/// One release on GitHub: the version it carries, its notes and the image to download.
struct Release: Equatable, Sendable {
    let version: AppVersion
    let notes: String
    let dmgURL: URL
    let size: Int64
}

/// Reads the answer of https://api.github.com/repos/KiraMurano/stash/releases/latest.
/// A tag that is not a version and a release without a DMG both mean "no release": Stash treats
/// them as "nothing new", never as an error.
enum ReleaseFeed {
    private struct Payload: Decodable {
        struct Asset: Decodable {
            let name: String
            let size: Int64
            let browserDownloadURL: URL

            enum CodingKeys: String, CodingKey {
                case name
                case size
                case browserDownloadURL = "browser_download_url"
            }
        }

        let tagName: String
        let body: String?
        let assets: [Asset]

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case body
            case assets
        }
    }

    static func parse(_ data: Data) -> Release? {
        guard
            let payload = try? JSONDecoder().decode(Payload.self, from: data),
            let version = AppVersion(payload.tagName),
            let asset = payload.assets.first(where: { $0.name.lowercased().hasSuffix(".dmg") })
        else {
            return nil
        }

        return Release(
            version: version,
            notes: payload.body ?? "",
            dmgURL: asset.browserDownloadURL,
            size: asset.size
        )
    }
}

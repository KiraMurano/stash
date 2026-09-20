import Foundation
import Testing
@testable import BufferJournal

struct ReleaseFeedTests {
    /// Ответ GitHub, обрезанный до полей, которые читает Stash.
    private func json(tag: String = "v1.27", assets: String = Self.dmgAsset) -> Data {
        Data("""
        {
          "tag_name": "\(tag)",
          "name": "Stash 1.27",
          "body": "- Журнал открывается у курсора.\\n- Stash обновляется сам.",
          "assets": [\(assets)]
        }
        """.utf8)
    }

    private static let dmgAsset = """
    {
      "name": "Stash-1.27.dmg",
      "size": 4404019,
      "browser_download_url": "https://github.com/KiraMurano/stash/releases/download/v1.27/Stash-1.27.dmg"
    }
    """

    @Test func readsVersionNotesAndTheImage() throws {
        let release = try #require(ReleaseFeed.parse(json()))
        #expect(release.version == AppVersion(major: 1, minor: 27))
        #expect(release.size == 4_404_019)
        #expect(release.dmgURL.lastPathComponent == "Stash-1.27.dmg")
        #expect(release.notes.contains("Stash обновляется сам."))
    }

    @Test func skipsAssetsThatAreNotTheImage() throws {
        let extra = """
        { "name": "Stash-1.27.dmg.sha256", "size": 80,
          "browser_download_url": "https://example.invalid/checksum" },
        \(Self.dmgAsset)
        """
        let release = try #require(ReleaseFeed.parse(json(assets: extra)))
        #expect(release.dmgURL.lastPathComponent == "Stash-1.27.dmg")
    }

    @Test func aReleaseWithoutAnImageIsNoRelease() {
        #expect(ReleaseFeed.parse(json(assets: "")) == nil)
    }

    @Test func aTagThatIsNotAVersionIsNoRelease() {
        #expect(ReleaseFeed.parse(json(tag: "nightly")) == nil)
    }

    @Test func rubbishIsNoRelease() {
        #expect(ReleaseFeed.parse(Data("not json".utf8)) == nil)
    }
}

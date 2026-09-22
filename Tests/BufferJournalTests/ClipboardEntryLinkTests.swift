import Foundation
import Testing
@testable import BufferJournal

/// A text clip that is one web address gets the link tile in the list; anything else is text.
struct ClipboardEntryLinkTests {
    private func text(_ value: String) -> ClipboardEntry {
        ClipboardEntry(id: UUID(), payload: .text(value), createdAt: Date(), fingerprint: value)
    }

    @Test func aWebAddressIsALink() {
        #expect(text("https://github.com/KiraMurano/stash").isLink)
        #expect(text("github.com/KiraMurano/stash").isLink)
        #expect(text("  www.ozero.digital \n").isLink)
    }

    @Test func proseAndAddressesOfOtherKindsAreText() {
        #expect(!text("Stash 1.10 — release notes").isLink)
        #expect(!text("see github.com/KiraMurano/stash for the code").isLink)
        #expect(!text("hello@ozero.digital").isLink)
        #expect(!text("").isLink)
    }

    @Test func onlyTextCanBeALink() {
        let image = ClipboardEntry(id: UUID(), payload: .image(filename: "x.png"), createdAt: Date(), fingerprint: "x")
        #expect(!image.isLink)
    }
}
